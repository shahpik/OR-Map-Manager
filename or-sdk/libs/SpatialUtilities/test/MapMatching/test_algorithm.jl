g = basic_osm_graph_stub(:distance)

#=
This linestring should match to:
Between 1008 and 1007 -> 1007 -> 1004 -> 1003 -> 1002 -> Between 1002 and 1001
=#
ls1 = coords_to_geoloc([
    [144.97816, -37.82023], 
    [144.97434, -37.82009], 
    [144.97108, -37.81958], 
    [144.96863, -37.82012], 
    [144.96559, -37.82189], 
    [144.96271, -37.82399], 
    [144.95992, -37.82545], 
    [144.95906, -37.82463], 
    [144.95928, -37.82223], 
    [144.95954, -37.81958], 
    [144.95958, -37.81602], 
    [144.95945, -37.81300]
])

#=
This linestring should match to:
Between 1007 and 1006 -> 1006 -> 1001 -> Between 1001 and 1002
=#
ls2 = coords_to_geoloc([
    [144.96962, -37.81643], 
    [144.96958, -37.81490], 
    [144.96516, -37.81233], 
    [144.96052, -37.81012], 
    [144.96035, -37.81195], 
    [144.96044, -37.81328]
])

rtree = construct_rtree(g)

hmm_g1 = construct_hmm_graph(g, ls1, rtree)
hmm_g2 = construct_hmm_graph(g, ls2, rtree)
@test nv(hmm_g1.graph) == length(hmm_g1.states)
@test nv(hmm_g2.graph) == length(hmm_g2.states)
@test length(hmm_g1.trellis) == length(ls1)
@test length(hmm_g2.trellis) == length(ls2)

@test MapMatching.emission_prob(0.0) == 1.0
@test MapMatching.emission_prob(1.0) > MapMatching.emission_prob(2.0)

match1 = match_linestring(g, ls1, rtree)
match2 = match_linestring(g, ls2, rtree)
@test match1.matched_nodes == [1008, 1007, 1004, 1003, 1002, 1001]
@test match2.matched_nodes == [1007, 1006, 1001, 1002]
@test match1.matched_ways == [2004, 2002, 2001]
@test match2.matched_ways == [2002, 2001]
