struct BordaVA <: InformedStrategy
    neededinfo
end

struct IRVVA <: InformedStrategy
    neededinfo
    compthreshold::Float64 #Should be somewhere in [0, 1). 1 = no compromise, 0 = compromise on above-average candidates
end

"""
    vote(voter, ::BordaVA, method::VotingMethod, winprobs)

Priorize giving the most extreme rankings to the most viable candidates.
"""
function vote(voter, ::BordaVA, method::VotingMethod, winprobs)
    expectedvalue = sum(voter[i]*winprobs[i] for i in eachindex(voter, winprobs))
    worthinesses = [winprobs[i]*(voter[i]-expectedvalue) for i in eachindex(voter, winprobs)]
    return vote(worthinesses, hon, irv)
end

"""
    vote(voter, ::IRVVA, method::VotingMethod, winprobs)

Prioritize giving the top rankings to viable candidates, but don't use burial.
"""
function vote(voter, strat::IRVVA, method::VotingMethod, winprobs)
    expectedvalue = sum(voter[i]*winprobs[i] for i in eachindex(voter, winprobs))
    threshold = strat.compthreshold*maximum(voter) + (1-strat.compthreshold)*expectedvalue
    worthinesses = [voter[i] > threshold ? winprobs[i]*(voter[i]-threshold) :
                    voter[i] - threshold for i in eachindex(voter, winprobs)]
    return vote(worthinesses, hon, irv)
end

struct CondorcetVA <: BlindStrategy
end

vote(voter, strat::CondorcetVA, method::VotingMethod) = vote(voter, hon, method)
condorcetva = CondorcetVA()