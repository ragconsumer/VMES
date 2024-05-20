"Expected Vote Effect"

function calc_eve(niter::Int,
                   vmodel::VoterModel,
                   methods::Vector{<:VotingMethod},
                   estrats::Vector{ElectorateStrategy},
                   nvot::Int, ncand::Int, nwinners::Int=1;
                   correlatednoise::Float64=0.1, iidnoise::Float64=0.0,
                   iter_per_update=0)
    nmetrics = numutilmetrics(nwinners, vmodel)

    #Keep running totals for each thread
    totaleffecttotals = zeros(Float64, length(methods), nmetrics, Threads.nthreads()) 
    optimaleffecttotals = zeros(Float64, Threads.nthreads())
    Threads.@threads for tid in 1:Threads.nthreads()
        iterationsinthread = niter ÷ Threads.nthreads() + (tid <= niter % Threads.nthreads() ? 1 : 0)
        for i in 1:iterationsinthread
            if iter_per_update > 0 && i % iter_per_update == 0
                println("Iteration $i in thread $tid")
            end
            te, oe = one_eve_iter(
                vmodel, methods, estrats, nvot, ncand, nwinners, correlatednoise, iidnoise)
            totaleffecttotals[:, :, tid] += te
            optimaleffecttotals[tid] += oe
        end
    end
    optimaleffect = sum(optimaleffecttotals)
    totaleffects = sum(totaleffecttotals, dims=3)
    println(optimaleffect)
    println(totaleffects)
    results = Matrix{Float64}(undef, length(methods), nmetrics)
    for i in 1:length(methods)
        for metric in 1:nmetrics
            if optimaleffect != 0
                results[i, metric] = totaleffects[i, metric]/optimaleffect
            else
                results[i, metric] = -42
            end
        end
    end
    scenariodf = DataFrame(:Method=>methods, Symbol("Electorate Strategy")=>estrats)
    resultdf = DataFrame(results, nwinners==1 ? ["EVE"] : [string(metricnames(met), " EVE")
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

function calc_eve(niter::Int,
    vmodel::VoterModel,
    methods::Vector{<:VotingMethod},
    estrats::Vector,
    nvot::Int, ncand::Int, nwinners::Int=1;
    correlatednoise::Float64=0.1, iidnoise::Float64=0.0,
    iter_per_update=0)
    calc_eve(niter, vmodel, methods,
            [esfromtemplate(template, hypot(correlatednoise, iidnoise)) for template in estrats],
            nvot, ncand, nwinners,
            correlatednoise=correlatednoise, iidnoise=iidnoise; iter_per_update=iter_per_update)
end

"""
    one_eve_iter(vmodel::VoterModel,
                      methods::Vector{<: VotingMethod},
                      estrats::Vector{ElectorateStrategy},
                      nvot::Int, ncand::Int, nwinners=1,
                      correlatednoise::Float64=0.1, iidnoise::Float64=0.0)

Create a single electorate and determine the utilities needed for calculating EVE
"""
function one_eve_iter(vmodel::VoterModel,
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
    abstaining_ballots = vote.((electorate[:,1],), (abstain,), methods)
    utilsums = zeros(Float64, length(methods), numutilmetrics(nwinners, vmodel))
    socialutils = sum(electorate, dims=2)
    magic_best_winner = argmax(socialutils)
    magic_util_sum = 0.0
    for voterindex in 1:nvot
        voter = electorate[:, voterindex]
        for methodindex in eachindex(methods)
            ballot = ballots[methodindex][:, voterindex]
            ballots[methodindex][:, voterindex] = abstaining_ballots[methodindex]
            new_winners = getwinners(ballots[methodindex], methods[methodindex], nwinners)
            utilsums[methodindex, :] += (-calc_utils(voter, new_winners, nwinners)
                            + calc_utils(voter, winnersets[methodindex], nwinners))
            ballots[methodindex][:, voterindex] = ballot
        end
        othersocialutils = socialutils - voter
        magic_util_sum += voter[magic_best_winner] - voter[argmax(othersocialutils)]
    end
    #show.(tabulate.(ballots, methods, nwinners))
    #println(socialutils)
    #println(electorate)
    return utilsums, magic_util_sum
end