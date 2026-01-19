-- Create temporary table to store transformed data
drop table if exists tmp_federal_electorate;
drop table if exists tmp_federal_electorate_attribute;

with tmp_federal_electorate1 as (
  select
    ST_GeomFromGeoJSON("geometry") as geom_feature,
    "FEDERALCOD",
    "FEDERALELE",
    "ID_FEDERAL",
    "MEMBERNAME",
    "MEMBERPART",
    "MEMBERPORT",
    row_number () over () as object_id,
    "OFFICEADDR",
    "SHAPE_AREA",
    "SHAPE_LEN"
  from map_manager.stg_federal_electorate
)
select
  'FEDERAL_ELECTORATE&&' || object_id as feature_id,
  "FEDERALCOD" as s_name,
  geom_feature,
  "FEDERALELE",
  "ID_FEDERAL",
  "MEMBERNAME",
  "MEMBERPART",
  "MEMBERPORT",
  "OFFICEADDR",
  "SHAPE_AREA",
  "SHAPE_LEN",
  object_id as s_source_id
into temporary tmp_federal_electorate
from tmp_federal_electorate1
;

with tmp_federal_electorate2 as (
  select
    feature_id || '&&FEDERALELE' as attribute_id,
    feature_id as feature_id,
    'FEDERALELE' as s_name,
    "FEDERALELE" as s_value
  from tmp_federal_electorate
  union
  select
    feature_id || '&&ID_FEDERAL' as attribute_id,
    feature_id as feature_id,
    'ID_FEDERAL' as s_name,
    "ID_FEDERAL" as s_value
  from tmp_federal_electorate
  union
  select
    feature_id || '&&MEMBERNAME' as attribute_id,
    feature_id as feature_id,
    'MEMBERNAME' as s_name,
    "MEMBERNAME" as s_value
  from tmp_federal_electorate
  union
  select
    feature_id || '&&MEMBERPART' as attribute_id,
    feature_id as feature_id,
    'MEMBERPART' as s_name,
    "MEMBERPART" as s_value
  from tmp_federal_electorate
  union
  select
    feature_id || '&&MEMBERPORT' as attribute_id,
    feature_id as feature_id,
    'MEMBERPORT' as s_name,
    "MEMBERPORT" as s_value
  from tmp_federal_electorate
  union
  select
    feature_id || '&&OFFICEADDR' as attribute_id,
    feature_id as feature_id,
    'OFFICEADDR' as s_name,
    "OFFICEADDR" as s_value
  from tmp_federal_electorate
  union
  select
    feature_id || '&&SHAPE_AREA' as attribute_id,
    feature_id as feature_id,
    'SHAPE_AREA' as s_name,
    "SHAPE_AREA" as s_value
  from tmp_federal_electorate
  union
  select
    feature_id || '&&SHAPE_LEN' as attribute_id,
    feature_id as feature_id,
    'SHAPE_LEN' as s_name,
    "SHAPE_LEN" as s_value
  from tmp_federal_electorate
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value
into temporary tmp_federal_electorate_attribute
from tmp_federal_electorate2
;

-- mm_layer, delete previous data
delete from map_manager.mm_feature where layer_id = 'FEDERAL_ELECTORATE';

-- mm_layer
insert into map_manager.mm_layer
select
  'FEDERAL_ELECTORATE' as layer_id,
  'Federal Electorate' as s_name,
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
  'FEDERAL_ELECTORATE' as layer_id,
  s_name,
  'POLYGON' as e_feature_type,
  s_source_id,
  geom_feature,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start,
  MD5(coalesce(s_name, '') || coalesce(cast(s_source_id as text), '') || coalesce(st_astext(geom_feature), '')) as join_key
from tmp_federal_electorate
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
from tmp_federal_electorate_attribute
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