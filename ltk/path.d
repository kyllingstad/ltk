/** This module is used to parse file names. All the operations work
    only on strings; they don't perform any input/output operations.
    This means that if a path contains a directory name with a dot,
    functions like extension() will work with it just as if it was a file.
    To differentiate these cases, use the std.file module first (i.e.
    std.file.isDir()).
*/
module ltk.path;


import std.contracts;
import std.ctype;
import std.file;
import std.path;
import std.string;




/** String used to separate directory names in a path.  Under
    POSIX this is a slash, under Windows a backslash.
*/
version(Posix)   immutable string dirSeparator = "/";
version(Windows) immutable string dirSeparator = "\\";


/** Alternate version of dirSeparator used in Windows (a slash).
    Under POSIX, this is the same as dirSeparator.
*/
version(Posix)   immutable string altDirSeparator = dirSeparator;
version(Windows) immutable string altDirSeparator = "/";


/** Path separator string.  A colon under POSIX, a semicolon
    under Windows.
*/
version(Posix)   immutable string pathSeparator = ":";
version(Windows) immutable string pathSeparator = ";";


/** String representing the current directory.  A dot under
    both POSIX and Windows.
*/
immutable string currentDirSymbol = ".";


/** String representing the parent directory.  A double dot under
    both POSIX and Windows.
*/
immutable string parentDirSymbol = "..";




/** Returns the name of a file, without any leading directory
    and with an optional suffix chopped off.

    ---
    basename("file.ext")                -->  "file.ext"
    basename("file.ext", ".ext")        -->  "file"
    basename("dir/file.ext")            -->  "file.ext"
    basename("dir/file.ext", ".ext")    -->  "file"
    basename("dir/subdir/")             -->  "subdir"

    // Windows only:
    basename("dir\\file.ext")           -->  "file.ext"
    basename("d:file.ext")              -->  "file.ext"
    basename("dir\\file.ext", ".ext")   -->  "file"
    basename("d:file.ext", ".ext")      -->  "file"
    basename("dir\\subdir\\")           -->  "subdir"
    ---
*/
string basename(string path, string suffix=null)
{
    path = chompSlashes(path);
    auto i = lastSlashPos(path);
    return chomp(path[i+1 .. $], suffix);
}


unittest
{
    assert (basename("file.ext") == "file.ext");
    assert (basename("file.ext", ".ext") == "file");
    assert (basename("dir/file.ext") == "file.ext");
    assert (basename("dir/file.ext", ".ext") == "file");
    assert (basename("dir/subdir/") == "subdir");

    version (Windows)
    {
    assert (basename("dir\\file.ext") == "file.ext");
    assert (basename("dir\\file.ext", ".ext") == "file");
    assert (basename("d:file.ext") == "file.ext");
    assert (basename("d:file.ext", ".ext") == "file");
    assert (basename("dir\\subdir\\") == "subdir");
    }
}




/** Returns the directory part of a path.  On Windows, this
    includes the drive letter if present.

    ---
    dirname("file")             -->  "."
    dirname("dir/")             -->  "."
    dirname("dir/file")         -->  "dir"
    dirname("dir///file")       -->  "dir"
    dirname("/file")            -->  "/"
    dirname("dir/subdir/")      -->  "dir"

    // Windows only:
    dirname("dir\\")            -->  "."
    dirname("dir\\\\\\file")    -->  "dir"
    dirname("d:file")           -->  "d:"
    dirname("d:\\file")         -->  "d:\\"
    dirname("dir\\subdir\\")    -->  "dir"
    ---
*/
string dirname(string path)
{
    path = chompSlashes(path);
    int i = lastSlashPos(path);

    if (i == -1) return currentDirSymbol;   // No dir
    if (i == 0) return path[0 .. i+1];      // Root dir

    version (Windows)
    {
        // If the directory part is either d: or d:\, don't
        // chop off the last symbol.
        if (path[i] == ':' || path[i-1] == ':')  return path[0 .. i+1];
    }

    // Remove any remaining trailing slashes.  (We do this
    // because "dir//file" is equivalent to "dir/file", and
    // we want both to return "dir".
    return chompSlashes(path[0 .. i]);
}


unittest
{
    assert (dirname("file") == ".");
    assert (dirname("dir/") == ".");
    assert (dirname("dir/file") == "dir");
    assert (dirname("dir///file") == "dir");
    assert (dirname("/file") == "/");
    assert (dirname("dir/subdir/") == "dir");

    version (Windows)
    {
    assert (dirname("dir\\") == ".");
    assert (dirname("dir\\file") == "dir");
    assert (dirname("dir\\\\\\file") == "dir");
    assert (dirname("d:file") == "d:");
    assert (dirname("d:\\file") == "d:\\");
    assert (dirname("dir\\subdir\\") == "dir");
    }
}




/** Returns the drive letter (including the colon) of a path, or
    an empty string if there is no drive letter.
    Always returns an empty string on POSIX.
    ---
    drivename("dir\\file")  -->  ""
    drivename("d:file")     -->  "d:"
    drivename("d:\\file")   -->  "d:"
    ---
*/
string drivename(string path)
{
    version (Windows)
    {
        path = stripl(path);
        if (path.length > 2  &&  path[1] == ':')  return path[0 .. 2];
    }
    return null;
}


unittest
{
    version (Posix)  assert (drivename("c:/foo") == null);
    version (Windows)
    {
    assert (drivename("dir\\file") == null);
    assert (drivename("d:file") == "d:");
    assert (drivename("d:\\file") == "d:");
    }
}




/*  Return the position of the last dir separator in path,
    -1 if none found.  On Windows, this includes the colon
    after the drive letter.
*/
private int lastSlashPos(string path)
{
    int i = path.length - 1;
    for (; i >= 0; i--)
    {
        version (Posix)
            if (path[i] == '/')
                break;

        version (Windows)
            if (path[i] == '\\' || path[i] == ':' || path[i] == '/')
                break;
    }
    return i;
}




/*  Strip trailing (back)slashes from path. */
private string chompSlashes(string path)
{
    int i = path.length - 1;
    version (Posix)   while (path[i] == '/')  i--;
    version (Windows) while (path[i] == '\\' || path[i] =='/')  i--;
    return path[0 .. i+1];
}


unittest
{
    assert (chompSlashes("foo") == "foo");
    assert (chompSlashes("foo/") == "foo");
    assert (chompSlashes("foo///") == "foo");

    version (Windows)
    {
    assert (chompSlashes("foo\\") == "foo");
    assert (chompSlashes("foo\\\\\\") == "foo");
    }
}




/** Determines whether the given string is a valid path.
    Note that this function only checks whether the path is
    well-formed, and does NOT check whether it exists.

    On POSIX, the only character that is disallowed in filenames
    is the null character.

    On Windows, the following rules apply:
    $(UL
        $(LI If the second character is a colon, the first character
            (the drive letter) must be an alphanumeric character.)
        $(LI Characters in the range 0x0-0x1f are not allowed.)
        $(LI The characters "*<>?| are not allowed, and : is only
            allowed following the drive letter.)
        $(LI The space and the period are not allowed as the final
            character.)
    )
    Source: $(LINK2 http://en.wikipedia.org/wiki/Filename,Wikipedia: Filename)
*/
version (Posix)  bool isValid(string path)
{
    foreach (c; path)  if (c == '\0') return false;
    return true;
}


version (Windows)  bool isValid(string path)
{
    // Does the path start with a drive letter?
    if (path.length > 2  &&  path[1] == ':')
    {
        // Drive letters must be alphanumeric.
        if (!isalnum(path[0])) return false;
        path = path[2 .. $];
    }

    // Space and period are not allowed as the final
    // character of a filename.
    if (path[$-1] == ' '  ||  path[$-1] == '.') return false;

    immutable reservedChars = "\"*:<>?|";
    foreach (c; path)
    {
        if (cast(int) c <= 0x1F) return false;
        foreach (r; reservedChars)
            if (c == r) return false;
    }

    return true;
}


unittest
{
    assert (isValid("foo bar"));
    assert (!isValid("foo\0bar"));

    version(Windows)
    {
    assert (isValid("d:foo"));
    assert (!isValid("&:foo"));
    assert (!isValid(":foo"));
    assert (!isValid("foo*.bar"));
    assert (!isValid("foo?bar"));
    assert (!isValid("foo."));
    }
}




/** Determines whether a path is absolute or relative.

    isRelative() is just defined as !isAbsolute(), with the
    notable exception that both functions return false if
    path is an empty string.

    On POSIX, an absolute path starts at the root directory,
    i.e. it starts with a slash (/).
    ---
    assert (isRelative("foo"));
    assert (isRelative("../foo"));
    assert (isAbsolute("/"));
    assert (isAbsolute("/foo"));
    ---

    On Windows, an absolute path starts at the root directory of
    a specific drive.  Hence, it must start with "d:\", where d
    is the drive letter.
    ---
    assert (isRelative("\\"));
    assert (isRelative("\\foo"));
    assert (isRelative("d:foo"));
    assert (isAbsolute("d:\\"));
    assert (isAbsolute("d:\\foo"));
    ---
*/
version (Posix)  bool isAbsolute(string path)
{
    if (path == null)  return false;
    return (path[0] == '/');
}

version (Windows)  bool isAbsolute(string path)
{
    return (path.length >= 3
        &&  path[1] == ':'
        && (path[2] == '\\' || path[2] == '/'));
}

/// ditto
bool isRelative(string path)
{
    if (path == null)  return false;
    return !isAbsolute(path);
}


unittest
{
    assert (isRelative("foo"));
    assert (isRelative("../foo"));

    version (Posix) 
    {
    assert (isAbsolute("/"));
    assert (isAbsolute("/foo"));
    }

    version (Windows)
    {
    assert (isRelative("\\"));
    assert (isRelative("\\foo"));
    assert (isRelative("d:foo"));
    assert (isAbsolute("d:\\"));
    assert (isAbsolute("d:\\foo"));
    }
}




/** Translate path into an absolute _path.  This means:
    $(UL
        $(LI If path is empty, return an empty string.)
        $(LI If path is already absolute, return it.)
        $(LI Otherwise, append path to the current working
            directory and return the result.)
    )
*/
string toAbsolute(string path)
{
    if (path == null)  return null;
    if (isAbsolute(path))  return path;
    return join(getcwd(), path);
}




/** Convert a relative path to a canonical path.  In addition to
    performing the same operations as toAbsolute(), this function
    does the following:

    On POSIX,
    $(UL
        $(LI trailing slashes are removed)
        $(LI multiple consecutive slashes are reduced to just one)
        $(LI ./ and ../ are resolved)
    )
    On Windows,
    $(UL
        $(LI slashes are replaced with backslashes)
        $(LI trailing backslashes are removed)
        $(LI multiple consecutive backslashes are reduced to just one)
        $(LI .\ and ..\ are resolved)
    )
*/
version(Posix)  string toCanonical(string path)
{
    if (path == null) return null;

    // Get absolute path
    auto apath = cast(char[]) toAbsolute(path);
    assert (!overlap(path, apath));

    // auto canon = apath.dup;
    alias apath canon;

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
            if (prev == doubleDot && j>0)
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




// Check whether two arrays overlap.
bool overlap(T, U)(const T[] a, const U[] b)
{
    auto av = cast(void[]) a;
    auto bv = cast(void[]) b;

    if (av.ptr <= bv.ptr)
    {
        return av.ptr + av.length > bv.ptr;
    }
    else
    {
        return bv.ptr + bv.length > av.ptr;
    }
}


unittest
{
    int[4] a;
    assert (overlap(a, a));
    assert (overlap(a[0 .. 2], a[1 .. 3]));
    assert (overlap(a[1 .. 3], a[0 .. 2]));
    assert (!overlap(a[0 .. 2], a[2 .. 4]));
    assert (!overlap(a[2 .. 4], a[0 .. 2]));

    union U { float[6] f; double[3] d; }
    U u;
    assert (overlap(u.f, u.d));
    assert (overlap(u.f[0 .. 2], u.d[0 .. 2]));
    assert (!overlap(u.f[0 .. 4], u.d[2 .. 3]));
}



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
    assert (extension("foo") == "");
    assert (extension("dir/foo.bar") == "bar");
    assert (extension("dir/foo") == "");

    version (Posix)
    {
    assert (extension(".foo") == "");
    assert (extension("dir/.foo") == "");
    }

    version(Windows)
    {
    assert (extension(".foo") == "foo");
    assert (extension("dir\\foo.bar") == "bar");
    assert (extension("dir\\.foo") == "foo");
    assert (extension("dir\\foo") == "");
    assert (extension("d:foo.bar") == "bar");
    assert (extension("d:.foo") == "foo");
    assert (extension("d:foo") == "");
    }
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
    assert (removeExtension("foo") == "foo");
    assert (removeExtension("dir/foo.bar") == "dir/foo");
    assert (removeExtension("dir/foo") == "dir/foo");

    version (Posix)
    {
    assert (removeExtension(".foo") == ".foo");
    assert (removeExtension("dir/.foo") == "dir/.foo");
    }

    version (Windows)
    {
    assert (removeExtension(".foo") == "");
    assert (removeExtension("dir\\foo.bar") == "dir\\foo");
    assert (removeExtension("dir\\.foo") == "dir\\");
    assert (removeExtension("dir\\foo") == "dir\\foo");
    assert (removeExtension("d:foo.bar") == "d:foo");
    assert (removeExtension("d:.foo") == "d:");
    assert (removeExtension("d:foo") == "d:foo");
    }
}



// Return the position of the filename/extension separator dot
// in path.  If not found, return -1.
private int extSepPos(string path)
{
    int i = path.length - 1;

    version(Windows)
    {
        while (i >= 0 && path[i] != dirSeparator[0] && path[i] != ':')
        {
            if (path[i] == '.')  return i;
            i--;
        }
    }

    else version(Posix)
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
