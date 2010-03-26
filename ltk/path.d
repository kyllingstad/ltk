module ltk.path;


import std.contracts;
import std.file;
import std.path;


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
