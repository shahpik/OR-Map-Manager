module Logger

using Logging

"""
Basic `__init__` function sets up the global logger to be used.

The loglevel is set by the environment variable `LOG_LEVEL`.

For more control, use a more feature-rich package like Memento.jl
"""
function __init__()
    loglevelmap = Dict(
        "INFO" => Logging.Info,
        "DEBUG" => Logging.Debug,
        "WARN" => Logging.Warn,
        "ERROR" => Logging.Error
    )
    loglevel = get(ENV, "LOG_LEVEL", "INFO")
    logger = Logging.ConsoleLogger(stderr, loglevelmap[loglevel])
    global_logger(logger)
end

end # module