

"""
Describes the strategies used by all the voters in an electorate.

flexible_strategists: The number of voters who may change strategies for PVSI, ESIF, etc.
stratlist: A vector of voter strategies
stratusers: A vector of integers; stratusers[i] is the number of voters who use the ith strategy

The voters with the lowest indicies will the flexible strategists.
The strategy or strategies you want the flexible strategists to use by default
should be at the beginning of stratlist.
"""
struct ElectorateStrategy
    flexible_strategists::Int
    stratlist::Vector{VoterStrategy}
    stratusers::Vector{Int}
end

"""
    ElectorateStrategy(strategy, nstrategists::Int, nhons::Int, nbullets::Int)

Create an ElectorateStrategy that has nstrategists using strategy (and being open to further strategizing for PVSI and ESIF),
nhons voters voting honestly, and nbullets voters bullet voting no matter what.
"""
function ElectorateStrategy(strategy::VoterStrategy, nstrategists::Int, nhons::Int, nbullets::Int)
    return ElecorateStrategy(nstrategists, [strategy, hon, bullet], [nstrategists, nhons, nbullets])
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
function castballots(electorate::Matrix, estrat::ElectorateStrategy, method::VotingMethod, infodict=nothing)
    nvot = size(electorate, 2)
    stratindex = 1
    votersleft = estrat.stratusers[1]
    stratvector = Vector{Int}(undef, nvot)
    for i in 1:nvot
        while votersleft == 0
            stratindex += 1
            votersleft = estrat.stratusers[stratindex]
        end
        stratvector[i] = stratindex
        votersleft -= 1
    end

    ballots = Array{Any}(undef, nvot)
    for (i, voter) in enumerate(eachslice(electorate,dims=2))
        strat = estrat.stratlist[stratvector[i]]
        info_for_strat = isnothing(info_used(strat, method)) ? nothing : infodict[info_used(strat, method)]
        ballots[i] = vote(voter, strat, method, info_for_strat)
    end
    return cat(ballots...; dims=2)
end

"""
    castballots(electorate::Matrix, strat::VoterStrategy, method::VotingMethod, polldict=nothing)

The entire electorate casts ballots using strat.
"""
function castballots(electorate::Matrix, strat::VoterStrategy, method::VotingMethod, polldict=nothing)
    estrat = ElectorateStrategy(0, [strat], [size(electorate, 2)])
    castballots(electorate, estrat, method, polldict)
end

"""
    hontabulate(electorate::Matrix, method::VotingMethod)

Tabulate the election that happens when everyone votes honestly.
"""
function hontabulate(electorate::Matrix, method::VotingMethod, nwinners=1)
    ballots = castballots(electorate, hon, method, nwinners)
    tabulate(ballots, method, nwinners)
end