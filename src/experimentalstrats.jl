

struct BestInTop3 <: InformedStrategy
    neededinfo
end

"""
    vote(voter, ::BestInTop3, method::Top2Method, polls)

Vote for the voter's favorite of the top three polling candidates.

This got an ESIF of 0.7838
"""
function vote(voter, ::BestInTop3, method::Top2Method, polls::Vector)
    sortedtuples = sort(collect(enumerate(polls)), lt=(((i1,u1),(i2,u2)) -> u1<u2 ? true : u1==u2 && i1>i2 ? true : false))
    top3 = [i for (i, _) in sortedtuples[end-2:end]]
    top3utils = [voter[top3[i]] for i in 1:3]
    ballot = zeros(Int, length(voter))
    ballot[top3[argmax(top3utils)]] = topballotmark(voter, method)
    return [ballot; vote(voter, hon, irv)]
end

vote(voter, s::BestInTop3, method::Top2Method, polls::Matrix) = vote(voter, s, method, dropdims(polls,dims=2))

"""
    top2values(v, p)

Determine how good it is to vote for each candidate to get them into the top two.

v is the voter, p is winprobs
"""
function top3values(v, p)
    values = Vector{Float64}(undef, length(v))
    for i in eachindex(v, p)
        values[i] = sum([(v[i]-v[j])*p[i]*p[j]*(1-p[i]-p[j]) for j in eachindex(v, p) if (1-p[i]-p[j]) > 0], init=0.)
    end
    return values
end

function top3valueslse(v, p)
    values = Vector{Float64}(undef, length(v))
    for i in eachindex(v, p)
        values[i] = sum([(v[i]-v[j])*exp(log(p[i])+log(p[j])+log(1-p[i]-p[j])) for j in eachindex(v, p) if 1-p[i]-p[j]>0], init=0.)
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
