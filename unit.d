#!/usr/local/bin/rdmd --shebang -unittest --force
module unit;


import std.stdio;
import ltk.array;
import ltk.filelock;
import ltk.path;
import ltk.posix.sys.un;
import ltk.process;
import ltk.stdio;
import ltk.types;
import ltk.util;

import ltk.web.cgi;



void main() { writeln("All unittests passed."); }