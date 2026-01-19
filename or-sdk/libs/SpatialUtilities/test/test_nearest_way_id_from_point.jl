test_graph = basic_osm_graph_stub()

@testset "way id from point tests" begin
    # @test get_way_id_from_point(test_g_50k, [-38.02914,145.32085]) == 779435253 # Princes Highway Off Ramp
    # @test get_way_id_from_point(test_g_50k, [-37.91310,145.11394]) == 791849034 # North Road
    # @test get_way_id_from_point(test_g_50k, [-38.01532,145.30622]) == 331599990 # Narre Warren North Road Off Ramp

    # test knn_pairs
    @test [1001, 1002] ∈ knn_pairs(test_graph, [-38.0751685, 145.3326842], 3)

    # test get way ids
    @test get_way_id_from_point(test_graph, [-38.0751685, 145.3326842], 5) == 2001
    @test get_way_id_from_point(test_graph, [-38.0754002, 145.3327215], 5) == 2002
    @test get_way_id_from_point(test_graph, [-38.0755639, 145.3326843], 5) == 2003
    
end
