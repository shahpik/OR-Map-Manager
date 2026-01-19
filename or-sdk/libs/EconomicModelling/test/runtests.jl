using Test
using EconomicModelling

@testset "Network modelling" begin
    @testset "calc_f_aud_congestion" begin
        @test iszero(EconomicModelling.calc_f_aud_congestion(100, 100, 50, 0.1))
        @test EconomicModelling.calc_f_aud_congestion(75, 100, 50, 2) == 75.38
        @test EconomicModelling.calc_f_aud_congestion(50, 100, 50, 3) == 467.36
        @test EconomicModelling.calc_f_aud_congestion(50, 60, 50, 4) == 305.88
        @test EconomicModelling.calc_f_aud_congestion(75, 100, 10, 4) == 30.15
        @test EconomicModelling.calc_f_aud_congestion(50, 100, 10, 5) == 155.79
        @test EconomicModelling.calc_f_aud_congestion(50, 60, 10, 2) == 30.59
        @test EconomicModelling.calc_f_aud_congestion(0, 100, 0, 0.3) == 0.0
        @test EconomicModelling.calc_f_aud_congestion(0, 60, 0, 0.4) == 0.0
    end

    @testset "delay_cost" begin
        @test round(EconomicModelling.delay_cost(), digits=2) == 0.0
        @test round(EconomicModelling.delay_cost(v_act=50.0, v_nom=60.0, total_vehicles=10.0, l_link=0.2), digits=2) == 6.9
    end

    @testset "voc_cost_estimate" begin
        @test round(EconomicModelling.voc_cost_estimate(), digits=2) == 0.0
        @test round(EconomicModelling.voc_cost_estimate(v_act=50.0, v_nom=60.0, total_vehicles=10.0), digits=2) == 5.85
    end

    @testset "_speed_proxy_delay" begin
        @test iszero(EconomicModelling._speed_proxy_delay(1.1, 1.0))
        @test iszero(EconomicModelling._speed_proxy_delay(1, 1))
        @test EconomicModelling._speed_proxy_delay(0.0, 1.0) == 300.0
        @test EconomicModelling._speed_proxy_delay(0.5, 1.0) == 150.0
    end

    @testset "_n_vehicles" begin
        delay_prop_vehicles = missing
        delay_prop_vehicles = EconomicModelling.get_veh_proportions(delay_prop_vehicles, :delay)
        @test isa(EconomicModelling._n_vehicles(1.0, delay_prop_vehicles), Vector)
        @test round(sum(EconomicModelling._n_vehicles(50.0, delay_prop_vehicles)), digits=2) == 50.0

        voc_prop_vehicles = missing
        voc_prop_vehicles = EconomicModelling.get_veh_proportions(voc_prop_vehicles, :voc)
        @test isa(EconomicModelling._n_vehicles(1.0, voc_prop_vehicles), Vector)
        @test round(sum(EconomicModelling._n_vehicles(50.0, voc_prop_vehicles)), digits=2) == 50.0
    end

    @testset "_cost_velocity_vehicle_1" begin
        @test isa(EconomicModelling._cost_velocity_vehicle_1(0), Vector)
        @test round(sum(EconomicModelling._cost_velocity_vehicle_1(0)), digits=2) == 0.0
        @test round(sum(EconomicModelling._cost_velocity_vehicle_1(0.1)), digits=2) == 747472.61
        @test round(sum(EconomicModelling._cost_velocity_vehicle_1(1)), digits=2) == 76339.5
        @test round(sum(EconomicModelling._cost_velocity_vehicle_1(10)), digits=2) == 9226.19
        @test round(sum(EconomicModelling._cost_velocity_vehicle_1(100)), digits=2) == 2514.86
    end

    @testset "_cost_velocity_vehicle_2" begin
        @test isa(EconomicModelling._cost_velocity_vehicle_2(0), Vector)
        @test round(sum(EconomicModelling._cost_velocity_vehicle_2(0)), digits=2) == 2387.24
        @test round(sum(EconomicModelling._cost_velocity_vehicle_2(0.1)), digits=2) == 2386.09
        @test round(sum(EconomicModelling._cost_velocity_vehicle_2(1)), digits=2) == 2375.87
        @test round(sum(EconomicModelling._cost_velocity_vehicle_2(10)), digits=2) == 2282.71
        @test round(sum(EconomicModelling._cost_velocity_vehicle_2(100)), digits=2) == 2264.46
    end

    @testset "get_veh_proportions" begin
        veh_proportions = missing
        @test EconomicModelling.get_veh_proportions(veh_proportions, :delay) == [50.03, 30.66, 15.68, 0.0, 0.89, 0.83, 0.7, 0.42, 0.42, 0.05, 0.05, 0.05, 0.05, 0.21, 0.38, 0.0, 0.0, 0.0, 0.0, 0.0]
        @test EconomicModelling.get_veh_proportions(veh_proportions, :voc) == [26.9, 26.9, 26.9, 15.68, 0.0, 0.89, 0.83, 0.7, 0.42, 0.05, 0.05, 0.05, 0.05, 0.21, 0.38, 0.0, 0.0, 0.0, 0.0, 0.0]
        
        veh_proportions = Dict(
            "Small Car" => 15.0,
            "Medium Car" => 15.0,
            "Large Car" => 15.0,
            "Courier Van-Utility" => 15.0,
            "4WD Mid Size Petrol" => 15.0,
            "Light Rigid" => 2.0,
            "Medium Rigid" => 2.0,
            "Heavy Rigid" => 2.0,
            "Heavy Bus" => 2.0,
            "Artic 4 Axle" => 2.0,
            "Artic 5 Axle" => 1.5,
            "Artic 6 Axle" => 1.5,
            "Rigid and 5 Axle Dog" => 1.5,
            "B-Double" => 1.5,
            "Twin steer and 5 Axle Dog" => 1.5,
            "A-Double" => 1.5,
            "B Triple" => 1.5,
            "A B Combination" => 1.5,
            "A-Triple" => 1.5,
            "Double B-Double" => 1.5,
        )
        @test EconomicModelling.get_veh_proportions(veh_proportions, :voc) == [15.0, 15.0, 15.0, 15.0, 15.0, 2.0, 2.0, 2.0, 2.0, 2.0, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]
    end
end