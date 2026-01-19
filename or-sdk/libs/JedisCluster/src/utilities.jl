"""
    split_on_whitespace(x)

Split a string on any amount of whitespaces.
"""
split_on_whitespace(x) = split(strip(x), r"(\s+(?=\S))")

"""
    log_error(err::Exception)

Log an exception and its backtrace to stderr.
"""
log_error(err::Exception) = @error "Function Failed: $(typeof(err))" exception=(err, catch_backtrace())
