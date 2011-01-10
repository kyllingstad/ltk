/** Useful types. */
module ltk.types;


import std.conv;



/** This mixin defines an enumerated type which is a cross
    between a named and an anonymous enum:  It has a unique name,
    hence it is type safe, but one doesn't have to specify the
    name when using its members.

    Example:
    ---
    mixin Enum!("MyEnum", int,
        "foo", 1,
        "bar", 2,
        "baz", 4);

    void myFunc(MyEnum m) { ... }

    void main()
    {
        myFunc(foo);
        myFunc(bar | baz);
    }
    ---

    Syntax:
    ---
    // For an automatically enumerated integer type:
    mixin Enum!("type_name", "member1", "member2", ...);

    // For an integer type with specific member values:
    mixin Enum!("type_name", "member1", 123, "member2", 456, ...);

    // For a non-integer type:
    mixin Enum!("type_name", base_type, "member1", value1, "member2", value2, ...);
    ---
*/
mixin template Enum(string name, membersAndValues...) if (!is(membersAndValues[0]))
{
    mixin Enum!(name, int, membersAndValues);
}

mixin template Enum(string name, BaseType, membersAndValues...)
{
    static assert (membersAndValues.length >= 2,
        "Must specify at least one enum member as well as its value.");
    
    enum structDef = "
        struct "~name~"
        {
            "~BaseType.stringof~" value;
            "~name~" opOpAssign(string op)("~name~" rhs)
                if (op == \"|\" || op == \"&\")
            {
                mixin(\"value \"~op~\"= rhs.value;\");
                return this;
            }

            "~name~" opBinary(string op)("~name~" rhs)
                if (op == \"|\" || op == \"&\")
            {
                auto result = this;
                result.opOpAssign!op(rhs);
                return result;
            }

            bool opCast(T)() if (is(T == bool))
            {
                return value ? true : false;
            }
        }";
    enum enumDef = enumImpl!BaseType(name, membersAndValues);

    //pragma (msg, structDef);
    mixin(structDef);

    //pragma (msg, enumDef);
    mixin(enumDef);
}

string enumImpl(T, U...)(string name, U mv)
{
    string code = "enum : "~name~"\n{\n";
    
    foreach (i, m; mv)
    {
        static if (i % 2 == 0)
        {
            static assert (is (U[i] == string),
                "Expected string with member name, not "~U[i].stringof);
            code ~= "    " ~ m ~ " = ";
        }
        else
        {
            static assert (is (U[i] == T),
                "Expected member value of type "~T.stringof~", not "~U[i].stringof);
            code ~= name ~"("~to!string(m)~"),\n";
        }
    }

    return code~"}";
}


unittest
{
    mixin Enum!("Number", int,
        "zero", 0,
        "one", 1,
        "two", 2,
        "three", 3);

    assert ((one & two) == zero);
    assert ((one | two) == three);
}


unittest
{
    mixin Enum!("MyEnum", int,
        "foo", 1,
        "bar", 2,
        "baz", 4);

    string myFunc(MyEnum m)
    {
        string s;
        if (m & foo) s ~= "foo";
        if (m & bar) s ~= "bar";
        if (m & baz) s ~= "baz";
        return s;
    }

    assert (myFunc(bar) == "bar");
    assert (myFunc(foo | baz) == "foobaz");
}
