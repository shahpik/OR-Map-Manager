-- Create temporary table to store transformed data
drop table if exists tmp_ttmc;
drop table if exists tmp_ttmc_attribute;

with tmp_ttmc1 as (
  select
    ST_GeomFromGeoJSON("geometry") as geom_feature,
    row_number () over () as object_id,
    "SHAPE_AREA",
    "SHAPE_LEN",
    "TTMC"
  from map_manager.stg_ttmc
)
select
  'TTMC&&' || object_id as feature_id,
  "TTMC" as s_name,
  geom_feature,
  "SHAPE_AREA",
  "SHAPE_LEN",
  object_id as s_source_id
into temporary tmp_ttmc
from tmp_ttmc1
;

with tmp_ttmc2 as (
  select
    feature_id || '&&SHAPE_AREA' as attribute_id,
    feature_id as feature_id,
    'SHAPE_AREA' as s_name,
    "SHAPE_AREA" as s_value
  from tmp_ttmc
  union
  select
    feature_id || '&&SHAPE_LEN' as attribute_id,
    feature_id as feature_id,
    'SHAPE_LEN' as s_name,
    "SHAPE_LEN" as s_value
  from tmp_ttmc
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value
into temporary tmp_ttmc_attribute
from tmp_ttmc2
;

-- mm_layer, delete previous data
delete from map_manager.mm_feature where layer_id = 'TTMC';

-- mm_layer
insert into map_manager.mm_layer
select
  'TTMC' as layer_id,
  'TTMC' as s_name,
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
  'TTMC' as layer_id,
  s_name,
  'POLYGON' as e_feature_type,
  s_source_id,
  geom_feature,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start,
  MD5(coalesce(s_name, '') || coalesce(cast(s_source_id as text), '') || coalesce(st_astext(geom_feature), '')) as join_key
from tmp_ttmc
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
from tmp_ttmc_attribute
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