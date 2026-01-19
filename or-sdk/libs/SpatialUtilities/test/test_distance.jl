
@testset "distance test" begin
    @test pt_dist_to_line(0,0, 2,2, 1,1) == 0
    @test pt_dist_to_line(0,0, 2,2, 3,2) == 1.0  # should not be 0, or else it's doing the infinity thing
    @test pt_dist_to_line(2,2, 0,0, 3,2) == 1.0  # reversing poitns also works
    @test pt_dist_to_line(0,0, 2,2, 1,0) == sqrt(2)/2 
    @test pt_dist_to_line(-1, -1, 2,2, 1, -1) == sqrt(2)
    @test pt_dist_to_line(-1, -1, -1,-1, 1, -1) == 2  # same point, also works
end
