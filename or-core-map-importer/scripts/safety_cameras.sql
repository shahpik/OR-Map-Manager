-- Create temporary table to store transformed data
drop table if exists tmp_safety_cameras;
drop table if exists tmp_safety_cameras_attribute;

with tmp_cameras1 as (
  select
    ST_GeomFromGeoJSON("geometry") as geom_feature,
    "AT_INTERSE",
    "BUFF_DIST",
    "CAMERA_LOC",
    "LATITUDE",
    "LONGITUDE",
    "MAP_REF",
    row_number () over () as object_id,
    "SHAPE_AREA",
    "SHAPE_LEN",
    "SITE",
    "SUBURB",
    "S_POS_X",
    "S_POS_Y"
  from map_manager.stg_safety_cameras
)
select
  'SAFETY_CAMERAS&&' || object_id as feature_id,
  "CAMERA_LOC" as s_name,
  geom_feature,
  "AT_INTERSE",
  "BUFF_DIST",
  "LATITUDE",
  "LONGITUDE",
  "MAP_REF",
  "SHAPE_AREA",
  "SHAPE_LEN",
  "SITE",
  "SUBURB",
  "S_POS_X",
  "S_POS_Y",
  object_id as s_source_id
into temporary tmp_safety_cameras
from tmp_cameras1
;

with tmp_cameras2 as (
  select
    feature_id || '&&AT_INTERSE' as attribute_id,
    feature_id as feature_id,
    'AT_INTERSE' as s_name,
    "AT_INTERSE" as s_value
  from tmp_safety_cameras
  union
  select
    feature_id || '&&BUFF_DIST' as attribute_id,
    feature_id as feature_id,
    'BUFF_DIST' as s_name,
    "BUFF_DIST" as s_value
  from tmp_safety_cameras
  union
  select
    feature_id || '&&LATITUDE' as attribute_id,
    feature_id as feature_id,
    'LATITUDE' as s_name,
    "LATITUDE" as s_value
  from tmp_safety_cameras
  union
  select
    feature_id || '&&LONGITUDE' as attribute_id,
    feature_id as feature_id,
    'LONGITUDE' as s_name,
    "LONGITUDE" as s_value
  from tmp_safety_cameras
  union
  select
    feature_id || '&&MAP_REF' as attribute_id,
    feature_id as feature_id,
    'MAP_REF' as s_name,
    "MAP_REF" as s_value
  from tmp_safety_cameras
  union
  select
    feature_id || '&&SHAPE_AREA' as attribute_id,
    feature_id as feature_id,
    'SHAPE_AREA' as s_name,
    "SHAPE_AREA" as s_value
  from tmp_safety_cameras
  union
  select
    feature_id || '&&SHAPE_LEN' as attribute_id,
    feature_id as feature_id,
    'SHAPE_LEN' as s_name,
    "SHAPE_LEN" as s_value
  from tmp_safety_cameras
  union
  select
    feature_id || '&&SITE' as attribute_id,
    feature_id as feature_id,
    'SITE' as s_name,
    "SITE" as s_value
  from tmp_safety_cameras
  union
  select
    feature_id || '&&SUBURB' as attribute_id,
    feature_id as feature_id,
    'SUBURB' as s_name,
    "SUBURB" as s_value
  from tmp_safety_cameras
  union
  select
    feature_id || '&&S_POS_X' as attribute_id,
    feature_id as feature_id,
    'S_POS_X' as s_name,
    "S_POS_X" as s_value
  from tmp_safety_cameras
  union
  select
    feature_id || '&&S_POS_Y' as attribute_id,
    feature_id as feature_id,
    'S_POS_Y' as s_name,
    "S_POS_Y" as s_value
  from tmp_safety_cameras
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value
into temporary tmp_safety_cameras_attribute
from tmp_cameras2
;

-- mm_layer, delete previous data
delete from map_manager.mm_feature where layer_id = 'SAFETY_CAMERAS';

-- mm_layer
insert into map_manager.mm_layer
select
  'SAFETY_CAMERAS' as layer_id,
  'Safety Cameras' as s_name,
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
  'SAFETY_CAMERAS' as layer_id,
  s_name,
  'POLYGON' as e_feature_type,
  s_source_id,
  geom_feature,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start,
  MD5(coalesce(s_name, '') || coalesce(cast(s_source_id as text), '') || coalesce(st_astext(geom_feature), '')) as join_key
from tmp_safety_cameras
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
from tmp_safety_cameras_attribute
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
