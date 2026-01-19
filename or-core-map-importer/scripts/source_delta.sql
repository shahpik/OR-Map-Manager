drop table if exists source_modified_features;
drop table if exists source_added_features;
drop table if exists source_deleted_features;
drop table if exists source_modified_attributes;
drop table if exists source_added_attributes;
drop table if exists source_deleted_attributes;

-- get modified features
with latest_features as (
    select feature_id, join_key 
    from map_manager.mm_feature
    where mm_feature.b_is_latest = true    
)
select 
    mm_temp_feature.feature_id as temp_feature_id,
    mm_temp_feature.layer_id as temp_layer_id,
    mm_temp_feature.s_name as temp_s_name,
    mm_temp_feature.e_feature_type as temp_e_feature_type,
    mm_temp_feature.s_source_id as temp_s_source_id,
    mm_temp_feature.geom_feature as temp_geom_feature,
    mm_temp_feature.join_key as temp_join_key
into temporary source_modified_features
from latest_features 
right join map_manager.mm_temp_feature
on latest_features.feature_id = mm_temp_feature.feature_id
where latest_features.join_key != mm_temp_feature.join_key;

-- get added features
with latest_features as (
    select feature_id, join_key 
    from map_manager.mm_feature
    where mm_feature.b_is_latest = true    
)
select 
    mm_temp_feature.feature_id as temp_feature_id,
    mm_temp_feature.layer_id as temp_layer_id,
    mm_temp_feature.s_name as temp_s_name,
    mm_temp_feature.e_feature_type as temp_e_feature_type,
    mm_temp_feature.s_source_id as temp_s_source_id,
    mm_temp_feature.geom_feature as temp_geom_feature,
    mm_temp_feature.join_key as temp_join_key
into temporary source_added_features
from latest_features
right join map_manager.mm_temp_feature
on latest_features.feature_id = mm_temp_feature.feature_id
where latest_features.join_key is null;

-- get deleted features
with feature_layer_id as (
    select cast(layer_id as VARCHAR(255)) as feature_layer_id from map_manager.mm_temp_feature limit 1
),
latest_features as (
    select 
    feature_id,
    layer_id,
    s_name,
    e_feature_type,
    s_source_id,
    geom_feature,
    join_key
    from map_manager.mm_feature
    where mm_feature.b_is_latest = true    
)
select
    latest_features.feature_id as latest_feature_id,
    latest_features.layer_id as latest_layer_id,
    latest_features.s_name as latest_s_name,
    latest_features.e_feature_type as latest_e_feature_type,
    latest_features.s_source_id as latest_source_id,
    latest_features.geom_feature as latest_geom_feature,
    latest_features.join_key as latest_join_key
into temporary source_deleted_features
from feature_layer_id, latest_features
left join map_manager.mm_temp_feature on 
latest_features.feature_id = mm_temp_feature.feature_id
where latest_features.join_key is not null and mm_temp_feature.join_key is null and latest_features.feature_id like feature_layer_id || '%';

-- get modified attributes
with latest_attributes as (
    select attribute_id, join_key
    from map_manager.mm_attribute
    where mm_attribute.b_is_latest = true and 
    mm_attribute.b_user_edit is null
)
select 
    mm_temp_attribute.attribute_id as temp_attribute_id,
    mm_temp_attribute.feature_id as temp_feature_id,
    mm_temp_attribute.s_name as temp_s_name,
    mm_temp_attribute.s_value as temp_s_value,
    mm_temp_attribute.join_key as temp_join_key
into temporary source_modified_attributes
from latest_attributes
right join map_manager.mm_temp_attribute
on latest_attributes.attribute_id = mm_temp_attribute.attribute_id
where latest_attributes.join_key != mm_temp_attribute.join_key;

-- get added attributes
with latest_attributes as (
    select attribute_id, join_key
    from map_manager.mm_attribute
    where mm_attribute.b_is_latest = true and 
    mm_attribute.b_user_edit is null
)
select 
    mm_temp_attribute.attribute_id as temp_attribute_id,
    mm_temp_attribute.feature_id as temp_feature_id,
    mm_temp_attribute.s_name as temp_s_name,
    mm_temp_attribute.s_value as temp_s_value,
    mm_temp_attribute.join_key as temp_join_key
into temporary source_added_attributes
from latest_attributes
right join map_manager.mm_temp_attribute
on latest_attributes.attribute_id = mm_temp_attribute.attribute_id
where latest_attributes.join_key is null;

-- get deleted attributes
with layer_id as (
    select cast(layer_id as VARCHAR(255)) from map_manager.mm_temp_feature limit 1
),
latest_attributes as (
    select 
    attribute_id,
    feature_id,
    s_name,
    s_value,
    join_key
    from map_manager.mm_attribute
    where mm_attribute.b_is_latest = true and
    mm_attribute.b_user_edit is null
    and mm_attribute.s_name not in (
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
      'declared_road')
)
select 
    latest_attributes.attribute_id as latest_attribute_id,
    latest_attributes.feature_id as latest_feature_id,
    latest_attributes.s_name as latest_s_name,
    latest_attributes.s_value as latest_s_value,
    latest_attributes.join_key as latest_join_key
into temporary source_deleted_attributes
from layer_id, latest_attributes
left join map_manager.mm_temp_attribute
on latest_attributes.attribute_id = mm_temp_attribute.attribute_id
where latest_attributes.join_key is not null and mm_temp_attribute.join_key is null and latest_attributes.attribute_id like layer_id || '%';

-- insert modified features
insert into map_manager.mm_feature (
    feature_id,
    layer_id, 
    s_name,
    e_feature_type,
    s_source_id,
    geom_feature,
    join_key,
    changeset_id,
    e_feature_status
)
select 
    temp_feature_id,
    temp_layer_id,
    temp_s_name,
    temp_e_feature_type,
    temp_s_source_id,
    temp_geom_feature,
    temp_join_key, 
    :changeset_id as changeset_id,
    'MODIFIED' as e_feature_status
from source_modified_features;

-- insert added features
insert into map_manager.mm_feature (
    feature_id,
    layer_id, 
    s_name,
    e_feature_type,
    s_source_id,
    geom_feature,
    join_key,
    changeset_id,
    e_feature_status
)
select 
    temp_feature_id,
    temp_layer_id,
    temp_s_name,
    temp_e_feature_type,
    temp_s_source_id,
    temp_geom_feature,
    temp_join_key,
    :changeset_id as changeset_id,
    'ADDED' as e_feature_status
from source_added_features;

-- -- insert removed features
insert into map_manager.mm_feature (
    feature_id,
    layer_id, 
    s_name,
    e_feature_type,
    s_source_id,
    geom_feature,
    join_key,
    changeset_id,
    e_feature_status
)
select 
    latest_feature_id,
    latest_layer_id,
    latest_s_name,
    latest_e_feature_type,
    latest_source_id,
    latest_geom_feature,
    latest_join_key,
    :changeset_id as changeset_id,
    'REMOVED' as e_feature_status
from source_deleted_features;
    
-- insert modified attributes
insert into map_manager.mm_attribute (
    attribute_id,
    feature_id,
    s_name,
    s_value,
    join_key,
    changeset_id,
    b_changeset_delete
)
select
    temp_attribute_id,
    temp_feature_id,
    temp_s_name,
    temp_s_value,
    temp_join_key,
    :changeset_id as changeset_id,
    false
from source_modified_attributes;

-- insert added attributes
insert into map_manager.mm_attribute(
    attribute_id,
    feature_id,
    s_name,
    s_value,
    join_key,
    changeset_id,
    b_changeset_delete 
)
select 
    temp_attribute_id,
    temp_feature_id,
    temp_s_name,
    temp_s_value,
    temp_join_key,
    :changeset_id as changeset_id,
    false
from source_added_attributes;

-- insert deleted attributes
insert into map_manager.mm_attribute(
    attribute_id,
    feature_id,
    s_name,
    s_value,
    join_key,
    changeset_id,
    b_changeset_delete 
)
select 
    latest_attribute_id,
    latest_feature_id,
    latest_s_name,
    latest_s_value,
    latest_join_key,
    :changeset_id as changeset_id,
    true
from source_deleted_attributes;

with modified_features as (
    select temp_feature_id from source_modified_attributes union
    select temp_feature_id from source_added_attributes union
    select latest_feature_id from source_deleted_attributes
) 
update map_manager.mm_feature set e_feature_status = 'MODIFIED', association_changeset_id = :changeset_id where mm_feature.feature_id in (select temp_feature_id from modified_features) and mm_feature.b_is_latest = true;
