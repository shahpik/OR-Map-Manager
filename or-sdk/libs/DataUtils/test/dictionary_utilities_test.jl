
@testset "delete_keys_not_in_list!" begin
    test_value_1 = Dict(i => i for i in 1:10)
    test_value_2 = Dict(i => i for i in 1:20)
    test_value_3 = [1:5...]
    test_value_4 = 2:2:20
    DataUtils.delete_keys_not_in_list!(test_value_1, test_value_3)
    DataUtils.delete_keys_not_in_list!(test_value_2, test_value_4)
    @test length(test_value_1) == 5
    @test !haskey(test_value_1, 6)
    @test get(test_value_1, 5, 0) == 5
    @test get(test_value_1, 10, 0) == 0
    @test length(test_value_2) == 10
    @test !haskey(test_value_2, 5)
    @test get(test_value_2, 11, 0) == 0
    @test get(test_value_2, 18, 0) == 18
end

@testset "pop_from_a_to_b!" begin
    test_value_1 = Dict("$i" => i for i in 1:10)
    test_value_2 = Dict("$i" => i for i in 11:20)
    test_value_3 = Dict("$i" => i for i in 5:10)
    test_value_4 = Dict("$i" => i for i in 25:30)
    DataUtils.pop_from_a_to_b!(test_value_1, test_value_2, "10")
    DataUtils.pop_from_a_to_b!(test_value_3, test_value_4, "10")
    @test !haskey(test_value_1, "10")
    @test haskey(test_value_2, "10")
    @test !haskey(test_value_3, "10")
    @test haskey(test_value_4, "10")
    DataUtils.pop_from_a_to_b!(test_value_2, test_value_1, "20")
    DataUtils.pop_from_a_to_b!(test_value_3, test_value_4, "5")
    @test !haskey(test_value_2, "20")
    @test haskey(test_value_1, "20")
    @test !haskey(test_value_3, "5")
    @test haskey(test_value_4, "5")
end

@testset "merge_dicts_on_matching_key" begin
    @testset "merge_dicts_on_matching_key1" begin
        test_value_1 = Dict("$i" => i for i in 1:10)
        test_value_2 = Dict("$i" => i for i in 10:20)
        evaluation = DataUtils.merge_dicts_on_matching_key(test_value_1, test_value_2, "10")
        @test haskey(evaluation, "20")
    end

    @testset "merge_dicts_on_matching_key2" begin
        test_value_3 = Dict("$i" => i for i in 5:10)
        test_value_4 = Dict("$i" => i for i in 25:30)
        @test_throws KeyError DataUtils.merge_dicts_on_matching_key(test_value_3, test_value_4, "10")
    end
end

@testset "delete_keys!" begin
    test_value_1 = Dict(i => i for i in 1:10)
    test_value_2 = Dict(i => i for i in 1:20)
    test_value_3 = [1:5...]
    test_value_4 = 2:2:20
    DataUtils.delete_keys!(test_value_1, test_value_3)
    DataUtils.delete_keys!(test_value_2, test_value_4)
    @test length(test_value_1) == 5
    @test haskey(test_value_1, 6)
    @test !haskey(test_value_1, 5)
    @test get(test_value_1, 5, 0) == 0
    @test get(test_value_1, 10, 0) == 10
    @test length(test_value_2) == 10
    @test haskey(test_value_2, 5)
    @test !haskey(test_value_2, 6)
    @test get(test_value_2, 11, 0) == 11
    @test get(test_value_2, 18, 0) == 0
end