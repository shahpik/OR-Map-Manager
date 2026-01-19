# For testing GeoLocation interpolation accounting for floating point error
Base.isapprox(a::GeoLocation, b::GeoLocation, kwargs...) = all([
    isapprox(a.lat, b.lat; kwargs...),
    isapprox(a.lon, b.lon; kwargs...),
    isapprox(a.alt, b.alt; kwargs...)
])
Base.isapprox(a::Vector{GeoLocation}, b::Vector{GeoLocation}, kwargs...) = all(
    isapprox.(a, b; Ref.(kwargs)...)
)

@test MapMatching.deduplicate([1,2,2,3,3,3,4,2,5,5,5]) == [1,2,3,4,2,5]

@test MapMatching.deduplicate2([1,2,1,2,3,4,5,4,5,4,5]) == [1,2,3,4,5]

@test MapMatching.deduplicate3([1,2,5,2,3,4,5,6,5]) == [1,2,3,4,5]

@test MapMatching.deduplicate_path([1,2,1,2,2,3,3,2,4,3,4,3,4,5,6,7,6,8,9,8,9]) == [1,2,4,5,6,8,9]

@test MapMatching.interp(
    GeoLocation(lon=144.90, lat=-37.80),
    GeoLocation(lon=144.91, lat=-37.81),
    0.3
) ≈ GeoLocation(lon=144.903, lat=-37.803)
@test MapMatching.interp(
    GeoLocation(lon=144.91, lat=-37.81),
    GeoLocation(lon=144.90, lat=-37.80),
    0.3
) ≈ GeoLocation(lon=144.907, lat=-37.807)

@test MapMatching.node_to_coords(g, [1001, 1002, 1003]) == [
    [144.96, -37.81], [144.96, -37.815], [144.96, -37.82]
]

@test MapMatching.node_to_geoloc(g, [1001, 1002, 1003]) == [
    GeoLocation(lon=144.96, lat=-37.81),
    GeoLocation(lon=144.96, lat=-37.815),
    GeoLocation(lon=144.96, lat=-37.82),
]
@test MapMatching.node_to_geoloc(g, [1001, 1002, 1003], 0.2, 0.5) ≈ [
    GeoLocation(lon=144.96, lat=-37.811),
    GeoLocation(lon=144.96, lat=-37.815),
    GeoLocation(lon=144.96, lat=-37.8175),
]

@test MapMatching.nodes_to_ways(g, [1001, 1002, 1003]) == [2001]
@test MapMatching.nodes_to_ways(g, [1008, 1007, 1004]) == [2004, 2002]
@test MapMatching.nodes_to_ways(g, [1008, 1007, 1004, 1005]) == [2004, 2002, 2003]

@test geoloc_to_coords(GeoLocation(lon=144.96, lat=-37.81)) == [144.96, -37.81]
@test geoloc_to_coords([
    GeoLocation(lon=144.96, lat=-37.81),
    GeoLocation(lon=144.96, lat=-37.815),
    GeoLocation(lon=144.96, lat=-37.82)
]) == [
    [144.96, -37.81], [144.96, -37.815], [144.96, -37.82]
]

@test coords_to_geoloc(
    [[144.96, -37.81], [144.96, -37.815], [144.96, -37.82]]
) ≈ [
    GeoLocation(lon=144.96, lat=-37.81),
    GeoLocation(lon=144.96, lat=-37.815),
    GeoLocation(lon=144.96, lat=-37.82)
]

state = HMMState(MapMatching.EdgePoint(1001, 1002, 0.3), GeoLocation(lon=144.96, lat=-37.812), 0.3)
@test MapMatching.get_offset(state, 1001) == 0.3
@test MapMatching.get_offset(state, 1002) == 0.7

@test MapMatching.location(g, MapMatching.EdgePoint(1001, 1002, 0.8)) ≈ GeoLocation(lon=144.96, lat=-37.814)
@test MapMatching.location(g, MapMatching.EdgePoint(1004, 1007, 0.5)) ≈ GeoLocation(lon=144.965, lat=-37.8225)

# Matching middle of line
x, y, pos = MapMatching.nearest_point_on_line(
    1.0, 1.0,
    2.0, 2.0,
    2.0, 1.0
)
@test x ≈ 1.5
@test y ≈ 1.5
@test pos ≈ 0.5
# Matching start of line
x, y, pos = MapMatching.nearest_point_on_line(
    1.0, 1.0,
    2.0, 2.0,
    0.0, 1.0
)
@test x ≈ 1.0
@test y ≈ 1.0
@test pos ≈ 0.0
# Matching end of line
x, y, pos = MapMatching.nearest_point_on_line(
    1.0, 1.0,
    2.0, 2.0,
    3.0, 4.0
)
@test x ≈ 2.0
@test y ≈ 2.0
@test pos ≈ 1.0

ep, dist = MapMatching.nearest_point_on_way(g, GeoLocation(lon=144.96, lat=-37.817), 2001)
@test ep.n1 == 1002
@test ep.n2 == 1003
