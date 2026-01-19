
"""
    Generate a Cmd from a string. Does not support piping.
"""
function str_to_cmd(s::String)
    return Cmd([String(substr) for substr in split(s, ' ', keepempty=false)])
end
str_to_cmd(substr::SubString) = str_to_cmd(String(substr))

"""
    run_shell(pipeline::Base.OrCmds)

Run a shell command, returning a Tuple of the standard
output and standard error streams.
Example usage: stdout, stderr = run_shell("echo 12 56 | proj +proj=utm +zone=32")
"""
function run_shell(pipe::Base.OrCmds)
    out = Pipe()
    err = Pipe()
    p = run(pipeline(pipe, stdout=out, stderr=err))
    close(out.in)
    close(err.in)

    stdout = String(read(out))
    stderr = String(read(err))

    return stdout, stderr
end
run_shell(cmd::Cmd) = run_shell(pipeline(cmd))
run_shell(cmd::String) = run_shell(shell_to_pipeline(cmd))

"""
    shell_to_pipeline(s::String)

Convert a string representing a shell pipeline into a
Julia pipeline.
"""
function shell_to_pipeline(s::String)
    if contains(s, '|')
        pipes = [String(substr) for substr in split(s, '|', keepempty=false)]
        if length(pipes) > 2
            joined = str_to_cmd(pipes[1])
            for p in 1:2:length(pipes)-1
                joined = pipeline(joined, str_to_cmd(pipes[p+1]))
            end
            return joined
        else
            return pipeline([str_to_cmd(p) for p in pipes]...)
        end
    else
        return pipeline(split(s, ' ', keepempty=false))
    end
end

