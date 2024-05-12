"""
    calc_primary_vse(niter::Int,
                   vmodel::VoterModel,
                   primary_methods::Vector{<:VotingMethod},
                   primary_estrats::Vector{ElectorateStrategy},
                   general_methods::Vector{<:VotingMethod},
                   general_estrats::Vector{ElectorateStrategy},
                   nvotprimary::Int, nvotgeneral::Int, ncand::Int, 
                   nadvance::Union{Int, AbstractVector{Int}}, random_voter_selection=false, nwinners::Int=1;
                   correlatednoise::Float64=0.1, iidnoise::Float64=0.0,
                   iter_per_update=0)

Determine Voter Satisfaction Efficiency in the context of two-round systems.

It is possible to have fewer voters participate in the primary than in the general election.
VSE is defined over the full candidate pool for the full electorate; if the best candidate gets
eliminated in the primary because the primary electorate was unrepresentative, that yields worse VSE.

primary_methods, primary_estrats, general_methods, and general_estrats must be vectors of the same length.
nadvance, how many candidates who advance to the general, can either be a vector of this length or an integer.
nvotprimary, the number of voters who participate int he primary election, must be <= nvotgeneral
If random_voter_selection is true, the voters who participate in the primary are decided at random;
otherwise, the first nvotprimary voters will do so.
primary_estrats must be for nvotprimary voters.
"""
function calc_primary_vse(niter::Int,
                   vmodel::VoterModel,
                   primary_methods::Vector{<:VotingMethod},
                   primary_estrats::Vector{ElectorateStrategy},
                   general_methods::Vector{<:VotingMethod},
                   general_estrats::Vector{ElectorateStrategy},
                   nvotprimary::Int, nvotgeneral::Int, ncand::Int, 
                   nadvance::Union{Int, AbstractVector{Int}}, random_voter_selection=false, nwinners::Int=1;
                   correlatednoise::Float64=0.1, iidnoise::Float64=0.0,
                   iter_per_update=0)
    nmetrics = numutilmetrics(nwinners, vmodel)

    #Keep running totals for each thread
    winnerutils = zeros(Float64, length(primary_methods), nmetrics, Threads.nthreads()) 
    bestutils = zeros(Float64, nmetrics, Threads.nthreads())
    avgutils = zeros(Float64, nmetrics, Threads.nthreads())
    Threads.@threads for tid in 1:Threads.nthreads()
        iterationsinthread = niter ÷ Threads.nthreads() + (tid <= niter % Threads.nthreads() ? 1 : 0)
        for i in 1:iterationsinthread
            if iter_per_update > 0 && i % iter_per_update == 0
                println("Iteration $i in thread $tid")
            end
            wu, bu, au = one_primary_vse_iter(
                vmodel, primary_methods, primary_estrats, general_methods, general_estrats,
                nvotprimary, nvotgeneral, ncand, nadvance, random_voter_selection,
                nwinners, correlatednoise, iidnoise)
            winnerutils[:, :, tid] += wu
            bestutils[:, tid] += bu
            avgutils[:, tid] += au
        end
    end
    bestsums, avgsums = sum(bestutils, dims=2), sum(avgutils, dims=2)
    winnersums = sum(winnerutils, dims=3)
    results = Matrix{Float64}(undef, length(primary_methods), nmetrics)
    for i in 1:length(primary_methods)
        for metric in 1:nmetrics
            results[i, metric] = (winnersums[i, metric]-avgsums[metric])/(bestsums[metric]-avgsums[metric])
        end
    end
    scenariodf = DataFrame(:PE_Method=>primary_methods, :GE_Method=>general_methods,
                           :PE_Estrat=>primary_estrats, :GE_Estrat=>general_estrats,
                           :GE_Candidates=>nadvance)
    resultdf = DataFrame(results, nwinners==1 ? ["VSE"] : [string(metricnames(met), " VSE")
                        for met in 1:nmetrics])
    results = hcat(scenariodf, resultdf)
    results[!, "Voter Model"] .= [vmodel]
    results[!, "PE_Voters"] .= nvotprimary
    results[!, "GE_Voters"] .= nvotgeneral
    results[!, "ncand"] .= ncand
    results[!, "Correlated Noise"] .= correlatednoise
    results[!, "IID Noise"] .= iidnoise
    results[!, "Random Participation"] .= random_voter_selection
    results[!, "Iterations"] .= niter
    return results
end

function calc_primary_vse(niter::Int,
                        vmodel::VoterModel,
                        primary_methods::Vector{<:VotingMethod},
                        primary_estrats::Vector,
                        general_methods::Vector{<:VotingMethod},
                        general_estrats::Vector,
                        nvotprimary::Int, nvotgeneral::Int, ncand::Int, 
                        nadvance, random_voter_selection=false, nwinners::Int=1;
                        correlatednoise::Float64=0.1, iidnoise::Float64=0.0,
                        iter_per_update=0)
    calc_primary_vse(niter, vmodel, primary_methods,
            [esfromtemplate(template, hypot(correlatednoise, iidnoise)) for template in primary_estrats],
            general_methods,
            [esfromtemplate(template, hypot(correlatednoise, iidnoise)) for template in general_estrats],
            nvotprimary, nvotgeneral, ncand, nadvance, random_voter_selection, nwinners,
            correlatednoise=correlatednoise, iidnoise=iidnoise; iter_per_update=iter_per_update)
end

"""
    one_primary_vse_iter(vmodel::VoterModel,
                      primary_methods::Vector{<:VotingMethod},
                      primary_estrats::Vector{ElectorateStrategy},
                      general_methods::Vector{<:VotingMethod},
                      general_estrats::Vector{ElectorateStrategy},
                      nvotprimary::Int, nvotgeneral::Int,
                      ncand::Int, nadvance::Union{Int, AbstractVector{Int}}, random_voter_selection=false, nwinners::Int=1,
                      correlatednoise::Float64=0.1, iidnoise::Float64=0.0)

Create a single electorate and determine the utilities needed for calculating VSE
"""
function one_primary_vse_iter(vmodel::VoterModel,
                      primary_methods::Vector{<:VotingMethod},
                      primary_estrats::Vector{ElectorateStrategy},
                      general_methods::Vector{<:VotingMethod},
                      general_estrats::Vector{ElectorateStrategy},
                      nvotprimary::Int, nvotgeneral::Int,
                      ncand::Int, nadvance::Union{Int, AbstractVector{Int}}, random_voter_selection=false, nwinners::Int=1,
                      correlatednoise::Float64=0.1, iidnoise::Float64=0.0)
    if(nwinners > 1 && isa(vmodel, SpatialModel))
        spatial_electorate = make_spatial_electorate(vmodel, nvot, ncand)
        full_electorate = spatial_electorate.utility_matrix
    else
        full_electorate = make_electorate(vmodel, nvotgeneral, ncand)
    end
    primary_infodict = administerpolls(full_electorate, (primary_estrats, primary_methods),
                                        correlatednoise, iidnoise)
    if random_voter_selection
        primary_voter_ids = Random.randperm(nvotgeneral)[1:nvotprimary]
    else
        primary_voter_ids = 1:nvotprimary
    end
    primary_electorate = full_electorate[:, primary_voter_ids]
    ballots = castballots.((primary_electorate,), primary_estrats, primary_methods, (primary_infodict,))
    advanced_candidate_sets = getwinners.(ballots, primary_methods, nadvance)
    winnersets = []
    for (method, estrat, candidate_field) in zip(general_methods, general_estrats, advanced_candidate_sets)
        general_electorate = full_electorate[candidate_field, :]
        infodict = administerpolls(general_electorate, ([estrat], [method]),
                                        correlatednoise, iidnoise)
        ballots = castballots(general_electorate, estrat, method, infodict)
        append!(winnersets, candidate_field[getwinners(ballots, method, nwinners)])
    end

    if nwinners == 1
        socialutils = sum(full_electorate, dims=2)
        bestutil = maximum(socialutils)
        avgutil = Statistics.mean(socialutils)
        winnerutils = [Statistics.mean(socialutils[w] for w in winners) for winners in winnersets]
        return winnerutils, [bestutil], [avgutil]
    else
        e = isa(vmodel, SpatialModel) ? spatial_electorate : electorate
        return simple_mw_winner_quality(e, winnersets)
    end
end