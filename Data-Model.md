# OR-Map Manager Data Model

This document describes the database schema for the OR-Map Manager system.

---

## Tables Overview

| Table Name | Description |
|------------|-------------|
| mm_custom_attribute | Custom attribute definitions per layer |
| mm_attribute | Feature attributes with versioning |
| mm_feature | Core feature data with geometry |
| mm_layer | Layer definitions |
| mm_hex | Hexagonal spatial index |
| mm_match_report | Matching operation reports |
| mm_relationship | Feature relationships |
| mm_derived_relationship | Derived feature relationships |
| mm_derived_attribute | Derived feature attributes |
| mm_derived_feature | Derived features |
| mm_changeset_lock | Changeset locking mechanism |
| mm_changeset | Changeset management |
| mm_global_version | Global versioning |
| mm_intersection | Intersection features |

---

## Table Definitions

### mm_custom_attribute

Custom attribute definitions for layers.

| Column | Key | Description |
|--------|-----|-------------|
| layer_id | PK, FK | Reference to layer |
| s_name | PK | Attribute name |
| ar_s_options | | Array of options |
| e_custom_attribute_type | | Attribute type enum |

---

### mm_attribute

Feature attributes with version tracking.

| Column | Key | Description |
|--------|-----|-------------|
| attribute_id | PK | Unique attribute identifier |
| changeset_id | PK, FK | Reference to changeset |
| feature_id | FK | Reference to feature |
| s_name | | Attribute name |
| s_value | | Attribute value |
| global_version_id_start | FK | Start version |
| global_version_id_end | FK | End version |
| join_key | | Join key for linking |
| b_is_latest | | Is latest version flag |
| b_changeset_delete | | Deleted in changeset flag |
| b_is_deleted | | Is deleted flag |
| b_user_edit | | User edited flag |

---

### mm_feature

Core feature table containing geometry and metadata.

| Column | Key | Description |
|--------|-----|-------------|
| feature_id | PK | Unique feature identifier |
| changeset_id | PK, FK | Reference to changeset |
| layer_id | FK | Reference to layer |
| s_name | | Feature name |
| e_feature_type | | Feature type enum |
| s_source_id | | Source identifier |
| geom_feature | | Feature geometry |
| ar_n_hex_index | | Array of hex indices |
| global_version_id_start | FK | Start version |
| global_version_id_end | FK | End version |
| association_changeset_id | FK | Associated changeset |
| join_key | | Join key for linking |
| b_is_latest | | Is latest version flag |
| e_feature_status | | Feature status enum |
| b_is_deleted | | Is deleted flag |
| b_user_edit | | User edited flag |
| b_user_rejected | | User rejected flag |

---

### mm_layer

Layer definitions.

| Column | Key | Description |
|--------|-----|-------------|
| layer_id | PK | Unique layer identifier |
| s_name | | Layer name |
| e_layer_type | | Layer type enum |

---

### mm_hex

Hexagonal spatial index for efficient spatial queries.

| Column | Key | Description |
|--------|-----|-------------|
| b_hex_index | PK | Hex index identifier |
| n_hex_resolution | | Hex resolution level |
| geom_hex | | Hex geometry |

---

### mm_match_report

Reports from matching operations.

| Column | Key | Description |
|--------|-----|-------------|
| match_report_id | PK | Unique report identifier |
| dt_timestamp | | Timestamp |
| n_version | | Version number |
| n_matched_features | | Count of matched features |
| n_failed_features | | Count of failed features |
| f_matching_rate | | Matching rate |
| is_latest | | Is latest report flag |
| layer_id | FK | Reference to layer |
| e_error_unit | | Error unit enum |
| global_version_id | FK | Reference to global version |

---

### mm_relationship

Relationships between features.

| Column | Key | Description |
|--------|-----|-------------|
| relationship_id | PK | Unique relationship identifier |
| changeset_id | PK, FK | Reference to changeset |
| match_report_id | | Reference to match report |
| e_relationship_type | | Relationship type enum |
| geom_relationship | | Relationship geometry |
| f_start_offset | | Start offset |
| f_end_offset | | End offset |
| f_error_value | | Error value |
| ar_n_hex_index | FK | Array of hex indices |
| feature_id_input | FK | Input feature reference |
| feature_id_matched | FK | Matched feature reference |
| layer_id | FK | Reference to layer |
| global_version_id_start | FK | Start version |
| global_version_id_end | FK | End version |
| join_key | | Join key for linking |
| b_is_latest | | Is latest version flag |
| b_changeset_delete | | Deleted in changeset flag |
| b_is_deleted | | Is deleted flag |
| b_user_edit | | User edited flag |

---

### mm_derived_relationship

Derived relationships between features.

| Column | Key | Description |
|--------|-----|-------------|
| relationship_id | PK | Unique relationship identifier |
| changeset_id | PK, FK | Reference to changeset |
| e_relationship_type | | Relationship type enum |
| geom_relationship | | Relationship geometry |
| f_start_offset | | Start offset |
| f_end_offset | | End offset |
| f_error_value | | Error value |
| ar_n_hex_index | FK | Array of hex indices |
| feature_id_input | FK | Input feature reference |
| feature_id_matched | FK | Matched feature reference |
| layer_id | FK | Reference to layer |
| global_version_id_start | FK | Start version |
| global_version_id_end | FK | End version |
| b_is_latest | | Is latest version flag |
| b_user_edit | | User edited flag |

---

### mm_derived_attribute

Attributes for derived features.

| Column | Key | Description |
|--------|-----|-------------|
| attribute_id | PK | Unique attribute identifier |
| changeset_id | PK, FK | Reference to changeset |
| feature_id | FK | Reference to feature |
| s_name | | Attribute name |
| s_value | | Attribute value |
| global_version_id_start | FK | Start version |
| global_version_id_end | FK | End version |
| b_is_latest | | Is latest version flag |
| b_user_edit | | User edited flag |

---

### mm_derived_feature

Derived features from mapping operations.

| Column | Key | Description |
|--------|-----|-------------|
| feature_id | PK | Unique feature identifier |
| changeset_id | PK, FK | Reference to changeset |
| mapping_feature_id | FK | Reference to mapping feature |
| layer_id | FK | Reference to layer |
| s_name | | Feature name |
| e_feature_type | | Feature type enum |
| s_source_id | | Source identifier |
| geom_feature | | Feature geometry |
| ar_n_hex_index | FK | Array of hex indices |
| global_version_id_start | FK | Start version |
| global_version_id_end | FK | End version |
| association_changeset_id | FK | Associated changeset |
| b_is_latest | | Is latest version flag |
| e_feature_status | | Feature status enum |
| b_user_rejected | | User rejected flag |

---

### mm_changeset_lock

Locking mechanism for changesets.

| Column | Key | Description |
|--------|-----|-------------|
| changeset_id | PK, FK | Reference to changeset |
| username | | Lock owner username |
| dt_valid_until | | Lock expiration datetime |

---

### mm_changeset

Changeset management for tracking edits.

| Column | Key | Description |
|--------|-----|-------------|
| changeset_id | PK | Unique changeset identifier |
| layer_id | FK | Reference to layer |
| e_changeset_edit_type | | Edit type enum |
| s_layer_version | | Layer version string |
| user_name | | User who created changeset |
| dt_last_opened | | Last opened datetime |
| e_changeset_status | | Changeset status enum |

---

### mm_global_version

Global versioning for the system.

| Column | Key | Description |
|--------|-----|-------------|
| global_version_id | PK | Unique version identifier |
| changeset_id | FK | Reference to changeset |
| dt_merged | | Merge datetime |

---

### mm_intersection

Intersection features (e.g., road intersections).

| Column | Key | Description |
|--------|-----|-------------|
| feature_id | PK | Unique feature identifier |
| changeset_id | PK, FK | Reference to changeset |
| layer_id | FK | Reference to layer |
| way_names | | Names of intersecting ways |
| way_ids | FK | IDs of intersecting ways |
| geom_feature | | Intersection geometry |
| localities | | Locality information |
| ar_n_hex_index | FK | Array of hex indices |
| global_version_id_start | FK | Start version |
| global_version_id_end | FK | End version |
| b_is_latest | | Is latest version flag |

---

## Key Relationships

- **mm_feature** → **mm_layer**: Features belong to layers
- **mm_feature** → **mm_changeset**: Features are versioned through changesets
- **mm_attribute** → **mm_feature**: Attributes belong to features
- **mm_relationship** → **mm_feature**: Relationships connect features
- **mm_changeset** → **mm_global_version**: Changesets are merged into global versions
- **mm_changeset_lock** → **mm_changeset**: Locks prevent concurrent editing
- **mm_derived_feature** → **mm_feature**: Derived features reference source features

---

## Naming Conventions

| Prefix | Meaning |
|--------|---------|
| s_ | String |
| n_ | Number |
| b_ | Boolean |
| e_ | Enum |
| dt_ | Datetime |
| f_ | Float |
| ar_ | Array |
| geom_ | Geometry |

---

## Summary

- **Total Tables:** 15
- **Core Tables:** mm_feature, mm_layer, mm_attribute
- **Versioning Tables:** mm_changeset, mm_global_version, mm_changeset_lock
- **Relationship Tables:** mm_relationship, mm_derived_relationship
- **Derived Tables:** mm_derived_feature, mm_derived_attribute
- **Supporting Tables:** mm_hex, mm_match_report, mm_intersection, mm_custom_attribute
