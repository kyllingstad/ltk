module ltk.file;


import core.sys.posix.unistd;
import std.string;



/** Check whether the file exists and can be executed by the
    current user.
*/
bool isExecutable(string path)
{
    return (access(toStringz(path), X_OK) == 0);
}

