test_g = basic_osm_graph_stub2()

@testset "get_intersections" begin
    test_ints = get_intersections(test_g)
    @test Set(test_ints[1].centroid_nodes) == Set([1007, 1006, 1004])

    test_ints2 = get_intersections(test_g, max_distance=0.0)
    @test length(test_ints2) == 4
    @test length(filter(x -> x.type == CarriagewayChangeIntersection, test_ints2)) == 1
end

@testset "match_arm_to_int_nodes" begin
    test_ints2 = get_intersections(test_g, max_distance=0.0)
    t_int = [t for t in test_ints2 if t.centroid_nodes == [1004]][1]
    @test all(t_int.inc_nodes .∈ [1007, 1005, 1003])
    Blobify.match_arm_to_int_nodes(test_g, 0, t_int) == [1003, 1004]
    Blobify.match_arm_to_int_nodes(test_g, 180, t_int) == [1005, 1004]
    Blobify.match_arm_to_int_nodes(test_g, 90, t_int) == [1007, 1004]
    Blobify.match_arm_to_int_nodes(test_g, -30, t_int) == [1003, 1004]
    Blobify.match_arm_to_int_nodes(test_g, -30, t_int, :outbound) == [1004, 1003]
    Blobify.match_arm_to_int_nodes(test_g, 90, t_int, :outbound) == [1004, 1007]
end
