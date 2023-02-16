

"""
Describes the strategies used by all the voters in an electorate.

flexible_strategists: The number of voters who may change strategies for PVSI, ESIF, etc.
stratlist: A vector of voter strategies
stratusers: A vector of integertuples; stratusers[i] gives the indicies of the first and last
    voters who use the ith strategy of stratlist

The voters with the lowest indicies will the flexible strategists.
The strategy or strategies you want the flexible strategists to use by default
should be at the beginning of stratlist.
"""
struct ElectorateStrategy
    flexible_strategists::Int
    stratlist::Vector{VoterStrategy}
    stratusers::Vector{Tuple{Int, Int}}
end

function ElectorateStrategy(flexible_strategists::Int, stratlist::Vector{<:VoterStrategy}, usercounts::Vector{Int})
    stratusers = Vector{Tuple{Int, Int}}(undef, length(stratlist))
    voteri = 1
    for strati in eachindex(stratlist)
        stratusers[strati] = (voteri, voteri + usercounts[strati] - 1)
        voteri += usercounts[strati]
    end
    return ElectorateStrategy(flexible_strategists, stratlist, stratusers)
end

function Base.:(==)(x::ElectorateStrategy, y::ElectorateStrategy)
    x.flexible_strategists == y.flexible_strategists && x.stratlist == y.stratlist && x.stratusers == y.stratusers
end

"""
    stratusercounts(estrat::ElectorateStrategy)

Create a list of the numbers of users of each strategy in an electorate strategy.
"""
stratusercounts(estrat::ElectorateStrategy) = [high-low+1 for (low, high) in estrat.stratusers]

function Base.show(io::IO, estrat::ElectorateStrategy)
    counts = stratusercounts(estrat)
    print(io, "(")
    for i in 1:length(estrat.stratlist)-1
        print(io, estrat.stratlist[i],":",counts[i], ",")
    end
    print(io, estrat.stratlist[end],":",counts[end],")")
end

function Base.hash(es::ElectorateStrategy, h::UInt)
    h = hash(es.flexible_strategists, h)
    h = hash(es.stratlist, h)
    h = hash(es.stratusers, h)
end
"""
    ElectorateStrategy(strategy, nstrategists::Int, nhons::Int, nbullets::Int)

Create an ElectorateStrategy that has nstrategists using strategy (and being open to further strategizing for PVSI and ESIF),
nhons voters voting honestly, and nbullets voters bullet voting no matter what.
"""
function ElectorateStrategy(strategy::VoterStrategy, nstrategists::Int, nhons::Int, nbullets::Int)
    return ElectorateStrategy(nstrategists, [strategy, hon, bullet], [nstrategists, nhons, nbullets])
end

"""
    ElectorateStrategy(strategy::VoterStrategy, nvot::Int)

Create an ElectorateStrategy in which everyone uses the same strategy.
"""
ElectorateStrategy(strategy::VoterStrategy, nvot::Int) = ElectorateStrategy(nvot, [strategy], [nvot])

"""
    castballots(electorate::Matrix, estrat::ElectorateStrategy, method::VotingMethod, polldict)

Everyone votes in accordance with estrat.
"""
function castballots(electorate::AbstractMatrix, estrat::ElectorateStrategy, method::VotingMethod, infodict=nothing)
    nvot = size(electorate, 2)
    stratindex = 1
    stratvector = Vector{Int}(undef, nvot)
    for i in 1:nvot
        while i > estrat.stratusers[stratindex][2]
            stratindex += 1
        end
        stratvector[i] = stratindex
    end

    ballots = Array{ballotmarktype(method)}(undef, getballotsize(method, size(electorate, 1)), nvot)
    for (i, voter) in enumerate(eachslice(electorate,dims=2))
        strat = estrat.stratlist[stratvector[i]]
        info_for_strat = isnothing(info_used(strat, method)) ? nothing : infodict[info_used(strat, method)]
        ballots[:, i] = vote(voter, strat, method, info_for_strat)
    end
    return ballots
end

"""
    castballots(electorate::Matrix, strat::VoterStrategy, method::VotingMethod, polldict=nothing)

The entire electorate casts ballots using strat.
"""
function castballots(electorate::AbstractMatrix, strat::VoterStrategy, method::VotingMethod, polldict=nothing)
    estrat = ElectorateStrategy(0, [strat], [size(electorate, 2)])
    castballots(electorate, estrat, method, polldict)
end

"""
    hontabulate(electorate::Matrix, method::VotingMethod)

Tabulate the election that happens when everyone votes honestly.
"""
function hontabulate(electorate::AbstractMatrix, method::VotingMethod, nwinners=1)
    ballots = castballots(electorate, hon, method, nwinners)
    tabulate(ballots, method, nwinners)
end

"""
    stratatindex(es::ElectorateStrategy, index)

Find the strategy used by the voter at the given index.
"""
function stratatindex(es::ElectorateStrategy, index)
    for i in eachindex(es.stratlist)
        if es.stratusers[i][1] <= index <= es.stratusers[i][2]
            return es.stratlist[i]
        end
    end
end