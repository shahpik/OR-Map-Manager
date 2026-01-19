"""
    get_way_extrema(g::OSMGraph{U,T,W}, 
                    way::T, 
                    node_locs_cart::AbstractDict{<:T,<:NTuple{3,<:AbstractFloat}}
                    ) where {U,T,W}

Returns the bounding box for a way.

# Arguments
- `g::OSMGraph{U,T,W}`: LightOSM graph.
- `way::T`: Way ID to get bounding box.
- `node_locs_cart::AbstractDict{<:T,<:NTuple{3,<:AbstractFloat}}`: Cartesian 
  coordinates of all nodes in Earth frame of reference. Example:
  ```julia
  Dict{Int64, Tuple} with 2336608 entries:
    6568064182 => (-4200.89, 2970.04, -3757.79)
    6948061365 => (-4027.01, 3130.6, -3817.36)
    280418652  => (-4101.17, 2866.87, -3943.49)
    ⋮          => ⋮
  ```

# Returns
- `::Tuple{Tuple{<:AbstractFloat}}`: Bounding box of a way. First point is 
  minimum, second point is maximum.
"""
function get_way_extrema(g::OSMGraph{U,T,W}, 
                         way::T, 
                         node_locs_cart::AbstractDict{<:T,<:NTuple{3,<:AbstractFloat}}
                         ) where {U,T,W}
    nodes = g.ways[way].nodes
    x = [node_locs_cart[nid][1] for nid in nodes]
    y = [node_locs_cart[nid][2] for nid in nodes]
    z = [node_locs_cart[nid][3] for nid in nodes]
    min_pt = (minimum(x), minimum(y), minimum(z))
    max_pt = (maximum(x), maximum(y), maximum(z))
    return (min_pt, max_pt)
end

""" 
    get_rtree_elements(g::OSMGraph{U,T,W}) where {U,T,W}

Creates R-tree elements for all ways in a LightOSM graph. Each element is 
essentially a rectangle tagged with a way ID.

# Arguments
- `g::OSMGraph{U,T,W}`: LightOSM graph.

# Returns
- `Vector{SpatialElem}`: R-tree elements to add.
"""
function get_rtree_elements(g::OSMGraph{U,T,W}) where {U,T,W}
    # Convert all nodes to 3D Cartesian coordinates in Earth frame of reference
    node_locs_cart = Dict([nid => LightOSM.to_cartesian(node.location) for (nid, node) in g.nodes])

    return [
        SpatialElem(
            SpatialIndexing.Rect(get_way_extrema(g, wid, node_locs_cart)...), 
            wid, 
            nothing
        )
        for wid in keys(g.ways)
    ]
end

""" 
    construct_rtree(g::OSMGraph{U,T,W}; 
                    leaf_cap::Integer=20, 
                    branch_cap::Integer=20
                    ) where {U,T,W}

Create an R-tree from LightOSM graphs ways, where each element of the tree is 
an OSM way.

Do not try to `print` or `show` this object. Try `tree.nelems` or 
`tree.nnodes_perlevel` instead for some basic info.

# Warning
Make sure to suppress outputs! 
Behaviour as of SpatialIndexing.jl 0.1.3 will print a line for every single OSM 
way, which will flood the terminal if not suppressed. Use with caution for now.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `leaf_cap::Integer`: The max amount of nodes in the lowest layer. 
  Leave as default unless tuning tree.
- `branch_cap`: Integer, max number of branches a layer can have in the tree. 
  Leave as default unless tuning tree.
"""
function construct_rtree(g::OSMGraph{U,T,W}; 
                         leaf_cap::Integer=20, 
                         branch_cap::Integer=20
                         ) where {U,T,W}
    tree = RTree{Float64,3}(T, Nothing, leaf_capacity=leaf_cap, branch_capacity=branch_cap)
    data = get_rtree_elements(g)
    SpatialIndexing.load!(tree, data)
    return tree
end

"""
    nearby_ways(tree::RTree, 
                point::GeoLocation, 
                distance::AbstractFloat
                )

Gets all way IDs nearby to a point within a given distance.

This is only an approximation. The search area and way bounding boxes are both 
rectangles, so some returned ways may be further away than the specified 
distance because only their corners intersect.

# Arguments
- `tree::RTree`: R-tree to search.
- `point::GeoLocation`: Point to search around.
- `distance::AbstractFloat`: Distance (in kilometres) to search around point.
"""
function nearby_ways(tree::RTree, 
                     point::GeoLocation, 
                     distance::AbstractFloat
                     )
    p = LightOSM.to_cartesian(point)
    bbox = SpatialIndexing.Rect(
        (p[1] - distance, p[2] - distance, p[3] - distance),
        (p[1] + distance, p[2] + distance, p[3] + distance)
    )
    return [x.id for x in intersects_with(tree, bbox)]
end
