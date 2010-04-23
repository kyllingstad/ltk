/** This module is used to parse file names. All the operations work
    only on strings; they don't perform any input/output operations.
    This means that if a path contains a directory name with a dot,
    functions like extension() will work with it just as if it was a file.
    To differentiate these cases, use the std.file module first (i.e.
    std.file.isDir()).

    The module supports both Windows and POSIX paths, and all the functions
    are therefore placed inside the Path template, which takes an identifier
    determining the operating system.  The appropriate
    version of this template is mixed into the module scope, so if you're
    on Windows, you don't have to call Path!Windows.foo(), you can just call
    foo() directly.

    The benefit of this is that if you are on Windows and need to manipulate
    POSIX paths -- for an FTP client, say -- then the POSIX path functions
    are still available through the Path!Posix template.
    ---
    // On Windows:
    getDirectory("c:\\foo\\bar.txt")         -->  "c:\\foo"
    Path!Posix.getDirectory("/foo/bar.txt")  -->  "/foo"
    ---
*/
module ltk.path;


import std.contracts;
import std.file;
import std.path;




enum { Windows, Posix }



///
template Path(int OS)  if (OS == Windows || OS == Posix)
{
    private enum : bool
    {
        windows = (OS == Windows),
        posix   = (OS == Posix)
    }

    /** String used to separate directory names in a path.  Under
        Windows this is a backslash, under POSIX a slash.
    */
    static if (windows) immutable string dirSeparator = "\\";
    static if (posix)   immutable string dirSeparator = "/";


    /** Alternate version of dirSeparator used in Windows (a slash).
        Under Posix, this is the same as dirSeparator.
    */
    static if (windows) immutable string altDirSeparator = "/";
    static if (posix)   immutable string altDirSeparator = dirSeparator;


    /** Path separator string.  A semicolon under Windows, a colon
        under POSIX.
    */
    static if (windows) immutable string pathSeparator = ";";
    static if (posix)   immutable string pathSeparator = ":";


    /** String representing the current directory.  A dot under
        both Windows and POSIX.
    */
    immutable string currentDir = ".";


    /** String representing the parent directory.  A double dot under
        both Windows and POSIX.
    */
    immutable string parentDir = "..";




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



    // Return the position of the filename/extension separator dot
    // in path.  If not found, return -1.
    private int extSepPos(string path)
    {
        int i = path.length - 1;

        static if (windows)
        {
            while (i >= 0 && path[i] != dirSeparator[0] && path[i] != ':')
            {
                if (path[i] == '.')  return i;
                i--;
            }
        }

        else static if (posix)
        {
            while (i >= 0 && path[i] != dirSeparator[0])
            {
                if (path[i] == '.' && i != 0 && path[i-1] != dirSeparator[0])
                    return i;
                i--;
            }
        }

        return -1;
    }
}


version(Posix)   mixin Path!Posix;
version(Windows) mixin Path!Windows;



// UNIT TESTS

// extension()
unittest
{
    with (Path!Windows)
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

    with (Path!Posix)
    {
        assert (extension("foo.bar") == "bar");
        assert (extension(".foo") == "");
        assert (extension("foo.") == "");
        assert (extension("dir/foo.bar") == "bar");
        assert (extension("dir/.foo") == "");
        assert (extension("dir/foo.") == "");
    }
}

// removeExtension()
unittest
{
    with (Path!Windows)
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

    with (Path!Posix)
    {
        assert (removeExtension("foo.bar") == "foo");
        assert (removeExtension(".foo") == ".foo");
        assert (removeExtension("foo.") == "foo");
        assert (removeExtension("dir/foo.bar") == "dir/foo");
        assert (removeExtension("dir/.foo") == "dir/.foo");
        assert (removeExtension("dir/foo.") == "dir/foo");
    }
}







// NO WINDOWS VERSIONS YET:


/*  Convert a relative path to an absolute path.  This means
    that if the path doesn't start with a slash, it is appended
    to the current working directory.
*/
version(Posix)  string toAbsolute(string path)
{
    if (path == null)  return null;
    if (path[0 .. sep.length] == sep)  return path;
    return join(getcwd(), path);
}

    

/*  Convert a relative path to a canonical path.  This means:
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
