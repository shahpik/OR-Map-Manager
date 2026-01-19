@testset "getsubfield" begin
    type_field = Dict("type" => "type_field")
    @test GQLInterface.getsubfield(type_field) == "type_field"
    ofType_field = Dict("type" => "ofType_field")
    @test GQLInterface.getsubfield(ofType_field) == "ofType_field"
    not_a_field = Dict()
    @test_throws GQLInterface.GraphQLClientException GQLInterface.getsubfield(not_a_field)
end

@testset "is tests" begin
    # istype
    generic_field = Dict("type" => Dict("kind" => "CUSTOM_TYPE"))
    @test GQLInterface.istype(generic_field, "CUSTOM_TYPE")
    @test !GQLInterface.istype(generic_field, "NOT_CUSTOM_TYPE")
    generic_field = Dict("ofType" => Dict("kind" => "CUSTOM_TYPE"))
    @test GQLInterface.istype(generic_field, "CUSTOM_TYPE")
    @test !GQLInterface.istype(generic_field, "NOT_CUSTOM_TYPE")

    # specific, not nested
    object = Dict("type" => Dict("kind" => "OBJECT"))
    @test GQLInterface.isobject(object)
    non_null = Dict("type" => Dict("kind" => "NON_NULL"))
    @test GQLInterface.isnonnull(non_null)
    list = Dict("type" => Dict("kind" => "LIST"))
    @test GQLInterface.islist(list)
    scalar = Dict("type" => Dict("kind" => "SCALAR"))
    @test GQLInterface.isscalar(scalar)
    input_object = Dict("type" => Dict("kind" => "INPUT_OBJECT"))
    @test GQLInterface.isinputobject(input_object)
    enum = Dict("type" => Dict("kind" => "ENUM"))
    @test GQLInterface.isenum(enum)

    # specific and nested
    nonnull_input_object = Dict(
        "type" => Dict(
            "kind" => "NON_NULL",
            "ofType" => Dict("kind" => "INPUT_OBJECT")
        )
    )
    @test GQLInterface.is_nonnull_input_object(nonnull_input_object)
    not_a_nonnull_input_object = Dict(
        "type" => Dict(
            "kind" => "NON_NULL",
            "ofType" => Dict("kind" => "SCALAR")
        )
    )
    @test !GQLInterface.is_nonnull_input_object(not_a_nonnull_input_object)
    @test GQLInterface.isroottypescalar(not_a_nonnull_input_object)
    listofobjects = Dict(
        "type" => Dict(
            "kind" => "LIST",
            "ofType" => Dict("kind" => "OBJECT")
        )
    )
    @test GQLInterface.isroottypeobject(listofobjects)
    @test !GQLInterface.isroottypeenum(listofobjects)
    listofenums = Dict(
        "type" => Dict(
            "kind" => "LIST",
            "ofType" => Dict("kind" => "ENUM")
        )
    )
    @test GQLInterface.isroottypeenum(listofenums)
    @test !GQLInterface.isroottypeobject(listofenums)
    nonnull_enum_list = build_type("kind", "Fieldname",
        type=build_type("NON_NULL", "",
            ofType=build_type("LIST", "",
                ofType=build_type("ENUM",""))))
    @test GQLInterface.isroottypeenum(nonnull_enum_list)
    nonnull_object_list = build_type("kind", "Fieldname",
        type=build_type("NON_NULL", "",
            ofType=build_type("LIST", "",
                ofType=build_type("OBJECT",""))))
    @test GQLInterface.isroottypeobject(nonnull_object_list)
end

@testset "get_field_type_string and getjuliatype" begin
    # SCALAR
    arg = build_arg("SCALAR", nothing, "String", nothing)
    @test GQLInterface.get_field_type_string(arg) == "String"
    @test GQLInterface.getroottype(arg) == "String"
    @test GQLInterface.getjuliatype(arg) == String
    
    # Custom scalar
    scalar_dict = merge(
        GQLInterface.GQL_DEFAULT_SCALAR_TO_JULIA_TYPE,
        Dict("CUSTOM_FLOAT_32" => Float32),
    )
    arg = build_arg("SCALAR", nothing, "CUSTOM_FLOAT_32", nothing)
    @test GQLInterface.get_field_type_string(arg) == "CUSTOM_FLOAT_32"
    @test GQLInterface.getroottype(arg) == "CUSTOM_FLOAT_32"
    @test GQLInterface.getjuliatype(arg; scalar_types=scalar_dict) == Float32

    # INPUT_OBJECT
    arg = build_arg("INPUT_OBJECT", nothing, "MyObject", nothing)
    @test GQLInterface.get_field_type_string(arg) == "MyObject"
    @test GQLInterface.getroottype(arg) == "MyObject"
    @test GQLInterface.getjuliatype(arg) == GQLInterface.InputObject
    
    # ENUM
    arg = build_arg("ENUM", nothing, "MyEnum", nothing)
    @test GQLInterface.get_field_type_string(arg) == "MyEnum"
    @test GQLInterface.getroottype(arg) == "MyEnum"
    @test GQLInterface.getjuliatype(arg) == String
    
    # NON_NULL
    arg = Dict(
        "name" => "MyArg",
        "defaultValue" =>  nothing,
        "description" =>  nothing,
        "type" => build_type("NON_NULL", nothing; ofType=build_type("SCALAR", "String"))
    )
    @test GQLInterface.get_field_type_string(arg) == "String!"
    @test GQLInterface.getroottype(arg) == "String"
    @test GQLInterface.getjuliatype(arg) == String

    # LIST
    arg = Dict(
        "name" => "MyArg",
        "defaultValue" =>  nothing,
        "description" =>  nothing,
        "type" => build_type("LIST", nothing; ofType=build_type("SCALAR", "Float"))
    )
    @test GQLInterface.get_field_type_string(arg) == "[Float]"
    @test GQLInterface.getroottype(arg) == "Float"
    @test GQLInterface.getjuliatype(arg) == Vector{Float64}

    # NESTED NON-NULL LIST
    arg = Dict(
        "name" => "MyArg",
        "defaultValue" =>  nothing,
        "description" =>  nothing,
        "type" => build_type("NON_NULL", nothing; 
            ofType=build_type("LIST", nothing,
                ofType=build_type("LIST", nothing,
                    ofType=build_type("ENUM", "MyEnum")))))
    @test GQLInterface.get_field_type_string(arg) == "[[MyEnum]]!"
    @test GQLInterface.getroottype(arg) == "MyEnum"
    @test GQLInterface.getjuliatype(arg) == Vector{Vector{String}}

    # OBJECT
    arg = build_arg("OBJECT", nothing, "MyObject", nothing)
    @test GQLInterface.get_field_type_string(arg) == "MyObject"
    @test GQLInterface.getroottype(arg) == "MyObject"
    @test GQLInterface.getjuliatype(arg) == GQLInterface.Object

    # Errors - not handled types
    arg = build_arg("UNION", nothing, "MyEnum", nothing)
    @test_throws GQLInterface.GraphQLClientException GQLInterface.get_field_type_string(arg)
    @test_throws GQLInterface.GraphQLClientException GQLInterface.getjuliatype(arg)
    arg = build_arg("INTERFACE", nothing, "MyEnum", nothing)
    @test_throws GQLInterface.GraphQLClientException GQLInterface.get_field_type_string(arg)
    @test_throws GQLInterface.GraphQLClientException GQLInterface.getjuliatype(arg)

    # Errors - unrecognised scalars
    arg = build_arg("SCALAR", nothing, "NOT_A_DEFAULT", nothing)
    @test_throws ArgumentError GQLInterface.getjuliatype(arg)
    arg = build_arg("SCALAR", nothing, "NOT_IN_CUSTOM_DICT", nothing)
    @test_throws ArgumentError GQLInterface.getjuliatype(arg; scalar_types=scalar_dict)
end

@testset "getroottypefield" begin
    type = build_type("NON_NULL", "name",
        type=build_type("LIST", nothing,
            ofType=build_type("LIST", nothing,
                ofType=build_type("SCALAR", "Boolean"))))
    @test GQLInterface.getroottypefield(type) == build_type("SCALAR", "Boolean")
    type = build_type("LIST", "name",
        type=build_type("LIST", nothing,
            ofType=build_type("LIST", nothing,
                ofType=build_type("SCALAR", "Boolean"))))
    @test GQLInterface.getroottypefield(type) == build_type("SCALAR", "Boolean")
    type = build_type("LIST", "name", type=build_type("SCALAR", "Boolean"))
    @test GQLInterface.getroottypefield(type) == build_type("SCALAR", "Boolean")
end

@testset "getroottypefield" begin
    type = build_type("NON_NULL", "name",
        type=build_type("LIST", nothing,
            ofType=build_type("LIST", nothing,
                ofType=build_type("SCALAR", "Boolean"))))
    @test GQLInterface.getroottypefield(type) == build_type("SCALAR", "Boolean")
    type = build_type("LIST", "name",
        type=build_type("LIST", nothing,
            ofType=build_type("LIST", nothing,
                ofType=build_type("SCALAR", "Boolean"))))
    @test GQLInterface.getroottypefield(type) == build_type("SCALAR", "Boolean")
    type = build_type("LIST", "name", type=build_type("SCALAR", "Boolean"))
    @test GQLInterface.getroottypefield(type) == build_type("SCALAR", "Boolean")
end