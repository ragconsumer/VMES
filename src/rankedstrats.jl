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

struct IRVPositional <: InformedStrategy
    neededinfo
    pushover::Bool
    hardcore_po::Bool
    eager_compromise::Bool
end

function vote(voter, strat::IRVPositional, _::VotingMethod, (finalists, top3))
    fave = top3[argmax(voter[top3])] #the voter's favorite of the top 3
    ballot = vote(voter, hon, irv)
    if fave == finalists[2]
        if (fave == top3[2] || strat.eager_compromise) && voter[finalists[1]] < voter[top3[3]] #compromise
            ballot[fave], ballot[top3[3]] = ballot[top3[3]], ballot[fave]
        elseif fave == top3[1] && strat.pushover && (voter[finalists[1]] < voter[top3[3]] || strat.hardcore_po)
            #use the third-place finisher as a pushover
            return vote([i==top3[3] ? voter[fave] + 0.001 : voter[i] for i in eachindex(voter)], hon, irv)
        end
    end
    return ballot
end

struct MinimaxPositional <: InformedStrategy
    neededinfo
end

function vote(voter, _::MinimaxPositional, _::VotingMethod, (poll, frontrunners))
    rfr = sort(frontrunners, by=x-> -voter[x]) #frontrunners ranked in preference order
    ballot = vote(voter, hon, minimax)
    if (poll[rfr[2],rfr[1]] > poll[rfr[1],rfr[2]] &&
        poll[rfr[2],rfr[3]] > poll[rfr[3],rfr[2]] &&
        poll[rfr[1],rfr[3]] > poll[rfr[3],rfr[1]])
        ballot[[rfr[2], rfr[3]]] = ballot[[rfr[3], rfr[2]]]
    end
    return ballot
end