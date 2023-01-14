using VMES
using Test

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
end