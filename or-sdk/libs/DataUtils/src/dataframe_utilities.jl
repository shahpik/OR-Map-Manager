
"""
replace_df(df::DataFrame, from, to)::DataFrame

Replaces values in a DataFrame with any other value.

# Arguments:
- `df::DataFrame`: Nonempty Dataframe
- `from`: Type of value eg `nothing`
- `to`: Type of value eg `missing`

# Returns:
- `df::DataFrame`: Dataframe where all instance of `from` are changed to `to`
"""
function replace_df(df::DataFrame, from, to)::DataFrame
    col_names = names(df)
    for col in col_names
        df[!, col] = replace(df[!, col], from=>to)
    end

    return df
end

"""
typed_dataframe(data_type::String)::DataFrame

Create a dataframe where each column is appropriately typed based on 
the GQL object. This allows to PKs to typed and labeled as 'NOTNULL' 
while allowing other fields to be nullable

# Arguements:
- `mapping::AbstractDict`: Mapping of column names to data types and 
if the column is nullable. For example:
    ```
    mapping = Dict(
        "col_1" => Dict(
            "dtype" => :String,
            "nullable" => false
            ),
        "col_2" => Dict(
            "dtype" => :Int64,
            "nullable" => true
            ),
        "col_3" => Dict(
            "dtype" => :Vector,
            "sub_dtype" => :Float64,
            "nullable" => true
            ),
        "col_4" => Dict(
            "dtype" => :Float64,
            )
    )
    ```

# Returns:
- `df::DataFrame`: DataFrame where the columns are typed according to the
datatype passed through args.
"""
function typed_dataframe(mapping::AbstractDict)::DataFrame
    df = DataFrame()
    for (col, meta) in mapping
        field = getfield(Base, meta["dtype"])
        if haskey(meta, "sub_dtype")
            sub_field = getfield(Base, meta["sub_dtype"])
            df[!, col] = get(meta, "nullable", true) ? Union{Nothing, field{sub_field}}[] : field{sub_field}[]
        else
            df[!, col] = get(meta, "nullable", true) ? Union{Nothing, field}[] : field[]
        end
    end

    return df
end
