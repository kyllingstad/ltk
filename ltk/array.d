/** Array-related stuff. These functions are implemented in a quite
    naïve way, so there is most likely ample room for optimisations.

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad. All rights reserved.
    License:    Boost License 1.0
*/
module ltk.array;



/** Combine several associative arrays. The arrays are processed in the
    order they are given, and if a key exists in two or more arrays, the
    first one takes precedence.
*/
T[U] combine(T, U)(T[U][] arrays ...)
{
    T[U] c;

    foreach (a; arrays)
    {
        foreach (key, val; a)
        {
            if ((key in c) == null)  c[key] = val;
        }
    }
    return c;
}

unittest
{
    auto a = [ "apple" : "red", "pear" : "green" ];
    auto b = [ "banana" : "yellow", "pear" : "blue" ];
    auto c = [ "orange" : "orange", "pear" : "42" ];

    auto d = combine(a, b, c);
    assert (d.length == 4);
    assert (d["apple"] == "red");
    assert (d["banana"] == "yellow");
    assert (d["orange"] == "orange");
    assert (d["pear"] == "green");
}


/** Duplicate an associative array. */
T[U] dup(T, U)(T[U] a)
{
    T[U] b;
    foreach (key, val; a)  b[key] = val;
    return b;
}
