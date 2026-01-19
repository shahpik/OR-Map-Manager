g = basic_osm_graph_stub(:distance)
ep1 = MapMatching.EdgePoint(1001, 1002, 0.3)
ep2 = MapMatching.EdgePoint(1007, 1004, 0.6)
ep3 = MapMatching.EdgePoint(1002, 1001, 0.0)
ep4 = MapMatching.EdgePoint(1008, 1007, 0.5)

# Test construct_modified_graph
mg, mw, start_idx, goal_idx = MapMatching.construct_modified_graph(g, ep1, ep2)
@test nv(mg) == length(g.nodes) + 2
@test Set(outneighbors(mg, start_idx)) == Set([g.node_to_index[1001], g.node_to_index[1002]])
@test Set(outneighbors(mg, goal_idx)) == Set([g.node_to_index[1004], g.node_to_index[1007]])
@test mw[g.node_to_index[1007], goal_idx] > 0.0
@test mw[g.node_to_index[1004], g.node_to_index[1007]] == 0.0

# Test shortest_path
@test shortest_path(g, ep1, ep2) == [1001, 1002, 1003, 1004, 1007]
@test isnothing(shortest_path(g, ep1, ep2, max_distance=1.0))  # exceeds max_distance
@test shortest_path(g, ep3, ep2) == [1002, 1003, 1004, 1007]
@test shortest_path(g, ep1, ep3) == [1001, 1002]
@test shortest_path(g, ep4, ep2) == [1008, 1007, 1004]
@test isnothing(shortest_path(g, ep2, ep4))  # 1008->1007 is one-way

# Test shortest_path_distance
@test MapMatching.shortest_path_distance(g, ep1, ep2) > MapMatching.shortest_path_distance(g, ep3, ep2)

# Test EdgePoint edge cases
#=
•----------u-----v----------•
u.n1                     u.n2
v.n1                     v.n2
=#
@test shortest_path(
    g,
    MapMatching.EdgePoint(1001, 1002, 0.3),
    MapMatching.EdgePoint(1001, 1002, 0.8)
) == [1001, 1002]
@test MapMatching.shortest_path_distance(
    g,
    MapMatching.EdgePoint(1001, 1002, 0.3),
    MapMatching.EdgePoint(1001, 1002, 0.8)
) == distance(g.nodes[1001], g.nodes[1002]) * 0.5

#=
•----------u-----v----------•
u.n1                     u.n2
v.n2                     v.n1
=#
@test shortest_path(
    g,
    MapMatching.EdgePoint(1001, 1002, 0.3),
    MapMatching.EdgePoint(1002, 1001, 0.2)
) == [1001, 1002]
@test MapMatching.shortest_path_distance(
    g,
    MapMatching.EdgePoint(1001, 1002, 0.3),
    MapMatching.EdgePoint(1002, 1001, 0.2)
) == distance(g.nodes[1001], g.nodes[1002]) * 0.5

#=
•----------v-----u----------•
u.n1                     u.n2
v.n1                     v.n2
=#
@test shortest_path(
    g,
    MapMatching.EdgePoint(1001, 1002, 0.8),
    MapMatching.EdgePoint(1001, 1002, 0.3)
) == [1002, 1001]
@test MapMatching.shortest_path_distance(
    g,
    MapMatching.EdgePoint(1001, 1002, 0.8),
    MapMatching.EdgePoint(1001, 1002, 0.3)
) == distance(g.nodes[1001], g.nodes[1002]) * 0.5

#=
•----------v-----u----------•
u.n1                     u.n2
v.n2                     v.n1
=#
@test shortest_path(
    g,
    MapMatching.EdgePoint(1001, 1002, 0.8),
    MapMatching.EdgePoint(1002, 1001, 0.7)
) == [1002, 1001]
@test MapMatching.shortest_path_distance(
    g,
    MapMatching.EdgePoint(1001, 1002, 0.8),
    MapMatching.EdgePoint(1002, 1001, 0.7)
) == distance(g.nodes[1001], g.nodes[1002]) * 0.5

# Impossible due to one-way
@test isnothing(shortest_path(
    g,
    MapMatching.EdgePoint(1008, 1007, 0.4),
    MapMatching.EdgePoint(1008, 1007, 0.2)
))
@test isnothing(MapMatching.shortest_path_distance(
    g,
    MapMatching.EdgePoint(1008, 1007, 0.4),
    MapMatching.EdgePoint(1008, 1007, 0.2)
))
@test isnothing(shortest_path(
    g,
    MapMatching.EdgePoint(1008, 1007, 0.6),
    MapMatching.EdgePoint(1007, 1008, 0.8)
))
@test isnothing(MapMatching.shortest_path_distance(
    g,
    MapMatching.EdgePoint(1008, 1007, 0.6),
    MapMatching.EdgePoint(1007, 1008, 0.8)
))
