/** Communication with the environment in which the program runs.

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad. All rights reserved.
    License:    Boost License 1.0
*/
module ltk.system;


import core.stdc.string;

// setenv() and unsetenv() are POSIX-specific.
version (Windows)
{
    import core.sys.windows.windows;
    import std.utf: toUTF16z;
    import std.windows.syserror;
}
version (Posix) import core.sys.posix.stdlib;
else import core.stdc.stdlib;

import std.exception;
import std.conv;
import std.string;


// Some sources say this is supposed to be defined in unistd.h,
// but the POSIX spec doesn't mention it:
version(Posix)
{
    private extern(C) extern __gshared const char** environ;
}


// TODO: This should be in druntime!
version(Windows)
{
    extern(Windows)
    {
        LPTCH GetEnvironmentStrings();
        DWORD GetEnvironmentVariableW(LPCWSTR lpName, LPWSTR lpBuffer,
            DWORD nSize);
        BOOL SetEnvironmentVariableW(LPCWSTR lpName, LPCWSTR lpValue);
    }
    enum ERROR_ENVVAR_NOT_FOUND = 203;
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




// Check whether an environment variable exists.
version(Windows) private bool envExists(LPCWSTR namez)
{
    return GetEnvironmentVariableW(namez, null, 0) != 0;
}



/** Set the _value of the environment variable name to value. */
void setEnv(string name, string value, bool overwrite)
{
    version(Posix)
    {
        // errno message not very informative, hence not use errnoEnforce().
        enforce(
            setenv(toStringz(name), toStringz(value), overwrite) == 0,
            "Invalid environment variable name '"~name~"'"
        );
    }

    else version(Windows)
    {
        auto namez = toUTF16z(name);
        if (!overwrite && envExists(namez)) return;

        enforce(
            SetEnvironmentVariableW(namez, toUTF16z(value)),
            sysErrorString(GetLastError())
        );
    }

    else static assert(0);
}




/** Remove the environment variable with the given name.
    If the variable does not exist in the environment, this
    function succeeds without changing the environment.
*/
void unsetEnv(string name)
{
    version(Posix)
    {
        enforce(
            unsetenv(toStringz(name)) == 0,
            "Invalid environment variable name '"~name~"'"
        );
    }

    else version(Windows)
    {
        auto namez = toUTF16z(name);
        if (envExists(namez))  enforce(
            SetEnvironmentVariableW(namez, null),
            sysErrorString(GetLastError())
        );
    }

    else static assert(0);
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

    // Unset variable again (should succeed)
    unsetEnv("foo");

    // Check that exceptions are thrown when they should be.
    try { setEnv("foo=bar", "baz", true); assert(false); } catch(Exception e) {}
}




/** Return an associative array containing (copies of) all the
    process' environment variables.
*/
string[string] getEnv()
{
    string[string] envArray;

    version(Posix)
    {
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
    }

    else version(Windows)
    {
        auto envDefz = GetEnvironmentStrings;

        string key = null;
        int i = 0;
        bool parsingKey = true;
        for (int j=0; ; ++j)
        {
            if (envDefz[j] == '=' && parsingKey)
            {
                key = envDefz[i .. j].idup;
                i = j+1;
                parsingKey = false;
            }
            else if (envDefz[j] == '\0')
            {
                assert (!parsingKey && key.length > 0);
                envArray[key] = envDefz[i .. j].idup;

                key = null;
                i = j+1;
                parsingKey = true;

                if (envDefz[i] == '\0') break; // End of environment block.
            }
        }
    }

    return envArray;
}


unittest
{
    auto env = getEnv();
    assert (env["PATH"] == to!string(getenv("PATH")));
}
