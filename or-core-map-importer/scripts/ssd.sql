-- Create temporary table to store transformed data
drop table if exists tmp_ssd;
drop table if exists tmp_ssd_attribute;

with tmp_ssd1 as (
  select
    ST_GeomFromGeoJSON("geometry") as geom_feature,
    "Shape__Area",
    "Shape__Length",
    row_number () over () as object_id,
    "ssd_code",
    "ssd_name"
  from map_manager.stg_ssd
)
select
  'SSD&&' || object_id as feature_id,
  "ssd_name" as s_name,
  geom_feature,
  object_id as s_source_id,
  "Shape__Area",
  "Shape__Length",
  "ssd_code",
  "ssd_name"
into temporary tmp_ssd
from tmp_ssd1
;
with tmp_attribute_fields as (
  select
    array[
      'id',
      'Shape__Area',
      'Shape__Length',
      'ssd_code',
      'ssd_name'
    ] as attribute_fields
), tmp_ssd2 as (
select
    unnest(array(select feature_id || '&&' || (unnest(attribute_fields)))) as attribute_id,
    feature_id,
    unnest(attribute_fields) as s_name,
    unnest(array[cast("s_source_id" as text),"Shape__Area","Shape__Length","ssd_code","ssd_name"]) as s_value
  from tmp_ssd, tmp_attribute_fields
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value
into temporary tmp_ssd_attribute
from tmp_ssd2
;

-- mm_layer, delete previous data
delete from map_manager.mm_feature where layer_id = 'SSD';

-- mm_layer
insert into map_manager.mm_layer
select
  'SSD' as layer_id,
  'Ssd' as s_name,
  'POLYGON' as e_layer_type
on conflict (layer_id) do update
set
  layer_id = excluded.layer_id,
  s_name = excluded.s_name,
  e_layer_type = excluded.e_layer_type
;

-- mm_feature
insert into map_manager.mm_feature(
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
  'SSD' as layer_id,
  s_name,
  'POLYGON' as e_feature_type,
  s_source_id,  -- Use OBJECTID when we get this
  geom_feature,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start,
  MD5(coalesce(s_name, '') || coalesce(cast(s_source_id as text), '') || coalesce(st_astext(geom_feature), '')) as join_key
from tmp_ssd
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
insert into map_manager.mm_attribute (
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

from tmp_ssd_attribute
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
