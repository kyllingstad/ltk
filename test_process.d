import std.file;
import std.stdio;
import std.string;
import ltk.process;
import ltk.stdio;

version(Posix)
{
    import core.sys.posix.signal;
}


void main()
{
    immutable string src = "deleteme.d";
    immutable string exe = "./deleteme";

    void compile(string code, string libs = null)
    {
        // Write and compile
        std.file.write(src, code);
        string compile = "dmd "~src~(libs.length>0 ? " "~libs : "");
        assert (shell(compile).status == 0, "Failed compilation: "~compile);
    }

    void ok()
    {
        static int i = 0;
        ++i;
        writeln(i, " OK");
    }
    
    void pok()
    {
        static int i = 0;
        ++i;
        writeln("P", i, " OK");
    }


    Pid pid;


    // Test 1:  Start a process that returns normally.
    compile(q{
        void main() { }
    });
    assert (wait(spawnProcess(exe)) == 0);
    ok();


    // Test 2:  Start a process that returns a nonzero exit code.
    compile(q{
        int main() { return 123; }
    });
    assert (wait(spawnProcess(exe)) == 123);
    ok();


    // Test 3:  Supply arguments.
    compile(q{
        int main(string[] args)
        {
            if (args.length == 3 && args[1] == "hello" && args[2] == "world")
                return 0;
            return 1;
        }
    });
    assert (wait(spawnProcess(exe, ["hello", "world"])) == 0);
    assert (wait(spawnProcess(exe~" hello world")) == 0);
    ok();


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
    assert (wait(spawnProcess(exe, null, env)) == 0);
    assert (wait(spawnProcess(exe, env)) == 0);
    ok();


    // Test 5: Redirect input.
    compile(q{
        import std.stdio, std.string;
        int main()
        {
            if (stdin.readln().chomp() == "hello world") return 0;
            return 1;
        }
    });
    auto pipe5 = Pipe.create();
    pid = spawnProcess(exe, pipe5.readEnd);
    pipe5.writeEnd.write("hello world\n");
    assert (wait(pid) == 0);
    pipe5.close();
    ok();


    // Test 6: Redirect output and error.
    compile(q{
        import std.stdio;
        void main()
        {
            stdout.write("hello output");
            stderr.write("hello error");
        }
    });
    auto pipe6o = Pipe.create();
    auto pipe6e = Pipe.create();
    pid = spawnProcess(exe, ustdin, pipe6o.writeEnd, pipe6e.writeEnd);
    auto buf6 = new char[20];
    auto rd6 = pipe6o.readEnd.read(buf6);
    assert (rd6 == "hello output");
    rd6 = pipe6e.readEnd.read(buf6);
    assert (rd6 == "hello error");
    wait(pid);
    ok();


    // Test 7: Test execute().
    compile(q{
        import std.stdio;
        int main(string[] args)
        {
            stdout.write("hello world");
            return args.length;
        }
    });
    string out7;
    auto ret7 = execute(exe~" foo");
    assert (ret7.status == 2  &&  ret7.output == "hello world");
    ret7 = execute(exe, ["foo", "bar"]);
    assert (ret7.status == 3  &&  ret7.output == "hello world");
    ok();


    // Test 8: Test waitAny().
    compile(q{
        import core.thread, std.conv;
        enum milliseconds = 10_000;
        int main(string[] args)
        {
            int t = to!int(args[1]);
            Thread.sleep(t*milliseconds);
            return t;
        }
    });
    auto pid8_1 = spawnProcess(exe, ["100"]);
    auto pid8_2 = spawnProcess(exe, ["200"]);
    auto stat8 = waitAny();
    assert (stat8.any && stat8.status == 100 && stat8.pid == pid8_1);
    stat8 = waitAny();
    assert (stat8.any && stat8.status == 200 && stat8.pid == pid8_2);
    stat8 = waitAny();
    assert (!stat8.any);
    ok();


    // Test 9: Test waitAll().
    compile(q{
        import core.thread, std.conv;
        enum milliseconds = 10_000;
        int main(string[] args)
        {
            int t = to!int(args[1]);
            Thread.sleep(t*milliseconds);
            return t;
        }
    });
    auto pid9_1 = spawnProcess(exe, ["100"]);
    auto pid9_2 = spawnProcess(exe, ["200"]);
    auto stat9 = waitAll();
    assert (stat9[pid9_1] == 100);
    assert (stat9[pid9_2] == 200);
    assert (stat9.length == 2);
    ok();


version (Posix)
{
    // POSIX test 1: Terminate by signal.
    compile(q{
        void main() { while(true) { } }
    });
    pid = spawnProcess(exe);
    kill(pid.processID, SIGTERM);
    assert (wait(pid) == -SIGTERM);
    pok();


    // POSIX test 2: Pseudo-test of path-searching algorithm.
    auto pipeX = Pipe.create();
    pid = spawnProcess("ls -l", ustdin, pipeX.writeEnd);
    bool found = false;
    foreach (line; pipeX.readEnd.buffered.byLine)
    {
        if (line.indexOf("deleteme.d") >= 0)  found = true;
    }
    assert (wait(pid) == 0);
    assert (found == true);
    pok();
}

    
    // Clean up.
    std.file.remove("deleteme");
    std.file.remove("deleteme.d");
    std.file.remove("deleteme.o");
}


