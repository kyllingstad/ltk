/** Communication with the environment in which the program runs.

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad. All rights reserved.
    License:    Boost License 1.0
*/
module ltk.system;


import core.stdc.string;

// setenv() and unsetenv() are POSIX-specific.
version (Posix) import core.sys.posix.stdlib;
else import core.stdc.stdlib;

import std.contracts;
import std.conv;
import std.string;


// Some sources say this is supposed to be defined in unistd.h,
// but the POSIX spec doesn't mention it:
version(Posix)
{
    private extern(C) extern __gshared const char** environ;
}




/** Return the value of the environment variable with the given name.
    Calls core.stdc.stdlib._getenv internally.
*/
string getEnv(string name)
{
    // Cache the last call's result.
    static string lastResult;

    const valuez = getenv(toStringz(name));
    if (valuez == null)  return null;
    auto value = valuez[0 .. strlen(valuez)];
    if (value == lastResult) return lastResult;

    return lastResult = value.idup;
}


/** Set the value of the environment variable name to value. */
version(Posix) void setEnv(string name, string value, bool overwrite)
{
    // errno message not very informative, hence not use errnoEnforce().
    enforce(setenv(toStringz(name), toStringz(value), overwrite) == 0,
        "Invalid environment variable name '"~name~"'");
}


/** Remove the environment variable with the given name.
    If the variable does not exist in the environment, this
    function succeeds without changing the environment.
*/
version(Posix) void unsetEnv(string name)
{
    enforce(unsetenv(toStringz(name)) == 0,
        "Invalid environment variable name '"~name~"'");
}


// Unittest for getEnv(), setEnv(), and unsetEnv()
unittest
{
    // New variable
    setEnv("foo", "bar", true);
    assert (getEnv("foo") == "bar");

    // Overwrite variable
    setEnv("foo", "baz", true);
    assert (getEnv("foo") == "baz");

    // Do not overwrite variable
    setEnv("foo", "bax", false);
    assert (getEnv("foo") == "baz");

    // Unset variable
    unsetEnv("foo");
    assert (getEnv("foo") == null);

    // Check that exceptions are thrown when they should be.
    try { setEnv("foo=bar", "baz", true); assert(false); } catch(Exception e) {}
    try { unsetEnv("foo=bar"); assert(false); } catch(Exception e) {}
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
    auto env = getEnv();
    assert (env["PATH"] == to!string(getenv("PATH")));
}
