tgraph = basic_osm_graph_stub2()

@testset "LightOSM related utilties" begin
    
    @test Set(get_adjacent_nodes_on_graph(tgraph, 1008)) == Set([1007, 1006, 1009])
    @test Set(get_adjacent_nodes_on_graph(tgraph, 1008, dir=:reverse)) == Set([1006])
    @test Set(get_adjacent_nodes_on_graph(tgraph, 1008, dir=:both)) == Set([1007, 1006, 1009])
    @test Set(get_adjacent_nodes_on_graph(tgraph, 1008, maxhops=2)) == Set([1007,1006,1004,1001,1008, 1009])
    @test Set(get_adjacent_nodes_on_graph(tgraph, 1008, dir=:reverse, maxhops=3)) == Set([1006,1007,1001,1008,1004,1002])
    @test Set(get_adjacent_nodes_on_graph(tgraph, 1008, dir=:both, maxhops=2)) == Set([1007,1006,1004,1008,1001, 1009])
    
    # note the logic of the one way road here
    @test Set(get_connected_ways(tgraph, 2004)) == Set([2002])
    @test Set(get_connected_ways(tgraph, 2004, dir=:reverse)) == Set([2005])
    @test Set(get_connected_ways(tgraph, 2002)) == Set([2001, 2005, 2003])
    @test Set(get_connected_ways(tgraph, 2002, dir=:reverse)) == Set([2001, 2005, 2003, 2004])

    @test  SpatialUtilities.get_frw_lookup(tgraph, [2006])[2006]['r'] == [2005]
    test_frw = SpatialUtilities.get_frw_lookup(tgraph, [2001])
    @test  test_frw[2001]['f'] == [2002, 2003]
    @test  SpatialUtilities.get_starting_ways(test_frw) == [2001]
    # find_paths_in_frw(tgraph, [2001], test_frw)

    @test length(get_way_ls_coords(tgraph, 2001)) == 4
    @test get_node_pos(tgraph, 1004) == [145.3326838, -38.0754637]
    @test get_node_pos(tgraph, 1004, false) == [-38.0754637, 145.3326838]
    @test get_node_pos(tgraph, 1006) ==  [145.3327838, -38.0752637]

    @test reverse_nodes_to_connect_ways(tgraph, 2001, 2003) == [false, false]
    @test reverse_nodes_to_connect_ways(tgraph, 2003, 2001) == [true, true]
    
    @test get_way_ls_coords(tgraph, 2001) == get_way_ls_coords(tgraph, [2001]) 
    @test get_way_ls_coords(tgraph, [2001, 2003]) == reverse(get_way_ls_coords(tgraph, [2003, 2001]))
    
    @test get_way_ls_nodes(tgraph, [2001, 2003]) == [1001,1002,1003,1004,1005]
    @test get_way_ls_nodes(tgraph, 2001) == get_way_ls_nodes(tgraph, [2001]) 
    @test get_way_ls_nodes(tgraph, 2001, rev_nodes=true) == reverse(get_way_ls_nodes(tgraph, 2001))
    # Problem is in looping ways - they result in different node orders when both are two way, and direction is reversed
    @test get_way_ls_nodes(tgraph, [2001, 2002]) == reverse(get_way_ls_nodes(tgraph, [2002, 2001]))
    
    @test lstring_distance(get_way_ls_coords(tgraph, [2001, 2002])) == lnode_distance(tgraph, get_way_ls_nodes(tgraph, [2001, 2002]))
    @test sign(swapxy(get_way_ls_coords(tgraph, 2001))[1][1]) == -1  # negative is the lat
    
    @test reverse_nodes_to_connect_ways(tgraph, 2005, 2004) == [false, false]
    @test get_way_path_start_end_node(tgraph, [2005, 2004]) == [1006, 1007]

    @test get_way_path_dir_oab(tgraph, [2005, 2004]) == ["2005-A", "2004-O"]
    @test get_way_path_dir_oab(tgraph, [2005, 2006]) == ["2005-A", "2006-O"]
    @test get_way_path_dir_oab(tgraph, [2001, 2002]) == ["2001-A", "2002-B"]
    @test get_way_path_dir_oab(tgraph, [2002, 2001]) == ["2002-A", "2001-B"]
    @test get_way_path_dir_oab(tgraph, [2003, 2001]) == ["2003-B", "2001-B"]

    test_ls = [[145.3326838, -38.0751637], [145.3326838, -38.0755637]]
    test_ls_reverse = reverse(test_ls)
    @test get_way_path_dir_oab_single(tgraph, [2001], test_ls) == ["2001-A"]
    @test get_way_path_dir_oab_single(tgraph, [2002], test_ls) == ["2002-A"]
    @test get_way_path_dir_oab_single(tgraph, [2003], test_ls) == ["2003-A"]
    @test get_way_path_dir_oab_single(tgraph, [2004], test_ls) == ["2004-O"]
    @test get_way_path_dir_oab_single(tgraph, [2001], test_ls_reverse) == ["2001-B"]
    @test get_way_path_dir_oab_single(tgraph, [2002], test_ls_reverse) == ["2002-B"]
    @test get_way_path_dir_oab_single(tgraph, [2003], test_ls_reverse) == ["2003-B"]
    @test get_way_path_dir_oab_single(tgraph, [2004], test_ls_reverse) == ["2004-O"]

    @test SpatialUtilities.get_way_oab_from_node_pair(tgraph, 1001, 1002) == "2001-A"
    @test SpatialUtilities.get_way_oab_from_node_pair(tgraph, 1004, 1006) == "2002-B"
    @test SpatialUtilities.get_way_oab_from_node_pair(tgraph, 1009, 1008) == "2006-O"
    
    @test SpatialUtilities.get_way_dir_from_node_pair(277377872, 277377873, [277377872, 123, 277377873]) == false
    @test SpatialUtilities.get_way_dir_from_node_pair(277377872, 277377873, [277377873, 123, 277377872]) == true
    @test SpatialUtilities.get_way_dir_from_node_pair(277377872, 277377873, [277377873, 277377873]) == false  # should throw warning

    input_path = [
        GeoLocation(lat=-37.8183120, lon=144.9566710), 
        GeoLocation(lat=-37.8176138, lon=144.9590574),
        GeoLocation(lat=-37.8166727, lon=144.9585924)
    ]
    output_path1 = [
        GeoLocation(-37.8183120, 144.9566710)
        GeoLocation(-37.8179997, 144.9577386)
        GeoLocation(-37.8176873, 144.9588061)
        GeoLocation(-37.8169732, 144.9587409)
        GeoLocation(-37.8166727, 144.9585924)
    ]
    output_path2 = [
        GeoLocation(-37.8183120, 144.9566710, 0.0),
        GeoLocation(-37.8181022, 144.9573881, 0.0),
        GeoLocation(-37.8178924, 144.9581053, 0.0),
        GeoLocation(-37.8176826, 144.9588224, 0.0),
        GeoLocation(-37.8172355, 144.9588707, 0.0),
        GeoLocation(-37.8166727, 144.9585924, 0.0)
    ]
    @test all(distance.(
        SpatialUtilities.interpolate_path(input_path, interval=0.1), 
        output_path1
    ) .< 1e-4)
    @test all(distance.(
        SpatialUtilities.interpolate_path(input_path, interval=0.1, append_endpoint=false), 
        output_path1[1:end-1]
    ) .< 1e-4)
    @test all(distance.(
        SpatialUtilities.interpolate_path(input_path, num_intervals=5, append_endpoint=true), 
        output_path2
    ) .< 1e-4)
    @test all(distance.(
        SpatialUtilities.interpolate_path(input_path, num_intervals=5, append_endpoint=false), 
        output_path2
    ) .< 1e-4)
    @test all(distance.(
        SpatialUtilities.interpolate_path(input_path, num_intervals=10, min_interval=0.1), 
        output_path1
    ) .< 1e-4)

    @test SpatialUtilities.lerp(input_path[1], input_path[2], 0.0) == input_path[1]
    @test SpatialUtilities.lerp(input_path[1], input_path[2], 1.0) == input_path[2]
    @test distance(
        SpatialUtilities.lerp(input_path[1], input_path[2], 0.5),
        GeoLocation(-37.8179629, 144.9578642)
    ) < 1e-4

    input_linestring_xy = [
        [144.9566710, -37.8183120], 
        [144.9590574, -37.8176138],
        [144.9585924, -37.8166727]
    ]
    input_linestring_yx = [[x[2], x[1]] for x in input_linestring_xy]
    @test SpatialUtilities.linestring_to_geolocations(input_linestring_xy) == input_path
    @test SpatialUtilities.linestring_to_geolocations(input_linestring_yx, false) == input_path

    # using UnicodePlots
    # lineplot([x[1] for x in ls], [x[2] for x in ls], canvas=DotCanvas, height=10, width=30, xlim=[0, 5], ylim=[0, 5])
    #=
     ┌──────────────────────────────┐ 
   5 │                              │ 
     │                              │ 
     │                              │ 
     │                              │ 
     │            :                 │ 
     │            :                 │ 
     │            :                 │ 
     │            :                 │ 
     │      '''''''                 │ 
   0 │                              │ 
     └──────────────────────────────┘ 
      0                            5 
    =#
    ls1 = [[1.0, 1.0], [2.0, 1.0], [2.0, 3.0]] 
    #=
     ┌──────────────────────────────┐ 
   5 │                              │ 
     │                              │ 
     │                              │ 
     │                        .     │ 
     │                  ...'''      │ 
     │             ..'''            │ 
     │      '':''''                 │ 
     │         ''.                  │ 
     │            '                 │ 
   0 │                              │ 
     └──────────────────────────────┘ 
      0                            5  
    =#
    ls2 = [[2.0, 1.0], [1.0, 2.0], [2.0, 2.0], [5.0, 3.0]]
    #=
     ┌──────────────────────────────┐ 
   5 │'''''''......                 │ 
     │             ''''''......     │ 
     │                      .'      │ 
     │                     :        │ 
     │                    .         │ 
     │                  .'          │ 
     │                 .'           │ 
     │               .'             │ 
     │              .'              │ 
   0 │            .'                │ 
     └──────────────────────────────┘ 
      0                            5  
    =#
    ls3 = [[0.0, 5.0], [4.0, 4.0], [2.0, 0.0]]
    #=
     ┌──────────────────────────────┐ 
   5 │                              │ 
     │                              │ 
     │                              │ 
     │                              │ 
     │                     .....''''│ 
     │            .....''''         │ 
     │'''''''''''''                 │ 
     │                              │ 
     │                              │ 
   0 │                              │ 
     └──────────────────────────────┘ 
      0                            5  
    =#
    ls4 = [[5.0, 3.0], [2.0, 2.0], [0.0, 2.0]]

    @test compass_direction(ls1) == "NORTHBOUND"
    @test compass_direction(ls2) == "EASTBOUND"
    @test compass_direction(ls3) == "SOUTHBOUND"
    @test compass_direction(ls4) == "WESTBOUND"

    @test compass_direction(tgraph, 2001) == "SOUTHBOUND"
    @test compass_direction(tgraph, 2002) == "SOUTHBOUND"
    @test compass_direction(tgraph, 2003) == "SOUTHBOUND"
    @test compass_direction(tgraph, 2004) == "WESTBOUND"
end