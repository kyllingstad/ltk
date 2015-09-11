/**
Filesystem-related functionality

Authors:    Lars Tandle Kyllingstad
Copyright:  Copyright (c) 2010–2015, Lars T. Kyllingstad. All rights reserved.
License:    Boost License 1.0
*/
module ltk.file;


/// Check whether the file exists and can be executed by the current user.
version(Posix) bool isExecutable(string path)
{
    import core.sys.posix.unistd;
    import std.string;
    return (access(toStringz(path), X_OK) == 0);
}

version(Posix) unittest
{
    assert(isExecutable("/bin/sh"));
    assert(!isExecutable("/etc/groups"));
}
