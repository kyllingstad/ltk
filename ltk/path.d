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




/*  Helper function that determines whether the given character is a
    directory separator.  On Windows, this includes both '\' and '/'.
    On POSIX, it's just '/'.
*/
private bool isDirSeparator(char c)
{
    if (c == '/') return true;
    version(Windows) if (c == '\\') return true;
    return false;
}



/*  Helper function that, on Windows, determines whether the given
    character is the colon character that separates the drive
    letter from the rest of the path.  On POSIX, this always
    returns false.
*/
private bool isDriveSeparator(char c)
{
    version(Windows) return c == ':';
    else return false;
}




/*  Helper function that determines the position of the last
    directory separator in a string.  Returns -1 if none is found.
*/
private int lastSeparator(in char[] path)
{
    int i = path.length - 1;
    while (i >= 0 && !isDirSeparator(path[i]) && !isDriveSeparator(path[i]))
        --i;
    return i;
}




/*  Helper function that strips trailing slashes and backslashes
    from a path.
*/
private inout(char[]) chompDirSeparators(inout char[] path)
{
    int i = path.length - 1;
    while (i >= 0 && isDirSeparator(path[i])) --i;
    return path[0 .. i+1];
}




/*  Helper function that strips the drive designation from a
    Windows path.  On POSIX, this is a noop.
*/
private inout(char[]) removeDrive(inout char[] path)
{
    version(Windows)
        if (path.length >= 2 && isDriveSeparator(path[1])) return path[2 .. $];
    return path;
}




/** Returns the name of a file, without any leading directory
    and with an optional suffix chopped off.

    ---
    basename("file.ext")                -->  "file.ext"
    basename("file.ext", ".ext")        -->  "file"
    basename("dir/file.ext")            -->  "file.ext"
    basename("dir/file.ext", ".ext")    -->  "file"
    basename("dir/subdir/")             -->  "subdir"
    basename("/")                       -->  "/"

    // Windows only:
    basename( "d:file.ext")             -->  "file.ext"
    basename( "d:file.ext", ".ext")     -->  "file"
    basename(r"dir\file.ext")           -->  "file.ext"
    basename(r"dir\file.ext", ".ext")   -->  "file"
    basename(r"dir\subdir\")            -->  "subdir"
    basename(r"\")                      -->  "\"
    basename(r"d:\")                    -->  "\"
    ---
*/
inout(char[]) basename(inout char[] path, in char[] suffix=null)
{
    path = removeDrive(path);
    if (path.length == 0) return path;

    auto p = chompDirSeparators(path);

    // If this is the root directory, we return one of
    // the (back)slashes we just stripped off.  That is,
    // after all, its name.
    if (p.length == 0) return path[0 .. 1];

    auto i = lastSeparator(p);
    return std.string.chomp(p[i+1 .. $], suffix);
}


unittest
{
    assert (basename("file.ext") == "file.ext");
    assert (basename("file.ext", ".ext") == "file");
    assert (basename("dir/file.ext") == "file.ext");
    assert (basename("dir/file.ext", ".ext") == "file");
    assert (basename("dir/subdir/") == "subdir", basename("dir/subdir/"));
    assert (basename("/") == "/");

    version (Windows)
    {
    assert (basename("dir\\file.ext") == "file.ext");
    assert (basename("dir\\file.ext", ".ext") == "file");
    assert (basename("d:file.ext") == "file.ext");
    assert (basename("d:file.ext", ".ext") == "file");
    assert (basename("dir\\subdir\\") == "subdir");
    assert (basename("\\") == "\\");
    assert (basename("d:\\" == "d:\\"));
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
    dirname( "d:file")          -->  "d:"
    dirname(r"dir\")            -->  "."
    dirname(r"dir\\\file")      -->  "dir"
    dirname(r"d:\file")         --> r"d:\"
    dirname(r"dir\subdir\")     -->  "dir"
    ---
*/
inout(char[]) dirname(inout char[] path)
{
    auto p = chompDirSeparators(path);

    // If this is the root directory, return one of the
    // (back)slashes just stripped off.
    if (p.length == 0) return path[0 .. 1];

    int i = lastSeparator(p);
    if (i == -1) return cast(typeof(return)) ".";   // No dir
    if (i == 0) return p[0 .. i+1];                 // Root dir

    // If the directory part is either d: or d:\, don't
    // chop off the last symbol.
    if (isDriveSeparator(path[i]) || isDriveSeparator(path[i-1]))
        return path[0 .. i+1];

    // Remove any remaining trailing (back)slashes.  We do this
    // because "dir//file" is equivalent to "dir/file", and we
    // want to return "dir" in both cases.
    return chompDirSeparators(path[0 .. i]);
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
    drivename( "d:file")    -->  "d:"
    drivename(r"d:\file")   -->  "d:"
    drivename(r"dir\file")  -->  ""
    ---
*/
inout(char[]) drivename(inout char[] path)
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
private int lastSlashPos(in char[] path)
{
    int i = path.length - 1;
    for (; i >= 0; i--)
    {
        version (Posix)
            if (path[i] == '/')  break;

        version (Windows)
            if (path[i] == '\\' || path[i] == ':' || path[i] == '/')  break;
    }
    return i;
}




/*  Strip trailing (back)slashes from path. */
private inout(char[]) chompSlashes(inout char[] path)
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




/** Get the extension of a file.

    This will search $(D path) from
    the end until the first dot, in which case it returns what's to
    the right of the dot, or until the first path separator, in
    which case it returns an empty string (meaning the file has no
    extension).
    
    Examples:
    ---
    extension("/dir/file.ext")      -->  "ext"
    extension("/dir/file")          -->  ""
    extension("/dir/.file.ext")     -->  "ext"

    // POSIX only:
    extension("/dir/.file")         -->  ""     // The dot denotes a hidden
                                                // file, not an extension.

    // Windows only:
    extension(r"d:\dir\file.ext")  -->  "ext"
    extension(r"d:\dir\file")      -->  ""
    extension(r"d:\dir\.ext")      -->  "ext"
    ---
*/
inout(char[]) extension(inout char[] path)
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




// Return the position of the filename/extension separator dot
// in path.  If not found, return -1.
// This could be included in extension() but for now we keep it
// as a separate function in case we want more support for extensions
// later (such as removeExtension(), replaceExtension(), etc.).
private int extSepPos(in char[] path)
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




/** Joins two or more path components. */
string join(in char[] path1, in char[] path2, in char[][] more...)
{
    // More than two path components
    if (more.length > 0)
        return join(join(path1, path2), more[0], more[1 .. $]);

    // Exactly two path components
    if (path2.length == 0) return path1.idup;
    if (path1.length == 0) return path2.idup;
    if (isAbsolute(path2)) return path2.idup;

    if (isDirSeparator(path1[$-1]) || isDirSeparator(path2[0]))
        return cast(string)(path1 ~ path2);
    else
        return cast(string)(path1 ~ dirSeparator ~ path2);
}


unittest
{
    version (Posix)
    {
        assert (join("foo", "bar") == "foo/bar");
        assert (join("foo/", "bar") == "foo/bar");
        assert (join("foo///", "bar") == "foo///bar");
        assert (join("/foo", "bar") == "/foo/bar");
        assert (join("foo", "/bar") == "/bar");
        assert (join("foo", "bar/") == "foo/bar/");
        assert (join("/", "foo") == "/foo");
        assert (join("", "foo") == "foo");
        assert (join("foo", "") == "foo");
        assert (join("foo", "bar", "baz") == "foo/bar/baz");
        assert (join("foo", "/bar", "baz") == "/bar/baz");
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
    assert (isRelative(r"\"));
    assert (isRelative(r"\foo"));
    assert (isRelative( "d:foo"));
    assert (isAbsolute(r"d:\"));
    assert (isAbsolute(r"d:\foo"));
    ---
*/
version (Posix)  bool isAbsolute(in char[] path)
{
    if (path == null)  return false;
    return (path[0] == '/');
}

version (Windows)  bool isAbsolute(in char[] path)
{
    return (path.length >= 3
        &&  path[1] == ':'
        && (path[2] == '\\' || path[2] == '/'));
}

/// ditto
bool isRelative(in char[] path)
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
string toCanonical(string path)
{
    if (path == null) return null;

    // Get absolute path, and duplicate it to make sure we can
    // safely cast it to mutable below.
    auto immutablePath = toAbsolute(path).idup;

    // On Windows, skip drive designation.
    version (Windows)
        auto absolute = cast(char[]) immutablePath[2 .. $];
    version (Posix)
        auto absolute = cast(char[]) immutablePath;

    // When constructing the canonical path, we will overwrite
    // absolute.  This alias is to make the following code easier
    // to read.
    alias absolute canonical;

    enum { singleDot, doubleDot, dirSep, other }
    int prev = other;

    // i is the position in the absolute path,
    // j is the position in the canonical path.
    int j = 0;
    for (int i=0; i<=absolute.length; i++, j++)
    {
        // On Windows, replace slashes with backslashes.
        version (Windows)
        {
            if (i < absolute.length && absolute[i] == altDirSeparator[0])
                absolute[i] = dirSeparator[0];
        }

        // At directory separator or end of path.
        if (i == absolute.length || absolute[i] == dirSeparator[0])
        {
            if (prev == singleDot || prev == doubleDot)
            {
                // Backtrack to last dir separator
                while (canonical[--j] != dirSeparator[0])  { }
            }
            if (prev == doubleDot && j>0)
            {
                enforce(j > 0, "Invalid path (too many ..)");
                // Backtrack once again
                while (canonical[--j] != dirSeparator[0])  { }
            }
            if (prev == dirSep)  --j;
            prev = dirSep;
        }

        // At period
        else if (absolute[i] == '.')
        {
            if (prev == dirSep)         prev = singleDot;
            else if (prev == singleDot) prev = doubleDot;
            else                        prev = other;
        }

        // At anything else
        else prev = other;

        if (i < absolute.length) canonical[j] = absolute[i];
    }

    // If the directory turns out to be root, we do want a
    // trailing slash.
    if (j == 1)  j = 2;

    // On Windows, include drive designation again.
    version (Windows)  j++;
    version (Posix)    j--;

    return immutablePath[0 .. j];
}


unittest
{
    version (Posix)
    {
        string p1 = "foo/bar/baz";
        string p2 = "foo/boo/../bar/../../foo///bar/baz/";
        assert (toCanonical(p2) == toAbsolute(p1));
    }
    version (Windows)
    {
        string p1 = "foo\\bar\\baz";
        string p2 = "foo\\boo\\../bar\\..\\../foo\\/\\bar\\baz/";
        assert (toCanonical(p2) == toAbsolute(p1));
    }
}
