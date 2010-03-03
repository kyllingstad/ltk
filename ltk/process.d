/** Facilities for executing other processes.

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad. All rights reserved.
    License:    Boost License 1.0
*/
module ltk.process;


import core.stdc.errno;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.posix.stdio;
import core.sys.posix.unistd;
import core.sys.posix.sys.wait;

import std.algorithm;
import std.array;
import std.contracts;
import std.conv;
import std.path;
import std.stdio;
import std.string;

import ltk.file;



// DMD BUG 3604
// Until this is fixed, we declare posix.unistd.pipe() here:
extern(C) int pipe(int[2]*);




/** A running process. */
struct Pid
{
private:
    // Process ID
    int _pid = -1;

    // The file descriptors of the process' standard input,
    // output and error streams, respectively.
    int _stdinFD = -1;
    int _stdoutFD = -1;
    int _stderrFD = -1;


public:

    /** The process ID. */
    @property int pid()  { return _pid; }


    /** The standard input, output and error streams of the process,
        respectively. Stdin is opened for writing, while stdout and
        stderr are opened for reading.

        Note that the corresponding ProcessOptions.redirectStdXXX
        option(s) must be passed to spawnProcess() for these streams
        to be valid. An exception will be thrown if one attempts to
        write to or read from an unredirected stream.
    */
    @property File stdin()
    {
        auto f = fdopen(_stdinFD, "w");
        errnoEnforce(f != null, "Unable to open stdin pipe");
        return File.wrapFile(f);
    }

    /// ditto
    @property File stdout()
    {
        auto f = fdopen(_stdoutFD, "r");
        errnoEnforce(f != null, "Unable to open stdout pipe");
        return File.wrapFile(f);
    }

    /// ditto
    @property File stderr()
    {
        auto f = fdopen(_stderrFD, "r");
        errnoEnforce(f != null, "Unable to open stderr pipe");
        return File.wrapFile(f);
    }


    /** Wait for the spawned process to terminate.
        If the process terminates normally, this function returns
        its exit status.
        If the process is terminated by a signal, a
        ChildTerminatedException with the relevant signal number
        is thrown.
    */
    int wait()
    {
        int status;
        while(true)
        {
            waitpid(_pid, &status, 0);
            if (WIFEXITED(status))
            {
                return WEXITSTATUS(status);
            }
            else if (WIFSIGNALED(status))
            {
                throw new ChildTerminatedException(_pid, WTERMSIG(status));
            }
        }
        assert (0);
    }
}



/** Exception thrown if a process that is wait()ed for
    is terminated by a signal.
*/
class ChildTerminatedException : Exception
{
    /** The process ID of the terminated process. */
    immutable int pid;
    
    /** The signal that terminated the process. */
    immutable int signal;

    this (int p, int s)
    {
        super ("Process "~to!string(p)~" was terminated by signal "
            ~to!string(s));
        pid = p;
        signal = s;
    }
}



/** Options that can be ORed together and passed to spawnProcess. */
enum ProcessOptions
{
    none = 0,

    /** Redirect the spawned process' standard input, output, and/or
        error streams so they can be written (stdin) or read (stdout,
        stderr) by the parent process. Use the Pid.stdXXX properties
        to get the file handles of the streams.
    */
    redirectStdin = 1,

    /// ditto
    redirectStdout = 2,

    /// ditto
    redirectStderr = 4,


    /** If the executable filename does not contain a path separator
        character (/ on POSIX, \ on Windows), search for it in the
        paths specified in the PATH environment variable.
    */
    searchPath = 8,
}



/** Spawn a new process.
    This function returns immediately, and the child process
    executes in parallel with its parent. To wait for the
    child process to finish, call Pid.wait().

    Example:
    ---
    import std.stdio, ltk.process;

    void main()
    {
        // The 'cat' program will echo everything we send to it.
        auto pid = spawnProcess("/bin/cat", null,
            ProcessOptions.redirectStdin | ProcessOptions.redirectStdout);

        auto pin = pid.stdin;
        auto pout = pid.stdout;

        // Read lines from the terminal and send them to cat,
        // then read and print its response.
        do
        {
            write("> ");
            auto input = stdin.readln();
            pin.write(inp);
            pin.flush();

            auto output = pout.readln();
            write("< ", output);
        } while (chomp(input) != "exit");
    }
    ---
    $(I cat) will automatically exit when it has reached the end
    of its input stream. In the example above this happens when
    the user types "quit", because all files are closed when
    the main() function returns. This includes the pipes to the
    child process.
    
    In general it is a good idea
    to wait for all child processes to finish so they don't
    become 'zombies'. As an example, here's a program that
    executes two programs in parallel:
    ---
    import ltk.process;

    void main(string[] args)
    {
        // Start two programs in parallel and wait for both to finish.
        assert (args.length == 3);

        auto pid1 = spawnProcess(args[1]);
        auto pid2 = spawnProcess(args[2]);

        pid1.wait();
        pid2.wait();
    }
    ---
*/
Pid spawnProcess(string executable, string[] args = null,
    ProcessOptions options = ProcessOptions.none)
{
    bool redirectStdin  = (options & ProcessOptions.redirectStdin)  > 0;
    bool redirectStdout = (options & ProcessOptions.redirectStdout) > 0;
    bool redirectStderr = (options & ProcessOptions.redirectStderr) > 0;
    bool searchPath     = (options & ProcessOptions.searchPath)     > 0;

    // Make sure the file exists and is executable.
    if (searchPath && (executable.indexOf(std.path.sep) == -1))
    {
        executable = searchPathFor(executable);
        enforce(executable != null, "Executable file not found: "~executable);
    }
    else
    {
        enforce(executable != null  &&  isExecutable(executable),
            "Executable file not found: "~executable);
    }

    // Set up pipes.
    int[2] stdinFDs;
    int[2] stdoutFDs;
    int[2] stderrFDs;

    int pipeStatus = 0;
    if (redirectStdin)  pipeStatus += pipe(&stdinFDs);
    if (redirectStdout) pipeStatus += pipe(&stdoutFDs);
    if (redirectStderr) pipeStatus += pipe(&stderrFDs);
    errnoEnforce (pipeStatus == 0, "Unable to create pipe");

    Pid pid;
    pid._pid = fork();
    errnoEnforce (pid._pid >= 0, "Cannot spawn new process");
    
    if (pid._pid == 0)
    {
        // Child process

        // Close the pipe ends we don't need, redirect streams,
        // and close the old file descriptors.
        if (redirectStdin)
        {
            close(stdinFDs[1]);
            dup2(stdinFDs[0], STDIN_FILENO);
            close(stdinFDs[0]);
        }
        if (redirectStdout)
        {
            close(stdoutFDs[0]);
            dup2(stdoutFDs[1], STDOUT_FILENO);
            close(stdoutFDs[1]);
        }
        if (redirectStderr)
        {
            close(stderrFDs[0]);
            dup2(stderrFDs[1], STDERR_FILENO);
            close(stderrFDs[1]);
        }

        // Execute program
        execv(toStringz(executable), toArgz(executable, args));
        throw new Error("Failed to execute program ("~
            to!string(strerror(errno))~")");
    }
    else
    {
        // Parent process

        // Close the pipe ends we don't need and store the file
        // descriptors of the open ends.
        if (redirectStdin)
        {
            close(stdinFDs[0]);
            pid._stdinFD  = stdinFDs[1];
        }
        if (redirectStdout)
        {
            close(stdoutFDs[1]);
            pid._stdoutFD = stdoutFDs[0];
        }
        if (redirectStderr)
        {
            close(stderrFDs[1]);
            pid._stderrFD = stderrFDs[0];
        }

        return pid;
    }
}


private const(char)** toArgz(string path, const string[] args)
{
    alias const(char)* stringz_t;
    auto argz = new stringz_t[](args.length+2);
    
    argz[0] = toStringz(path);
    foreach(i; 0 .. args.length)
    {
        argz[i+1] = toStringz(args[i]);
    }
    argz[$-1] = null;
    return argz.ptr;
}



/** Convenience function that spawns a new process, waits
    for it to finish, and returns its exit code.
*/
int execute(string executable, string[] args = null)
{
    return spawnProcess(executable, args).wait();
}



/** Execute the given command in the user's default shell (or
    '/bin/sh' if the default shell can't be determined).
    This function blocks until the command returns, and returns
    the exit code of the command.

    The output of the command can be stored in a string and returned
    through the optional output argument.
*/
int shell(string cmd)
{
    string[2] args = ["-c", cmd];
    return spawnProcess(getShell(), ["-c", cmd]).wait();
}


/// ditto
int shell(string cmd, out string output)
{
    string[2] args = ["-c", cmd];
    auto pid = spawnProcess(getShell, ["-c", cmd],
        ProcessOptions.redirectStdout);
    
    Appender!string a;
    foreach (line; pid.stdout.byLine(File.KeepTerminator.yes))  a.put(line);
    output = a.data;
    return pid.wait();
}


private string getShell()
{
    auto shellPathz = getenv("SHELL");
    if (shellPathz == null)
        return "/bin/sh";
    return to!string(shellPathz);
}



version(Windows)  enum char pathListSeparator = ';';
else              enum char pathListSeparator = ':';

private string searchPathFor(string executable)
{
    auto pathz = getenv("PATH");
    if (pathz == null)  return null;

    foreach (dir; splitter(to!string(pathz), pathListSeparator))
    {
        auto execPath = join(dir, executable);
        if (isExecutable(execPath))  return execPath;
    }

    return null;
}
