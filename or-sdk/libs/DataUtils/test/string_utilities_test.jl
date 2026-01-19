@testset "camel_to_snake" begin
    @testset "camel_to_snake1" begin
        test_string = "anExcellentGoodTestString"
        expected_string = "an_excellent_good_test_string"
        @test DataUtils.camel_to_snake(test_string) == expected_string
        @test DataUtils.camel_to_snake(expected_string) == expected_string
    end

    @testset "camel_to_snake2" begin
        test_string = "asdAsd"
        expected_string = "asd_asd"
        @test DataUtils.camel_to_snake(test_string) == expected_string
        @test DataUtils.camel_to_snake(expected_string) == expected_string
    end
end

@testset "snake_to_camel" begin
    @testset "snake_to_camel1" begin
        test_string = "an_excellent_good_test_string"
        expected_string = "anExcellentGoodTestString"
        @test DataUtils.snake_to_camel(test_string) == expected_string
        @test DataUtils.snake_to_camel(expected_string) == expected_string
    end

    @testset "snake_to_camel2" begin
        test_string = "asd_asd"
        expected_string = "asdAsd"
        @test DataUtils.snake_to_camel(test_string) == expected_string
        @test DataUtils.snake_to_camel(expected_string) == expected_string
    end
end

@testset "tryparse_string_to_number" begin
    test_value_1 = "1"
    test_value_2 = "1.02"
    test_value_3 = "asdf"
    expected_value_1 = 1
    expected_value_2 = 1.02
    expected_value_3 = "asdf"
    @test DataUtils.tryparse_string_to_number(test_value_1) == expected_value_1
    @test DataUtils.tryparse_string_to_number(test_value_2) == expected_value_2
    @test DataUtils.tryparse_string_to_number(test_value_3) == expected_value_3
end