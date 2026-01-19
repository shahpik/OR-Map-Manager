# Intersection of Collins St and William St, Melbourne CBD
test_intsc = Intersection{ComplexIntersection}(
    type=ComplexIntersection,
    centroid_nodes=Int[2189145403, 2189145381, 2189145394, 2189145390],
    inc_nodes=Int[7620884652, 3394725163, 7620884634, 6167191174],
    inc_nodes_dirs=Float64[-111.33247590245558, -19.776781150510537, 70.5153974960833, 161.10294661444019],
    inc_ways=Int[878771431, 208642574, 207830036, 505256329],
    out_nodes=Int[7620884633, 6167191723, 7620884651, 6167191177],
    out_nodes_dirs=Float64[-111.01660191323518, 160.26477241261227, 69.30741769211613, -19.781618945091367],
    out_ways=Int[208642573, 208642575, 207830040, 208641736],
    has_light=true,
    internal_nodes=Int[4520380538, 4520380544, 4520380545, 4520380543, 4520380540, 4520380539, 4520380541, 4520380542],
    internal_ways=Int[],
    nodes=Dict(
        7620884652 => Node(7620884652, GeoLocation(-37.8176, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        4520380538 => Node(4520380538, GeoLocation(-37.8176, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        2189145381 => Node(2189145381, GeoLocation(-37.8177, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        4520380544 => Node(4520380544, GeoLocation(-37.8176, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        3394725163 => Node(3394725163, GeoLocation(-37.8178, 144.959), Dict{String,Any}("highway"=>"traffic_signals", "traffic_signals:direction"=>"forward", "lanes"=>1, "maxspeed"=>40)),
        6167191723 => Node(6167191723, GeoLocation(-37.8177, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        7620884651 => Node(7620884651, GeoLocation(-37.8175, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        4520380545 => Node(4520380545, GeoLocation(-37.8177, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        6167191177 => Node(6167191177, GeoLocation(-37.8176, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        2189145403 => Node(2189145403, GeoLocation(-37.8176, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        4520380543 => Node(4520380543, GeoLocation(-37.8176, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        7620884633 => Node(7620884633, GeoLocation(-37.8177, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        4520380540 => Node(4520380540, GeoLocation(-37.8177, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        2189145394 => Node(2189145394, GeoLocation(-37.8177, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        2189145390 => Node(2189145390, GeoLocation(-37.8176, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        4520380539 => Node(4520380539, GeoLocation(-37.8176, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        4520380541 => Node(4520380541, GeoLocation(-37.8177, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        4520380542 => Node(4520380542, GeoLocation(-37.8176, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        7620884634 => Node(7620884634, GeoLocation(-37.8176, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40)),
        6167191174 => Node(6167191174, GeoLocation(-37.8175, 144.959), Dict{String,Any}("lanes"=>1, "maxspeed"=>40))
    ),
    ways=Dict(
        878771431 => Way(878771431, [7620884652, 2189145381, 4520380541, 4520380540, 2189145394], Dict{String, Any}("name" => "Collins Street", "reverseway" => false, "oneway" => true, "source" => "nearmap", "highway" => "tertiary", "lanes" => 1, "maxspeed" => 40, "surface" => "asphalt")), 
        207830036 => Way(207830036, [2180785610, 6407789676, 2180785627, 3394725164, 6696357495, 7620884634, 2189145403], Dict{String, Any}("name" => "Collins Street", "reverseway" => false, "oneway" => true, "source" => "nearmap", "highway" => "tertiary", "lanes" => 1, "maxspeed" => 40, "name:zh" => "柯林斯街", "surface" => "asphalt")), 
        207830040 => Way(207830040, [2189145403, 4520380539, 4520380538, 2189145390, 7620884651, 6696357515, 2180785612, 6721913991, 9561515050, 2182479617, 2180815093, 2180785595, 3394726516, 6167489481, 2180822307], Dict{String, Any}("name" => "Collins Street", "reverseway" => false, "oneway" => true, "source" => "nearmap", "highway" => "tertiary", "lanes" => 1, "maxspeed" => 40, "surface" => "asphalt")), 
        208641736 => Way(208641736, [2189145394, 4520380545, 4520380544, 2189145403, 6167191177, 2189145377, 6430275324, 6430275321, 6696357519, 2189145378], Dict{String, Any}("cycleway" => "track", "name" => "William Street", "reverseway" => false, "oneway" => true, "highway" => "tertiary", "lanes" => 1, "maxspeed" => 40, "surface" => "asphalt")), 
        208642574 => Way(208642574, [9561515025, 8955976465, 6696357511, 8957196428, 8957196429, 8957196430, 8957196431, 3394725163, 2189145394], Dict{String, Any}("cycleway" => "lane", "name" => "William Street", "reverseway" => false, "oneway" => true, "highway" => "tertiary", "lanes" => 1, "maxspeed" => 40, "surface" => "asphalt")), 
        208642573 => Way(208642573, [2189145394, 7620884633, 6696357496, 2180785581, 3394725168, 6407789673, 2180785588, 2180785571], Dict{String, Any}("name" => "Collins Street", "reverseway" => false, "oneway" => true, "source" => "nearmap", "highway" => "tertiary", "lanes" => 1, "maxspeed" => 40, "name:zh" => "柯林斯街", "surface" => "asphalt")), 
        208642575 => Way(208642575, [2189145381, 6167191723, 8957196433, 2189145393, 9561515026, 6696357510, 2189158030, 4520380546, 8955976490, 9561515023], Dict{String, Any}("cycleway" => "track", "name" => "William Street", "reverseway" => false, "oneway" => true, "highway" => "tertiary", "lanes" => 1, "maxspeed" => 40, "surface" => "asphalt")), 
        505256329 => Way(505256329, [26034544, 6430275320, 3394725165, 6167191174, 2189145390, 4520380543, 4520380542, 2189145381], Dict{String, Any}("cycleway" => "track", "name" => "William Street", "reverseway" => false, "oneway" => true, "highway" => "tertiary", "lanes" => 1, "maxspeed" => 40, "surface" => "asphalt"))
    ),
    centroid_to_inc=Dict{Integer, Vector{Integer}}(2189145403 => [7620884634], 2189145381 => [7620884652], 2189145394 => [3394725163], 2189145390 => [6167191174]),
    centroid_to_out=Dict{Integer, Vector{Integer}}(2189145403 => [6167191177], 2189145381 => [6167191723], 2189145394 => [7620884633], 2189145390 => [7620884651]),
    inc_to_centroid=Dict{Integer, Integer}(7620884652 => 2189145381, 3394725163 => 2189145394, 7620884634 => 2189145403, 6167191174 => 2189145390),
    out_to_centroid=Dict{Integer, Integer}(7620884633 => 2189145394, 6167191723 => 2189145381, 7620884651 => 2189145390, 6167191177 => 2189145403)
)
test_intersections = Intersection[test_intsc]

@testset "Intersection serialization" begin
    # Export to JSON dict
    json = export_intersection_json(test_intersections)
    @test json[1]["has_light"] == test_intersections[1].has_light
    @test all(json[1]["centroid_nodes"] .== string.(test_intersections[1].centroid_nodes))
    @test json[1]["id"] == "1"

    # Export to JSON file
    rm("test_intersections_serialize_output.json", force=true)
    export_intersection_json(test_intersections, "test_intersections_serialize_output.json")

    # Import JSON file
    intObjects, nodeIntMap, n_intersections, has_lights = load_intersection_light_objects("test_intersections_serialize_output.json")
    @test intObjects[1]["centroid_nodes"] == json[1]["centroid_nodes"]
    @test n_intersections == length(test_intersections)
    @test has_lights[1] == test_intersections[1].has_light

    # Cleanup
    rm("test_intersections_serialize_output.json", force=true)
end
