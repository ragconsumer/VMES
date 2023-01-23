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
    @test VMES.hontabulate(VMES.centersqueeze1, plurality)==[5; 2; 4;;]
    @test VMES.hontabulate(VMES.centersqueeze1, borda)==[10; 13; 10;;]
    @test VMES.hontabulate(VMES.centersqueeze1, pluralitytop2)==[5; 2; 4;; 5; 0; 6]
    @test VMES.hontabulate(VMES.centersqueeze2, pluralitytop2)==[6; 3; 3;; 6; 6; 0]
    @test getwinners(VMES.hontabulate(VMES.centersqueeze2, pluralitytop2),
                    pluralitytop2) == [1]

    @test VMES.top2([1,2,3,4,5])==[5, 4]
    @test VMES.top2([1,2,2,1,3])==[5, 2]
    @test VMES.top2([1,1,1,1])==[1, 2]

    @test tabulate(VMES.startestballots, score) == [50; 43; 43;;]
    @test tabulate(VMES.startestballots, star) == [50; 43; 43;; 10; 11; 0]

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
        VMES.hontabulate(VMES.reversespoiler, rcv) == [12; 6; 2;;]
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
    @test VMES.administerpolls(e, [ElectorateStrategy(hon, 2)], [plurality], 0, 0, 1) == Dict()

    estrat = ElectorateStrategy(hon, 2)
    vaestrat = ElectorateStrategy(PluralityVA(VMES.WinProbSpec(spec, 0.1), 0.1), 2)
    counts = Dict{Array, Int}()
    for _ in 1:100
        polldict = VMES.administerpolls(e, [vaestrat], [plurality], 0, 0, 1)
        counts[polldict[spec]] = get(counts, polldict[spec], 0) + 1
    end
    @test counts[[1;0;;]] + counts[[0;1;;]] == 100
    @test 20 < counts[[1;0;;]] < 80
    counts = Dict{}()
    for _ in 1:100
        polldict = VMES.administerpolls(e, [vaestrat], [plurality], 0, 0, 2)
        counts[polldict[spec]] = get(counts, polldict[spec], 0) + 1
    end
    @test counts[[1;0;;]] + counts[[0;1;;]] + counts[[0.5;0.5;;]]== 100
    @test 30 < counts[[0.5;0.5;;]] < 70
    
end