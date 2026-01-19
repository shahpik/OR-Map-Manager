

# Conversion tests
@testset "convert_vec_to_num_types" begin

    @test Blobify.convert_vec_to_number_type(Any[7396155681, 7396155684, 5085674286]) == [7396155681,7396155684,5085674286]
    @test Blobify.convert_vec_to_number_type(Any["7396155681", "7396155684", "5085674286"]) == [7396155681,7396155684,5085674286] 
    @test Blobify.convert_vec_to_number_type(String["7396155681", "7396155684", "5085674286"]) == [7396155681,7396155684,5085674286]
    @test Blobify.convert_vec_to_number_type(Int[7396155681, 7396155684, 5085674286]) == [7396155681,7396155684,5085674286]
    @test Blobify.convert_vec_to_number_type(Any[7396155681, 7396155684, 5085674286]; to_type=Int64) == [7396155681,7396155684,5085674286]
    @test Blobify.convert_vec_to_number_type(Any[7396155681, 7396155684, 5085674286]; to_type=Int32) == [7396155681,7396155684,5085674286]
    @test Blobify.convert_vec_to_number_type(Any[7396155681, 7396155684, 5085674286]; to_type=Float64) == [7.396155681e9, 7.396155684e9, 5.085674286e9]
end