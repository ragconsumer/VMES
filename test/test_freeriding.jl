@testset "Freeriding" begin
    @test vote([10,0,1], FreeRide(hon, 0, 1), approval) == [0,0,1]
    @test vote([10,9,0,2], FreeRide(hon, 2, 2), star) == [5,2,0,1]
    @test vote([10,9,0,2], FreeRide(bullet, 1, 2), star) == [5,1,0,0]
    @test vote([10,9,0,2], FreeRide(bullet, 2, 1), star) == [2,5,0,0]
    @test vote([10,9,0,2], FreeRide(hon, 2, 2), irv) == [3,2,0,1]
    @test vote([10,9,0,2], FreeRide(hon, 1, 2), irv) == [3,1,0,2]
    @test vote([10,9,0,2], FreeRide(hon, 1, 1), irv) == [1,3,0,2]
    @test vote([10,9,0,2], FreeRide(hon, 1, 3), irv) == [3,2,1,0]
    e = [ 11 12 13
          5  6  7
          8  9 10]
    VMES.order_freeriding_electorate!(e, 1, 2)
    @test e == [12 11 13
                6  5  7
                9  8 10]
    VMES.order_freeriding_electorate!(e, 3, 1)
    @test e == [9  8 10
                6  5  7
                12 11 13]
    VMES.order_freeriding_electorate!(e, 2, 2)
    @test e == [5 6 7
                8 9 10
                11 12 13]
    @test VMES.find_ballot_with_score(
        [4 1 2 3
         2 3 4 1
         3 4 1 2], 2, 4) == 3
    @test VMES.find_ballot_with_score(
        [4 1 5 3
         2 3 4 1
         3 5 1 2], 2, 5) == 0

    e = [5 5 0 0 0 0
        0 0 5 5 5 0
        4 4 4 4 4 5]
    m = FreeRidingModel(
        VMES.TestModel(e),
        [([VMES.sss, VMES.allocatedscore], [VMES.ElectorateStrategy(VMES.hon, 6)])],
        2, 4, 1, 0)
    @test VMES.check_electorate(
        e, m, 3, 1) == true
    @test VMES.check_electorate(
        e, m, 2, 3) == false
    fe = make_electorate(
        m, 6, 3, 42)
    results = castballots(
        fe, VMES.ElectorateStrategy(VMES.hon, 6), VMES.sss)
    @test getwinners(results, VMES.sss, 2) == [1,2]

    fres = VMES.make_free_riding_estrat(
        VMES.ElectorateStrategy(VMES.hon, 6))
    @test fres.stratlist[1] isa FreeRide
    @test length(fres.stratlist) == 2
    @test fres.stratusers == [(1,1), (2,6)]

    fres = VMES.make_free_riding_estrat(
        VMES.ElectorateStrategy(6, [VMES.hon, VMES.bullet], [4,2]))
    @test length(fres.stratlist) == 3
    @test fres.stratusers == [(1,1), (2,4), (5,6)]
    fres = VMES.make_free_riding_estrat(
        VMES.ElectorateStrategy(1, [VMES.hon, VMES.bullet], [1,9]))
    @test length(fres.stratlist) == 2
    @test fres.stratusers == [(1,1), (2,10)]
end