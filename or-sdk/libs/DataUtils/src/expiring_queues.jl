# Uses a Queue and custom struct with a timestamp to emulate expiring queue
# based on Queue from DataStructures, will need to be used together with that package

abstract type TimedVal end

""" Structure for any number value with a timer on it """
struct TimedNumber{T} <: TimedVal where T<: Number
    ts::Int
    val::T
end
TimedNumber(n::T) where T<: Number = TimedNumber(floor(Int, time()), n)

Base.zero(::TimedNumber{T}) where T <: Number = zero(T)
Base.zero(::Type{TimedNumber{T}}) where T <: Number = zero(T)

""" Structure for an integer value with a timer on it """
const TimedInt = TimedNumber{Int}

""" Structure for a float value with timer on it """
const TimedFloat = TimedNumber{Float64}

""" Adds values at the current timestamp to a timed Queue"""
function add_now!(q::Queue{TimedNumber{N}}, n::N) where N <: Number
    enqueue!(q, TimedNumber(n))
end

""" 
    expire_elements_by_ts!(q::Queue{T}, cutoff::Int) where T <: TimedVal

expires all items until the cutoff, assumes sorted by ts!
# WARNING If input into Queue is not sorted by TS, will need a different implementation
# TODO: 
- Implementation for non-sorted queues
- Implementation for calculating values without mutating queues in place
"""
function expire_elements_by_ts!(q::Queue{T}, cutoff::Int) where T <: TimedVal
    while !isempty(q) && first(q).ts < cutoff
        dequeue!(q)  # removes items until cutoff, assumes sorted
    end
end

""" Gets the sum of the values of a queue of timed vals, doesn't check expiry """
function queue_val_sum(q::Queue{T}) where T <: TimedVal
    res = zero(T)
    for i in q
        res += i.val
    end
    return res
end

""" returns average of vals, does not check expiry """
function average_val_sum(q::Queue{T}) where T <: TimedVal 
    ql = length(q)
    if ql == 0
        return zero(T)
    end
    qavg = queue_val_sum(q)
    return qavg / ql
end

""" 
returns the non-expired average of vals in queue. 
# Note: Mutates queue in place
"""
function expiring_avg!(q::Queue{T}, cutoff::Int=floor(Int, time())) where T <: TimedVal
    expire_elements_by_ts!(q, cutoff)
    return average_val_sum(q)
end

""" 
returns the non-expired values of a queue by some ts
# Note: Mutates queue in place! 
"""
function expiring_sum!(q::Queue{T}, cutoff::Int=floor(Int, time())) where T <: TimedVal
    expire_elements_by_ts!(q, cutoff)
    return queue_val_sum(q)
end

""" returns number of non-expired items in the queue """
function expiring_count!(q::Queue{T}, cutoff::Int=floor(Int, time())) where T <: TimedVal
    expire_elements_by_ts!(q, cutoff)
    return length(q)
end

# Todo: Add other summary functions like max, min etc.