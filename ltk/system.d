/** Communication with the environment in which the program runs.

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad. All rights reserved.
    License:    Boost License 1.0
*/
module ltk.system;


import core.exception: RangeError;
import core.stdc.string;

import std.exception;
import std.conv;
import std.string;

version (Windows)
{
    import core.sys.windows.windows;
    import std.utf;
    import std.windows.syserror;
}

version (Posix)
{
    import core.stdc.errno;
    import core.sys.posix.stdlib;
}




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
        alias WCHAR* LPWCH;
        LPWCH GetEnvironmentStringsW();
        BOOL FreeEnvironmentStringsW(LPWCH lpszEnvironmentBlock);
        DWORD GetEnvironmentVariableW(LPCWSTR lpName, LPWSTR lpBuffer,
            DWORD nSize);
        BOOL SetEnvironmentVariableW(LPCWSTR lpName, LPCWSTR lpValue);
    }
    enum ERROR_ENVVAR_NOT_FOUND = 203;
}




// This struct provides an AA-like interface for reading/writing
// environment variables.
struct Environment
{
    // Return the length of an environment variable (in number of
    // wchars, including the null terminator), 0 if it doesn't exist.
    version(Windows)
    static private int varLength(LPCWSTR namez)
    {
        return GetEnvironmentVariableW(namez, null, 0);
    }



    // Retrieve an environment variable, null if not found.
    static string opIndex(string name)
    {
        version(Posix)
        {
            const valuez = getenv(toStringz(name));
            if (valuez == null) return null;
            auto value = valuez[0 .. strlen(valuez)];

            // Cache the last call's result.
            static string lastResult;
            if (value == lastResult) return lastResult;
            return lastResult = value.idup;
        }

        else version(Windows)
        {
            const namez = toUTF16z(name);
            immutable len = varLength(namez);
            if (len <= 1) return null;

            auto buf = new WCHAR[len];
            GetEnvironmentVariableW(namez, buf.ptr, buf.length);
            return toUTF8(buf[0 .. $-1]);
        }

        else static assert(0);
    }



    // Assign a value to an environment variable.  If the variable
    // exists, it is overwritten.
    static string opIndexAssign(string value, string name)
    {
        version(Posix)
        {
            if (core.sys.posix.stdlib.setenv(toStringz(name),
                toStringz(value), 1) != -1)
            {
                return value;
            }

            // The default errno error message is very uninformative
            // in the most common case, so we handle it manually.
            enforce(errno != EINVAL,
                "Invalid environment variable name: '"~name~"'");
            errnoEnforce(false,
                "Failed to add environment variable");
            assert(0);
        }

        else version(Windows)
        {
            enforce(
                SetEnvironmentVariableW(toUTF16z(name), toUTF16z(value)),
                sysErrorString(GetLastError())
            );
            return value;
        }

        else static assert(0);
    }



    // Remove an environment variable.  The function succeeds even
    // if the variable isn't in the environment.
    static void remove(string name)
    {
        version(Posix)
        {
            unsetenv(toStringz(name));
        }

        else version(Windows)
        {
            SetEnvironmentVariableW(toUTF16z(name), null);
        }

        else static assert(0);
    }



    // Same as opIndex, except return a default value if
    // the variable doesn't exist.
    static string get(string name, string defaultValue)
    {
        auto value = opIndex(name);
        return value ? value : defaultValue;
    }



    // Return all environment variables in an associative array.
    static string[string] toAA()
    {
        string[string] aa;

        version(Posix)
        {
            const(char)* envDefz;
            for (int i=0; (envDefz = environ[i]) != null; i++)
            {
                auto envDef = to!string(envDefz);
                auto eqPos = envDef.indexOf('=');
                if (eqPos == -1)  continue;

                auto key = envDef[0 .. eqPos];
                // In POSIX, environment variables may be defined more
                // than once.  This is a security issue, which we avoid
                // by checking whether the key already exists in the array.
                // For more info:
                // http://www.dwheeler.com/secure-programs/Secure-Programs-HOWTO/environment-variables.html
                if (key in aa)  continue;

                aa[key] = envDef[eqPos+1 .. $];
            }
        }

        else version(Windows)
        {
            auto envBlock = GetEnvironmentStringsW;
            scope(exit) FreeEnvironmentStringsW(envBlock);

            // Are there any variables at all?
            if (envBlock == null || envBlock[0] == '\0') return aa;

            string key = null;
            int i = 0;
            bool parsingKey = true;
            for (int j=0; ; ++j)
            {
                if (envBlock[j] == '=' && parsingKey)
                {
                    key = toUTF8(envBlock[i .. j]);
                    i = j+1;
                    parsingKey = false;
                }
                else if (envBlock[j] == '\0')
                {
                    assert (!parsingKey && key.length > 0);
                    aa[key] = toUTF8(envBlock[i .. j]);

                    key = null;
                    i = j+1;
                    parsingKey = true;

                    if (envBlock[i] == '\0') break; // End of environment block.
                }
            }
        }

        else static assert(0);

        return aa;
    }

}




/** Manipulates environment variables using an associative-array-like
    interface.

    Examples:
    ---
    // Read variable
    auto path = environment["PATH"];

    // Add/replace variable
    environment["foo"] = "bar";

    // Remove variable
    environment.remove("foo");

    // Return variable, providing a default value if variable doesn't exist
    auto foo = environment.get("foo", "default foo value");

    // Return an associative array of type string[string] containing
    // all the environment variables.
    auto aa = environment.toAA();
    ---
*/
Environment environment;


unittest
{
    // New variable
    environment["foo"] = "bar";
    assert (environment["foo"] == "bar");

    // Set variable again
    environment["foo"] = "baz";
    assert (environment["foo"] == "baz");

    // Remove variable
    environment.remove("foo");
    assert (environment["foo"] == null);

    // Remove again, should succeed
    environment.remove("foo");

    // get() with default value
    assert (environment.get("foo", "bar") == "bar");

    // Convert to associative array
    auto aa = environment.toAA();
    foreach (n, v; aa)
    {
        assert (v == environment[n]);
    }
}

