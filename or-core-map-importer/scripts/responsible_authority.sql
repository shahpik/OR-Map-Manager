-- Create temporary table to store transformed data
drop table if exists tmp_responsible_authority;
drop table if exists tmp_responsible_authority_attribute;

with tmp_responsible_authority1 as (
  select
    ST_GeomFromGeoJSON("geometry") as geom_feature,
    "ABB_NAME",
    "AREA",
    row_number () over () as object_id,
    "PERIMETER",
    "RMA",
    "SHAPE_AREA",
    "SHAPE_LEN",
    "SH_NAME",
    "SH_PARMS"
  from map_manager.stg_responsible_authority
)
select
  'RESPONSIBLE_AUTHORITY&&' || object_id as feature_id,
  "ABB_NAME" as s_name,
  geom_feature,
  "AREA",
  "PERIMETER",
  "RMA",
  "SHAPE_AREA",
  "SHAPE_LEN",
  "SH_NAME",
  "SH_PARMS",
  object_id as s_source_id
into temporary tmp_responsible_authority
from tmp_responsible_authority1
;

with tmp_responsible_authority2 as (
  select
    feature_id || '&&AREA' as attribute_id,
    feature_id as feature_id,
    'AREA' as s_name,
    "AREA" as s_value
  from tmp_responsible_authority
  union
  select
    feature_id || '&&PERIMETER' as attribute_id,
    feature_id as feature_id,
    'PERIMETER' as s_name,
    "PERIMETER" as s_value
  from tmp_responsible_authority
  union
  select
    feature_id || '&&RMA' as attribute_id,
    feature_id as feature_id,
    'RMA' as s_name,
    "RMA" as s_value
  from tmp_responsible_authority
  union
  select
    feature_id || '&&SHAPE_AREA' as attribute_id,
    feature_id as feature_id,
    'SHAPE_AREA' as s_name,
    "SHAPE_AREA" as s_value
  from tmp_responsible_authority
  union
  select
    feature_id || '&&SHAPE_LEN' as attribute_id,
    feature_id as feature_id,
    'SHAPE_LEN' as s_name,
    "SHAPE_LEN" as s_value
  from tmp_responsible_authority
  union
  select
    feature_id || '&&SH_NAME' as attribute_id,
    feature_id as feature_id,
    'SH_NAME' as s_name,
    "SH_NAME" as s_value
  from tmp_responsible_authority
  union
  select
    feature_id || '&&SH_PARMS' as attribute_id,
    feature_id as feature_id,
    'SH_PARMS' as s_name,
    "SH_PARMS" as s_value
  from tmp_responsible_authority
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value
into temporary tmp_responsible_authority_attribute
from tmp_responsible_authority2
;

-- mm_layer, delete previous data
delete from map_manager.mm_feature where layer_id = 'RESPONSIBLE_AUTHORITY';

-- mm_layer
insert into map_manager.mm_layer
select
  'RESPONSIBLE_AUTHORITY' as layer_id,
  'Responsible Authority' as s_name,
  'MULTIPOLYGON' as e_layer_type
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
  'RESPONSIBLE_AUTHORITY' as layer_id,
  s_name,
  'MULTIPOLYGON' as e_feature_type,
  s_source_id,
  geom_feature,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start,
  MD5(coalesce(s_name, '') || coalesce(cast(s_source_id as text), '') || coalesce(st_astext(geom_feature), '')) as join_key
from tmp_responsible_authority
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

from tmp_responsible_authority_attribute
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