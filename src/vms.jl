abstract type VotingMethod end
abstract type OneRoundMethod <: VotingMethod end #as opposed to top 2; this includes IRV
abstract type RankedMethod <: OneRoundMethod end
abstract type CardinalMethod <: OneRoundMethod end
abstract type ScoringMethod <: CardinalMethod end
abstract type ApprovalMethod <: CardinalMethod end
abstract type RankedCondorcet <: RankedMethod end
abstract type CondorcetCompMatOnly <: RankedCondorcet end
abstract type RankedChoiceVoting <: RankedMethod end

include("mwmethods.jl")

struct Top2Method <: VotingMethod
    basemethod::OneRoundMethod
end
struct Smith <: OneRoundMethod
    basemethod::OneRoundMethod
end

struct PluralityVoting <: ApprovalMethod; end #irrelevant that it's considered a cardinal method in the code
plurality = PluralityVoting()
pluralitytop2 = Top2Method(plurality)
struct ApprovalVoting <: ApprovalMethod; end
approval = ApprovalVoting()
approvaltop2 = Top2Method(approval)

struct ScoreVoting <: ScoringMethod
    maxscore::Int
end
score = ScoreVoting(5)
struct STARVoting <: ScoringMethod
    maxscore::Int
end
star = STARVoting(5)

struct BordaCount <: RankedMethod; end
borda = BordaCount()

struct Minimax <: RankedCondorcet; end
minimax = Minimax()
struct RankedRobin <: RankedCondorcet; end
rankedrobin = RankedRobin()

smithscore = Smith(score)

"""
    tabulate(ballots, method::Votingmethod, nwinners::Int)

Tabulate an election.
"""
function tabulate(ballots, method::VotingMethod, nwinners::Int)
    if nwinners != 1
        throw(ArgumentError("Method not implemented for multiple winners"))
    else
        tabulate(ballots, method)
    end
end

"""
    tabulate(ballots, ::OneRoundMethod)
    
Tabulate the results of the method with the given ballots.

When there is a tie it will be resolved in favor of the candidate(s) with the lowest index.
The returned object is an array that describes the full tabulation.

# Examples
```jldoctest
"""
function tabulate(ballots, ::OneRoundMethod)
    results = sum(ballots, dims=2)
    return results
end

"""
    tabulate(ballots::AbstractArray{T,2}, method::Top2Method) where T

Tabulate a top two voting method. The results of the runoff will appear in the rightmost column.
"""
function tabulate(ballots::AbstractArray{T,2}, method::Top2Method) where T
    ncands = div(size(ballots, 1), 2)
    r1results = tabulate(view(ballots, 1:ncands, :), method.basemethod)
    relevantresults = view(r1results, :, size(r1results, 2))
    finalists = sort(top2(relevantresults))
    tallies = zeros(T, ncands)
    for ranking in eachslice(view(ballots, ncands+1:2ncands, :),dims=2)
        if ranking[finalists[1]] > ranking[finalists[2]]
            tallies[finalists[1]] += 1
        elseif ranking[finalists[1]] < ranking[finalists[2]]
            tallies[finalists[2]] += 1
        end
    end
    return [r1results tallies]
end

"""    
    getwinners(tabulation::AbstractArray, ::VotingMethod)

Determine the winner and put it in a vector of length 1.

Resolves ties to always favor the candidates with the lowest indicies.
"""
function getwinners(tabulation::AbstractArray, ::VotingMethod)
    return [argmax(tabulation[:,end])]
end

"""
    getwinners(tabulation::AbstractArray, method::VotingMethod, nwinners::Integer)

Determine nwinners winning candidates.
"""
function getwinners(tabulation::AbstractArray, method::VotingMethod, nwinners::Integer)
    if nwinners == 1
        return winners(tabulation, method)
    else
        throw(ArgumentError("multiwinner results NYI"))
    end
end

"""
    top2(results)

Return a vector with the indicies of the two highest values.

The lowest indicies win all ties.

# Examples
```jldoctest
julia> VMES.top2([1,2,3,4,5])
(5, 4)
julia> VMES.top2([1,2,2,1,3])
(5, 2)
julia> VMES.top2([1,1,1,1])
(1, 2)

"""
function top2(results)
    if results[2]>results[1]
        bestresult = results[2]
        secondresult = results[1]
        besti = 2
        secondi = 1
    else
        bestresult = results[1]
        secondresult = results[2]
        besti = 1
        secondi = 2
    end
    for i in 3:lastindex(results)
        if results[i] > secondresult
            if results[i] > bestresult
                secondi, secondresult = besti, bestresult
                besti, bestresult = i, results[i]
            else
                secondi, secondresult = i, results[i]
            end
        end
    end
    return [besti, secondi]
end

"""
    star_runoff(ballots, finalist1, finalist2)

Perform a STAR-style runoff between the finalists.
"""
function star_runoff(ballots, finalist1, finalist2)
    tallies = zeros(Int, size(ballots, 1))
    for ballot in eachslice(ballots, dims=2)
        if ballot[finalist1] > ballot[finalist2]
            tallies[finalist1] += 1
        elseif ballot[finalist1] < ballot[finalist2]
            tallies[finalist2] += 1
        end
    end
    return tallies
end

"""
    tabulate(ballots, ::STARVoting)

Tabulate a STAR election.

Tiebreakers are determined by candidate indices; official STAR tiebreaker rules are not used.
(The purpose of this is to eliminate incentives to maximize the difference in scores between finalists
when it's near-certain who the finalists will be. This incentive is negligible in STAR incentives with
large electorates, but could be very significant with well under 100 voters.)
"""
function tabulate(ballots, ::STARVoting)
    r1results = sum(ballots, dims=2)
    runoffresults = star_runoff(ballots, top2(r1results)...)
    return [r1results runoffresults]
end

