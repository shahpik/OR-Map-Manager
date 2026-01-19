default_zoom = 6  # Default zoom, set to the OR preferred zoom level
test_graph = basic_osm_graph_stub()

@testset "H3encoding" begin
    # Encodes specific points to hex
    test_y = -37.8293757  # lat
    test_x = 144.937603  # lon
    test_gc = GeoCoord(-0.6602471599389347, 2.529638382298411)
    test_hex = 0x086be6356fffffff
    test_hex2 = 0x0862e2ca4fffffff
    test_missing_hex = 0x0000000000000000
    test_multi_hex_id = [0x086be63467ffffff, 0x086be6354fffffff, 0x086be63547ffffff, 0x086be63567ffffff]
    test_multi_hex_id2 = [0x086be63467ffffff]
    @test SpatialUtilities.xy_to_h3coord(test_x, test_y) == test_gc
    @test SpatialUtilities.xy_to_hex(test_x, test_y, default_zoom) == test_hex
    @test SpatialUtilities.xy_to_hex(test_x, missing, default_zoom) == test_missing_hex
    @test SpatialUtilities.xy_to_hex(missing, 1.23, default_zoom) == test_missing_hex
    @test SpatialUtilities.xy_to_hex(missing, missing, default_zoom) == test_missing_hex
    @test SpatialUtilities.xy_to_hex(-38, 144, default_zoom) == test_hex2
    
    # Encode a LineString to hex
    test_short_way_id = 2003
    test_long_way_id = 2001
    test_multi_hex_way_id = 237263156
    test_linestring = [[-38.0754637, 145.3326838], [-38.0755637, 145.3326838]]
    test_linestring_multi_hex = [[ -37.68784743535062, 144.8502870355562], [-37.819560273939025, 144.95081591040991]]
    test_linestring_multi_hex2 = [[ -37.68784743535062, 144.8502870355562], [-37.68784743535062, 144.8502870355562]]
    test_way_hex_id = 0x086be63d1fffffff
    
    @test SpatialUtilities.osm_way_to_linestring(test_short_way_id, test_graph) == test_linestring
    @test SpatialUtilities.linestring_to_hex(test_linestring, default_zoom) == test_way_hex_id
    @test SpatialUtilities.way_to_hex(test_long_way_id, test_graph, default_zoom) == test_way_hex_id
    @test SpatialUtilities.linestring_to_all_hex(test_linestring_multi_hex, default_zoom) == test_multi_hex_id
    @test SpatialUtilities.linestring_to_all_hex(test_linestring_multi_hex2, default_zoom) == test_multi_hex_id2
    
    # Encoding linestrings that crosses multiple hexes
    test_zoom = 8  # uses first sorted hex, could explore different approaches
    test_ls_multi_hex = 0x088be63d1a7fffff

    @test SpatialUtilities.way_to_hex(test_long_way_id, test_graph, test_zoom) == test_ls_multi_hex
    @test Set(SpatialUtilities.encode_nodes_to_H3_hex(test_graph.nodes, default_zoom)) == Set(test_way_hex_id)

end


@testset "H3decoding" begin
    # Decode Polygon to Hexes 
    test_poly = [[-37.7916,145.0133], [-37.7940,145.1431], [-37.8605,145.1407], [-37.8579,145.0374]]
    test_poly_str = [["-37.7916","145.0133"], ["-37.7940","145.1431"], ["-37.8605","145.1407"], ["-37.8579","145.0374"]]
    test_poly_small = [[ -37.8130553, 144.9597517], [-37.81385,144.96327], [-37.81535,144.96199]]
    test_poly_hex = Set([0x086be63cdfffffff, 0x086be63cd7ffffff, 0x086be6352fffffff])
    test_poly_small_hex = Set([0x086be63567ffffff])
    test_padded_hex = Set([0x086be63cdfffffff,0x086be63cd7ffffff,0x086be6352fffffff,0x086be63577ffffff,0x086be63567ffffff,0x086be63ccfffffff,0x086be63cc7ffffff,0x086be63c8fffffff,0x086be63527ffffff,0x086be63cf7ffffff,0x086be63507ffffff,0x086be6350fffffff])
    
    @test SpatialUtilities.convert_to_h3_coord(test_poly[1]) == GeoCoord(-0.659587849596689, 2.5309595441822927)
    @test SpatialUtilities.convert_to_h3_coord(test_poly_str[1]) == GeoCoord(-0.659587849596689, 2.5309595441822927)
    @test isapprox(SpatialUtilities.h3coords_to_lat_long(SpatialUtilities.convert_to_h3_coord(test_poly)), test_poly; atol=1e-8)
    @test isapprox(SpatialUtilities.h3coords_to_lat_long(SpatialUtilities.convert_to_h3_coord(test_poly_str)), test_poly; atol=1e-8)

    @test all(SpatialUtilities.get_lat_lon_centroid(test_poly) .≈ (-37.826, 145.083625))
    @test Set(SpatialUtilities.get_hexes_inside_polygon(test_poly, default_zoom, 0)) == test_poly_hex
    @test Set(SpatialUtilities.get_hexes_inside_polygon(test_poly, default_zoom, 1)) == test_padded_hex
    @test Set(SpatialUtilities.get_hexes_inside_polygon(test_poly_small, default_zoom)) == test_poly_small_hex


    @test length(SpatialUtilities.get_hexes_inside_polygon(test_poly, 8, 0)) == 89
    # Longitude Wraparound testing
    test_wrap_poly = [[66.6,179.1], [66.4,-179.1], [66.6,179.1], [66.4,-179.1]]
    test_wrap_centroid_hex = Set([0x0850d956ffffffff])
    test_wrap_poly_big = [[66.7,178.1], [66.5,-179.2], [66.6,178.2], [66.4,-179.5]]
    test_big_poly_hex_res_5 = Set([0x0850d919bfffffff, 0x0850d956ffffffff, 0x0850d956bfffffff])
    @test Set(SpatialUtilities.get_hexes_inside_polygon(test_wrap_poly, 5, 1)) == test_wrap_centroid_hex
    @test_broken Set(SpatialUtilities.get_hexes_inside_polygon(test_wrap_poly_big, 5, 0)) == test_big_poly_hex_res_5  
end
