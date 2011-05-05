/** Various utilities.

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad. All rights reserved.
    License:    Boost License 1.0
*/
module ltk.util;


import std.file;
import std.string;



/** Parse an ini file and return its contents as an associative array.

    Example of an ini file:
    ---
    ; Comment lines in ini files normally start with semicolons.
    # This implementation also supports comments that start with a hash,
    # since its author is a Linux user that thinks hashes look better.

    [Section 1]
    key1=This is value one. It is assigned to key1
    anotherKey=This is the second value

    [Yet another section]
    foo=bar
    andSo=on
    ---

    The values in the above ini file are accessed as follows:
    ---
    auto ini = parseIni("myIniFile.ini");
    auto valueOfAnotherKey = ini["Section 1"]["anotherKey"];
    assert (valueOfAnotherKey == "This is the second value");
    ---
*/
string[string][string] parseIni(string path)
{
    void parseException(size_t n, string e)
    {
        throw new Exception(format("Error parsing %s, line %s: %s",
            path, n+1, e));
    }


    // Split file into lines.
    string[] lines = splitlines(readText(path));

    // Provide a default unnamed section.
    string currentSection = "";

    // Create and fill return array.
    string[string][string] values;

    foreach (lineNo, lineText; lines)
    {
        string text = strip(lineText);

        // Skip empty lines and comment lines
        if (text.length == 0)  continue;
        if (text[0] == ';'  ||  text[0] == '#')  continue;

        // Is this a section?
        if (text[0] == '[')
        {
            if (text[$-1] != ']')
            {
                parseException(
                    lineNo,
                    "Trailing ']' missing in section header.");
            }
            currentSection = text[1 .. $-1];
            continue;
        }

        // Is this a key/value pair?
        auto delimPos = text.indexOf('=');
        if (delimPos < 1)
        {
            parseException(lineNo, "Not a key=value pair.");
        }
        string key = strip(text[0 .. delimPos]);
        string val = strip(text[delimPos+1 .. $]);
        values[currentSection][key] = val;
    }

    return values;
}

