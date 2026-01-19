import JuliaAppTemplate
using TestEnv
TestEnv.activate("JuliaAppTemplate") do
    include(joinpath(dirname(pathof(JuliaAppTemplate)), "../test", "runtests.jl"))
end
