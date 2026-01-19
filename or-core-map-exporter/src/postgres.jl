"""
    initialise_db()

Initialise connections to RDS

"""
function initialise_db()
    global_psql_config( 
        PostgreSQLConnectionParams( 
            endpoint=get(ENV, "PG_ENDPOINT", "localhost:5440"), 
            dbname=get(ENV, "PG_DBNAME", "postgres"), 
            user=get(ENV, "PG_RDS_IAM_USER", get(ENV, "PG_USER", "postgres")), 
            password=get(ENV, "PG_PASSWORD", "postgres"),
            iam_connection=!isempty(get(ENV, "PG_RDS_IAM_USER", ""))
        ) 
    )
end

# Function to create materialised view
function create_export_view(schema="map_manager", debug=false)
  # Try to drop table to handle when a previous run failed
  drop_table = "DROP MATERIALIZED VIEW if exists $(schema).mm_osm_export_mv;"
  execute_psql_string(drop_table)

  @info "Creating materialised view mm_osm_export_mv"
  # Creates a materialised view
  create_materialised_view = "CREATE MATERIALIZED VIEW $(schema).mm_osm_export_mv AS
  WITH res AS (
    SELECT feature_id,
    jsonb_object_agg(s_name, s_value) FILTER (WHERE s_name NOT IN (
        'DEC_NAME', 'DEC_TYPE', 'declared_road', 'RD_NUM', 'RD_SECTION', 'CLASSN', 'ARTERIAL', 'PROFILE', 'RTE_NO', 
        'CWAY', 'SERVICE_RD', 'RAMP', 'COMPLEX', 'CBR', 'R_RTE_NO', 'R_CWAY', 'R_RAMP', 'RNDB_EDIT', 'SRNS1', 'SRNS2',
        'SRNS3', 'MEL30_ART', 'RMANUM', 'RMACLASS', 'RAMP_NUM', 'RAMP_NAME', 'AUSLINK', 'DEC_STATUS', 'PREV_RMA', 'RMC',
        'MAINT_ORG', 'LGA_ABB_NAME', 'LGA_NAME', 'REGION_NAME', 'RESPONSIBLE_REGION_NAME'
    )) AS tags, 
    jsonb_object_agg(s_name, s_value) FILTER (WHERE s_name IN (
      'DEC_NAME', 'DEC_TYPE', 'declared_road', 'RD_NUM', 'RD_SECTION', 'CLASSN', 'ARTERIAL', 'PROFILE', 'RTE_NO', 
      'CWAY', 'SERVICE_RD', 'RAMP', 'COMPLEX', 'CBR', 'R_RTE_NO', 'R_CWAY', 'R_RAMP', 'RNDB_EDIT', 'SRNS1', 'SRNS2',
      'SRNS3', 'MEL30_ART', 'RMANUM', 'RMACLASS', 'RAMP_NUM', 'RAMP_NAME', 'AUSLINK', 'DEC_STATUS', 'PREV_RMA', 'RMC',
      'MAINT_ORG', 'LGA_ABB_NAME', 'LGA_NAME', 'REGION_NAME', 'RESPONSIBLE_REGION_NAME'
    )) AS custom_attribute_tags
  FROM $(schema).mm_derived_attribute WHERE b_is_latest = true AND (feature_id LIKE 'OSM&&WAY%' OR feature_id like 'DTP&&WAY%') GROUP BY feature_id
  ), feat AS (
    SELECT * FROM $(schema).mm_derived_feature WHERE b_is_latest='t' AND layer_id= 'DTP_OSM'
  ), rel AS (
    SELECT feature_id_input, 
    UNNEST(feature_id_matched) AS feature_id_matched
    FROM $(schema).mm_derived_relationship 
    WHERE b_is_latest = 't' AND layer_id = 'VICMAP_TRANSPORT'
  ), osm_mv AS (
    SELECT feat.feature_id, feat.mapping_feature_id, tags, custom_attribute_tags, 
    e_feature_type, layer_id, s_name, s_source_id, 
    st_asgeojson(geom_feature) AS geom_feature, rel.feature_id_input
    FROM res RIGHT JOIN feat ON feat.feature_id = res.feature_id 
    LEFT JOIN rel ON feat.feature_id = rel.feature_id_matched
  ), vicmap_tags AS (
    SELECT feature_id AS vmt_feature_id, 
    jsonb_object_agg(s_name, s_value) AS vicmap_tags
    FROM $(schema).mm_attribute WHERE b_is_latest = 't' AND 
    feature_id LIKE 'VICMAP%' AND s_name IN ('alternative_road_1', 'alternative_road_2', 'alternative_road_3', 'class_code', 'div_rd', 
    'left_locality', 'local_road', 'restrictions', 'right_locality', 'road_name', 'road_name_1', 'road_name_2', 'road_name_3', 'road_name_use', 'road_seal',
    'road_status', 'road_suffix', 'road_suffix_1', 'road_suffix_2', 'road_suffix_3', 'road_type', 'road_type_1', 'road_type_2', 'road_type_3', 'seasonal_close_date', 
    'seasonal_open_date', 'ufi', 'urban', 'vehicular_access'                             
    ) GROUP BY feature_id
  )
  SELECT feature_id, mapping_feature_id, tags, custom_attribute_tags, e_feature_type, 
  layer_id, s_name, s_source_id, 
  st_asgeojson(geom_feature) AS geom_feature, 
  vicmap_tags AS vmt_tags, 
  feature_id_input
  FROM osm_mv
  LEFT JOIN vicmap_tags ON osm_mv.feature_id_input = vicmap_tags.vmt_feature_id 
  GROUP BY feature_id, mapping_feature_id, tags, custom_attribute_tags, e_feature_type, layer_id, s_name, s_source_id, geom_feature, vmt_tags, feature_id_input;"
  execute_psql_string(create_materialised_view)
  @info "Created materialised view mm_osm_export_mv"
end