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
                   methods::Vector{<:VotingMethod},
                   estrats::Vector{ElectorateStrategy},
                   nvot::Int, ncand::Int, nwinners::Int=1,
                   correlatednoise::Float64=0.1, iidnoise::Float64=0.0)
    winnerutils = Array{Float64, 3}(undef, length(methods), numutilmetrics(nwinners), niter)
    bestutils = Matrix{Float64}(undef, numutilmetrics(nwinners), niter)
    avgutils = Matrix{Float64}(undef, numutilmetrics(nwinners), niter)
    Threads.@threads for i in 1:niter
        winnerutils[:, :, i], bestutils[:, i], avgutils[:, i] = one_vse_iter(
            vmodel, methods, estrats, nvot, ncand, nwinners, correlatednoise, iidnoise)
    end
    bestsums, avgsums = sum(bestutils, dims=2), sum(avgutils, dims=2)
    winnersums = sum(winnerutils, dims=3)
    results = Matrix{Float64}(undef, length(methods), numutilmetrics(nwinners))
    for i in 1:length(methods)
        for metric in 1:numutilmetrics(nwinners)
            results[i, metric] = (winnersums[i, metric]-avgsums[metric])/(bestsums[metric]-avgsums[metric])
        end
    end
    scenariodf = DataFrame(:Method=>methods, Symbol("Electorate Strategy")=>estrats)
    resultdf = DataFrame(results, nwinners==1 ? ["VSE"] : [string(metricnames(met), " VSE") for met in 1:numutilmetrics(nwinners)])
    return hcat(scenariodf, resultdf)
end

function calc_vses(niter::Int,
    vmodel::VoterModel,
    methods::Vector{<:VotingMethod},
    estrats::Vector,
    nvot::Int, ncand::Int, nwinners::Int=1,
    correlatednoise::Float64=0.1, iidnoise::Float64=0.0)
    calc_vses(niter, vmodel, methods,
            [esfromtemplate(template, hypot(correlatednoise, iidnoise)) for template in estrats],
            nvot, ncand, nwinners, correlatednoise, iidnoise)
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
                      nvot::Int, ncand::Int, nwinners=1,
                      correlatednoise::Float64=0.1, iidnoise::Float64=0.0)
    electorate = make_electorate(vmodel, nvot, ncand)
    infodict = administerpolls(electorate, (estrats, methods), correlatednoise, iidnoise)
    ballots = castballots.((electorate,), estrats, methods, (infodict,))
    winnersets = getwinners.(ballots, methods, nwinners)
    if nwinners == 1
        socialutils = sum(electorate, dims=2)
        bestutil = maximum(socialutils)
        avgutil = Statistics.mean(socialutils)
        winnerutils = [Statistics.mean(socialutils[w] for w in winners) for winners in winnersets]
        return winnerutils, [bestutil], [avgutil]
    else
        return mw_winner_quality(electorate, winnersets, nwinners)
    end
end

"""
    mw_winner_quality(electorate, winnersets, nwinners)

Determine the quality of sets of possible winners.

Returns (methodresults, highs, avgs), where highs and avgs are vectors of length 3
and methodresults is a k-by-3 matrix, where k is the number of winnersets.
methodresults[*,1], highs[1], and avgs[1] all related to how good each voter thinks the median winner is.
Indicies 2 and 3 are for the mean winner and the best winner, respectively.
Highs decribes results for particularly good winner set for each method,
and avgs describes an average of random winnersets.
"""
function mw_winner_quality(electorate, winnersets, nwinners)
    RANDOM_SAMPLES = 5
    ncands = size(electorate,1)
    #Determine the quality of the average winner set
    randomwinnersets = [Random.shuffle(1:ncands)[1:nwinners] for _ in 1:RANDOM_SAMPLES]
    avgmedian = Statistics.mean(
        Statistics.median(v[w] for w in ws) for v in eachslice(electorate, dims=2), ws in randomwinnersets)
    avgbest = Statistics.mean(maximum(v[w] for w in ws) for v in eachslice(electorate, dims=2), ws in randomwinnersets)
    avgmean = Statistics.mean(electorate)
    #Estimate the quality of good winner sets (not necessarily perfect ones)
    sntvwinners = winnersfromtab(hontabulate(electorate, sntv, nwinners), sntv, nwinners)
    socialutils = Statistics.mean(electorate, dims=2)
    bestutil = maximum(socialutils)
    highbest = Statistics.mean(maximum(v[w] for w in sntvwinners) for v in eachslice(electorate, dims=2))
    #Determine the quality of the actual sets of winners
    bests = map(winnersets) do winnerset
        Statistics.mean(maximum(v[w] for w in winnerset) for v in eachslice(electorate, dims=2))
    end
    means = [Statistics.mean(socialutils[w] for w in winners) for winners in winnersets]
    medians = map(winnersets) do winnerset
        Statistics.mean(Statistics.median(v[w] for w in winnerset) for v in eachslice(electorate, dims=2))
    end
    #Combine the results into arrays
    methodresults = [medians means bests]
    avgs = [avgmedian, avgmean, avgbest]
    highs = [bestutil, bestutil, highbest]
    return methodresults, highs, avgs
end