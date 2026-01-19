# Use a mix of Int and Float formats to test tolerance for different types

#= p1
    •
  / |
•---•
=#
p1 = [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 0.0]]

#= p2
•---•
|   |
•---•
=#
p2 = [[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]] 

#= p3
        •---•
        |   |
        •---•
=#
p3 = [[2, 0], [3, 0], [3, 1], [2, 1], [2, 0]] 

#= p4
•---•
| /
•
=#
p4 = [[0, 0], [1, 1], [0, 1], [0, 0]]

#= p5
    •
  /
•
=#
p5 = [[0, 0], [1, 1], [0, 0]]

#= p6
•-------•
  \   /
    •
  /   \
•-------•
=#
p6 = [[0, 0], [1, 0], [0.5, 0.5], [0, 1], [1, 1], [0, 0]]

#= p7
•-•-•
|   |
•-•-•
=#
p7 = [[0.0, 0.0], [0.5, 0.0], [1.0, 0.0], [1.0, 1.0], [0.5, 1.0], [0.0, 1.0], [0.0, 0.0]]

#= p8, p9, p10
•---•
|   |
•---•
=#
p8 = [[144, -37], [145, -37], [145, -38], [144, -38], [144, -37]]
p9 = [[144.0, -37.0], [144.1, -37.0], [144.1, -37.1], [144.0, -37.1], [144.0, -37.0]]
p10 = [[144.0, -37.0], [144.01, -37.0], [144.01, -37.01], [144.0, -37.01], [144.0, -37.0]]

#= p11, p12, p13
•-------•
  \   /
    •
  /   \
•-------•
=#
p11 = [[144, -37], [145, -37], [144, -38], [145, -38], [144, -37]]
p12 = [[144.0, -37.0], [144.1, -37.0], [144.0, -37.1], [144.1, -37.1], [144.0, -37.0]]
p13 = [[144.0, -37.0], [144.01, -37.0], [144.0, -37.01], [144.01, -37.01], [144.0, -37.0]]

#= p14, p15 open polygons (invalid)
•---•
    |
•---•
=#
p14 = [[0, 0], [1, 0], [1, 1], [0, 1]]
p15 = [[144.0, -37.0], [144.1, -37.0], [144.1, -37.1], [144.0, -37.1]]

#= p16 (a big circle)
( )
=#
function generate_circle(num_points::Integer, radius::AbstractFloat, centre_x::AbstractFloat, centre_y::AbstractFloat)
    x = cos.(2pi ./ num_points .* (0:num_points)) .* radius .+ centre_x
    y = sin.(2pi ./ num_points .* (0:num_points)) .* radius .+ centre_y
    return [[xi, yi] for (xi, yi) in zip(x, y)]
end
p16 = generate_circle(10000, 0.01, 144.0, -37.0)


@testset "Polygon basic functions tests" begin
    @test simplify_2d_polygon(p7) == p2
    @test_throws SpatialUtilities.LibGEOS.GEOSError simplify_2d_polygon(p14)
    @test_throws SpatialUtilities.LibGEOS.GEOSError simplify_2d_polygon(p15)

    @test validate_polygon(p1)[1] == p1
    @test validate_polygon(p6) == [  # Split into two polygons
        [[[0.0, 0.0], [0.5, 0.5], [1.0, 0.0], [0.0, 0.0]]],
        [[[1.0, 1.0], [0.5, 0.5], [0.0, 1.0], [1.0, 1.0]]]
    ]
    @test_throws SpatialUtilities.LibGEOS.GEOSError validate_polygon(p15)

    @test calculate_area_2d_polygon(p1) ≈ 0.5
    @test calculate_area_2d_polygon(p2) ≈ 1.0
    @test calculate_area_2d_polygon(p3) ≈ 1.0
    @test calculate_area_2d_polygon(p4) ≈ 0.5
    @test calculate_area_2d_polygon(p5) ≈ 0.0
    @test calculate_area_2d_polygon(p6) ≈ 0.5
    @test calculate_area_2d_polygon(p7) ≈ 1.0
    @test_throws SpatialUtilities.LibGEOS.GEOSError calculate_area_2d_polygon(p14)

    # The following were computed in QGIS using https://gis.stackexchange.com/a/23356
    # Using a 1% tolerance because polygon area varies between methods,
    # this amount of error is fine for our applications
    @test isapprox(calculate_area_2d_polygon_geo(p8), 9813924696, rtol=0.01)
    @test isapprox(calculate_area_2d_polygon_geo(p9), 98719154, rtol=0.01)
    @test isapprox(calculate_area_2d_polygon_geo(p10), 987766, rtol=0.01)
    @test isapprox(calculate_area_2d_polygon_geo(p11), 4906962348, rtol=0.01)
    @test isapprox(calculate_area_2d_polygon_geo(p12), 49359577, rtol=0.01)
    @test isapprox(calculate_area_2d_polygon_geo(p13), 493883, rtol=0.01)
    @test_throws SpatialUtilities.LibGEOS.GEOSError calculate_area_2d_polygon_geo(p15)

    # Test batching coordinates to proj, don't care about the result
    @test calculate_area_2d_polygon_geo(p16) > 0.01

    @test centroid_2d_polygon(p2) ≈ [0.5,0.5]
    @test centroid_2d_polygon(p6) ≈ [0.5,0.5]
    @test_throws SpatialUtilities.LibGEOS.GEOSError centroid_2d_polygon(p14)
    @test_throws SpatialUtilities.LibGEOS.GEOSError centroid_2d_polygon(p15)

    @test get_intersection(p1, p2)[1] == [[0,0],[1,1],[1,0],[0,0]] 
    @test get_intersection(p1, p4) == [[1,1],[0,0]]
    @test_throws SpatialUtilities.LibGEOS.GEOSError get_intersection(p14, p15)

    @test check_intersect(p1, p2)
    @test check_intersect(p1, p4)
    @test check_intersect(p1, p4)
    @test !check_intersect(p1, p3)
    @test_throws SpatialUtilities.LibGEOS.GEOSError check_intersect(p14, p15)

    @test union_polygons(p1, p4)[1] == [[1, 0], [0, 0], [0, 1], [1, 1], [1, 0]]
    @test_throws SpatialUtilities.LibGEOS.GEOSError union_polygons(p14, p15)
end
