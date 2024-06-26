abstract type VotingMethod end
abstract type OneRoundMethod <: VotingMethod end #as opposed to top 2; this includes IRV
abstract type RankedMethod <: OneRoundMethod end
abstract type CardinalMethod <: OneRoundMethod end
abstract type ScoringMethod <: CardinalMethod end
abstract type ApprovalMethod <: CardinalMethod end
abstract type PluralityMethod <: ApprovalMethod end
abstract type RankedCondorcet <: RankedMethod end
abstract type CondorcetCompMatOnly <: RankedCondorcet end
abstract type RankedChoiceVoting <: RankedMethod end

vmnames = Dict{VotingMethod, String}()

include("mwmethods.jl")

struct Top2Method{T} <: VotingMethod
    basemethod::T
end
struct Smith{T} <: OneRoundMethod
    basemethod::T
end

struct PluralityVoting <: PluralityMethod; end #irrelevant that it's considered a cardinal method in the code
@namevm plurality = PluralityVoting()
@namevm pluralitytop2 = Top2Method(plurality)
struct RankedPlurality <: RankedMethod; end #Elects the Plurality winner from ranked ballots.
struct ApprovalVoting <: ApprovalMethod; end
@namevm approval = ApprovalVoting()
@namevm approvaltop2 = Top2Method(approval)

struct ScoreVoting <: ScoringMethod
    maxscore::Int
end
@namevm score = ScoreVoting(5)
struct STARVoting <: ScoringMethod
    maxscore::Int
end
@namevm star = STARVoting(5)

struct BordaCount <: RankedMethod; end
@namevm borda = BordaCount()

struct Minimax <: CondorcetCompMatOnly; end
@namevm minimax = Minimax()
struct RankedRobin <: CondorcetCompMatOnly; end
@namevm rankedrobin = RankedRobin()

@namevm smithscore = Smith(score)
@namevm smithirv = Smith(irv)
@namevm smithplurality = Smith(RankedPlurality())


function Base.show(io::IO, m::M) where {M <: VotingMethod}
    if m in keys(vmnames)
        print(io, vmnames[m])
    else
        print(io, M, [getfield(m, i) for i in 1:fieldcount(M)])
    end
end

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

tabulate(ballots, method::ApprovalMethod, ::Int) = tabulate(ballots, method)

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
function tabulate(ballots::AbstractMatrix, method::Top2Method)
    ncands = div(size(ballots, 1), 2)
    r1results = tabulate(view(ballots, 1:ncands, :), method.basemethod)
    relevantresults = view(r1results, :, size(r1results, 2))
    finalists = sort(top2(relevantresults))
    tallies = zeros(Int, ncands)
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
    getballotsize(::OneRoundMethod, ncand)

Return the length of an array that represents a ballot.
"""
getballotsize(::OneRoundMethod, ncand) = ncand
getballotsize(::Top2Method, ncand) = 2ncand

ballotmarktype(::VotingMethod) = Int

topballotmark(_, ::ApprovalMethod) = 1
topballotmark(_, method::ScoringMethod) = method.maxscore
topballotmark(voter, ::RankedMethod) = length(voter) - 1
topballotmark(voter, method::Top2Method) = topballotmark(voter, method.basemethod)


"""
    getwinners(ballots::AbstractArray, method::VotingMethod, nwinners=1)

Determine the winners for the given ballots and voting method.
"""
function getwinners(ballots::AbstractArray, method::VotingMethod, nwinners=1)
    winnersfromtab(tabulate(ballots, method, nwinners), method, nwinners)
end

"""    
    winnersfromtab(tabulation::AbstractArray, ::VotingMethod)

Determine the winner and put it in a vector of length 1.

Resolves ties to always favor the candidates with the lowest indicies.
"""
function winnersfromtab(tabulation::AbstractArray, ::VotingMethod)
    return [argmax(tabulation[:,end])]
end

"""
    winnersfromtab(tabulation::AbstractArray, method::VotingMethod, nwinners::Integer)

Determine nwinners winning candidates.
"""
function winnersfromtab(tabulation::AbstractArray, method::VotingMethod, nwinners::Integer)
    if nwinners == 1
        return winnersfromtab(tabulation, method)
    else
        return indices_by_sorted_values(tabulation[:, end])[1:nwinners]
        result_tuples = [(i, result) for (i, result) in enumerate(tabulation[:,end])]
        sort!(result_tuples,
            lt=((i1, r1), (i2, r2))->r1<r2 ? true : r1==r2 && i1>i2 ? true : false,
            rev=true)
        return[i for (i, _) in result_tuples[1:nwinners]]
    end
end

"""
    indices_by_sorted_values(values::AbstractArray)

Return a vector v with the property values[v] == sort(values, rev=true)

(Up to ties, which are broken s.t. lower indicies mean greater values)
"""
function indices_by_sorted_values(values::AbstractArray)
    result_tuples = [(i, result) for (i, result) in enumerate(values)]
    sort!(result_tuples,
            lt=((i1, r1), (i2, r2))->r1<r2 ? true : r1==r2 && i1>i2 ? true : false,
            rev=true)
    return[i for (i, _) in result_tuples]
end

"""
    placementsfromtab(tabulation::AbstractArray, ::VotingMethod)

Determine the first-place, second-place, etc. candidates.
"""
placementsfromtab(tabulation::AbstractArray, method::VotingMethod, _) = placementsfromtab(tabulation, method)

placementsfromtab(tabulation::AbstractArray, ::VotingMethod) = indices_by_sorted_values(tabulation[:, end])

function placementsfromtab(tabulation::AbstractArray, ::Union{Top2Method, STARVoting})
    placements = indices_by_sorted_values(tabulation[:, 1])
    if argmax(tabulation[:, end]) != placements[1]
        placements[1], placements[2] = placements[2], placements[1]
    end
    return placements
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

function tabulate(ballots, ::RankedPlurality)
    n = size(ballots, 1)
    totals = zeros(Int, n)
    for ballot in eachslice(ballots, dims=2)
        m = maximum(ballot)
        for c in 1:n
            if ballot[c] == m
                totals[c] += 1
            end
        end
    end
    return totals
end

"""
    star_runoff(ballots, finalist1, finalist2)

Perform a STAR-style runoff between the finalists.
"""
function star_runoff(ballots, finalist1, finalist2)
    tallies = -ones(Int, size(ballots, 1))
    tallies[finalist1] = 0
    tallies[finalist2] = 0
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

"""
    pairwisematrix(ballots_or_utils)

Computer the Condorcet pairwise matrix.

pairwisematrix(ballots)[i, j] is the number of voters prefering i to j.
"""
function pairwisematrix(ballots_or_utils)
    ncands = size(ballots_or_utils, 1)
    mat = Matrix{Int}(undef, ncands, ncands)
    for topcand in 1:ncands
        for leftcand in 1:ncands
            mat[leftcand, topcand] = count(>(0), ballots_or_utils[leftcand, :]-ballots_or_utils[topcand, :])
        end
    end
    return mat
end

function pairwisematrix(ballots_or_utils, weights::Vector{<:Real}, electedcands=Set())
    ncands, nvot = size(ballots_or_utils)
    mat = Matrix{Float64}(undef, ncands, ncands)
    for topcand in 1:ncands
        for leftcand in 1:ncands
            if leftcand in electedcands
                mat[leftcand, topcand] = -1
            elseif topcand in electedcands
                mat[leftcand, topcand] = 1
            else
                mat[leftcand, topcand] = sum(
                    (weights[i] for i in 1:nvot
                        if ballots_or_utils[leftcand, i] > ballots_or_utils[topcand, i]),
                    init=0)
            end
        end
    end
    return mat
end

function tabulate(ballots, method::CondorcetCompMatOnly)
    tabulatefromcompmat(pairwisematrix(ballots), method)
end

function tabulatefromcompmat(compmat, ::Minimax)
    ncands = size(compmat, 1)
    minmargins = [minimum(
        compmat[lcand, tcand] - compmat[tcand, lcand]
        for tcand in 1:ncands if tcand != lcand)
        for lcand in 1:ncands]
    return [compmat minmargins]
end

function tabulatefromcompmat(compmat::Matrix{T}, ::RankedRobin) where T <: Real
    n = size(compmat, 1)
    wincounts = [count(>(0), compmat[lcand, tcand] - compmat[tcand, lcand] for tcand in 1:n) for lcand in 1:n]
    mostwins = maximum(wincounts)
    finalists = [c for c in 1:n if wincounts[c] == mostwins]
    if length(finalists) == 1
        return [compmat wincounts]
    end
    finalmargins = [(lcand ∈ finalists ?
                    sum(compmat[lcand, tcand] - compmat[tcand, lcand] for tcand in finalists) : T(-999))
                    for lcand in 1:n]
    return [compmat wincounts finalmargins]
end

function tabulate(ballots, method::Smith)
    ncand = size(ballots, 1)
    compmat = pairwisematrix(ballots)
    s = smithset(compmat)
    if length(s) == 1
        return [compmat [c in s ? 1 : -1 for c in 1:ncand]]
    else
        inner_results = tabulate(ballots[s, :], method.basemethod)
        return [compmat [c in s ? inner_results[findfirst(x->x==c, s),col] : -1. for c in 1:ncand, col in 1:size(inner_results, 2)]]
    end
end

"""
    smithset(compmat::Array{T}) where T <: Real

Return a vector whose elements are the elements of the Smith set.
"""
function smithset(compmat::Array{T}) where T <: Real
    n = size(compmat, 1)
    wincounts = [count(>(0), compmat[lcand, tcand] - compmat[tcand, lcand] for tcand in 1:n) for lcand in 1:n]
    s = [argmax(wincounts)]
    if wincounts[s[1]] == n-1
        return s
    end
    extensionfound = true
    while extensionfound
        extensionfound = false
        for potentialmember in 1:n
            if potentialmember ∉ s
                for member in s
                    if compmat[potentialmember,member] >= compmat[member, potentialmember]
                        push!(s, potentialmember)
                        extensionfound = true
                        break
                    end
                end
            end
        end
    end
    return s
end

#Score Cascading Vote; given here instead of the mw file since it uses Score
@namevm scv = CascadingScoreMethod(score, droop, 5, false, false)
@namevm scvr = CascadingScoreMethod(score, droop, 5, true, true)
@namevm stvminimax = STVCompMatMethod(minimax, droop)