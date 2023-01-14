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
    @test vote([1,4,3,5],bullet,pluralitytop2) == [[0,0,0,1];;[0,2,1,3]]
    @test vote([1,4,3,5],bullet,VMES.Top2Method(VMES.score)) == [[0,0,0,5];;[0,2,1,3]]
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