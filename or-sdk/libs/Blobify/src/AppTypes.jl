module AppTypes

using LightOSM: Node, Way, distance
using Parameters: @with_kw

export Intersection,
       IntersectionType, 
       SimpleIntersection, 
       ComplexIntersection, 
       RoundaboutIntersection, 
       CarriagewayChangeIntersection

"""
    IntersectionType

Intersection types. Use the typing system to define these to support multiple 
dispatch on intersection types.
"""
abstract type IntersectionType end
abstract type SimpleIntersection <: IntersectionType end
abstract type ComplexIntersection <: IntersectionType end
abstract type RoundaboutIntersection <: IntersectionType end
abstract type CarriagewayChangeIntersection <: IntersectionType end

"""
    Intersection

Model of an intersection on an OSM graph. An intersection includes simple 
intersections where two ways cross, and more complex intersections with 
multiple carriageways, slip lanes, etc.

# Fields
- `type::String`: Intersection type. Will be changed to a Symbol in the future.
- `uid::String`: Unique ID for the intersection, given by hashing all of the
  intersection's node IDs. `uid` is stable for a given OSM dataset, but is not
  guaranteed to remain stable over time.
- `external_id::String`: Intersection ID in external source system.
- `external_source::String`: Name of the source for `external_id`.
- `intersecting_roads::Set{String}`: Names of roads meeting at the intersection.
- `centroid_nodes::Vector{Int}`: Centroid OSM node IDs.
- `centroid_locations::Vector{GeoLocation}`: Locations of centroid nodes.
- `inc_nodes::Vector{Int}`: Incoming OSM node IDs.
- `inc_nodes_dirs::Vector{Float64}`: Incoming node compass headings.
- `inc_highway_types::Vector{String}`: Values of the OSM "highway" tag for 
  incoming nodes, or "other" if the tag is not available.
- `out_nodes::Vector{Int}`: Outgoing OSM node IDs.
- `out_nodes_dirs::Vector{Float64}`: Outgoing node compass headings.
- `out_highway_types::Vector{String}`: Values of the OSM "highway" tag for 
  outgoing nodes, or "other" if the tag is not available.
- `has_light::Bool`: If the intersection has traffic lights.
- `is_roundabout::Bool`: If the intersection is a roundabout.
- `roundabout_ways::Union{Vector{<:Integer},Nothing}`: The ways that make up the
  roundabout, if the intersection is a roundabout.
- `centroid_to_inc::Dict{Int,Vector{Int}}`: Mapping of centroids to incoming 
  nodes.
- `centroid_to_out::Dict{Int,Vector{Int}}`: Mapping of centroids to outgoing 
  nodes.
- `inc_to_centroid::Dict{Int,Int}`: Mapping of incoming nodes to centroids. If 
  the node is connected to multiple centroids, choose the first connected one.
- `out_to_centroid::Dict{Int,Int}`: Mapping of outgoing nodes to centroids. If 
  the node is connected to multiple centroids, choose the first connected one.
- `n_linked_pathgroups::Int`: Number of 'roadways' through the intersection.
  Each road way is 1 or 2 opposing pathgroups.
- `pg_overall_priorities::Vector{Int}`: The highest priority assigned to each 
  pathgroup.
- `path_priorities::Dict{Int,Dict{Int,Any}}`: Dictionary of incoming node to 
  outgoing node, and priorities for each

# Notes
- Centroid nodes are where two ways cross.
- Incoming and outgoing nodes are nodes through which a vehicle can enter and 
  exit an intersection. These can be the same e.g. on a two-way way.
- More info on highway_types can be found here:
  https://wiki.openstreetmap.org/wiki/Key:highway

# TODO
- Should we rename "centroid" to "vertex"? Doesn't make sense to have multiple 
  "centroid" nodes.
- Add a new field called "centroid" with the calculated centroid location.
- Discuss and implement an ID system for internal model identification. Example:
  `id::String`
"""
@with_kw mutable struct Intersection{T <: IntersectionType}
    type::Type{T} = T
    uid::String = ""
    external_id::String = ""
    external_source::String = ""
    intersecting_roads::Set{String} = Set{String}()
    centroid_nodes::Vector{<:Integer} = Integer[]
    inc_nodes::Vector{<:Integer} = Integer[]
    inc_nodes_dirs::Vector{Float64} = Float64[]
    inc_ways::Vector{<:Integer} = Integer[]
    out_nodes::Vector{<:Integer} = Int[]
    out_nodes_dirs::Vector{Float64} = Float64[]
    out_ways::Vector{<:Integer} = Integer[]
    has_light::Bool = false
    internal_nodes::Vector{<:Integer} = Integer[]
    internal_ways::Vector{<:Integer} = Integer[]
    nodes::Dict{<:Integer,<:Node} = Dict{Integer,Node}()
    ways::Dict{<:Integer,<:Way} = Dict{Integer,Way}()
    centroid_to_inc::Dict{<:Integer,<:Vector{<:Integer}} = Dict{Integer,Vector{Integer}}()
    centroid_to_out::Dict{<:Integer,<:Vector{<:Integer}} = Dict{Integer,Vector{Integer}}()
    inc_to_centroid::Dict{<:Integer,<:Integer} = Dict{Integer,Integer}()
    out_to_centroid::Dict{<:Integer,<:Integer} = Dict{Integer,Integer}()
    n_linked_pathgroups::Integer = 0
    pg_overall_priorities::Vector{<:Integer} = Vector{Integer}()
    path_priorities::Dict{<:Integer,<:Dict{<:Integer,Any}} = Dict{Integer,Dict{Integer,Any}}() 
end

""" Deprecation warnings for Intersection """
function Base.getproperty(intsc::Intersection, field::Symbol)
    # Ensure renaming of "highways" to "ways" is backwards compatible
    if field === :centroid_locations
        Base.depwarn("`centroid_locations` field is deprecated, use `Intersection.nodes[id].location` instead", :getproperty)
        return [intsc.nodes[nid].location for nid in intsc.centroid_nodes]
    elseif field === :inc_highway_types
        Base.depwarn("`inc_highway_types` field is deprecated, use `Blobify.inc_highway_types` function instead", :getproperty)
        return [get(intsc.ways[wid].tags, "highway", "other") for wid in intsc.inc_ways]
    elseif field === :out_highway_types
        Base.depwarn("`out_highway_types` field is deprecated, use `Blobify.out_highway_types` function instead", :getproperty)
        return [get(intsc.ways[wid].tags, "highway", "other") for wid in intsc.out_ways]
    elseif field == :is_roundabout
        Base.depwarn("`is_roundabout` field is deprecated, use `Intersection.type <: RoundaboutIntersection` instead", :getproperty)
        return intsc.type <: RoundaboutIntersection
    elseif field === :roundabout_ways
        Base.depwarn("`roundabout_ways` field is deprecated, use `Intersection.internal_ways` instead", :getproperty)
        return getfield(intsc, :internal_ways)
    end

    return getfield(intsc, field)
end

end # module
