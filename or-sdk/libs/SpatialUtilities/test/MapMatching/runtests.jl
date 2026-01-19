include("stub.jl")

@testset "MapMatching tests" begin
    @testset "R-tree tests" begin include("test_rtree.jl") end
    @testset "Shortest path tests" begin include("test_shortest_path.jl") end
    @testset "Types tests" begin include("test_types.jl") end
    @testset "Utilities tests" begin include("test_utilities.jl") end
    @testset "Algorithm tests" begin include("test_algorithm.jl") end
    @testset "GeoJSON tests" begin include("test_geojson.jl") end
end
