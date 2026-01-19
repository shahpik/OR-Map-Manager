using Test

using DataUtils
using DataStructures

"""

Where possible, separate app files into their own correspending _test files. 
Each test file should be inlcuded like the below file, and all dependencies for 
that file should be included in the _test file too.

"""

@testset "String Utilities Tests" begin include("string_utilities_test.jl") end
@testset "Dictionary Utilities Tests" begin include("dictionary_utilities_test.jl") end
@testset "Encoding Tests" begin include("encoding_test.jl") end
@testset "DataFrame Tests" begin include("dataframe_utilities_test.jl") end
@testset "Expiring Queues" begin include("expiring_queue_test.jl") end

