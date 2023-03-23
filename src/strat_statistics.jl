"""
    collect_strat_stats(niter::Int,
                            vmodel::VoterModel,
                            methods::Vector{<:VotingMethod},
                            estrats::Vector{<:Union{ElectorateStrategy, ESTemplate}},
                            nvot::Int, ncand::Int, nwinners::Int=1,
                            correlatednoise::Float64=0.1, iidnoise::Float64=0.0)

Collect statistics on voter behavior under the give strategies.

methods and estrats must be vectors of the same lengths. estrats may include both
ElectorateStrategies and ESTemplates.
"""
function collect_strat_stats(niter::Int,
                            vmodel::VoterModel,
                            methods::Vector{<:VotingMethod},
                            estrats::Vector{<:Union{ElectorateStrategy, ESTemplate}},
                            nvot::Int, ncand::Int, nwinners::Int=1,
                            correlatednoise::Float64=0.1, iidnoise::Float64=0.0)
    collect_strat_stats(niter, vmodel, methods,
                        [esfromtemplate(template, hypot(correlatednoise, iidnoise)) for template in estrats],
                        nvot, ncand, nwinners, correlatednoise, iidnoise)
end

function collect_strat_stats(niter::Int,
                            vmodel::VoterModel,
                            methods::Vector{<:VotingMethod},
                            estrats::Vector{ElectorateStrategy},
                            nvot::Int, ncand::Int, nwinners::Int=1,
                            correlatednoise::Float64=0.1, iidnoise::Float64=0.0)
    ITER_PER_SUM = 1000
    nmethod = length(methods)
    positionalscorecounts = Array{Dict{ballotmarktype(methods[1]), Int}, 3}(undef, ncand, nmethod, min(niter, ITER_PER_SUM))
    top2spreadcounts = Array{Dict{ballotmarktype(methods[1]), Int}, 2}(undef, nmethod, min(niter, ITER_PER_SUM))
    top3spreadcounts = Array{Dict{ballotmarktype(methods[1]), Int}, 2}(undef, nmethod, min(niter, ITER_PER_SUM))
    bulletcounts = Array{Int, 2}(undef, nmethod, min(niter, ITER_PER_SUM))
    positionalscoretotals = Array{Dict{ballotmarktype(methods[1]), Int}, 2}(undef, ncand, nmethod)
    top2spreadtotals = Array{Dict{ballotmarktype(methods[1]), Int}, 1}(undef, nmethod)
    top3spreadtotals = Array{Dict{ballotmarktype(methods[1]), Int}, 1}(undef, nmethod)
    for i in 1:nmethod
        top2spreadtotals[i] = Dict{ballotmarktype(methods[1]), Int}()
        top3spreadtotals[i] = Dict{ballotmarktype(methods[1]), Int}()
        for j in 1:ncand
            positionalscoretotals[j, i] = Dict{ballotmarktype(methods[1]), Int}()
        end
    end
    bullettotals = zeros(Int, nmethod)
    iterleft = niter
    for _ in 1:ceil(Int, niter/ITER_PER_SUM)
        iter_this_round = min(iterleft, ITER_PER_SUM)
        Threads.@threads for i in 1:iter_this_round
            iter_results = strat_stats_one_iter(vmodel, methods, estrats, nvot, ncand, nwinners,
                                                correlatednoise, iidnoise)
            positionalscorecounts[:, :, i], bulletcounts[:, i], top2spreadcounts[:, i], top3spreadcounts[:, i] = iter_results
        end
        for j in 1:nmethod
            mergewith!(+, top2spreadtotals[j], top2spreadcounts[j, 1:iter_this_round]...)
            mergewith!(+, top3spreadtotals[j], top3spreadcounts[j, 1:iter_this_round]...)
            for pos in 1:ncand
                mergewith!(+, positionalscoretotals[pos, j], positionalscorecounts[pos, j, 1:iter_this_round]...)
            end
            bullettotals[j] += sum(bulletcounts[j, 1:iter_this_round])
        end
        iterleft -= ITER_PER_SUM
    end
    process_strat_stats(positionalscoretotals, top2spreadtotals, top3spreadtotals, bullettotals,
                        niter, vmodel, methods, estrats, nvot, ncand, nwinners,
                        correlatednoise, iidnoise)
end

"""
    process_strat_stats(positionalscoretotals, top2spreadtotals, top3spreadtotals, bullettotals,
                            niter, vmodel, methods, estrats, nvot, ncand, nwinners,
                            correlatednoise, iidnoise)

Create DataFrames with the information from collect_strat_stats
"""
function process_strat_stats(positionalscoretotals, top2spreadtotals, top3spreadtotals, bullettotals,
                            niter, vmodel, methods, estrats, nvot, ncand, nwinners,
                            correlatednoise, iidnoise)
    nballots = niter*nvot
    nstrats = length(estrats)
    nscores = niter*nvot*ncand
    nstrategistvector = [s.flexible_strategists for s in estrats]
    totalscores = [sum(sum(score*count for (score, count) in pairs(positionalscoretotals[pos,i]))
                    for pos in 1:ncand) for i in 1:nstrats]
    meanspread2 = [sum(spread*count/(n*niter) for (spread, count) in d) for (d, n) in zip(top2spreadtotals, nstrategistvector)]
    meanspread3 = [sum(spread*count/(n*niter) for (spread, count) in d) for (d, n) in zip(top3spreadtotals, nstrategistvector)]
    basicdf = DataFrame("Strategy"=>estrats, "Bullet Votes"=> bullettotals./(nstrategistvector .* niter),
                        "Mean Score"=>totalscores./(nstrategistvector .* niter*ncand),
                        "Top 2 Spread"=>meanspread2,
                        "Top 3 Spread"=>meanspread3,
                        "Method"=>methods)
    spread_df = DataFrame()
    return basicdf, spread_df
end

"""
    strat_stats_one_iter(vmodel::VoterModel,
                                methods::Vector{<:VotingMethod},
                                estrats::Vector{<:VoterStrategy},
                                nvot::Int, ncand::Int, nwinners::Int=1,
                                correlatednoise::Float64=0.1, iidnoise::Float64=0.0)

One iteration of collect_strat_stats
"""
function strat_stats_one_iter(vmodel::VoterModel,
                                methods::Vector{<:VotingMethod},
                                estrats::Vector{<:ElectorateStrategy},
                                nvot::Int, ncand::Int, nwinners::Int=1,
                                correlatednoise::Float64=0.1, iidnoise::Float64=0.0)
    electorate = make_electorate(vmodel, nvot, ncand)
    infodict = administerpolls(electorate, (estrats, methods), correlatednoise, iidnoise)
    positionalscorecounts = [Dict{ballotmarktype(method), Int}() for _ in 1:ncand, method in methods]
    top2spreadcounts = [Dict{ballotmarktype(method), Int}() for method in methods]
    top3spreadcounts = [Dict{ballotmarktype(method), Int}() for method in methods]
    bulletcounts = zeros(Int, length(methods))
    for i in eachindex(methods, estrats)
        ballots = castballots(electorate, estrats[i], methods[i], infodict)
        placements = placementsfromtab(tabulate(ballots, methods[i], nwinners), methods[i], nwinners)
        for ballot in eachslice(ballots[1:ncand, 1:estrats[i].flexible_strategists], dims=2)
            if sum(ballot) == maximum(ballot)
                bulletcounts[i] += 1
            end
            spread = maximum(ballot[placements[1:2]]) - minimum(ballot[placements[1:2]])
            if spread in keys(top2spreadcounts[i])
                top2spreadcounts[i][spread] += 1
            else
                top2spreadcounts[i][spread] = 1
            end
            if ncand >= 3
                spread = maximum(ballot[placements[1:3]]) - minimum(ballot[placements[1:3]])
                if spread in keys(top3spreadcounts[i])
                    top3spreadcounts[i][spread] += 1
                else
                    top3spreadcounts[i][spread] = 1
                end
            end
            for (position, cand) in enumerate(placements)
                score = ballot[cand]
                if score in keys(positionalscorecounts[position, i])
                    positionalscorecounts[position, i][score] += 1
                else
                    positionalscorecounts[position, i][score] = 1
                end
            end
        end
    end
    return positionalscorecounts, bulletcounts, top2spreadcounts, top3spreadcounts
end
