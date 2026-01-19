@testset "dataframe_typed" begin
    
    mapping = Dict(
        "test_col_1" => Dict(
            "dtype" => :String,
            "nullable" => false
            ),
        "test_col_2" => Dict(
            "dtype" => :Int64,
            "nullable" => true
            ),
        "test_col_3" => Dict(
            "dtype" => :Float64,
            )
    )

    df = DataUtils.typed_dataframe(mapping)
    @test df.test_col_1 == String[]
    @test df.test_col_2 == Int64[]

    push!(df, Dict(
        "test_col_1" => "Test",
        "test_col_2" => 1,
        "test_col_3" => 1.2
        )
    )
    @test df.test_col_1[1] == "Test"
    @test df.test_col_2[1] == 1
    @test df.test_col_3[1] == 1.2

    push!(df, Dict(
        "test_col_1" => "Test_0",
        "test_col_2" => nothing,
        "test_col_3" => nothing
        )
    )
    @test df.test_col_1[2] == "Test_0"
    @test df.test_col_2[2] === nothing
    @test df.test_col_3[2] === nothing
    
    @test_throws MethodError push!(df, Dict(
        "test_col_1" => nothing,
        "test_col_2" => nothing,
        "test_col_3" => nothing
        )
    )

    df = DataUtils.replace_df(df, nothing, missing)
    @test df.test_col_2[2] === missing
    @test df.test_col_3[2] === missing
end

