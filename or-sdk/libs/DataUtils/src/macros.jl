"""
    retry(expr, max_retries=5)

Retries a function in a forever while loop, unless max_retries argument is specified.

# Source
`DataIngestion.src.utilities`
`DataRecorder.src.utilities`
"""
macro retry(expr, max_retries=5)
    esc(
        quote
            sleep_for = 1
            n_retries = 0
            result = nothing
            err = nothing
            while n_retries <= $max_retries
                try
                    result = $expr
                    break
                catch err
                    if n_retries < $max_retries
                        @error "Function failed: $(typeof(err)), after $n_retries retries, sleeping for $sleep_for seconds"
                        sleep(sleep_for)
                        # sleep_for += 2^n_retries
                    end
                    n_retries += 1
                end
            end
            
            if n_retries > $max_retries
                @error "Function failed: $(typeof(err)), after $(n_retries - 1) retries."
                throw(err)
            end
            
            result
        end
    )
end