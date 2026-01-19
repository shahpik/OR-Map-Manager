using Test
using SpatialUtilities

using H3.Lib, H3.Libc
using H3.API
using LightOSM
using Graphs
using DataFrames

include("osm_stub.jl")

@testset "H3 tests" begin include("test_h3functions.jl") end
@testset "Distance tests" begin include("test_distance.jl") end
@testset "Geocoding tests" begin include("test_geocoding.jl") end
@testset "LightOSM utilties tests" begin include("test_lightosm_utils.jl") end
@testset "Geomapping way id from point tests" begin include("test_nearest_way_id_from_point.jl") end
@testset "Geomapping way id from line tests" begin include("test_geomapping.jl") end
@testset "Polygon basic functions tests" begin include("test_polygon.jl") end
@testset "MapMatching tests" begin include("MapMatching/runtests.jl") end
@testset "Lines basic functions tests" begin include("test_line.jl")end
