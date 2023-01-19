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