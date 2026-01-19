# MapImporter

## Development
### Unit tests
Run unit tests locally by running the following in a terminal:
```sh
make local-unit-test
```

For unit test development, start up the unit test supporting containers by running:
```sh
make local-unit-test-up
```

Unit tests rely on an up-to-date PostgreSQL schema in `test/recreate_tables.sql` so that ingestion scripts can run. In order to update this file, you need to have Experiment Manager and the Map Manager PostgreSQL database running locally. Then, run the following in a terminal:
```sh
pg_dump -U postgres -h localhost -p 5440 postgres --schema-only --schema=map_manager --table="map_manager.mm*" -f recreate_tables.sql
```
Enter the default database password "`postgres`" when prompted. Replace the resulting file with the file in the `test/` directory.

## Map Importer
### Map Importer Functionalities
The following listed the overall goal and functionalities of Map Importer.

#### Map Data Ingestion
Map Importer microservice is able to import large data from multiple sources into a single data storage for analysing.

#### Map Data Transformation
Data from different sources will be transformed and converted to the format that front end needed and is compatible with Map Manager database.

#### Map Data Load
Transformed data will be loaded the Map Manager database and should be able to retrieved from GraphQL.

### Map Importer Endpoints
To be discussed.

### Template Version Used

This application generated with or-sdk JuliaAppTemplate v0.2.37