insert into map_manager.mm_hex (n_hex_index, n_hex_resolution, geom_hex)
select
  hex_int::bigint as n_hex_index,
  6 as n_hex_resolution,
  ST_GeomFromGeoJSON(geometry) as geom_hex
from map_manager.stg_hex
on conflict do nothing  -- skip importing existing hex indexes
;
