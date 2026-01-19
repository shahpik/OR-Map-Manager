drop table if exists tmp_state_upper_house;
drop table if exists tmp_state_upper_house_attribute;

with tmp_state_upper_house1 as (
  select
    ST_GeomFromGeoJSON("geometry") as geom_feature,
    row_number () over () as object_id,
    "Shape__Area",
    "Shape__Length",
    "region",
    "region_code",
    "region_label",
    "ufi",
    "ufi_created"
  from map_manager.stg_state_upper_house
)
select
  'STATE_UPPER_HOUSE&&' || object_id as feature_id,  -- Maybe generate from s_source_id when we get this
    geom_feature,
    "region" as s_name,
    object_id as s_source_id,
    "Shape__Area",
    "Shape__Length",
    "region",
    "region_code",
    "region_label",
    "ufi",
    "ufi_created"
into temporary tmp_state_upper_house
from tmp_state_upper_house1
;

with tmp_state_upper_house2 as (
  select
    feature_id || '&&Shape__Area' as attribute_id,
    feature_id as feature_id,
    'Shape__Area' as s_name,
    s_name as s_value
  from tmp_state_upper_house
  union
select
    feature_id || '&&Shape__Length' as attribute_id,
    feature_id as feature_id,
    'Shape__Length' as s_name,
    s_name as s_value
    from tmp_state_upper_house
    union
select
    feature_id || '&&region' as attribute_id,
    feature_id as feature_id,
    'region' as s_name,
    s_name as s_value
    from tmp_state_upper_house
    union
select
    feature_id || '&&region_code' as attribute_id,
    feature_id as feature_id,
    'region_code' as s_name,
    s_name as s_value
    from tmp_state_upper_house
    union
select
    feature_id || '&&region_label' as attribute_id,
    feature_id as feature_id,
    'region_label' as s_name,
    s_name as s_value
    from tmp_state_upper_house
    union
select
    feature_id || '&&ufi' as attribute_id,
    feature_id as feature_id,
    'ufi' as s_name,
    s_name as s_value
  from tmp_state_upper_house
  union
select
    feature_id || '&&ufi_created' as attribute_id,
    feature_id as feature_id,
    'ufi_created' as s_name,
    s_name as s_value
    from tmp_state_upper_house        
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value
into temporary tmp_state_upper_house_attribute
from tmp_state_upper_house2
;

-- mm_layer, delete previous data
delete from map_manager.mm_feature where layer_id = 'STATE_UPPER_HOUSE';

-- mm_layer
insert into map_manager.mm_layer
select
  'STATE_UPPER_HOUSE' as layer_id,
  'STATE_UPPER_HOUSE' as s_name,
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
  'STATE_UPPER_HOUSE' as layer_id,
  s_name,
  'POLYGON' as e_feature_type,
  s_source_id,  -- Use OBJECTID when we get this
  geom_feature,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start,
  MD5(coalesce(s_name, '') || coalesce(cast(s_source_id as text), '') || coalesce(st_astext(geom_feature), '')) as join_key
from tmp_state_upper_house
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

from tmp_state_upper_house_attribute
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