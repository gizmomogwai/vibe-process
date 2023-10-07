import std.stdio : writeln;
import vibe.core.process : pipeProcess, PipeInputStream, ProcessPipes;
import vibe.core.stream;
import vibe.stream.stdio;
import vibe.core.core : runApplication, exitEventLoop, runTask, Task;

// crashes sometimes or runs forever sometimes or run ok sometimes :(
void v3() {
    runTask!()(() nothrow {
            try {
                auto processPipes = pipeProcess(["./output.sh"]);
                {
                    auto stdoutStream = new StdoutStream;
                    scope (exit) stdoutStream.close();

                    auto stderrStream = new StderrStream;
                    scope (exit) stderrStream.close();

                    auto pump(S, T)(ref S input, ref T output)
                    {
                        return runTask!()(() nothrow {
                                try input.pipe(output, PipeMode.concurrent);
                                catch (Exception e) {assert(false);}
                            });
                    }
                    auto stdoutTask = pump(processPipes.stdout, stdoutStream);
                    auto stderrTask = pump(processPipes.stderr, stderrStream);

                    stdoutTask.join();
                    stderrTask.join();
                    processPipes.process.wait();
                    exitEventLoop();
                }
            } catch (Exception e)
            {
                assert(false);
            }
        });
    runApplication();
}

// seems to be ok, but assert in the catch block
// would be cool to do scope stdoutStream = new StdoutStream and get in the destructor the call to close ...
void v2() {
    auto processPipes = pipeProcess(["./output.sh"]);
    { // scope to cleanup streams
        auto stdoutStream = new StdoutStream;
        scope (exit) stdoutStream.close();

        auto stderrStream = new StderrStream;
        scope (exit) stderrStream.close();

        auto pump(ref PipeInputStream input, StdFileStream output)
        {
            return runTask!()(() nothrow {
                    try input.pipe(output, PipeMode.concurrent);
                    catch (Exception e) {assert(false);}
                });
        }
        auto stdoutTask = pump(processPipes.stdout, stdoutStream);
        auto stderrTask = pump(processPipes.stderr, stderrStream);

        runTask!(ProcessPipes)((ProcessPipes pipes) {
                try {
                    // make sure all data is copied out
                    stdoutTask.join();
                    stderrTask.join();
                    // make sure process is really done
                    processPipes.process.wait();
                    exitEventLoop();
                } catch (Exception e)
                {
                    assert(false);
                }
            }, processPipes);

        runApplication();
    }
}

// seems to be ok, but lots of code, and too tricky wait/join combinations, also empty catch blocks are evil
void v1() {
    auto processPipes = pipeProcess(["./output.sh"]);
    auto stdoutStream = new StdoutStream;
    auto stderrStream = new StderrStream;

    auto stdoutPipe = runTask!(ProcessPipes)((ProcessPipes processPipes) {
            try {
                pipe(processPipes.stdout, stdoutStream, PipeMode.concurrent);
                processPipes.process.wait();
            } catch (Exception e)
            {
            }
        }, processPipes);
    auto stderrPipe = runTask!(ProcessPipes)((ProcessPipes processPipes) {
            try {
                pipe(processPipes.stderr, stderrStream, PipeMode.concurrent);
                processPipes.process.wait();
            } catch (Exception e){
            }
        }, processPipes);

    runTask!(Task, Task)((Task t1, Task t2) nothrow {
            try {
                t1.join();
                t2.join();
                exitEventLoop();
            } catch (Exception e)
            {
            }
        }, stdoutPipe, stderrPipe);
    runApplication();
    stdoutStream.close();
    stderrStream.close();
}
// would be cool, but stdout and stderr are not interleaved -> would block with lots of stderr output + does not terminate
void v0()
{
    auto processPipes = pipeProcess(["./output.sh"]);
    auto stdoutStream = new StdoutStream;
    auto stderrStream = new StderrStream;
    processPipes.stdout.pipe(stdoutStream, PipeMode.concurrent);
    processPipes.stderr.pipe(stderrStream, PipeMode.concurrent);
    runApplication();
    stdoutStream.close();
    stderrStream.close();
}
void main()
{
    v2();
}
