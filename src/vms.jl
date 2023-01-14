export tabulate, getwinners
export plurality, pluralitytop2, approval, approvaltop2, star, irv, borda, minimax, rankedrobin

abstract type VotingMethod end
abstract type OneRoundMethod <: VotingMethod end #as opposed to top 2; this includes IRV
abstract type RankedMethod <: OneRoundMethod end
abstract type ScoringMethod <: OneRoundMethod end
abstract type ApprovalMethod <: OneRoundMethod end
abstract type RankedCondorcet <: RankedMethod end
abstract type CondorcetCompMatOnly <: RankedCondorcet end

struct Top2Method <: VotingMethod
    basemethod::OneRoundMethod
end
struct Smith <: OneRoundMethod
    basemethod::OneRoundMethod
end

struct PluralityVoting <: ApprovalMethod; end
plurality = PluralityVoting()
pluralitytop2 = Top2Method(plurality)
struct ApprovalVoting <: ApprovalMethod; end
approval = ApprovalVoting()
approvaltop2 = Top2Method(approval)

struct ScoreVoting <: ScoringMethod
    maxscore::Int8
end
score = ScoreVoting(5)
struct STARVoting <: ScoringMethod
    maxscore::Int8
end
star = STARVoting(5)

struct InstantRunoffVoting <: RankedMethod; end
irv = InstantRunoffVoting()
struct BordaCount <: RankedMethod; end
borda = BordaCount()

struct Minimax <: RankedCondorcet; end
minimax = Minimax()
struct RankedRobin <: RankedCondorcet; end
rankedrobin = RankedRobin()

smithscore = Smith(score)

"""
    tabulate(::OneRoundMethod, ballots)
    
Tabulate the results of the method with the given ballots.

When there is a tie it will be resolved in favor of the candidate(s) with the lowest index.
The returned object is an array that describes the full tabulation.

# Examples
```jldoctest
"""
function tabulate(::OneRoundMethod, ballots)
    results = sum(ballots, dims=2)
    return results
end

"""
    tabulate(method::Top2Method, ballots)

Tabulate a top two voting method. The results of the runoff will appear in the rightmost column.
"""
function tabulate(method::Top2Method, ballots::AbstractArray{T,2}) where T
    ncands = div(size(ballots, 2), 2)
    r1results = tabulate(method.basemethod, view(ballots, :, 1:ncands))
    relevantresults = view(r1results, :, size(r1results, 2))
    finalists = sort(top2(relevantresults))
    tallies = zeros(T, ncands)
    for ranking in view(ballots, :, ncands+1:2ncands)
        if ranking[finalists[1]] > ranking[finalists[2]]
            tallies[finalists[1]] += 1
        elseif ranking[finalists[1]] < ranking[finalists[2]]
            tallies[finalists[2]] += 1
        end
    end
    return [r1results tallies]
end

"""    
end
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
julia> VMs.top2([1,2,3,4,5])
(5, 4)
julia> VMs.top2([1,2,2,1,3])
(5, 2)
julia> VMs.top2([1,1,1,1])
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
    for i in 3:length(results)
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