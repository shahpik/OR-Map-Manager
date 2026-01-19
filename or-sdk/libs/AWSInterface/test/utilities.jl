include("../src/utilities.jl")

@testset "s3" begin
    path_slash = "s3://bucket/path/"
    path_noslash = "s3://bucket/path"
    bad_path = "s3 ://bucket/path/"

    # Format tests
    @test is_valid_s3_path(path_slash, :optional)
    @test is_valid_s3_path(path_slash, :required)
    @test !is_valid_s3_path(path_slash, :disallowed)

    @test is_valid_s3_path(path_noslash, :optional)
    @test !is_valid_s3_path(path_noslash, :required)
    @test is_valid_s3_path(path_noslash, :disallowed)

    @test !is_valid_s3_path(bad_path, :optional)
    @test !is_valid_s3_path(bad_path, :required)
    @test !is_valid_s3_path(bad_path, :disallowed)

end
