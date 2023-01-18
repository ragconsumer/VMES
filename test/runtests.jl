using VMES
using Test
import Statistics

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
    @test VMES.addpoll!(Dict(), VMES.centersqueeze2, spec, [.1;.1;-.1;;]) == [.6;.35;.15;;]
    @test VMES.addpoll!(Dict(), VMES.centersqueeze2, spec, [.6;.1;-.3;;]) == [1;.35;0;;]
    p = VMES.addpoll!(Dict(), VMES.centersqueeze2, spec, [.1;.1;-.1;;], 0.01)
    @test 0.1 > Statistics.std(p - [.6;.35;.15;;], corrected=false) > 0.00001
    @test VMES.addpoll!(Dict(), VMES.centersqueeze2, spec, zeros(3,1), 0, [7,7,11,12]) == [0;.5;.5;;]

    e = [1;0;;0;1]
    spec = VMES.BasicPollSpec(plurality, ElectorateStrategy(hon, 2))
    @test VMES.administerpolls(e, [ElectorateStrategy(hon, 2)], [plurality], 0, 0, 1) == Dict()
    #Readd tests for administerpolls once I have a strategy that uses a poll implemented
    #=estrat = ElectorateStrategy(hon, 2)
    counts = Dict{}
    for _ in 1:100
        polldict = VMES.administerpolls(e, [estrat], [plurality], 0, 0, 1)
        counts[polldict[spec]] = get(counts, polldict[spec], 0) + 1
    end
    @test counts[[1;0;;]] + counts[[0;1;;]] == 100
    @test 20 < counts[[1;0;;]] < 80
    counts = Dict{}
    for _ in 1:100
        polldict = VMES.administerpolls(e, [spec], [plurality], 0, 0, 2)
        counts[polldict[spec]] = get(counts, polldict[spec], 0) + 1
    end
    @test counts[[1;0;;]] + counts[[0;1;;]] + counts[[0.5;0.5;;]]== 100
    @test 30 < counts[[0.5;0.5;;]] < 70
    =#
    
end