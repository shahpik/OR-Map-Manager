# OR-Map Manager Data Model

This document describes the database schema for the OR-Map Manager system.

---

## Overview

The Map Manager database is organized into the following categories:

| Category | Purpose | Tables |
|----------|---------|--------|
| **Core Tables** | Store source data from OSM, VicMap, and other layers | mm_layer, mm_feature, mm_attribute, mm_relationship |
| **Derived Tables** | Store the output DTP-OSM network | mm_derived_feature, mm_derived_attribute, mm_derived_relationship |
| **Versioning Tables** | Manage changesets and version history | mm_changeset, mm_global_version, mm_changeset_lock |
| **Supporting Tables** | Enable spatial indexing, reporting, and custom attributes | mm_hex, mm_match_report, mm_intersection, mm_custom_attribute |
| **Staging Tables** | Temporary storage during data ingestion | stg_*, mm_temp_* |

---

## Data Flow Context

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   SOURCE DATA   │     │   PROCESSING    │     │  OUTPUT DATA    │
│                 │     │                 │     │                 │
│  stg_osm        │────►│  mm_feature     │────►│ mm_derived_     │
│  stg_vicmap     │     │  mm_attribute   │     │    feature      │
│  stg_custom_    │     │  mm_relationship│     │ mm_derived_     │
│    seed_file    │     │                 │     │    attribute    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
      STAGING              CORE TABLES           DERIVED TABLES
```

---

## Naming Conventions

| Prefix | Type | Example |
|--------|------|---------|
| `s_` | String | s_name, s_value, s_source_id |
| `n_` | Number/Integer | n_version, n_matched_features |
| `b_` | Boolean | b_is_latest, b_user_edit |
| `e_` | Enum | e_feature_type, e_changeset_status |
| `dt_` | Datetime | dt_merged, dt_last_opened |
| `f_` | Float | f_error_value, f_start_offset |
| `ar_` | Array | ar_n_hex_index, ar_s_options |
| `geom_` | Geometry (PostGIS) | geom_feature, geom_relationship |

---

# 1. CORE TABLES

These tables store the source data ingested from OSM, VicMap, and other data sources.

---

## 1.1 mm_layer

Defines the available data layers in the system.

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| layer_id | VARCHAR | PK | Unique layer identifier (e.g., 'OSM', 'VICMAP_TRANSPORT') |
| s_name | VARCHAR | | Human-readable layer name |
| e_layer_type | ENUM | | Layer geometry type (POINT, LINE, POLYGON) |

**Example Data:**
```
layer_id          | s_name              | e_layer_type
------------------+---------------------+--------------
OSM               | OpenStreetMap       | LINE
VICMAP_TRANSPORT  | VicMap Transport    | LINE
CUSTOM_SEED_FILE  | Custom Seed File    | LINE
```

---

## 1.2 mm_feature

Core feature table containing geometry and metadata for all source features.

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| feature_id | VARCHAR | PK | Unique feature identifier (e.g., 'OSM&&WAY123456') |
| changeset_id | VARCHAR | PK, FK | Reference to changeset (composite PK) |
| layer_id | VARCHAR | FK | Reference to mm_layer |
| s_name | VARCHAR | | Feature name (e.g., road name) |
| e_feature_type | ENUM | | Geometry type (POINT, LINE, POLYGON) |
| s_source_id | VARCHAR | | Original ID from source system |
| geom_feature | GEOMETRY | | PostGIS geometry |
| ar_n_hex_index | INTEGER[] | FK | Array of hex indices for spatial indexing |
| global_version_id_start | INTEGER | FK | Version when this record became active |
| global_version_id_end | INTEGER | FK | Version when this record was superseded (NULL = current) |
| association_changeset_id | VARCHAR | FK | Associated changeset for edits |
| join_key | VARCHAR | | MD5 hash for change detection |
| b_is_latest | BOOLEAN | | TRUE if this is the current version |
| e_feature_status | ENUM | | Status: ADDED, MODIFIED, REMOVED |
| b_is_deleted | BOOLEAN | | TRUE if feature is deleted |
| b_user_edit | BOOLEAN | | TRUE if manually edited by user |
| b_user_rejected | BOOLEAN | | TRUE if rejected by user |

**Feature ID Convention:**
```
OSM&&WAY123456      → Original OSM way
OSM&&NODE789        → Original OSM node
VICMAP&&12345       → VicMap feature
CUSTOM_SEED&&001    → Custom seed file feature
```

---

## 1.3 mm_attribute

Stores key-value attributes for features (1:N relationship with mm_feature).

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| attribute_id | VARCHAR | PK | Unique identifier (format: feature_id&&attribute_name) |
| changeset_id | VARCHAR | PK, FK | Reference to changeset (composite PK) |
| feature_id | VARCHAR | FK | Reference to mm_feature |
| s_name | VARCHAR | | Attribute name (e.g., 'highway', 'speed_limit') |
| s_value | VARCHAR | | Attribute value (e.g., 'primary', '60') |
| global_version_id_start | INTEGER | FK | Version when this record became active |
| global_version_id_end | INTEGER | FK | Version when this record was superseded |
| join_key | VARCHAR | | MD5 hash for change detection |
| b_is_latest | BOOLEAN | | TRUE if this is the current version |
| b_changeset_delete | BOOLEAN | | TRUE if deleted in this changeset |
| b_is_deleted | BOOLEAN | | TRUE if attribute is deleted |
| b_user_edit | BOOLEAN | | TRUE if manually edited by user |

**Example Data:**
```
attribute_id              | feature_id      | s_name      | s_value
--------------------------+-----------------+-------------+---------
OSM&&WAY123&&highway      | OSM&&WAY123     | highway     | primary
OSM&&WAY123&&name         | OSM&&WAY123     | name        | King St
OSM&&WAY123&&speed_limit  | OSM&&WAY123     | speed_limit | 60
```

---

## 1.4 mm_relationship

Stores relationships between features (e.g., VicMap feature matched to OSM features).

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| relationship_id | VARCHAR | PK | Unique relationship identifier |
| changeset_id | VARCHAR | PK, FK | Reference to changeset (composite PK) |
| match_report_id | VARCHAR | | Reference to match report |
| e_relationship_type | ENUM | | Type: AUTOMATIC, MANUAL |
| geom_relationship | GEOMETRY | | Geometry of the matched path |
| f_start_offset | FLOAT | | Start offset along matched feature |
| f_end_offset | FLOAT | | End offset along matched feature |
| f_error_value | FLOAT | | Match quality metric (lower = better) |
| ar_n_hex_index | INTEGER[] | FK | Array of hex indices |
| feature_id_input | VARCHAR | FK | Source feature (e.g., VicMap feature) |
| feature_id_matched | VARCHAR[] | FK | Array of matched features (e.g., OSM ways) |
| layer_id | VARCHAR | FK | Reference to layer |
| global_version_id_start | INTEGER | FK | Version when this record became active |
| global_version_id_end | INTEGER | FK | Version when this record was superseded |
| join_key | VARCHAR | | MD5 hash for change detection |
| b_is_latest | BOOLEAN | | TRUE if this is the current version |
| b_changeset_delete | BOOLEAN | | TRUE if deleted in this changeset |
| b_is_deleted | BOOLEAN | | TRUE if relationship is deleted |
| b_user_edit | BOOLEAN | | TRUE if manually edited by user |

---

# 2. DERIVED TABLES

These tables store the output DTP-OSM network - the result of processing and matching.

---

## 2.1 mm_derived_feature

Derived features that form the DTP-OSM network (split/transformed from source OSM).

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| feature_id | VARCHAR | PK | Unique identifier (e.g., 'DTP&&WAY1') |
| changeset_id | VARCHAR | PK, FK | Reference to changeset (composite PK) |
| mapping_feature_id | VARCHAR | FK | Parent OSM feature this was derived from |
| layer_id | VARCHAR | FK | Reference to layer (typically 'DTP_OSM') |
| s_name | VARCHAR | | Feature name |
| e_feature_type | ENUM | | Geometry type (POINT, LINE, POLYGON) |
| s_source_id | VARCHAR | | Source identifier |
| geom_feature | GEOMETRY | | PostGIS geometry |
| ar_n_hex_index | INTEGER[] | FK | Array of hex indices |
| global_version_id_start | INTEGER | FK | Version when this record became active |
| global_version_id_end | INTEGER | FK | Version when this record was superseded |
| association_changeset_id | VARCHAR | FK | Associated changeset |
| b_is_latest | BOOLEAN | | TRUE if this is the current version |
| e_feature_status | ENUM | | Status: ADDED, MODIFIED, REMOVED |
| b_user_rejected | BOOLEAN | | TRUE if rejected by user |

**Relationship to Source:**
```
OSM&&WAY123 (original)
    │
    ├──► DTP&&WAY1 (mapping_feature_id = OSM&&WAY123)
    ├──► DTP&&WAY2 (mapping_feature_id = OSM&&WAY123)
    └──► DTP&&WAY3 (mapping_feature_id = OSM&&WAY123)
```

---

## 2.2 mm_derived_attribute

Attributes for derived features (inherited from VicMap + custom attributes).

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| attribute_id | VARCHAR | PK | Unique identifier |
| changeset_id | VARCHAR | PK, FK | Reference to changeset (composite PK) |
| feature_id | VARCHAR | FK | Reference to mm_derived_feature |
| s_name | VARCHAR | | Attribute name |
| s_value | VARCHAR | | Attribute value |
| global_version_id_start | INTEGER | FK | Version when this record became active |
| global_version_id_end | INTEGER | FK | Version when this record was superseded |
| b_is_latest | BOOLEAN | | TRUE if this is the current version |
| b_user_edit | BOOLEAN | | TRUE if manually edited by user |

---

## 2.3 mm_derived_relationship

Relationships in the derived network (links DTP features to source layers).

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| relationship_id | VARCHAR | PK | Unique relationship identifier |
| changeset_id | VARCHAR | PK, FK | Reference to changeset (composite PK) |
| e_relationship_type | ENUM | | Type: AUTOMATIC, MANUAL |
| geom_relationship | GEOMETRY | | Geometry of the relationship |
| f_start_offset | FLOAT | | Start offset |
| f_end_offset | FLOAT | | End offset |
| f_error_value | FLOAT | | Match quality metric |
| ar_n_hex_index | INTEGER[] | FK | Array of hex indices |
| feature_id_input | VARCHAR | FK | Input feature reference |
| feature_id_matched | VARCHAR[] | FK | Matched feature reference(s) |
| layer_id | VARCHAR | FK | Reference to layer |
| global_version_id_start | INTEGER | FK | Version when this record became active |
| global_version_id_end | INTEGER | FK | Version when this record was superseded |
| b_is_latest | BOOLEAN | | TRUE if this is the current version |
| b_user_edit | BOOLEAN | | TRUE if manually edited by user |

---

# 3. VERSIONING TABLES

These tables manage changesets and version history for temporal data management.

---

## 3.1 mm_changeset

Tracks groups of changes awaiting approval or already applied.

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| changeset_id | VARCHAR | PK | Unique changeset identifier |
| layer_id | VARCHAR | FK | Reference to layer |
| e_changeset_edit_type | ENUM | | Type: SOURCE, ATTRIBUTE, RELATIONSHIP |
| s_layer_version | VARCHAR | | Layer version string |
| user_name | VARCHAR | | User who created the changeset |
| dt_last_opened | TIMESTAMP | | Last opened datetime |
| e_changeset_status | ENUM | | Status: PENDING, IN-PROGRESS, APPROVING, APPROVED |

**Changeset Lifecycle:**
```
PENDING → IN-PROGRESS → APPROVING → APPROVED
                            ↑
                     (DTP clicks approve)
```

---

## 3.2 mm_global_version

Tracks global version numbers when changesets are merged.

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| global_version_id | INTEGER | PK | Unique version number (auto-incrementing) |
| changeset_id | VARCHAR | FK | Reference to the changeset that created this version |
| dt_merged | TIMESTAMP | | Datetime when the changeset was merged |

**Versioning Concept:**
```
Version 0: Initial load
Version 1: First OSM update
Version 2: First VicMap update
Version 3: Manual edit
...
```

---

## 3.3 mm_changeset_lock

Prevents concurrent editing of the same changeset.

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| changeset_id | VARCHAR | PK, FK | Reference to changeset |
| username | VARCHAR | | User who holds the lock |
| dt_valid_until | TIMESTAMP | | Lock expiration datetime |

---

# 4. SUPPORTING TABLES

These tables provide additional functionality like spatial indexing, reporting, and custom attributes.

---

## 4.1 mm_hex

Hexagonal spatial index for efficient spatial queries (H3-based).

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| b_hex_index | BIGINT | PK | Hex index identifier |
| n_hex_resolution | INTEGER | | Hex resolution level |
| geom_hex | GEOMETRY | | Hex polygon geometry |

---

## 4.2 mm_match_report

Stores reports from matching operations for quality tracking.

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| match_report_id | VARCHAR | PK | Unique report identifier |
| dt_timestamp | BIGINT | | Timestamp (epoch) |
| n_version | INTEGER | | Report version number |
| n_matched_features | INTEGER | | Count of successfully matched features |
| n_failed_features | INTEGER | | Count of failed matches |
| f_matching_rate | FLOAT | | Matching rate (0.0 - 1.0) |
| is_latest | BOOLEAN | | TRUE if this is the latest report |
| layer_id | VARCHAR | FK | Reference to layer |
| e_error_unit | ENUM | | Error unit (e.g., 'M2_PER_M') |
| global_version_id | INTEGER | FK | Reference to global version |

---

## 4.3 mm_intersection

Stores road intersection features for the network.

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| feature_id | VARCHAR | PK | Unique intersection identifier |
| changeset_id | VARCHAR | PK, FK | Reference to changeset |
| layer_id | VARCHAR | FK | Reference to layer |
| way_names | VARCHAR[] | | Names of intersecting roads |
| way_ids | VARCHAR[] | FK | IDs of intersecting ways |
| geom_feature | GEOMETRY | | Intersection point geometry |
| localities | VARCHAR[] | | Locality/suburb names |
| ar_n_hex_index | INTEGER[] | FK | Array of hex indices |
| global_version_id_start | INTEGER | FK | Version when this record became active |
| global_version_id_end | INTEGER | FK | Version when this record was superseded |
| b_is_latest | BOOLEAN | | TRUE if this is the current version |

---

## 4.4 mm_custom_attribute

Defines custom attributes that can be added to features per layer.

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| layer_id | VARCHAR | PK, FK | Reference to layer |
| s_name | VARCHAR | PK | Custom attribute name |
| ar_s_options | VARCHAR[] | | Array of allowed values (NULL = free text) |
| e_custom_attribute_type | ENUM | | Attribute type |

**Example:**
```
layer_id  | s_name          | ar_s_options
----------+-----------------+---------------------------
DTP_OSM   | road_condition  | {good, fair, poor}
DTP_OSM   | notes           | NULL (free text allowed)
```

---

# 5. STAGING TABLES

Temporary tables used during data ingestion. These are created, populated, and dropped during ETL processes.

---

## 5.1 stg_* (Staging Tables)

Raw data loaded from external sources before transformation.

| Table | Purpose |
|-------|---------|
| stg_osm | Raw OSM data from API |
| stg_vicmap_transport | Raw VicMap Transport data |
| stg_custom_seed_file | Raw custom seed file data |
| stg_declared_network | Raw declared network data |
| stg_temp_map_matching_results | Intermediate matching results |
| stg_ttmc | TTMC (Traffic Management) data |

**Lifecycle:**
```
1. CREATE TABLE stg_* (all columns as TEXT)
2. COPY data from CSV/API
3. Transform and INSERT into mm_* tables
4. DROP TABLE stg_*
```

---

## 5.2 mm_temp_* (Processing Tables)

Temporary tables for processing incoming data before delta calculation.

| Table | Purpose |
|-------|---------|
| mm_temp_feature | Incoming features before delta comparison |
| mm_temp_attribute | Incoming attributes before delta comparison |

**Used in Delta Calculation:**
```sql
-- Compare temp vs current to find changes
SELECT * FROM mm_temp_feature
LEFT JOIN mm_feature ON mm_temp_feature.feature_id = mm_feature.feature_id
WHERE mm_feature.join_key != mm_temp_feature.join_key  -- Modified
   OR mm_feature.join_key IS NULL                       -- Added
```

---

# 6. KEY RELATIONSHIPS

## Entity Relationship Summary

```
mm_layer
    │
    ├──► mm_custom_attribute (1:N)  ← Defines ALLOWED attributes per layer
    │         │
    │         │ (validates)
    │         ▼
    ├──► mm_feature ──► mm_attribute (1:N)  ← Stores ACTUAL values per feature
    │
    └──► mm_derived_feature ──► mm_derived_attribute (1:N)  ← Stores ACTUAL values

mm_changeset
    │
    ├──► mm_global_version (1:1)
    │
    ├──► mm_changeset_lock (1:1)
    │
    └──► All feature/attribute/relationship tables (via changeset_id)

mm_hex
    │
    └──► Referenced by ar_n_hex_index in feature/relationship tables
```

---

# 7. VERSIONING MODEL

## How Versioning Works

Every record has:
- `global_version_id_start`: When the record became active
- `global_version_id_end`: When the record was superseded (NULL = current)
- `b_is_latest`: Quick filter for current records

**Example Timeline:**
```
Version 1: Feature A created
           global_version_id_start = 1, global_version_id_end = NULL, b_is_latest = TRUE

Version 2: Feature A modified  
           Old row: global_version_id_end = 1, b_is_latest = FALSE
           New row: global_version_id_start = 2, global_version_id_end = NULL, b_is_latest = TRUE

Version 3: Feature A deleted
           Row: global_version_id_end = 2, b_is_latest = FALSE
```

**Querying Current State:**
```sql
SELECT * FROM mm_feature WHERE b_is_latest = TRUE;
```

**Querying Historical State (at version 2):**
```sql
SELECT * FROM mm_feature 
WHERE global_version_id_start <= 2 
  AND (global_version_id_end IS NULL OR global_version_id_end > 2);
```

---

# 8. SUMMARY

| Category | Count | Tables |
|----------|-------|--------|
| **Core Tables** | 4 | mm_layer, mm_feature, mm_attribute, mm_relationship |
| **Derived Tables** | 3 | mm_derived_feature, mm_derived_attribute, mm_derived_relationship |
| **Versioning Tables** | 3 | mm_changeset, mm_global_version, mm_changeset_lock |
| **Supporting Tables** | 4 | mm_hex, mm_match_report, mm_intersection, mm_custom_attribute |
| **Staging Tables** | ~8 | stg_*, mm_temp_* |
| **Total** | ~22 | |

---

*Document last updated based on code analysis from or-core-map-importer, or-core-map-matcher, or-core-map-editor repositories.*