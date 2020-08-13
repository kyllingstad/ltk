/*
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

/**
Text processing.

Authors:    Lars Tandle Kyllingstad
Copyright:  Copyright (c) 2015, Lars T. Kyllingstad. All rights reserved.
License:    Mozilla Public License v. 2.0
*/
module ltk.text;

// For the range primitives:
import std.array;
import std.range.primitives;
import std.traits;


/**
Returns a slice of the front n elements of the string s.

This function is mainly intended for use in ranges that wrap strings, or
which wrap other wrapper ranges.  If all such ranges support this primitive,
and implement it as returning the innerFrontSlice of their underlying
range, it becomes possible to acquire a slice of an underlying string through
several layers of such wrappers.
*/
inout(C)[] innerFrontSlice(C)(inout(C)[] s, size_t n)
    @safe pure nothrow @nogc
    if (isSomeChar!C)
{
    return s[0 .. n];
}

unittest
{
    assert ("".innerFrontSlice(0) == "");
    assert ("hello".innerFrontSlice(4) == "hell");
}


/**
A range which wraps a character range and keeps track of _line and_column
numbers.

The range has the same characteristics as the wrapped range; that is, it may
have input, forward, bidirectional and random access range primitives,
depending on whether the underlying range supports them.

It does not support general slicing via the slicing operator, however, as that
would be impossible to implement efficiently while keeping track of line and
column numbers.  However, it does support slicing from the _front via the
frontSlice method, as well as returning a slice of the front of the underlying
range with innerFrontSlice.

Both LF and CR are counted as newline characters, except when an LF immediately
follows a CR (Windows _line endings), in which case only the LF will be counted.
*/
struct TextLocationTracker(Range)
    if (isInputRange!Range && isSomeChar!(ElementType!Range))
{
    import std.range.primitives;

    static assert (isInputRange!(typeof(this)));
    static assert (is(ElementType!(typeof(this)) == ElementType!Range));

    /**
    Wraps the given string, starting counting at the given _line and _column
    numbers.
    */
    this(Range s, int startLine = 1, int startColumn = 1, int startCUColumn = 1)
    {
        inner_ = s;
        line_ = startLine;
        column_ = startColumn;
        cuColumn_ = startCUColumn;
    }

    // Input range primitives
    @property bool empty() const
    {
        return inner_.empty;
    }

    @property auto ref front()
    {
        assert (!empty);
        return inner_.front;
    }

    void popFront()
    {
        assert (!empty);
        const lengthBefore = inner_.length;
        const c = front;
        inner_.popFront();
        if (c == '\n' || (c == '\r' && !(!inner_.empty && inner_.front == '\n'))) {
            ++line_;
            column_ = 1;
            cuColumn_ = 1;
        } else {
            ++column_;
            cuColumn_ += lengthBefore - inner_.length;
        }
    }

    // Forward range primitives
    static if (isForwardRange!Range) {
        typeof(this) save()
        {
            return typeof(this)(inner_.save, line_, column_, cuColumn_);
        }
    }

    // Bidirectional range primitive.
    static if (isBidirectionalRange!Range) {
        @property auto ref back()
        {
            assert (!empty);
            return inner_.back;
        }

        void popBack()
        {
            assert (!empty);
            inner_.popBack();
        }
    }

    // Indexing
    static if (__traits(compiles, { auto c = Range.init[0]; })) {
        auto ref opIndex(size_t index)
        {
            return inner_[index];
        }
    }

    // Length
    static if (__traits(compiles, { auto n = Range.init.length; })) {
        @property auto ref length()
        {
            return inner_.length;
        }
    }

    // Slicing (kind of)
    static if (__traits(compiles, { auto s = Range.init[0 .. 1]; })) {
        typeof(this) frontSlice(size_t n)
        {
            return typeof(this)(inner_[0 .. n], line_, column_);
        }

        auto innerFrontSlice(size_t n)
        {
            return inner_.innerFrontSlice(n);
        }
    }

    /// Returns the underlying range.
    @property Range inner()
    {
        return inner_;
    }

    /// Returns the _line number of the _front element.
    @property int line() const @safe pure nothrow @nogc
    {
        return line_;
    }

    /// Returns the _column number of the _front element.
    @property int column() const @safe pure nothrow @nogc
    {
        return column_;
    }

    /// Returns the _column number of the _front element, counted in code units.
    @property int codeUnitColumn() const @safe pure nothrow @nogc
    {
        return cuColumn_;
    }

private:
    Range inner_;
    int line_;
    int column_;
    int cuColumn_;
}

/// Convenience function for creating a TextLocationTracker.
TextLocationTracker!Range textLocationTracker(Range)(auto ref Range s)
    if (isInputRange!Range && isSomeChar!(ElementType!Range))
{
    return typeof(return)(s);
}

unittest
{
    auto t = textLocationTracker("a\nbc\r\nd\ref");
    assert (!t.empty);
    assert (t.front == 'a');
    assert (t.back == 'f');
    assert (t.length == 10);
    assert (t.line == 1);
    assert (t.column == 1);

    t.popFront();
    assert (t.front == '\n');
    assert (t.back == 'f');
    assert (t.length == 9);
    assert (t.line == 1);
    assert (t.column == 2);

    t.popBack();
    assert (t.front == '\n');
    assert (t.back == 'e');
    assert (t.length == 8);
    assert (t.line == 1);
    assert (t.column == 2);

    auto tSave = t.save;

    t.popFront();
    assert (t.front == 'b');
    assert (t.line == 2);
    assert (t.column == 1);

    import std.range: popFrontN;
    popFrontN(t, 3);
    assert (t.front == '\n');
    assert (t.line == 2);
    assert (t.column == 4);

    popFrontN(t, 3);
    assert (t.front == 'e');
    assert (t.line == 4);
    assert (t.column == 1);
    assert (t.length == 1);
    assert (!t.empty);

    t.popBack();
    assert(t.empty);

    assert (tSave.front == '\n');
    assert (tSave.back == 'e');
    assert (tSave.length == 8);
    assert (tSave.line == 1);
    assert (tSave.column == 2);
}
