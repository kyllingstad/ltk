/** Module for using CGI from D.  It contains a lot of free functions,
    and it is recommended to use a named import:
    ---
    import CGI = ltk.web.cgi;

    void main()
    {
        CGI.init();
        ...
    }
*/
module ltk.web.cgi;


import std.algorithm;
import std.array;
import std.exception;
import std.format;
import std.process;
import std.stdio;




version (TestCGI)
{
    void main()
    {
        writeln("GET variables: ", getData);
    }
}




// Variables to hold the HTTP response
private string statusLine = "200 OK";
private Appender!(char[]) headerBuffer, outputBuffer;
private bool flushedHeader = false;

static this()
{
    headerBuffer = appender!(char[])();
    outputBuffer = appender!(char[])();
}

static ~this() { flush(); }




/** Write to the output buffer.

    The contents of the output buffer are sent to the client when
    flush() is called (which is done automatically when the program
    terminates).
*/
void writef(Char, T...)(in Char[] fmt, T args)
{
    formattedWrite(outputBuffer, fmt, args);
}

/// ditto
void writefln(Char, T...)(in Char[] fmt, T args)
{
    .writef(fmt, args);
    outputBuffer.put('\n');
}




/** Flush the output buffer.

    This function first calls flushHeader() (which does nothing if
    the headers have already been sent), and then it sends the contents
    of the output buffer to the client.
*/
void flush()
{
    flushHeader();
    stdout.write(outputBuffer.data);
    stdout.flush();
    outputBuffer.clear();
}
    



/** Write header data. */
void addHeader(Char, T...)(in Char[] fmt, T args)
{
    enforce(!flushedHeader,
        "Cannot write header data after flushHeader() has been called");
    formattedWrite(headerBuffer, fmt, args);
    headerBuffer.put('\n');
}




/** Send header data to client.

    There is normally no need to call this function directly, as it is
    done automatically by the first call to flush(), or at program
    termination.
*/
void flushHeader()
{
    if (flushedHeader) return;

    stdout.writeln("HTTP/1.0 ", statusLine);
    stdout.write(headerBuffer.data);
    stdout.writeln();
    headerBuffer.clear();
}




/** The raw query string (the part following a '?' in the URL). */
immutable string queryString;




/** Variables passed to the program using the HTTP GET method. */
immutable string[string] getData;


static this()
{
    // Read environment variables.
    queryString = environment.get("QUERY_STRING");


    // Parse query string
    string[string] decomposedQueryString;
    foreach (s; splitter(cast(string) queryString, '&'))
    {
        auto p = s.indexOf("=");
        if (p == -1)
            decomposedQueryString[percentDecode(s)] = "";
        else
            decomposedQueryString[percentDecode(s[0 .. p])] =
                percentDecode(s[p+1 .. $]);
    }
    getData = cast(immutable) decomposedQueryString;


}




/** Decode percent-encoded strings.

    Example:
    ---
    assert (percentDecode("Hello%20World%21") == "Hello World!");
    ---
*/
string percentDecode(string text)
{
    auto ret = new char[text.length];

    int j = 0;
    for (int i=0; i<text.length; ++i)
    {
        auto c = text[i];
        if (c == '+')
        {
            ret[j] = ' ';
            ++j;
        }
        else if (c == '%' && i+3 <= text.length)
        {
            try
            {
                ret[j] = cast(char) fromHex(text[i+1 .. i+3]);
                ++j;
                i += 2;
            }
            catch (Exception e)
            {
                ret[j] = '%';
                ++j;
            }
        }
        else
        {
            ret[j] = text[i];
            ++j;
        }
    }

    return cast(string) ret[0 .. j];
}


unittest
{
    assert (percentDecode("Hey+there") == "Hey there");
    assert (percentDecode("Hey%20there") == "Hey there");
    assert (percentDecode("Hey+there%21") == "Hey there!");
    assert (percentDecode("Hey%2Othere%2") == "Hey%2Othere%2");
}




int fromHex(in char[] hexNumber)
{
    int hexDigit(char c)
    {
        if (c >= '0' && c <= '9')
            return c - '0';
        else if (c >= 'A' && c <= 'F')
            return 10 + c - 'A';
        else if (c >= 'a' && c <= 'f')
            return 10 + c - 'a';
        else
            throw new Exception("Invalid hex digit: "~c);
    }

    int sum = 0, multiplier = 1;
    foreach_reverse (c; hexNumber)
    {
        sum += multiplier * hexDigit(c);
        multiplier *= 16;
    }

    return sum;
}


unittest
{
    assert (fromHex("1") == 1);
    assert (fromHex("C") == 12);
    assert (fromHex("d") == 13);
    assert (fromHex("1A") == 26);
    assert (fromHex("5b8F") == 23_439);
}
