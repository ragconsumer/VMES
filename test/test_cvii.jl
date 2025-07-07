@testset "Candidate-Voter Instruction" begin

    @testset "Instruction Strategies" begin
        @test instruct_votes(2, bulletinstruction, 2, 4, irv) == [0 0
                                                                3 3
                                                                0 0
                                                                0 0]
        @test instruct_votes(2, abstaininstruction, 2, 3, irv) == [0 0
                                                                0 0
                                                                0 0]
        @test instruct_votes(2, AssistInstruction(3), 2, 4, star, 4) == [0 0
                                                                        5 5
                                                                        0 0
                                                                        3 3]
        @test instruct_votes(2, CopyNaturalSupporterInstruction(hon), 2, 3, irv, [3 0 1 
                                                                            2 3 4
                                                                            1 1 5]) == [0 0
                                                                                        2 2
                                                                                        1 1]
    end

    @testset "Instruction Selectors" begin
        @test VMES.select_instructors_and_trackees(ArbitrarySelector(2,2)) == (
            [1,2], [1,2], [[2],[1]])
        @test VMES.select_instructors_and_trackees(ArbitrarySelector(1,2)) == (
            [1], [1,2], [[2]])
        @test VMES.select_instructors_and_trackees(OnePositionalSelector(nothing, 2), approval, [0.2,0.4,0.3,0.1]) == (
            [3], [3], [[]])
        @test VMES.select_instructors_and_trackees(TwoPositionalSelectorOneWay(nothing, 2, 3), approval, [0.2,0.4,0.3,0.1]) == (
            [3], [3,1], [[1]])
        @test VMES.select_instructors_and_trackees(TwoPositionalSelectorOneWay(nothing, 2, 3), star,
                [0.2;0.4;0.3;0.1;;0.;.45;.55;0.]) == ([2], [2,1], [[1]])
        @test VMES.select_instructors_and_trackees(TwoPositionalSelectorTwoWay(nothing, 2, 3), approval, [0.2,0.4,0.3,0.1]) == (
            [3,1], [3,1], [[1],[3]])
    end

    @testset "Poll Admin" begin
        arglist = [([star, score], [ElectorateStrategy(hon, 20)],
                    [bulletinstruction, CopyNaturalSupporterInstruction(hon)], repeat([ArbitrarySelector(2,2)],3),
                    [[AssistInstruction(3)], [AssistInstruction(2)], [AssistInstruction(1)]])]
        admininput = VMES.getadminpollsinput_instruction(arglist, 0.1, 0.0, 0.1, 0.0)
        @test length(admininput[1]) == 21
        arglist = [([star, score], [ElectorateStrategy(hon, 20), ElectorateStrategy(bullet, 20)],
                    [bulletinstruction, CopyNaturalSupporterInstruction(hon)], repeat([ArbitrarySelector(2,2)],3),
                    [[AssistInstruction(3)], [AssistInstruction(2)], [AssistInstruction(1)]])]
        admininput = VMES.getadminpollsinput_instruction(arglist, 0.1, 0.0, 0.1, 0.0)
        @test length(admininput[1]) == 42
        arglist = [([star], [ElectorateStrategy(hon, 20)],
                    [bulletinstruction], repeat([ArbitrarySelector(2,2)],3),
                    [[AssistInstruction(3)], [AssistInstruction(2)], [AssistInstruction(1)]])]
        admininput = VMES.getadminpollsinput_instruction(arglist, 0.1, 0.0, 0.1, 0.0)
        @test length(admininput[1]) == 8
    end

    @testset "CVII" begin
        niter = 20
        arglist = [([star, score, irv], [ElectorateStrategy(hon, 5)],
                    [bulletinstruction], [ArbitrarySelector(2,2),ArbitrarySelector(1,2)],
                    [[AssistInstruction(1), AssistInstruction(1)], [AssistInstruction(1)]])]
        results = calc_cvii(niter, VMES.ic, arglist, 5, 51, 3)
        @test results[11, "CVII"] == 1 #IRV with a single instructor who is unaffected thanks to LNH
        @test results[7, "CVII"] == 0 #Score with a single instructor who dooms themself
        for i in 1:5
            @test results[2i, "FG Wins"] + results[2i-1, "FG Wins"] == niter #A candidate who benefits from endorsements always wins
        end
    end

end