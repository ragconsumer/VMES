@testset "VM Tabulation" begin
    @test VMES.indices_by_sorted_values([1,3,5,5,3,2,6,0]) == [7,3,4,2,5,6,1,8]
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
    @test tabulate(VMES.startestballots, star) == [50; 43; 43;; 10; 11; -1]
    @test VMES.placementsfromtab([50; 43; 43;;], score) == [1,2,3]
    @test VMES.placementsfromtab([50; 43; 43;; 10; 11; 0], score) == [2,1,3]

    @test VMES.pairwisematrix(VMES.centersqueeze1) == [0 5 5
                                                           6 0 7
                                                           6 4 0]
    @test VMES.pairwisematrix(VMES.centersqueeze1, ones(Float64, 11), Set(1)) == [-1 -1 -1
                                                                                  1 0 7
                                                                                  1 4 0]
    @test VMES.pairwisematrix(VMES.centersqueeze1, 
        [1,1,1,1,1,1,1,.5,.5,.5,.5]) == [0 5 5
                                        4 0 7
                                        4 2 0]
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
    @test VMES.hontabulate(VMES.centersqueeze1, smithirv)==[0 5 5 -1
                                                            6 0 7 1
                                                            6 4 0 -1]
    @test VMES.hontabulate(VMES.cycle1, smithirv)==[0.0   5.0  9.0  5.0  9.0
                                                    10.0  0.0  4.0  4.0  0.0
                                                    6.0  11.0  0.0  6.0  6.0]
    @test VMES.hontabulate(VMES.cycle2, smithirv)==[0 0 0 4 -1 -1
                                                    15 0 5 9 5 9
                                                    15 10 0 4 4 0
                                                    11 6 11 0 6 6]
    @test VMES.hontabulate(VMES.cycle1, smithplurality)==[0.0   5.0  9.0  5.0
                                                        10.0  0.0  4.0  4.0
                                                        6.0  11.0  0.0  6.0]
    @testset "RCV" begin
        
        @test VMES.hontabulate(VMES.centersqueeze1, irv)==[5; 2; 4;; 5; 0; 6]
        @test VMES.hontabulate(VMES.centersqueeze2, irv)==[6; 3; 3;; 6; 6; 0]
        @test VMES.placementsfromtab([6; 3; 3;; 6; 6; 0], irv) == [1,2,3]
        @test VMES.placementsfromtab([5; 2; 4;; 5; 0; 6], irv) == [3, 1, 2]
        @test VMES.hontabulate(VMES.fivecand2party, rcv, 1)==[  8.0  12.0  12.0  12.0
                                                                4.0   0     0     0
                                                                6.0   6.0   6.0   0
                                                                6.0   6.0  11.0  17.0
                                                                5.0   5.0   0     0]
        @test VMES.placementsfromtab([  8.0  12.0  12.0  12.0
                                        4.0   0     0     0
                                        6.0   6.0   6.0   0
                                        6.0   6.0  11.0  17.0
                                        5.0   5.0   0     0], rcv, 1) == [4, 1, 3, 5, 2]
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
        @test VMES.placementsfromtab([ 8.0  8.0   8.0  8.0
                                        4.0  4.0   0.0  0.0
                                        6.0  6.0  10.0  8.0
                                        6.0  6.0   6.0  8.0
                                        5.0  5.0   5.0  5.0], rcv, 3) == [1, 3, 4, 5, 2]
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
        @test tabulate(VMES.manybulletranked, buirv, 3) == [7 7 7 
                                                          4 4 0
                                                          6 6 6
                                                          20 20 24
                                                          3 0 0]
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

    tab = VMES.hontabulate(VMES.centersqueeze1, VMES.allocatedrankedrobin, 2)
    @test tab[:, end] == [2.0, 2.0, -1.0]
    @test tab[3, 5] == 4*5.5/9
    @test VMES.hontabulate(VMES.cycle2, VMES.allocatedrankedrobin, 3)[:, end] == [-1, 0, 3, 4]
    @test VMES.hontabulate(VMES.manybulletranked, VMES.stvminimax, 3) == [  0.0  16.0  10.0  16.0  17.0   7.0   7.0   7.25   0.0
                                                                            24.0   0.0  34.0  18.0  17.0   4.0   4.0   4.75  12.0
                                                                            30.0   6.0   0.0  14.0  17.0   6.0   6.0   6.0    6.0
                                                                            24.0  22.0  26.0   0.0  37.0  20.0  11.0  11.0   11.0
                                                                            23.0  23.0  23.0   3.0   0.0   3.0  12.0  11.0   11.0]

    @testset "SCV" begin
        @test VMES.tabulate(VMES.scoretest1, scv, 2) ≈  [70.0 10.0 70.0 6.0 6.0
                                                         55.0 0.0 0.0 0.0 5.0
                                                         25.0 5.0 0.0 5.0 0.0
                                                         50.0 10.0 50.0 4.0 4.0]
        @test VMES.tabulate(VMES.scoretest1, scvr, 2) ≈ [70.0  0.0  15.0  10.0  5.0  10.0  70.0  6.0  6.0  6.0
                                                        55.0  0.0   0.0  10.0  5.0   0.0   0.0  0.0  5.0  0.0
                                                        25.0  5.0   5.0   0.0  5.0   5.0   0.0  5.0  0.0  0.0
                                                        50.0  0.0  10.0  10.0  0.0  10.0  50.0  4.0  4.0  6.0]
        @test VMES.tabulate(VMES.scoretest2, scvr, 2) ≈ [50.0  0.0  10.0  10.0  10.0  10.0  50.0  6.0  6.0  6.0
                                                        20.0  0.0   0.0  10.0  10.0   0.0   0.0  4.0  4.0  6.0
                                                        35.0  5.0   5.0   0.0  10.0   5.0   0.0  5.0  5.0  0.0
                                                        25.0  5.0   5.0   0.0   0.0   5.0   0.0  5.0  0.0  0.0]
        @test VMES.tabulate(VMES.scoretest2, VMES.scvr, 3) ≈ [50.0  0.0  10.0  10.0  10.0  10.0  50.0  4.0   0.0  4.0   0.0  4.0  4.0
                                                            20.0  0.0   0.0  10.0  10.0   0.0   0.0  6.0  20.0  6.0  20.0  4.0  4.0
                                                            35.0  5.0   5.0   0.0  10.0   5.0  35.0  5.0  35.0  4.0   0.0  4.0  4.0
                                                            25.0  5.0   5.0   0.0   0.0   5.0  25.0  5.0  25.0  1.0   0.0  1.0  0.0]
    end

    

    @testset "Approval-based PR methods" begin
        ballots = [1;1;1;0;;1;1;1;0;;1;1;1;0;;0;1;1;0;;0;0;0;1]
        @test VMES.tabulate(ballots, approval) == [3;4;4;1;;]
        @test VMES.tabulate(ballots, spav,4 ) ≈ [3 1.5 1 1
                                                  4 4 4 4
                                                  4 2 2 2
                                                  1 1 1 1]
        @test VMES.tabulate([0;0;0;0;;0;0;0;0], spav,2 ) ≈ [0 0
                                                            0 0
                                                            0 0
                                                            0 0]
        @test VMES.tabulate(ballots, spav_sl,4 ) ≈ [3 1 3/5 3/5
                                                     4 4 4 4
                                                     4 4/3 4/3 4/3
                                                     1 1 1 1]
        @test VMES.tabulate(ballots, spav_msl,4 ) ≈ [3/1.4 1 3/5 3/5
                                                    4/1.4 4/1.4 4/1.4 4/1.4
                                                    4/1.4 4/3 4/3 4/3
                                                    1/1.4 1/1.4 1/1.4 1/1.4]
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
        trickyballots = [0 0 0 0 0 0 1 0 0 0 0 5 0 0 0 0 0 0 0 5 0 5 0 0 0
                        0 0 0 5 5 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 5 0 0
                        0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0
                        5 0 4 0 0 0 0 5 0 0 2 0 5 5 0 5 0 5 5 0 5 0 0 0 5
                        0 0 0 5 5 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 5 0 0
                        0 5 0 0 0 0 0 0 5 0 0 0 0 0 0 0 5 0 0 0 0 0 0 0 1
                        4 0 5 0 1 0 0 4 0 0 2 0 4 3 0 4 0 4 3 0 4 0 0 0 3
                        1 0 3 0 2 0 0 1 0 0 5 0 1 0 0 1 0 1 0 0 1 0 0 0 0
                        0 0 0 0 0 0 1 0 0 0 0 5 0 0 0 0 0 0 0 5 0 5 0 0 0
                        0 0 0 0 0 5 5 0 0 5 0 5 0 0 5 0 0 0 0 0 0 5 0 5 0]
        #These previously caused the MES-Droop tabulation to enter an infinite loop
        @test VMES.tabulate(trickyballots, mesdroop, 4)[1,1] == 4
    end
end