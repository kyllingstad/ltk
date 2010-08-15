/** Communication with the environment in which the program runs.

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad. All rights reserved.
    License:    Boost License 1.0
*/
module ltk.system;


import core.stdc.string;

import std.exception;
import std.conv;
import std.string;
import std.typecons;

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




version(Posix)
{
    // Made available by the C runtime:
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
}




// This struct provides an AA-like interface for reading/writing
// environment variables.
struct Environment
{
static:
    // Return the length of an environment variable (in number of
    // wchars, including the null terminator), 0 if it doesn't exist.
    version(Windows)
    private int varLength(LPCWSTR namez)
    {
        return GetEnvironmentVariableW(namez, null, 0);
    }



    // Retrieve an environment variable, null if not found.
    string opIndex(string name)
    {
        version(Posix)
        {
            const valuez = core.sys.posix.stdlib.getenv(toStringz(name));
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
    string opIndexAssign(string value, string name)
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
    void remove(string name)
    {
        version(Posix)
        {
            core.sys.posix.stdlib.unsetenv(toStringz(name));
        }

        else version(Windows)
        {
            SetEnvironmentVariableW(toUTF16z(name), null);
        }

        else static assert(0);
    }



    // Same as opIndex, except return a default value if
    // the variable doesn't exist.
    string get(string name, string defaultValue)
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
            for (int i=0; environ[i] != null; ++i)
            {
                immutable varDef = to!string(environ[i]);
                immutable eq = varDef.indexOf('=');
                assert (eq >= 0);
                
                immutable name = varDef[0 .. eq];
                immutable value = varDef[eq+1 .. $];

                // In POSIX, environment variables may be defined more
                // than once.  This is a security issue, which we avoid
                // by checking whether the key already exists in the array.
                // For more info:
                // http://www.dwheeler.com/secure-programs/Secure-Programs-HOWTO/environment-variables.html
                if (name !in aa)  aa[name] = value;
            }
        }

        else version(Windows)
        {
            auto envBlock = GetEnvironmentStringsW();
            enforce (envBlock, "Failed to retrieve environment variables.");
            scope(exit) FreeEnvironmentStringsW(envBlock);

            for (int i=0; envBlock[i] != '\0'; ++i)
            {
                auto start = i;
                while (envBlock[i] != '=')
                {
                    assert (envBlock[i] != '\0');
                    ++i;
                }
                immutable name = toUTF8(envBlock[start .. i]);

                start = i+1;
                while (envBlock[i] != '\0') ++i;
                aa[name] = toUTF8(envBlock[start .. i]);
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

    // Iterate over all environment variable names and values
    foreach (var; environment[]) writefln("%s=%s", var.name, var.value);

    // Iterate over variable names and values separately
    foreach (name; environment.byName())   writeln(name);
    foreach (value; environment.byValue()) writeln(value);

    // Return an associative array of type string[string] containing
    // all the environment variables.
    auto aa = environment.toAA();
    ---
*/
//Environment environment;
alias Environment environment;


unittest
{
    // New variable
    environment["std_process"] = "foo";
    assert (environment["std_process"] == "foo");

    // Set variable again
    environment["std_process"] = "bar";
    assert (environment["std_process"] == "bar");

    // Remove variable
    environment.remove("std_process");
    assert (environment["std_process"] == null);

    // Remove again, should succeed
    environment.remove("std_process");

    // get() with default value
    assert (environment.get("std_process", "baz") == "baz");

    // Convert to associative array. Also tests ranges.
    auto aa = environment.toAA();
    assert (aa.length > 0);
    foreach (n, v; aa)
    {
        // Due to what seems to be a bug in the Wine cmd shell,
        // sometimes there is an environment variable with an empty
        // name, which GetEnvironmentVariable() refuses to retrieve.
        version(Windows)  if (n.length == 0) continue;

        assert (v == environment[n]);
    }
}
