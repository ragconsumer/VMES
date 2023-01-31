"""
    calc_vses(niter::Int,
                   vmodel::VoterModel,
                   methods::Vector{<: VotingMethod},
                   estrats::Vector{ElectorateStrategy},
                   nvot::Int, ncand::Int, pollingerror=0.1, nwinners=1)

Determine the VSEs of the given voting methods and strategies.

methods and estrats must be vectors of the same length.
"""
function calc_vses(niter::Int,
                   vmodel::VoterModel,
                   methods::Vector{<: VotingMethod},
                   estrats::Vector{ElectorateStrategy},
                   nvot::Int, ncand::Int, pollingerror=0.1, nwinners=1)
    winnerutils = Matrix{Float64}(undef, length(methods), niter)
    bestutils = Vector{Float64}(undef, niter)
    avgutils = Vector{Float64}(undef, niter)
    Threads.@threads for i in 1:niter
        winnerutils[:, i], bestutils[i], avgutils[i] = one_vse_iter(
            vmodel, methods, estrats, nvot, ncand, pollingerror, nwinners)
    end
    bestsum, avgsum = sum(bestutils), sum(avgutils)
    winnersums = reshape(sum(winnerutils, dims=2), length(methods))
    vses = [(w-avgsum)/(bestsum-avgsum) for w in winnersums]
    #oldvses = [Statistics.mean((winnerutils[m, i]-avgutils[i])/(bestutils[i]-avgutils[i])
                            #for i in 1:niter) for m in 1:length(methods)]
    return vses
end

"""
    one_vse_iter(vmodel::VoterModel,
                      methods::Vector{<: VotingMethod},
                      estrats::Vector{ElectorateStrategy},
                      nvot::Int, ncand::Int, pollingerror=0.1, nwinners=1)

Create a single electorate and determine the utilities needed for calculating VSE
"""
function one_vse_iter(vmodel::VoterModel,
                      methods::Vector{<: VotingMethod},
                      estrats::Vector{ElectorateStrategy},
                      nvot::Int, ncand::Int, pollingerror=0.1, nwinners=1)
    electorate = make_electorate(vmodel, nvot, ncand)
    infodict = administerpolls(electorate, (estrats, methods), pollingerror, 0)
    ballots = castballots.((electorate,), estrats, methods, (infodict,))
    winnersets = getwinners.(ballots, methods, nwinners)
    socialutils = sum(electorate, dims=2)
    bestutil = maximum(socialutils)
    avgutil = Statistics.mean(socialutils)
    winnerutils = [Statistics.mean(socialutils[w] for w in winners) for winners in winnersets]
    if nwinners == 1
        return winnerutils, bestutil, avgutil
    else
        return mw_winner_quality(electorate, winnersets)
    end
end

function mw_winner_quality(electorate, winnersets)
end