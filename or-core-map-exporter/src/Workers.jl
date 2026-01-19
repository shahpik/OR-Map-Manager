"""
`Workers` creates a work queue that is used by all threads except the main
thread, and provides a macro (`Workers.@async`) which assigns tasks to that
queue.

This allows the main thread (thread 1) to be left to the handling of HTTP
requests, meaning that a long running tasks will not block the handler.

`Workers.@async` should be used to schedule long running tasks. This is
typically done in `Resource`, like so:

```julia
execute_app(req) = fetch(Workers.@async(App.execute_app(req)))
HTTP.@register(ROUTER, "/execute", execute_app)
```
`fetch` is non-blocking, so will wait for the result from `Workers.@sync`
without blocking further requests.
"""
module Workers

using EMInterface

const WORK_QUEUE = Channel{Task}(1000)
const B_IS_WORKING = Ref{Bool}(false)

"""
    @async expr

Adds `expr` as a new task to `Workers.WORK_QUEUE`, wrapped in a try-catch
to display any error messages.

The tasks in `Workers.WORK_QUEUE` are run on any available threads except for
thread 1, which is reserved for the HTTP handler (unless only one thread is
in use).
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
    init()

If `Threads.nthreads()` is greater than 1, initialise async function on each
thread apart from thread 1, which is left for the HTTP handler.

If only 1 task is available, only this task is used and `Workers.@async` acts
in the same way as `Base.@async`.
"""
function init()
    # If workers are already initialised then do nothing
    B_IS_WORKING[] && return nothing

    tids = Threads.nthreads() == 1 ? (1:1) : 2:Threads.nthreads()
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
    B_IS_WORKING[] = true
    return nothing
end

end # module