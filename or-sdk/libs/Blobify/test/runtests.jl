using Test
using Blobify
using LightOSM

include("osm_stub.jl")

@testset "Blobify tests" begin
    @testset "Vector conversion" begin include("test_blob.jl") end
    @testset "Intersections" begin include("test_intersections.jl") end
    @testset "Intersections serialization" begin include("test_intersections_serialize.jl") end
end
