drop table if exists tmp_osm;
drop table if exists tmp_osm_attribute;

with tmp_osm1 as (
  select
    'OSM&&' || upper("type") || "id" as feature_id,
    case
      when "type" = 'node' then 'POINT'
      when "type" = 'way' then 'LINE'
    end as e_feature_type,
    "id" as s_source_id,
    ST_GeomFromGeoJSON("geometry") as geom_feature,
    "tags"::jsonb as tags
  from map_manager.stg_osm
)
select
  feature_id,
  tags->>'name' as s_name,
  e_feature_type,
  s_source_id,
  geom_feature,
  tags
into temporary tmp_osm
from tmp_osm1
;

select
  feature_id || '&&' || jsonb_object_keys(tags) as attribute_id,
  feature_id,
  jsonb_object_keys(tags) as s_name,
  tags->>jsonb_object_keys(tags) as s_value 
into temporary tmp_osm_attribute
from tmp_osm
;

-- mm_layer
insert into map_manager.mm_layer
select
  'OSM' as layer_id,
  'OpenStreetMap' as s_name,
  'GRAPH' as e_layer_type
on conflict (layer_id) do update
set
  layer_id = excluded.layer_id,
  s_name = excluded.s_name,
  e_layer_type = excluded.e_layer_type
;

-- mm_feature
insert into map_manager.mm_feature (
  feature_id,
  layer_id,
  s_name,
  e_feature_type,
  s_source_id,
  geom_feature,
  changeset_id,
  global_version_id_start,
  join_key
)
select 
  feature_id, 
  'OSM' as layer_id, 
  s_name, 
  e_feature_type, 
  s_source_id, 
  geom_feature,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start,
  MD5(coalesce(s_name, '') || coalesce(s_source_id, '') || coalesce(st_astext(geom_feature), '')) as join_key
from tmp_osm
on conflict (feature_id, changeset_id) do update
set
  feature_id = excluded.feature_id,
  layer_id = excluded.layer_id,
  s_name = excluded.s_name,
  e_feature_type = excluded.e_feature_type,
  s_source_id = excluded.s_source_id,
  geom_feature = excluded.geom_feature,
  changeset_id = excluded.changeset_id,
  global_version_id_start = excluded.global_version_id_start,
  join_key = excluded.join_key
;
-- mm_attribute
insert into map_manager.mm_attribute(
  attribute_id,
  feature_id,
  s_name,
  s_value,
  changeset_id,
  global_version_id_start,
  join_key
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start,
  MD5(coalesce(feature_id, '') || coalesce(s_name, '') || coalesce(s_value, '')) as join_key
from tmp_osm_attribute
on conflict (attribute_id, changeset_id) do update
set
  attribute_id = excluded.attribute_id,
  feature_id = excluded.feature_id,
  s_name = excluded.s_name,
  s_value = excluded.s_value,
  changeset_id = excluded.changeset_id,
  global_version_id_start = excluded.global_version_id_start,
  join_key = excluded.join_key
;