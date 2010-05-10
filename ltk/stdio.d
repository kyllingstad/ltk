module ltk.stdio;


import core.sys.posix.fcntl;
import core.sys.posix.unistd;

import std.array;
import std.conv;
import std.contracts;
import std.string;
import std.stdio;
import std.traits;




/** Struct for unbuffered reading and writing of files. */
struct UnbufferedFile
{
    struct Impl
    {
        int fileDescriptor = -1;
        int refs = 0;

        this (int fd, int r)
        {
            fileDescriptor = fd;
            refs = r;
        }
    }

    Impl* p;


    /** Open the specified file.  The valid modes are:
        $(UL
            $(LI "r":   Open a file for reading.  The file must exist.)
            $(LI "w":   Open a new file for writing.  If the file already
                        exists, its contents are erased.)
            $(LI "a":   Append to a file.  If it doesn't exist, a new file
                        is created.)
            $(LI "r+":  Open a file for both reading and writing.  The file
                        must exist, and its contents are not erased.)
            $(LI "w+":  Open a new file for reading and writing.  If the
                        file already exists, its contents are erased.)
            $(LI "a+":  Open a file for reading and appending.  All write
                        operations are performed at the end of a file.
                        You may seek to another part of the file for reading,
                        but the next write operation will move the internal
                        pointer to the end of the file again.))
    */
    this (string filename, string mode)
    {
        int flags;
        switch (mode[0])
        {
        case 'r':
            if (mode.length > 1 && mode[1] == '+')
                flags = O_RDWR;
            else
                flags = O_RDONLY;
            break;

        case 'w':
            if (mode.length > 1 && mode[1] == '+')
                flags = O_RDWR | O_CREAT | O_TRUNC;
            else
                flags = O_WRONLY | O_CREAT | O_TRUNC;
            break;

        case 'a':
            if (mode.length > 1 && mode[1] == '+')
                flags = O_RDWR | O_CREAT | O_APPEND;
            else
                flags = O_WRONLY | O_CREAT | O_APPEND;
            break;
        }

        auto fd = open(toStringz(filename), flags, octal!666);
        errnoEnforce(fd != -1, "Cannot open file '"~filename~"'");

        p = new Impl(fd, 1);
    }


    ~this()
    {
        if (p == null) return;
        if (p.refs == 1)  close();
        else --p.refs;
    }


    this(this)
    {
        if (p == null) return;
        enforce(p.refs > 0);
        ++p.refs;
    }



    /** Close the file. */
    void close()
    {
        if (p == null) return;
        if (p.fileDescriptor == -1)
        {
            p = null;
            return;
        }

        scope(exit)
        {
            p.fileDescriptor = -1;
            --p.refs;
            p = null;
        }

        errnoEnforce(core.sys.posix.unistd.close(p.fileDescriptor) != -1,
            "Could not close file");
    }



    /** Detach this UnbufferedFile instance from the underlying file.
        Other references to the file will still work.
    */
    void detach()
    {
        if (p == null) return;

        if (p.refs == 1)  close();
        else --p.refs;

        p = null;
    }



    /** Attempt to read one character from file, and return
        true on success.
    */
    bool read(C)(ref C c)
    {
        auto r = core.sys.posix.unistd.read(p.fileDescriptor,
            cast(void*) &c, C.sizeof);
        errnoEnforce(r != -1, "Could not read from file");

        // At end of file?
        if (r == 0) return false;

        // For multibyte characters, check that the file didn't end
        // in the middle of one.
        static if (C.sizeof > 1)
        {
            enforce (r == C.sizeof,
                "File ended in the middle of a character");
        }

        return true;
    }




    /** Read a line from the file. */
    size_t readln(C)(ref C[] buf) if (is (C : dchar))
    {
        return readln!(C, C)(buf, '\n');
    }


    /// ditto
    size_t readln(C, T)(ref C[] buf, T terminator)
        if (is(C : T) || is (T : C))
    {
        if (buf.length == 0)  buf.length = 1024;

        int pos = 0;
        while(true)
        {
            // Check whether buffer is big enough.
            if (pos == buf.length) buf.length *= 2;

            // Read one character from file.
            if (!read(buf[pos])) break;

            // Compare against terminator
            if (buf[pos] == terminator) { ++pos; break; }
            
            ++pos;
        }

        buf = buf[0 .. pos];
        return pos;
    }




    /** Input range that reads the file line by line.
        The array is reused between calls to popFront().
    */
    struct ByLine(C, T)
        if (is(T : C) ||  is(C : T))
    {
    private:
        C[] line;
        T terminator;
        UnbufferedFile file;
        bool keepTerminator;
        bool eof;


    public:
        this(UnbufferedFile file, bool keepTerminator, T terminator)
        {
            this.file = file;
            this.keepTerminator = keepTerminator;
            this.terminator = terminator;
            popFront();
        }


        void popFront()
        {
            enforce(!empty, "popFront() at end of file");

            if (file.readln(line, terminator) == 0)
            {
                eof = true;
                return;
            }

            if (!keepTerminator)
            {
                line = line[0 .. $-1];
            }
        }


        @property C[] front()
        {
            return line;
        }


        @property bool empty()
        {
            return eof;
        }
    }


    /// ditto
    version(Posix) ByLine!(C, char) byLine(C = char)
        (bool keepTerminator = false)
    {
        return typeof(return)(this, keepTerminator, '\n');
    }


    template ElemType(T)
    {
        static if (is (T E == E[])) alias Unqual!E ElemType;
        else alias T ElemType;
    }
    
    /// ditto
    ByLine!(C, T) byLine(T, C = ElemType!T)(bool keepTerminator, T terminator)
    {
        return typeof(return)(this, keepTerminator, terminator);
    }




    /** Range that reads the file in chunks, given a maximum chunk
        size.
        Note that the array is reused between calls to popFront().
    */
    struct ByChunk(Char)
    {
    private:
        Char[] chunk;
        ssize_t readLen;
        UnbufferedFile file;


    public:
        this(UnbufferedFile file, size_t size)
        {
            assert (size > 0);
            chunk = new Char[size];
            this.file = file;
            popFront();
        }

        void popFront()
        {
            readLen = core.sys.posix.unistd.read(file.p.fileDescriptor,
                cast(void*) chunk.ptr, Char.sizeof*chunk.length);
            errnoEnforce(readLen != -1,
                "Could not read from file '"~file.p.name~"'");
        }
            
        @property Char[] front()
        {
            return chunk[0 .. readLen];
        }

        @property bool empty()
        {
            return readLen == 0;
        }
    }

    
    /// ditto
    ByChunk!Char byChunk(Char = ubyte)(size_t chunkSize)
    {
        return ByChunk!Char(this, chunkSize);
    }
}

