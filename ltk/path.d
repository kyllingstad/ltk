/** Proposal for a rewrite of
    $(LINK2 http://www.digitalmars.com/d/2.0/phobos/std_path.html,std._path).

    This module is used to parse file names. All the operations work
    only on strings; they don't perform any input/output operations.
    This means that if a path contains a directory name with a dot,
    functions like extension() will work with it just as if it was a file.
    To differentiate these cases, use the std.file module first (i.e.
    std.file.isDir()).

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010–2011, Lars T. Kyllingstad. All rights reserved.
    License:    Boost License 1.0
*/
module ltk.path;


import std.conv;
import std.ctype;
import std.file;
import std.string;
import std.traits;




/** String used to separate directory names in a path.  Under
    POSIX this is a slash, under Windows a backslash.
*/
version(Posix)   enum string dirSeparator = "/";
version(Windows) enum string dirSeparator = "\\";


/** Path separator string.  A colon under POSIX, a semicolon
    under Windows.
*/
version(Posix)   enum string pathSeparator = ":";
version(Windows) enum string pathSeparator = ";";


/** Strings representing the current and parent directories
    ("." and "..", respectively)
*/
enum string currentDirSymbol = ".";
enum string parentDirSymbol = "..";     /// ditto




/** Determine whether the given character is a directory separator.

    On Windows, this includes both '\' and '/'.  On POSIX, it's just '/'.
*/
bool isDirSeparator(dchar c)
{
    if (c == '/') return true;
    version(Windows) if (c == '\\') return true;
    return false;
}


/*  Determine whether the given character is a drive separator.

    On Windows, this is true if c is the ':' character that separates
    the drive letter from the rest of the path.  On POSIX, this always
    returns false.
*/
private bool isDriveSeparator(dchar c)
{
    version(Windows) return c == ':';
    else return false;
}


/*  Combines the isDirSeparator and isDriveSeparator tests. */
version(Windows) private bool isSeparator(dchar c)
{
    return isDirSeparator(c) || isDriveSeparator(c);
}
version(Posix) private alias isDirSeparator isSeparator;


/*  Helper function that determines the position of the last
    drive/directory separator in a string.  Returns -1 if none
    is found.
*/
private int lastSeparator(C)(in C[] path)  if (isSomeChar!C)
{
    int i = to!int(path.length) - 1;
    while (i >= 0 && !isSeparator(path[i])) --i;
    return i;
}


/*  Helper function that strips trailing slashes and backslashes
    from a path.
*/
private C[] chompDirSeparators(C)(C[] path)  if (isSomeChar!C)
{
    int i = to!int(path.length) - 1;
    while (i >= 0 && isDirSeparator(path[i])) --i;
    return path[0 .. i+1];
}




/** Returns the name of a file, without any leading directory
    and with an optional suffix chopped off.

    Examples:
    ---
    baseName("dir/file.ext")            -->  "file.ext"
    baseName("dir/file.ext", ".ext")    -->  "file"
    baseName("dir/filename", "name")    -->  "file"
    baseName("dir/subdir/")             -->  "subdir"

    // Windows only:
    baseName( "d:file.ext")             -->  "file.ext"
    baseName(r"d:\dir\file.ext")        -->  "file.ext"
    ---

    Note:
    This function only strips away the specified suffix.  If you want
    to remove the extension from a path, regardless of what the extension
    is, use stripExtension().
    If you want the filename without leading directories and without
    an extension, combine the functions like this:
    ---
    assert (baseName(stripExtension("dir/file.ext")) == "file");
    ---
*/
// This function is written so it adheres to the POSIX requirements
// for the 'basename' shell utility:
// http://pubs.opengroup.org/onlinepubs/9699919799/utilities/basename.html
C[] baseName(C)(C[] path) if (isSomeChar!C)
{
    auto p1 = stripDrive(path);
    if (p1.length == 0) return null;

    auto p2 = chompDirSeparators(p1);
    if (p2.length == 0) return p1[0 .. 1];

    return p2[lastSeparator(p2)+1 .. $];
}

/// ditto
C[] baseName(C, C1)(C[] path, C1[] suffix)  if (isSomeChar!C && isSomeChar!C1)
{
    auto p1 = baseName(path);
    auto p2 = std.string.chomp(p1, suffix);
    if (p2.length == 0) return p1;
    else return p2;
}


unittest
{
    assert (baseName("")                            == "");
    assert (baseName("file.ext"w)                   == "file.ext");
    assert (baseName("file.ext"d, ".ext")           == "file");
    assert (baseName("file", "file"w.dup)           == "file");
    assert (baseName("dir/file.ext"d.dup)           == "file.ext");
    assert (baseName("dir/file.ext", ".ext"d)       == "file");
    assert (baseName("dir/file"w, "file"d)          == "file");
    assert (baseName("dir///subdir////")            == "subdir");
    assert (baseName("dir/subdir.ext/", ".ext")     == "subdir");
    assert (baseName("dir/subdir/".dup, "subdir")   == "subdir");
    assert (baseName("/"w.dup)                      == "/");
    assert (baseName("//"d.dup)                     == "/");
    assert (baseName("///")                         == "/");

    version (Win32)
    {
    assert (baseName("dir\\file.ext")               == "file.ext");
    assert (baseName("dir\\file.ext", ".ext")       == "file");
    assert (baseName("dir\\file", "file")           == "file");
    assert (baseName("d:file.ext")                  == "file.ext");
    assert (baseName("d:file.ext", ".ext")          == "file");
    assert (baseName("d:file", "file")              == "file");
    assert (baseName("dir\\\\subdir\\\\\\")         == "subdir");
    assert (baseName("dir\\subdir.ext\\", ".ext")   == "subdir");
    assert (baseName("dir\\subdir\\", "subdir")     == "subdir");
    assert (baseName("\\")                          == "\\");
    assert (baseName("\\\\")                        == "\\");
    assert (baseName("\\\\\\")                      == "\\");
    assert (baseName("d:\\")                        == "\\");
    assert (baseName("d:")                          == "");
    }

    assert (baseName(stripExtension("dir/file.ext")) == "file");
}




/** Returns the directory part of a path.  On Windows, this
    includes the drive letter if present.

    Examples:
    ---
    dirName("file")             -->  "."
    dirName("dir/file")         -->  "dir"
    dirName("/file")            -->  "/"
    dirName("dir/subdir/")      -->  "dir"

    // Windows only:
    dirName( "d:file")          -->  "d:"
    dirName(r"d:\dir\file")     --> r"d:\dir"
    dirName(r"d:\file")         --> r"d:\"
    dirName(r"dir\subdir\")     -->  "dir"
    ---
*/
C[] dirName(C)(C[] path)  if (isSomeChar!C)
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
    assert (dirName("")                 == ".");
    assert (dirName("file"w)            == ".");
    assert (dirName("dir/"d)            == ".");
    assert (dirName("dir///")           == ".");
    assert (dirName("dir/file"w.dup)    == "dir");
    assert (dirName("dir///file"d.dup)  == "dir");
    assert (dirName("dir/subdir/")      == "dir");
    assert (dirName("/dir/file"w)       == "/dir");
    assert (dirName("/file"d)           == "/");
    assert (dirName("/")                == "/");
    assert (dirName("///")              == "/");

    version (Windows)
    {
    assert (dirName("dir\\")            == ".");
    assert (dirName("dir\\\\\\")        == ".");
    assert (dirName("dir\\file")        == "dir");
    assert (dirName("dir\\\\\\file")    == "dir");
    assert (dirName("dir\\subdir\\")    == "dir");
    assert (dirName("\\dir\\file")      == "\\dir");
    assert (dirName("\\file")           == "\\");
    assert (dirName("\\")               == "\\");
    assert (dirName("\\\\\\")           == "\\");
    assert (dirName("d:")               == "d:");
    assert (dirName("d:file")           == "d:");
    assert (dirName("d:\\")             == "d:\\");
    assert (dirName("d:\\file")         == "d:\\");
    assert (dirName("d:\\dir\\file")    == "d:\\dir");
    }
}




/** Returns the drive letter (including the colon) of a path, or
    an empty string if there is no drive letter.

    Always returns an empty string on POSIX.

    Examples:
    ---
    driveName( "d:file")    -->  "d:"
    driveName(r"d:\file")   -->  "d:"
    driveName(r"dir\file")  -->  ""
    ---
*/
C[] driveName(C)(C[] path)  if (isSomeChar!C)
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
    version (Posix)  assert (driveName("c:/foo") == null);
    version (Windows)
    {
    assert (driveName("dir\\file") == null);
    assert (driveName("d:file") == "d:");
    assert (driveName("d:\\file") == "d:");
    }
}




/** Strip the drive designation from a Windows path.
    On POSIX, this is a noop.

    Example:
    ---
    stripDrive(r"d:\dir\file")       -->  r"\dir\file"
    ---
*/
C[] stripDrive(C)(C[] path)  if (isSomeChar!C)
{
    version(Windows)
        if (path.length >= 2 && isDriveSeparator(path[1])) return path[2 .. $];
    return path;
}


unittest
{
    version(Windows) assert (stripDrive(r"d:\dir\file") == r"\dir\file");
    version(Posix)   assert (stripDrive(r"d:\dir\file") == r"d:\dir\file");
}




/*  Helper function that returns the position of the filename/extension
    separator dot in path.  If not found, returns -1.
*/
private int extSeparatorPos(C)(in C[] path) if (isSomeChar!C)
{
    int i = to!int(path.length) - 1;
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




/** Return the path with the extension stripped off.

    Examples:
    ---
    extension("file")               -->  "file"
    extension("file.ext")           -->  "file"
    extension("file.ext1.ext2")     -->  "file.ext1"
    extension(".file")              -->  ".file"
    extension(".file.ext")          -->  ".file"
    extension("dir/file.ext")       -->  "dir/file"
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

    This function always allocates a new string, except in the case when
    path is immutable and already has an extension.

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




/** Joins two or more path components.

    The given path components are concatenated with each other,
    and if necessary, directory separators are inserted between
    them. If any of the path components are absolute paths (see
    $(LINK2 #isAbsolute,isAbsolute)) the preceding path components
    will be dropped.

    Examples:
    ---
    // On Windows:
    joinPath(r"c:\foo", "bar")  -->  r"c:\foo\bar"
    joinPath("foo", r"d:\bar")  -->  r"d:\bar"

    // On POSIX
    joinPath("/foo/", "bar")    -->  "/foo/bar"
    joinPath("/foo", "/bar")    -->  "/bar"
    ---
*/
immutable(Unqual!C)[] joinPath(C, Strings...)(in C[] path, in Strings morePaths)
    if (Strings.length > 0 && compatibleStrings!(C[], Strings))
{
    // More than two path components
    static if (Strings.length > 1)
    {
        return joinPath(joinPath(path, morePaths[0]), morePaths[1 .. $]);
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
            return cast(typeof(return))(path1 ~ path2);
        else
            return cast(typeof(return))(path1 ~ dirSeparator ~ path2);
    }
}


unittest
{
    version (Posix)
    {
        assert (joinPath("foo", "bar") == "foo/bar");
        assert (joinPath("foo/".dup, "bar") == "foo/bar");
        assert (joinPath("foo///", "bar".dup) == "foo///bar");
        assert (joinPath("/foo"w, "bar"w) == "/foo/bar");
        assert (joinPath("foo"w.dup, "/bar"w) == "/bar");
        assert (joinPath("foo"w, "bar/"w.dup) == "foo/bar/");
        assert (joinPath("/"d, "foo"d) == "/foo");
        assert (joinPath(""d.dup, "foo"d) == "foo");
        assert (joinPath("foo"d, ""d.dup) == "foo");
        assert (joinPath("foo", "bar".dup, "baz") == "foo/bar/baz");
        assert (joinPath("foo"w, "/bar"w, "baz"w.dup) == "/bar/baz");
    }
    version (Windows)
    {
        assert (joinPath(r"c:\foo", "bar") == r"c:\foo\bar");
        assert (joinPath("foo"w, r"d:\bar"w.dup) ==  r"d:\bar");
    }
}




/** Determines whether a path is absolute or relative.

    isRelative() is just defined as !_isAbsolute(), with the
    notable exception that both functions return false if
    path is an empty string.

    Examples:
    On POSIX, an absolute path starts at the root directory,
    i.e. it starts with a slash (/).
    ---
    assert (isRelative("foo"));
    assert (isRelative("../foo"));
    assert (isAbsolute("/"));
    assert (isAbsolute("/foo"));
    ---

    On Windows, an absolute path starts at the root directory of
    a specific drive.  Hence, it must start with "d:\" or "d:/",
    where d is the drive letter.
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
        return path.length >= 1 && isDirSeparator(path[0]);
    }
    else version (Windows)
    {
        return path.length >= 3 && isDriveSeparator(path[1])
            && isDirSeparator(path[2]);
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
    assert (isRelative("d:"));
    assert (isRelative("d:foo"));
    assert (isAbsolute("d:\\"w));
    assert (isAbsolute("d:\\foo"d));
    }
}




/** Translate path into an absolute _path.

    This means:
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
    return joinPath(getcwd(), path);
}




/** Convert path to a canonical _path.

    In addition to performing the same operations as toAbsolute(),
    this function does the following:

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
    if (path.length == 0) return null;

    // Get absolute path, and duplicate it to make sure we can
    // safely change it below.
    auto p1 = toAbsolute(path).dup;

    // On Windows, skip drive designation.
    version (Windows)  auto p2 = p1[2 .. $];
    else auto p2 = p1;

    enum { singleDot, doubleDot, dirSep, other }
    int prev = other;

    // i is the position in the absolute path,
    // j is the position in the canonical path.
    int j = 0;
    for (int i=0; i<=p2.length; ++i, ++j)
    {
        // At directory separator or end of path?
        if (i == p2.length || isDirSeparator(p2[i]))
        {
            if (prev == singleDot || prev == doubleDot)
            {
                // Backtrack to last dir separator
                while (!isDirSeparator(p2[--j])) { }
            }
            if (prev == doubleDot && j>0)
            {
                // Backtrack once again
                while (!isDirSeparator(p2[--j])) { }
            }
            if (prev == dirSep)  --j;
            prev = dirSep;
        }

        // At dot?
        else if (p2[i] == '.')
        {
            if (prev == dirSep)         prev = singleDot;
            else if (prev == singleDot) prev = doubleDot;
            else                        prev = other;
        }

        // At anything else
        else prev = other;

        if (i < p2.length) p2[j] = p2[i];
    }

    // If the directory turns out to be root, we do want a trailing slash.
    if (j == 1)  j = 2;

    // On Windows, make a final pass through the path and replace slashes
    // with backslashes and include drive designation again.
    // Note that we can safely cast the result to string, since we dup-ed
    // the string we got from toAbsolute() earlier.
    version (Windows)
    {
        foreach (ref c; p2) if (c == '/') c = '\\';
        return cast(string) p1[0 .. j+1];
    }
    else version (Posix) return cast(string) p2[0 .. j-1];
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




import std.path;
/** Functions from the current std.path which I don't plan to change.
    Some of them should perhaps be renamed.
*/
alias std.path.fcmp fcmp;
alias std.path.fncharmatch fncharmatch; /// ditto
alias std.path.fnmatch fnmatch;         /// ditto
alias std.path.expandTilde expandTilde; /// ditto


deprecated:
/** Kept for backwards compatibility */
alias dirSeparator sep;
enum string altsep = "/"; /// ditto
alias pathSeparator pathsep; /// ditto
version(Windows) enum string linesep = "\r\n"; /// ditto
version(Posix) enum string linesep = "\n"; /// ditto
alias currentDirSymbol curdir; /// ditto
alias parentDirSymbol pardir; /// ditto
alias extension getExt; /// ditto
string getName(string path) { return baseName(stripExtension(path)); } /// ditto
alias baseName getBaseName; /// ditto
alias baseName basename; /// ditto
alias dirName dirname; /// ditto
alias dirName getDirName; /// ditto
alias driveName getDrive; /// ditto
alias defaultExtension defaultExt; /// ditto
alias setExtension addExt; /// ditto
alias isAbsolute isabs; /// ditto
alias toAbsolute rel2abs; /// ditto
alias joinPath join; /// ditto
