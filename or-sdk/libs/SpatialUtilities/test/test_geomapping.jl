tgraph = basic_osm_graph_stub2()


@testset "geo utilities" begin
    
    @test get_way_heading(tgraph, 2001) == 180.0
    @test get_way_heading(tgraph, 2001, return_units = :radians) ≈ π
    @test get_way_heading(tgraph, 2001, reverse=true) == 0
    @test get_way_heading(tgraph, 2005) ≈ 141.7901812
    @test get_way_heading(tgraph, 2005, reverse=true) ≈ -38.2098804
    @test (get_way_heading(tgraph, 2004) - -90.0) < 0.01  # approx is not accurate enough
    @test (get_way_heading(tgraph, 2004, reverse=true) - 90.00) < 0.01
    
    @test abs(get_point_dir([0,0], [-1,1]) - (-45)) < 0.01  
    @test abs(get_point_dir([0,0], [-1,1], xy=false) - 135) < 0.01
    
    test_ls = [[0,1],[1,1],[-1,1],[1,-1]]
    @test all(abs.(get_dirs_along_linestring(test_ls) .- [90, -90, 135]) .< 0.1)
    test_ls_short = [[0,1]]
    @test isempty(get_dirs_along_linestring(test_ls_short))
    
    
    @test is_within_angle(10, 30, 10) == false
    @test is_within_angle(10, 30, 20.0) == true
    @test is_within_angle(-10, 30, 40) == true
    @test is_within_angle(-10.1, 30, 20) == false
    @test is_within_angle(-10, 30, 190) == true
    @test is_within_angle(40, -130, 170) ==true
    @test is_within_angle(40, -130, 169.5) == false
    @test is_within_angle(160, -130, 70) == true
    @test is_within_angle(160, -130, 69) == false
    
    # Test that filter works on one way/two way
    @test SpatialUtilities.filter_ways_by_angle(tgraph, 2006, get_way_heading(tgraph, 2006), deg_buffer=1) == true
    @test SpatialUtilities.filter_ways_by_angle(tgraph, 2006, get_way_heading(tgraph, 2006, reverse=true), deg_buffer=1) == false
    @test SpatialUtilities.filter_ways_by_angle(tgraph, 2005, get_way_heading(tgraph, 2005), deg_buffer=1) == true
    @test SpatialUtilities.filter_ways_by_angle(tgraph, 2005, get_way_heading(tgraph, 2005, reverse=true ), deg_buffer=1) == true

    @test typeof(convert_to_float_linestring(Any[Any[53.2,6.1]])) == Vector{Vector{Float64}}
end

@testset "Mapping tests" begin
    test_tree = get_osm_rtree(tgraph; leaf_cap=5, branch_cap=5);
    test_ls = [[145.3326838, -38.0751637], [145.3326838, -38.0755637]]
    test_ls2 = reverse(test_ls)
    @test get_best_way_path_from_linestring(tgraph, test_ls, test_tree, e_metric_start_end_dist_length; apad=45, bpad=0.00001) == [2001, 2003]
    @test get_best_way_path_from_linestring(tgraph, test_ls, test_tree, e_metric_combined; apad=45, bpad=0.00001) == [2001, 2003]
    transpose_weights = copy(transpose(tgraph.weights))  # check transpose weights implementation works
    @test get_best_way_path_from_linestring(tgraph, test_ls, test_tree, e_metric_start_end_dist_length; apad=45, bpad=0.00001, weights_t=transpose_weights) == [2001, 2003]
    @test get_best_way_path_from_linestring(tgraph, test_ls, test_tree, e_metric_combined; apad=45, bpad=0.00001, weights_t=transpose_weights) == [2001, 2003]
end

@testset "Inverse Haversine tests" begin
    # Validation: inverse Haversine are hard to find, these are approx correct
    tol = 0.001
    testpoint1 = inverse_haversine(-37.9526,145.3183,0.0,100.0) 
    @test testpoint1[1] ≈ 145.3183 atol=eps(Float64)
    @test testpoint1[2] ≈ -37.0533 atol=tol
    testpoint2 = inverse_haversine(-37.9526,145.3183,45.0,100.0)
    @test testpoint2[1] ≈ 146.2814 atol=tol
    @test testpoint2[2] ≈ -37.4767 atol=tol
    testpoint3 = inverse_haversine(-37.9526,145.3183,90.0,100.0)
    @test testpoint3[1] ≈ 146.3423 atol=tol
    @test testpoint3[2] ≈ -38.3506 atol=tol
end
