/** Module for using the Common Gateway Interface from D.

    Basic usage:
    ---
    auto cgi = new CGI;
    scope(exit) cgi.flush();

    cgi.addHeader("Content-type: text/html");
    cgi.addHeader("Content-length: %d", htmlFile.length);

    auto htmlFile = std.file.readText("somefile.html");
    cgi.write(htmlFile);
    ---
*/
module ltk.web.cgi;


import std.algorithm;
import std.array;
import std.exception;
import std.format;
import std.process;
import std.range;
import std.stdio;
import std.string;




version (TestCGI)
{
    void main()
    {
        auto cgi = new CGI;
        cgi.setStatus(404, "Not Found");
        cgi.addHeaderField("Foo", "fubared");
        cgi.addHeaderField("Content-Type", "application/pdf");

        cgi.writeln("<html><body>");
        cgi.writefln("<h%s>Hello World</h%1$s>", 1);
        cgi.writeln("<p>GET variables: ", cgi.getData, "</p>");
        cgi.write("</body>");
        cgi.writef("</%s>\n", "html");
    }
}

enum httpNewline = "\r\n";




/** A class for making CGI applications. */
class CGI
{
private:

    // Variables to hold the HTTP response
    int statusCode;
    string statusMsg;
    bool statusSet = false;

    bool autoContentType = true;

    Appender!string headerBuffer, outputBuffer;
    bool flushedHeader = false;

    // Total number of class instances.
    static int numInstances = 0;



public:

    /** Construct a new CGI class instance.

        It is extremely rare that one should need to create more than
        one CGI class instance per application.  For this reason, the
        class checks whether one has been created already, and throws
        an exception if this is the case.  To disable this behaviour,
        set allowMany to true.
    */
    this(bool allowMany = false)
    {
        enforce(allowMany || numInstances == 0,
            "ltk.web.cgi.CGI has already been instantiated");
        ++numInstances;

        // Prepare output buffers
        headerBuffer = appender!string();
        outputBuffer = appender!string();

        // Read environment variables
        queryString = environment.get("QUERY_STRING");


        // Parse query string
        string[string] decomposedQueryString;
        foreach (s; splitter(cast(string) queryString, '&'))
        {
            auto p = s.countUntil("=");
            if (p == -1)
                decomposedQueryString[percentDecode(s)] = "";
            else
                decomposedQueryString[percentDecode(s[0 .. p])] =
                    percentDecode(s[p+1 .. $]);
        }
        getData = cast(immutable) decomposedQueryString;
    }




    /** Set the HTTP status code and reason phrase.

        It is completely optional to use this method.  If you do not
        set the status explicitly, the web server will automatically
        send an appropriate status.

        It is preferred to use this method over addHeader("Status: ..."),
        because it ensures only one status line is sent to the web server.
        ---
        cgi.setStatus(404, "Not found");
        ---
    */
    void setStatus(int code, string reason)
    {
        statusCode = code;
        statusMsg = reason;
        statusSet = true;
    }




    /** Add a header field.

        Note:
        If no "Content-Type" or "Location" header is added, the following
        is automatically added when flushHeader() is called:
        ---
        Content-Type: text/html; charset=utf-8
        ---

        Examples:
        ---
        cgi.addHeaderField("Content-Type", "application/pdf");
        ---
    */
    void addHeaderField(string fieldName, string fieldValue)
    {
        enforce(!flushedHeader,
            "Cannot write header data after flushHeader() has been called");

        if (icmp(fieldName, "Content-Type") == 0 ||
            icmp(fieldName, "Location") == 0)
        {
            autoContentType = false;
        }

        headerBuffer.put(fieldName);
        headerBuffer.put(": ");
        headerBuffer.put(fieldValue);
        headerBuffer.put(httpNewline);
    }




    /** Send header data to client.

        There is normally no need to call this function directly, as it is
        done automatically by the first call to flush().
    */
    void flushHeader()
    {
        if (flushedHeader) return;

        if (statusSet)
        {
            stdout.writefln("Status: %d %s", statusCode, statusMsg);
        }
        if (autoContentType)
        {
            stdout.writeln("Content-Type: text/html; charset=utf-8");
        }
        stdout.write(headerBuffer.data);
        stdout.writeln();

        flushedHeader = true;
    }




    /** Write to the output buffer.

        The contents of the output buffer are sent to the client when
        flush() is called (which is done automatically when this CGI
        instance is garbage collected).

        These functions have the same signatures, and work in the same
        way, as the corresponding functions in std.stdio.
    */
    void write(T...)(T args)
    {
        foreach (arg; args)
        {
            static if (isOutputRange!(typeof(outputBuffer), typeof(arg)))
                put(outputBuffer, arg);
            else
                formattedWrite(outputBuffer, "%s", arg);
        }
    }

    /// ditto
    void writeln(T...)(T args)
    {
        this.write(args, httpNewline);
    }

    /// ditto
    void writef(Char, T...)(in Char[] fmt, T args)
    {
        formattedWrite(outputBuffer, fmt, args);
    }

    /// ditto
    void writefln(Char, T...)(in Char[] fmt, T args)
    {
        this.writef(fmt, args);
        outputBuffer.put(httpNewline);
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
        outputBuffer = appender!string();
    }




    /** The raw query string (the part following a '?' in the URL). */
    immutable string queryString;

    /** Variables passed to the program using the HTTP GET method. */
    immutable string[string] getData;
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
