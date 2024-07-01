@testset "Basic Strategies" begin
    @test vote([1,4,3,5],hon,irv)==[0,2,1,3]
    @test vote([1,3,3,2],hon,irv)==[0,3,2,1]
    @test vote([1,4,3,2],hon, LimitedVoting(3))==[0,1,1,1]
    @test vote([1,4,3,5],bullet,irv)==[0,0,0,3]
    @test vote([1,3,3,2],bullet,irv)==[0,3,0,0]
    @test vote([1,4,3,5],bullet,approval)==[0,0,0,1]
    @test vote([1,3,3,2],bullet,approval)==[0,1,0,0]
    @test vote([1,4,3,5],bullet,star)==[0,0,0,5]
    @test vote([1,3,3,2],bullet,star)==[0,5,0,0]
    @test vote([1,4,3,5],bullet,pluralitytop2) == [0, 0, 0, 1,  0, 2, 1, 3]
    @test vote([1,4,3,5],bullet,VMES.Top2Method(VMES.score)) == [0,0,0,5, 0,2,1,3]
    @test vote([1,4,3,5], HonLimRankings(2), irv) == [0,1,0,2]
    @test vote([0,3,2,5], HonLimTiedRankings(2), minimax) == [0,1,1,2]
    @test vote([-4,3,2,5,10,8], HonLimTiedRankings(2), minimax) == [0,1,1,1,2,2]
    @test vote([-10,1,2,3],TopBottomThreshold(.6),approval) == [0,1,1,1]
    @test vote([-10,1,2,3],TopBottomThreshold(.9),approval) == [0,0,1,1]
    @test vote([-10,1,2,3],TopBottomThreshold(.95),approval) == [0,0,0,1]
    @test vote([-10,1,2,3],TopBottomThreshold(1),approval) == [0,0,0,1]
    @test vote([-10,1,2,3],TopMeanThreshold(0.5),approval) == [0,1,1,1]
    @test vote([-10,1,2,3],TopMeanThreshold(0.6),approval) == [0,0,1,1]
    @test vote([-10,1,2,3],TopMeanThreshold(0.6),star) == [0,0,5,5]
    @test vote([-10,-1,1,10],StdThreshold(0),approval) == [0,0,1,1]
    @test vote([-10,-1,1,10],StdThreshold(0.3),approval) == [0,0,0,1]
    @test vote([-2,-1,1,2],StdThreshold(0.3),approval) == [0,0,1,1]

    @test VMES.mean_plus_std([0,2]) == 2
    @test vote([0,0.8,1,2,3,4,4.2,5], topbotem, star) == [0,0,1,2,3,4,5,5]
    @test vote([0,0.8,1,2,3,4,4.2,5],
                VMES.ArbitraryScoreScale(maximum, minimum, 1, 0, VMES.roundtoscore),
                star) == [0,1,1,2,3,4,4,5]
    @test vote([-10,0,0,0,0,1,2], topbotem, star) == [0,4,4,4,4,5,5]
    @test vote([-10,0,0,0,0,1,2], topmeanem, star) == [0,3,3,3,3,4,5]
    @test vote([-12,-1,0,0,0,2,10], scorebystd(1), star) == [0,2,3,3,3,4,5]
    @test vote([-12,-1,0,0,0,2,10], scorebystd(0.4), star) == [0,1,3,3,3,5,5]
    @test vote([-12,-1,0,0,0,2,10], topmeanem, star) == [0,2,3,3,3,3,5]
    @test vote([0,0.8,1,2,3,4,4.2,5], ExpScale(1, topmeanem), star) == [0,0,1,2,3,4,5,5]
    @test vote([0,0.8,1,2,3,4,4.2,5], ExpScale(2, topmeanem), star) == [0,0,0,0,2,3,4,5]
    @test vote([0,0.8,1,2,3,4,4.2,5], ExpScale(5, topmeanem), star) == [0,0,0,0,0,1,2,5]
    @test vote([0,1.4,0.6,5], smartblindstar, star) == [0,2,1,5]
    @test vote([0,1,1.01,5], smartblindstar, star) == [0,1,1,5]
end

@testset "Viability-Aware Strategies" begin
    @test vote([0,1,5], PluralityVA(nothing), plurality, [.49,.49,.02]) == [0,1,0]
    @test vote([0,1,5], PluralityVA(nothing), pluralitytop2, [.49,.49,.02]) == [0,0,1,0,1,2]
    @test vote([0,1,5,6], VMES.PluralityTop2VA(nothing), pluralitytop2, [.4,.3,.2, .1]) == [0,0,1,0,0,1,2,3]
    @test vote([0,1,5], PluralityVA(nothing), plurality, [.05,.9,.05]) == [0,0,1]
    @test vote([0,1,5], ApprovalVA(nothing), approval, [.49,.49,.02]) == [0,1,1]
    @test vote([0,1,5], ApprovalVA(nothing), approvaltop2, [.49,.49,.02]) == [0,0,1,0,1,2]
    @test vote([0,1,5,6], VMES.ApprovalTop2VA(nothing), approvaltop2, [.4,.3,.2,.1]) == [0,0,1,1,0,1,2,3]
    @test vote([0,1,5], ApprovalVA(nothing), approval, [.05,.9,.05]) == [0,0,1]
    @test vote([3,2,1,0], BordaVA(nothing), borda, [.05, .4, .4, .05]) == [2, 3, 0, 1]
    @test vote([3,2,1,0], IRVVA(nothing, 0), irv, [.05, .4, .4, .05]) == [2, 3, 1, 0]
    @test VMES.top3values([0,1,3], [.5,.4,.1]) ≈ [-.08, -0.02, 0.1]
    #@test sign.(VMES.top3values([1,2,3,5],[.99999,1e-5,1e-5,1e-5])) == [-1,-1,1,1]
    sc, rc = VMES.starvacoeffs([0,1,3], hon, [.5,.4,.1])
    @test isapprox(sc, [-.08, -0.02, 0.1], atol=1e-10)
    @test isapprox(rc, [0 0.2 0.15
                        -.2 0 0.08
                        -.15 -.08 0], atol=1e-10)
    @test vote([2.1,2,1,0], STARVA(nothing, .2), star, [.98, .01, .01, .0001]) == [5, 4, 0, 0]
    @test vote([4,2,1,0], STARVA(nothing, .2), star, [.98, .01, .01, .0001]) == [5, 1, 0, 0]
    @test vote([3,2,1,0], STARVA(nothing, .2), star, [.01, .49, .49, .01]) == [5, 4, 1, 0]
    
end

@testset "Position-based Strategies" begin
    @test VMES.getfrontrunners([1,2,3,4,5,6], 4) == [6,5,4,3]
    @test VMES.getfrontrunners([1,2,3,4,5,6], 2) == [6,5]
    @test VMES.getfrontrunners([6,5,4,3,2,1], 2) == [1,2]
    @test VMES.getfrontrunners([6,5,4,3,2,1], 4) == [1,2,3,4]

    @test vote([1,2,3,4,5], VMES.PluralityPositional(nothing), VMES.plurality, [2,4]) == [0,0,0,1,0]
    @test vote([1,2,3,4,5], VMES.ApprovalPositional(nothing), VMES.approval, [2,4]) == [0,0,0,1,1]
    @test vote([1,2,3,4,5], VMES.PluralityTop2Positional(nothing, false, false, false),
                VMES.pluralitytop2, ([4,2], [4,3,2])) == [0,0,0,1,0, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.PluralityTop2Positional(nothing, false, false, false),
                VMES.pluralitytop2, ([3,4], [4,3,2])) == [0,0,0,1,0, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.PluralityTop2Positional(nothing, true, false, false),
                VMES.pluralitytop2, ([3,4], [4,3,2])) == [0,0,0,1,0, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.PluralityTop2Positional(nothing, true, true, false),
                VMES.pluralitytop2, ([3,4], [4,3,2])) == [0,1,0,0,0, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.PluralityTop2Positional(nothing, true, false, false),
                VMES.pluralitytop2, ([2,4], [2,4,3])) == [0,0,1,0,0, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.PluralityTop2Positional(nothing, false, false, false),
                VMES.pluralitytop2, ([2,4], [4,2,3])) == [0,0,0,1,0, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.PluralityTop2Positional(nothing, true, true, true),
                VMES.pluralitytop2, ([2,4], [4,2,3])) == [0,0,1,0,0, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.PluralityTop2Positional(nothing, true, true, true),
                VMES.pluralitytop2, ([2,3], [2,3,4])) == [0,0,0,1,0, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.ApprovalTop2Positional(nothing, false, false),
                VMES.approvaltop2, ([4,2], [4,3,2])) == [0,0,0,1,1, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.ApprovalTop2Positional(nothing, true, true),
                VMES.approvaltop2, ([4,2], [4,3,2])) == [0,0,0,1,1, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.ApprovalTop2Positional(nothing, false, false),
                VMES.approvaltop2, ([2,4], [4,2,3])) == [0,0,1,1,1, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.ApprovalTop2Positional(nothing, false, false),
                VMES.approvaltop2, ([3,4], [4,3,2])) == [0,0,0,1,1, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.ApprovalTop2Positional(nothing, true, false),
                VMES.approvaltop2, ([3,4], [4,3,2])) == [0,0,0,1,1, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.ApprovalTop2Positional(nothing, false, true),
                VMES.approvaltop2, ([3,4], [4,3,2])) == [0,1,0,1,1, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.ApprovalTop2Positional(nothing, true, true),
                VMES.approvaltop2, ([3,2], [2,3,4])) == [0,0,0,1,1, 0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.IRVPositional(nothing, false, false, false),
                VMES.irv, ([4,2], [4,3,2])) == [0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.IRVPositional(nothing, false, false, false),
                VMES.irv, ([3,4], [4,3,2])) == [0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.IRVPositional(nothing, true, false, false),
                VMES.irv, ([3,4], [4,3,2])) == [0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.IRVPositional(nothing, true, true, false),
                VMES.irv, ([3,4], [4,3,2])) == [0,3,1,2,4]
    @test vote([1,2,3,4,5], VMES.IRVPositional(nothing, true, false, false),
                VMES.irv, ([2,4], [4,2,3])) == [0,1,3,2,4]
    @test vote([1,2,3,4,5], VMES.IRVPositional(nothing, false, false, false),
                VMES.irv, ([2,4], [4,2,3])) == [0,1,2,3,4]
    @test vote([1,2,3,4,5], VMES.IRVPositional(nothing, false, false, false),
                VMES.irv, ([2,4], [2,4,3])) == [0,1,3,2,4]
    @test vote([1,2,3,4,5], VMES.IRVPositional(nothing, false, false, true),
                VMES.irv, ([2,4], [4,2,3])) == [0,1,3,2,4]
    @test vote([1,2,3,4,5], VMES.IRVPositional(nothing, true, true, true),
                VMES.irv, ([2,3], [3,2,4])) == [0,1,2,3,4]
    
    @test VMES.threepointscale(.51, 10, 12, 0, 0.5, 1) == 10
    @test VMES.threepointscale(.49, 10, 12, 0, 0.5, 1) == 10
    @test VMES.threepointscale(10, 10, 12, 0, 0.5, 1) == 12
    @test VMES.threepointscale(-10, 10, 12, 0, 0.5, 1) == 0
    @test VMES.threepointscale(.1, 10, 12, 0, 0.5, 1) == 2
    @test VMES.threepointscale(.6, 10, 12, 0, 0.5, 1) == 10
    @test VMES.threepointscale(.7, 10, 12, 0, 0.5, 1) == 11
    @test VMES.threepointscale(.9, 10, 12, 0, 0.5, 1) == 12
    @test vote([1,2,3,4,5,6], VMES.STARPositional(nothing, true, true),
                VMES.star, ([4,3], [3,4,2])) == [0,1,2,3,4,5]
    @test vote([1,2,2.9,4,5,6], VMES.STARPositional(nothing, false, false),
                VMES.star, ([2,4], [4,2,5])) == [0,0,0,1,5,5]
    @test vote([1,2,3.1,4,5,6], VMES.STARPositional(nothing, false, false),
                VMES.star, ([2,4], [4,2,5])) == [0,0,1,1,5,5]
    @test vote([1,2,3,4,5,6], VMES.STARPositional(nothing, false, false),
                VMES.star, ([2,3], [2,3,5])) == [0,0,1,3,5,5]
    @test vote([1,2,3,3.9,5,6], VMES.STARPositional(nothing, false, false),
                VMES.star, ([2,5], [2,5,3])) == [0,0,4,4,5,5]
    @test vote([1,2,3,4,5,6], VMES.STARPositional(nothing, true, false),
                VMES.star, ([2,5], [2,5,3])) == [0,0,5,5,1,5]
    @test vote([1,2,3,4,5,6], VMES.STARPositional(nothing, true, false),
                VMES.star, ([1,6], [1,6,4])) == [0,2,3,5,5,1]
    @test vote([1,2,3,4,5,6], VMES.STARPositional(nothing, false, false),
                VMES.star, ([2,5], [5,2,4])) == [0,0,2,4,5,5]
    @test vote([1,2,3,4,5,6], VMES.STARPositional(nothing, true, false),
                VMES.star, ([4,5], [5,4,2])) == [0,0,0,1,5,5]
    @test vote([1,2,3,4,5,6], VMES.STARPositional(nothing, false, true),
                VMES.star, ([4,5], [5,4,2])) == [0,4,0,0,5,5] 
    @test vote([1,2,3,4,5,6], VMES.STARPositional(nothing, false, false),
                VMES.star, ([4,5], [5,4,2])) == [0,0,0,1,5,5]
    @test VMES.vote([1,0,2], VMES.MinimaxPositional(nothing),
                    VMES.minimax, ([0;2;2;;1;0;1;;3;3;0], [3;1;2])) == [1,0,2]
    @test VMES.vote([2,1,0], VMES.MinimaxPositional(nothing),
                    VMES.minimax, ([0;2;2;;1;0;1;;3;3;0], [3;1;2])) == [2,0,1]
    @test VMES.vote([-2,-1,2,1,0], VMES.MinimaxPositional(nothing),
                    VMES.minimax, ([0;2;4;6;5;;1;0;3;5;4;;1;0;0;2;2;;1;0;1;0;1;;1;0;3;3;0], [5;3;4])) == [0,1,4,2,3]
end