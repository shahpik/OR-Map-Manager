g = basic_osm_graph_stub(:distance)

# Make test data
function make_mg(g::OSMGraph{U,T,W}) where {U,T,W}
    new_node = nv(g.graph) + 1
    n1 = g.node_to_index[1002]
    n2 = g.node_to_index[1003]
    return MapMatching.ModifiedGraph(
        g.graph,
        U(nv(g.graph) + 1),
        Dict{U,Set{U}}(
            U(n1) => Set{U}(new_node),
            U(n2) => Set{U}(new_node)
        ),
        Dict{U,Set{U}}(
            U(n1) => Set{U}(n2),
            U(n2) => Set{U}(n1)
        )
    )
end

function make_mw(g::OSMGraph{U,T,W}) where {U,T,W}
    new_node = nv(g.graph) + 1
    n1 = g.node_to_index[1002]
    n2 = g.node_to_index[1003]
    return MapMatching.ModifiedWeights(
        g.weights,
        U(nv(g.graph) + 1),
        Dict{Tuple{U,U},W}(
            (n1, new_node) => g.weights[n1,n2] * 0.2,
            (n2, new_node) => g.weights[n2,n1] * 0.8,
            (new_node, n1) => g.weights[n1,n2] * 0.2,
            (new_node, n2) => g.weights[n2,n1] * 0.8
        ),
        Set{Tuple{U,U}}([
            (n1, n2),
            (n2, n1)
        ])
    )
end

mg = make_mg(g)
mw = make_mw(g)

# Test ModifiedGraph
@test nv(mg) == length(g.nodes) + 1
@test Set(outneighbors(mg, g.node_to_index[1001])) == Set([g.node_to_index[1002], g.node_to_index[1006]])
@test Set(outneighbors(mg, g.node_to_index[1002])) == Set([g.node_to_index[1001], nv(mg)])
@test Set(outneighbors(mg, g.node_to_index[1003])) == Set([g.node_to_index[1004], nv(mg)])

# Test ModifiedWeights
@test size(mw) == [nv(mg), nv(mg)]
@test mw[g.node_to_index[1001],g.node_to_index[1002]] == g.weights[g.node_to_index[1001],g.node_to_index[1002]]
@test mw[g.node_to_index[1002],nv(mg)] == g.weights[g.node_to_index[1002],g.node_to_index[1003]] * 0.2
@test mw[nv(mg),g.node_to_index[1003]] == g.weights[g.node_to_index[1003],g.node_to_index[1002]] * 0.8
@test mw[g.node_to_index[1002],g.node_to_index[1003]] == 0.0
