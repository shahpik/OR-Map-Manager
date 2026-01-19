using Test
using Tile38Interface

@testset "Tile38Interface" begin
    Tile38Interface.set_global_connection()
    # @test Tile38Interface.set_object("test_key", "test_id", """{\"type\":\"Polygon\",\"coordinates\":[[[-111.9787,33.4411],[-111.8902,33.4377],[-111.8950,33.2892],[-111.9739,33.2932],[-111.9787,33.4411]]]}""") == "OK"
    # @test Tile38Interface.get_object("test_key", "test_id") == "{\"type\":\"Polygon\",\"coordinates\":[[[-111.9787,33.4411],[-111.8902,33.4377],[-111.895,33.2892],[-111.9739,33.2932],[-111.9787,33.4411]]]}"
    # @test Tile38Interface.scan_key("test_key") == [0, ["test_id"]]
    # @test Tile38Interface.intersect_point("test_key", [-111.8902, 33.4377]) == [0, ["test_id"]]
    # @test Tile38Interface.intersect_linestring("test_key", [[-111.9787,33.4411],[-111.8902,33.4377]]) == [0, ["test_id"]]
    # @test Tile38Interface.intersect_object("test_key", """{\"type\":\"Polygon\",\"coordinates\":[[[-111.9787,33.4411],[-111.8902,33.4377],[-111.8950,33.2892],[-111.9739,33.2932],[-111.9787,33.4411]]]}""") == [0, ["test_id"]]
    # @test Tile38Interface.intersect_circle("test_key", 33.3652303, -111.9352341, 100) == [0, ["test_id"]]
    # @test Tile38Interface.del_object("test_key", "test_id") == 1

    # Test WHEREIN commands
    # @test Tile38Interface.set_object_with_field(
    #     "test_key", 
    #     "test_WAYS&&1", 
    #     "meta",
    #     """{"layer_id":"WAYS"}""",
    #     """{"feature_id":"WAYS&&1","layer_id":"WAYS","feature_type":"LINE","type":"Feature","geometry":{"coordinates":[[145.07169216224293,-37.82289884508096],[145.0863201674847,-37.82458390194396],[145.1017481417632,-37.82641936653332],[145.11294770827658,-37.8277131911889],[145.1139762398949,-37.82232712061829]],"type":"LineString"}}""") == "OK"
    # @test Tile38Interface.set_object_with_field(
    #     "test_key", 
    #     "test_LOCALITY&&1", 
    #     "meta",
    #     """{"layer_id":"LOCALITY"}""",
    #     """{"feature_id":"LOCALITY&&1","layer_id":"LOCALITY","feature_type":"POLYGON","type":"Feature","geometry":{"coordinates":[[[145.08369169779297,-37.82804416594547],[145.0903962001953,-37.82999989556511],[145.09995773487248,-37.829428226114636],[145.0996910785264,-37.82277848240436],[145.09828160927196,-37.81802399966751],[145.08696776146695,-37.8175124231499],[145.0819393846652,-37.821514662447754],[145.08369169779297,-37.82804416594547]]],"type":"Polygon"}}""") == "OK"
    # @test Tile38Interface.set_object_with_field(
    #     "test_key", 
    #     "test_INTERSECTION&&1", 
    #     "meta",
    #     """{"layer_id":"INTERSECTION"}""",
    #     """{"feature_id":"INTERSECTION&&1","layer_id":"INTERSECTION","feature_type":"POINT","type":"Feature","geometry":{"coordinates":[145.09720028422606,-37.825877253034434],"type":"Point"}}""") == "OK"

    # try
    #     resp = Tile38Interface.get_object("test_key","test_INTERSECTION&&1", timeout=25)
    #     @info "resp : $(resp)"
    #     @test resp == "{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[145.09720028422606,-37.825877253034434]},\"feature_id\":\"INTERSECTION&&1\",\"layer_id\":\"INTERSECTION\",\"feature_type\":\"POINT\",\"properties\":{}}"
    # catch e
    #     @error "An error occurred: $(e)"
    # end

    # try
    #     resp = Tile38Interface.intersect_object("test_key", """{\"type\":\"Polygon\",\"coordinates\":[[[-111.9787,33.4411],[-111.8902,33.4377],[-111.8950,33.2892],[-111.9739,33.2932],[-111.9787,33.4411]]]}""", timeout=0.0000025)
    #     @info "resp : $(resp)"
    #     @test resp == [0, ["test_id"]]
    # catch e
    #     @error "An error occurred: $(e)"
    # end

    # @test Tile38Interface.get_intersecting_objects(
    #     "test_key", 
    #     """{"type":"Feature","properties":{},"geometry":{"coordinates":[[145.09256754472364,-37.83255730992912],[145.0935198888148,-37.828615846118964],[145.09618645227084,-37.82479453134712],[145.09782448410704,-37.82229702973505],[145.10216717316365,-37.81964898391268]],"type":"LineString"}}""",
    #     # "meta.layer_id 2 LOCALITY WAYS IDS") == [0, []]
    #     "meta.layer_id 2 LOCALITY WAYS IDS") == [0, ["test_WAYS&&1", "test_LOCALITY&&1"]]
    # @test Tile38Interface.intersect_circle_objects(
    #     "test_key",  
    #     -37.82804416594547,
    #     145.08369169779297,
    #     100.0,
    #     "test*",
    #     "meta.layer_id 2 LOCALITY WAYS IDS") == [0, ["test_LOCALITY&&1"]]
    # @test Tile38Interface.nearby_point(
    #     "test_key",  
    #     100,
    #     -37.82804416594547,
    #     145.08369169779297,
    #     "test*",
    #     "meta.layer_id 2 LOCALITY WAYS IDS",
    #     100.0) == [0, ["test_LOCALITY&&1","test_WAYS&&1"]]

    # try
    #     resp = Tile38Interface.get_intersecting_objects(
    #         "LRS", 
    #         """{"type":"Feature","properties":{},"geometry":{"coordinates":[[145.09256754472364,-37.83255730992912],[145.0935198888148,-37.828615846118964],[145.09618645227084,-37.82479453134712],[145.09782448410704,-37.82229702973505],[145.10216717316365,-37.81964898391268]],"type":"LineString"}}""",
    #         # "meta.layer_id 2 LOCALITY WAYS IDS") == [0, []]
    #         "meta.layer_id 2 LOCALITY WAYS IDS",
    #         limit=1000,
    #         buffer=15.0,
    #         timeout=0.005
    #     )
    #     @info "resp : $(resp)"
    #     @test resp == [0, ["test_WAYS&&1", "test_LOCALITY&&1"]]
    # catch e
    #     @error "An error occurred: $(e)"
    # end


    # try
    #     resp = Tile38Interface.intersect_circle_objects(
    #         "LRS",  
    #         -37.82804416594547,
    #         145.08369169779297,
    #         15.0,
    #         "test*",
    #         limit=1000,
    #         timeout=20
    #     )
    #     @info "resp : $(resp)"
    #     @test resp == [0, ["test_LOCALITY&&1"]]
    # catch e
    #     @error "An error occurred: $(e)"
    # end

    # Test SET with FIELD Functions
    # @test Tile38Interface.set_object_with_field(
    #     "LRS", 
    #     "LOCALITY&&1", 
    #     "meta",
    #     """{"speed":61,"layer_id":"LOCALITY"}""",
    #     """{"feature_id":"LOCALITY&&1","layer_id":"LOCALITY","feature_type":"POLYGON","type":"Feature","properties":{"LocalityName":"LINDSAY POINT","HexIndexes":[606831691595513900,606831691595513900]},"geometry":{"type":"Polygon","coordinates":[[[145.07654319688731,-37.81969676750438],[145.07654319688731,-37.843430548358185],[145.11157155996295,-37.843430548358185],[145.11157155996295,-37.81969676750438],[145.07654319688731,-37.81969676750438]]]}}""") == "OK"
            
    # Test FSET Functions
    # @test Tile38Interface.set_object("LRS", "LOCALITY&&1", """{"feature_id":"LOCALITY&&1","layer_id":"LOCALITY","feature_type":"POLYGON","type":"Feature","properties":{"LocalityName":"LINDSAY POINT","HexIndexes":[606831691595513900,606831691595513900]},"geometry":{"type":"Polygon","coordinates":[[[145.07654319688731,-37.81969676750438],[145.07654319688731,-37.843430548358185],[145.11157155996295,-37.843430548358185],[145.11157155996295,-37.81969676750438],[145.07654319688731,-37.81969676750438]]]}}""") == "OK"
    # # Test setting single values
    # @test Tile38Interface.set_object_field("LRS", "LOCALITY&&1", "layer_id", "LOCALITY") == 1
    # # Test setting complex values
    # @test Tile38Interface.set_object_field("LRS", "LOCALITY&&1", "meta", """{"speed":61,"layer_id":"LOCALITY"}""") == 1

    # Test SCAN with WHEREIN
    # @test Tile38Interface.set_object_with_field(
    # "LRS", 
    # "LOCALITY&&1", 
    # "meta",
    # """{"speed":61,"layer_id":"LOCALITY"}""",
    # """{"feature_id":"LOCALITY&&1","layer_id":"LOCALITY","feature_type":"POLYGON","type":"Feature","properties":{"LocalityName":"LINDSAY POINT","HexIndexes":[606831691595513900,606831691595513900]},"geometry":{"type":"Polygon","coordinates":[[[145.07654319688731,-37.81969676750438],[145.07654319688731,-37.843430548358185],[145.11157155996295,-37.843430548358185],[145.11157155996295,-37.81969676750438],[145.07654319688731,-37.81969676750438]]]}}""") == "OK"
    # scan_resp = Tile38Interface.scan_key_with_where_in("LRS", "meta.layer_id 1 LOCALITY", limit=1)
    # @test scan_resp[1] == 1
    # @test scan_resp[2][1][1] == "LOCALITY&&1"
end