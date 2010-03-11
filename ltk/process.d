/** Facilities for executing other processes.

    Authors:    Lars Tandle Kyllingstad
    Copyright:  Copyright (c) 2010, Lars T. Kyllingstad. All rights reserved.
    License:    Boost License 1.0
*/
module ltk.process;


version(Posix)
{
    import core.stdc.errno;
    import core.stdc.string;
    import core.sys.posix.stdio;
    import core.sys.posix.unistd;
    import core.sys.posix.sys.wait;
}

import std.algorithm;
import std.array;
import std.contracts;
import std.conv;
import std.path;
import std.stdio;
import std.string;

import ltk.file;
import ltk.system;



version(Posix)
{
    // DMD BUG 3604
    // Until this is fixed, we declare posix.unistd.pipe() here:
    extern(C) int pipe(int[2]*);

    // Some sources say this is supposed to be defined in unistd.h,
    // but the POSIX spec doesn't mention it:
    extern(C) extern __gshared const char** environ;
}




/** Spawn a new process.

    This function returns immediately, and the child process
    executes in parallel with its parent.  To wait for the
    child process to finish, call Pid.wait().  (In general
    one should always do this, to avoid child processes
    becoming 'zombies' when the parent process exits.
    Scope guards are perfect for this, see below for examples.)

    Unless a directory is specified in the command (or name)
    parameter, this function will search the directories in the
    PATH environment variable for the program.

    Params:
        command = A string containing the program name and
            its arguments, separated by spaces.  If the program
            name or any of the arguments contain spaces, use
            the third or fourth form of this function, where
            they are specified separately.

        environmentVars = The environment variables for the
            child process can be specified using this parameter.
            If it is omitted, the child process executes in the
            same environment as the parent process.

        stdin_ = The standard input stream of the child process.
            This can be any File that is opened for reading.  By
            default the child process inherits the parent's input
            stream.

        stdout_ = The standard output stream of the child process.
            This can be any File that is opened for writing.  By
            default the child process inherits the parent's output
            stream.

        stderr_ = The standard error stream of the child process.
            This can be any File that is opened for writing.  By
            default the child process inherits the parent's error
            stream.

        closeStreams = Control which of the given File objects are
            closed in the parent process when this function returns
            (see below for more info).

        name = The name of the executable file.

        args = The command line arguments to give to the program.
            (There is no need to specify the program name as the
            zeroth argument, this is done automatically.)

    Note:
    If you pass a File object that is $(I not) one of the standard
    input/output/error streams of the parent process, that stream
    will by default be closed in the parent process when this
    function returns.  Use the closeStreams argument to control which
    streams are closed or not.

    Examples:
    Open firefox on the D homepage and wait for it to complete:
    ---
    auto pid = spawnProcess("firefox http://www.digitalmars.com/d/2.0");
    pid.wait();
    ---
    Use the "ls" command to retrieve a list of files:
    ---
    string[] files;
    auto pipe = Pipe.create();

    auto pid = spawnProcess("ls", stdin, pipe.writeEnd);
    scope(exit) pid.wait();

    foreach (f; pipe.readEnd.byLine)  files ~= f.idup;
    ---
    Use the "ls -l" command to get a list of files, pipe the output
    to "grep" and let it filter out all files except D source files,
    and write the output to the file "dfiles.txt":
    ---
    // Let's emulate the command "ls -l | grep \.d > dfiles.txt"
    auto pipe = Pipe.create();
    auto file = File("dfiles.txt", "w");

    auto lsPid = spawnProcess("ls -l", stdin, pipe.writeEnd);
    scope(exit) lsPid.wait();
    
    auto grPid = spawnProcess("grep \\.d", pipe.readEnd, file);
    scope(exit) grPid.wait();
    ---
    Open a set of files with spaces in their names in OpenOffice
    Writer, and make it print any error messages to the standard
    output stream:
    ---
    spawnProcess("oowriter", ["my document.odt", "your document.odt"],
        stdin, stdout, stdout);
    ---
*/
Pid spawnProcess(string command,
    File stdin_ = std.stdio.stdin,
    File stdout_ = std.stdio.stdout,
    File stderr_ = std.stdio.stderr,
    CloseStreams closeStreams = CloseStreams.all)
{
    auto splitCmd = split(command);
    return spawnProcessImpl(splitCmd[0], splitCmd[1 .. $],
        environ,
        stdin_, stdout_, stderr_, closeStreams);
}


/// ditto
Pid spawnProcess(string command, string[string] environmentVars,
    File stdin_ = std.stdio.stdin,
    File stdout_ = std.stdio.stdout,
    File stderr_ = std.stdio.stderr,
    CloseStreams closeStreams = CloseStreams.all)
{
    auto splitCmd = split(command);
    return spawnProcessImpl(splitCmd[0], splitCmd[1 .. $],
        toEnvz(environmentVars),
        stdin_, stdout_, stderr_, closeStreams);
}


/// ditto
Pid spawnProcess(string name, const string[] args,
    File stdin_ = std.stdio.stdin,
    File stdout_ = std.stdio.stdout,
    File stderr_ = std.stdio.stderr,
    CloseStreams closeStreams = CloseStreams.all)
{
    return spawnProcessImpl(name, args,
        environ,
        stdin_, stdout_, stderr_, closeStreams);
}


/// ditto
Pid spawnProcess(string name, const string[] args,
    string[string] environmentVars,
    File stdin_ = std.stdio.stdin,
    File stdout_ = std.stdio.stdout,
    File stderr_ = std.stdio.stderr,
    CloseStreams closeStreams = CloseStreams.all)
{
    return spawnProcessImpl(name, args,
        toEnvz(environmentVars),
        stdin_, stdout_, stderr_, closeStreams);
}


// The actual implementation of the above.
private Pid spawnProcessImpl(string name, const string[] args,
    const char** envz, File stdin_, File stdout_, File stderr_,
    CloseStreams closeStreams)
{
    // Make sure the file exists and is executable.
    if (name.indexOf(std.path.sep) == -1)
    {
        name = searchPathFor(name);
        enforce(name != null, "Executable file not found: "~name);
    }
    else
    {
        enforce(name != null  &&  isExecutable(name),
            "Executable file not found: "~name);
    }

    // Get the file descriptors of the streams.
    int stdinFD  = core.stdc.stdio.fileno(stdin_.getFP());
    errnoEnforce(stdinFD != -1, "Invalid stdin stream");
    int stdoutFD = core.stdc.stdio.fileno(stdout_.getFP());
    errnoEnforce(stdoutFD != -1, "Invalid stdout stream");
    int stderrFD = core.stdc.stdio.fileno(stderr_.getFP());
    errnoEnforce(stderrFD != -1, "Invalid stderr stream");

    Pid pid;
    pid._pid = fork();
    errnoEnforce (pid._pid >= 0, "Cannot spawn new process");
    
    if (pid._pid == 0)
    {
        // Child process

        // Redirect streams and close the old file descriptors.
        // In the case that stderr is redirected to stdout, we need
        // to backup the file descriptor since stdout may be redirected
        // as well.
        if (stderrFD == STDOUT_FILENO)  stderrFD = dup(stderrFD);
        dup2(stdinFD,  STDIN_FILENO);
        dup2(stdoutFD, STDOUT_FILENO);
        dup2(stderrFD, STDERR_FILENO);

        // Close the old file descriptors, unless they are
        // either of the standard streams.
        if (stdinFD  > STDERR_FILENO)  close(stdinFD);
        if (stdoutFD > STDERR_FILENO)  close(stdoutFD);
        if (stderrFD > STDERR_FILENO)  close(stderrFD);

        // Execute program
        execve(toStringz(name), toArgz(name, args), envz);
        throw new Error("Failed to execute program ("~
            to!string(strerror(errno))~")");
    }
    else
    {
        // Parent process:  Close streams and return.

        if ((stdinFD > STDERR_FILENO && (closeStreams & CloseStreams.stdin))
            || (closeStreams & CloseStreams.forceStdin))  stdin_.close();

        if ((stdoutFD > STDERR_FILENO && (closeStreams & CloseStreams.stdout))
            || (closeStreams & CloseStreams.forceStdout))  stdout_.close();

        if ((stderrFD > STDERR_FILENO && (closeStreams & CloseStreams.stderr))
            || (closeStreams & CloseStreams.forceStderr))  stderr_.close();

        return pid;
    }
}

// Search the PATH variable for the given executable file,
// (checking that it is in fact executable).
version(Posix)  private string searchPathFor(string executable)
{
    enum char pathListSeparator = ':';

    auto pathz = getEnv("PATH");
    if (pathz == null)  return null;

    foreach (dir; splitter(to!string(pathz), pathListSeparator))
    {
        auto execPath = join(dir, executable);
        if (isExecutable(execPath))  return execPath;
    }

    return null;
}

// Convert a C array of C strings to a string[] array,
// setting the program name as the zeroth element.
private const(char)** toArgz(string prog, const string[] args)
{
    alias const(char)* stringz_t;
    auto argz = new stringz_t[](args.length+2);
    
    argz[0] = toStringz(prog);
    foreach (i; 0 .. args.length)
    {
        argz[i+1] = toStringz(args[i]);
    }
    argz[$-1] = null;
    return argz.ptr;
}

// Convert a C array of C strings on the form "key=value"
// to a string[string] array.
private const(char)** toEnvz(const string[string] env)
{
    alias const(char)* stringz_t;
    auto envz = new stringz_t[](env.length+1);
    int i = 0;
    foreach (k, v; env)
    {
        envz[i] = (k~'='~v~'\0').ptr;
        i++;
    }
    envz[$-1] = null;
    return envz.ptr;
}




/** A running process. */
struct Pid
{
private:
    // Process ID
    int _pid = -1;


public:

    /** The process ID. */
    @property int pid()  { return _pid; }


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




/** Options controlling which streams are closed in the parent
    process when spawnProcess() returns.
*/
enum CloseStreams
{
    /** Don't close any of the streams. */
    none = 0,

    /** Close the streams that are given as the standard
        input/output/error streams of the child process,
        $(I unless) they are also the standard input/output/error
        streams of the parent process.
    */
    stdin  = 1,
    stdout = 2,                                         /// ditto
    stderr = 4,                                         /// ditto
    all = stdin | stdout | stderr,                      /// ditto

    /** Close the specified streams, $(I even if they are
        the standard streams of the parent process).
    */
    forceStdin  =  8,        
    forceStdout = 16,                                   /// ditto
    forceStderr = 32,                                   /// ditto
    forceAll = forceStdin | forceStdout | forceStderr   /// ditto
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




/** A unidirectional pipe.  Data is written to one end of the pipe
    and read from the other.
    ---
    auto p = Pipe.create();
    p.writeEnd.writeln("Hello World");
    assert (p.readEnd.readln().chomp() == "Hello World");
    ---
    Pipes can, for example, be used for interprocess communication
    by spawning a new process and passing one end of the pipe to
    the child, while the parent uses the other end.  See the
    spawnProcess() documentation for examples of this.
*/
struct Pipe
{
private:
    File _read, _write;


public:
    /** The read end of the pipe. */
    @property File readEnd() { return _read; }


    /** The write end of the pipe. */
    @property File writeEnd() { return _write; }


    /** Create a new pipe. */
    static Pipe create()
    {
        int[2] fds;
        errnoEnforce(pipe(&fds) == 0, "Unable to create pipe");

        Pipe p;
        
        // TODO: Using the internals of File like this feels like a hack,
        // but the File.wrapFile() function disables automatic closing of
        // the file.  Perhaps there should be a protected version of
        // wrapFile() that fills this purpose?
        p._read.p = new File.Impl(
            errnoEnforce(fdopen(fds[0], "r"), "Cannot open read end of pipe"),
            1, null);
        p._write.p = new File.Impl(
            errnoEnforce(fdopen(fds[1], "w"), "Cannot open write end of pipe"),
            1, null);

        return p;
    }


    /** Close both ends of the pipe.
    
        Normally it is not necessary to do this manually, as File objects
        are automatically closed when there are no more references to them.
        (See the std.stdio.File documentation for more info.)

        Note that if either end of the pipe has been passed to a child process,
        it will only be closed in the parent process.
    */
    void close()
    {
        _read.close();
        _write.close();
    }
}

unittest
{
    auto p = Pipe.create();
    p.writeEnd.writeln("Hello World");
    assert (p.readEnd.readln().chomp() == "Hello World");
}




/** Execute the given command in the user's default shell (or
    '/bin/sh' if the default shell can't be determined).
    This function blocks until the command returns, and returns
    the exit code of the command.

    The output of the command can be stored in a string and returned
    through the optional output argument.
    ---
    string myFiles;
    shell("ls -l", myFiles);
    ---
*/
version(Posix)  int shell(string cmd)
{
    string[2] args = ["-c", cmd];
    return spawnProcess(getShell(), ["-c", cmd]).wait();
}


/// ditto
version(Posix)  int shell(string cmd, out string output)
{
    string[2] args = ["-c", cmd];
    auto p = Pipe.create();
    auto pid = spawnProcess(getShell, ["-c", cmd], std.stdio.stdin, p.writeEnd);
    
    Appender!string a;
    foreach (line; p.readEnd.byLine(File.KeepTerminator.yes))  a.put(line);
    output = a.data;
    return pid.wait();
}


// Get the user's default shell, defaulting to /bin/sh.
version(Posix)  private string getShell()
{
    auto shellPathz = getEnv("SHELL");
    if (shellPathz == null)
        return "/bin/sh";
    return to!string(shellPathz);
}
