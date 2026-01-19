-- Create temporary table to store transformed data
drop table if exists tmp_lga_contact;
drop table if exists tmp_lga_contact_attribute;

with tmp_lga_contact1 as (
  select
    ST_GeomFromGeoJSON("geometry") as geom_feature,
    "ADDRESS",
    "CODE",
    "EMAIL",
    "FAX",
    "LGANAME",
    "LGASHORTNA",
    "MELWAYS_OR",
    "MUNICIPALI",
    row_number () over () as object_id,
    "PCODE",
    "PHONE",
    "POSTAL",
    "POSTAL_SUB",
    "SHAPE_AREA",
    "SHAPE_LEN",
    "SUBURB__TO",
    "WWW_SITE"
  from map_manager.stg_lga_contact
)
select
  'LGA_CONTACT&&' || object_id as feature_id,
  "LGANAME" as s_name,
  geom_feature,
  "ADDRESS",
  "CODE",
  "EMAIL",
  "FAX",
  "LGASHORTNA",
  "MELWAYS_OR",
  "MUNICIPALI",
  "PCODE",
  "PHONE",
  "POSTAL",
  "POSTAL_SUB",
  "SHAPE_AREA",
  "SHAPE_LEN",
  "SUBURB__TO",
  "WWW_SITE",
  object_id as s_source_id
into temporary tmp_lga_contact
from tmp_lga_contact1
;

with tmp_lga_contact2 as (
  select
    feature_id || '&&ADDRESS' as attribute_id,
    feature_id as feature_id,
    'ADDRESS' as s_name,
    "ADDRESS" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&CODE' as attribute_id,
    feature_id as feature_id,
    'CODE' as s_name,
    "CODE" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&EMAIL' as attribute_id,
    feature_id as feature_id,
    'EMAIL' as s_name,
    "EMAIL" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&FAX' as attribute_id,
    feature_id as feature_id,
    'FAX' as s_name,
    "FAX" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&LGASHORTNA' as attribute_id,
    feature_id as feature_id,
    'LGASHORTNA' as s_name,
    "LGASHORTNA" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&MELWAYS_OR' as attribute_id,
    feature_id as feature_id,
    'MELWAYS_OR' as s_name,
    "MELWAYS_OR" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&MUNICIPALI' as attribute_id,
    feature_id as feature_id,
    'MUNICIPALI' as s_name,
    "MUNICIPALI" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&PCODE' as attribute_id,
    feature_id as feature_id,
    'PCODE' as s_name,
    "PCODE" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&PHONE' as attribute_id,
    feature_id as feature_id,
    'PHONE' as s_name,
    "PHONE" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&POSTAL' as attribute_id,
    feature_id as feature_id,
    'POSTAL' as s_name,
    "POSTAL" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&POSTAL_SUB' as attribute_id,
    feature_id as feature_id,
    'POSTAL_SUB' as s_name,
    "POSTAL_SUB" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&SHAPE_AREA' as attribute_id,
    feature_id as feature_id,
    'SHAPE_AREA' as s_name,
    "SHAPE_AREA" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&SHAPE_LEN' as attribute_id,
    feature_id as feature_id,
    'SHAPE_LEN' as s_name,
    "SHAPE_LEN" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&SUBURB__TO' as attribute_id,
    feature_id as feature_id,
    'SUBURB__TO' as s_name,
    "SUBURB__TO" as s_value
  from tmp_lga_contact
  union
  select
    feature_id || '&&WWW_SITE' as attribute_id,
    feature_id as feature_id,
    'WWW_SITE' as s_name,
    "WWW_SITE" as s_value
  from tmp_lga_contact
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value
into temporary tmp_lga_contact_attribute
from tmp_lga_contact2
;

-- mm_layer, delete previous data
delete from map_manager.mm_feature where layer_id = 'LGA_CONTACT';

-- mm_layer
insert into map_manager.mm_layer
select
  'LGA_CONTACT' as layer_id,
  'LGA Contact' as s_name,
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
  'LGA_CONTACT' as layer_id,
  s_name,
  'POLYGON' as e_feature_type,
  s_source_id,
  geom_feature,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start,
  MD5(coalesce(s_name, '') || coalesce(cast(s_source_id as text), '') || coalesce(st_astext(geom_feature), '')) as join_key

from tmp_lga_contact
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

from tmp_lga_contact_attribute
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