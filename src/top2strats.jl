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

struct PluralityTop2Positional <: InformedStrategy
    neededinfo
    pushover::Bool
    hardcore_po::Bool
    eager_compromise::Bool
end

"""
    vote(voter, ::PluralityTop2Positional, method::VotingMethod, finalists::Vector{Int}, top3::Vector{Int})

Always vote for one of the top 3. Includes compromise within that and (optionally) a pushover strategy.
"""
function vote(voter, strat::PluralityTop2Positional, method::VotingMethod, (finalists, top3))
    fave = top3[argmax(voter[top3])] #the voter's favorite of the top 3
    ballot = zeros(Int, length(voter))
    if fave == top3[3] || fave == finalists[1]
        ballot[fave] = topballotmark(voter, method) #vote for the best of the top 3
    elseif fave == top3[1] 
        if strat.pushover && (voter[finalists[1]] < voter[top3[3]] || strat.hardcore_po)
            #get the third place finisher into the finals in hopes that fave will beat them
            ballot[top3[3]] = topballotmark(voter, method) 
        else
            ballot[fave] = topballotmark(voter, method)
        end
    else
        if (fave == top3[2] || strat.eager_compromise) && voter[top3[3]] > voter[finalists[1]]
            ballot[top3[3]] = topballotmark(voter, method) #compromise if fave loses the runoff
        else
            ballot[fave] = topballotmark(voter, method)
        end
    end
    return [ballot; vote(voter, hon, irv)]
end

struct ApprovalTop2Positional <: InformedStrategy
    neededinfo
    favorite_betrayal::Bool
    pushover::Bool
end

function vote(voter, strat::ApprovalTop2Positional, method::VotingMethod, (finalists, top3))
    fave = top3[argmax(voter[top3])] #the voter's favorite of the top 3
    if fave == finalists[2] && voter[top3[3]] > voter[finalists[1]]
        #set the approval threshold to the utility of the voter's second choice among the top 3
        threshold = voter[top3[3]] 
    else
        threshold = maximum(voter[top3])
    end
    ballot = [voter[i] < threshold ? 0 : topballotmark(voter, method) for i in eachindex(voter)]
    #decide whether to vote for the third place candidate as a pushover
    if fave == finalists[2] && strat.pushover && fave == top3[1]
        ballot[top3[3]] = topballotmark(voter, method)
    elseif strat.favorite_betrayal && fave == finalists[2] && fave == top3[2] && voter[top3[1]] < voter[top3[3]]
        ballot[fave] = 0
        #ballot[top3[3]] = topballotmark(voter, method)
    end
    return [ballot; vote(voter, hon, irv)]
end