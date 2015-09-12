/*
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

/**
Filesystem-related functionality

Authors:    Lars Tandle Kyllingstad
Copyright:  Copyright (c) 2010–2015, Lars T. Kyllingstad. All rights reserved.
License:    Mozilla Public License v. 2.0
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
