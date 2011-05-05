#!/usr/local/bin/rdmd --shebang -m64 -unittest --force
module unit;


import std.stdio;
import ltk.array;
import ltk.filelock;
import ltk.path;
import ltk.process;
import ltk.range;
import ltk.stdio;
import ltk.types;
import ltk.util;

import ltk.web.cgi;



void main() { writeln("All unittests passed."); }
