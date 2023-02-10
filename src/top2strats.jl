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

"""
    top2values(v, p)

Determine how good it is to vote for each candidate to get them into the top two.

v is the voter, p is winprobs
"""
function top3values(v, p)
    values = Vector{Float64}(undef, length(v))
    for i in eachindex(v, p)
        values[i] = sum((v[i]-v[j])*p[i]*p[j]*(1-p[i]-p[j]) for j in eachindex(v, p))
    end
    return values
end

function vote(voter, ::ApprovalVA, method::Top2Method, winprobs)
    values = top3values(voter, winprobs)
    [[value > 0 ? topballotmark(voter, method.basemethod) : 0 for value in values]; vote(voter, hon, irv)]
end

function vote(voter, ::PluralityVA, method::Top2Method, winprobs)
    values = top3values(voter, winprobs)
    ballot = zeros(Int, length(voter))
    ballot[argmax(values)] = topballotmark(voter, method.basemethod)
    return [ballot; vote(voter, hon, irv)]
end