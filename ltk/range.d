/** Range-related stuff. */
module ltk.range;


import std.range;

version(unittest) import std.algorithm;




/** Range that iterates another range by reference. */
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

unittest
{
    auto a = [1, 2, 3, 4];
    auto b = take(byRef(a), 2);

    assert (equal(b, [1, 2]));
    assert (equal(a, [3, 4]));
}




/** Range that iterates another range until the given predicate is true.

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


unittest
{
    auto a = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    static bool isFour(int i) { return i == 4; }

    assert (equal(until!isFour(a), [0, 1, 2, 3]));
}
