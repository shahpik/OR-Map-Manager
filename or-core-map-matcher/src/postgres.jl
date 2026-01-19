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

# Function to upload map matching results
function source_elt(df, sourceName, trigger_layer; schema="map_manager", original_osm, debug=false)
    # Extract the data needed to load the DataFrame into the DB
    column_names = names(df)
    # Changed bufsize to account for large row sizes
    data = CSV.RowWriter(df, bufsize = 2^26, transform=(col, val) -> something(val, missing))
    # Try to drop table to handle when a previous run failed
    drop_table = "DROP TABLE if exists $(schema).stg_temp_map_matching_results;"
    execute_psql_string(drop_table)

    # Creates a staging table with text as the column type for everything
    create_staging_table = "CREATE TABLE if not exists $(schema).stg_temp_map_matching_results ($("\"" * join(column_names, "\" text, \"") * "\"") text);"
    execute_psql_string(create_staging_table)
    @info "Created staging table for temp_map_matching_results"

    # Copy in data from the DataFrames
    copy_string = "COPY $(schema).stg_temp_map_matching_results ($("\"" * join(column_names, "\", \"") * "\"")) FROM STDIN (FORMAT CSV, HEADER);"
    PSQLInterface.execute_psql_string_copyin(copy_string, data)
    @info "Loaded raw data into temp_map_matching_results staging table"

    if original_osm
      write_original_relationships_to_db(sourceName, trigger_layer)
    else 
      write_derived_relationships_to_db(sourceName, trigger_layer)
    end

    # Drop staging table
    if debug
      @warn "In debug mode, skipping staging table drop"
    else
      #PSQLInterface.execute_psql_string(drop_table)
      @info "Retain temp map matching results for Testing"
      #@info "Dropped temp_map_matching_results staging table"
    end
end

function write_original_relationships_to_db(sourceName::String, trigger_layer::String)

  uppercaseSN = uppercase(string(sourceName))
  uppercaseTL = uppercase(trigger_layer)
  match_report_gen_time = DataFrame(PSQLInterface.execute_psql_string("""select extract(epoch from now())::int"""))[1,1]

  insert_relationships_statement = """
  WITH changeset_count as (
    select count(*) from map_manager.mm_changeset where e_changeset_edit_type = 'SOURCE'
  ), get_changeset_id as (
    select case when (select count from changeset_count) = 0 then 'INITIAL_CHANGESET'
    else (select changeset_id from map_manager.mm_changeset where e_changeset_edit_type = 'SOURCE' and layer_id = '$uppercaseTL' order by dt_last_opened desc limit 1)
    end as changeset_id
  ), get_changeset_info as (
    select global_version_id, changeset_id from map_manager.mm_global_version where changeset_id = (select changeset_id from get_changeset_id)
  ), latest_features AS (
    SELECT feature_id
    FROM map_manager.mm_feature
    WHERE layer_id = '$uppercaseSN' AND b_is_latest = true
  ), temp_map_matching_relationship AS (
    SELECT '$uppercaseSN&&' || $match_report_gen_time AS match_report_id,
      ST_GeomFromGeoJSON("geometry") AS geom_relationship,
      "offset_start"::float AS f_start_offset,
      "offset_end"::float AS f_end_offset,
      "mapmatching_error"::float AS f_error_value,
      id AS feature_id_input,
      translate("matched_ways", '[]', '{}')::text[] AS feature_id_matched
    FROM map_manager.stg_temp_map_matching_results stmmr 
    INNER JOIN latest_features 
    ON latest_features.feature_id = stmmr."id"
    WHERE matched_ways is not NULL
  )
  INSERT INTO map_manager.mm_relationship(
    relationship_id,
    e_relationship_type,
    geom_relationship,
    f_start_offset,
    f_end_offset,
    f_error_value,
    feature_id_input,
    feature_id_matched,
    layer_id,
    global_version_id_start,
    global_version_id_end,
    changeset_id,
    join_key,
    b_changeset_delete,
    b_is_deleted,
    b_user_edit
  )
  SELECT 
    match_report_id || '&&' || feature_id_input as relationship_id,
    'AUTOMATIC',
    geom_relationship,
    f_start_offset,
    f_end_offset,
    f_error_value,
    feature_id_input,
    feature_id_matched,
    '$uppercaseSN',
    global_version_id,
    null,
    changeset_id,
    MD5(coalesce(st_astext(geom_relationship), '') || coalesce(f_error_value::text, '') || coalesce(feature_id_input, '') || coalesce(feature_id_matched::text, '')) as join_key,
    null,
    null,
    null
  FROM temp_map_matching_relationship, get_changeset_info
  ON CONFLICT DO NOTHING;
  """

  PSQLInterface.execute_psql_string(insert_relationships_statement)
  
  return nothing
end

function write_derived_relationships_to_db(sourceName::String, trigger_layer::String)

  uppercaseSN = uppercase(string(sourceName))
  uppercaseTL = uppercase(trigger_layer)
  match_report_gen_time = DataFrame(PSQLInterface.execute_psql_string("""select extract(epoch from now())::int"""))[1,1]

  insert_relationships_statement = """
  WITH changeset_count as (
    select count(*) from map_manager.mm_changeset where e_changeset_edit_type = 'SOURCE'
  ), get_changeset_id as (
    select case when (select count from changeset_count) = 0 then 'INITIAL_CHANGESET'
    else (select changeset_id from map_manager.mm_changeset where e_changeset_edit_type = 'SOURCE' and layer_id = '$uppercaseTL' order by dt_last_opened desc limit 1)
    end as changeset_id
  ), get_changeset_info as (
    select global_version_id, changeset_id from map_manager.mm_global_version where changeset_id = (select changeset_id from get_changeset_id)
  ), latest_features AS (
    SELECT feature_id
    FROM map_manager.mm_feature
    WHERE layer_id = '$uppercaseSN' AND b_is_latest = true
  ), temp_map_matching_relationship AS (
    SELECT '$uppercaseSN&&' || $match_report_gen_time AS match_report_id,
      ST_GeomFromGeoJSON("geometry") AS geom_relationship,
      "offset_start"::float AS f_start_offset,
      "offset_end"::float AS f_end_offset,
      "mapmatching_error"::float AS f_error_value,
      id AS feature_id_input,
      translate("matched_ways", '[]', '{}')::text[] AS feature_id_matched
    FROM map_manager.stg_temp_map_matching_results stmmr 
    INNER JOIN latest_features 
    ON latest_features.feature_id = stmmr."id"
    WHERE matched_ways is not NULL
  )
  INSERT INTO map_manager.mm_derived_relationship(
    relationship_id,
    e_relationship_type,
    geom_relationship,
    f_start_offset,
    f_end_offset,
    f_error_value,
    feature_id_input,
    feature_id_matched,
    layer_id,
    global_version_id_start,
    global_version_id_end,
    changeset_id,
    b_user_edit
  )
  SELECT 
    match_report_id || '&&' || feature_id_input as relationship_id,
    'AUTOMATIC',
    geom_relationship,
    f_start_offset,
    f_end_offset,
    f_error_value,
    feature_id_input,
    feature_id_matched,
    '$uppercaseSN',
    global_version_id,
    null,
    changeset_id,
    null
  FROM temp_map_matching_relationship, get_changeset_info
  ON CONFLICT DO NOTHING;
  """
  PSQLInterface.execute_psql_string(insert_relationships_statement)
  
  return nothing
end

function generate_match_report(sourceName::String)
  uppercaseSN = uppercase(string(sourceName))

  generate_initial_report_statement = """
  WITH match_report_max_version AS (
    SELECT 
        CASE WHEN max(n_version) is null THEN 1
        ELSE (max(n_version) + 1) end AS max_version  
    FROM map_manager.mm_match_report
    WHERE layer_id = '$uppercaseSN'
  ), max_global_version AS (
      SELECT global_version_id
      FROM map_manager.mm_global_version
      WHERE changeset_id = 'INITIAL_CHANGESET'
  ), get_relationship_id AS (
      SELECT relationship_id FROM map_manager.mm_derived_relationship WHERE changeset_id = 'INITIAL_CHANGESET' AND feature_id_input like '$uppercaseSN' || '%' LIMIT 1
  ), match_report_gen_time AS (
      SELECT split_part(relationship_id, '&&', 2)::int AS report_gen_time FROM get_relationship_id
  ), vmt_filter_class_zero_to_seven AS (
    SELECT DISTINCT feature_id FROM map_manager.mm_attribute WHERE s_name = 'class_code' AND s_value in ('0', '1', '2', '3', '4', '5', '6', '7')
    AND feature_id LIKE 'VICMAP%' AND b_is_latest = true
  ), vmt_connector_ford_count AS (
    SELECT count(distinct(mm_attribute.feature_id)) FROM map_manager.mm_attribute INNER JOIN vmt_filter_class_zero_to_seven ON vmt_filter_class_zero_to_seven.feature_id = mm_attribute.feature_id
    WHERE s_name = 'feature_type_code' AND s_value in ('connector', 'ford') AND mm_attribute.feature_id LIKE 'VICMAP%' AND b_is_latest = true
  ), vmt_filter_class_eight as (
    SELECT DISTINCT feature_id FROM map_manager.mm_attribute WHERE s_name = 'class_code' AND s_value = '8' AND feature_id LIKE 'VICMAP%' AND b_is_latest = true
  ), vmt_class_eight_bridge_road as (
    SELECT count(distinct(mm_attribute.feature_id)) FROM map_manager.mm_attribute INNER JOIN vmt_filter_class_eight ON vmt_filter_class_eight.feature_id = mm_attribute.feature_id
    WHERE s_name = 'feature_type_code' AND s_value not in ('bridge', 'road')
  ), vmt_filter_class_nine as (
    SELECT DISTINCT feature_id FROM map_manager.mm_attribute WHERE s_name = 'class_code' AND s_value = '9' AND feature_id LIKE 'VICMAP%' AND b_is_latest = true
  ), vmt_class_nine_trail_tunnel as (
    SELECT count(distinct(mm_attribute.feature_id)) FROM map_manager.mm_attribute INNER JOIN vmt_filter_class_nine ON vmt_filter_class_nine.feature_id = mm_attribute.feature_id
    WHERE s_name = 'feature_type_code' AND s_value not in ('trail', 'tunnel')
  ), vmt_filter_class_thirteen AS (
    SELECT DISTINCT feature_id FROM map_manager.mm_attribute WHERE s_name = 'class_code' AND s_value = '13' AND feature_id LIKE 'VICMAP%' AND b_is_latest = true
  ), vmt_class_thirteen_road_count AS (
    SELECT count(distinct(mm_attribute.feature_id)) FROM map_manager.mm_attribute INNER JOIN vmt_filter_class_thirteen ON vmt_filter_class_thirteen.feature_id = mm_attribute.feature_id
    WHERE s_name = 'feature_type_code' AND s_value != 'road'
  ), total_feature_count AS (
    SELECT 
      CASE WHEN '$uppercaseSN' = 'VICMAP_TRANSPORT' THEN ((SELECT count(*) FROM map_manager.mm_feature WHERE layer_id = '$uppercaseSN' AND b_is_latest = true) - (select count from vmt_connector_ford_count) - (select count from vmt_class_eight_bridge_road) - (select count from vmt_class_nine_trail_tunnel) - (select count from vmt_class_thirteen_road_count))
      ELSE ((SELECT count(*) FROM map_manager.mm_feature WHERE layer_id = '$uppercaseSN' AND b_is_latest = true)) end as total_feature_count
  ), matched_feature_count as (
    (SELECT count(*) AS matched_feature_count FROM map_manager.mm_derived_relationship WHERE layer_id = '$uppercaseSN' AND b_is_latest = true AND feature_id_matched != '{""}')
  )
  INSERT INTO map_manager.mm_match_report (
    match_report_id,
    dt_timestamp,
    n_version,
    n_matched_features,
    n_failed_features,
    f_matching_rate,
    is_latest,
    layer_id,
    e_error_unit,
    global_version_id
  )
  SELECT '$uppercaseSN' || '&&' || report_gen_time as match_report_id,
  report_gen_time,
  max_version,
  matched_feature_count,
  (total_feature_count - matched_feature_count) as n_failed_feature,
  matched_feature_count::float / total_feature_count::float as f_matching_rate,
  true,
  '$uppercaseSN',
  'M2_PER_M',
  global_version_id
  FROM match_report_gen_time, match_report_max_version, matched_feature_count, total_feature_count, max_global_version;
  """

  execute_psql_string(generate_initial_report_statement)
  return nothing
end

function publish_match_report(sourceName::String, trigger_layer::String="VICMAP_TRANSPORT")

  uppercaseSN = uppercase(string(sourceName))
  trigger_layer = uppercase(string(trigger_layer))

  update_previous_match_report_status_statement = """
  UPDATE map_manager.mm_match_report 
  SET is_latest = false 
  WHERE layer_id = \$1;
  """ 

  generate_match_report_statement = """
  with current_changeset AS (
    SELECT changeset_id AS current_changeset_id
    FROM map_manager.mm_changeset
    WHERE layer_id = \$1 AND
    e_changeset_edit_type = 'SOURCE'
    ORDER BY s_layer_version DESC 
    LIMIT 1
  ), get_relationship_id AS (
    SELECT relationship_id FROM map_manager.mm_derived_relationship 
    WHERE changeset_id = (SELECT current_changeset_id FROM current_changeset)
    LIMIT 1
  ), match_report_gen_time AS (
    SELECT split_part(relationship_id, '&&', 2)::int AS report_gen_time FROM get_relationship_id 
  ), match_report_max_version AS (
    SELECT 
        CASE WHEN max(n_version) is null THEN 1
        ELSE (max(n_version) + 1) end AS max_version  
    FROM map_manager.mm_match_report
    WHERE layer_id = \$2
  ), max_global_version AS (
    SELECT global_version_id
    FROM map_manager.mm_global_version
    WHERE mm_global_version.changeset_id = (SELECT current_changeset_id FROM current_changeset)
  ), vmt_filter_class_zero_to_seven AS (
    SELECT DISTINCT feature_id FROM map_manager.mm_attribute WHERE s_name = 'class_code' AND s_value in ('0', '1', '2', '3', '4', '5', '6', '7')
    AND feature_id LIKE 'VICMAP%' AND b_is_latest = true
  ), vmt_connector_ford_count AS (
    SELECT count(distinct(mm_attribute.feature_id)) FROM map_manager.mm_attribute INNER JOIN vmt_filter_class_zero_to_seven ON vmt_filter_class_zero_to_seven.feature_id = mm_attribute.feature_id
    WHERE s_name = 'feature_type_code' AND s_value in ('connector', 'ford') AND mm_attribute.feature_id LIKE 'VICMAP%' AND b_is_latest = true
  ), vmt_filter_class_eight as (
    SELECT DISTINCT feature_id FROM map_manager.mm_attribute WHERE s_name = 'class_code' AND s_value = '8' AND feature_id LIKE 'VICMAP%' AND b_is_latest = true
  ), vmt_class_eight_bridge_road as (
    SELECT count(distinct(mm_attribute.feature_id)) FROM map_manager.mm_attribute INNER JOIN vmt_filter_class_eight ON vmt_filter_class_eight.feature_id = mm_attribute.feature_id
    WHERE s_name = 'feature_type_code' AND s_value not in ('bridge', 'road')
  ), vmt_filter_class_nine as (
    SELECT DISTINCT feature_id FROM map_manager.mm_attribute WHERE s_name = 'class_code' AND s_value = '9' AND feature_id LIKE 'VICMAP%' AND b_is_latest = true
  ), vmt_class_nine_trail_tunnel as (
    SELECT count(distinct(mm_attribute.feature_id)) FROM map_manager.mm_attribute INNER JOIN vmt_filter_class_nine ON vmt_filter_class_nine.feature_id = mm_attribute.feature_id
    WHERE s_name = 'feature_type_code' AND s_value not in ('trail', 'tunnel')
  ), vmt_filter_class_thirteen AS (
    SELECT DISTINCT feature_id FROM map_manager.mm_attribute WHERE s_name = 'class_code' AND s_value = '13' AND feature_id LIKE 'VICMAP%' AND b_is_latest = true
  ), vmt_class_thirteen_road_count AS (
    SELECT count(distinct(mm_attribute.feature_id)) FROM map_manager.mm_attribute INNER JOIN vmt_filter_class_thirteen ON vmt_filter_class_thirteen.feature_id = mm_attribute.feature_id
    WHERE s_name = 'feature_type_code' AND s_value != 'road'
  ), total_feature_count AS (
    SELECT 
      CASE WHEN \$2 = 'VICMAP_TRANSPORT' THEN ((SELECT count(*) FROM map_manager.mm_feature WHERE layer_id = \$2 AND b_is_latest = true) - (select count from vmt_connector_ford_count) - (select count from vmt_class_eight_bridge_road) - (select count from vmt_class_nine_trail_tunnel) - (select count from vmt_class_thirteen_road_count))
      ELSE ((SELECT count(*) FROM map_manager.mm_feature WHERE layer_id = \$2 AND b_is_latest = true)) end as total_feature_count
  ), matched_feature_count as (
    (SELECT count(*) AS matched_feature_count FROM map_manager.mm_derived_relationship WHERE layer_id = \$2 AND b_is_latest = true AND feature_id_matched != '{""}')
  )
  INSERT INTO map_manager.mm_match_report (
    match_report_id,
    dt_timestamp,
    n_version,
    n_matched_features,
    n_failed_features,
    f_matching_rate,
    is_latest,
    layer_id,
    e_error_unit,
    global_version_id
  )
  SELECT \$2 || '&&' || report_gen_time,
  report_gen_time,
  max_version,
  matched_feature_count,
  (total_feature_count - matched_feature_count) as n_failed_feature,
  matched_feature_count::float / total_feature_count::float as f_matching_rate,
  true,
  \$2,
  'M2_PER_M',
  global_version_id
  FROM match_report_gen_time, max_global_version, match_report_max_version, total_feature_count, matched_feature_count;
  """

  PSQLInterface.execute_psql_string(update_previous_match_report_status_statement, parameters=[uppercaseSN])
  PSQLInterface.execute_psql_string(generate_match_report_statement, parameters=[trigger_layer, uppercaseSN])
  return nothing
end

function load_delta_relationships(sourceName::String)
  
  uppercaseSN = uppercase(string(sourceName))
  match_report_gen_time = DataFrame(PSQLInterface.execute_psql_string("""select extract(epoch from now())::int"""))[1,1]

  insert_temp_relationships_statement = """
  WITH temp_map_matching_relationship AS (
    SELECT st_geomfromgeojson("geometry") AS geom_relationship,
      "offset_start"::float AS f_start_offset,
      "offset_end"::float AS f_end_offset,
      "mapmatching_error"::float AS f_error_value,
      id AS feature_id_input,
      translate("matched_ways", '[]', '{}')::text[] AS feature_id_matched
    FROM map_manager.stg_temp_map_matching_results stmmr 
    WHERE matched_ways is not null
  )
  INSERT INTO map_manager.mm_temp_relationship (
    relationship_id,
    geom_relationship,
    f_start_offset,
    f_end_offset,
    f_error_value,
    feature_id_input,
    feature_id_matched,
    join_key
  )
  SELECT '$uppercaseSN&&' || $match_report_gen_time || '&&' || feature_id_input as relationship_id,
    geom_relationship,
    f_start_offset,
    f_end_offset,
    f_error_value,
    feature_id_input,
    feature_id_matched,
    MD5(coalesce(st_astext(geom_relationship), '') || coalesce(f_error_value::text, '') || coalesce(feature_id_input, '') || coalesce(feature_id_matched::text, '')) AS join_key
  FROM temp_map_matching_relationship;
  """

  update_mm_temp_relationship_feature_id_matched_statement = """
  WITH mm_feature_osm_lines AS (
    SELECT feature_id, s_source_id
    FROM map_manager.mm_feature
    WHERE layer_id = 'OSM' AND e_feature_type = 'LINE' AND b_is_latest = true
  ), mm_relationship_matched_lines AS (
    SELECT relationship_id, unnest(feature_id_matched) AS feature_id_matched
    FROM map_manager.mm_temp_relationship 
  ), relationship_feature_mapping AS (
    SELECT relationship_id, feature_id
    FROM mm_relationship_matched_lines INNER JOIN mm_feature_osm_lines
    ON mm_feature_osm_lines.s_source_id = mm_relationship_matched_lines.feature_id_matched  
  ), relationship_feature_mapped AS (
    SELECT relationship_id, array_agg(feature_id) AS feature_id_matched_list
    FROM relationship_feature_mapping GROUP BY relationship_id
  )
  UPDATE map_manager.mm_temp_relationship SET feature_id_matched = relationship_feature_mapped.feature_id_matched_list
  FROM relationship_feature_mapped
  WHERE mm_temp_relationship.relationship_id = relationship_feature_mapped.relationship_id;
  """

  insert_relationships_statement = """
  WITH new_relationships AS (
    SELECT * FROM map_manager.mm_temp_relationship
    WHERE NOT EXISTS (SELECT * FROM map_manager.mm_relationship WHERE mm_relationship.join_key = mm_temp_relationship.join_key)
  ), changeset_layer_id AS (
    SELECT CASE when exists (select * from map_manager.mm_feature where global_version_id_start is null) THEN '$uppercaseSN'
    ELSE 'OSM'
    END AS changeset_layer_id
  ), current_changeset AS (
    SELECT changeset_id AS current_changeset_id
    FROM map_manager.mm_changeset
    WHERE layer_id = (select changeset_layer_id from changeset_layer_id) AND 
    e_changeset_edit_type = 'SOURCE'
    ORDER BY s_layer_version DESC 
    LIMIT 1
  ), global_version_id AS (
    SELECT 
      CASE WHEN changeset_layer_id = 'OSM' THEN (SELECT global_version_id FROM map_manager.mm_global_version WHERE changeset_id = (SELECT current_changeset_id FROM current_changeset))
      ELSE null
      END AS global_version_id
    FROM changeset_layer_id
  )
  INSERT INTO map_manager.mm_relationship (
    relationship_id,
    e_relationship_type,
    geom_relationship,
    f_start_offset,
    f_end_offset,
    f_error_value,
    feature_id_input,
    feature_id_matched,
    layer_id,
    global_version_id_start,
    global_version_id_end,
    changeset_id, 
    join_key,
    b_changeset_delete,
    b_is_deleted,
    b_user_edit
  )
  SELECT relationship_id,
    'AUTOMATIC',
    geom_relationship,
    f_start_offset,
    f_end_offset,
    f_error_value,
    feature_id_input,
    feature_id_matched,
    '$uppercaseSN',
    global_version_id,
    null,
    current_changeset_id,
    join_key,
    null,
    null,
    null
  FROM new_relationships, current_changeset, global_version_id
  WHERE feature_id_input NOT IN (
    SELECT feature_id_input 
    FROM map_manager.mm_relationship
    WHERE b_user_edit = true AND 
    b_is_latest = true
  )
  """

  PSQLInterface.execute_psql_string(insert_temp_relationships_statement)
  PSQLInterface.execute_psql_string(update_mm_temp_relationship_feature_id_matched_statement)
  PSQLInterface.execute_psql_string(insert_relationships_statement)
  return nothing
end


"""
remove_invalid_relationships(sourceName::String)

This function is not used in the current step function as the delta process is not being used for relationships. 
It was built to create new relationship entries with 'null' as the matched_ways, indicating that the relationship had been removed. 
"""
function remove_invalid_relationships(sourceName::String)

  uppercaseSN = uppercase(string(sourceName))

  remove_invalid_relationships_statement = """
  WITH current_changeset_layer_id AS (
    SELECT CASE 
    WHEN EXISTS (SELECT * FROM map_manager.mm_feature WHERE global_version_id_start is null) THEN '$uppercaseSN'
    ELSE 'OSM'
    END AS current_changeset_layer_id
  ), current_changeset as (
    SELECT changeset_id AS current_changeset_id
    FROM map_manager.mm_changeset 
    WHERE layer_id = (SELECT current_changeset_layer_id FROM current_changeset_layer_id) AND
    e_changeset_edit_type = 'SOURCE'
    ORDER BY s_layer_version DESC
    LIMIT 1
  ), removed_features AS (
    SELECT feature_id from map_manager.mm_feature
    WHERE changeset_id = (SELECT current_changeset_id from current_changeset) AND 
    e_feature_status = 'REMOVED'
  ), updated_records AS (
    UPDATE map_manager.mm_relationship SET global_version_id_end = (SELECT max(global_version_id) FROM map_manager.mm_global_version)
    FROM removed_features
    WHERE mm_relationship.feature_id_input IN (SELECT feature_id FROM removed_features) AND 
    b_is_latest = true
    returning mm_relationship.*
  )
  INSERT INTO map_manager.mm_relationship (
    relationship_id,
    e_relationship_type,
    geom_relationship,
    f_start_offset,
    f_end_offset,
    f_error_value,
    feature_id_input,
    feature_id_matched,
    layer_id,
    global_version_id_start,
    global_version_id_end,
    changeset_id, 
    join_key,
    b_changeset_delete,
    b_is_deleted,
    b_user_edit
 )
  SELECT 
    relationship_id,
    e_relationship_type,
    null,
    null,
    null,
    null,
    feature_id_input,
    null as feature_id_matched,
    layer_id,
    null,
    null,
    current_changeset_id,
    MD5(coalesce(st_astext(geom_relationship), '') || coalesce(f_error_value::text, '') || coalesce(feature_id_input, '') || coalesce(feature_id_matched::text, '')) as join_key,
    true as b_changeset_delete,
    null,
    null
  FROM updated_records, current_changeset
  """

  PSQLInterface.execute_psql_string(remove_invalid_relationships_statement)
end

function create_dtp_osm_layer()
  PSQLInterface.execute_psql_string("""insert into map_manager.mm_layer (layer_id, s_name, e_layer_type) values ('DTP_OSM', 'DTP OSM', 'GRAPH') ON CONFLICT (layer_id) DO NOTHING;""")
  @info "DTP OSM layer is inserted to DB"
end

"""invalidate_DTP_OSM_features_and_attributes()

This function should be called after the OSM Split calculation is performed to invalidate the current
split geometries and attributes in the mm_derived_feature and mm_derived_attribute tables. 
In the current state, we are loading full feature and attribute sets rather than a delta, 
so we will invalidate every row where global_version_id_start != max(global_version_id) 
and global_version_id_end = NULL. Future update may be to invalidate only features/attributes
overwritten by a delta. 
"""
function invalidate_DTP_OSM_features_and_attributes(trigger_layer::String)
    uppercaseTL = uppercase(trigger_layer)
    changeset_version = execute_psql_string("""
    with latest_changeset_id as (
        select changeset_id from map_manager.mm_changeset where e_changeset_edit_type = 'SOURCE' and layer_id = '$uppercaseTL' order by dt_last_opened desc limit 1
    )
    select (global_version_id - 1) from map_manager.mm_global_version where changeset_id = (select changeset_id from latest_changeset_id);
    """)
    if !isempty(DataFrame(changeset_version))
        end_version = DataFrame(changeset_version)[1,1]
    else 
        @error "No changeset found"
    end

    update_derived_features = """
    update map_manager.mm_derived_feature set global_version_id_end = \$1 where
    mm_derived_feature.global_version_id_start != \$1 + 1 and global_version_id_end is null;
    """

    update_derived_attributes = """
    update map_manager.mm_derived_attribute set global_version_id_end = \$1 where
    mm_derived_attribute.global_version_id_start != \$1 + 1 and global_version_id_end is null;
    """

    PSQLInterface.execute_psql_string(update_derived_features, parameters=[end_version])
    PSQLInterface.execute_psql_string(update_derived_attributes, parameters=[end_version])
    @info "Invalidated previous DTP OSM Road Network Features & Attributes"
    return nothing
end

"""invalidate_DTP_OSM_relationships()

This function should be called after map matching is run on VicMap Transport against the DTP OSM Road Network. 
In the current state, we are loading a full relationship set rather than a delta, 
so we will invalidate every row where global_version_id_start != max(global_version_id) 
and global_version_id_end = NULL. Future update may be to invalidate only relationships
overwritten by a delta. 
"""
function invalidate_DTP_OSM_relationships(trigger_layer::String)
    uppercaseTL = uppercase(trigger_layer)
    changeset_version = execute_psql_string("""
    with latest_changeset_id as (
        select changeset_id from map_manager.mm_changeset where e_changeset_edit_type = 'SOURCE' and layer_id = '$uppercaseTL' order by dt_last_opened desc limit 1
    )
    select (global_version_id - 1) from map_manager.mm_global_version where changeset_id = (select changeset_id from latest_changeset_id);
    """)
    if !isempty(DataFrame(changeset_version))
        end_version = DataFrame(changeset_version)[1,1]
    else 
        @error "No changeset found"
    end

    update_derived_relationships = """
    update map_manager.mm_derived_relationship set global_version_id_end = \$1 where
    mm_derived_relationship.global_version_id_start != \$1 + 1 and global_version_id_end is null;
    """

    PSQLInterface.execute_psql_string(update_derived_relationships, parameters=[end_version])
    @info "Invalidated previous DTP OSM Road Network Relationships"
    return nothing
end


"""invalidate_original_OSM_relationships()

This function should be called after map matching is run on VicMap Transport against the original OSM Network. 
In the current state, we are loading a full relationship set rather than a delta, 
so we will invalidate every row where global_version_id_start != max(global_version_id) 
and global_version_id_end = NULL. Future update may be to invalidate only relationships
overwritten by a delta. 
"""
function invalidate_original_OSM_relationships(trigger_layer::String)
    uppercaseTL = uppercase(trigger_layer)
    changeset_version = execute_psql_string("""
    with latest_changeset_id as (
        select changeset_id from map_manager.mm_changeset where e_changeset_edit_type = 'SOURCE' and layer_id = '$uppercaseTL' order by dt_last_opened desc limit 1
    )
    select (global_version_id - 1) from map_manager.mm_global_version where changeset_id = (select changeset_id from latest_changeset_id);
    """)
    if !isempty(DataFrame(changeset_version))
        end_version = DataFrame(changeset_version)[1,1]
    else 
        @error "No changeset found"
    end

    update_relationships = """
    update map_manager.mm_relationship set global_version_id_end = \$1 where
    mm_relationship.global_version_id_start != \$1 + 1 and global_version_id_end is null;
    """

    PSQLInterface.execute_psql_string(update_relationships, parameters=[end_version])
    @info "Invalidated previous OSM Network Relationships"
    return nothing
end