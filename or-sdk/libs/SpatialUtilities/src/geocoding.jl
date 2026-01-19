"""
    GeocodingAPIConfig

Super type for HTTP configs for geocoding APIs.
"""
abstract type GeocodingAPIConfig end

"""
    MapBoxGeocodingAPIConfig(access_token) -> MapBoxGeocodingAPIConfig

HTTP config for the Mapbox geocoding API, see https://docs.mapbox.com/api/search/geocoding/.

# Fields
- `endpoint::String`: Geocoding endpoint, https://api.mapbox.com/geocoding/v5/mapbox.places/.
- `access_token::String`: Mapbox access token.
"""
struct MapBoxGeocodingAPIConfig <: GeocodingAPIConfig
    endpoint::String
    access_token::String
end
MapBoxGeocodingAPIConfig(access_token) = MapBoxGeocodingAPIConfig("https://api.mapbox.com/geocoding/v5/mapbox.places/", access_token)

"""
    NominatimGeocodingAPIConfig() -> NominatimGeocodingAPIConfig

HTTP config for the Nominatim geocoding API, see https://nominatim.org/release-docs/latest/api/Reverse/ 
or https://nominatim.org/release-docs/latest/api/Search/.

# Fields
- `endpoint::String`: Geocoding endpoint, https://api.mapbox.com/geocoding/v5/mapbox.places/.
"""
struct NominatimGeocodingAPIConfig <: GeocodingAPIConfig
    endpoint::String
end
NominatimGeocodingAPIConfig() = NominatimGeocodingAPIConfig("https://nominatim.openstreetmap.org/")

"""
    DEFAULT_GEOCODING_CONFIG

Default geocoding HTTP config (Nominatim) for requests that do not provide a config.
"""
const DEFAULT_GEOCODING_CONFIG = NominatimGeocodingAPIConfig()

"""
    forward_geocode_url(config::MapBoxGeocodingAPIConfig, search_text)
    forward_geocode_url(config::NominatimGeocodingAPIConfig)

Returns forward geocoding URL, depends on the config type and search text.
"""
forward_geocode_url(config::MapBoxGeocodingAPIConfig, search_text) = joinpath(config.endpoint, "$search_text.json")
forward_geocode_url(config::NominatimGeocodingAPIConfig) = joinpath(config.endpoint, "search")

"""
    forward_geocode([config::GeocodingAPIConfig,] search_text; kwargs...)

Forward geocode search on free-form text input for a location, returns a JSON deserialised object, 
format depends on the API being used, see source documentation.

# Arguments
- `config::GeocodingAPIConfig`: Optional, HTTP config for geocoding API, defaults to `NominatimGeocodingAPIConfig`.
- `search_text`: Free-form text input for a location.
- `kwargs`: Keyword query arguments for the HTTP GET request, see Mapbox / Nominatim source documentation.

# Nominatim Query Kwargs (https://nominatim.org/release-docs/latest/api/Search/)
- street
- city
- county
- state
- country
- postalcode
- format

# Mapbox Query Kwargs (https://docs.mapbox.com/api/search/geocoding/)
- autocomplete
- bbox
- country
- fuzzyMatch
- languag
- limit
- proximity
- routin
- type
- worldview
"""
function forward_geocode(config::MapBoxGeocodingAPIConfig, search_text; kwargs...)
    url = forward_geocode_url(config, HTTP.escapeuri(replace(search_text, r";" => ",")))
    kwargs = (; access_token=config.access_token, kwargs...)
    return JSON3.read(HTTP.get(url, query=kwargs).body)
end
function forward_geocode(config::NominatimGeocodingAPIConfig, search_text; kwargs...)
    url = forward_geocode_url(config)
    kwargs = (; q=search_text, format="geojson", kwargs...)
    return JSON3.read(HTTP.get(url, query=kwargs).body)
end
forward_geocode(search_text; kwargs...) = forward_geocode(DEFAULT_GEOCODING_CONFIG, search_text; kwargs...)

"""
    reverse_geocode_url(config::MapBoxGeocodingAPIConfig, lon, lat)
    reverse_geocode_url(config::NominatimGeocodingAPIConfig)

Returns reverse geocoding URL, depends on the config type and lon lat coordinate.
"""
reverse_geocode_url(config::MapBoxGeocodingAPIConfig, lon, lat) = joinpath(config.endpoint, "$lon,$lat.json")
reverse_geocode_url(config::NominatimGeocodingAPIConfig) = joinpath(config.endpoint, "reverse")

"""
    reverse_geocode([config::GeocodingAPIConfig,] lon, lat; kwargs...)

Reverse geocode search on a single coordinate (lon, lat), returns a JSON deserialised object, 
format depends on the API being used.

# Arguments
- `config::GeocodingAPIConfig`: Optional, HTTP config for geocoding API, defaults to `NominatimGeocodingAPIConfig`.
- `lon`: Longitude of the coordinate.
- 'lat`: Latitude of the coordinate.
- `kwargs`: Keyword query arguments for the HTTP GET request, see Mapbox / Nominatim source documentation.

# Nominatim Query Kwargs (https://nominatim.org/release-docs/latest/api/Reverse/)
- format

# Mapbox Query Kwargs (https://docs.mapbox.com/api/search/geocoding/)
- country
- language
- limit
- reverseMode
- routing
- types
- worldview
"""
function reverse_geocode(config::MapBoxGeocodingAPIConfig, lon, lat; kwargs...)
    url = reverse_geocode_url(config, lon, lat)
    kwargs = (; access_token=config.access_token, kwargs...)
    return JSON3.read(HTTP.get(url, query=kwargs).body)
end
function reverse_geocode(config::NominatimGeocodingAPIConfig, lon, lat; kwargs...)
    url = reverse_geocode_url(config)
    kwargs = (; lon=lon, lat=lat, format="geojson", kwargs...)
    return JSON3.read(HTTP.get(url, query=kwargs).body)
end
reverse_geocode(lon, lat; kwargs...) = reverse_geocode(DEFAULT_GEOCODING_CONFIG, lon, lat; kwargs...)
