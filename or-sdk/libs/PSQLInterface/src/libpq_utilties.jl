

"""
    libpq_result_as_dict(result::LibPQ.Result; camel_case::Bool=false)

Converts a LibPQ.Result to array of dicts (each row of the table is a dict), option to convert column names to camel case.
"""
function libpq_result_as_dict(result::LibPQ.Result; camel_case::Bool=false)
    col_names = camel_case ? [snake_to_camel(n) for n in result.column_names] : result.column_names
    return [Dict(zip(col_names, values(row))) for row in LibPQ.rowtable(result)]
end