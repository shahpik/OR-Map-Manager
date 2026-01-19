drop table if exists tmp_vcsd;
drop table if exists tmp_vcsd_attribute;

with tmp_vcsd1 as (
  select
    ST_GeomFromGeoJSON("geometry") as geom_feature,
    row_number () over () as object_id,
    "MAPREF",
    "EDITION",
    "HG",
    "MAP",
    "MAP_TOWN",
    "SCALE",
    "TW_NAME",
    "VG"
  from map_manager.stg_vcsd
)
select
  'VCSD&&'|| object_id as feature_id,  -- Maybe generate from s_source_id when we get this
    geom_feature,
    object_id as s_source_id,
    "MAPREF" as s_name,
    "EDITION",
    "HG",
    "MAP",
    "MAP_TOWN",
    "SCALE",
    "TW_NAME",
    "VG"
into temporary tmp_vcsd
from tmp_vcsd1
;

with tmp_vcsd2 as (
  select
    feature_id || '&&EDITION' as attribute_id,
    feature_id as feature_id,
    'EDITION' as s_name,
    s_name as s_value
  from tmp_vcsd
  union
select
    feature_id || '&&HG' as attribute_id,
    feature_id as feature_id,
    'HG' as s_name,
    s_name as s_value
  from tmp_vcsd
  union
select
    feature_id || '&&MAP' as attribute_id,
    feature_id as feature_id,
    'MAP' as s_name,
    s_name as s_value
  from tmp_vcsd
  union
select
    feature_id || '&&MAP_TOWN' as attribute_id,
    feature_id as feature_id,
    'MAP_TOWN' as s_name,
    s_name as s_value
  from tmp_vcsd
  union
select
    feature_id || '&&SCALE' as attribute_id,
    feature_id as feature_id,
    'SCALE' as s_name,
    s_name as s_value
  from tmp_vcsd
  union
select
    feature_id || '&&VG' as attribute_id,
    feature_id as feature_id,
    'VG' as s_name,
    s_name as s_value
  from tmp_vcsd 
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value
into temporary tmp_vcsd_attribute
from tmp_vcsd2
;

-- mm_layer, delete previous data
delete from map_manager.mm_feature where layer_id = 'VCSD';

-- mm_layer
insert into map_manager.mm_layer
select
  'VCSD' as layer_id,
  'VCSD' as s_name,
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
  'VCSD' as layer_id,
  s_name,
  'POLYGON' as e_feature_type,
  s_source_id,  -- Use OBJECTID when we get this
  geom_feature,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start,
  MD5(coalesce(s_name, '') || coalesce(cast(s_source_id as text), '') || coalesce(st_astext(geom_feature), '')) as join_key
from tmp_vcsd
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

from tmp_vcsd_attribute
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