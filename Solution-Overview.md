[ TRIGGER: Fortnightly Schedule / Manual ]
                                                 |
                                                 v
+---------------------------------------------------------------------------------------------------+
|  AWS STEP FUNCTION ORCHESTRATOR (Monolithic Workflow)                                             |
|                                                                                                   |
|  1. INGESTION PHASE                                                                               |
|     +----------------+       +----------------+      +---------------------------+                |
|     |  OSM API       | ----> |  Microservice  | ---> |  DB: Temporary Tables     |                |
|     +----------------+       |  (Ingest)      |      |  (Staging Data)           |                |
|                              +----------------+      +---------------------------+                |
|     +----------------+               ^                                                            |
|     |  VicMap API    | --------------+                                                            |
|     +----------------+                                                                            |
|                                                                                                   |
|  2. PROCESSING PHASE (The Bottleneck)                                                             |
|     +---------------------------+      +--------------------------+      +---------------------+  |
|     |  Microservice: Matcher    | <--> |  CORE LOGIC (Julia)      | <--> |  InMemory Process   |  |
|     |  (Lambda/Container)       |      |  "SpatialUtilities.jl"   |      |  (Heavy Compute)    |  |
|     +---------------------------+      +--------------------------+      +---------------------+  |
|                 |                                                                                 |
|                 v                                                                                 |
|     +---------------------------+                                                                 |
|     |  DB: "Derived Network"    |                                                                 |
|     +---------------------------+                                                                 |
|                                                                                                   |
|  3. APPROVAL PHASE (The Timeout Risk)                                                             |
|     +---------------------------+                                                                 |
|     |  WAIT STATE (Polling)     | <--- [ HUMAN: DTP User via Frontend ]                           |
|     |  "Check Changeset Status" |                                                                 |
|     +---------------------------+                                                                 |
|                 |                                                                                 |
|                 v                                                                                 |
|                                                                                                   |
|  4. PERSISTENCE PHASE                                                                             |
|     +---------------------------+      +--------------------------+                               |
|     |  Microservice: Delta      | ---> |  Legacy Logic (Julia)    |                               |
|     |  Persistence              |      |  "persistence.jl"        |                               |
|     +---------------------------+      +--------------------------+                               |
|                 |                                                                                 |
|                 v                                                                                 |
|     +---------------------------+                                                                 |
|     |  DB: Permanent Tables     |                                                                 |
|     |  (Prod Network)           |                                                                 |
|     +---------------------------+                                                                 |
|                                                                                                   |
|  5. OUTPUT PHASE                                                                                  |
|     +---------------------------+      +--------------------------+                               |
|     |  Export Service           | ---> |  S3 Bucket (GeoJSON)     |                               |
|     +---------------------------+      +--------------------------+                               |
|                                                     |                                             |
|                                                     v                                             |
|                                        +--------------------------+                               |
|                                        |  LRS (Linear Ref System) |                               |
|                                        |  (Downstream Consumer)   |                               |
|                                        +--------------------------+                               |
+---------------------------------------------------------------------------------------------------+