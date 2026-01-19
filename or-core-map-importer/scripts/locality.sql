drop table if exists tmp_locality;
drop table if exists tmp_locality_attribute;

with tmp_locality1 as (
  select
    ST_GeomFromGeoJSON("geometry") as geom_feature,
    "Shape__Area",
    "Shape__Length",
    "gazetted_locality_name",
    row_number () over () as object_id,
    "locality_name",
    "pfi",
    "pfi_created",
    "task_id",
    "ufi",
    "ufi_created",
    "ufi_old",
    "vicnames_id"
  from map_manager.stg_locality
)
select
  'LOCALITY&&'|| object_id as feature_id,  -- Maybe generate from s_source_id when we get this
  "locality_name" as s_name,
  geom_feature,
  object_id as s_source_id,
  "Shape__Area",
  "Shape__Length",
  "gazetted_locality_name",
  "pfi",
  "pfi_created",
  "task_id",
  "ufi",
  "ufi_created",
  "ufi_old",
  "vicnames_id"
into temporary tmp_locality
from tmp_locality1
;

with tmp_attribute_fields as (
  select
    array[
      'Shape__Area',
      'Shape__Length',
      'gazetted_locality_name',
      'pfi',
      'pfi_created',
      'task_id',
      'ufi',
      'ufi_created',
      'ufi_old',
      'vicnames_id'
    ] as attribute_fields
), tmp_locality2 as (
  select
    unnest(array(select feature_id || '&&' || (unnest(attribute_fields)))) as attribute_id,
    feature_id,
    unnest(attribute_fields) as s_name,
    unnest(array["Shape__Area","Shape__Length","gazetted_locality_name","pfi","pfi_created","task_id","ufi","ufi_created","ufi_old","vicnames_id"]) as s_value
  from tmp_locality, tmp_attribute_fields
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value
into temporary tmp_locality_attribute
from tmp_locality2
;

-- mm_layer, delete previous data
delete from map_manager.mm_feature where layer_id = 'LOCALITY';

-- mm_layer 
insert into map_manager.mm_layer
select
  'LOCALITY' as layer_id,
  'locality' as s_name,
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
  'LOCALITY' as layer_id,
  s_name,
  'POLYGON' as e_feature_type,
  s_source_id,  -- Use OBJECTID when we get this
  geom_feature,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start,
  MD5(coalesce(s_name, '') || coalesce(cast(s_source_id as text), '') || coalesce(st_astext(geom_feature), '')) as join_key
from tmp_locality
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

from tmp_locality_attribute
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