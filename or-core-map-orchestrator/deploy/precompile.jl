import MapOrchestrator
using TestEnv
TestEnv.activate("MapOrchestrator") do
    include(joinpath(dirname(pathof(MapOrchestrator)), "../test", "runtests.jl"))
end
