module SpatialUtilities
using LightOSM
using DataFrames
using DataFrames: mean
using H3.API
using H3.Lib: Geofence, pointer, GeoPolygon, polyfill, GeoCoord, maxPolyfillSize, H3Index
using H3.Libc: calloc, free
using HTTP
using JSON3
using DataStructures: OrderedDict
using SparseArrays
using LibGEOS, GeoInterface, GeoFormatTypes  # Polygon functions

# H3 hex functions
export hex_to_xy, h3coords_to_xy, h3coords_to_lat_long, yx_to_h3coord, xy_to_h3coord, h3_to_geo_location_bounary
export xy_to_hex, linestring_to_hex, linestring_to_all_hex, way_to_hex, osm_way_to_linestring, get_hexes_inside_polygon
export encode_nodes_to_H3_hex, get_all_h3_res_levels, convert_to_h3_coord, get_lat_lon_centroid
export get_lon_centroid, lons_near_dateline, get_hex_extremities, get_geojson_from_hexs

# Geocoding
export MapBoxGeocodingAPIConfig, NominatimGeocodingAPIConfig, forward_geocode, reverse_geocode

# rtree functions
export get_osm_rtree, get_isect_ids, get_contained_ids
export pt_dist_to_line

# LightOSM utilities
export get_way_heading, get_adjacent_nodes_on_graph, get_connected_ways, get_node_pos
export get_way_ls_coords, get_way_ls_nodes, reverse_nodes_to_connect_ways, get_way_path_start_end_node
export get_way_path_dir_oab, get_way_path_dir_oab_single, lnode_distance, get_way_oab_from_node_pair
export total_graph_distance, total_geojson_distance, compass_direction

# general angle/linestring utilities
export get_point_dir, get_dirs_along_linestring, is_within_angle, convert_to_float_linestring, swapxy, lstring_distance, inverse_haversine

# nearest way_id functions
export knn_pairs, calculate_edge_distance, min_dist_way_id
export get_way_id_from_point

# These geomapping functions have been deprecated and replaced with MapMatching:
export get_best_way_path_from_linestring
export e_metric_path_length, e_metric_start_to_end_heading, e_metric_start_end_dist, e_metric_total_length, e_metric_interpolated_path_distance
export e_metric_combined, e_metric_start_end_dist_length, e_metric_weighted_angle_length

# polygon basic functions
export simplify_2d_polygon, calculate_area_2d_polygon, centroid_2d_polygon
export get_polygon_wkt, get_intersection, check_intersect, union_polygons
export calculate_area_2d_polygon_geo, validate_polygon

# MapMatching
export MapMatching
export MapMatch, HMMState, HMMGraph, EdgePoint
export match_linestring, match_geojson_linestrings, construct_hmm_graph, construct_rtree
export geoloc_to_coords, coords_to_geoloc, to_geojson

# Lines
export get_line_wkt, merge_lines

include("MapMatching/MapMatching.jl")
using .MapMatching
include("exceptions.jl")
include("h3functions.jl")
include("rtree.jl")
include("distance.jl")
include("geocoding.jl")
include("nearest_way_id_from_point.jl")
include("geomapping.jl")
include("geomapper_line_to_way.jl")
include("geomapper_errors.jl")
include("lightosm_utils.jl")
include("polygon.jl")
include("shell_utils.jl")
include("line.jl")

end # module
