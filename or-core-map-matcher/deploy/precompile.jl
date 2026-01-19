import MapMatcher
using TestEnv
TestEnv.activate("MapMatcher") do
    include(joinpath(dirname(pathof(MapMatcher)), "../test", "runtests.jl"))
end
