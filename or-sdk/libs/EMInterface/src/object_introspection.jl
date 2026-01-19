@doc """
    intialise_object(name::String; kwargs...)

Re-exported from GraphQLClient.

A dictionary of introspected types can be retrieved using the function
`get_introspected_types`
""" GraphQLClient.introspect_object

@doc """
    create_introspected_struct(object_name::String, fields::AbstractDict)

Creates a struct for the object specified and populates its fields with
the keys and values of `fields`.

Re-exported from GraphQLClient.

# Examples
```julia
julia> EMInterface.create_introspected_struct("SegmentActualObject",Dict("segmentId"=>"Melbourne", "fReliability" => 1.0))
SegmentActualObject
  fReliability : 1.0
     segmentId : Melbourne
```
""" GraphQLClient.create_introspected_struct

@doc """
    initialise_introspected_struct(name::String)
    initialise_introspected_struct(name::SubString)
    initialise_introspected_struct(T::Type)

Re-exported from GraphQLClient.
""" GraphQLClient.initialise_introspected_struct

@doc """
    get_introspected_type(client, object_name::String)

Re-exported from GraphQLClient.
""" GraphQLClient.get_introspected_type

"""
    get_introspected_types()

Return dictionary of introspected types from connected client.
"""
get_introspected_types() = get_client().introspected_types

@doc """
    getjuliatype()

Re-exported from GraphQLClient.
""" GraphQLClient.getjuliatype