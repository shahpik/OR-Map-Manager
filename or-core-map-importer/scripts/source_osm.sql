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
  from map_manager.stg_source_osm
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

-- mm_feature
insert into map_manager.mm_temp_feature (
  feature_id,
  layer_id,
  s_name,
  e_feature_type,
  s_source_id,
  geom_feature,
  join_key
)
select 
  feature_id, 
  'OSM' as layer_id, 
  s_name, 
  e_feature_type, 
  s_source_id, 
  geom_feature,
  MD5(coalesce(s_name, '') || coalesce(s_source_id, '') || coalesce(st_astext(geom_feature), '')) as join_key
from tmp_osm;

-- mm_attribute
insert into map_manager.mm_temp_attribute(
attribute_id,
feature_id,
s_name,
s_value,
join_key
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value,
  MD5(coalesce(feature_id, '') || coalesce(s_name, '') || coalesce(s_value, '')) as join_key
from tmp_osm_attribute;