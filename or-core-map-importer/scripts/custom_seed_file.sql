--SQL for ingesting Custom Seed File
drop table if exists tmp_seed_file;
drop table if exists tmp_seed_file_attribute;
drop table if exists custom_seed_file_duplicates_removed; 

--This first section of SQL will be used for cleaning the file & removing duplicates
--Duplicates are handled by preferentially selecting those with a Declared Name provided
--We also order by CLASSN to preferentially choose LO (local roads) over BP (bikepaths)

CREATE TEMPORARY TABLE IF NOT EXISTS custom_seed_file_duplicates_removed AS (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY geometry ORDER BY "DEC_NAME" DESC, "CLASSN" DESC) AS row_num
  FROM map_manager.stg_custom_seed_file
);
DELETE FROM custom_seed_file_duplicates_removed
WHERE row_num > 1;


--This second section of SQL handles ingesting the data into mm_feature and mm_attribute
with tmp_seedfile1 as (
  select
    ST_GeomFromGeoJSON("geometry") as geom_feature,
    "DEC_NAME",
    "DEC_TYPE",
    "RD_NUM", 
    "RD_SECTION",
    "CLASSN",
    "ARTERIAL",
    "PROFILE",
    "COMPLEX", 
    "RTE_NO",
    "CWAY", 
    "SERVICE_RD",
    "RAMP", 
    "CBR", 
    "R_RTE_NO", 
    "R_CWAY", 
    "R_RAMP", 
    "RNDB_EDIT", 
    "SRNS1", 
    "SRNS2", 
    "SRNS3", 
    "MEL30_ART", 
    "RMANUM", 
    "RMACLASS", 
    "RAMP_NUM", 
    "RAMP_NAME", 
    "DEC_STATUS", 
    "PREV_RMA", 
    "AUSLINK", 
    "RMC", 
    "MAINT_ORG", 
    "LGA_NAME", 
    "LGA_ABB_NAME", 
    "DTP_REG_NAME" as region_name, 
    "DTP_ABB_NAME" as responsible_region_name,
    CASE
    	WHEN "DEC_NAME" IS NULL AND "DEC_TYPE" IS NULL THEN NULL
    	ELSE COALESCE("DEC_NAME", '') || ' ' || COALESCE("DEC_TYPE", '')
	  END AS declared_road
  from custom_seed_file_duplicates_removed
)
select
  'CUSTOM_SEED_FILE&&'|| '_' || MD5(geom_feature::text) as feature_id,  -- Maybe generate from s_source_id when we get this
  "DEC_NAME" || ' ' || "DEC_TYPE" as s_name,
  geom_feature,
  "DEC_NAME",
  "DEC_TYPE",
  "RD_NUM", 
  "RD_SECTION",
  "CLASSN",
  "ARTERIAL",
  "PROFILE",
  "COMPLEX", 
  "RTE_NO",
  "CWAY", 
  "SERVICE_RD",
  "RAMP", 
  "CBR", 
  "R_RTE_NO", 
  "R_CWAY", 
  "R_RAMP", 
  "RNDB_EDIT", 
  "SRNS1", 
  "SRNS2", 
  "SRNS3", 
  "MEL30_ART", 
  "RMANUM", 
  "RMACLASS", 
  "RAMP_NUM", 
  "RAMP_NAME", 
  "DEC_STATUS", 
  "PREV_RMA", 
  "AUSLINK", 
  "RMC", 
  "MAINT_ORG", 
  "LGA_NAME", 
  "LGA_ABB_NAME", 
  region_name, 
  responsible_region_name,
  declared_road
into temporary tmp_seed_file
from tmp_seedfile1
;

with tmp_attribute_fields as (
  select
    array[
      'DEC_NAME',
      'DEC_TYPE',
      'RD_NUM', 
      'RD_SECTION',
      'CLASSN',
      'ARTERIAL',
      'PROFILE',
      'COMPLEX', 
      'RTE_NO',
      'CWAY', 
      'SERVICE_RD',
      'RAMP', 
      'CBR', 
      'R_RTE_NO', 
      'R_CWAY', 
      'R_RAMP', 
      'RNDB_EDIT', 
      'SRNS1', 
      'SRNS2', 
      'SRNS3', 
      'MEL30_ART', 
      'RMANUM', 
      'RMACLASS', 
      'RAMP_NUM', 
      'RAMP_NAME', 
      'DEC_STATUS', 
      'PREV_RMA', 
      'AUSLINK', 
      'RMC', 
      'MAINT_ORG', 
      'LGA_NAME', 
      'LGA_ABB_NAME', 
      'REGION_NAME', 
      'RESPONSIBLE_REGION_NAME',
      'declared_road'
    ] as attribute_fields
), tmp_seedfile2 as (
  select
    unnest(array(select feature_id || '&&' || (unnest(attribute_fields)))) as attribute_id,
    feature_id,
    unnest(attribute_fields) as s_name,
    unnest(array["DEC_NAME", "DEC_TYPE","RD_NUM", "RD_SECTION", "CLASSN", "ARTERIAL", "PROFILE", "COMPLEX", "RTE_NO", "CWAY", "SERVICE_RD", "RAMP", "CBR", "R_RTE_NO", "R_CWAY", "R_RAMP", "RNDB_EDIT", "SRNS1", "SRNS2", "SRNS3", "MEL30_ART", 
    "RMANUM", "RMACLASS", "RAMP_NUM", "RAMP_NAME", "DEC_STATUS", "PREV_RMA", "AUSLINK", "RMC", "MAINT_ORG", "LGA_NAME", "LGA_ABB_NAME", "region_name", "responsible_region_name", "declared_road"]) as s_value
   from tmp_seed_file, tmp_attribute_fields
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value
into temporary tmp_seed_file_attribute
from tmp_seedfile2
;

-- mm_layer
insert into map_manager.mm_layer
select
  'CUSTOM_SEED_FILE' as layer_id,
  'Custom Seed File' as s_name,
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
  geom_feature,
  changeset_id,
  global_version_id_start
)
select
  feature_id,
  'CUSTOM_SEED_FILE' as layer_id,
  s_name,
  'LINE' as e_feature_type,
  geom_feature,
  'INITIAL_CHANGESET' as changeset_id, 
  0 as global_version_id_start
from tmp_seed_file
on conflict (feature_id, changeset_id) do nothing;

-- mm_attribute
insert into map_manager.mm_attribute (
  attribute_id,
  feature_id,
  s_name,
  s_value,
  changeset_id,
  global_version_id_start
)
select
  attribute_id,
  feature_id,
  s_name,
  s_value,
  'INITIAL_CHANGESET' as changeset_id,
  0 as global_version_id_start
from tmp_seed_file_attribute where s_value is not null
on conflict (attribute_id, changeset_id) do nothing;