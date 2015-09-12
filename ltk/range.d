/*
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

/**
General-purpose ranges and related functionality.

Authors:    Lars Tandle Kyllingstad
Copyright:  Copyright (c) 2010–2015, Lars T. Kyllingstad. All rights reserved.
License:    Mozilla Public License v. 2.0
*/
module ltk.range;

import std.range;


/// Range that iterates another range by reference.
auto byRef(Range)(ref Range range) if (isInputRange!Range)
{
    static struct ByRef
    {
        private Range* _range;

        static if (isInfinite!Range)
        {
            enum empty = false;
        }
        else
        {
            @property bool empty() { return (*_range).empty; }
        }

        @property ElementType!Range front()
        {
            return (*_range).front;
        }

        void popFront()
        {
            (*_range).popFront();
        }
    }

    return ByRef(&range);
}

///
unittest
{
    import std.algorithm: equal;
    auto a = [1, 2, 3, 4];
    auto b = take(byRef(a), 2);
    assert (equal(b, [1, 2]));
    assert (equal(a, [3, 4]));
}


/**
Range that iterates another range until the given predicate is true.

This differs from std.algorithm in that it does not require the
"sentinel" value.  On the other hand, it does require you to specify
the predicate.
*/
auto until(alias pred, Range)(Range range) if (isInputRange!Range)
{
    static struct Until
    {
        private Range _range;
        private bool _empty;

        @property bool empty() { return _empty; }

        @property ElementType!Range front()
        {
            return _range.front;
        }

        void popFront()
        {
            _range.popFront();
            _empty = _range.empty || pred(_range.front);
        }
    }

    return Until(range, range.empty || pred(range.front));
}

///
unittest
{
    import std.algorithm: equal;
    auto a = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    static bool isFour(int i) { return i == 4; }
    assert (equal(until!isFour(a), [0, 1, 2, 3]));
}
