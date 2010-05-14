/** I/O stuff.

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad. All rights reserved.
    License:    Boost License 1.0
*/
module ltk.stdio;


import core.sys.posix.fcntl;
import core.sys.posix.stdio;
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
private:

    struct Impl
    {
        int fileDescriptor = -1;
        string name;
        string mode;
        int refs = 0;

        this (int fd, string n, string m, int r)
        {
            fileDescriptor = fd;
            name = n;
            mode = m;
            refs = r;
        }
    }

    Impl* p;



public:

    /** Open the specified file.  The valid modes are:
        $(TABLE
        $(TR $(TD "r":) $(TD Open a file for reading.  The file must exist.))
        $(TR $(TD "w":) $(TD Open a new file for writing.  If the file already
                            exists, its contents are erased.))
        $(TR $(TD "a":) $(TD Append to a file.  If it doesn't exist, a new file
                            is created.))
        $(TR $(TD "r+":)$(TD Open a file for both reading and writing.  The file
                            must exist, and its contents are not erased.))
        $(TR $(TD "w+":)$(TD Open a new file for reading and writing.  If the
                            file already exists, its contents are erased.))
        $(TR $(TD "a+":)$(TD Open a file for reading and appending.  All write
                        operations are performed at the end of a file.
                        You may seek to another part of the file for reading,
                        but the next write operation will move the internal
                        pointer to the end of the file again.)))
    */
    this (string filename, string mode = "r", bool autoClose = true)
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
        default:
            enforce(false, "Invalid file open mode");
        }

        auto fd = core.sys.posix.fcntl.open(
            toStringz(filename),
            flags,
            octal!666);
        errnoEnforce(fd != -1, "Cannot open file '"~filename~"'");

        p = new Impl(fd, filename, mode,
            (autoClose ? 1 : 999));
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




    /** First calls detach() and then attempts to open the given
        file with the specified mode.
    */
    void open(string filename, string mode)
    {
        detach();
        this = UnbufferedFile(filename, mode);
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
        Other references to the file will still work.  If this is the
        last reference, close the file.
    */
    void detach()
    {
        if (p == null) return;

        if (p.refs == 1)  close();
        else --p.refs;

        p = null;
    }




    /** Attempt to read a single value from the file, and return
        true on success, false on failure.
    */
    bool read(T)(ref T t) const
        if (!isArray!T)
    {
        auto n = core.sys.posix.unistd.read(p.fileDescriptor,
            cast(void*) &t, T.sizeof);
        errnoEnforce(n != -1, "Could not read from file");

        if (n == 0) return false;

        // For multibyte values, check that the whole value was read.
        static if (T.sizeof > 1)
        {
            enforce (n == T.sizeof,
                "File ended in the middle of a character");
        }

        return true;
    }



    /** Attempt to read up to buffer.length values from the
        file into buffer and return buffer[0..n], where n is
        the actual number of values read.
    */
    T[] read(T)(T[] buffer) const
    {
        auto n = core.sys.posix.unistd.read(p.fileDescriptor,
            cast(void*) buffer.ptr, T.sizeof*buffer.length);
        errnoEnforce(n != -1, "Could not read from file");

        // For multibyte values, check that a whole number of values
        // was read.
        static if (T.sizeof > 1)
        {
            enforce (n % T.sizeof == 0,
                "File ended in the middle of a character");
        }

        return buffer[0 .. n/T.sizeof];
    }



    /** Attempt to write a single value to the file, and return
        true on success, false on failure.
    */
    bool write(T)(T t) const 
        if (!isArray!T)
    {
        auto n = core.sys.posix.unistd.write(p.fileDescriptor,
            cast(void*) &t, T.sizeof);
        errnoEnforce(n != -1, "Could not write to file");

        if (n == 0) return false;

        // For multibyte values, check that the whole value was written.
        static if (T.sizeof > 1)
        {
            enforce (n == T.sizeof,
                "Write stopped in the middle of a character");
        }

        return true;
    }




    /** Attempt to write the contents of buffer to the file,
        and return the number of elements written.
    */
    size_t write(T)(const T[] buffer) const
    {
        auto n = core.sys.posix.unistd.write(p.fileDescriptor,
            cast(void*) buffer.ptr, T.sizeof*buffer.length);
        errnoEnforce(n != -1, "Could not write to file");

        // For multibyte values, check that a whole number of values
        // was written.
        static if (T.sizeof > 1)
        {
            enforce (n % T.sizeof == 0,
                "Write stopped in the middle of a character");
        }

        return n / T.sizeof;
    }




    /** Range that reads the file one value at a time.  Note that this
        is a very slow way of reading most streams, especially disk files.
    */
    struct ByValue(T)
    {
    private:
        T value;
        bool gotValue = true; // Set to true so popFront() succeeds first time.
        UnbufferedFile file;

    public:
        this(UnbufferedFile file)
        {
            this.file = file;
            popFront();
        }

        void popFront()
        {
            enforce(!empty, "popFront() called on empty range");
            gotValue = file.read(value);
        }
            
        @property T front()
        {
            enforce(!empty, "front() called on empty range");
            return value;
        }

        @property bool empty()
        {
            return !gotValue;
        }
    }

    
    /// ditto
    ByValue!T byValue(T = ubyte)()
    {
        return ByValue!T(this);
    }




    /** Range that reads the file in chunks, given a maximum chunk size.
        Note that the array is reused between calls to popFront().

        ---
        auto input = UnbufferedFile("secret.txt", "r");
        auto output = UnbufferedFile("secret.encrypted", "w");

        // Man, no-one is *ever* going to break this.
        foreach (chunk; input.byChunk(1024))
        {
            chunk[] += 1;
            output.write(chunk);
        }
        ---
    */
    struct ByChunk(T)
    {
    private:
        T[] buffer, data;
        UnbufferedFile file;

    public:
        this(UnbufferedFile file, size_t size)
        {
            enforce (size > 0, "Cannot read in zero-sized chunks");
            buffer = new T[size];
            data = buffer; // So popFront() succeeds the first time.
            this.file = file;
            popFront();
        }

        void popFront()
        {
            enforce(!empty, "popFront() called on empty range");
            data = file.read(buffer);
        }
            
        @property T[] front()
        {
            enforce(!empty, "front() called on empty range");
            return data;
        }

        @property bool empty()
        {
            return data.length == 0;
        }
    }

    
    /// ditto
    ByChunk!T byChunk(T = ubyte)(size_t chunkSize)
    {
        return ByChunk!T(this, chunkSize);
    }




    /** Return a std.stdio.File pointing to the same file. */
    File buffered(bool autoClose = false) const
    {
        // TODO: Using the internals of File like this feels like a hack,
        // but the File.wrapFile() function disables automatic closing of
        // the file.  Perhaps there should be a protected version of
        // wrapFile() that fills this purpose?
        File f;
        f.p = new File.Impl(
            errnoEnforce(fdopen(p.fileDescriptor, toStringz(p.mode)),
                "Cannot wrap in File"),
            (autoClose ? 1 : 999),
            p.name);

        return f;
    }




    /** Wrap a POSIX file descriptor.
    
        Unless a mode is specifically specified, this function will
        try to deduce the correct mode for the file, and throw an
        exception on failure.  This will happen in the case of pipes
        for instance, for which the OS mode flag isn't set.
    */
    static UnbufferedFile wrapFileDescriptor(int fd, string name=null,
        string mode=null, bool autoClose=false)
    {

        if (mode == null)
        {
            auto flags = core.sys.posix.fcntl.fcntl(fd, F_GETFL);
            errnoEnforce(flags != -1,
                "Unable to retrieve info about file descriptor");

            if (flags & O_RDONLY)  mode = "r";
            else if (flags & O_WRONLY)
            {
                if (flags & O_APPEND)  mode = "a";
                else mode = "w";
            }
            else if (flags & O_RDWR)
            {
                if (flags & O_APPEND)  mode = "a+";
                else if (flags & O_TRUNC)  mode = "w+";
                else mode = "r+";
            }
            else enforce(false,
                "Could not deduce correct mode for file descriptor "
                ~to!string(fd)~" ("~name~")");
        }

        UnbufferedFile f;
        int refs = (autoClose ? 1 : 999);
        f.p = new Impl(fd, name, mode, refs);
        return f;
    }



    /** Return the POSIX file descriptor referred to by this
        UnbufferedFile.
    */
    @property int fileDescriptor() { return p.fileDescriptor; }
}


unittest
{
    auto f = UnbufferedFile("deleteme", "w");
    f.write("Hello world"d);

    f.open("deleteme", "r");
    auto buffer = new dchar[20];
    auto hello = f.read(buffer);
    assert (hello == "Hello world"d);

    f.open("deleteme", "r");
    auto rawBuffer = new ubyte[50];
    auto rawHello = f.read(rawBuffer);
    assert (cast(const(dchar)[])(rawHello) == "Hello world"d);

    auto fd = core.sys.posix.fcntl.open("deleteme", O_RDWR);
    auto w = UnbufferedFile.wrapFileDescriptor(fd, "deleteme", null, true);
    buffer[] = '\0';
    hello = w.read(buffer);
    assert (hello == "Hello world"d);
}




// TODO: Make this a member function of File.
/// Return an UnbufferedFile that points to the same file as
/// the given File object.
UnbufferedFile unbuffered(File f, bool autoClose = false)
{
    return UnbufferedFile.wrapFileDescriptor(
        core.sys.posix.stdio.fileno(f.getFP()),
        f.name,
        null,
        autoClose);
}




/** UnbufferedFile handles pointing to the standard input, output, and
    error streams.

    Note:
    On POSIX, even though UnbufferedFile doesn't perform any buffering,
    terminal input/output is usually buffered by the operating system.
    This can be controlled using the core.sys.posix.termios.tcsetattr()
    system call with the ICANON flag.  See the tcsetattr(3) man page for
    more info.
*/
UnbufferedFile ustdin;
UnbufferedFile ustdout;     /// ditto
UnbufferedFile ustderr;     /// ditto

static this()
{
    ustdin  =
        UnbufferedFile.wrapFileDescriptor(STDIN_FILENO, null, null, false);
    ustdout =
        UnbufferedFile.wrapFileDescriptor(STDOUT_FILENO, null, null, false);
    ustderr =
        UnbufferedFile.wrapFileDescriptor(STDERR_FILENO, null, null, false);
}
