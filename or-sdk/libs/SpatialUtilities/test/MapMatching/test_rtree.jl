g = basic_osm_graph_stub(:distance)
rtree = construct_rtree(g)

@test rtree.nelems == length(g.ways)

p = GeoLocation(lon=144.96, lat=-37.81)
@test length(MapMatching.nearby_ways(rtree, p, 0.1)) == 2
@test length(MapMatching.nearby_ways(rtree, p, 1.2)) == 3
@test length(MapMatching.nearby_ways(rtree, p, 2.0)) == 4
