module ltk.path;


import std.contracts;
import std.file;
import std.path;




// PosixPath and WindowsPath have the same members.  Doc comments for
// all of them are in WindowsPath.

///
struct PosixPath
{
static:
    immutable dirSeparator = "/";
    alias dirSeparator altDirSeparator;
    immutable pathSeparator = ":";
    immutable currentDir = ".";
    immutable parentDir = "..";



    string extension(string path)
    {
        int i = extSepPos(path);
        if (i == -1) return null;
        return path[i+1 .. $];
    }

    unittest
    {
        assert (extension("foo.bar") == "bar");
        assert (extension(".foo") == "");
        assert (extension("foo.") == "");
        assert (extension("dir/foo.bar") == "bar");
        assert (extension("dir/.foo") == "");
        assert (extension("dir/foo.") == "");
    }


    string removeExtension(string path)
    {
        int i = extSepPos(path);
        if (i == -1) return path;
        return path[0 .. i];
    }

    unittest
    {
        assert (removeExtension("foo.bar") == "foo");
        assert (removeExtension(".foo") == ".foo");
        assert (removeExtension("foo.") == "foo");
        assert (removeExtension("dir/foo.bar") == "dir/foo");
        assert (removeExtension("dir/.foo") == "dir/.foo");
        assert (removeExtension("dir/foo.") == "dir/foo");
    }

    private int extSepPos(string path)
    {
        int i = path.length - 1;

        while (i >= 0 && path[i] != dirSeparator[0])
        {
            if (path[i] == '.' && i != 0 && path[i-1] != dirSeparator[0])
                return i;
            i--;
        }
        
        return -1;
    }
}




///
struct WindowsPath
{
static:
    /** String used to separate directory names in a path.  Under
        Windows this is a backslash, under POSIX a slash.
    */
    immutable dirSeparator = "\\";


    /** Alternate version of dirSeparator used in Windows (a slash).
        Under Posix, this just points to dirSeparator.
    */
    immutable altDirSeparator = "/";


    /** Path separator string.  A semicolon under Windows, a colon
        under POSIX.
    */
    immutable pathSeparator = ";";


    /** String representing the current directory.  A dot under
        both Windows and POSIX.
    */
    immutable currentDir = ".";


    /** String representing the parent directory.  A double dot under
        both Windows and POSIX.
    */
    immutable parentDir = "..";




    /** Get the extension of a file.

        This will search $(D path) from
        the end until the first dot, in which case it returns what's to
        the right of the dot, or until the first path separator, in
        which case it returns an empty string (meaning the file has no
        extension).
        
        Examples:
        ---
        // POSIX:
        extension("/tmp/foo.bar")   // "bar"
        extension("/tmp/foo")       // ""
        extension("/tmp/.bar")      // ""  -- The dot denotes a hidden file,
                                    //        not an extension.
        extension("/tmp/.foo.bar")  // "bar"

        // Windows:
        extension("d:\\temp\\foo.bar")  // "bar"
        extension("d:\\temp\\foo")      // ""
        extension("d:\\temp\\.bar")     // "bar"
        ---
    */
    string extension(string path)
    {
        int i = extSepPos(path);
        if (i == -1) return null;
        return path[i+1 .. $];
    }

    unittest
    {
        assert (extension("foo.bar") == "bar");
        assert (extension(".foo") == "foo");
        assert (extension("foo.") == "");
        assert (extension("dir\\foo.bar") == "bar");
        assert (extension("dir\\.foo") == "foo");
        assert (extension("dir\\foo.") == "");
        assert (extension("d:foo.bar") == "bar");
        assert (extension("d:.foo") == "foo");
        assert (extension("d:foo.") == "");
    }


    /** Strip the extension from a path.
        Follows the same rules as extension().
        
        Examples:
        ---
        // POSIX:
        extension("/tmp/foo.bar")   // "/tmp/foo"
        extension("/tmp/.bar")      // "/tmp/.bar"
        extension("/tmp/.foo.bar")  // "/tmp/.foo"

        // Windows:
        extension("d:\\temp\\foo.bar")  // "d:\\temp\\foo"
        extension("d:\\temp\\.bar")     // "d:\\temp\\"
        ---
    */
    string removeExtension(string path)
    {
        int i = extSepPos(path);
        if (i == -1) return path;
        return path[0 .. i];
    }

    unittest
    {
        assert (removeExtension("foo.bar") == "foo");
        assert (removeExtension(".foo") == "");
        assert (removeExtension("foo.") == "foo");
        assert (removeExtension("dir\\foo.bar") == "dir\\foo");
        assert (removeExtension("dir\\.foo") == "dir\\");
        assert (removeExtension("dir\\foo.") == "dir\\foo");
        assert (removeExtension("d:foo.bar") == "d:foo");
        assert (removeExtension("d:.foo") == "d:");
        assert (removeExtension("d:foo.") == "d:foo");
    }



    // Return the position of the filename/extension separator dot
    // in path.  If not found, return -1.
    private int extSepPos(string path)
    {
        int i = path.length - 1;

        while (i >= 0 && path[i] != dirSeparator[0] && path[i] != ':')
        {
            if (path[i] == '.')  return i;
            i--;
        }

        return -1;
    }
}




version(Posix)   private alias PosixPath   CurrentPath;
version(Windows) private alias WindowsPath CurrentPath;

immutable dirSeparator = CurrentPath.dirSeparator;
immutable altDirSeparator = CurrentPath.altDirSeparator;
immutable pathSeparator = CurrentPath.pathSeparator;
immutable currentDir = CurrentPath.currentDir;
immutable parentDir = CurrentPath.parentDir;

alias CurrentPath.extension extension;




/** Convert a relative path to an absolute path.  This means
    that if the path doesn't start with a slash, it is appended
    to the current working directory.
*/
version(Posix)  string toAbsolute(string path)
{
    if (path == null)  return null;
    if (path[0 .. sep.length] == sep)  return path;
    return join(getcwd(), path);
}

    

/** Convert a relative path to a canonical path.  This means:
    $(UL
        $(LI the path is made absolute (starts at root level))
        $(LI trailing slashes are removed)
        $(LI multiple consecutive slashes are removed)
        $(LI ./ and ../ are resolved)
    )
*/
version(Posix)  string toCanonical(string path)
{
    if (path == null) return null;

    // Get absolute path
    auto apath = cast(char[]) toAbsolute(path);
    if (apath.ptr == path.ptr)  apath = apath.dup;
    alias apath canon;
    // auto canon = apath.dup;

    enum { singleDot, doubleDot, dirSep, other }
    int prev = other;

    int j = 0;
    for (int i=0; i<=apath.length; i++, j++)
    {
        // At directory separator or end of path
        if (i == apath.length || apath[i] == sep[0])
        {
            if (prev == singleDot || prev == doubleDot)
            {
                // Backtrack to last dir separator
                while (canon[--j] != sep[0])  { }
            }
            if (prev == doubleDot)
            {
                enforce(j > 0, "Invalid path (too many ../)");
                // Backtrack once again
                while (canon[--j] != sep[0])  { }
            }
            if (prev == dirSep)  --j;
            prev = dirSep;
        }

        // At period
        else if (apath[i] == '.')
        {
            if (prev == dirSep)         prev = singleDot;
            else if (prev == singleDot) prev = doubleDot;
            else                        prev = other;
        }

        // At anything else
        else prev = other;

        if (i < apath.length) canon[j] = apath[i];
    }

    if (j == 1)  j = 2; // Include root

    return cast(immutable(char)[]) canon[0 .. j-1];
}
