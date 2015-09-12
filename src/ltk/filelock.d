/*
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

/** POSIX file locking, the easy way.

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad. All rights reserved.
    License:    Mozilla Public License v. 2.0
*/
module ltk.filelock;


import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.stdc.errno;
import core.stdc.string;
import core.stdc.stdio;

import std.conv;
import std.exception;
import std.stdio;



/** Lock types. */
enum LockType : short
{
    /** A read lock, also known as a "shared lock". There may be multiple
        read locks on a file, as they do not conflict with each other.
    */
    read = F_RDLCK,

    /** A write lock, also known as an "exclusive lock". When a write lock
        has been acquired on a file, no other locks (read or write) may be
        acquired on the same file until the first one has been released.

        A write lock cannot be acquired if there is already a lock (read or
        write) on the file.
    */
    write = F_WRLCK
}


/** What to do if a lock cannot be acquired on a file because another
    lock is blocking it.
*/
enum OnBlockingLock
{
    /// Wait for the blocking lock(s) to be released.
    wait = F_SETLKW,

    /// Throw an exception.
    throwException = F_SETLK
}


/** This struct is used to acquire a lock on a file. Note that the
    lock is released automatically as soon as there are no more
    references to it.

    Examples:
    safewriter.d
    ---
    module safewriter;
    import std.stdio, ltk.filelock;

    void main(string[] args)
    {
        assert (args.length > 1);

        // Open file for writing and acquire a write lock.
        auto file = File(args[1], "w");
        auto lock = FileLock(file, LockType.write);

        writeln("Write contents of file, 'EOF' to end:");
        foreach (line; stdin.byLine)
        {
            if (line == "EOF") break;
            file.writeln(line);
        }
    }
    ---
    safereader.d
    ---
    module safereader;
    import std.stdio, ltk.filelock;

    void main(string[] args)
    {
        assert (args.length > 1);

        // Open file for reading and acquire a read lock.
        auto file = File(args[1], "r");
        auto lock = FileLock(file, LockType.read);

        writeln("Contents of file:");
        foreach (line; file.byLine) writeln(line);
    }
    ---
*/
struct FileLock
{
private:
    struct Impl
    {
        flock fileLock;
        int fileDescriptor;
        bool locked = false;
        int refs;

        this (flock fl, int fd, bool lk)
        {
            fileLock = fl;
            fileDescriptor = fd;
            locked = lk;
            refs = 1;
        }
    }
    Impl* lock;


public:
    /** Constructor. */
    this(File file, LockType type, OnBlockingLock action = OnBlockingLock.wait)
    {
        // Set lock data
        flock fl;
        fl.l_type = type;
        fl.l_whence = SEEK_SET;
        fl.l_start = 0;
        fl.l_len = 0;
        fl.l_pid = getpid();

        // Get file descriptor
        auto fd = file.fileno;

        // Set lock
        auto status = fcntl(fd, action, &fl);
        enforce(status != -1, to!string(strerror(errno)));
        
        lock = new Impl(fl, fd, true);
    }

    this(this)
    {
        if (lock == null) return;
        enforce (lock.refs > 0);
        lock.refs++;
    }

    ~this()
    {
        if (lock == null) return;
        if (lock.refs == 1)  release();
        lock.refs--;
    }


    /** Manual release of the lock. */
    void release()
    {
        if (lock == null || !lock.locked) return;

        // Unlock file
        lock.fileLock.l_type = F_UNLCK;
        fcntl(lock.fileDescriptor, F_SETLK, &lock.fileLock);
        lock.locked = false;
    }


    /** Returns true if the lock is set. */
    @property bool locked()
    {
        return (lock != null) && lock.locked;
    }
}


version (unittest) import std.stdio;
unittest
{
    string name = "/tmp/ltk_filelock_unittest";

    version (filelock_write)
    {    
        // Open file for writing and acquire a write lock.
        auto file = File(name, "w");
        writeln("Acquiring lock...");
        auto lock = FileLock(file, LockType.write);

        writeln("Write contents of file, 'EOF' to end:");
        foreach (line; std.stdio.stdin.byLine)
        {
            if (line == "EOF") break;
            file.writeln(line);
        }
    }

    version (filelock_read)
    {
        // Open file for reading and acquire a read lock.
        auto file = File(name, "r");
        writeln("Acquiring lock...");
        auto lock = FileLock(file, LockType.read);

        writeln("Contents of file:");
        foreach (line; file.byLine) writeln(line);
    }
}
