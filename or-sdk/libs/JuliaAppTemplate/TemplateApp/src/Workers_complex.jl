"""
`Workers` creates three "thread groups". Thread 1 is left for HTTP comms,
then one group of threads is used for asynchronous tasks (assigned to by
`Workers.@async` macro) and one group of threads is used for multithreading
(used by `Workers.@threads` macro). The thread groups are configured when
`Workers.init()` is executed. Before that, `Workers.@async` will hang 
and `Workers.@threads` will use all available threads.

The thread groups allow the main thread (thread 1) to be left to the
handling of HTTP requests, meaning that a long running tasks will not
block the handler.

For further information, please see docstrings.

Notes:
1. This needs to export ThreadPools and MULTITHREAD_RANGE so they are
    available when the macros are used. Ideally, this would be handled
    by macro context and only `esc`aping certain things, rather than
    the whole returned expression, but due to argument checking of
    `ThreadPools.@tthreads` this isn't possible currently.
"""
module Workers

using ThreadPools

export ThreadPools, MULTITHREAD_RANGE

"""
    WORK_QUEUE

`Channel` for queueing up tasks to be executed asynchronously. Populated by
`Workers.@async`.
"""
const WORK_QUEUE = Channel{Task}(1000)

"""
    MULTITHREAD_RANGE

Thread range to be used by Workers.@threads macro. Defaults to `1:Threads.nthreads()`
so macro works if only 1 thread is being used.
"""
const MULTITHREAD_RANGE = Ref{UnitRange{Int64}}(1:Threads.nthreads())

function __init__()
    # We do this here do ensure this is initialised properly, rather
    # relying on defaulting of MULTITHREAD_RANGE in its definition.
    # Some funnies were seen when Julia launched with --threads argument
    MULTITHREAD_RANGE[] = 1:Threads.nthreads()
end

"""
    @async expr

Adds `expr` as a new task to `Workers.WORK_QUEUE`, wrapped in a try-catch
to display any error messages.

The tasks in `Workers.WORK_QUEUE` are run on the threads configured by `init()`.
"""
macro async(expr)
    esc(quote
        tsk = @task begin
            try
                $expr
            catch err
                @error "Async function failed: $(typeof(err))" exception=(err, catch_backtrace())
                return err
            end
        end
        tsk.storage = current_task().storage
        put!(Workers.WORK_QUEUE, tsk)
        tsk
    end)
end

"""
    init(;nworkers=1, multithreadstart=3, multithreadend=Threads.nthreads())

Sets up Workers. The following three sections are made in the threads:

1. Thread 1 is left completely (for HTTP comms).
2. Threads 2 to `2+nworkers-1` are used for the Workers, with tasks to be assigned with
    `Workers.@async`.
3. Threads `multithreadstart` to `multithreadend` will be used for multithreading with
    `Workers.@threads`.

`Threads.nthreads()` must be greater than or equal to 3.
"""
function init(;nworkers=1, multithreadstart=3, multithreadend=Threads.nthreads())
    # Threads and argument checking
    if Threads.nthreads() < 3
        throw(throw(JuliaAppTemplateException("JuliaAppTemplate requires 3 or more threads.\nSee Workers for more information.")))
    end
    1 + nworkers >= multithreadstart && throw(ArgumentError("multithreadstart value must be greater than 1 + nworkers"))
    multithreadend < multithreadstart && throw(ArgumentError("multithreadend must be greater than or equal to multithreadstart"))
   
    # Initialise Workers.@async threads
    tids = 2:min(Threads.nthreads(), 2 + nworkers - 1)
    Threads.@threads for _ in 1:Threads.nthreads()
        if Threads.threadid() in tids
            Base.@async begin
                for task in WORK_QUEUE
                    schedule(task)
                    wait(task)
                end
            end
        end
    end

    # Initialise MULTITHREAD_RANGE
    MULTITHREAD_RANGE[] = multithreadstart:multithreadend
    return
end

"""
    @threads expr

Run a for loop on threads `Workers.MULTITHREAD_RANGE[]`. If `Threads.nthreads()=1`, this will
default to 1, as long as `Workers.MULTITHREAD_RANGE[]` hasn't been set to something else.
"""
macro threads(expr)
    esc(quote
        t = ThreadPools.twith(ThreadPools.StaticPool(MULTITHREAD_RANGE[])) do pool
            ThreadPools.@tthreads pool $expr
        end
        nothing
    end)
end

"""
    @threads_over_range start_id end_id expr

Run a `for` loop on threads `start_id:end_id`. If `Threads.nthreads()=1`, this will just
default to 1 thread.
"""
macro threads(start_id, end_id, expr)
    # TODO: add argument checking
    # TODO: combine duplicated code into one function
    esc(quote
        t = ThreadPools.twith(ThreadPools.StaticPool($start_id:$end_id)) do pool
            ThreadPools.@tthreads pool $expr
        end
        nothing
    end)
end

end # module