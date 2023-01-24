struct BordaVA <: InformedStrategy
    neededinfo
    pollinguncertainty::Float64
end

struct IRVVA <: InformedStrategy
    neededinfo
    pollinguncertainty::Float64
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
function vote(voter, ::IRVVA, method::VotingMethod, winprobs)
    expectedvalue = sum(voter[i]*winprobs[i] for i in eachindex(voter, winprobs))
    worthinesses = [voter[i] > expectedvalue ? winprobs[i]*(voter[i]-expectedvalue) :
                    voter[i] - expectedvalue for i in eachindex(voter, winprobs)]
    return vote(worthinesses, hon, irv)
end