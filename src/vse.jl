"""
    calc_vses(niter::Int,
                   vmodel::VoterModel,
                   methods::Vector{<:VotingMethod},
                   estrats::Vector{ElectorateStrategy},
                   nvot::Int, ncand::Int, nwinners::Int=1,
                   correlatednoise::Float64=0.1, iidnoise::Float64=0.0)

Determine the VSEs of the given voting methods and strategies.

methods and estrats must be vectors of the same length.
"""
function calc_vses(niter::Int,
                   vmodel::VoterModel,
                   methods::Vector{<:VotingMethod},
                   estrats::Vector{ElectorateStrategy},
                   nvot::Int, ncand::Int, nwinners::Int=1;
                   correlatednoise::Float64=0.1, iidnoise::Float64=0.0,
                   iter_per_update=0)
    nmetrics = numutilmetrics(nwinners, vmodel)

    #Keep running totals for each thread
    winnerutils = zeros(Float64, length(methods), nmetrics, Threads.nthreads()) 
    bestutils = zeros(Float64, nmetrics, Threads.nthreads())
    avgutils = zeros(Float64, nmetrics, Threads.nthreads())
    Threads.@threads for tid in 1:Threads.nthreads()
        iterationsinthread = niter ÷ Threads.nthreads() + (tid <= niter % Threads.nthreads() ? 1 : 0)
        for i in 1:iterationsinthread
            if iter_per_update > 0 && i % iter_per_update == 0
                println("Iteration $i in thread $tid")
            end
            wu, bu, au = one_vse_iter(
                vmodel, methods, estrats, nvot, ncand, nwinners, correlatednoise, iidnoise)
            winnerutils[:, :, tid] += wu
            bestutils[:, tid] += bu
            avgutils[:, tid] += au
        end
    end
    bestsums, avgsums = sum(bestutils, dims=2), sum(avgutils, dims=2)
    winnersums = sum(winnerutils, dims=3)
    results = Matrix{Float64}(undef, length(methods), nmetrics)
    for i in 1:length(methods)
        for metric in 1:nmetrics
            results[i, metric] = (winnersums[i, metric]-avgsums[metric])/(bestsums[metric]-avgsums[metric])
        end
    end
    scenariodf = DataFrame(:Method=>methods, Symbol("Electorate Strategy")=>estrats)
    resultdf = DataFrame(results, nwinners==1 ? ["VSE"] : [string(metricnames(met), " VSE")
                        for met in 1:nmetrics])
    results = hcat(scenariodf, resultdf)
    results[!, "Voter Model"] .= [vmodel]
    results[!, "nvot"] .= nvot
    results[!, "ncand"] .= ncand
    results[!, "Correlated Noise"] .= correlatednoise
    results[!, "IID Noise"] .= iidnoise
    results[!, "Iterations"] .= niter
    return results
end

function calc_vses(niter::Int,
    vmodel::VoterModel,
    methods::Vector{<:VotingMethod},
    estrats::Vector,
    nvot::Int, ncand::Int, nwinners::Int=1;
    correlatednoise::Float64=0.1, iidnoise::Float64=0.0,
    iter_per_update=0)
    calc_vses(niter, vmodel, methods,
            [esfromtemplate(template, hypot(correlatednoise, iidnoise)) for template in estrats],
            nvot, ncand, nwinners, correlatednoise, iidnoise; iter_per_update=iter_per_update)
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
    if(nwinners > 1 && isa(vmodel, SpatialModel))
        spatial_electorate = make_spatial_electorate(vmodel, nvot, ncand)
        electorate = spatial_electorate.utility_matrix
    else
        electorate = make_electorate(vmodel, nvot, ncand)
    end
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
        e = isa(vmodel, SpatialModel) ? spatial_electorate : electorate
        return simple_mw_winner_quality(e, winnersets)
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

"""
    simple_mw_winner_quality(electorate, winnersets)

Determine the quality of sets of possible winners.

Like mw_winner_quality but uses the single-winner VSE scale
(magic best single winner to random winner) as the scale for everything
"""
function simple_mw_winner_quality(electorate, winnersets)
    socialutils = Statistics.mean(electorate, dims=2)
    bestutil = maximum(socialutils)
    meanutil = Statistics.mean(electorate)
    #Determine the quality of the sets of winners
    bests = map(winnersets) do winnerset
        Statistics.mean(maximum(v[w] for w in winnerset) for v in eachslice(electorate, dims=2))
    end
    means = [Statistics.mean(socialutils[w] for w in winners) for winners in winnersets]
    medians = map(winnersets) do winnerset
        Statistics.mean(Statistics.median(v[w] for w in winnerset) for v in eachslice(electorate, dims=2))
    end
    methodresults = [medians means bests]
    avgs = [meanutil, meanutil, meanutil]
    highs = [bestutil, bestutil, bestutil]
    return methodresults, highs, avgs
end

function simple_mw_winner_quality(se::SpatialElectorate, winnersets)
    electorate = se.utility_matrix
    socialutils = Statistics.mean(electorate, dims=2)
    bestutil = maximum(socialutils)
    meanutil = Statistics.mean(electorate)
    #Determine the quality of the sets of winners
    bests = map(winnersets) do winnerset
        Statistics.mean(maximum(v[w] for w in winnerset) for v in eachslice(electorate, dims=2))
    end
    means = [Statistics.mean(socialutils[w] for w in winners) for winners in winnersets]
    medians = map(winnersets) do winnerset
        Statistics.mean(Statistics.median(v[w] for w in winnerset) for v in eachslice(electorate, dims=2))
    end
    ndims = size(se.candidate_coordinates, 1)
    median_positions = [Statistics.median(se.candidate_coordinates[dim, w] for w in winners)
                        for dim in 1:ndims, winners in winnersets]
    median_winner_utils = make_utility_matrix(se.voter_coordinates, se.caring_matrix, median_positions)
    social_pos_utils = Statistics.mean(median_winner_utils, dims=2)
    methodresults = [medians means bests social_pos_utils]
    avgs = repeat([meanutil], 4)
    highs = repeat([bestutil], 4)
    return methodresults, highs, avgs
end