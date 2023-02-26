"""
    vote(voter, strat::BulletVote, method::Top2Method)

Vote in accordance with the blind strategy in the first election. Vote honestly in the runoff.
"""
function vote(voter, strat::BlindStrategy, method::Top2Method)
    r1ballot = vote(voter, strat, method.basemethod)
    runoffprefs = vote(voter, hon, irv)
    return [r1ballot;runoffprefs]
end

function vote(voter, strat::InformedStrategy, method::Top2Method, infodict::Dict)
    r1ballot = vote(voter, strat, method, infodict[neededinfo(strat, method)]);;
    runoffprefs = vote(voter, hon, irv)
    return [r1ballot;runoffprefs]
end


struct PluralityTop2VA <: InformedStrategy
    neededinfo
end

struct ApprovalTop2VA <: InformedStrategy
    neededinfo
end

function vote(voter, ::PluralityTop2VA, method::Top2Method, tie2probs)
    expectedvalue = sum(voter[i]*tie2probs[i] for i in eachindex(voter, tie2probs))
    ballot = zeros(Int, length(voter))
    ballot[argmax((voter[i]-expectedvalue)*tie2probs[i] for i in eachindex(voter, tie2probs))] = topballotmark(voter, method)
    return [ballot; vote(voter, hon, irv)]
end

function vote(voter, ::ApprovalTop2VA, method::Top2Method, tie2probs)
    expectedvalue = sum(voter[i]*tie2probs[i] for i in eachindex(voter, tie2probs))
    firstballot = [util >=expectedvalue ? topballotmark(voter, method) : 0 for util in voter]
    return [firstballot; vote(voter, hon, irv)]
end