/** Range-related stuff. */
module ltk.range;


import std.range;

version(unittest) import std.algorithm;




/** Range that iterates another range by reference. */
auto byRef(Range)(ref Range range) if (isInputRange!Range)
{
    struct ByRef
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
