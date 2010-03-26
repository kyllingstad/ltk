/** Complex numbers.

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad. All rights reserved.
    License:    Boost License 1.0
*/
module ltk.complex;


import std.conv;
import std.math;

version(unittest) import std.stdio;




/** Struct representing a complex number parametrised by a type T
    
    Note that results of intermediate calculations are stored in
    variables of type R, which by default is real.  In some cases
    performance can be increased by using double instead, but
    this is at the cost of precision.
*/
struct Complex(T, R = real)
{
    /** The real part of the number. */
    T re;

    /** The imaginary part of the number. */
    T im;




    /** Calculate the modulus (or absolute value) of the number. */
    @property T mod()
    {
        T absRe = abs(re);
        T absIm = abs(im);
        if (absRe < absIm)
            return absIm * sqrt(1 + (re/im)^^2);
        else
            return absRe * sqrt(1 + (im/re)^^2);
    }

    /** Calculate the argument (or phase) of the number. */
    @property T arg()
    {
        return atan2(im, re);
    }




    // Unary operators
    Complex opUnary(string op)()  if (op == "+")  { return this; }

    Complex opUnary(string op)()  if (op == "-")
    {
        return Complex(-re, -im);
    }




    // Binary operators
    Complex opBinary(string op, U)(U y)
    {
        Complex x = this;
        return x.opOpAssign!(op~"=")(y);
    }

    
    Complex opBinaryRight(string op, U : T)(U a)  if (op == "-")
    {
        // a - this
        return Complex(a - re, -im);
    }


    Complex opBinaryRight(string op, U : T)(U a)  if (op == "/")
    {
        // a / this
        Complex x;

        if (abs(re) < abs(im))
        {
            R ratio = re/im;
            R adivd = a/(re*ratio + im);

            x.re = adivd*ratio;
            x.im = -adivd;
        }
        else
        {
            R ratio = im/re;
            R adivd = a/(re + im*ratio);

            x.re = adivd;
            x.im = -adivd*ratio;
        }

        return x;
    }


    // OpAssign operators:  Complex op= Complex
    Complex opOpAssign(string op)(Complex x)  if (op == "+=" || op == "-=")
    {
        mixin("re "~op~" x.re;");
        mixin("im "~op~" x.im;");
        return this;
    }


    Complex opOpAssign(string op)(Complex x)  if (op == "*=")
    {
    version (MultiplicationIsSlow)
    {
        R ac = re*x.re;
        R bd = im*x.im;
        T temp = ac - bd;
        im = (re + im)*(x.re + x.im) - ac - bd;
        re = temp;
    }
    else
    {
        T temp = re*x.re - im*x.im;
        im = im*x.re + re*x.im;
        re = temp;
    }
        return this;
    }


    Complex opOpAssign(string op)(Complex x)  if (op == "/=")
    {
        if (abs(x.re) < abs(x.im))
        {
            R ratio = x.re/x.im;
            R denom = x.re*ratio + x.im;

            T temp  = (re*ratio + im)/denom;
            im      = (im*ratio - re)/denom;
            re      = temp;
        }
        else
        {
            R ratio = x.im/x.re;
            R denom = x.re + x.im*ratio;

            T temp  = (re + im*ratio)/denom;
            im      = (im - re*ratio)/denom;
            re      = temp;
        }
        return this;
    }


    Complex opOpAssign(string op, U : T)(U a)  if (op == "+=" || op == "-=")
    {
        mixin ("re "~op~" a;");
        return this;
    }


    Complex opOpAssign(string op, U : T)(U a)  if (op == "*=" || op == "/=")
    {
        mixin ("re "~op~" a;");
        mixin ("im "~op~" a;");
        return this;
    }


    // Just for debugging.  TODO: Improve later.
    string toString()
    {
        return to!string(re)~"+i"~to!string(im);
    }
}


unittest
{
    enum EPS = double.epsilon;

    // Check mod() and arg()
    auto c1 = Complex!double(1.0, 1.0);
    assert (approxEqual(c1.mod, sqrt(2.0), EPS));
    assert (approxEqual(c1.arg, PI_4, EPS));


    // Check unary operators.
    auto c2 = Complex!double(0.5, 2.0);

    assert (c2 == +c2);
    
    assert ((-c2).re == -(c2.re));
    assert ((-c2).im == -(c2.im));
    assert (c2 == -(-c2));


    // Check Complex-Complex operations.
    auto c3 = c1 + c2;
    assert (c3.re == c1.re + c2.re);
    assert (c3.im == c1.im + c2.im);

    auto c4 = c1 - c2;
    assert (c4.re == c1.re - c2.re);
    assert (c4.im == c1.im - c2.im);

    auto c5 = c1 * c2;
    assert (approxEqual(c5.mod, c1.mod*c2.mod, EPS));
    assert (approxEqual(c5.arg, c1.arg+c2.arg, EPS));

    auto c6 = c1 / c2;
    assert (approxEqual(c6.mod, c1.mod/c2.mod, EPS));
    assert (approxEqual(c6.arg, c1.arg-c2.arg, EPS));


    // Check Complex-float operations.
    double a = 123.456;

    auto c7 = c1 + a;
    assert (c7.re == c1.re + a);
    assert (c7.im == c1.im);

    auto c8 = c1 - a;
    assert (c8.re == c1.re - a);
    assert (c8.im == c1.im);

    auto c9 = c1 * a;
    assert (c9.re == c1.re*a);
    assert (c9.im == c1.im*a);

    auto c10 = c1 / a;
    assert (approxEqual(c10.mod, c1.mod/a, EPS));
    assert (approxEqual(c10.arg, c1.arg, EPS));

    auto c11 = a - c1;
    assert (c11.re == a-c1.re);
    assert (c11.im == -c1.im);

    auto c12 = a / c1;
    assert (approxEqual(c12.mod, a/c1.mod, EPS));
    assert (approxEqual(c12.arg, -c1.arg, EPS));
}
