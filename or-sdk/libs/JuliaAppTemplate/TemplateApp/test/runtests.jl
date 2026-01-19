using JuliaAppTemplate
using HTTP
using Test

"""

Where possible, separate app files into their own correspending _test files. 
Each test file should be inlcuded like the below file, and all dependencies for 
that file should be included in the _test file too.

"""

@testset "Exceptions" begin include("exceptions_test.jl") end
@testset "Resource" begin include("resource_test.jl") end
@testset "ExampleTests" begin include("example_test.jl") end

@testset "ServiceDependencyTests" begin
    @test JuliaAppTemplate.Resource.Dependency.validate_service_deps(JuliaAppTemplate.Resource.Dependency.PROJECTDATA)
end