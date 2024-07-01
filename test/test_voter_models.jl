@testset "Voter Models" begin
    e = VMES.make_electorate(ic, 30, 5, 1234567)
    @test VMES.getseed(e) == 1234567
    @test size(VMES.make_electorate(ic, 5,2)) == (2,5)
    @test size(VMES.make_electorate(VMES.DimModel(1), 5,2)) == (2,5)
    for n in 1:4
        meandiff = Statistics.mean(Statistics.mean(VMES.make_electorate(VMES.DimModel(n), 5,5) .^ 2) for i in 1:1000)
        @test 0.9*(2n) < meandiff < 1.1*(2n)
        cstd = 0.5
        meandiff = Statistics.mean(Statistics.mean(VMES.make_electorate(VMES.DimModel(n, cstd), 5,5) .^ 2) for i in 1:1000)
        @test 0.9*(1+cstd^2)*n < meandiff < 1.1*(1+cstd^2)*n
    end

    @test VMES.make_electorate(BaseQualityNoiseModel(VMES.TestModel([1.;2;;3;4]), 0, 0), 2, 2)[1,1] == 1
    e = VMES.make_electorate(BaseQualityNoiseModel(VMES.TestModel([1.;1;;1;1]), 1.0, 0), 2, 2)
    @test e[1,1] != e[2,1]
    @test e[1,1] == e[1,2]
    abspref = 0
    totalpref = 0
    n = 10
    for i in 1:n
        e = VMES.make_electorate(BaseQualityNoiseModel(ic, 0, 1000),1000, 2)
        abspref += abs(sum(e[1,:]) - sum(e[2,:]))
        totalpref += sum(e[1,:]) - sum(e[2,:])
    end
    @test abspref > 10000n
    @test totalpref < 100000 * sqrt(n)

    @test VMES.make_electorate(ExpPreferenceModel(VMES.TestModel([-10.;-5;0;;0;5;0]), 1), 2, 3) == [0;.5;1;;0;1;0]
    @test VMES.make_electorate(ExpPreferenceModel(VMES.TestModel([-10.;-5;0;;0;5;0]), 2), 2, 3) == [0;.25;1;;0;1;0]

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
        #test normalize_weights
        weights = [2 .5 3
                   0 .5 4
        ]
        VMES.normalize_weights(VMES.dcc, weights)
        @test weights[1,1] == 1
        @test weights[1,2] ≈ 1/sqrt(2)
        @test weights[1,3] ≈ 3/5
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