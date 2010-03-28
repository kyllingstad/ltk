/** Complex numbers.

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad. All rights reserved.
    License:    Boost License 1.0
*/
module ltk.complex;


import std.conv;
import std.math;
import std.numeric;
import std.traits;

version(unittest) import std.stdio;




/** Struct representing a complex number parametrised by a type T
*/
struct Complex(T)
{
    /** The real part of the number. */
    T re;

    /** The imaginary part of the number. */
    T im;




    /** Calculate the absolute value (or modulus) of the number. */
    @property T abs()
    {
        auto absRe = fabs(re);
        auto absIm = fabs(im);
        if (absRe < absIm)
            return absIm * sqrt(1 + (re/im)^^2);
        else
            return absRe * sqrt(1 + (im/re)^^2);

        // TODO: Will use std.math.hypot() later, but currently it
        // returns inf if either argument is zero.
        // return hypot(re, im);
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
    Complex opBinary(string op, U)(U x)
    {
        Complex w = this;
        return w.opOpAssign!(op~"=")(x);
    }


    Complex opBinaryRight(string op, U : T)(U a)  if (op == "+" || op == "*")
    {
        return opBinary!(op, U)(a);
    }

    
    Complex opBinaryRight(string op, U : T)(U a)  if (op == "-")
    {
        // a - this
        return Complex(a - re, -im);
    }


    Complex opBinaryRight(string op, U : T)(U a)  if (op == "/")
    {
        // a / this
        Complex w;

        if (fabs(re) < fabs(im))
        {
            FPTemporary!T ratio = re/im;
            FPTemporary!T adivd = a/(re*ratio + im);

            w.re = adivd*ratio;
            w.im = -adivd;
        }
        else
        {
            FPTemporary!T ratio = im/re;
            FPTemporary!T adivd = a/(re + im*ratio);

            w.re = adivd;
            w.im = -adivd*ratio;
        }

        return w;
    }


    // OpAssign operators:  Complex op= Complex
    Complex opOpAssign(string op)(Complex z)  if (op == "+=" || op == "-=")
    {
        mixin ("re "~op~" z.re;");
        mixin ("im "~op~" z.im;");
        return this;
    }


    Complex opOpAssign(string op)(Complex z)  if (op == "*=")
    {
    version (MultiplicationIsSlow)
    {
        FPTemporary!T ac = re*z.re;
        FPTemporary!T bd = im*z.im;

        auto temp = ac - bd;
        im = (re + im)*(z.re + z.im) - ac - bd;
        re = temp;
    }
    else
    {
        auto temp = re*z.re - im*z.im;
        im = im*z.re + re*z.im;
        re = temp;
    }
        return this;
    }


    Complex opOpAssign(string op)(Complex z)  if (op == "/=")
    {
        if (fabs(z.re) < fabs(z.im))
        {
            FPTemporary!T ratio = z.re/z.im;
            FPTemporary!T denom = z.re*ratio + z.im;

            auto temp = (re*ratio + im)/denom;
            im = (im*ratio - re)/denom;
            re = temp;
        }
        else
        {
            FPTemporary!T ratio = z.im/z.re;
            FPTemporary!T denom = z.re + z.im*ratio;

            auto temp = (re + im*ratio)/denom;
            im = (im - re*ratio)/denom;
            re = temp;
        }
        return this;
    }


    Complex opOpAssign(string op)(Complex z)  if (op == "^^=")
    {
        FPTemporary!T r = abs;
        FPTemporary!T t = arg;
        FPTemporary!T ab = r^^z.re * exp(-t*z.im);
        FPTemporary!T ar = t*z.re + log(r)*z.im;
        re = ab*cos(ar);
        im = ab*sin(ar);
        return this;
    }


    // OpAssign operators:  Complex op= real
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


    Complex opOpAssign(string op, U : T)(U a)  if (op == "^^=")
    {
        FPTemporary!T mo = abs^^a;
        FPTemporary!T ar = arg*a;
        re = mo*cos(ar);
        im = mo*sin(ar);
        return this;
    }


    Complex opOpAssign(string op, U)(U i)  if (op == "^^=" && isIntegral!U)
    {
        if (i == 0)
        {
            re = 1.0;
            im = 0.0;
        }
        else if (i == 1) { }
        else if (i == 2)
        {
            this *= this;
        }
        else if (i == 3)
        {
            auto z = this;
            this *= z;
            this *= z;
        }
        else
        {
            this ^^= cast(real) i;
        }
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

    // Check abs() and arg()
    auto c1 = Complex!double(1.0, 1.0);
    assert (approxEqual(c1.abs, sqrt(2.0), EPS));
    assert (approxEqual(c1.arg, PI_4, EPS));


    // Check unary operators.
    auto c2 = Complex!double(0.5, 2.0);

    assert (c2 == +c2);
    
    assert ((-c2).re == -(c2.re));
    assert ((-c2).im == -(c2.im));
    assert (c2 == -(-c2));


    // Check complex-complex operations.
    auto cpc = c1 + c2;
    assert (cpc.re == c1.re + c2.re);
    assert (cpc.im == c1.im + c2.im);

    auto cmc = c1 - c2;
    assert (cmc.re == c1.re - c2.re);
    assert (cmc.im == c1.im - c2.im);

    auto ctc = c1 * c2;
    assert (approxEqual(ctc.abs, c1.abs*c2.abs, EPS));
    assert (approxEqual(ctc.arg, c1.arg+c2.arg, EPS));

    auto cdc = c1 / c2;
    assert (approxEqual(cdc.abs, c1.abs/c2.abs, EPS));
    assert (approxEqual(cdc.arg, c1.arg-c2.arg, EPS));

    auto cec = c1^^c2;
    assert (approxEqual(cec.re, 0.11524131979943839881, EPS));
    assert (approxEqual(cec.im, 0.21870790452746026696, EPS));



    // Check complex-real operations.
    double a = 123.456;

    auto cpr = c1 + a;
    assert (cpr.re == c1.re + a);
    assert (cpr.im == c1.im);

    auto cmr = c1 - a;
    assert (cmr.re == c1.re - a);
    assert (cmr.im == c1.im);

    auto ctr = c1 * a;
    assert (ctr.re == c1.re*a);
    assert (ctr.im == c1.im*a);

    auto cdr = c1 / a;
    assert (approxEqual(cdr.abs, c1.abs/a, EPS));
    assert (approxEqual(cdr.arg, c1.arg, EPS));

    auto rpc = a + c1;
    assert (rpc == cpr);

    auto rmc = a - c1;
    assert (rmc.re == a-c1.re);
    assert (rmc.im == -c1.im);

    auto rtc = a * c1;
    assert (rtc == ctr);

    auto rdc = a / c1;
    assert (approxEqual(rdc.abs, a/c1.abs, EPS));
    assert (approxEqual(rdc.arg, -c1.arg, EPS));

    auto cer = c1^^3.0;
    assert (approxEqual(cer.abs, c1.abs^^3, EPS));
    assert (approxEqual(cer.arg, c1.arg*3, EPS));


    // Check Complex-int operations.
    foreach (i; 0..6)
    {
        auto cei = c1^^i;
        assert (approxEqual(cei.abs, c1.abs^^i, EPS));
        // Use cos() here to deal with arguments that go outside
        // the (-pi,pi] interval (only an issue for i>3).
        assert (approxEqual(cos(cei.arg), cos(c1.arg*i), EPS));
    }
}
