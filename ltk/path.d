// This module is currently not in a working state, so don't waste time
// trying to use it.

/** Proposal for a rewrite of
    $(LINK2 http://www.digitalmars.com/d/2.0/phobos/std_path.html,std._path).

    This module is used to parse file names. All the operations work
    only on strings; they don't perform any input/output operations.
    This means that if a path contains a directory name with a dot,
    functions like extension() will work with it just as if it was a file.
    To differentiate these cases, use the std.file module first (i.e.
    std.file.isDir()).
*/
module ltk.path;


import std.array;
import std.conv;
import std.ctype;
import std.exception;
import std.file;
import std.path;
import std.range;
import std.string;
import std.traits;




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
private bool isDirSeparator(dchar c)
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
private bool isDriveSeparator(dchar c)
{
    version(Windows) return c == ':';
    else return false;
}



/*  Combines the isDirSeparator and isDriveSeparator tests. */
version(Posix) private alias isDirSeparator isSeparator;
version(Windows) private bool isSeparator(dchar c)
{
    return isDirSeparator(c) || isDriveSeparator(c);
}





/*  Helper function that determines the position of the last
    drive/directory separator in a string.  Returns -1 if none
    is found.
*/
private int lastSeparator(C)(in C[] path)  if (isSomeChar!C)
{
    int i = path.length - 1;
    while (i >= 0 && !isSeparator(path[i])) --i;
    return i;
}




/*  Helper function that strips trailing slashes and backslashes
    from a path.
*/
private C[] chompDirSeparators(C)(C[] path)  if (isSomeChar!C)
{
    int i = path.length - 1;
    while (i >= 0 && isDirSeparator(path[i])) --i;
    return path[0 .. i+1];
}




/*  Helper function that strips the drive designation from a
    Windows path.  On POSIX, this is a noop.
*/
private C[] stripDrive(C)(C[] path)  if (isSomeChar!C)
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
    basename(r"\")                      -->  r"\"
    basename(r"d:\")                    -->  r"\"
    ---
*/
// This function is written so it adheres to the POSIX requirements
// for the 'basename' shell utility:
// http://pubs.opengroup.org/onlinepubs/9699919799/utilities/basename.html
C[] basename(C)(C[] path) if (isSomeChar!C)
{
    auto p1 = stripDrive(path);
    if (p1.length == 0) return null;

    auto p2 = chompDirSeparators(p1);
    if (p2.length == 0) return p1[0 .. 1];

    return p2[lastSeparator(p2)+1 .. $];
}

/// ditto
C[] basename(C, C1)(C[] path, C1[] suffix)  if (isSomeChar!C && isSomeChar!C1)
{
    auto p1 = basename(path);
    auto p2 = std.string.chomp(p1, suffix);
    if (p2.length == 0) return p1;
    else return p2;
}


unittest
{
    assert (basename("")                            == "");
    assert (basename("file.ext"w)                   == "file.ext");
    assert (basename("file.ext"d, ".ext")           == "file");
    assert (basename("file", "file"w.dup)           == "file");
    assert (basename("dir/file.ext"d.dup)           == "file.ext");
    assert (basename("dir/file.ext", ".ext"d)       == "file");
    assert (basename("dir/file"w, "file"d)          == "file");
    assert (basename("dir///subdir////")            == "subdir");
    assert (basename("dir/subdir.ext/", ".ext")     == "subdir");
    assert (basename("dir/subdir/".dup, "subdir")   == "subdir");
    assert (basename("/"w.dup)                      == "/");
    assert (basename("//"d.dup)                     == "/");
    assert (basename("///")                         == "/");

    version (Win32)
    {
    assert (basename("dir\\file.ext")               == "file.ext");
    assert (basename("dir\\file.ext", ".ext")       == "file");
    assert (basename("dir\\file", "file")           == "file");
    assert (basename("d:file.ext")                  == "file.ext");
    assert (basename("d:file.ext", ".ext")          == "file");
    assert (basename("d:file", "file")              == "file");
    assert (basename("dir\\\\subdir\\\\\\")         == "subdir");
    assert (basename("dir\\subdir.ext\\", ".ext")   == "subdir");
    assert (basename("dir\\subdir\\", "subdir")     == "subdir");
    assert (basename("\\")                          == "\\");
    assert (basename("\\\\")                        == "\\");
    assert (basename("\\\\\\")                      == "\\");
    assert (basename("d:\\")                        == "\\");
    assert (basename("d:")                          == "");
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
C[] dirname(C)(C[] path)  if (isSomeChar!C)
{
    // This function is written so it adheres to the POSIX requirements
    // for the 'dirname' shell utility:
    // http://pubs.opengroup.org/onlinepubs/9699919799/utilities/dirname.html

    if (path.length == 0) return to!(typeof(return))(".");

    auto p = chompDirSeparators(path);
    if (p.length == 0) return path[0 .. 1];
    if (p.length == 2 && isDriveSeparator(p[1]) && path.length > 2)
        return path[0 .. 3];

    int i = lastSeparator(p);
    if (i == -1) return to!(typeof(return))(".");
    if (i == 0) return p[0 .. 1];

    // If the directory part is either d: or d:\, don't
    // chop off the last symbol.
    if (isDriveSeparator(p[i]) || isDriveSeparator(p[i-1]))
        return p[0 .. i+1];

    // Remove any remaining trailing (back)slashes.
    return chompDirSeparators(p[0 .. i]);
}


unittest
{
    assert (dirname("")                 == ".");
    assert (dirname("file"w)            == ".");
    assert (dirname("dir/"d)            == ".");
    assert (dirname("dir///")           == ".");
    assert (dirname("dir/file"w.dup)    == "dir");
    assert (dirname("dir///file"d.dup)  == "dir");
    assert (dirname("dir/subdir/")      == "dir");
    assert (dirname("/dir/file"w)       == "/dir");
    assert (dirname("/file"d)           == "/");
    assert (dirname("/")                == "/");
    assert (dirname("///")              == "/");

    version (Windows)
    {
    assert (dirname("dir\\")            == ".");
    assert (dirname("dir\\\\\\")        == ".");
    assert (dirname("dir\\file")        == "dir");
    assert (dirname("dir\\\\\\file")    == "dir");
    assert (dirname("dir\\subdir\\")    == "dir");
    assert (dirname("\\dir\\file")      == "\\dir");
    assert (dirname("\\file")           == "\\");
    assert (dirname("\\")               == "\\");
    assert (dirname("\\\\\\")           == "\\");
    assert (dirname("d:file")           == "d:");
    assert (dirname("d:")               == "d:");
    assert (dirname("d:\\file")         == "d:\\");
    assert (dirname("d:\\")             == "d:\\");
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
C[] drivename(C)(C[] path)  if (isSomeChar!C)
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




/*  Helper function that returns the position of the filename/extension
    separator dot in path.  If not found, returns -1.
*/
private int extSeparatorPos(C)(in C[] path) if (isSomeChar!C)
{
    int i = path.length - 1;
    while (i >= 0 && !isSeparator(path[i]))
    {
        if (path[i] == '.' && i > 0 && !isSeparator(path[i-1])) return i;
        --i;
    }
    return -1;
}




/** Get the extension part of a file name.

    Examples:
    ---
    extension("file")               -->  ""
    extension("file.ext")           -->  "ext"
    extension("file.ext1.ext2")     -->  "ext2"
    extension(".file")              -->  ""
    extension(".file.ext")          -->  "ext"
    ---
*/
C[] extension(C)(C[] path)  if (isSomeChar!C)
{
    int i = extSeparatorPos(path);
    if (i == -1) return null;
    else return path[i+1 .. $];
}


unittest
{
    assert (extension("file") == "");
    assert (extension("file.ext"w) == "ext");
    assert (extension("file.ext1.ext2"d) == "ext2");
    assert (extension(".foo".dup) == "");
    assert (extension(".foo.ext"w.dup) == "ext");

    assert (extension("dir/file"d.dup) == "");
    assert (extension("dir/file.ext") == "ext");
    assert (extension("dir/file.ext1.ext2"w) == "ext2");
    assert (extension("dir/.foo"d) == "");
    assert (extension("dir/.foo.ext".dup) == "ext");

    version(Windows)
    {
    assert (extension("dir\\file") == "");
    assert (extension("dir\\file.ext") == "ext");
    assert (extension("dir\\file.ext1.ext2") == "ext2");
    assert (extension("dir\\.foo") == "");
    assert (extension("dir\\.foo.ext") == "ext");

    assert (extension("d:file") == "");
    assert (extension("d:file.ext") == "ext");
    assert (extension("d:file.ext1.ext2") == "ext2");
    assert (extension("d:.foo") == "");
    assert (extension("d:.foo.ext") == "ext");
    }
}




/** Return the file name without the extension.

    Examples:
    ---
    extension("file")               -->  "file"
    extension("file.ext")           -->  "file"
    extension("file.ext1.ext2")     -->  "file.ext1"
    extension(".file")              -->  ".file"
    extension(".file.ext")          -->  ".file"
    ---
*/
C[] stripExtension(C)(C[] path)  if (isSomeChar!C)
{
    int i = extSeparatorPos(path);
    if (i == -1) return path;
    else return path[0 .. i];
}


unittest
{
    assert (stripExtension("file") == "file");
    assert (stripExtension("file.ext"w) == "file");
    assert (stripExtension("file.ext1.ext2"d) == "file.ext1");
    assert (stripExtension(".foo".dup) == ".foo");
    assert (stripExtension(".foo.ext"w.dup) == ".foo");

    assert (stripExtension("dir/file"d.dup) == "dir/file");
    assert (stripExtension("dir/file.ext") == "dir/file");
    assert (stripExtension("dir/file.ext1.ext2"w) == "dir/file.ext1");
    assert (stripExtension("dir/.foo"d) == "dir/.foo");
    assert (stripExtension("dir/.foo.ext".dup) == "dir/.foo");

    version(Windows)
    {
    assert (stripExtension("dir\\file") == "dir\\file");
    assert (stripExtension("dir\\file.ext") == "dir\\file");
    assert (stripExtension("dir\\file.ext1.ext2") == "dir\\file.ext1");
    assert (stripExtension("dir\\.foo") == "dir\\.foo");
    assert (stripExtension("dir\\.foo.ext") == "dir\\.foo");

    assert (stripExtension("d:file") == "d:file");
    assert (stripExtension("d:file.ext") == "d:file");
    assert (stripExtension("d:file.ext1.ext2") == "d:file.ext1");
    assert (stripExtension("d:.foo") == "d:.foo");
    assert (stripExtension("d:.foo.ext") == "d:.foo");
    }
}




/** Set the extension of a filename.

    If the filename already has an extension, it is replaced.   If not, the
    extension is simply appended to the filename.

    This function always allocates a new string.

    Examples:
    ---
    setExtension("file", "ext")         -->  "file.ext"
    setExtension("file.old", "new")     -->  "file.new"
    ---
*/
immutable(Unqual!C1)[] setExtension(C1, C2)(in C1[] path, in C2[] ext)
    if (isSomeChar!C1 && is(Unqual!C1 == Unqual!C2))
{
    return cast(typeof(return))(stripExtension(path)~'.'~ext);
}


unittest
{
    auto p1 = setExtension("file", "ext");
    assert (p1 == "file.ext");
    static assert (is(typeof(p1) == string));

    auto p2 = setExtension("file.old"w.dup, "new"w);
    assert (p2 == "file.new");
    static assert (is(typeof(p2) == wstring));
}




/** Set the extension of a filename, but only if it doesn't
    already have one.

    This function always allocates a new string.

    Examples:
    ---
    defaultExtension("file", "ext")         -->  "file.ext"
    defaultExtension("file.old", "new")     -->  "file.old"
    ---
*/
immutable(Unqual!C1)[] defaultExtension(C1, C2)(in C1[] path, in C2[] ext)
    if (isSomeChar!C1 && is(Unqual!C1 == Unqual!C2))
{
    auto i = extSeparatorPos(path);
    if (i == -1) return cast(typeof(return))(path~'.'~ext);
    else return path.idup;
}


unittest
{
    auto p1 = defaultExtension("file"w, "ext"w);
    assert (p1 == "file.ext");
    static assert (is(typeof(p1) == wstring));

    auto p2 = defaultExtension("file.old"d, "new"d.dup);
    assert (p2 == "file.old");
    static assert (is(typeof(p2) == dstring));
}




// Detects whether the given types are all string types of the same width
private template compatibleStrings(Strings...)  if (Strings.length > 0)
{
    static if (Strings.length == 1)
    {
        enum compatibleStrings = isSomeChar!(typeof(Strings[0].init[0]));
    }
    else
    {
        enum compatibleStrings =
            is(Unqual!(typeof(Strings[0].init[0])) == Unqual!(typeof(Strings[1].init[0])))
            && compatibleStrings!(Strings[1 .. $]);
    }
}

version (unittest)
{
    static assert (compatibleStrings!(char[], const(char)[], string));
    static assert (compatibleStrings!(wchar[], const(wchar)[], wstring));
    static assert (compatibleStrings!(dchar[], const(dchar)[], dstring));
    static assert (!compatibleStrings!(int[], const(int)[], immutable(int)[]));
    static assert (!compatibleStrings!(char[], wchar[]));
    static assert (!compatibleStrings!(char[], dstring));
}


/** Joins two or more path components. */
immutable(Unqual!C)[] join(C, Strings...)(in C[] path, in Strings morePaths)
    if (compatibleStrings!(C[], Strings))
{
    // More than two path components
    static if (Strings.length > 1)
    {
        return join(join(path, morePaths[0]), morePaths[1 .. $]);
    }

    // Exactly two path components
    else
    {
        alias path path1;
        alias morePaths[0] path2;
        if (path2.length == 0) return path1.idup;
        if (path1.length == 0) return path2.idup;
        if (isAbsolute(path2)) return path2.idup;

        if (isDirSeparator(path1[$-1]) || isDirSeparator(path2[0]))
            return cast(string)(path1 ~ path2);
        else
            return cast(string)(path1 ~ dirSeparator ~ path2);
    }
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
bool isAbsolute(C)(in C[] path)  if (isSomeChar!C)
{
    version (Posix)
    {
        if (path.length == 0)  return false;
        return (path[0] == '/');
    }
    else version (Windows)
    {
        return (path.length >= 3
            &&  path[1] == ':'
            && (path[2] == '\\' || path[2] == '/'));
    }
}


/// ditto
bool isRelative(C)(in C[] path)  if (isSomeChar!C)
{
    if (path.length == 0)  return false;
    return !isAbsolute(path);
}


unittest
{
    assert (isRelative("foo"));
    assert (isRelative("../foo"w));

    version (Posix) 
    {
    assert (isAbsolute("/"d));
    assert (isAbsolute("/foo".dup));
    }

    version (Windows)
    {
    assert (isRelative("\\"w.dup));
    assert (isRelative("\\foo"d.dup));
    assert (isRelative("d:foo"));
    assert (isAbsolute("d:\\"w));
    assert (isAbsolute("d:\\foo"d));
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
    if (path.length == 0)  return null;
    if (isAbsolute(path))  return path;
    return join(getcwd(), path);
}



/+
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
    version(Windows) string altDirSeparator = "\\";

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
        writeln(toCanonical(p2), "  ", toAbsolute(p1));
        assert (toCanonical(p2) == toAbsolute(p1));
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
+/
