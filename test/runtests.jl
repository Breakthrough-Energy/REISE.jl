using Test

include("../src/REISE.jl")

@testset "gencost linearization" begin
    include("./test_linearize_gencost.jl")
end
