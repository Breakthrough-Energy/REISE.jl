# Set up input data
test_case = Dict(
    "gen_pmin" => [20, 40, 60],
    "gen_pmax" => [50, 100, 150],
    "gencost" => [
        [2, 0, 0, 3, 1, 4, 7]' ;
        [2, 0, 0, 3, 2, 5, 8]' ;
        [2, 0, 0, 3, 3, 6, 9]'
        ]
    )

# Build expected returns
expected_one_segment = [
    [1, 0, 0, 2, 20, (1*20^2 + 4*20 + 7), 50, (1*50^2 + 4*50 + 7)]' ;
    [1, 0, 0, 2, 40, (2*40^2 + 5*40 + 8), 100, (2*100^2 + 5*100 + 8)]' ;
    [1, 0, 0, 2, 60, (3*60^2 + 6*60 + 9), 150, (3*150^2 + 6*150 + 9)]'
    ]

expected_two_segment = zeros(3, 10)
expected_two_segment[:, 1] .= 1
expected_two_segment[:, 4] .= 3
expected_two_segment[:, 5:6] = expected_one_segment[:, 5:6]
expected_two_segment[1, 7:8] = [35, (1*35^2 + 4*35 + 7),]
expected_two_segment[2, 7:8] = [70, (2*70^2 + 5*70 + 8)]
expected_two_segment[3, 7:8] = [105, (3*105^2 + 6*105 + 9)]
expected_two_segment[:, 9:10] = expected_one_segment[:, 7:8]

expected_all_equal = copy(test_case["gencost"])
expected_all_equal[:, 5:6] .= 0
expected_all_equal[:, 7] = [2707, 20508, 68409]

expected_some_equal = zeros(3, 8)
expected_some_equal[1, 1:7] = expected_all_equal[1, :]
expected_some_equal[2:3, :] = expected_one_segment[2:3, :]


# Actually run tests
@testset "test default" begin
        this_case = copy(test_case)
        gencost_new = REISE.linearize_gencost(this_case)
        @test gencost_new == expected_one_segment
    end

    @testset "test one segment" begin
        this_case = copy(test_case)
        gencost_new = REISE.linearize_gencost(this_case, num_segments=1)
        @test gencost_new == expected_one_segment
    end
    
    @testset "test two segments" begin
        this_case = copy(test_case)
        gencost_new = REISE.linearize_gencost(this_case, num_segments=2)
        @test gencost_new == expected_two_segment
    end
    
    @testset "test all Pmin = Pmax" begin
        this_case = copy(test_case)
        this_case["gen_pmin"] = this_case["gen_pmax"]
        gencost_new = REISE.linearize_gencost(this_case, num_segments=3)
        @test gencost_new == expected_all_equal
    end
    
    @testset "test some Pmin = Pmax" begin
        this_case = copy(test_case)
        this_case["gen_pmin"][1] = this_case["gen_pmax"][1]
        gencost_new = REISE.linearize_gencost(this_case, num_segments=1)
        @test gencost_new == expected_some_equal
    end
