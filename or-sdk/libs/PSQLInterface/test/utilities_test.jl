@warn "Not all utilities are currently tested explicitly. TODO: More tests, more robustness, etc."

@testset "column generation" begin
    @test PSQLInterface._generate_column_line("pizza", Dict("type" => "pineapple")) == "pizza PINEAPPLE"
    @test PSQLInterface._generate_column_line(
        "pizza",
        Dict("type" => "pineapple", "not_null" => true, "unique" => true, "primary_key" => true)
    ) == "pizza PINEAPPLE UNIQUE PRIMARY KEY NOT NULL"
    @test PSQLInterface._generate_column_line(
        "pizza",
        Dict("type" => "pineapple", "not_null" => false, "unique" => false, "primary_key" => false)
    ) == "pizza PINEAPPLE"
    @test PSQLInterface._generate_column_line(
        "pizza",
        Dict("type" => "pineapple", "not_null" => true, "unique" => false, "primary_key" => false)
    ) == "pizza PINEAPPLE NOT NULL"
    @test PSQLInterface._generate_column_line(
        "pizza",
        Dict("type" => "pineapple", "not_null" => false, "unique" => true, "primary_key" => false)
    ) == "pizza PINEAPPLE UNIQUE"
    @test PSQLInterface._generate_column_line(
        "pizza",
        Dict("type" => "pineapple", "not_null" => false, "unique" => false, "primary_key" => true)
    ) == "pizza PINEAPPLE PRIMARY KEY"
    @test_throws PSQLInterface.PSQLInterfaceException PSQLInterface._generate_column_line("pizza", Dict("not_null" => true))
end

# Why did I add this?
@test PSQLInterface.get_value_str("aaa") == "'aaa'"
@test PSQLInterface.get_value_str(123) == "123"

@testset "multireplace" begin
    # Note, this does NOT operate in the same way as replace in 1.7 onwards, apparently
    @test PSQLInterface.multi_replace("aabbcc", ["aa" => "cc", "bb" => "cc"]) == "cccccc"
    @test PSQLInterface.multi_replace("aabbcc", ["cc" => "cc", "bb" => "cc"]) == "aacccc"
    @test PSQLInterface.multi_replace("aabbcc", ["aa" => "bb", "bb" => "cc"]) == "cccccc"
    @test PSQLInterface.multi_replace("aabbcc", ["aa" => "bb", "bb" => "aa"]) == "aaaacc"
    @test PSQLInterface.multi_replace("aabbcc", ["11" => "22", "33" => "44"]) == "aabbcc"
    @test PSQLInterface.multi_replace("aabbcc", ["aa" => "bb", "bb" => "aa", "aa" => "bb"]) == "bbbbcc"
    @test PSQLInterface.multi_replace("aabbcc", ["a" => "123bb", "bb" => "aa"]) == "123aa123aaaacc"
    @test PSQLInterface.multi_replace("aabbcc", ["aa" => "", "bb" => ""]) == "cc"
    #This inserts "aa" around every other letter
    @test PSQLInterface.multi_replace("aabbcc", ["aa" => "", "" => "aa"]) == "aabaabaacaacaa"
end

@testset "delimit" begin
    @test PSQLInterface._delimit_object_names("aaa") == "\"aaa\""
    @test PSQLInterface._delimit_object_names("\"aaa\"") == "\"aaa\""
    @test PSQLInterface._delimit_object_names("aaa.bbb") == "\"aaa\".\"bbb\""
    @test PSQLInterface._delimit_object_names("aaa.bbb.ccc") == "\"aaa\".\"bbb\".\"ccc\""
    @test PSQLInterface._delimit_object_names("aaa.bbb.ccc.ddd") == "\"aaa\".\"bbb\".\"ccc\".\"ddd\""
    @test PSQLInterface._delimit_object_names("aaa.bbb.ccc.ddd.eee") == "\"aaa\".\"bbb\".\"ccc\".\"ddd\".\"eee\""
    @test PSQLInterface._delimit_object_names("\"aaa\".\"bbb\".\"ccc\".ddd.eee") == "\"aaa\".\"bbb\".\"ccc\".\"ddd\".\"eee\""
    @test PSQLInterface._delimit_object_names("aaa.\"bbb\".\"ccc\".\"ddd\".eee") == "\"aaa\".\"bbb\".\"ccc\".\"ddd\".\"eee\""
    @test PSQLInterface._delimit_object_names("aaa.bbb.ccc.ddd.eee") == "\"aaa\".\"bbb\".\"ccc\".\"ddd\".\"eee\""
    @test PSQLInterface._delimit_object_names("aaa.bbb.ccc.ddd.eee") == "\"aaa\".\"bbb\".\"ccc\".\"ddd\".\"eee\""
    @test PSQLInterface._delimit_object_names("aaa.bbb.ccc.ddd.eee") == "\"aaa\".\"bbb\".\"ccc\".\"ddd\".\"eee\""
    @test PSQLInterface._delimit_object_names("aaa.\"bbb\".ccc.ddd.eee") == "\"aaa\".\"bbb\".\"ccc\".\"ddd\".\"eee\""

    @test_broken PSQLInterface._delimit_object_names("aaa\"") == "\"aaa\""
    @test_broken PSQLInterface._delimit_object_names("aaa.bbb\".ccc.ddd.eee") == "\"aaa\".\"bbb\".\"ccc\".\"ddd\".\"eee\""
    @test_broken PSQLInterface._delimit_object_names("\"aaa") == "\"aaa\""
    @test_broken PSQLInterface._delimit_object_names("aaa.\"bbb.ccc.ddd.eee") == "\"aaa\".\"bbb\".\"ccc\".\"ddd\".\"eee\""
end