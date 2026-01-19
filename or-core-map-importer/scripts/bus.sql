-- Create temporary table to store transformed data
drop table if exists tmp_bus;
drop table if exists tmp_bus_attribute;

with tmp_bus1 as (
  select
    ST_GeomFromGeoJSON("geometry") as geom_feature,
    "BUSROUTEID",
    "FK_ROUTE",
    "ID_BUSROUT",
    row_number () over () as object_id,
    "SHAPE_LEN",
    "VICROADSBU"
  from map_manager.stg_bus
)
select
  'BUS&&' || object_id as feature_id,
  "BUSROUTEID" as s_name,
  geom_feature,
  "FK_ROUTE",
  "ID_BUSROUT",
  "SHAPE_LEN",
  "VICROADSBU",
  object_id as s_source_id
into temporary tmp_bus
from tmp_bus1
;

with tmp_bus2 as (
  select
    feature_id || '&&BUSROUTEID' as attribute_id,
    feature_id as feature_id,
    s_name,
    s_name as s_value
  from tmp_bus
  union
  select
    feature_id || '&&ID_BUSROUT' as attribute_id,
    feature_id as feature_id,
    'ID_BUSROUT' as s_name,
    "ID_BUSROUT" as s_value
  from tmp_bus
  union
  select
    feature_id || '&&SHAPE_LEN' as attribute_id,
    feature_id as feature_id,
    'SHAPE_LEN' as s_name,
    "SHAPE_LEN" as s_value
  from tmp_bus
  union
  select
    feature_id || '&&VICROADSBU' as attribute_id,
    feature_id as feature_id,
    'VICROADSBU' as s_name,
    "VICROADSBU" as s_value
  from tmp_bus
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value
into temporary tmp_bus_attribute
from tmp_bus2
;

-- mm_layer, delete previous data
delete from map_manager.mm_feature where layer_id = 'BUS';

-- mm_layer
insert into map_manager.mm_layer
select
  'BUS' as layer_id,
  'Bus' as s_name,
  'MULTILINE' as e_layer_type
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
  'BUS' as layer_id,
  s_name,
  'MULTILINE' as e_feature_type,
  s_source_id,  -- Use OBJECTID when we get this
  geom_feature,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start,
  MD5(coalesce(s_name, '') || coalesce(cast(s_source_id as text), '') || coalesce(st_astext(geom_feature), '')) as join_key
from tmp_bus
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

from tmp_bus_attribute
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