using Test
using PSQLInterface
using DataFrames
using LibPQ
using JSON3

#===============================================================================
This testing requires a running postgres instance that the code can modify. This
is preferably a docker container.

===============================================================================#

@testset "Utilities" begin include("utilities_test.jl") end

# Check that there are params for testing a conn
if all(map(x -> haskey(ENV, x), ("DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASS", )))
    @info "Using the DB env vars and assuming it's PG"
    params = PostgreSQLConnectionParams(endpoint=get(ENV, "DB_HOST", "localhost") * ":" * get(ENV, "DB_PORT", "5432"), dbname=get(ENV, "DB_NAME", "postgres"), user=get(ENV, "DB_USER", "postgres"), password=get(ENV, "DB_PASS", "postgres"),)
elseif all(map(x -> haskey(ENV, x), ("PG_ENDPOINT", "PG_DBNAME", "PG_USER", "PG_PASSWORD",)))
    @info "Using the PG env vars"
    params = PostgreSQLConnectionParams(endpoint=get(ENV, "PG_ENDPOINT", "localhost:5432"), dbname=get(ENV, "PG_DBNAME", "postgres"), user=get(ENV, "PG_USER", "postgres"), password=get(ENV, "PG_PASSWORD", "postgres"),)
else
    @info "No default env vars, assuming there is a PG instance available"
    params = PostgreSQLConnectionParams(endpoint="localhost:5432", dbname="postgres", user="postgres", password="postgres")
end

# NOTE: This requires shell `pg_isready`
@test is_pg_ready(params)

# Test battery
if is_pg_ready(params)
    target_test_schema = "PSQLInterface_test"
    table = "best_table_ever"
    table_name = target_test_schema * "." * table
    try
        # Build the schema
        @testset "Schema generation" begin
            @info "Creating the test schema: $target_test_schema"
            @test isnothing(make_schema(params, target_test_schema))
            @test schema_exists(params, "public")  # Is this a valid test?
            @test schema_exists(params, target_test_schema)
        end

        @testset "Make tables" begin
            cols_1 = [Dict("name" => "name", "type" => "text"), Dict("name" => "age", "type" => "int"), Dict("name" => "metadata", "type" => "jsonb"), ]
            @test !table_exists(params, table_name)
            @test isnothing(make_table(params, table_name, cols_1))
            @test table_exists(params, table_name)
            @test get_table_length(params, table_name) == 0
            @test !is_table_populated(params, table_name)

            @test PSQLInterface.get_column_names(params, table_name) == ["name", "age", "metadata"]
        end

        @testset "Populate tables 1: write" begin
            # Write vectors
            col_names = ["name", "age", "metadata"]
            data = [["bill", "ted"], [-76, 50], [[1,2,3], Dict("abc" => 123)]]

            # NEED TO PREPROCESS FOR JSONB
            data[3] = JSON3.write.(data[3])
            @test isnothing(write_to_table(params, data, col_names, table_name))
            @test get_table_length(params, table_name) == 2
            @test is_table_populated(params, table_name)

            # Write DF
            data_df = DataFrame(name=["trinity", "neo", "morphius"], age=[30, 100000, 0], metadata=[[1,2,3], missing, Dict("abc" => 123)])
            # NEED TO PREPROCESS FOR JSONB
            data_df.metadata = JSON3.write.(data_df.metadata)
            @test isnothing(write_to_table(params, data_df, table_name))
            @test get_table_length(params, table_name) == 5
            @test is_table_populated(params, table_name)

            # Write via select string - this is a weirder one
            @test isnothing(write_to_table(params, "SELECT * FROM $(PSQLInterface._delimit_object_names(table_name))", table, target_test_schema))
            @test get_table_length(params, table_name) == 10
            @test is_table_populated(params, table_name)
        end

        @testset "Tuncate tables" begin
            @test isnothing(truncate_table(params, table_name))
            @test get_table_length(params, table_name) == 0
            @test !is_table_populated(params, table_name)
        end

        @testset "Populate tables 2: copy" begin
            data_df = DataFrame(
                name = ["Albert Einstein", "Marie Curie", "Isaac Newton", "Nelson Mandela", "Malala Yousafzai", "Martin Luther King Jr.", "Amelia Earhart", "Rosa Parks", "Mahatma Gandhi", "Jane Austen",
                        "Leonardo da Vinci", "Coco Chanel", "Walt Disney", "Anne Frank", "Pablo Picasso", "Frida Kahlo", "Winston Churchill", "Mother Teresa", "Neil Armstrong", "Marlon Brando",
                        "Oprah Winfrey", "Elvis Presley", "Marilyn Monroe", "Vincent van Gogh", "Stephen Hawking", "Queen Elizabeth II", "William Shakespeare", "Emily Dickinson", "Helen Keller",
                        "Ada Lovelace", "Steve Jobs", "Bill Gates", "Mark Zuckerberg", "Elon Musk", "Serena Williams", "Usain Bolt", "Roger Federer", "Michael Jordan", "Muhammad Ali", "Tiger Woods",
                        "Cristiano Ronaldo", "Lionel Messi", "Venus Williams", "Beyoncé", "Taylor Swift", "Angelina Jolie", "Jennifer Lawrence", "Emma Watson", "Robert Downey Jr.", "Tom Hanks"],
                age = [76, 66, 84, 95, 24, 39, 39, 42, 78, 41, 67, 87, 65, 15, 91, 47, 90, 87, 82, 80, 67, 42, 36, 37, 76, 95, 456, 52, 87, 88, 56, 65, 47, 48, 49, 39, 44, 59, 74, 40,
                       33, 32, 39, 38, 31, 38, 32, 35, 30, 58],
                metadata = map(x -> [x], ["Won Nobel Prize in Physics", "Discovered Radium and Polonium", "Laws of Motion and Universal Gravitation", "Anti-Apartheid Activist and Former President of South Africa",
                            "Youngest Nobel Prize Laureate", "Civil Rights Activist", "Aviation Pioneer and Author", "Civil Rights Activist", "Leader of Indian Independence Movement", "Famous Novelist",
                            "Renaissance Man", "Fashion Designer and Businesswoman", "Co-Founder of Disney", "Diary Writer during Holocaust", "Prominent Painter and Sculptor", "Mexican Artist",
                            "British Prime Minister during World War II", "Missionary and Founder of Missionaries of Charity", "Astronaut and First Person to Walk on the Moon", "Acclaimed Actor",
                            "Media Mogul and Philanthropist", "Rock and Roll Legend", "Iconic Actress and Model", "Dutch Post-Impressionist Painter", "Theoretical Physicist and Cosmologist",
                            "Longest-Reigning Monarch in British History", "Renowned Playwright and Poet", "Prominent American Poet", "Author and Activist", "Mathematician and Writer",
                            "Co-Founder of Apple Inc.", "Co-Founder of Microsoft", "Co-Founder of Facebook", "Entrepreneur and CEO of SpaceX and Tesla", "Tennis Champion", "Fastest Man in the World",
                            "Tennis Legend", "Basketball Superstar", "Boxing Legend", "Golf Champion", "Football Superstar", "Football Superstar", "Tennis Champion", "Singer and Actress",
                            "Award-Winning Singer-Songwriter", "Hollywood Actress and Humanitarian", "Oscar-Winning Actress", "Actress and Activist", "Iron Man in Marvel Cinematic Universe",
                            "Academy Award-Winning Actor"])
            )

            # NEED TO PREPROCESS FOR JSONB
            data_df.metadata = JSON3.write.(data_df.metadata)

            # We need to alter the table so the definition has a PK.
            @warn "Copy methods assume a primary key. TODO: Select other method if no PK."
            with_postgresql(params) do psql
                execute(psql, "ALTER TABLE IF EXISTS $(PSQLInterface._delimit_object_names(table_name)) ADD PRIMARY KEY (name);")
            end

            @test PSQLInterface.get_primary_key_name(params, table_name) == "\"name\""  # Delimited for internal use.

            @test_throws PSQLInterface.PSQLInterfaceException copy_to_table(params, data_df, table_name; on_conflict=:ham)

            @test isnothing(copy_to_table(params, data_df, table_name))  # This is the error version, but we will run it again when populated.
            @test get_table_length(params, table_name) == 50
            @test is_table_populated(params, table_name)

            # This does not error, it will force update
            @test isnothing(copy_to_table(params, data_df, table_name; on_conflict=:error))
            @test get_table_length(params, table_name) == 50
            @test is_table_populated(params, table_name)

            @test isnothing(copy_to_table(params, data_df, table_name; on_conflict=:upsert))
            @test get_table_length(params, table_name) == 50
            @test is_table_populated(params, table_name)

            @test isnothing(copy_to_table(params, data_df, table_name; on_conflict=:nothing))
            @test get_table_length(params, table_name) == 50
            @test is_table_populated(params, table_name)
        end

        @testset "Select from tables" begin
            @testset "DataFrame response" begin
                @testset "Star select" begin
                    test_data = select_from_table(params, table_name)
                    @test isa(test_data, DataFrame)
                    @test nrow(test_data) == 50
                    @test ncol(test_data) == 3
                end

                @testset "Select with renaming" begin
                    test_data = select_from_table(params, table_name; target_column_map=[Dict("name" => "name", "mapping" => "Callsign"), Dict("name" => "age"),])
                    @test isa(test_data, DataFrame)
                    @test nrow(test_data) == 50
                    @test ncol(test_data) == 2
                    @test ("Callsign" in names(test_data))
                    @test !("name" in names(test_data))
                end

                @test_throws PSQLInterface.PSQLInterfaceException select_from_table(params, table_name; target_column_map=[Dict("mapping" => "Callsign"), Dict("name" => "age"),])

                @testset "Filter select" begin
                    test_data = select_from_table(params, table_name; filter_metadata=[Dict("column_name" => "age", "operator" => ">", "value" => "31"),])
                    @test isa(test_data, DataFrame)
                    @test nrow(test_data) == 46
                    @test ncol(test_data) == 3
                end

                # There is no handling for the filters at all, this will error but we should validate it first
                @test_broken select_from_table(params, table_name; filter_metadata=[Dict("colmn_name" => "age", "operator" => ">", "value" => "31"),])
            end

            @testset "Raw response" begin
                @testset "Star select" begin
                    test_data = PSQLInterface.select_from_table_raw(params, table_name)
                    @test num_rows(test_data) == 50
                    @test num_columns(test_data) == 3
                end

                @testset "Select with renaming" begin
                    test_data = PSQLInterface.select_from_table_raw(params, table_name; target_column_map=[Dict("name" => "name", "mapping" => "Callsign"), Dict("name" => "age"),])
                    @test num_rows(test_data) == 50
                    @test num_columns(test_data) == 2
                    @test ("Callsign" in LibPQ.column_names(test_data))
                    @test !("name" in LibPQ.column_names(test_data))
                end

                @test_throws PSQLInterface.PSQLInterfaceException PSQLInterface.select_from_table_raw(params, table_name; target_column_map=[Dict("mapping" => "Callsign"), Dict("name" => "age"),])

                @testset "Filter select" begin
                    test_data = PSQLInterface.select_from_table_raw(params, table_name; filter_metadata=[Dict("column_name" => "age", "operator" => ">", "value" => "31"),])
                    @test num_rows(test_data) == 46
                    @test num_columns(test_data) == 3
                end

                # There is no handling for the filters at all, this will error but we should validate it first
                @test_broken PSQLInterface.select_from_table_raw(params, table_name; filter_metadata=[Dict("colmn_name" => "age", "operator" => ">", "value" => "31"),])
            end
        end

        @testset "Removing from table (occassionally return)" begin
            @testset "DataFrame response returned" begin
                @testset "Filtered but star" begin
                    test_data = PSQLInterface.remove_and_return_from_table(params, table_name; filter_metadata=[Dict("column_name" => "name", "operator" => "=", "value" => "Amelia Earhart")])
                    @test isa(test_data, DataFrame)
                    @test nrow(test_data) == 1
                    @test ncol(test_data) == 3
                    @test get_table_length(params, table_name) == 49
                end

                @testset "Filter and column selected" begin
                    test_data = PSQLInterface.remove_and_return_from_table(
                        params,
                        table_name;
                        filter_metadata=[Dict("column_name" => "name", "operator" => "=", "value" => "Albert Einstein")],
                        returning_columns=[Dict("name" => "name")]
                    )
                    @test isa(test_data, DataFrame)
                    @test nrow(test_data) == 1
                    @test ncol(test_data) == 1
                    @test get_table_length(params, table_name) == 48
                end
                @testset "filter not available" begin
                    test_data = PSQLInterface.remove_and_return_from_table(params, table_name; filter_metadata=[Dict("column_name" => "name", "operator" => "=", "value" => "Amelia Earhart")])
                    @test isa(test_data, DataFrame)
                    @test nrow(test_data) == 0
                    @test ncol(test_data) == 3
                    @test get_table_length(params, table_name) == 48
                end
            end

            @testset "Raw response returned" begin
                @testset "Filtered but star" begin
                    test_data = PSQLInterface.remove_and_return_from_table_raw(params, table_name; filter_metadata=[Dict("column_name" => "name", "operator" => "=", "value" => "Marie Curie")])
                    @test num_rows(test_data) == 1
                    @test num_columns(test_data) == 3
                    @test get_table_length(params, table_name) == 47
                end

                @testset "Filter and column selected" begin
                    test_data = PSQLInterface.remove_and_return_from_table_raw(
                        params,
                        table_name;
                        filter_metadata=[Dict("column_name" => "name", "operator" => "=", "value" => "Isaac Newton")],
                        returning_columns=[Dict("name" => "name")]
                    )
                    @test num_rows(test_data) == 1
                    @test num_columns(test_data) == 1
                    @test get_table_length(params, table_name) == 46
                end
                @testset "filter not available" begin
                    test_data = PSQLInterface.remove_and_return_from_table_raw(params, table_name; filter_metadata=[Dict("column_name" => "name", "operator" => "=", "value" => "Marie Curie")])
                    @test num_rows(test_data) == 0
                    @test num_columns(test_data) == 3
                    @test get_table_length(params, table_name) == 46
                end
            end
            @testset "No data in response returned" begin
                @testset "Filtered but star" begin
                    test_data = PSQLInterface.remove_from_table(params, table_name; filter_metadata=[Dict("column_name" => "name", "operator" => "=", "value" => "Nelson Mandela")])
                    @test num_rows(test_data) == 0
                    @test num_columns(test_data) == 0
                    @test get_table_length(params, table_name) == 45
                end

                @testset "Filter and column selected" begin
                    test_data = PSQLInterface.remove_from_table(
                        params,
                        table_name;
                        filter_metadata=[Dict("column_name" => "name", "operator" => "=", "value" => "Malala Yousafzai")],
                        returning_columns=[Dict("name" => "name")]
                    )
                    @test num_rows(test_data) == 0
                    @test num_columns(test_data) == 0
                    @test get_table_length(params, table_name) == 44
                end
                @testset "filter not available" begin
                    test_data = PSQLInterface.remove_from_table(params, table_name; filter_metadata=[Dict("column_name" => "name", "operator" => "=", "value" => "Nelson Mandela")])
                    @test num_rows(test_data) == 0
                    @test num_columns(test_data) == 0
                    @test get_table_length(params, table_name) == 44
                end
            end
        end

        @testset "Drop tables" begin
            @test table_exists(params, table_name)
            @test isnothing(drop_table(params, table_name))
            @test !table_exists(params, table_name)
        end

    # catch
    finally
        @info "Dropping the test schema: $target_test_schema"
        # Drop the schema
        with_postgresql(params) do psql
            execute(psql, "DROP SCHEMA IF EXISTS $(PSQLInterface._delimit_object_names(target_test_schema)) CASCADE;")
        end

        @test !schema_exists(params, target_test_schema)

    end
end

