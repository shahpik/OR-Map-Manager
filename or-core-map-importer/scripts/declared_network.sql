drop table if exists tmp_declared_network;
drop table if exists tmp_declared_network_attribute;

with tmp_dec_net1 as (
  select
    ST_GeomFromGeoJSON("geometry") as geom_feature,
    "ROADNAME",
    "FK_ROUTE",
    "FROMMEASUR",
    "ID_EVROADN",
    "NAMETYPE",
    "OBJECTID",
    "ROADSUFFIX",
    "ROADTYPE",
    "TOMEASURE"
  from map_manager.stg_declared_network
)
select
  'DECLARED_NETWORK&&' || "OBJECTID" || '_' || MD5(geom_feature::text) as feature_id,  -- Maybe generate from s_source_id when we get this
  "ROADNAME" as s_name,
  geom_feature,
  "FK_ROUTE",
  "FROMMEASUR",
  "ID_EVROADN",
  "NAMETYPE",
  "ROADSUFFIX",
  "ROADTYPE",
  "TOMEASURE",
  "OBJECTID" as s_source_id
into temporary tmp_declared_network
from tmp_dec_net1
;

with tmp_dec_net2 as (
  select
    feature_id || '&&FK_ROUTE' as attribute_id,
    feature_id as feature_id,
    'FK_ROUTE' as s_name,
    "FK_ROUTE" as s_value
  from tmp_declared_network
  union
  select -- just an example, replace later with a different field
    feature_id || '&&FROMMEASUR' as attribute_id,
    feature_id as feature_id,
    'FROMMEASUR' as s_name,
    "FROMMEASUR" as s_value
  from tmp_declared_network
  union
  select -- just an example, replace later with a different field
    feature_id || '&&ID_EVROADN' as attribute_id,
    feature_id as feature_id,
    'ID_EVROADN' as s_name,
    "ID_EVROADN" as s_value
  from tmp_declared_network
  union
  select -- just an example, replace later with a different field
    feature_id || '&&NAMETYPE' as attribute_id,
    feature_id as feature_id,
    'NAMETYPE' as s_name,
    "NAMETYPE" as s_value
  from tmp_declared_network
  union
  select -- just an example, replace later with a different field
    feature_id || '&&ROADSUFFIX' as attribute_id,
    feature_id as feature_id,
    'ROADSUFFIX' as s_name,
    "ROADSUFFIX" as s_value
  from tmp_declared_network
  union
  select -- just an example, replace later with a different field
    feature_id || '&&ROADTYPE' as attribute_id,
    feature_id as feature_id,
    'ROADTYPE' as s_name,
    "ROADTYPE" as s_value
  from tmp_declared_network
  union
  select -- just an example, replace later with a different field
    feature_id || '&&TOMEASURE' as attribute_id,
    feature_id as feature_id,
    'TOMEASURE' as s_name,
    "TOMEASURE" as s_value
  from tmp_declared_network
  union
  select
    feature_id || '&&ROADNAME' as attribute_id,
    feature_id as feature_id,
    'ROADNAME' as s_name,
    s_name as s_value
  from tmp_declared_network
  union
  select
    feature_id || '&&OBJECTID' as attribute_id,
    feature_id as feature_id,
    'ROADNUMBER' as s_name,
    s_source_id as s_value
  from tmp_declared_network
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value
into temporary tmp_declared_network_attribute
from tmp_dec_net2
;

-- mm_layer
insert into map_manager.mm_layer
select
  'DECLARED_NETWORK' as layer_id,
  'Declared Network' as s_name,
  'LINE' as e_layer_type
on conflict (layer_id) do update
set
  layer_id = excluded.layer_id,
  s_name = excluded.s_name,
  e_layer_type = excluded.e_layer_type
;

-- mm_feature
insert into map_manager.mm_feature (
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
  'DECLARED_NETWORK' as layer_id,
  s_name,
  'LINE' as e_feature_type,
  s_source_id,  -- Use OBJECTID when we get this
  geom_feature,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start,
  MD5(coalesce(s_name, '') || coalesce(s_source_id, '') || coalesce(st_astext(geom_feature), '')) as join_key
from tmp_declared_network
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
from tmp_declared_network_attribute
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