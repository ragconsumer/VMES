@testset "Metrics" begin
    @testset "VSE" begin
        methods = [plurality, irv, minimax]
        strats = [ElectorateStrategy(hon, 11) for _ in 1:3]
        vses = calc_vses(10, VMES.TestModel(VMES.centersqueeze1), methods, strats, 11, 3).VSE
        @test vses ≈ [(10.5 - 32.5/3)/(13-32.5/3), (9 - 32.5/3)/(13-32.5/3), 1]

        electorate = [10;0;0;0;;10;0;0;0;;0;10;6;0;;0;0;10;0]
        qs, highs, avgs = VMES.mw_winner_quality(electorate, [[1,2,3],[1,2,4],[1,3,4],[2,3,4]], 3)
        @test highs == [5; 5; 10]
        @test qs == [1.5; 0; 0; 1.5;; 46/12;30/12;36/12;26/12;; 10;7.5;9;5]

        qs, highs, avgs = VMES.simple_mw_winner_quality(electorate, [[1,2,3],[1,2,4],[1,3,4],[2,3,4]])
        @test highs == [5; 5; 5]
        @test avgs ≈ [46/16, 46/16, 46/16]
        @test qs == [1.5; 0; 0; 1.5;; 46/12;30/12;36/12;26/12;; 10;7.5;9;5]
        vpos = [0 0
                0 0.]
        cpos = [1 -1 1 
                -1 1 1.]
        cares = [1 1
                 1 1.]
        se = VMES.SpatialElectorate(vpos, cares, cpos, 42)
        qs, highs, avgs = VMES.simple_mw_winner_quality(se, [[1,2],[1,3]])
        @test highs[4] ≈ -sqrt(2)
        @test qs[1, 4] == 0
        @test qs[2, 4] ≈ -1
    end

    @testset "Primary VSE" begin
        ge_methods = [plurality, irv, minimax]
        primary_methods = [sntv, sntv, sntv]
        strats = [ElectorateStrategy(hon, 11) for _ in 1:3]
        vses = calc_primary_vse(10, VMES.TestModel(VMES.centersqueeze1),
                                primary_methods, strats, ge_methods, strats, 11, 11, 3, 3).VSE
        @test vses ≈ [(10.5 - 32.5/3)/(13-32.5/3), (9 - 32.5/3)/(13-32.5/3), 1]
        ge_methods = [approval, minimax, minimax]
        vses = calc_primary_vse(10, VMES.TestModel(VMES.centersqueeze1),
                                primary_methods, strats, ge_methods, strats, 11, 11, 3, 1:3).VSE
        @test vses ≈ [(10.5 - 32.5/3)/(13-32.5/3), (9 - 32.5/3)/(13-32.5/3), 1]
        ge_methods = [plurality, plurality, plurality]
        primary_strats = [ElectorateStrategy(hon, 5) for _ in 1:3]
        vses = VMES.calc_primary_vse(10, VMES.TestModel(VMES.centersqueeze1),
                                primary_methods, primary_strats, ge_methods, strats, 5, 11, 3, 1).VSE
        @test vses[1] ≈ (10.5 - 32.5/3)/(13-32.5/3)
        vses = VMES.calc_primary_vse(100, VMES.TestModel(VMES.centersqueeze1),
                                primary_methods, primary_strats, ge_methods, strats, 5, 11, 3, 1, true).VSE
        @test -.5 < vses[1] < .16
    end

    @testset "CID" begin
        @test VMES.normalizedUtilDeviation([0,10],1) == -1
        @test VMES.utilDeviation([0,10],1) == -5
        @test VMES.utilDeviation([0,10],2) == 5
        @test VMES.utilDeviation([0,10,5],3) == 0
        @test VMES.devFromTop([0,10,5],3) == -5
        @test VMES.devFromTop([0,10,5],2) == 5
        @test VMES.devFromTop([0,10,10],3) == 0
        @test VMES.normDevFromTop([0,10],2) == 2
        e = [0;0.9;1;;0;0.9;1;;0;0.9;1]
        es = ElectorateStrategy(abstain, 2, 2, 2)
        @test VMES.cidrevote(e, [5,1,4], es, approval, Dict(nothing=>nothing)) == [0;0;1;;0;0;0;;0;1;1]
        e = [0;0.9;1;;0;0.9;1;;5;0.9;1]
        @test VMES.cidrevote(e, [5,1,4], es, approval, Dict(nothing=>nothing)) == [0;0;1;;0;0;0;;1;0;0]
        ic = [0;0;;5;0;;0;0]
        VMES.updateincentivecounts!(ic, 1, 1, [1,3], [1,2], 1, 1, (false, false, false, false))
        @test ic == [0;0;;5;0;;0;0]
        VMES.updateincentivecounts!(ic, 1, 1, [1,3], [1,2], 1, 1, (true, true, true, true))
        @test ic == [0;0;;5;0;;0;0]
        VMES.updateincentivecounts!(ic, 1, 1, [1,3], [1,2], 3, 1, (false, true, true, true))
        @test ic == [0;0;;5;0;;0;0]
        VMES.updateincentivecounts!(ic, 1, 1, [1,3], [1,2], 3, 1, (true, false, false, false))
        @test ic == [1;0;;5;0;;0;0]
        VMES.updateincentivecounts!(ic, 1, 1, [1,3], [1,2], 2, 1, (true, true, true, false))
        @test ic == [1;0;;5;0;;0;0]
        VMES.updateincentivecounts!(ic, 1, 1, [1,3], [1,2], 2, 1, (false, false, false, true))
        @test ic == [0;0;;5;0;;0;0]
        VMES.updateincentivecounts!(ic, 1, 1, [1,3], [1,2], 2, -1, (true, false, true, true))
        @test ic == [0;0;;5;0;;0;0]
        VMES.updateincentivecounts!(ic, 2, 3, [1,3], [1,2], 2, -1, (false, true, false, false))
        @test ic == [0;0;;5;0;;0;1]
        VMES.updateincentivecounts!(ic, 1, 2, [1,3], [1,2], 3, -1, (true, true, false, true))
        @test ic == [0;0;;5;0;;0;1]
        VMES.updateincentivecounts!(ic, 1, 2, [1,3], [1,2], 3, -1, (false, false, true, false))
        @test ic == [0;0;;4;0;;0;1]
        e = reduce(hcat, [k,1,0] for k in 1:12)
        s = VMES.normalizedUtilDeviation
        @test VMES.assignbuckets(e,1,4,3,s) == [1 4 7 10
                                                2 5 8 11
                                                3 6 9 12]
        e = reduce(hcat, [-k,1,0] for k in 1:12)
        @test VMES.assignbuckets(e,1,4,3,s) == [12 9 6 3
                                                11 8 5 2
                                                10 7 4 1]
        ic = [0;0;;0;0;;0;0]
        approvalbaseballots = [1 1 0
                               1 1 1
                               0 0 0]
        irvbaseballots = [2 0 1
                          1 1 2
                          0 2 0]
        baseballotsets = [approvalbaseballots, irvbaseballots]
        basewinnersets = [[2],[2]]
        VMES.innercidbasic!(ic, 1,
                            [5;1;0;;], 1, [1],
                            baseballotsets, [[2],[2]], Dict(nothing=>nothing), 
                            [approval, irv], [ElectorateStrategy(hon, 3), ElectorateStrategy(hon, 3)],
                            1, 1, (true, true, true, true))
        @test ic == [1;0;;0;0;;0;0]
        @test baseballotsets == [[1;1;0;;1;1;0;;0;1;0], [2;1;0;;0;1;2;;1;2;0]]
        VMES.innercidbasic!(ic, 2,
                            [5;1;0;;], 1, [2],
                            baseballotsets, [[2],[2]], Dict(nothing=>nothing), 
                            [approval, irv], [ElectorateStrategy(hon, 3), ElectorateStrategy(hon, 3)],
                            1, 1, (true, true, true, true))
        @test ic == [0;-1;;0;0;;0;0]
        e =[2;1;0;;2;1;0;;0.9;1;1.0001]
        ic = [0;0;;0;0;;0;0]
        vaes = esfromtemplate(ESTemplate(3,[[(hon, 1, 3)], [(pluralityvatemplate,1,2)]]), 0.1)
        VMES.innercidnewpolls!(ic, 1, [1.9,1,1.0001],1,[3],e,[[2], [1]],[-0.4, 0.4, 0], 0.0, [plurality, minimax],
            [vaes, ElectorateStrategy(hon,3)], 1, 1, (true, true, true, true))
        @test ic == [1;0;;0;0;;0;0]
        @test e == [2;1;0;;2;1;0;;0.9;1;1.0001]

        #test calc_cid
        methods = [plurality, minimax]
        estrats = [ElectorateStrategy(hon, 3), ElectorateStrategy(hon, 3)]
        electorate = [1.01;1;0;;1;2;0;;0;0.01;5]
        df = calc_cid(10, VMES.TestModel(electorate), methods, estrats, 3, 3, 1, 1)
        @test df.CID == [0,1.5,1.5,3,0,0]
        @test df.Total == [0,10,10,20,0,0]
    end

    @testset "Cid summary statistics" begin
        df = DataFrame(:Method=>repeat([plurality],12), :CID=>repeat([1],12), :Bucket=>1:12, Symbol("Total Buckets")=>repeat([12],12),
            Symbol("Electorate Strategy") => repeat([nothing],12),
            :ncand => repeat([nothing],12), Symbol("Utility Change") => repeat([nothing],12))
        @test influence_cdf(df, 1/2)[1, "CS0.5"] == 0.5
        df = DataFrame(:Method=>repeat([plurality],12), :CID=>repeat([1],12), Symbol("Electorate Strategy") => repeat([nothing],12),
                        :ncand => repeat([nothing],12), Symbol("Utility Change") => repeat([nothing],12),
                        :Bucket=>12:-1:1, Symbol("Total Buckets")=>repeat([12],12), :Iterations => repeat([nothing],12))
        @test influence_cdf(df, 1//4)[1, "CS1//4"] == 0.25
        @test total_variation_distance_from_uniform([2,2,2,2]) == 0
        @test total_variation_distance_from_uniform([1,0,1,0]) == 0.5
        @test total_variation_distance_from_uniform([1,1,0,0]) == 0.5
        @test total_variation_distance_from_uniform([0,1,0,0]) == 0.75
        @test earth_movers_distance_from_uniform([1,0,1,0]) == 1/8
        @test earth_movers_distance_from_uniform([1,0,1,0,1,0]) == 1/12
        @test earth_movers_distance_from_uniform([0,1,1,0]) == 1/8
        @test earth_movers_distance_from_uniform([1,1,0,0]) == 1/4
        @test earth_movers_distance_from_uniform([1,0,0,0]) == 3/8
        @test earth_movers_distance_from_uniform([0.5,0.5,0,0]) == 1/4
        @test distance_from_uniform(total_variation_distance_from_uniform, df)[1, "DFU"] == 0
        @test distance_from_uniform(earth_movers_distance_from_uniform, df)[1, "DFU"] == 0
        df = DataFrame(:Method=>repeat([plurality],4), :CID=>[1,1,0,0], :Bucket=>[1,3,2,4],
                        Symbol("Electorate Strategy") => repeat([nothing],4),
                        :ncand => repeat([nothing],4), Symbol("Utility Change") => repeat([nothing],4),
                        :Iterations => repeat([nothing],4))
        @test distance_from_uniform(total_variation_distance_from_uniform, df)[1, "DFU"] == 0.5
        @test distance_from_uniform(earth_movers_distance_from_uniform, df)[1, "DFU"] == 1/8
    end
    
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
        stratinputs, methodinputs = VMES.getadminpollsinput(methodsandstrats, 0.1)
        @test stratinputs == [hon, hon, bullet, ExpScale(2), bullet, hon, bullet, ExpScale(2), hon, bullet, abstain]
        @test methodinputs == [repeat([star], 8); repeat([rcv], 3)]

        #test one_esif_iter
        methodsandstrats = [([score, star], [ElectorateStrategy(topmeanem,3), ElectorateStrategy(ExpScale(3, topmeanem),3)], [topmeanem, bullet]),
                            ([rcv], [ElectorateStrategy(bullet,3)], [abstain, bullet, hon])]
        electorate = [0;1;2;-10;;2;0;1;-10;;1;2;0;-10] #symmetric reverse spoiler scenario (also a Condorcet cycle)
        utiltotals = VMES.one_stratmetric_iter(VMES.ESIF(), VMES.TestModel(electorate), methodsandstrats, 3, 4, 0, 0, 1, ())
        @test utiltotals == [0. 3 0 1 -3 3 0 -3 -2 0 1]

        esifs = calc_esif(10, VMES.TestModel(electorate), methodsandstrats, 3, 4).ESIF
        @test esifs == [1, 2, 1, 4/3, 0, 2, 1, -0.5, 0, 1, 1.5]

        totals = [-3 0. 3 -3 0 1 -3 -3 3 -2 0 -3 -2 -2 0 1]
        @test VMES.strategic_totals_to_df(totals, methodsandstrats).ESIF == [1, 2, 1, 4/3, 0, 2, 1, -0.5, 0, 1, 1.5]

        #test seeding DOES NOT CURRENTLY ALWAYS WORK
        #for _ in 1:20
            seed = abs(rand(Int))
            df1 = calc_esif(10, dcc, [([score, star],
                            [ElectorateStrategy(hon, 11), ElectorateStrategy(ExpScale(3, topmeanem),11)], [bullet, hon, starvatemplate])],
                            11, 5, iidnoise=0.1, seed=seed)
            df2 = calc_esif(10, dcc, [([score, star],
                            [ElectorateStrategy(hon, 11), ElectorateStrategy(ExpScale(3, topmeanem),11)], [bullet, hon, starvatemplate])],
                            11, 5, iidnoise=0.1, seed=seed)
            #@test df1 == df2
        #end
    end

    @testset "Strategy Statistics" begin
        electorate = [0;1;3;5;;5;4;4;0;;5;4;4;0;;3;4;5;0;;0;5;4;0;;0;0;0;5]
        strat_totals = VMES.strat_stats_one_iter(VMES.TestModel(electorate), [star, irv],
                                [ElectorateStrategy(hon, 6), ElectorateStrategy(hon, 6)], 6, 4, 1)
        @test strat_totals[1] == [Dict(3=>1, 4=>3, 5=>1, 0=>1);
                                    Dict(1=>1, 4=>3, 5=>1, 0=>1);
                                    Dict(2=>1, 5=>2, 0=>3);
                                    Dict(5=>2, 0=>4);;
                                    Dict(3=>2, 2=>1, 1=>2, 0=>1);
                                    Dict(3=>1, 2=>3, 1=>2);
                                    Dict(3=>2, 0=>4);
                                    Dict(3=>1, 2=>2, 1=>2, 0=>1)]
        @test strat_totals[2] == [1,0]
        @test strat_totals[3] == [Dict(0=>3, 2=>1, 1=>2);
                                    Dict(1=>5, 2=>1)]
        @test strat_totals[4] == [Dict(0=>1, 1=>2, 3=>2, 5=>1);
                                    Dict(2=>2, 3=>4)]
        dfs = collect_strat_stats(10, VMES.TestModel(electorate), [star, irv],
                            [ElectorateStrategy(hon, 6), ElectorateStrategy(hon, 6)], 6, 4, 1)
        @test dfs[1][!,"Bullet Votes"] == [1/6, 0]
        @test dfs[1][!,"Mean Score"] == [Statistics.mean([0;1;3;5;;5;4;4;0;;5;4;4;0;;2;4;5;0;;0;5;4;0;;0;0;0;5]), 1.5]
        @test dfs[1][!,"Top 2 Spread"] == [2/3, 7/6]
        @test dfs[1][!,"Top 3 Spread"] ≈ [13/6, 16/6]
    end

    @testset "Voter Model Statistics" begin
        @test !VMES.hascondorcetcycle([1;2;;2;1])
        @test !VMES.hascondorcetcycle([1;2;3;;2;3;1;;3;3;3])
        @test VMES.hascondorcetcycle([1;2;3;;2;3;1;;3;1;2])
    end
end