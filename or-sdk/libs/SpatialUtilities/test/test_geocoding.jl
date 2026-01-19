lon = 143.958404
lat = -37.818074
search_text = "477 Collins St/ Melbourne; Australia"

# Nominatim
nominatim_config = NominatimGeocodingAPIConfig()
nominatim_forward = forward_geocode(nominatim_config, search_text)
nominatim_reverse = reverse_geocode(nominatim_config, lon, lat)

@test haskey(nominatim_forward, :features)
@test !isempty(nominatim_forward.features)
@test haskey(nominatim_reverse, :features)
@test !isempty(nominatim_reverse.features)

# Mapbox
MAPPOX_ACCESS_TOKEN = get(ENV, "MAPBOX_ACCESS_TOKEN", nothing)

if !isnothing(MAPPOX_ACCESS_TOKEN)
    mapbox_config = MapBoxGeocodingAPIConfig(MAPPOX_ACCESS_TOKEN)
    mapbox_forward = forward_geocode(mapbox_config, search_text; types="address")
    mapbox_reverse = reverse_geocode(mapbox_config, lon, lat)

    @test haskey(mapbox_forward, :features)
    @test !isempty(mapbox_forward.features)
    @test haskey(mapbox_reverse, :features)
    @test !isempty(mapbox_reverse.features)
end