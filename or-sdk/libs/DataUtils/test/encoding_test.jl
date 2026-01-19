types = [
    UInt128,
    UInt16,
    UInt32,
    UInt64,
    UInt8,
    Int128,
    Int16,
    Int32,
    Int64,
    Int8,
    Float16,
    Float32,
    Float64,
    Complex{Int64},
    Complex{Float64},
]

sample_string = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce sed dui ac nunc laoreet sagittis eu vel dui. Integer neque turpis, luctus vel cursus ac, euismod non massa."

function test_vec(vec, T)
    for zlib in (true, false)
        str = @inferred encode(vec, zlib)
        @test decode(str, T, zlib) == vec
        @inferred decode(str, T, zlib) 
    end
    local str
    str = DataUtils.initialise_encoding_codec() do codec
        @inferred encode(vec, codec)
    end
    DataUtils.initialise_decoding_codec() do codec
        @test decode(str, T, codec) == vec
        @inferred decode(str, T, codec)
    end
end
function test_vec(vec)
    str = @inferred encode(vec)
    @test decode(str) == vec
    @inferred decode(str)

    local str
    str = DataUtils.initialise_encoding_codec() do codec
        @inferred encode(vec; codec)
    end

    DataUtils.initialise_decoding_codec() do codec
        @test decode(str; codec) == vec
        @inferred decode(str; codec)
    end
end

@testset "encode and decode" begin
    # Normal use for various types
    for type in types
        vec = rand(type, rand(10:20))
        test_vec(vec, type)
    end
    vec = [Rational(i,j) for (i, j) in zip(rand(Int, 10), rand(Int, 10))]
    test_vec(vec, Rational{Int64})

    # Empty vector
    for type in types
        vec = type[]
        test_vec(vec, type)
    end

    # Strings
    test_vec(sample_string)
end

@testset "serialize and deserialize" begin
    variables = [
        UInt(1),
        Int,
        1.0,
        "string",
        [Dict("a" => 1)]
    ]
    for variable in variables
        @test base64_deserialize(base64_serialize(variable)) == variable
    end
end

function test_vec_coordinates(vec, T)
    # Cannot go from a Float64 vector value to Float32 encoding and expect original accuracy
    if T isa Float32
        for compress in (true, false)
            str = @inferred encode_coordinates(vec, compress=compress)
            @test decode_coordinates(str, decompress=compress) == vec
            @inferred decode_coordinates(str, decompress=compress) 
        end
        local str
        str = DataUtils.initialise_encoding_codec() do codec
            @inferred encode_coordinates(vec, compress=true, codec=codec)
        end
        DataUtils.initialise_decoding_codec() do codec
            @test decode_coordinates(str, decompress=true, codec=codec) == vec
            @inferred decode_coordinates(str, decompress=true, codec=codec)
        end
    end

    for compress in (true, false)
        str = @inferred encode_coordinates(vec, compress=compress, precision64=true)
        @test decode_coordinates(str, decompress=compress, precision64=true) == vec
        @inferred decode_coordinates(str, decompress=compress, precision64=true) 
    end
    local str
    str = DataUtils.initialise_encoding_codec() do codec
        @inferred encode_coordinates(vec, compress=true, codec=codec, precision64=true)
    end
    DataUtils.initialise_decoding_codec() do codec
        @test decode_coordinates(str, decompress=true, codec=codec, precision64=true) == vec
        @inferred decode_coordinates(str, decompress=true, codec=codec, precision64=true)
    end
end

@testset "encode_coordinates and decode_coordinates" begin
    coordinates1 = [1.0, 2.0, 3.0, 4.0]
    coordinates2 = [[1.0, 2.0], [3.0, 4.0]]
    @test encode_coordinates(coordinates1) == encode_coordinates(coordinates2)
    @test encode_coordinates(coordinates1, precision64=true) == encode_coordinates(coordinates2, precision64=true)

    for _ in 1:10
        coordinates3 = [[rand(Float32)*360-180, rand(Float32)*180-0] for _ in 1:rand(10:50)]
        test_vec_coordinates(coordinates3, Float32)

        coordinates4 = [[rand(Float64)*360-180, rand(Float64)*180-0] for _ in 1:rand(10:50)]
        test_vec_coordinates(coordinates4, Float64)
    end
end
