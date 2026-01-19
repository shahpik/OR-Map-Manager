""" 
    get_osm_rtree(g::OSMGraph; leaf_cap=20, branch_cap=20)

DEPRECATED! Use `construct_rtree` instead.

Create a rtree from LightOSM graphs ways, where ID of each element is the way id 
# Arguments
- `g::OSMGraph`: OSM Graph
- `leaf_cap`: Integer, the max amount of nodes in the lowest layer. Leave as default unless tuning tree.
- `branch_cap`: Integer, max number of branches a layer can have in the tree. Leave as default unless tuning tree.

# Warning
Make sure to suppress outputs! 
Behaviour as of SpatialIndexing.jl 0.1.3 will print a line for every single osm way,
which will flood the terminal if not suppressed. Use with caution for now.

Do not try to print or show() this object, to inspect, try tree.nelem or tree.nnodes_perlevel instead
for some basic info
"""
function get_osm_rtree(g::OSMGraph; leaf_cap=20, branch_cap=20)
    Base.depwarn(
        "`get_osm_rtree` has been deprecated, use `construct_rtree` instead." *
        "`construct_rtree` has been called automatically here but this will " *
        "be removed in a future release!",
        :get_osm_rtree
    )
    return construct_rtree(g, leaf_cap=leaf_cap, branch_cap=branch_cap)
end
