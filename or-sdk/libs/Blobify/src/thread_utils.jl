using ThreadPools

const MULTITHREAD_RANGE = Ref{UnitRange{Int64}}(1:Threads.nthreads())

function __init__()
    start_thread = parse(Int64, get(ENV, "MULTITHREAD_START", "1"))
    end_thread = parse(Int64, get(ENV, "MULTITHREAD_END", string(Threads.nthreads())))
    MULTITHREAD_RANGE[] = start_thread:end_thread
end

"""
    set_multithread_range(range::UnitRange{Int64})

Set the constant `MULTITHREAD_RANGE[]` equal to `range`.
"""
set_multithread_range(range::UnitRange{Int64}) = MULTITHREAD_RANGE[] = range

"""
    @custom_threads expr

Run a `for` loop on threads `MULTITHREAD_RANGE[]`. If `Threads.nthreads()=1`, this will just
default to 1 thread.

`MULTITHREAD_RANGE[]` can be set by `set_multithread_range` or by the environment variables
`MULTITHREAD_START` and `MULTITHREAD_END` (must be set before `using Blobify` is executed).

See also: [`set_multithread_range`](@ref)
"""
macro custom_threads(expr)
    esc(quote
        t = ThreadPools.twith(ThreadPools.StaticPool(MULTITHREAD_RANGE[])) do pool
            ThreadPools.@tthreads pool $expr
        end
        nothing
    end)
end

"""
    @is_inbounds_on

Returns `true` if @inbounds is being used, and `false` if not.

This is to be used with `@is_inbounds_on` to allow `@inbounds`
to have an effect inside threaded loops within functions where
`@inbounds` is propagated.

# Example

For the following definition of `foo`, if `@inbounds foo()` is executed,
@inbounds will be propagated firstly into `foo` (by `Base.@propagate_inbounds`)
and secondly into the `for` loop inside `foo`. If `foo()` is executed
without `@inbounds`, then bounds checking will be as normal inside the `for` loop.

```julia
Base.@propagate_inbounds foo()
    using_inbounds = @is_inbounds_on
    @threads for i in 1:10
        @optional_inbounds using_inbounds doo_something()
    end
end
```
"""
macro is_inbounds_on()
    return Expr(:if, Expr(:boundscheck), false, true)
end

"""
    @optional_inbounds using_inbounds expr

Runs `expr` with `@inbounds` if `using_inbounds` evaluates to `true`

This is to be used with `@is_inbounds_on` to allow `@inbounds`
to have an effect inside threaded loops within functions where
`@inbounds` is propagated.

# Example

For the following definition of `foo`, if `@inbounds foo()` is executed,
@inbounds will be propagated firstly into `foo` (by `Base.@propagate_inbounds`)
and secondly into the `for` loop inside `foo`. If `foo()` is executed
without `@inbounds`, then bounds checking will be as normal inside the `for` loop.

```julia
Base.@propagate_inbounds foo()
    using_inbounds = @is_inbounds_on
    @threads for i in 1:10
        @optional_inbounds using_inbounds doo_something()
    end
end
```
"""
macro optional_inbounds(using_inbounds, expr)
    return quote
        if $(esc(using_inbounds))
            @inbounds $(esc(expr))
        else
            $(esc(expr))
        end
    end
end