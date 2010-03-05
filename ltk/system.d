/** Communication with the environment in which the program runs.

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad. All rights reserved.
    License:    Boost License 1.0
*/
module ltk.system;


import core.stdc.stdlib;

import std.conv;
import std.string;


// Some sources say this is supposed to be defined in unistd.h,
// but the POSIX spec doesn't mention it:
version(Posix)
{
    extern(C) extern __gshared const char** environ;
}




/** Return the value of the environment variable with the given name. */
string getEnv(string name)
{
    return to!string(getenv(toStringz(name)));
}



/** Return all environment variables as an associative array. */
version(Posix) string[string] getEnv()
{
    string[string] envArray;

    const(char)* envDefz;
    for (int i=0; (envDefz = environ[i]) != null; i++)
    {
        auto envDef = to!string(envDefz);
        auto eqPos = envDef.indexOf('=');
        if (eqPos == -1)  continue;

        auto key = envDef[0 .. eqPos];
        // In POSIX, environment variables may be defined more than once.
        // This is a security issue, which we avoid by checking whether the
        // key already exists in the array.  For more info:
        // http://www.dwheeler.com/secure-programs/Secure-Programs-HOWTO/environment-variables.html
        if (key in envArray)  continue;

        envArray[key] = envDef[eqPos+1 .. $];
    }

    return envArray;
}

unittest
{
    // As long as getEnv(string) uses the C getenv() function,
    // this unittest should be good enough.
    auto env = getEnv();
    assert (env["PATH"] == getEnv("PATH"));
}
