using VMES
using Test
using DataFrames
import Statistics, Distributions, Random

include("test_voter_models.jl")
include("test_strategies.jl")
include("test_vm_tabulation.jl")
include("test_cvii.jl")
include("test_freeriding.jl")
include("test_metrics.jl")

@testset "Electorate Strategies and Templates" begin
    @test castballots(VMES.centersqueeze1, hon, irv) == [
        2  2  2  2  2  0  0  0  0  0  0
        1  1  1  1  1  2  2  1  1  1  1
        0  0  0  0  0  1  1  2  2  2  2]
    @test castballots(VMES.centersqueeze1,
        ElectorateStrategy(4, [hon, abstain, bullet], [4,2,5]), irv) == [
            2  2  2  2  0  0  0  0  0  0  0
            1  1  1  1  0  0  2  0  0  0  0
            0  0  0  0  0  0  0  2  2  2  2]
    @test ElectorateStrategy(5, [hon], [5]) == ElectorateStrategy(5, [hon], [5])
    es = ElectorateStrategy(4, [hon, abstain, bullet], [4,2,5])
    @test VMES.stratatindex(es, 1) == hon
    @test VMES.stratatindex(es, 6) == abstain
    @test VMES.stratatindex(es, 7) == bullet
    @test VMES.stratatindex(es, 11) == bullet
    @test VMES.strats_and_users_in_range(es, 1, 1) == ([hon], [(1,1)])
    @test VMES.strats_and_users_in_range(es, 11, 11) == ([bullet], [(11,11)])
    @test VMES.strats_and_users_in_range(es, 1, 4) == ([hon], [(1,4)])
    @test VMES.strats_and_users_in_range(es, 1, 5) == ([hon, abstain], [(1,4), (5,5)])
    @test VMES.strats_and_users_in_range(es, 5, 6) == ([abstain], [(5,6)])
    @test VMES.strats_and_users_in_range(es, 4, 9) == ([hon, abstain, bullet], [(4,4),(5,6),(7,9)])
    template = ESTemplate(5, [[(hon, 1,10), (bullet, 11,15), (abstain, 16,16)], [(approvalvatemplate,1,3)]])
    poll_es = ElectorateStrategy(5, [hon, bullet, abstain], [10, 5, 1])
    vastrat = ApprovalVA(VMES.WinProbSpec(VMES.BasicPollSpec(approval, poll_es), 0.5))
    estarget = ElectorateStrategy(5, [vastrat, hon, bullet, abstain], [3,7,5,1])
    es =  esfromtemplate(template, 0.5)
    @test es.stratusers == [(1,3),(4,10),(11,15),(16,16)]
    @test es.stratlist[2:end] == [hon, bullet, abstain]
    @test typeof(es.stratlist[1]) == ApprovalVA
    @test es.stratlist[1].neededinfo.uncertainty == 0.5
    @test es.stratlist[1].neededinfo.pollspec.estrat.stratusers == [(1,10),(11,15),(16,16)]
    @test es.stratlist[1].neededinfo.pollspec.estrat.stratlist == [hon, bullet, abstain]
    @test es == estarget
    template = VMES.ApprovalWinProbTemplate(VMES.IRVVA, 0.1,VMES.TopMeanThreshold(0.5),[0.0])
    a = VMES.vsfromtemplate(template, ElectorateStrategy(hon,5), 0.2)
    b = VMES.vsfromtemplate(template, ElectorateStrategy(hon,5), 0.2)
    @test hash(a) == hash(b)
end

@testset "Polls to Probabilities" begin
    @test VMES.betaprobs([0.4,0.4,0.5],0.1) ≈ [0.16885924923285558, 0.16885924923285558, 0.6622815015342889]
    @test VMES.tiefortwoprob([.499999999999,.499999999999,.000000000002]) ≈ [0.2928932188139377
                                                                            0.2928932188139377
                                                                            0.41421356237212464]
    @test VMES.tiefortwoprob([0, 0.5,0.5]) ≈ [0.41421356260416836
                                                0.29289321869791585
                                                0.29289321869791585]
end

@testset "Polls" begin
    polldict = Dict()
    spec = VMES.BasicPollSpec(plurality, ElectorateStrategy(hon, 12))
    @test spec == VMES.BasicPollSpec(plurality, ElectorateStrategy(hon, 12))
    @test VMES.addinfo!(Dict(), VMES.centersqueeze2, spec, [.1;.1;-.1;;]) == [.6;.35;.15;;]
    @test VMES.addinfo!(Dict(), VMES.centersqueeze2, spec, [.6;.1;-.3;;]) == [1;.35;0;;]
    p = VMES.addinfo!(Dict(), VMES.centersqueeze2, spec, [.1;.1;-.1;;], 0.01)
    @test 0.1 > Statistics.std(p - [.6;.35;.15;;], corrected=false) > 0.00001
    @test VMES.addinfo!(Dict(), VMES.centersqueeze2, spec, zeros(3,1), 0, [7,7,11,12]) == [0;.5;.5;;]

    e = [1;0;;0;1]
    spec = VMES.BasicPollSpec(plurality, ElectorateStrategy(hon, 2))
    @test VMES.administerpolls(e, ([ElectorateStrategy(hon, 2)], [plurality]), 0, 0, 1) == Dict(nothing=>nothing)

    estrat = ElectorateStrategy(hon, 2)
    vaestrat = ElectorateStrategy(PluralityVA(VMES.WinProbSpec(spec, 0.1)), 2)
    @test vaestrat == ElectorateStrategy(PluralityVA(VMES.WinProbSpec(spec, 0.1)), 2)
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

    a = [-0.1, -0.2]
    VMES.clamptosum!(a, 1, 2)
    @test a == [0.5, 0.5]
    a = [1.,1]
    VMES.clamptosum!(a, 1, 1)
    @test a == [0.5, 0.5]
    a = [0.4,1.1]
    VMES.clamptosum!(a, 1, 1)
    @test a ≈ [4/15, 11/15]
    a = [0, 0.1,0.2,0.3,0.4, 9]
    VMES.clamptosum!(a, 1, 0.5)
    @test a ≈[0, 0.05, 0.1, 0.15, 0.2, 0.5]
    a = [0.1, -0.2]
    VMES.clamptosum!(a, 0, 1)
    @test a == [0, 0]
    
    @testset "Fancy Polls" begin
        spec = VMES.STARPollSpec(star, ElectorateStrategy(hon, 12))
        ballots = VMES.castballots(VMES.centersqueeze2, ElectorateStrategy(hon, 12), star, polldict)
        scoreresults = VMES.hontabulate(VMES.centersqueeze2, score) ./60 + [.2;.1;0;;]
        r2results = [.7;.6;0;;] ./ 1.3
        @test VMES.makepoll(ballots, spec, [.2;.1;0;;], 0) ≈ [scoreresults r2results]

        spec = VMES.RCVPollSpec(ElectorateStrategy(hon, 12))
        @test VMES.addinfo!(Dict(), VMES.centersqueeze2, spec, [.6;.1;-.3;;]) ≈ [1.1/1.45;.35/1.45;0;;]
        spec = VMES.RCVPollSpec(ElectorateStrategy(hon, 29))
        @test VMES.addinfo!(Dict(), VMES.fivecand2party, spec, [0;0;0;0;0;;])==[8.0  12.0  12.0  12.0
                                                                                4.0   0     0     0
                                                                                6.0   6.0   6.0   0
                                                                                6.0   6.0  11.0  17.0
                                                                                5.0   5.0   0     0] ./ 29
        @test VMES.addinfo!(Dict(), VMES.fivecand2party, spec, [0.1;0;0;0;0;;])[1,1] == (8/29 + 0.1)*10/11
        @test VMES.addinfo!(Dict(), VMES.fivecand2party, spec, [0.1;0;0;0;0;;])[2,1] == 4*10/(29*11)
        pollresults = VMES.addinfo!(Dict(), VMES.fivecand2party, spec, [0.1;0;0;0;0;;])
        @test all(sum(pollresults, dims=1) .≈ 1)
        @test VMES.addinfo!(Dict(), VMES.fivecand2party, spec, [0.1;0;0;0;0;;])[1,2] == (8/29 + 0.1)*10/11 + 4*10/(29*11)
        @test VMES.addinfo!(Dict(), VMES.fivecand2party, spec, [-0.01;0;0;0;0;;])[1,2] ≈ (8/29 + 4/29 - 0.01)*100/99
        spec = VMES.CondorcetPollSpec(minimax, ElectorateStrategy(hon, 11))
        poll = VMES.addinfo!(Dict(), VMES.centersqueeze1, spec, [0.,0,0])
        @test poll≈[0 5 5 -1
                    6 0 7 1
                    6 4 0 -3] ./ 11
        poll = VMES.addinfo!(Dict(), VMES.centersqueeze1, spec, [0.1,-0.025,0])
        @test poll[2,1] ≈ 6/11 - 0.125
        @test poll[1,2] ≈ 5/11 + 0.125
        @test poll[1,3] ≈ 5/11 + 0.1
        @test poll[1,4] ≈ -1/11 + 0.2
        spec = VMES.CondorcetPollSpec(rankedrobin, ElectorateStrategy(hon, 15))
        poll = VMES.addinfo!(Dict(), VMES.cycle2, spec, [0.,0,0,0]) 
        @test poll[:,1:4] == [0 0 0 4
                              15 0 5 9
                              15 10 0 4
                              11 6 11 0] ./ 15
        @test poll[:,5] == [0,2,2,2]
        @test poll[:,6] ≈ [-999, -2/15, -2/15, 4/15]
    end
end