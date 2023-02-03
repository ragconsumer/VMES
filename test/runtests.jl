using VMES
using Test
import Statistics, Distributions, Random

@testset "Voter Models" begin
    e = VMES.make_electorate(ic, 30, 5, 1234567)
    @test VMES.getseed(e) == 1234567
    @test size(VMES.make_electorate(ic, 5,2)) == (2,5)
    @test size(VMES.make_electorate(VMES.DimModel(1), 5,2)) == (2,5)
    for n in 1:4
        meandiff = Statistics.mean(Statistics.mean(VMES.make_electorate(VMES.DimModel(n), 5,5) .^ 2) for i in 1:1000)
        @test 0.9*(2n) < meandiff < 1.1*(2n)
    end

    @testset "DCCModel" begin
        #test makeviews
        for i in 1:4
            cutmodel = DCCModel(Distributions.Uniform(), 0.2i,
                            Distributions.Uniform(), 0.2i,
                            1, Distributions.Beta(6, 3))
            oneviewcount, onedimcount, onedimtotalcount, dim2weightsum = 0, 0, 0, 0
            niter = 2000
            for _ in 1:niter
                viewdims, weights = VMES.makeviews(cutmodel, Random.Xoshiro())
                if length(viewdims) == 1
                    oneviewcount += 1
                end
                if viewdims[1] == 1
                    onedimcount += 1
                end
                if length(weights) > 1
                    dim2weightsum += weights[2]
                else
                    onedimtotalcount += 1
                end
            end
            @test 0.15i < oneviewcount/niter < 0.25i
            @test 0.15i < onedimcount/niter < 0.25i
            @test 0.9*(1 + 0.2i)/2 < dim2weightsum/(niter - onedimtotalcount) < 1.1*(1 + 0.2i)/2
        end
        #test assignclusters with very few points
        niter = 5000
        twopoint = VMES.assignclusters(dcc, 2, niter, Random.Xoshiro())
        threepoint = VMES.assignclusters(dcc, 3, niter, Random.Xoshiro())
        @test 0.9niter/2 < count(==(2), twopoint[2]) < 1.1niter/2
        @test 0.8niter/6 < count(==(3), threepoint[1]) < 1.2niter/6
        @test size(VMES.assignclusters(dcc, 5, 10, Random.Xoshiro())[1]) == (10, 5)
        #test makeclusterprefs, first by making sure all the stds aren't just uncorrelated
        clumpsize, nclumps, nclusters = 200, 200, 10
        allmeans = VMES.makeclusterprefs(
            dcc, nclumps + 1, [nclumps*clumpsize; repeat([clumpsize], nclumps)],
            repeat([nclusters], nclumps + 1), Random.Xoshiro())
        for cluster in 1:nclusters
            depstds = [sum((allmeans[1][k, cluster, 1]^2 for k in i*clumpsize+1:(i+1)*clumpsize)) for i in 0:nclumps-1]
            indstds = [sum((allmeans[1][k, cluster, i])^2 for k in 1:clumpsize) for i in 2:nclumps+1]
            @test Statistics.std(depstds) < Statistics.std(indstds)
        end
        means, importances = VMES.makeclusterprefs(dcc, 3, [2,2,1], [4, 2, 1], Random.Xoshiro())
        @test size(means) == (2, 4, 3)
        @test size(importances) == (4, 3)
        @test count(≈(0, atol=1e-10), importances) == 5
        #test makeprefpoints
        views = [1 1 1 2 2 2 repeat([2],1,100)
                 1 2 2 2 2 1 repeat([1],1,100)]
        viewdims = [1, 2]
        dimweights = [1, 1, 0.1]
        clustermeans = [1. -1
                        0 0;;;
                        10 -10
                        5 -5]
        clusterimportances = [1. 1
                              0 1]
        points, weights = VMES.makeprefpoints(dcc, views, viewdims, dimweights, clustermeans, clusterimportances, 2, Random.Xoshiro())
        @test all(points[1,1:3] .== 1)
        @test 0.2 < Statistics.std(points[1,4:105]) < 2
        @test -1.5 < Statistics.mean(points[1,4:105]) < -0.5
        @test all(points[2,2:5] .== -10)
        @test points[2,1] == 10
        @test points[3,1] == 5
        @test weights[1, 1] == 1
        @test weights[3, 1] == .1
        @test weights[1, 8] == 0
        #test positions_to_utils
        votersandcands = [10 0 1 10 1
                          0 0 5 0 0]
        weights = [1 1 3
                   1 1 4]
        elec = VMES.positions_to_utils(dcc, votersandcands, weights, 3, 2)
        @test elec[1,1] == 0
        @test elec[1,2] == -sqrt(50)
        @test elec[2,2] ≈ -1/sqrt(2)
        @test elec[1,3] == -sqrt(81*9 + 25*16)/5
        @test elec[2,3] == -4
        elec = make_electorate(dcc, 50, 10)
        @test size(elec) == (10,50)
        seed = VMES.getseed(elec)
        @test make_electorate(dcc, 50, 10, seed) == elec
        @test make_electorate(dcc, 50, 10) != elec
    end

    base_elec = [1.;0;;1.5;.8;;-1.1;0]
    niter = 10000
    upsetcount = 0
    for _ in 1:niter
        elec = make_electorate(RepDrawModel(base_elec), 3, 2)
        if winnersfromtab(VMES.hontabulate(elec, plurality), plurality) == [2]
            upsetcount += 1
        end
    end
    elec = make_electorate(RepDrawModel(base_elec), 3, 2)
    @test size(elec) == (2, 3)
    @test 0.7*2/9 < upsetcount/niter < 1.3*2/9
end

@testset "Basic Strategies" begin
    @test vote([1,4,3,5],hon,irv)==[0,2,1,3]
    @test vote([1,3,3,2],hon,irv)==[0,3,2,1]
    @test vote([1,4,3,5],bullet,irv)==[0,0,0,3]
    @test vote([1,3,3,2],bullet,irv)==[0,3,0,0]
    @test vote([1,4,3,5],bullet,approval)==[0,0,0,1]
    @test vote([1,3,3,2],bullet,approval)==[0,1,0,0]
    @test vote([1,4,3,5],bullet,star)==[0,0,0,5]
    @test vote([1,3,3,2],bullet,star)==[0,5,0,0]
    @test vote([1,4,3,5],bullet,pluralitytop2) == [0, 0, 0, 1,  0, 2, 1, 3]
    @test vote([1,4,3,5],bullet,VMES.Top2Method(VMES.score)) == [0,0,0,5, 0,2,1,3]
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
    @test vote([0,0.8,1,2,3,4,4.2,5], ExpScale(1), star) == [0,0,1,2,3,4,5,5]
    @test vote([0,0.8,1,2,3,4,4.2,5], ExpScale(2), star) == [0,0,0,0,2,3,4,5]
    @test vote([0,0.8,1,2,3,4,4.2,5], ExpScale(5), star) == [0,0,0,0,0,1,2,5]
end

@testset "Viability-Aware Strategies" begin
    @test vote([0,1,5], PluralityVA(nothing, 0.1), plurality, [.49,.49,.02]) == [0,1,0]
    @test vote([0,1,5], PluralityVA(nothing, 0.1), plurality, [.05,.9,.05]) == [0,0,1]
    @test vote([0,1,5], ApprovalVA(nothing, 0.1), approval, [.49,.49,.02]) == [0,1,1]
    @test vote([0,1,5], ApprovalVA(nothing, 0.1), approval, [.05,.9,.05]) == [0,0,1]
    @test vote([3,2,1,0], BordaVA(nothing, 0.1), borda, [.05, .4, .4, .05]) == [2, 3, 0, 1]
    @test vote([3,2,1,0], IRVVA(nothing, 0.1), irv, [.05, .4, .4, .05]) == [2, 3, 1, 0]
    sc, rc = VMES.starvacoeffs([0,1,3], hon, [.5,.4,.1])
    @test isapprox(sc, [-.08, -0.02, 0.1], atol=1e-10)
    @test isapprox(rc, [0 0.2 0.15
                        -.2 0 0.08
                        -.15 -.08 0], atol=1e-10)
    @test vote([2.1,2,1,0], STARVA(nothing, 0.1, .2), star, [.98, .01, .01, .0001]) == [5, 4, 0, 0]
    @test vote([4,2,1,0], STARVA(nothing, 0.1, .2), star, [.98, .01, .01, .0001]) == [5, 1, 0, 0]
    @test vote([3,2,1,0], STARVA(nothing, 0.1, .2), star, [.01, .49, .49, .01]) == [5, 4, 1, 0]
    
end

@testset "Electorate Strategies" begin
    @test castballots(VMES.centersqueeze1, hon, irv) == [
        2  2  2  2  2  0  0  0  0  0  0
        1  1  1  1  1  2  2  1  1  1  1
        0  0  0  0  0  1  1  2  2  2  2]
    @test castballots(VMES.centersqueeze1,
        ElectorateStrategy(4, [hon, abstain, bullet], [4,2,5]), irv) == [
            2  2  2  2  0  0  0  0  0  0  0
            1  1  1  1  0  0  2  0  0  0  0
            0  0  0  0  0  0  0  2  2  2  2]
end

@testset "Polls to Probabilities" begin
    @test VMES.betaprobs([0.4,0.4,0.5],0.1) ≈ [0.16885924923285558, 0.16885924923285558, 0.6622815015342889]
end

@testset "VM Tabulation" begin
    @test winnersfromtab([50; 43; 60;; 50; 43; 43], allocatedscore, 2) == [1, 2]
    @test winnersfromtab([50; 43; 60;; 50; 43; 53], allocatedscore, 2) == [3, 1]
    @test VMES.hontabulate(VMES.centersqueeze1, plurality)==[5; 2; 4;;]
    @test VMES.hontabulate(VMES.centersqueeze1, borda)==[10; 13; 10;;]
    @test VMES.hontabulate(VMES.centersqueeze1, pluralitytop2)==[5; 2; 4;; 5; 0; 6]
    @test VMES.hontabulate(VMES.centersqueeze2, pluralitytop2)==[6; 3; 3;; 6; 6; 0]
    @test winnersfromtab(VMES.hontabulate(VMES.centersqueeze2, pluralitytop2),
                    pluralitytop2) == [1]

    @test VMES.top2([1,2,3,4,5])==[5, 4]
    @test VMES.top2([1,2,2,1,3])==[5, 2]
    @test VMES.top2([1,1,1,1])==[1, 2]

    @test tabulate(VMES.startestballots, score) == [50; 43; 43;;]
    @test tabulate(VMES.startestballots, star) == [50; 43; 43;; 10; 11; 0]

    @test VMES.pairwisematrix(VMES.centersqueeze1) == [0 5 5
                                                           6 0 7
                                                           6 4 0]
    @test VMES.hontabulate(VMES.centersqueeze1, minimax)==[0 5 5 -1
                                                            6 0 7 1
                                                            6 4 0 -3]
    @test VMES.hontabulate(VMES.centersqueeze1, rankedrobin)==[0 5 5 0
                                                               6 0 7 2
                                                               6 4 0 1]
    @test VMES.hontabulate(VMES.cycle1, rankedrobin)==[0 5 9 1 -2
                                                       10 0 4 1 -2
                                                       6 11 0 1 4]
    @test VMES.hontabulate(VMES.cycle2, rankedrobin)==[0 0 0 4 0 -999
                                                       15 0 5 9 2 -2
                                                       15 10 0 4 2 -2
                                                       11 6 11 0 2 4]
    @testset "RCV" begin
        
        @test VMES.hontabulate(VMES.centersqueeze1, irv)==[5; 2; 4;; 5; 0; 6]
        @test VMES.hontabulate(VMES.centersqueeze2, irv)==[6; 3; 3;; 6; 6; 0]
        @test VMES.hontabulate(VMES.fivecand2party, rcv, 1)==[  8.0  12.0  12.0  12.0
                                                                4.0   0     0     0
                                                                6.0   6.0   6.0   0
                                                                6.0   6.0  11.0  17.0
                                                                5.0   5.0   0     0]
        @test VMES.hontabulate(VMES.fivecand2party, rcv, 2)≈[ 8.0  12.0  10.0  10.0
                                                                4.0   0.0   0.0   0.0
                                                                6.0   6.0   8.0   8.0
                                                                6.0   6.0   6.0  11.0
                                                                5.0   5.0   5.0   0.0]
        @test VMES.hontabulate(VMES.fivecand2party, rcv, 3)≈[ 8.0  8.0   8.0  8.0
                                                                4.0  4.0   0.0  0.0
                                                                6.0  6.0  10.0  8.0
                                                                6.0  6.0   6.0  8.0
                                                                5.0  5.0   5.0  5.0]
        @test VMES.hontabulate(VMES.fivecand2partymessier, rcv, 2)≈[8.0  12.0  10.0      10.0
                                                                    4.0   0.0   0.0       0.0
                                                                    6.0   6.0   7.666666667   7.666666667
                                                                    6.0   6.0   6.333333333  11.333333333
                                                                    5.0   5.0   5.0       0.0]
        @test tabulate(VMES.manybulletranked, rcv, 3) ≈ [7.0   7.0   7.0    7.0
                                                        4.0   4.0   4.75   0.0
                                                        6.0   6.0   6.0   10.75
                                                        20.0  11.0  11.0   11.0
                                                        3.0  12.0  11.0   11.0]
        @test VMES.hontabulate(VMES.reversespoiler, rcv) == [12; 6; 2;;]
        @test VMES.hontabulate(VMES.cycle2, rcv)==[0 0 0
                                                   5 5 9
                                                   4 4 0
                                                   6 6 6]
    end
    @testset "Score PR" begin
        @test VMES.weightedscorecount([5;4;0;;0;2;5], [1,0.5], sss) == [5, 5, 2.5]
        @test VMES.weightedstarrunoff([5, 10, 5], [5;0;0;;4;5;0;;0;0;5], [1, .5, 75]) == [1, .5, 0]
        weights = [1,0.9,1,1, 0.25]
        VMES.sssreweight!(weights, sss, [5;;5;;3;;3;;0], 1, 2, Set())
        @test weights ≈ [1-2/3.1,0.9*(1-2/3.1),1-6/15.5,1-6/15.5, 0.25]
        weights = [0.5,0.4,1,1, 0.25]
        VMES.sssreweight!(weights, sss, [5;;5;;3;;2;;0], 1, 2, Set())
        @test weights ≈ [0,0,0.4,0.6,0.25]
        weights = [1,1,1,1, 0.25]
        VMES.asreweight!(weights, allocatedscore, [5;;5;;3;;3;;0], 1, 2, Set())
        @test weights ≈ [0,0,1,1, 0.25]
        weights = [1,.8,1,1, 0.25]
        VMES.asreweight!(weights, allocatedscore, [5;;5;;3;;3;;0], 1, 2, Set())
        @test weights ≈ [0,0,.9,.9, 0.25]
        weights = [1,.5,1,1, 0.25]
        VMES.asreweight!(weights, allocatedscore, [5;;5;;4;;3;;0], 1, 2, Set())
        @test weights ≈ [0,0.5,0,1, 0.25]
        weights = [0.5,.5,1,0.25, 0.25]
        VMES.asreweight!(weights, allocatedscore, [5;;0;;4;;3;;0], 1, 2, Set())
        @test weights ≈ [0,0.5,0,0, 0.25]
        weights = [0.5,.5,1,1, 0.25]
        VMES.asreweight!(weights, allocatedscore, [4;;4;;2;;2;;0], 1, 2, Set())
        @test weights ≈ [1/6,1/6,1/3,1/3, 0.25]
        weights = [1,1,1,1, 0.25]
        VMES.asreweight!(weights, asu, [5;;5;;3;;3;;0], 1, 2, Set())
        @test weights ≈ [0,0,1,1, 0.25]
        weights = [1,.5,1,1, 0.25]
        VMES.asreweight!(weights, asu, [5;;5;;4;;3;;0], 1, 2, Set())
        @test weights ≈ [0,0,0.5,1, 0.25]
        weights = [1,1,1,1, 0.25]
        VMES.asreweight!(weights, s5h, [5;;5;;3;;3;;0], 1, 2, Set())
        @test weights ≈ [0,0,1,1, 0.25]
        weights = [0.5,.5,1,0.25, 0.25]
        VMES.asreweight!(weights, s5h, [5;;5;;4;;3;;0], 1, 2, Set())
        @test weights ≈ [0,0,0.2,0.1, 0.25]
        weights = [1,.5,1,0.5, 0.25]
        VMES.asreweight!(weights, s5h, [5;;0;;4;;3;;0], 1, 2, Set())
        @test weights ≈ [0,0.5,0.2,0.3, 0.25]

        ec = Set([1,4])
        @test VMES.addwinner!(ec, [9,1,5,5,5]) == (3, 5)
        ec == Set([1,3,4])

        @test VMES.tabulate(VMES.startestballots, allocatedscore, 2) == [50; 43; 43;; 50; 43; 43]
        @test VMES.tabulate(VMES.scoretest1, allocatedscore, 2) ≈ [70 70 
                                                                   55 31
                                                                   25 25
                                                                   50 20]
        @test VMES.tabulate(VMES.scoretest1, allocatedscore, 3) ≈ [70 70 70 
                                                                   55 39 39
                                                                   25 25 5
                                                                   50 30 30]
        @test VMES.tabulate(VMES.scoretest1, asu, 3) ≈ [70 70 70 
                                                        55 39 39
                                                        25 25 25
                                                        50 30 10]
        @test VMES.tabulate(VMES.scoretest1, sss, 2) ≈ [70 70 
                                                        55 4*(10-30/7)+3*(5-12/7)
                                                        25 5*(5-12/7)
                                                        50 5*(10-30/7)]
        @test VMES.tabulate(VMES.scoretest1, s5h, 3) ≈ [70 70 70 
                                                        55 39 39
                                                        25 25 25
                                                        50 30 10]
        @test VMES.tabulate(VMES.scoretest1, s5hr, 3) ≈[70 15 70 70 70 70
                                                        55 0 39 5 23 2
                                                        25 0 25 0 25 5
                                                        50 0 30 6 30 30]
        @test VMES.tabulate(VMES.scoretest1, s5hfr, 3) ≈ [70 70 70 70
                                                          55 39 39 39
                                                          25 25 25 5
                                                          50 30 10 2]
    end
    @testset "MES and TEA" begin
        @test VMES.mes_min_rho([(0.5, 4), (1., 5), (1., 3)], 2) ≈ 3/16
        @test VMES.mes_min_rho([(1., 3), (0.5, 4), (1., 5)], 2) ≈ 3/16
        @test VMES.mes_min_rho([(0.5, 4), (0.2, 5), (1., 3)], 1) ≈ 4/35

        electedcands = Set(3)
        ballots = [0;5;1;;1;0;5;;2;5;1]
        weights = [.5, .5, .8]
        winner, results = VMES.positiveweightapproval!(electedcands, weights, ballots)
        @test winner == 1
        @test results == [1.3,1.3,-1]
        @test weights == [.5, 0, 0]
        electedcands = Set(3)
        ballots = [0;5;1;;1;0;5;;2;5;1]
        weights = [.5, .5, .8]
        winner, results = VMES.weightedscorefallback!(electedcands, weights, ballots)
        @test winner == 2
        @test results == [2.1,6.5,-1]
        @test weights == [0, 0.5, 0]
        @test VMES.tabulate(VMES.scoretest1, mes, 3) ≈ [70 70 70
                                                        55 55 55
                                                        5 50/14 50/14-15/11
                                                        50 50 10*(1-5/14-4/11)]
        @test VMES.tabulate(VMES.scoretest2, mes, 2) ≈ [50 50
                                                        20 2.5
                                                        30 7.5
                                                        5 5]
        @test VMES.tabulate(VMES.scoretest2, mes, 3) ≈ [50 50 50
                                                        20 5 5-10/7
                                                        35 35 35
                                                        5 5 10/7]
        @test VMES.tabulate(VMES.scoretest2, VMES.tea, 3) == [10 10 10 10 10 10 10 10 10
                                                              0 0 0 4 0 3 0 2 10
                                                              5 5 5 5 5 5 5 5 5
                                                              5 5 0 4 0 3 0 2 0]
    end
end

@testset "Polls" begin
    polldict = Dict()
    spec = VMES.BasicPollSpec(plurality, ElectorateStrategy(hon, 12))
    @test VMES.addinfo!(Dict(), VMES.centersqueeze2, spec, [.1;.1;-.1;;]) == [.6;.35;.15;;]
    @test VMES.addinfo!(Dict(), VMES.centersqueeze2, spec, [.6;.1;-.3;;]) == [1;.35;0;;]
    p = VMES.addinfo!(Dict(), VMES.centersqueeze2, spec, [.1;.1;-.1;;], 0.01)
    @test 0.1 > Statistics.std(p - [.6;.35;.15;;], corrected=false) > 0.00001
    @test VMES.addinfo!(Dict(), VMES.centersqueeze2, spec, zeros(3,1), 0, [7,7,11,12]) == [0;.5;.5;;]

    e = [1;0;;0;1]
    spec = VMES.BasicPollSpec(plurality, ElectorateStrategy(hon, 2))
    @test VMES.administerpolls(e, ([ElectorateStrategy(hon, 2)], [plurality]), 0, 0, 1) == Dict(nothing=>nothing)

    estrat = ElectorateStrategy(hon, 2)
    vaestrat = ElectorateStrategy(PluralityVA(VMES.WinProbSpec(spec, 0.1), 0.1), 2)
    counts = Dict{Array, Int}()
    for _ in 1:100
        polldict = VMES.administerpolls(e, ([vaestrat], [plurality]), 0, 0, 1)
        counts[polldict[spec]] = get(counts, polldict[spec], 0) + 1
    end
    @test counts[[1;0;;]] + counts[[0;1;;]] == 100
    @test 20 < counts[[1;0;;]] < 80
    counts = Dict{}()
    for _ in 1:100
        polldict = VMES.administerpolls(e, ([vaestrat], [plurality]), 0, 0, 2)
        counts[polldict[spec]] = get(counts, polldict[spec], 0) + 1
    end
    @test counts[[1;0;;]] + counts[[0;1;;]] + counts[[0.5;0.5;;]]== 100
    @test 30 < counts[[0.5;0.5;;]] < 70
    
end

@testset "Metrics" begin
    methods = [plurality, irv, minimax]
    strats = [ElectorateStrategy(hon, 11) for _ in 1:3]
    vses = calc_vses(10, VMES.TestModel(VMES.centersqueeze1), methods, strats, 11, 3)
    @test vses ≈ [(10.5 - 32.5/3)/(13-32.5/3), (9 - 32.5/3)/(13-32.5/3), 1]

    electorate = [10;0;0;0;;10;0;0;0;;0;10;6;0;;0;0;10;0]
    qs, highs, avgs = VMES.mw_winner_quality(electorate, [[1,2,3],[1,2,4],[1,3,4],[2,3,4]], 3)
    @test highs == [5; 5; 10]
    @test qs == [1.5; 0; 0; 1.5;; 46/12;30/12;36/12;26/12;; 10;7.5;9;5]

    @testset "esif" begin
        strats = [hon, abstain, bullet, ExpScale(3), ExpScale(3.1)]
        possballots, ballotlookup = VMES.stratballotdict(
            [0,1,2,3,4,5], strats, star, [0,1,2,3,4,5], Dict(nothing=>nothing))
        @test possballots == [0 0 0 0
                              1 0 0 0
                              2 0 0 0
                              3 0 0 1
                              4 0 0 3
                              5 0 5 5]
        @test ballotlookup == Dict{Int, Int}(1=>1, 2=>2, 3=>3, 4=>4, 5=>4)
        strats = [abstain, bullet, ExpScale(3), ExpScale(3.1)]
        possballots, ballotlookup = VMES.stratballotdict(
            [0,1,2,3,4,5], strats, star, [0,1,2,3,4,5], Dict(nothing=>nothing))
        @test possballots == [0 0 0 0
                              1 0 0 0
                              2 0 0 0
                              3 0 0 1
                              4 0 0 3
                              5 0 5 5]
        @test ballotlookup == Dict{Int, Int}(1=>2, 2=>3, 3=>4, 4=>4)

        possibleballots = [5;0;0;;0;5;0;;0;0;5;;0;1;5]
        bgballots = [3;2;1;;5;0;0;;1;5;1;;0;1;5;;3;2;1]
        d = VMES.ballotresultmap(possibleballots, bgballots, [score, star], [[1],[2]], [1,2,3], 1, 1)
        @test d == [0.0 1.0 2.0 2.0;;; 0.0 0.0 -1.0 -1.0]

        methodsandstrats = [([star, score], [hon, bullet], [hon, bullet, ExpScale(2)]),
                            ([rcv],[hon], [bullet, abstain])]
        stratinputs, methodinputs = VMES.getadminpollsinput(methodsandstrats)
        @test stratinputs == [hon, bullet, hon, bullet, ExpScale(2), hon, bullet, abstain]
        @test methodinputs == [repeat([star], 5); repeat([rcv], 3)]

        #test one_esif_iter
        methodsandstrats = [([score, star], [ElectorateStrategy(hon,3), ElectorateStrategy(ExpScale(3),3)], [hon, bullet]),
                            ([rcv], [ElectorateStrategy(bullet,3)], [abstain, bullet, hon])]
        electorate = [0;1;2;-10;;2;0;1;-10;;1;2;0;-10] #symmetric reverse spoiler scenario (also a Condorcet cycle)
        utiltotals = VMES.one_esif_iter(VMES.TestModel(electorate), methodsandstrats, 3, 4, 0, 0, 1)
        @test utiltotals == [0. 3 0 1 -3 3 0 -3 -2 0 1]

        esifs = calc_esif(10, VMES.TestModel(electorate), methodsandstrats, 3, 4, 0, 0, 1)[4]
        @test esifs == [1, 2, 1, 4/3, 0, 2, 1, -0.5, 0, 1, 1.5]

        totals = [-3 0. 3 -3 0 1 -3 -3 3 -2 0 -3 -2 -2 0 1]
        @test VMES.totals_to_esif(totals, methodsandstrats)[4] == [1, 2, 1, 4/3, 0, 2, 1, -0.5, 0, 1, 1.5]
    end
end