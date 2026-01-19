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
            iam_connection=!isempty(get(ENV, "PG_RDS_IAM_USER", "")), 
        ) 
    )
end


function source_elt(df, table_name; path="/scripts/", schema="map_manager", debug=false)
    # Extract the data needed to load the DataFrame into the DB
    column_names = names(df)
    # Changed bufsize to account for large row sizes
    data = CSV.RowWriter(df, bufsize = 2^30, transform=(col, val) -> something(val, missing))
    # Try to drop table to handle when a previous run failed
    drop_table = "DROP TABLE if exists $(schema).stg_$(table_name);"
    execute_psql_string(drop_table)

    # Creates a staging table with text as the column type for everything
    create_staging_table = "CREATE TABLE if not exists $(schema).stg_$(table_name) ($("\"" * join(column_names, "\" text, \"") * "\"") text);"
    execute_psql_string(create_staging_table)
    @info "Created staging table for $(table_name)"

    # Copy in data from the DataFrames
    copy_string = "COPY $(schema).stg_$(table_name) ($("\"" * join(column_names, "\", \"") * "\"")) FROM STDIN (FORMAT CSV, HEADER);"
    PSQLInterface.execute_psql_string_copyin(copy_string, data)

    @info "Loaded raw data into $(table_name) staging table"

    # Run cleaning and loading scripts
    file_name = "$(table_name).sql"
    script_path = joinpath(path, file_name)
    sql_script = read(script_path, String)
    PSQLInterface.execute_psql_string(sql_script)
    @info "Loaded cleaned & formatted $(table_name) data into schema"

    # Drop staging table
    if debug
        @warn "In debug mode, skipping staging table drop"
    else
        PSQLInterface.execute_psql_string(drop_table)
        @info "Dropped $(table_name) staging table"
    end
end


"""
create_temp_tables()

This function creates temporary tables for data ingestion. The tables are used for data ingestion.
The table name would be tem tables but the table are actually normal tables.
The reason is tem tables automatically drops at the end of a session or a transaction.
"""
function create_temp_tables()

  # Check if temp table exists
  tem_attribute_table_exists = PSQLInterface.execute_psql_string(
    """
    SELECT *
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'map_manager'
    AND TABLE_NAME = 'mm_temp_attribute'
    """
  )

  tem_feature_table_exists = PSQLInterface.execute_psql_string(
    """
    SELECT *
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'map_manager'
    AND TABLE_NAME = 'mm_temp_feature'
    """
  )

  tem_relationship_table_exists = PSQLInterface.execute_psql_string(
    """
    SELECT *
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'map_manager'
    AND TABLE_NAME = 'mm_temp_relationship'
    """
  )

  # Create mm_temp_attribute table
  if isempty(tem_attribute_table_exists)
    PSQLInterface.execute_psql_string(
      """
      CREATE TABLE map_manager.mm_temp_attribute (
      attribute_id TEXT,
      feature_id TEXT,
      s_name TEXT,
      s_value TEXT,
      changeset_id TEXT,
      join_key TEXT
      )
      """
    )
  end

  # Create mm_temp_feature table
  if isempty(tem_feature_table_exists)
    PSQLInterface.execute_psql_string(
      """
      CREATE TABLE map_manager.mm_temp_feature (
      feature_id TEXT,
      layer_id TEXT,
      s_name TEXT,
      e_feature_type TEXT,
      s_source_id TEXT,
      geom_feature GEOMETRY(GEOMETRY, 4326),
      changeset_id TEXT,
      join_key TEXT
      )
      """
    )
  end

  # Create mm_temp_relationship table
  if isempty(tem_relationship_table_exists)
    PSQLInterface.execute_psql_string(
      """
      CREATE TABLE map_manager.mm_temp_relationship (
      relationship_id TEXT,
      geom_relationship GEOMETRY(GEOMETRY, 4326),
      f_start_offset FLOAT8,
      f_end_offset FLOAT8,
      f_error_value FLOAT8,
      feature_id_input TEXT,
      feature_id_matched _TEXT,
      join_key TEXT
      )
      """
    )
  end
end


"""
get_latest_source_changeset_id_by_status(layerId::String, changesetStatus::String)

This function gets latest SOURCE editing changeset ID, 
where the changeset is in given status for the input layer
"""
function get_latest_source_changeset_id_by_status(layerId::String, changesetStatus::String)

  get_changeset_id = PSQLInterface.execute_psql_string("""
    SELECT changeset_id FROM map_manager.mm_changeset
    WHERE e_changeset_edit_type = 'SOURCE'
    AND e_changeset_status = \$2
    AND layer_id = \$1
    ORDER BY s_layer_version DESC limit 1
    """, parameters=[layerId, changesetStatus]
  )
  
  try
    changeset_id = DataFrame(get_changeset_id)[1,1]
    return changeset_id
  catch e
    if isa(e, BoundsError)
        println("Caught BoundsError: Changeset not found - LayerId: $layerId, changesetStatus: $changesetStatus")
    else
        rethrow()
    end
    return nothing
  end
end


"""
truncate_all_temp_tables()

This function deletes all data in the temporary tables for publish workflow.
After data are inserted into actual tables, the data within temp tables can be truncated then. 
"""
function truncate_all_temp_tables()
  # Delete mm_temp_attribute table
  PSQLInterface.execute_psql_string("""TRUNCATE TABLE map_manager.mm_temp_attribute""")
  # Delete mm_temp_feature table
  PSQLInterface.execute_psql_string("""TRUNCATE TABLE map_manager.mm_temp_feature""")
  # Delete mm_temp_relationship table
  PSQLInterface.execute_psql_string("""TRUNCATE TABLE map_manager.mm_temp_relationship""")
end


function create_initial_changeset()
  changeset_creation_time = DataFrame(PSQLInterface.execute_psql_string("""select extract(epoch from now())::int"""))[1,1]

  PSQLInterface.execute_psql_string("""
  INSERT INTO map_manager.mm_changeset (changeset_id, s_layer_version, dt_last_opened) VALUES ('INITIAL_CHANGESET', '0.0', '$changeset_creation_time')
  """)

  PSQLInterface.execute_psql_string("""
  INSERT INTO map_manager.mm_global_version (global_version_id, dt_merged, changeset_id) VALUES (0, 0, 'INITIAL_CHANGESET')
  """)
end


function check_db_before_load()
  try 
    layer_check = PSQLInterface.execute_psql_string("""select * from map_manager.mm_layer limit 1""")
    feature_check = PSQLInterface.execute_psql_string("""select * from map_manager.mm_feature limit 1""")
    attribute_check = PSQLInterface.execute_psql_string("""select * from map_manager.mm_attribute limit 1""")
    hex_check = PSQLInterface.execute_psql_string("""select * from map_manager.mm_hex limit 1""")
    custom_attributes_check = PSQLInterface.execute_psql_string("""select * from map_manager.mm_custom_attribute limit 1""")
    changeset_check = PSQLInterface.execute_psql_string("""select * from map_manager.mm_changeset limit 1""")
    global_version_table_check = PSQLInterface.execute_psql_string("""select * from map_manager.mm_global_version limit 1""")

    if !isempty(layer_check) || !isempty(feature_check) || !isempty(attribute_check) || !isempty(hex_check) || !isempty(custom_attributes_check) || !isempty(changeset_check) || !isempty(global_version_table_check)
      @error "MapImporter - please clean up database before initial load"
    end

  catch err
    @error "MapImporter - cannot query database" exception=(err, catch_backtrace())
  end

  try
    PSQLInterface.execute_psql_string("""GRANT SELECT, INSERT, UPDATE, DELETE ON map_manager.mm_feature TO refresh_materialized_views;""")
    PSQLInterface.execute_psql_string("""GRANT SELECT, INSERT, UPDATE, DELETE ON map_manager.mm_attribute TO refresh_materialized_views;""")
    PSQLInterface.execute_psql_string("""GRANT SELECT, INSERT, UPDATE, DELETE ON map_manager.mm_relationship TO refresh_materialized_views;""")
    PSQLInterface.execute_psql_string("""GRANT SELECT, INSERT, UPDATE, DELETE ON map_manager.mm_derived_feature TO refresh_materialized_views;""")
    PSQLInterface.execute_psql_string("""GRANT SELECT, INSERT, UPDATE, DELETE ON map_manager.mm_derived_attribute TO refresh_materialized_views;""")
    PSQLInterface.execute_psql_string("""GRANT SELECT, INSERT, UPDATE, DELETE ON map_manager.mm_derived_relationship TO refresh_materialized_views;""")

    PSQLInterface.execute_psql_string("""GRANT SELECT, INSERT, UPDATE, DELETE ON map_manager.mm_feature_vicmap_transport_line_mv TO refresh_materialized_views;""")
    PSQLInterface.execute_psql_string("""GRANT SELECT, INSERT, UPDATE, DELETE ON map_manager.mm_feature_osm_line_mv TO refresh_materialized_views;""")
    PSQLInterface.execute_psql_string("""GRANT SELECT, INSERT, UPDATE, DELETE ON map_manager.mm_feature_dtp_osm_line_mv TO refresh_materialized_views;""")
    PSQLInterface.execute_psql_string("""GRANT SELECT, INSERT, UPDATE, DELETE ON map_manager.mm_derived_relationship_vicmap_transport_mv TO refresh_materialized_views;""")

    PSQLInterface.execute_psql_string("""ALTER TABLE map_manager.mm_feature_osm_line_mv OWNER TO refresh_materialized_views;""")
    PSQLInterface.execute_psql_string("""ALTER TABLE map_manager.mm_feature_dtp_osm_line_mv OWNER TO refresh_materialized_views;""")
    PSQLInterface.execute_psql_string("""ALTER TABLE map_manager.mm_feature_vicmap_transport_line_mv OWNER TO refresh_materialized_views;""")
    PSQLInterface.execute_psql_string("""ALTER TABLE map_manager.mm_derived_relationship_vicmap_transport_mv OWNER TO refresh_materialized_views;""")
  catch priviledgeErr
    @error "MapImporter - cannot grant table privileges" exception=(priviledgeErr, catch_backtrace())
  end

end

function truncate_tables_before_initial_load()
  PSQLInterface.execute_psql_string("""truncate table map_manager.mm_layer cascade""")
  PSQLInterface.execute_psql_string("""truncate table map_manager.mm_hex""")
  PSQLInterface.execute_psql_string("""truncate table map_manager.mm_match_report""")
  @info "Tables are truncated successfully"
end

"""
inherit_csf_attributes_as_dtp_attributes()

This function uses the mapmatching results for a source layer to create new DTP attributes that inherit from the source layer attributes
For every DTP way that matched to a source feature, it will taking the existing attributes for that source feature and make them DTP attributes.
Therefore, after the custom seed file is loaded, it must undergo mapmatching for this function to work. 
"""
function inherit_csf_attributes_as_dtp_attributes()
  drop_statement = """
  DROP TABLE IF EXISTS TransformedAttributes;
  """
  transform_statement = """
  WITH MatchedAttributes AS (
  SELECT
    r.feature_id_input,
    r.feature_id_matched,
    a.attribute_id,
    a.s_name,
    a.s_value,
    r.changeset_id,
    a.global_version_id_start
  FROM map_manager.mm_derived_relationship r
  JOIN map_manager.mm_attribute a ON r.feature_id_input = a.feature_id
  WHERE r.layer_id = 'CUSTOM_SEED_FILE' AND r.b_is_latest = TRUE 
  ), 
  TransformedAttributes AS (
  SELECT
    CONCAT(matched_feature, '&&', ma.s_name) AS attribute_id,
    matched_feature AS feature_id,
    ma.s_name,
    ma.s_value,
    ma.changeset_id,
    ma.global_version_id_start
  FROM MatchedAttributes ma
  CROSS JOIN UNNEST(ma.feature_id_matched) AS matched_feature
  )
  INSERT INTO map_manager.mm_derived_attribute (attribute_id, feature_id, s_name, s_value, changeset_id, global_version_id_start)
  SELECT attribute_id, feature_id, s_name, s_value, changeset_id, global_version_id_start
  FROM TransformedAttributes
  ON CONFLICT DO NOTHING;"""

  @info "Beginning Custom Seed File Inheritance Process..."
  PSQLInterface.execute_psql_string(drop_statement)
  PSQLInterface.execute_psql_string(transform_statement)
  @info "Custom Attribute Inheritance complete."
end


"""
delete_custom_seed_file_relationships()

This function deletes all historical relationships between CSF and DTP_OSM after it has been used to create
DTP Custom Attributes. This will free up space in the database and improve performance. We retain one set of relationships
for validation purposes. 
"""
function delete_custom_seed_file_relationships()

  delete_relationships_statement = """
  DELETE FROM map_manager.mm_derived_relationship where layer_id = 'CUSTOM_SEED_FILE' and b_is_latest = false;
  """
  PSQLInterface.execute_psql_string(delete_relationships_statement)
end


"""
inherit_csf_attributes_as_dtp_attributes_ufi_method()

[DEPRECATED] This function uses the mapmatching results for a source layer to create new DTP attributes that inherit from the source layer attributes
For every DTP way that matched to a source feature, it will taking the existing attributes for that source feature and make them DTP attributes.
Therefore, after the custom seed file is loaded, it must undergo mapmatching for this function to work. 
"""
function inherit_csf_attributes_as_dtp_attributes_ufi_method()
  drop_indexes = [
  "drop index if exists map_manager.mm_derived_attribute_attribute_id_idx;"
  "drop index if exists map_manager.mm_derived_attribute_feature_id_idx;"
  "drop index if exists map_manager.mm_derived_attribute_s_name_idx;"
  "drop index if exists map_manager.mm_derived_attribute_changeset_id_idx;"
  "drop index if exists map_manager.mm_derived_attribute_global_version_id_start_idx;"
  "drop index if exists map_manager.mm_derived_attribute_global_version_id_end_idx;"
  ]
  mapping_staging_table = """
  CREATE TABLE vmt_csf_mapping_temp AS (
    SELECT 
        av.feature_id AS vmt_feature_id,
        ac.feature_id AS csf_feature_id
    FROM 
        map_manager.mm_attribute av 
    JOIN 
        map_manager.mm_attribute ac ON av.s_value = ac.s_value 
    WHERE 
        av.feature_id LIKE 'VICMAP_TRANSPORT&&%' 
        AND av.s_name = 'ufi' 
        AND av.b_is_latest = true
        AND ac.feature_id LIKE 'CUSTOM_SEED_FILE%'
        AND ac.s_name = 'UFI' 
        AND ac.b_is_latest
  );
  """
  csf_relationships_staging_table = """
  CREATE TABLE csf_relationships_temp AS (
    SELECT 
        vc.csf_feature_id,
        r.feature_id_matched, 
        r.changeset_id,
        r.global_version_id_start
    FROM 
        vmt_csf_mapping_temp vc
    JOIN 
        map_manager.mm_derived_relationship r ON vc.vmt_feature_id = r.feature_id_input
    WHERE 
        r.b_is_latest AND r.layer_id = 'VICMAP_TRANSPORT'
  );
  """
  matched_attributes_staging_table = """
  CREATE TABLE matched_attributes_temp AS (
    SELECT
        csf.csf_feature_id,
        csf.feature_id_matched,
        csf.changeset_id,
        csf.global_version_id_start,
        a.s_name,
        a.s_value
    FROM 
        csf_relationships_temp csf
    JOIN 
        map_manager.mm_attribute a ON csf.csf_feature_id = a.feature_id
    WHERE 
        a.b_is_latest
  );
  """
  transformed_attributes_staging_table = """
  CREATE TABLE transformed_attributes_temp AS (
    SELECT
        CONCAT(matched_feature, '&&', ma.s_name) AS attribute_id,
        matched_feature AS feature_id,
        ma.s_name,
        ma.s_value,
        ma.changeset_id,
        ma.global_version_id_start
    FROM 
        matched_attributes_temp ma
    CROSS JOIN 
        UNNEST(ma.feature_id_matched) AS matched_feature
  );
  """
  remove_duplicates = """
  CREATE TABLE transformed_attributes_temp_unique AS
  SELECT DISTINCT ON (attribute_id, changeset_id)
      attribute_id, 
      feature_id, 
      s_name, 
      s_value, 
      changeset_id, 
      global_version_id_start
  FROM transformed_attributes_temp
  ORDER BY attribute_id, changeset_id;
  """
  insert_statement = """
  INSERT INTO map_manager.mm_derived_attribute (attribute_id, feature_id, s_name, s_value, changeset_id, global_version_id_start)
  SELECT 
      attribute_id, 
      feature_id, 
      s_name, 
      s_value, 
      changeset_id, 
      global_version_id_start
  FROM 
      transformed_attributes_temp_unique
  ON CONFLICT DO NOTHING;
  """
  drop_staging_tables = [
  "DROP TABLE IF EXISTS vmt_csf_mapping_temp;"
  "DROP TABLE IF EXISTS csf_relationships_temp;"
  "DROP TABLE IF EXISTS matched_attributes_temp;"
  "DROP TABLE IF EXISTS transformed_attributes_temp;"
  "DROP TABLE IF EXISTS transformed_attributes_temp_unique;"
  ]
  recreate_indexes = [
    "CREATE INDEX mm_derived_attribute_attribute_id_idx ON map_manager.mm_derived_attribute USING btree (attribute_id);"
    "CREATE INDEX mm_derived_attribute_feature_id_idx ON map_manager.mm_derived_attribute USING btree (feature_id);"
    "CREATE INDEX mm_derived_attribute_s_name_idx ON map_manager.mm_derived_attribute USING btree (s_name);"
    "CREATE INDEX mm_derived_attribute_global_version_id_start_idx ON map_manager.mm_derived_attribute USING btree (global_version_id_start);"
    "CREATE INDEX mm_derived_attribute_global_version_id_end_idx ON map_manager.mm_derived_attribute USING btree (global_version_id_end);"
    "CREATE INDEX mm_derived_attribute_changeset_id_idx ON map_manager.mm_derived_attribute USING btree (changeset_id);"
  ]
  @info "Beginning Custom Seed File Inheritance Process..."
  for command in drop_indexes
    PSQLInterface.execute_psql_string(command)
  end
  @info "Dropped indexes for Derived Attributes Table. Beginning attribute inheritance..."
  for command in drop_staging_tables
    PSQLInterface.execute_psql_string(command)
  end
  PSQLInterface.execute_psql_string(mapping_staging_table)
  PSQLInterface.execute_psql_string(csf_relationships_staging_table)
  PSQLInterface.execute_psql_string(matched_attributes_staging_table)
  PSQLInterface.execute_psql_string(transformed_attributes_staging_table)
  @info "Transformed Attributes. Removing duplicates..."
  PSQLInterface.execute_psql_string(remove_duplicates)
  @info "Duplicates Removed. Beginning insert to table..."
  PSQLInterface.execute_psql_string(insert_statement)
  @info "Insert finished. Dropping temp tables..."
  for command in drop_staging_tables
    PSQLInterface.execute_psql_string(command)
  end
  @info "Attribute inheritance complete. Beginning recreation of indexes..."
  for command in recreate_indexes
    PSQLInterface.execute_psql_string(command)
  end
  @info "Custom Attribute Inheritance complete."
end