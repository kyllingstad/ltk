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

import std.array; // for the range primitives


/**
Evaluates to true if Range is a built-in string type or some type which has the
same characteristics.

By "same characteristics" we here mean that it must be a random access range
which has a known length and which supports slicing, and whose elements are of
one of the three character types.
*/
template isStringlike(Range)
{
    import std.traits, std.range.primitives;
    enum isStringlike = isSomeString!Range
        || (isRandomAccessRange!Range && hasLength!Range && hasSlicing!Range
            && isSomeChar!(ElementType!Range));
}


/**
A range which wraps a string (or string-like range) and keeps track of _line and
_column numbers.

This range is a random-access range view of the underlying string, but it does
not support general slicing via the slicing operator.  Since TextLocationTracker
has to look at each character to determine when a new _line begins, slicing
would be very inefficient.  However, it does support slicing from the _front via
the frontSlice method.

It should also be noted that the element type of this range is the element
encoding type of the underlying string.  That is, even though Phobos performs
auto-decoding of narrow strings in range operations, this does not happen here.
If desirable, this may be added in the future as a compile-time option, though.

Both LF and CR are counted as newline characters, except when an LF immediately
follows a CR (Windows _line endings), in which case they are considered together
as one newline.
*/
struct TextLocationTracker(String) if (isStringlike!String)
{
    import std.range.primitives;

    static assert (
        isRandomAccessRange!(typeof(this))
        && hasLength!(typeof(this))
        && is(ElementType!(typeof(this)) == ElementEncodingType!String));

    /**
    Wraps the given string, starting counting at the given _line and _column
    numbers.
    */
    this(String s, int startLine = 1, int startColumn = 1)
    {
        inner_ = s;
        line_ = startLine;
        column_ = startColumn;
    }

    /// Input range primitive.
    @property bool empty() const
    {
        return inner_.empty;
    }

    /// Input range primitive.
    @property auto ref front()
    {
        assert (!empty);
        return inner_[0];
    }

    /// Input range primitive.
    void popFront()
    {
        assert (!empty);
        const c = front;
        inner_ = inner_[1 .. $];
        if (c == '\n' || (c == '\r' && !(!inner_.empty && inner_[0] == '\n'))) {
            ++line_;
            column_ = 1;
        } else {
            ++column_;
        }
    }

    /// Forward range primitive.
    typeof(this) save()
    {
        return typeof(this)(inner_.save, line_, column_);
    }

    /// Bidirectional range primitive.
    @property auto ref back()
    {
        assert (!empty);
        return inner_[$-1];
    }

    /// Bidirectional range primitive.
    void popBack()
    {
        assert (!empty);
        inner_ = inner_[0 .. $-1];
    }

    /// Random access range primitive.
    auto ref opIndex(size_t index)
    {
        return inner_[index];
    }

    /// Returns the _length of the string (in code units).
    @property auto ref length()
    {
        return inner_.length;
    }

    /**
    Returns a slice of the _front n elements of the underlying range.

    n must be smaller than or equal to length.
    */
    typeof(this) frontSlice(size_t n)
    {
        return typeof(this)(inner_[0 .. n], line_, column_);
    }

    /// Returns the underlying range.
    @property String inner()
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

private:
    String inner_;
    int line_;
    int column_;
}

/// Convenience function for creating a TextLocationTracker.
TextLocationTracker!String textLocationTracker(String)(auto ref String s)
    if (isStringlike!String)
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
