"""
    vote(voter, strat::BulletVote, method::Top2Method)

Vote in accordance with the blind strategy in the first election. Vote honestly in the runoff.
"""
function vote(voter, strat::BlindStrategy, method::Top2Method)
    r1ballot = vote(voter, strat, method.basemethod)
    runoffprefs = vote(voter, hon, irv)
    return [r1ballot;runoffprefs]
end