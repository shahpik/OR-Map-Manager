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


"""
validate_changeset(upper_case_source_name)

This function validates the creation of a new change_set for a specified source layer by checking whether there is already a pending/in-progress
changeset associated with this source_layer. It does this by querying the map_manager.mm_changeset table and will return an HTTP500 error if 
there is an existing changeset for this layer which is not in the APPROVED/DECLINED status. 
If not, it will return null to indicate that there is no blocking change_set_id. 
"""
function validate_changeset(layerID::String)
    uppercaseSN = uppercase(layerID)
    check_query = PSQLInterface.execute_psql_string(
    """
    WITH current_changeset_id AS (
        SELECT max(dt_last_opened) AS newest_changeset_dt
        FROM map_manager.mm_changeset
        WHERE layer_id = '$uppercaseSN' AND e_changeset_status NOT IN ('APPROVED', 'DECLINED')
    ) 
    SELECT 
    CASE 
        WHEN (SELECT newest_changeset_dt FROM current_changeset_id) IS NULL THEN 'EMPTY'
        ELSE (SELECT changeset_id FROM map_manager.mm_changeset, current_changeset_id
        WHERE dt_last_opened = (SELECT newest_changeset_dt FROM current_changeset_id) and layer_id = '$uppercaseSN')
    END AS result;
    """
    ) 
    return DataFrame(check_query)[1,1]
end


"""
    create_changeset(sourceName, userName, changesetDescription)
    This function creates a new changeset row in the database by executing a SQL command. It takes in a sourceName, and if the 
    changeset type is a user edit, it will also take in a userName and changesetDescription. 
    changeset_id is a randomly generated UUID string, layer_id is the uppercase source name, e_changeset_edit_type can be 'SOURCE',
    'ATTRIBUTE' or 'RELATIONSHIP' depending
"""
function create_changeset(sourceName::String; userName = "Source data"::String, e_changeset_edit_type)
    # WRITE a blocking check that will only allow a changeset to be created if there isn't an existing pending changeset for a given layer
    # E.g. select from mm_changeset all that are VICMAP_TRANSPORT and not APPROVED - if the length of this list > 0 then don't allow creation
    # Throw an error that says that it can't be created until changeset ID *** has been approved or declined. 
    uppercaseSN = uppercase(string(sourceName))
    changeset_id = string(UUIDs.uuid4())

    select_statement = """
    WITH latest_changeset as (
      select mm_global_version.changeset_id
      from map_manager.mm_global_version
        left join map_manager.mm_changeset 
        on mm_global_version.changeset_id = mm_changeset.changeset_id
      where mm_changeset.layer_id = '$uppercaseSN'
      order by global_version_id DESC
      LIMIT 1
    ), latest_s_layer_version as (
        select (
          case when '$e_changeset_edit_type' != 'SOURCE' then
            (split_part(mm_changeset.s_layer_version, '.', 1)::integer)::text || '.' || (1 + split_part(mm_changeset.s_layer_version, '.', 2)::integer)::text
          else
            (1 + split_part(mm_changeset.s_layer_version, '.', 1)::integer)::text || '.0'
          end
        ) as update_version
        from map_manager.mm_changeset, latest_changeset
        where mm_changeset.changeset_id = latest_changeset.changeset_id
      ), get_update_version as (
        select (
          case when (select count(*) from latest_s_layer_version) = 0 then '1.0'
          else 
            (select latest_s_layer_version.update_version from latest_s_layer_version)
          end
        ) as update_version
      ) 
    INSERT INTO map_manager.mm_changeset (
      changeset_id,
      layer_id,
      e_changeset_edit_type,
      s_layer_version,
      user_name,
      dt_last_opened,
      e_changeset_status
    )
    SELECT '$changeset_id',
    '$uppercaseSN',
    '$e_changeset_edit_type',
    update_version,
    '$userName',
    floor(extract(EPOCH from NOW()))::integer,
    case when '$e_changeset_edit_type' != 'SOURCE' then 'IN_PROGRESS' else 'PROCESSING' end
  FROM get_update_version; 
    """
    PSQLInterface.execute_psql_string(select_statement)
    
    changeset_id = PSQLInterface.execute_psql_string(
        """ 
        SELECT changeset_id AS cs_id
        FROM map_manager.mm_changeset
        WHERE dt_last_opened = (
        SELECT MAX(dt_last_opened)
        FROM map_manager.mm_changeset)
        """
    )
    changeset_id_string = DataFrame(changeset_id)[1,1]
    changeset_json = JSON3.write(Dict("changeset_id" => changeset_id_string))
    @info "Created new change_set $changeset_id_string"
    println(changeset_json)
    return changeset_json
end

"""
reject_edit(changeset_id, rejected_feature_ids)

This function takes in a changeset_id and list of feature_ids to reject. It queries the mm_feature 
database and marks all listed features as rejected. 
"""
function reject_edit(changeset_id::String, rejected_feature_ids)

    items = join(["\$$n" for n in 2:(length(rejected_feature_ids)+1)], ", ")
    println(items)
    result = PSQLInterface.execute_psql_string("""
    update map_manager.mm_feature 
    set b_user_rejected = TRUE
    where (changeset_id = \$1 or association_changeset_id = \$1)
    and feature_id in ($items);
    """, parameters = [changeset_id, rejected_feature_ids...]) 
    @info "Successfully rejected features from changeset: $changeset_id"
    PSQLInterface.execute_psql_string("""refresh materialized view map_manager.mm_feature_osm_line_mv;""")
    changeset_json = JSON3.write(Dict("changeset_id" => changeset_id))
    return changeset_json
end

"""
restore_edit(changeset_id, restored_feature_ids)

This function takes in a changeset_id and list of feature_ids to reject. It queries the mm_feature 
database and marks all listed features as rejected. 
"""
function restore_edit(changeset_id::String, restored_feature_ids)

    items = join(["\$$n" for n in 2:(length(restored_feature_ids)+1)], ", ")
    println(items)
    result = PSQLInterface.execute_psql_string("""
    update map_manager.mm_feature 
    set b_user_rejected = NULL
    where (changeset_id = \$1 or association_changeset_id = \$1)
    and feature_id in ($items);
    """, parameters = [changeset_id, restored_feature_ids...]) 
    @info "Successfully restored features from changeset: $changeset_id"
    PSQLInterface.execute_psql_string("""refresh materialized view map_manager.mm_feature_osm_line_mv;""")
    changeset_json = JSON3.write(Dict("changeset_id" => changeset_id))
    return changeset_json
end

"""

"""
function upsert_attribute(changeset_id::String, attributeParams)
    changeset_id = "$changeset_id"

    attribute_id = attributeParams.attribute_id
    feature_id = attributeParams.feature_id
    s_name = attributeParams.s_name
    s_value = attributeParams.s_value
    upsert_statement = """
    create temporary table if not exists stg_attribute_upsert as
    

    insert into map_manager.mm_attribute(attribute_id, feature_id, s_name, s_value, global_version_id_start, global_version_id_end, b_user_edit, changeset_id)
    select $attribute_id, $feature_id, $s_name, $s_value, null, null, true, $changeset_id
    from map_manager.stg_mm_attribute
    on conflict (join_key)
    do nothing;
    """
    # TWO conditions: 1) is that if the attribute has already been edited/added in this changeset, only update
    # 2) is that if the attribute doesn't exist yet, add, if it does modify
    PSQLInterface.execute_psql_string(upsert_statement, parameters[attribute_id, ])
end

# function upsert_relationship()

# end

# function delete_relationship()

# end

function publish_user_edits(changeset_id::String)
    changeset_id = "$changeset_id"
    select_statement = """

    --STEP 1: Update global_version_id = global_version_id + 1
    
    WITH current_global_id AS (
      SELECT max(global_version_id) AS id
      FROM map_manager.mm_global_version
    )
    insert into map_manager.mm_global_version(global_version_id, dt_merged)
    select id + 1, CURRENT_DATE
    from current_global_id;
    
    --FEATURES----------------------------------------------------------------------------------------------------------------------------------------------------------
    
    --STEP 2: Update old values by altering global_version_id_end
    
    --Modifications update old rows to be historical by adding a global_version_id_end
    
    with current_global_id as (
      select max(global_version_id) - 1 as id
      from map_manager.mm_global_version
    )
    update map_manager.mm_feature
    set global_version_id_end = id, changeset_id = $changeset_id from current_global_id
    where feature_id in (select feature_id from map_manager.temp_feature_changes where feature_change = 'MODIFICATION') and global_version_id_start notnull;
    
    --Modifications update new rows to be current by changing global_version_id_start
    
    with current_global_id as (
      select max(global_version_id) as id
      from map_manager.mm_global_version
    )
    update map_manager.mm_feature
    set global_version_id_start = id from current_global_id
    where feature_id in (select feature_id from map_manager.temp_feature_changes where feature_change = 'MODIFICATION') and global_version_id_start is null;
    

    --Additions update new rows to be current by changing global_version_id_start
    
    with current_global_id as (
      select max(global_version_id) as id
      from map_manager.mm_global_version
    )
    update map_manager.mm_feature
    set global_version_id_start = id from current_global_id
    where feature_id in (select feature_id from map_manager.temp_feature_changes where feature_change = 'ADDITION');
    
    --Deletions update old rows to be historical by adding a global_version_id_end
    
    with current_global_id as (
      select max(global_version_id) - 1 as id
      from map_manager.mm_global_version
    )
    update map_manager.mm_feature
    set global_version_id_end = id, changeset_id = $changeset_id from current_global_id
    where feature_id in (select feature_id from map_manager.temp_feature_changes where feature_change = 'DELETION') and is_current = true;

    --Delete feature change table (this is created anew each time)
    drop table map_manager.temp_feature_changes;

    --Update changeset_id to 'APPROVED' and assign a global_version_id
    with current_global_id as (
        select max(global_version_id) as id
        from map_manager.mm_global_version
      )
    update map_manager.mm_changeset
    set global_version_id = id, e_changeset_status = 'MERGED' 
    from current_global_id
    where changeset_id = $changeset_id;
    """
    # Perform the select statement and convert result to a dataframe
    PSQLInterface.execute_psql_string(select_statement)
    @info "Successfully published $changeset_id"
    return nothing
end

function source_update_initial_load(changeset_id::String)
    # Define an SQL select statement to retrieve geom_feature and feature_id
    # Add query to check version of match "select n_version from map_manager.mm_match_report wwhere layer_id = '"
    # Add the '' signs here for SQLs benefit
    changeset_id = "'$changeset_id'"
    select_statement = """
    --FEATURES------------------------------------------------------------------------------------------
    
    --STEP 1a: Assemble temporary table of just current rows in main table (is_current = true) 


    drop table if exists tmp_current_feature_table;
    create temporary table tmp_current_feature_table as
    select *
    from map_manager.mm_feature
    where is_current = true;

    --STEP 3: FULL DELTA 
    
    -- Assemble full list of differences between stg_mm_feature and mm_feature using an outer join
    
    drop table if exists full_change_list;
    create temporary table full_change_list as
    select 	stg_mm_feature.feature_id as stg_feature_id, 
            stg_mm_feature.s_name as stg_s_name, 
            stg_mm_feature.join_key as stg_join_key, 
            stg_mm_feature.global_version_id_start as stg_global_version_id_start, 
            stg_mm_feature.global_version_id_end as stg_global_version_id_end, 
            tmp_current_feature_table.feature_id as current_feature_id, 
            tmp_current_feature_table.s_name as current_s_name, 
            tmp_current_feature_table.join_key as current_join_key, 
            tmp_current_feature_table.global_version_id_start as current_global_version_id_start, 
            tmp_current_feature_table.global_version_id_end as current_global_version_id_end
    from map_manager.stg_mm_feature
    full outer join tmp_current_feature_table
        on stg_mm_feature.join_key = tmp_current_feature_table.join_key
    where (stg_mm_feature.join_key is null or tmp_current_feature_table.join_key is null);
    
    --STEP 4: CHANGE TABLES
    
    --Additions
    drop table if exists additions;
    create temporary table additions as (
    select stg_mm_feature.feature_id as stg_feature_id, 
            stg_mm_feature.s_name as stg_s_name, 
            stg_mm_feature.join_key as stg_join_key, 
            stg_mm_feature.global_version_id_start as stg_global_version_id_start, 
            stg_mm_feature.global_version_id_end as stg_global_version_id_end, 
            tmp_current_feature_table.feature_id as current_feature_id, 
            tmp_current_feature_table.s_name as current_s_name, 
            tmp_current_feature_table.join_key as current_join_key, 
            tmp_current_feature_table.global_version_id_start as current_global_version_id_start, 
            tmp_current_feature_table.global_version_id_end as current_global_version_id_end
    from tmp_current_feature_table
    right join map_manager.stg_mm_feature
        on tmp_current_feature_table.feature_id = stg_mm_feature.feature_id
    where tmp_current_feature_table.feature_id is null);
    
    --Deletions
    
    drop table if exists deletions;
    create temporary table deletions as (
    select stg_mm_feature.feature_id as stg_feature_id, 
            stg_mm_feature.s_name as stg_s_name, 
            stg_mm_feature.join_key as stg_join_key, 
            stg_mm_feature.global_version_id_start as stg_global_version_id_start, 
            stg_mm_feature.global_version_id_end as stg_global_version_id_end, 
            tmp_current_feature_table.feature_id as current_feature_id, 
            tmp_current_feature_table.s_name as current_s_name, 
            tmp_current_feature_table.join_key as current_join_key, 
            tmp_current_feature_table.global_version_id_start as current_global_version_id_start, 
            tmp_current_feature_table.global_version_id_end as current_global_version_id_end
    from map_manager.stg_mm_feature
    right join tmp_current_feature_table
        on stg_mm_feature.feature_id = tmp_current_feature_table.feature_id
    where stg_mm_feature.feature_id is null);
    
    --Modifications
    
    drop table if exists modifications;
    create temporary table modifications as
    select * from full_change_list except (select * from deletions)
    intersect
    select * from full_change_list except (select * from additions);
    
    
    --STEP 5: ADD ROWS - add new rows for additions and modifications
    
    --Modifications new rows
    
    insert into map_manager.mm_feature(feature_id, layer_id, s_name, s_source_id, e_feature_type, geom_feature, ar_n_hex_index, global_version_id_start, global_version_id_end, changeset_id)
    select feature_id, layer_id, s_name, s_source_id, e_feature_type, geom_feature, ar_n_hex_index, NULL, global_version_id_end, $changeset_id
    from map_manager.stg_mm_feature
    where feature_id in (select stg_feature_id from modifications);
    
    --Additions new rows
    
    insert into map_manager.mm_feature(feature_id, layer_id, s_name, e_feature_type, s_source_id, geom_feature, ar_n_hex_index, global_version_id_start, global_version_id_end, changeset_id)
    select feature_id, layer_id, s_name, e_feature_type, s_source_id, geom_feature, ar_n_hex_index, NULL, global_version_id_end, $changeset_id
    from map_manager.stg_mm_feature
    where feature_id in (select stg_feature_id from additions);

    --Additions to temporary 'changes' table so that we can save between SQL queries
    drop table if exists map_manager.temp_feature_changes;
    create table if not exists map_manager.temp_feature_changes (
        feature_id text, 
        feature_change text
    ); 
    insert into map_manager.temp_feature_changes(feature_id, feature_change)
    select stg_feature_id, 'ADDITION'
    from additions;
    insert into map_manager.temp_feature_changes(feature_id, feature_change)
    select current_feature_id, 'DELETION'
    from deletions;
    insert into map_manager.temp_feature_changes(feature_id, feature_change)
    select stg_feature_id, 'MODIFICATION'
    from modifications
    where stg_feature_id notnull;

    --ATTRIBUTES------------------------------------------------------------------------------------------
    --STEP 1: Assemble temporary table of just current rows in main table (is_current = true) 

    drop table if exists tmp_current_attribute_table;
    create temporary table if not exists tmp_current_attribute_table as
    select *
    from map_manager.mm_attribute
    where is_current = true;

    --STEP 2: FULL DELTA 
    
    -- Assemble full list of differences between stg_mm_feature and mm_feature using an outer join
    
    drop table if exists full_attribute_change_list;
        create temporary table full_attribute_change_list as
        select 	stg_mm_attribute.attribute_id as stg_attribute_id, 
                stg_mm_attribute.s_name as stg_s_name, 
                stg_mm_attribute.s_value as stg_s_value,
                stg_mm_attribute.join_key as stg_join_key, 
                stg_mm_attribute.global_version_id_start as stg_global_version_id_start, 
                stg_mm_attribute.global_version_id_end as stg_global_version_id_end, 
                tmp_current_attribute_table.attribute_id as current_attribute_id, 
                tmp_current_attribute_table.s_name as current_s_name, 
                tmp_current_attribute_table.s_value as current_s_value,
                tmp_current_attribute_table.join_key as current_join_key, 
                tmp_current_attribute_table.global_version_id_start as current_global_version_id_start, 
                tmp_current_attribute_table.global_version_id_end as current_global_version_id_end
        from map_manager.stg_mm_attribute
        full outer join tmp_current_attribute_table
            on stg_mm_attribute.join_key = tmp_current_attribute_table.join_key
        where (stg_mm_attribute.join_key is null or tmp_current_attribute_table.join_key is null);
        
    --STEP 3: CHANGE TABLES
    
    --Additions

    drop table if exists additions;
    create temporary table additions as 
    select stg_mm_attribute.attribute_id as stg_attribute_id, 
            stg_mm_attribute.s_name as stg_s_name, 
            stg_mm_attribute.s_value as stg_s_value, 
            stg_mm_attribute.join_key as stg_join_key, 
            stg_mm_attribute.global_version_id_start as stg_global_version_id_start, 
            stg_mm_attribute.global_version_id_end as stg_global_version_id_end, 
            tmp_current_attribute_table.attribute_id as current_attribute_id, 
            tmp_current_attribute_table.s_name as current_s_name, 
            tmp_current_attribute_table.s_value as current_s_value,
            tmp_current_attribute_table.join_key as current_join_key, 
            tmp_current_attribute_table.global_version_id_start as current_global_version_id_start, 
            tmp_current_attribute_table.global_version_id_end as current_global_version_id_end
    from tmp_current_attribute_table
    right join map_manager.stg_mm_attribute
        on tmp_current_attribute_table.attribute_id = stg_mm_attribute.attribute_id
    where tmp_current_attribute_table.attribute_id is null;
    
    --Deletions
    
    drop table if exists deletions;
    create temporary table deletions as (
    select stg_mm_attribute.attribute_id as stg_attribute_id, 
            stg_mm_attribute.s_name as stg_s_name,
            stg_mm_attribute.s_value as stg_s_value, 
            stg_mm_attribute.join_key as stg_join_key, 
            stg_mm_attribute.global_version_id_start as stg_global_version_id_start, 
            stg_mm_attribute.global_version_id_end as stg_global_version_id_end, 
            tmp_current_attribute_table.attribute_id as current_attribute_id, 
            tmp_current_attribute_table.s_name as current_s_name, 
            tmp_current_attribute_table.s_value as current_s_value, 
            tmp_current_attribute_table.join_key as current_join_key, 
            tmp_current_attribute_table.global_version_id_start as current_global_version_id_start, 
            tmp_current_attribute_table.global_version_id_end as current_global_version_id_end
    from map_manager.stg_mm_attribute
    right join tmp_current_attribute_table
        on stg_mm_attribute.attribute_id = tmp_current_attribute_table.attribute_id
    where stg_mm_attribute.attribute_id is null);
    
    
    --Modifications
    
    drop table if exists modifications;
    create temporary table modifications as
    select * from full_attribute_change_list except (select * from deletions)
    intersect
    select * from full_attribute_change_list except (select * from additions);


    --STEP 4: ADD ROWS - add new rows for additions and modifications
    
    --Modifications new rows
    
    insert into map_manager.mm_attribute(attribute_id, feature_id, s_name, s_value, global_version_id_start, global_version_id_end, b_user_edit, changeset_id)
    select attribute_id, feature_id, s_name, s_value, null, null, b_user_edit, $changeset_id
    from map_manager.stg_mm_attribute
    where attribute_id in (select stg_attribute_id from modifications);

    --Additions new rows

    insert into map_manager.mm_attribute(attribute_id, feature_id, s_name, s_value, global_version_id_start, global_version_id_end, b_user_edit, changeset_id)
    select attribute_id,feature_id, s_name, s_value, null, null, b_user_edit, $changeset_id
    from map_manager.stg_mm_attribute
    where attribute_id in (select stg_attribute_id from additions);

    --Additions to temporary 'changes' table so that we can save between SQL queries

    drop table if exists map_manager.temp_attribute_changes;
    create table if not exists map_manager.temp_attribute_changes (
        attribute_id text, 
        attribute_change text
    ); 
    
    insert into map_manager.temp_attribute_changes(attribute_id, attribute_change)
    select stg_attribute_id, 'ADDITION'
    from additions;
    insert into map_manager.temp_attribute_changes(attribute_id, attribute_change)
    select current_attribute_id, 'DELETION'
    from deletions;
    insert into map_manager.temp_attribute_changes(attribute_id, attribute_change)
    select stg_attribute_id, 'MODIFICATION'
    from modifications
    where stg_attribute_id notnull;    
    """
    # Perform the select statement and convert result to a dataframe
    PSQLInterface.execute_psql_string(select_statement)
    @info "Completed initial load into database - awaiting approval"
    return changeset_id
end


function source_update_merge(changeset_id::String)
    # Define an SQL select statement to update all global_version_ids so that the new source layer update becomes current, and the old values become historical
    changeset_id = "$changeset_id"
    select_statement = """

    --STEP 1: Update global_version_id = global_version_id + 1
    
    WITH current_global_id AS (
      SELECT max(global_version_id) AS id
      FROM map_manager.mm_global_version
    )
    insert into map_manager.mm_global_version(global_version_id, dt_merged)
    select id + 1, CURRENT_DATE
    from current_global_id;
    
    --FEATURES----------------------------------------------------------------------------------------------------------------------------------------------------------
    
    --STEP 2: Update old values by altering global_version_id_end
    
    --Modifications update old rows to be historical by adding a global_version_id_end
    
    with current_global_id as (
      select max(global_version_id) - 1 as id
      from map_manager.mm_global_version
    )
    update map_manager.mm_feature
    set global_version_id_end = id, changeset_id = $changeset_id from current_global_id
    where feature_id in (select feature_id from map_manager.temp_feature_changes where feature_change = 'MODIFICATION') and global_version_id_start notnull;
    
    --Modifications update new rows to be current by changing global_version_id_start
    
    with current_global_id as (
      select max(global_version_id) as id
      from map_manager.mm_global_version
    )
    update map_manager.mm_feature
    set global_version_id_start = id from current_global_id
    where feature_id in (select feature_id from map_manager.temp_feature_changes where feature_change = 'MODIFICATION') and global_version_id_start is null;
    

    --Additions update new rows to be current by changing global_version_id_start
    
    with current_global_id as (
      select max(global_version_id) as id
      from map_manager.mm_global_version
    )
    update map_manager.mm_feature
    set global_version_id_start = id from current_global_id
    where feature_id in (select feature_id from map_manager.temp_feature_changes where feature_change = 'ADDITION');
    
    --Deletions update old rows to be historical by adding a global_version_id_end
    
    with current_global_id as (
      select max(global_version_id) - 1 as id
      from map_manager.mm_global_version
    )
    update map_manager.mm_feature
    set global_version_id_end = id, changeset_id = $changeset_id from current_global_id
    where feature_id in (select feature_id from map_manager.temp_feature_changes where feature_change = 'DELETION') and is_current = true;

    --Delete feature change table (this is created anew each time)
    drop table map_manager.temp_feature_changes;

    --ATTRIBUTES----------------------------------------------------------------------------------------------------------------------------------------------------------
    
    --STEP 2b: Update old values by altering global_version_id_end
    
    --Modifications update old rows to be historical by adding a global_version_id_end
    
    with current_global_id as (
      select max(global_version_id) - 1 as id
      from map_manager.mm_global_version
    )
    update map_manager.mm_attribute
    set global_version_id_end = id, changeset_id = $changeset_id from current_global_id
    where attribute_id in (select attribute_id from map_manager.temp_attribute_changes where attribute_change = 'MODIFICATION') and global_version_id_start notnull;
    
    --Modifications update new rows to be current by changing global_version_id_start
    
    with current_global_id as (
      select max(global_version_id) as id
      from map_manager.mm_global_version
    )
    update map_manager.mm_attribute
    set global_version_id_start = id from current_global_id
    where attribute_id in (select attribute_id from map_manager.temp_attribute_changes where attribute_change = 'MODIFICATION') and global_version_id_start is null;

    --Additions update new rows to be current by changing global_version_id_start
    
    with current_global_id as (
      select max(global_version_id) as id
      from map_manager.mm_global_version
    )
    update map_manager.mm_attribute
    set global_version_id_start = id from current_global_id
    where attribute_id in (select attribute_id from map_manager.temp_attribute_changes where attribute_change = 'ADDITION');
    
    --Deletions update old rows to be historical by adding a global_version_id_end
    
    with current_global_id as (
      select max(global_version_id) - 1 as id
      from map_manager.mm_global_version
    )
    update map_manager.mm_attribute
    set global_version_id_end = id, changeset_id = $changeset_id from current_global_id
    where attribute_id in (select attribute_id from map_manager.temp_attribute_changes where attribute_change = 'DELETION') and is_current = true;

    --Delete attribute change table (this is created anew each time)
    drop table map_manager.temp_attribute_changes;

    --Update changeset_id to 'APPROVED' and assign a global_version_id
    with current_global_id as (
        select max(global_version_id) as id
        from map_manager.mm_global_version
      )
    update map_manager.mm_changeset
    set global_version_id = id, e_changeset_status = 'MERGED' 
    from current_global_id
    where changeset_id = $changeset_id;
    """
    # Perform the select statement and convert result to a dataframe
    PSQLInterface.execute_psql_string(select_statement)
    @info "Successfully merged $changeset_id"
    return nothing
end

function is_changeset_exists(changeset_id::String)
  is_changeset_exists = PSQLInterface.execute_psql_string("""
  SELECT changeset_id from map_manager.mm_changeset where changeset_id = '$changeset_id'
  """
  )
  if isempty(is_changeset_exists)
    @error "changeset does not exist"
    return 500, "Changeset '$changeset_id' does not exist."
  else
    return 200
  end
end

function show_psql_statement(pg_params::PostgreSQLConnectionParams, 
                             psql_string::AbstractString;
                             options=Dict{String, String}(), 
                             parameters::Union{Nothing,AbstractVector,Tuple}=nothing
                             )
    @warn "Executing a PSQL query from a string"
    @debug psql_string
    with_postgresql(pg_params, options) do psql
        Base.show(Base.stdout, psql)
        if isnothing(parameters)
            return execute(psql, psql_string)
        else
            return execute(psql, psql_string, parameters)
        end
    end
end

show_psql_statement(psql_string::AbstractString; kwargs...) = show_psql_statement(global_psql_config(), psql_string; kwargs...)

function edit_relationship(changeset_id::String, input_feature_id::String, matched_feature_ids::Vector{String})

  # Creates a variable sized 'items' which means feature_ids can be any length
  items = join(["\$$n" for n in 1:length(matched_feature_ids)], ", ")

  # Selects a multi-linestring or connected linestring from a list of OSM ways
  # ST_LineMerge will attempt to join linestrings end to end if possible
  select_new_relationship_geom = show_psql_statement(
  """select
    ST_AsGeoJSON(ST_LineMerge(ST_Collect((
    select array_agg(geom_feature)
    from map_manager.mm_derived_feature
    where feature_id in ($(items))
    and b_is_latest  
  ))))""", parameters=matched_feature_ids) 

  if !isempty(select_new_relationship_geom)
    new_relationship_geom = DataFrame(select_new_relationship_geom)[1,1]
  end

  new_relation_json_array = JSON3.read(new_relationship_geom)["coordinates"]
  new_relation_vector = copy(new_relation_json_array)

  # Select the input feature geometry
  select_input_feature_geom = PSQLInterface.execute_psql_string(
    """select ST_AsGeoJSON(geom_feature)
    from map_manager.mm_feature
    where feature_id = \$1
    and b_is_latest;""", 
    parameters=[input_feature_id])
  
  if !isempty(select_input_feature_geom)
    input_feature_geom = DataFrame(select_input_feature_geom)[1,1]
  end
  input_feat_json_array = JSON3.read(input_feature_geom)["coordinates"]
  input_feat_vector = copy(input_feat_json_array)
  println(typeof(input_feat_vector))

  # Using SpatialUtilities, calculate the relationship geometry 
  trimmed_relationship_geom = SpatialUtilities.MapMatching.calculate_return_geom(input_feat_vector, new_relation_vector)
  println("Trimmed relationship data = $trimmed_relationship_geom \n\nand type is $(typeof(trimmed_relationship_geom))\n\n")

  # trimmed_relationship_geom will be a vector{vector{vector{Float64}}} by default
  # Define as either a linestring or multilinestring depending on length
  # Unnest if trimmed_relationship_geom is a linestring
  if length(trimmed_relationship_geom)>1
    type = "MultiLineString"
    trimmed_relationship_geom = Vector{Vector{Float64}}.(trimmed_relationship_geom)
  else
    type = "LineString"
    trimmed_relationship_geom = trimmed_relationship_geom[1]
  end
  # Reformat so that it can be used in parameterisation of SQL queries
  new_rel_geom = "[[" * join(map(x -> join(x, ", "), trimmed_relationship_geom), "], [") * "]]"
  formatted_rel_geom = "{ \"coordinates\": $new_rel_geom, \"type\": \"$type\" }"
  println("\nFormatted = $formatted_rel_geom\n")

  # Calculate error for the new relationship geometry against the input feature geometry
  error = SpatialUtilities.MapMatching.e_polygon_area(trimmed_relationship_geom, input_feat_vector)[1]
  println(error)

  # Find the layer_id for the changeset we are looking at
  determine_layer_id = PSQLInterface.execute_psql_string("""
  SELECT layer_id FROM map_manager.mm_changeset WHERE changeset_id = \$1;
  """, parameters = [changeset_id])
  layer_id = DataFrame(determine_layer_id)[1, 1]

  # Statements to be performed after creating new rows to update fields
  update_join_key_statement = """
  UPDATE map_manager.mm_relationship 
  SET join_key = MD5(
    coalesce(st_astext(geom_relationship), '') || 
    coalesce(f_error_value::text, '') || 
    coalesce(feature_id_input, '') ||
    coalesce(feature_id_matched::text, ''))
  WHERE relationship_id = \$1
  """

  update_feature_status_statement = """
  UPDATE map_manager.mm_feature
  SET e_feature_status = \$1, association_changeset_id = \$2
  WHERE feature_id = \$3 AND b_is_latest = \$4
  """

  # Check first if relationship is already on the changeset 
  is_relationship_on_changeset = PSQLInterface.execute_psql_string("""
  SELECT relationship_id from map_manager.mm_derived_relationship 
  WHERE feature_id_input = '$input_feature_id' and changeset_id = '$changeset_id'
  """
  )

  # If it is, then we only need to update 
  if !isempty(is_relationship_on_changeset)
    relationship_id = DataFrame(is_relationship_on_changeset)[1,1]
    update_matched_features_statement = """
    UPDATE map_manager.mm_derived_relationship
    SET geom_relationship = ST_GeomFromGeoJSON(\$1), f_error_value = \$2, feature_id_matched = \$3, layer_id = \$4, b_user_edit = true
    WHERE relationship_id = \$5 AND changeset_id = \$6
    """ 
    PSQLInterface.execute_psql_string(update_matched_features_statement, parameters=[formatted_rel_geom, error, matched_feature_ids, layer_id, relationship_id, changeset_id])
    relationship_json = JSON3.write(Dict("relationship_id" => relationship_id))
    return relationship_json
  end

  # Check whether the relationship already exists in the database
  is_relationship_existing = PSQLInterface.execute_psql_string("""
  SELECT relationship_id from map_manager.mm_derived_relationship 
  WHERE feature_id_input = '$input_feature_id'
  """)

  # If we are creating an entirely new relationship, we need to create a new relationship_id
  if isempty(is_relationship_existing)
    relationship_id = "MANUAL_RELATIONSHIP_EDIT&&$input_feature_id"
    insert_non_existing_relationship_statement = """
    INSERT INTO map_manager.mm_derived_relationship (
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
    SELECT \$1,
    \$2,
    ST_GeomFromGeoJSON(\$3),
    NULL,
    NULL,
    \$4,
    \$5,
    \$6,
    \$7,
    NULL,
    NULL,
    \$8,
    \$9
    """
    PSQLInterface.execute_psql_string(insert_non_existing_relationship_statement, parameters=[relationship_id, "MANUAL", formatted_rel_geom, error, input_feature_id, matched_feature_ids, layer_id, changeset_id, true])
    PSQLInterface.execute_psql_string(update_feature_status_statement, parameters=["MODIFIED", changeset_id, input_feature_id, true])
    relationship_json = JSON3.write(Dict("relationship_id" => relationship_id))
    return relationship_json
  end
  
  # It's possible the relationship is outdated and no longer in use. Check whether there is a current version of the relationship. 
  is_relationship_on_latest_version = PSQLInterface.execute_psql_string("""
  SELECT relationship_id FROM map_manager.mm_derived_relationship WHERE feature_id_input = '$input_feature_id' AND changeset_id != '$changeset_id' AND b_is_latest = true
  """)
  relationship_id = DataFrame(is_relationship_on_latest_version)[1, 1]

  # If there is a current version of the relationship, we will add the new version as another row
  if !isempty(relationship_id)
    insert_relationship_statement = """
    INSERT INTO map_manager.mm_derived_relationship (
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
    SELECT \$1,
    \$2,
    ST_GeomFromGeoJSON(\$3),
    NULL,
    NULL,
    \$4,
    \$5,
    \$6,
    \$7,
    NULL,
    NULL,
    \$8,
    \$9
    """

    PSQLInterface.execute_psql_string(insert_relationship_statement, parameters=[relationship_id, "MANUAL", formatted_rel_geom, error, input_feature_id, matched_feature_ids, layer_id, changeset_id, true])    
    PSQLInterface.execute_psql_string(update_feature_status_statement, parameters=["MODIFIED", changeset_id, input_feature_id, true])
    relationship_json = JSON3.write(Dict("relationship_id" => relationship_id))
    return relationship_json
  end
end

function edit_attributes(changeset_id::String, feature_id::String, s_name::String, s_value::String)

  update_join_key_statement = """
  UPDATE map_manager.mm_attribute
  SET join_key = MD5(
    coalesce(feature_id, '') ||
    coalesce(s_name, '') ||
    coalesce(s_value, ''))
  WHERE attribute_id = \$1
  """

  update_feature_status_statement = """
  UPDATE map_manager.mm_derived_feature
  SET e_feature_status = \$1, association_changeset_id = \$2
  WHERE feature_id = \$3 AND b_is_latest = \$4
  """

  is_attribute_on_changeset = PSQLInterface.execute_psql_string("""
  SELECT attribute_id from map_manager.mm_derived_attribute
  WHERE changeset_id = '$changeset_id' AND feature_id = '$feature_id' AND s_name = '$s_name'
  """)

  if !isempty(is_attribute_on_changeset)
    attribute_id = DataFrame(is_attribute_on_changeset)[1,1]

    update_attribute_statement = """
    UPDATE map_manager.mm_derived_attribute
    SET s_value = \$1
    WHERE attribute_id = \$2 AND changeset_id = \$3 AND s_name = \$4
    """

    PSQLInterface.execute_psql_string(update_attribute_statement, parameters=[s_value, attribute_id, changeset_id, s_name])
    return attribute_id
  end

  is_attribute_on_latest_version = PSQLInterface.execute_psql_string("""
  SELECT attribute_id FROM map_manager.mm_derived_attribute WHERE feature_id = '$feature_id' 
  AND s_name = '$s_name' 
  AND b_is_latest = true
  AND changeset_id != '$changeset_id'
  """)

  if !isempty(is_attribute_on_latest_version)
    attribute_id = DataFrame(is_attribute_on_latest_version)[1, 1]

    insert_attribute_statement = """
    INSERT INTO map_manager.mm_derived_attribute (
      attribute_id,
      feature_id, 
      s_name,
      s_value,
      changeset_id,
      global_version_id_start,
      global_version_id_end,
      b_user_edit
    )
    SELECT \$1,
    \$2,
    \$3,
    \$4,
    \$5,
    NULL,
    NULL,
    \$6
    """

    PSQLInterface.execute_psql_string(insert_attribute_statement, parameters=[attribute_id, feature_id, s_name, s_value, changeset_id, true])
    PSQLInterface.execute_psql_string(update_feature_status_statement, parameters=["MODIFIED", changeset_id, feature_id, true])
    return attribute_id
  end

  get_distinct_custom_attributes_statement = """
  SELECT s_name, ar_s_options FROM map_manager.mm_custom_attribute
  """

  insert_custom_attribute_statement = """
  INSERT INTO map_manager.mm_derived_attribute (
      attribute_id,
      feature_id, 
      s_name,
      s_value,
      changeset_id,
      global_version_id_start,
      global_version_id_end,
      b_user_edit
    )
  SELECT \$1,
  \$2,
  \$3,
  \$4,
  \$5,
  NULL,
  NULL,
  \$6
  """

  execute_get_custom_attributes_statement = PSQLInterface.execute_psql_string(get_distinct_custom_attributes_statement)

  attribute_names = [values(row)[1] for row in LibPQ.rowtable(execute_get_custom_attributes_statement)]

  attribute_value_options = [values(row)[2] for row in LibPQ.rowtable(execute_get_custom_attributes_statement)]

  convert_attribute_options = [ismissing(options) ? missing : [string(strip(x)) for x in split(replace(options, r"[{}\"]" => ""), ',')] for options in attribute_value_options]

  if in(s_name, attribute_names)
    find_index = findfirst(n -> n == s_name, attribute_names)
    attribute_id = feature_id * "&&" * s_name
    if !ismissing(convert_attribute_options[find_index])
      if in(s_value, convert_attribute_options[find_index])
        PSQLInterface.execute_psql_string(insert_custom_attribute_statement, parameters=[attribute_id, feature_id, s_name, s_value, changeset_id, true])
        PSQLInterface.execute_psql_string(update_feature_status_statement, parameters=["MODIFIED", changeset_id, feature_id, true])
        return attribute_id
      else
        return 500, "Cannot assign value $s_value to attribute $s_name"
      end
    else
      PSQLInterface.execute_psql_string(insert_custom_attribute_statement, parameters=[attribute_id, feature_id, s_name, s_value, changeset_id, true])
      PSQLInterface.execute_psql_string(update_feature_status_statement, parameters=["MODIFIED", changeset_id, feature_id, true])
      return attribute_id
    end
  else
    return 500, "The specified attribute can not be edited"
  end

end


"""
validate_unpublished_changeset_source_update()

This function validates the if the source-layer update changeset can be published by checking whether there are exisitng PENDING/IN-PROGRESS
changeset. It does this by querying the map_manager.mm_changeset table and will return an HTTP500 error if there is an existing changeset for 
this layer which is not in the APPROVED/DECLINED status.
If not, it will return "EMPTY" to indicate that there is no blocking changeset_id. 
For an OSM layer changeset to be published successfully, there should be no other PENDING/IN_PROGRESS changeset exists on all other layers
For other source layer changeset to be published successfully, there should be no other PENDING/IN_PROGRESS changeset exists on the same layer 
"""
function validate_unpublished_changeset_source_update(changesetId)

  is_source_editing = PSQLInterface.execute_psql_string(
    """
    SELECT e_changeset_edit_type FROM map_manager.mm_changeset 
    WHERE changeset_id = \$1 AND e_changeset_edit_type ='SOURCE'
    """, parameters=[changesetId])
  
  is_source_editing_osm = PSQLInterface.execute_psql_string(
    """
    SELECT e_changeset_edit_type FROM map_manager.mm_changeset 
    WHERE changeset_id = \$1 AND e_changeset_edit_type ='SOURCE' AND layer_id = 'OSM'
    """, parameters=[changesetId])

  # Check if there are existing 'PENDING' changeset
  # If OSM update and there are existing PENDING/IN PROGRESS changeset, return Warning message
  # If other source layer update and there are existing PENDING/IN PROGRESS changeset on the selected layer, return Warning message
  if !isempty(is_source_editing)
    if !isempty(is_source_editing_osm)
      has_unpublished_changeset = PSQLInterface.execute_psql_string(
      """
      SELECT changeset_id FROM map_manager.mm_changeset
      WHERE e_changeset_status IN ('IN_PROGRESS', 'PENDING') AND changeset_id != \$1
      """, parameters=[changesetId])

      !isempty(has_unpublished_changeset) && return DataFrame(has_unpublished_changeset)[1,1]

    else
      has_unpublished_changeset = PSQLInterface.execute_psql_string(
      """
      SELECT changeset_id FROM map_manager.mm_changeset
      WHERE e_changeset_status IN ('IN_PROGRESS', 'PENDING') 
      AND changeset_id != \$1
      AND layer_id = (SELECT layer_id FROM map_manager.mm_changeset WHERE changeset_id = \$1)
      """, parameters=[changesetId])

      !isempty(has_unpublished_changeset) && return DataFrame(has_unpublished_changeset)[1,1]

    end
  end
  return "EMPTY"
end

function update_global_version_id_start_attribute_table()
  update_global_version_id_start_attribute_table = """                    
  UPDATE map_manager.mm_attribute
  SET global_version_id_start = \$1
  WHERE changeset_id = \$2
  AND (global_version_id_start IS NULL AND global_version_id_end IS NULL)
  """
  return update_global_version_id_start_attribute_table
end

function update_global_version_id_start_derived_attribute_table()
  update_global_version_id_start_attribute_table = """                    
  UPDATE map_manager.mm_derived_attribute
  SET global_version_id_start = \$1
  WHERE changeset_id = \$2
  AND (global_version_id_start IS NULL AND global_version_id_end IS NULL)
  """
  return update_global_version_id_start_attribute_table
end

function update_global_version_id_end_attribute_table()
  update_global_version_id_end_attribute_table = """
  UPDATE map_manager.mm_attribute 
  SET global_version_id_end = \$1
  WHERE attribute_id IN (SELECT attribute_id FROM map_manager.mm_attribute WHERE changeset_id = \$2)
  AND (global_version_id_start IS NOT NULL AND global_version_id_end IS NULL)
  """
  return update_global_version_id_end_attribute_table
end

function update_global_version_id_end_derived_attribute_table()
  update_global_version_id_end_attribute_table = """
  UPDATE map_manager.mm_derived_attribute 
  SET global_version_id_end = \$1
  WHERE attribute_id IN (SELECT attribute_id FROM map_manager.mm_derived_attribute WHERE changeset_id = \$2)
  AND (global_version_id_start IS NOT NULL AND global_version_id_end IS NULL)
  """
  return update_global_version_id_end_attribute_table
end

function update_global_version_id_end_derived_relationship_table()
  update_global_version_id_end_relationship_table = """
  UPDATE map_manager.mm_derived_relationship 
  SET global_version_id_end = \$1
  WHERE relationship_id IN (SELECT relationship_id FROM map_manager.mm_derived_relationship WHERE changeset_id = \$2)
  AND (global_version_id_start IS NOT NULL AND global_version_id_end IS NULL)
  """
  return update_global_version_id_end_relationship_table
end

function update_global_version_id_start_derived_relationship_table()
  update_global_version_id_start_relationship_table = """
  UPDATE map_manager.mm_derived_relationship 
  SET global_version_id_start = \$1
  WHERE changeset_id = \$2
  AND (global_version_id_start IS NULL AND global_version_id_end IS NULL)
  """
  return update_global_version_id_start_relationship_table
end

function update_global_version_id_end_feature_table()
  update_global_version_id_end_feature_table = """
  UPDATE map_manager.mm_feature
  SET global_version_id_end = \$1
  WHERE feature_id IN (SELECT feature_id FROM map_manager.mm_feature WHERE changeset_id = \$2)
  AND (global_version_id_start IS NOT NULL AND global_version_id_end IS NULL)
  """
  return update_global_version_id_end_feature_table
end

function update_global_version_id_start_feature_table()
  update_global_version_id_start_feature_table = """
  UPDATE map_manager.mm_feature
  SET global_version_id_start = \$1
  WHERE changeset_id = \$2
  AND (global_version_id_start IS NULL AND global_version_id_end IS NULL)
  """
  return update_global_version_id_start_feature_table
end

function update_global_version_id_end_for_deletion_attribute_table()
  update_global_version_id_end_for_deletion_attribute_table = """                    
  UPDATE map_manager.mm_attribute 
  SET global_version_id_end = \$1
  WHERE changeset_id = \$2
  AND (global_version_id_end IS NULL AND b_changeset_delete = TRUE)
  """
  return update_global_version_id_end_for_deletion_attribute_table
end

function update_global_version_id_end_for_deletion_feature_table()
  update_global_version_id_end_for_deletion_feature_table = """
  UPDATE map_manager.mm_feature
  SET global_version_id_end = \$1
  WHERE changeset_id = \$2
  AND (global_version_id_end IS NULL AND e_feature_status = 'REMOVED')
  """
  return update_global_version_id_end_for_deletion_feature_table
end

function update_global_version_id_end_for_deletion_relationship_table()
  update_global_version_id_end_for_deletion_relationship_table = """                    
  UPDATE map_manager.mm_relationship
  SET global_version_id_end  = \$1
  WHERE changeset_id = \$2 
  AND (global_version_id_end IS NULL AND b_changeset_delete = TRUE)
  """
  return update_global_version_id_end_for_deletion_relationship_table
end

function global_version_pre_approval()
  global_version_pre_approval = """
  SELECT global_version_id
  FROM map_manager.mm_global_version
  ORDER BY global_version_id
  DESC LIMIT 1
  """
  return global_version_pre_approval
end

function source_update_approved_changeset()
  source_update_approved_changeset = """
  WITH current_changeset_id AS (
    SELECT changeset_id FROM map_manager.mm_changeset WHERE e_changeset_status = 'APPROVING'
  )
  SELECT global_version_id, changeset_id FROM map_manager.mm_global_version 
  WHERE changeset_id = (SELECT changeset_id FROM current_changeset_id);
  """
  return source_update_approved_changeset
end

"""
publish_changeset(changesetId::String)

This function publishes changeset after Front-end user clicks 'Publish'. 
The fuction will:
Generate a new global version number in global version table.
Update the changeset status to 'APPROVED' if it is user edit changeset else set changeset status to 'APPROVING' in changeset table.
Assign the corresponding rows in attribute, feature and relationship tables global version id start and end.
"""
function publish_changeset(changesetId::String)

  editing_type_query = PSQLInterface.execute_psql_string(
  """
  SELECT e_changeset_edit_type FROM map_manager.mm_changeset 
  WHERE changeset_id = \$1
  """, parameters=[changesetId])
  edit_type = DataFrame(editing_type_query)[1,1]
  
  add_new_global_version = """
  INSERT INTO map_manager.mm_global_version (global_version_id, dt_merged, changeset_id)
  VALUES (\$1,(SELECT EXTRACT(EPOCH FROM NOW())), \$2)
  ON CONFLICT DO NOTHING;
  """

  update_changeset_status = """
  WITH current_changeset_status AS (
    SELECT e_changeset_edit_type FROM map_manager.mm_changeset WHERE changeset_id = \$1
  ), get_changeset_status AS (
    SELECT CASE WHEN e_changeset_edit_type = 'SOURCE' THEN 'APPROVING'
    ELSE 'APPROVED' END AS new_changeset_status 
    FROM current_changeset_status
  )
  UPDATE map_manager.mm_changeset SET e_changeset_status = (SELECT new_changeset_status FROM get_changeset_status) WHERE changeset_id = \$1; 
  """

  # Select largest current global_version_id. The new id is current global_version_id + 1
  current_global_version = PSQLInterface.execute_psql_string(App.global_version_pre_approval())
  global_version_pre_approval = DataFrame(current_global_version)[1,1]
  global_version_post_approval = global_version_pre_approval + 1

  # Update derived attribute table by invalidating old attributes and making new attributes valid
  update_global_version_id_end_derived_attribute_table = App.update_global_version_id_end_derived_attribute_table()
  update_global_version_id_start_derived_attribute_table = App.update_global_version_id_start_derived_attribute_table()

  # Update derived relationship table by invalidating old relationships and making new relationships valid
  update_global_version_id_end_derived_relationship_table = App.update_global_version_id_end_derived_relationship_table()
  update_global_version_id_start_derived_relationship_table = App.update_global_version_id_start_derived_relationship_table()

  # ATTRIBUTE EDIT
  if edit_type == "ATTRIBUTE"
    PSQLInterface.execute_psql_string(add_new_global_version, parameters=[global_version_post_approval, changesetId])
    PSQLInterface.execute_psql_string(update_changeset_status, parameters=[changesetId])
    PSQLInterface.execute_psql_string(update_global_version_id_end_derived_attribute_table, parameters=[global_version_pre_approval, changesetId])
    PSQLInterface.execute_psql_string(update_global_version_id_start_derived_attribute_table, parameters=[global_version_post_approval, changesetId])
  end
  
  # RELATIONSHIP EDIT
  if edit_type == "RELATIONSHIP"
    PSQLInterface.execute_psql_string(add_new_global_version, parameters=[global_version_post_approval, changesetId])
    PSQLInterface.execute_psql_string(update_changeset_status, parameters=[changesetId])
    PSQLInterface.execute_psql_string(update_global_version_id_end_derived_relationship_table, parameters=[global_version_pre_approval, changesetId])
    PSQLInterface.execute_psql_string(update_global_version_id_start_derived_relationship_table, parameters=[global_version_post_approval, changesetId])
  end

  # SOURCE UPDATE
  if edit_type == "SOURCE"
    PSQLInterface.execute_psql_string(add_new_global_version, parameters=[global_version_post_approval, changesetId])
    PSQLInterface.execute_psql_string(update_changeset_status, parameters=[changesetId])
  end

  changeset_json = JSON3.write(
      Dict("changeset_id" => changesetId))
  @info "Published change_set \'$changesetId\'"
  return changeset_json
end

""" source_layer_update_publish_changeset()

This function occurs after a delta source update is ingested and approved. To publish the new changeset the old data must be assigned  
a global_version_id_end and the new data must be assigned a global_version_id_start. 
"""
function source_layer_update_publish_changeset()
  # This function requests from the database the changeset_id and global_version_id of the changeset which is in the 'APPROVING' state. 
  # This should only ever be one changeset. 
  source_update_approved_changeset = PSQLInterface.execute_psql_string(App.source_update_approved_changeset())
  # Global version is assigned
  approved_changeset_global_version = DataFrame(source_update_approved_changeset)[1,1]
  # Changeset id is assigned
  approved_changeset_id = DataFrame(source_update_approved_changeset)[1,2]

  # Therefore the global_version_id_end should be the current global_version - 1
  pre_approved_changeset_global_version = approved_changeset_global_version - 1

  # Update global_version_id_end for old entries in the feature and attribute tables
  update_global_version_id_end_attribute_table = App.update_global_version_id_end_attribute_table()
  update_global_version_id_end_feature_table = App.update_global_version_id_end_feature_table()

  # Update global_version_id_start for new entries in the feature and attribute tables
  update_global_version_id_start_attribute_table = App.update_global_version_id_start_attribute_table()
  update_global_version_id_start_feature_table = App.update_global_version_id_start_feature_table()

  # Also update global_version_id_end for new entries where a feature or attribute has been deleted
  update_global_version_id_end_for_deletion_attribute_table = App.update_global_version_id_end_for_deletion_attribute_table()
  update_global_version_id_end_for_deletion_feature_table = App.update_global_version_id_end_for_deletion_feature_table()

  # Update global_version_id_end for old features/attributes
  PSQLInterface.execute_psql_string(update_global_version_id_end_attribute_table, parameters=[pre_approved_changeset_global_version, approved_changeset_id])
  PSQLInterface.execute_psql_string(update_global_version_id_end_feature_table, parameters=[pre_approved_changeset_global_version, approved_changeset_id])

  # Update global_version_id_start for new/updated features/attributes
  PSQLInterface.execute_psql_string(update_global_version_id_start_attribute_table, parameters=[approved_changeset_global_version, approved_changeset_id])
  PSQLInterface.execute_psql_string(update_global_version_id_start_feature_table, parameters=[approved_changeset_global_version, approved_changeset_id])

  # Update global_version_id_start for deleted features/attributes
  PSQLInterface.execute_psql_string(update_global_version_id_end_for_deletion_attribute_table, parameters=[approved_changeset_global_version, approved_changeset_id])
  PSQLInterface.execute_psql_string(update_global_version_id_end_for_deletion_feature_table, parameters=[approved_changeset_global_version, approved_changeset_id])
end


"""
get_latest_changeset_id(layerId::String)::String

This function get the lastest changeset_id on the specified layer by getting
the max s_layer_version
"""
function get_latest_changeset_id(layerId::String)::String
  # Get latest SOURCE editing changeset Id
  get_changeset_id = PSQLInterface.execute_psql_string("""
  select changeset_id from map_manager.mm_changeset
  where s_layer_version = (
  select MAX(s_layer_version) from map_manager.mm_changeset where layer_id = \$1
  )
  """, parameters=[layerId])

  changeset_id = DataFrame(get_changeset_id)[1,1]
  return changeset_id
end


"""
refresh_materialized_view_feature(layerId::String)

This function refreshes materialized view for mm_feature table after delta function
"""
function refresh_materialized_view_feature(layerId::String)
  if layerId == "OSM"
    PSQLInterface.execute_psql_string(
      """ 
      REFRESH MATERIALIZED VIEW map_manager.mm_feature_osm_line_mv
      """)
  elseif layerId == "VICMAP_TRANSPORT" 
    PSQLInterface.execute_psql_string(
      """ 
      REFRESH MATERIALIZED VIEW map_manager.mm_feature_vicmap_transport_line_mv
      """)
  elseif layerId == "DTP_OSM" 
    PSQLInterface.execute_psql_string(
      """ 
      REFRESH MATERIALIZED VIEW map_manager.mm_feature_dtp_osm_line_mv
      """)
  else
    error("Layer ID incorrect. Layer ID should be OSM/VICMAP_TRANSPORT")
  end
end


"""
refresh_materialized_view_relationship(layerId::String)

This function refreshes materialized view for mm_derived_relationship table after running map matching b/w
DTP_OSM and VicMap Transport. 
"""
function refresh_materialized_view_relationship()
  PSQLInterface.execute_psql_string(
    """ 
    REFRESH MATERIALIZED VIEW map_manager.mm_derived_relationship_vicmap_transport_mv
    """)
end


"""
get_changeset_status(changesetId::String)

This function retrieve changset status and return the status.
"""
function get_changeset_status(changsetId::String)
  get_changeset_status = PSQLInterface.execute_psql_string("""
  SELECT e_changeset_status FROM map_manager.mm_changeset
  WHERE changeset_id = \$1
  """, parameters=[changsetId])

  changeset_status = DataFrame(get_changeset_status)[1,1]
  return changeset_status
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

function update_source_update_changeset_status(layerId::String, currentChangesetStatus::String, newChangesetStatus::String)
  changeset_id  = get_latest_source_changeset_id_by_status(layerId, currentChangesetStatus)
  update_changeset_status_statement = """
  UPDATE map_manager.mm_changeset SET 
  e_changeset_status = \$2
  WHERE changeset_id = \$1
  """
  if changeset_id !== nothing
    PSQLInterface.execute_psql_string(update_changeset_status_statement, parameters=[changeset_id, newChangesetStatus])
  else
    throw(MapEditorException("Changeset not found. Cannot update status."))
  end
  
end
