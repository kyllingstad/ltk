import std.file;
import std.stdio;
import std.string;
import ltk.process;


void main()
{
    immutable string src = "deleteme.d";
    immutable string exe = "./"~src[0 .. $-2];

    void compile(string code, string libs = null)
    {
        // Write and compile
        std.file.write(src, code);
        string compile = "dmd "~src~(libs.length>0 ? " "~libs : "");
        assert (shell(compile) == 0, "Failed compilation: "~compile);
    }

    Pid pid;


    // Test 1:  Start a process that returns normally.
    compile(q{
        void main() { }
    });
    assert (spawnProcess(exe).wait() == 0);


    // Test 2:  Start a process that returns a nonzero exit code.
    compile(q{
        int main() { return 123; }
    });
    assert (spawnProcess(exe).wait() == 123);


    // Test 3:  Supply arguments.
    compile(q{
        int main(string[] args)
        {
            if (args.length == 3 && args[1] == "hello" && args[2] == "world")
                return 0;
            return 1;
        }
    });
    assert (spawnProcess(exe, ["hello", "world"]).wait() == 0);
    assert (spawnProcess(exe~" hello world").wait() == 0);


    // Test 4: Supply environment variables.
    compile(q{
        import core.stdc.stdlib;
        import std.conv;
        int main()
        {
            if (to!string(getenv("PATH")).length > 0)  return 1;
            if (to!string(getenv("hello")) != "world")  return 2;
            return 0;
        }
    });
    string[string] env;
    env["hello"] = "world";
    assert (spawnProcess(exe, null, env).wait() == 0);
    assert (spawnProcess(exe, env).wait() == 0);


    // Test 5: Redirect input.
    compile(q{
        import std.stdio, std.string;
        int main()
        {
            if (stdin.readln().chomp() == "hello world") return 0;
            return 1;
        }
    });
    pid = spawnProcess(exe, ProcessOptions.redirectStdin);
    pid.stdin.writeln("hello world");
    assert (pid.wait() == 0);


    // Test 6: Redirect output and error.
    compile(q{
        import std.stdio;
        void main()
        {
            stdout.writeln("hello output");
            stderr.writeln("hello error");
        }
    });
    pid = spawnProcess(exe, ProcessOptions.redirectStdout
        | ProcessOptions.redirectStderr);
    assert (pid.stdout.readln().chomp() == "hello output");
    assert (pid.stderr.readln().chomp() == "hello error");
    pid.wait();


}


