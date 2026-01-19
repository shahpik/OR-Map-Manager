g = basic_osm_graph_stub(:distance)

#=
Test linestrings in GeoJSON format
ls1: Between 1008 and 1007 -> 1007 -> 1004 -> 1003 -> 1002 -> Between 1002 and 1001
ls2: Between 1007 and 1006 -> 1006 -> 1001 -> Between 1001 and 1002
=#
geoj = Dict{String,Any}(
    "type" => "FeatureCollection",
    "features" => [
        Dict{String,Any}(
            "type" => "Feature",
            "id" => "ls1",
            "properties" => Dict{String,Any}(
                "name" => "test2"
            ),
            "geometry" => Dict{String,Any}(
                "type" => "LineString",
                "coordinates" => [
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
                ]
            )
        ),
        Dict{String,Any}(
            "type" => "Feature",
            #"id" => "ls2",  # test graceful handling of no ID
            "properties" => Dict{String,Any}(
                "name" => "test2"
            ),
            "geometry" => Dict{String,Any}(
                "type" => "LineString",
                "coordinates" => [
                    [144.96962, -37.81643], 
                    [144.96958, -37.81490], 
                    [144.96516, -37.81233], 
                    [144.96052, -37.81012], 
                    [144.96035, -37.81195], 
                    [144.96044, -37.81328]
                ]
            )
        ),
        Dict{String,Any}(
            "type" => "Feature",
            "id" => "ls3",
            "properties" => Dict{String,Any}(
                "name" => "test2"
            ),
            "geometry" => Dict{String,Any}(
                "type" => "MultiLineString",
                "coordinates" => [
                    [
                        [144.97816, -37.82023], 
                        [144.97434, -37.82009], 
                        [144.97108, -37.81958], 
                        [144.96863, -37.82012], 
                        [144.96559, -37.82189], 
                    ], [
                        [144.96271, -37.82399], 
                        [144.95992, -37.82545], 
                        [144.95906, -37.82463], 
                        [144.95928, -37.82223], 
                        [144.95954, -37.81958], 
                        [144.95958, -37.81602], 
                        [144.95945, -37.81300],
                    ]
                ]
            )
        ),
        Dict{String,Any}(
            "type" => "Feature",
            "id" => "ls4",
            "properties" => Dict{String,Any}(
                "name" => "test2",
                "status" => "will_fail"
            ),
            "geometry" => Dict{String,Any}(
                "type" => "Polygon",
                "coordinates" => [
                    [
                        [144.97816, -37.82023], 
                        [144.97434, -37.82009], 
                        [144.97108, -37.81958], 
                        [144.96863, -37.82012], 
                        [144.96559, -37.82189], 
                    ], [
                        [144.96271, -37.82399], 
                        [144.95992, -37.82545], 
                        [144.95906, -37.82463], 
                        [144.95928, -37.82223], 
                        [144.95954, -37.81958], 
                        [144.95958, -37.81602], 
                        [144.95945, -37.81300],
                    ]
                ]
            )
        ),
    ]
)

rtree = construct_rtree(g)

geoj = match_geojson_linestrings(g, geoj, rtree)

@test geoj["features"][1]["properties"]["matched_ways"] == [2004, 2002, 2001]
@test geoj["features"][2]["properties"]["matched_ways"] == [2002, 2001]
@test geoj["features"][3]["properties"]["matched_ways"] == [2004, 2002, 2001]
@test geoj["features"][1]["properties"]["mapmatching_error"] isa AbstractFloat
@test geoj["features"][2]["properties"]["mapmatching_error"] isa AbstractFloat
@test geoj["features"][3]["properties"]["mapmatching_error"] isa AbstractFloat
