abstract type WinnerQualityMetric end

function low_end_winner_quality(electorate::AbstractMatrix, metric::WinnerQualityMetric, nwinners::Int)
    winner_set_quality(electorate, collect(1:nwinners), metric)
end
function high_end_winner_quality(electorate::AbstractMatrix, metric::WinnerQualityMetric, nwinners::Int)
    good_winners = metric.high_end_winner_function(electorate, nwinners)
    return winner_set_quality(electorate, good_winners, metric)
end
function winner_set_quality(electorate::AbstractMatrix, winners::Set, metric::WinnerQualityMetric)
    winner_set_quality(electorate, collect(winners), metric)
end

struct MeanUtility <: WinnerQualityMetric
    name::String
    high_end_winner_function::Function
end
low_end_winner_quality(electorate::AbstractMatrix, metric::MeanUtility, ::Int) = Statistics.mean(electorate)
mean_utility_high_end(electorate, nwinners) = getwinners(electorate, approval, nwinners)
mean_utility = MeanUtility("Mean", mean_utility_high_end)
vse = MeanUtility("VSE", mean_utility_high_end)

struct MedianUtility <: WinnerQualityMetric
    name::String
    high_end_winner_function::Function
end
median_utility = MedianUtility("Median", mean_utility_high_end)

struct FavoriteUtility <: WinnerQualityMetric
    name::String
    high_end_winner_function::Function
end
favorite_utility_high_end(electorate, nwinners) = winnersfromtab(hontabulate(electorate, sntv, nwinners), sntv, nwinners)
favorite_utility = FavoriteUtility("Favorite", favorite_utility_high_end)

struct HarmonicUtility <: WinnerQualityMetric
    name::String
    high_end_winner_function::Function
end
function harmonic_greedy_winners(electorate, nwinners::Int, method::VotingMethod)
    rescaled_electorate = Matrix{Float64}(undef, size(electorate))
    #rescale each voter's utilities to [0,5]
    for i in axes(electorate, 2)
        rescaled_electorate[:, i] = electorate[:, i] .- minimum(electorate[:, i])
        max_util = maximum(rescaled_electorate[:, i])
        if max_util > 0
            rescaled_electorate[:, i] ./= max_util/5
        end
    end
    return getwinners(rescaled_electorate, method, nwinners)
end
harmonic_utility_high_end(electorate, nwinners) = harmonic_greedy_winners(electorate, nwinners, rrv)
harmonic_utility = HarmonicUtility("Harmonic", harmonic_utility_high_end)

struct HarmonicSLUtility <: WinnerQualityMetric
    name::String
    high_end_winner_function::Function
end
harmonic_sl_utility_high_end(electorate, nwinners) = harmonic_greedy_winners(electorate, nwinners, rrv_sl)
harmonic_sl_utility = HarmonicSLUtility("HarmonicSL", harmonic_sl_utility_high_end)

struct MonroeEfficiency <: WinnerQualityMetric
    name::String
    high_end_winner_function::Function
end
monroe1000 = ScorePRTemplate(
    1000, exacthare, monroe_total, norunoffs, nothing,
    asreweight!, allweight, justscore
)
monroe_high_end(electorate, nwinners) = winnersfromtab(hontabulate(electorate, monroe1000, nwinners), monroe1000, nwinners)
monroe_efficiency = MonroeEfficiency("Monroe Efficiency", monroe_high_end)

struct MedianPositionUtility <: WinnerQualityMetric
    name::String
    high_end_winner_function::Function
end
median_position_high_end(electorate, nwinners) = winnersfromtab(hontabulate(electorate, stv, nwinners), stv, nwinners)
median_position_utility = MedianPositionUtility("Median Position", median_position_high_end)

struct MeanQuality <: WinnerQualityMetric
    name::String
end
low_end_winner_quality(electorate::AbstractMatrix, metric::MeanQuality, nwinners::Int) = 0
high_end_winner_quality(electorate::AbstractMatrix, metric::MeanQuality, nwinners::Int) = 1
mean_quality = MeanQuality("Quality")

default_metrics = [harmonic_utility, harmonic_sl_utility, monroe_efficiency, 
                    mean_utility, favorite_utility, median_utility, median_position_utility, mean_quality]

using JuMP, HiGHS






function winner_set_quality(electorate::AbstractMatrix, winners::Vector{Int}, metric::MeanUtility)
    Statistics.mean(electorate[winners, :])
end
function winner_set_quality(electorate::AbstractMatrix, winners::Vector{Int}, metric::MedianUtility)
    Statistics.mean(Statistics.median(voter[winners]) for voter in eachcol(electorate))
end
function winner_set_quality(electorate::AbstractMatrix, winners::Vector{Int}, metric::FavoriteUtility)
    Statistics.mean(maximum(voter[winners]) for voter in eachcol(electorate))
end
function winner_set_quality(electorate::AbstractMatrix, winners::Vector{Int}, metric::HarmonicUtility)
    Statistics.mean(sum(util/k for (k, util) in enumerate(sort(voter[winners], rev=true)))
                        for voter in eachcol(electorate))
end
function winner_set_quality(electorate::AbstractMatrix, winners::Vector{Int}, metric::HarmonicSLUtility)
    Statistics.mean(sum(util/(2k-1) for (k, util) in enumerate(sort(voter[winners], rev=true)))
                        for voter in eachcol(electorate))
end
function monroe_assignment(opinions_of_winners::AbstractMatrix)
    nwinner, nvote = size(opinions_of_winners)
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    set_optimizer_attribute(model, "solver", "simplex")
    set_optimizer_attribute(model, "threads", 1)
    set_optimizer_attribute(model, "parallel", "off")
    set_optimizer_attribute(model, "simplex_strategy", 4)  # network simplex mode
    
    @variable(model, 0 <= x[1:nwinner, 1:nvote] <= 1)
    @constraint(model, [i in 1:nvote], sum(x[j,i] for j in 1:nwinner) == 1.0)
    @constraint(model, [j in 1:nwinner], sum(x[j,i] for i in 1:nvote) == nvote/nwinner)
    @objective(model, Max, sum(opinions_of_winners[j,i]*x[j,i] for j in 1:nwinner, i in 1:nvote))
    
    optimize!(model)
    return value.(x)
end

function winner_set_quality(electorate::AbstractMatrix, winners::Vector{Int}, metric::MonroeEfficiency)
    assignment = monroe_assignment(electorate[winners,:])
    Statistics.mean(sum(electorate[winners[j],i]*assignment[j,i] for j in eachindex(winners)) for i in axes(electorate,2))
end

function winner_set_quality(electorate::AugmentedElectorate, winners::Vector{Int}, metric::MedianPositionUtility)
    winner_coordinates = electorate.candidate_coordinates[:, winners]
    median_positions = [Statistics.median(winner_coordinates[dim, :]) for dim in axes(winner_coordinates, 1)]
    return Statistics.mean(-sqrt(sum(electorate.caring_matrix[dim, i]*(voter_pos[dim] - median_positions[dim])^2
                        for dim in axes(winner_coordinates, 1)))
                        for (i,voter_pos) in enumerate(eachcol(electorate.voter_coordinates)))
end
function winner_set_quality(electorate::AugmentedElectorate, winners::Vector{Int}, metric::MeanQuality)
    return Statistics.mean(electorate.candidate_qualities[winners])
end

function calc_winner_quality(niter::Int,
                   vmodel::VoterModel,
                   methods::Vector{<:VotingMethod},
                   estrats::Vector{ElectorateStrategy},
                   nvot::Int, ncand::Int, nwinners::Int;
                   metrics = default_metrics,
                   correlatednoise::Float64=0.1, iidnoise::Float64=0.0,
                   iter_per_update=0)
    #Keep running totals for each thread
    totals = zeros(Float64, length(methods), length(metrics), Threads.nthreads())
    #first index is metric, second index is 1 for high end, 2 for low end
    normalization_totals = zeros(Float64, length(metrics), 2, Threads.nthreads())
    Threads.@threads for tid in 1:Threads.nthreads()
        iterationsinthread = niter ÷ Threads.nthreads() + (tid <= niter % Threads.nthreads() ? 1 : 0)
        for i in 1:iterationsinthread
            if iter_per_update > 0 && i % iter_per_update == 0 && tid == 1
                println("Iteration $i in thread $tid")
            end
            method_results, normalization_results = one_winner_quality_iter(
                vmodel, methods, estrats, nvot, ncand, nwinners, metrics, correlatednoise, iidnoise)
            totals[:, :, tid] += method_results
            normalization_totals[:, :, tid] += normalization_results
        end
    end
    totals = sum(totals, dims=3)
    normalization_totals = sum(normalization_totals, dims=3)
    df = DataFrame(:Method=>methods, Symbol("Electorate Strategy")=>estrats)
    for (i, metric) in enumerate(metrics)
        df[!, metric.name] = (totals[:, i] .- normalization_totals[i, 2]) ./ (normalization_totals[i, 1] - normalization_totals[i, 2])
    end
    df[!, "Voter Model"] .= [vmodel]
    df[!, "nvot"] .= nvot
    df[!, "ncand"] .= ncand
    df[!, "Correlated Noise"] .= correlatednoise
    df[!, "IID Noise"] .= iidnoise
    df[!, "Iterations"] .= niter
    return df
end

function calc_winner_quality(niter::Int,
    vmodel::VoterModel,
    methods::Vector{<:VotingMethod},
    estrats::Vector,
    nvot::Int, ncand::Int, nwinners::Int;
    metrics = default_metrics,
    correlatednoise::Float64=0.1, iidnoise::Float64=0.0,
    iter_per_update=0)
    calc_winner_quality(niter, vmodel, methods,
            [esfromtemplate(template, hypot(correlatednoise, iidnoise)) for template in estrats],
            nvot, ncand, nwinners, metrics=metrics,
            correlatednoise=correlatednoise, iidnoise=iidnoise; iter_per_update=iter_per_update)
end

function one_winner_quality_iter(vmodel::VoterModel,
                      methods::Vector{<: VotingMethod},
                      estrats::Vector{ElectorateStrategy},
                      nvot::Int, ncand::Int, nwinners=1,
                      metrics = default_metrics,
                      correlatednoise::Float64=0.1, iidnoise::Float64=0.0)
    electorate = make_electorate(vmodel, nvot, ncand)
    infodict = administerpolls(electorate, (estrats, methods), correlatednoise, iidnoise)
    ballots = castballots.((electorate,), estrats, methods, (infodict,))
    winnerlists = getwinners.(ballots, methods, nwinners, (electorate,))
    winnersets = Set{Set{Int}}()
    winnersetlookup = Vector{Set{Int}}(undef, length(methods))
    for (i, winnerlist) in enumerate(winnerlists)
        winnerset = Set(winnerlist)
        push!(winnersets, winnerset)
        winnersetlookup[i] = winnerset
    end

    normalization_results = zeros(Float64, length(metrics), 2)
    winner_set_qualities = [Dict{Set{Int}, Float64}() for i in 1:length(metrics)]
    for (i, metric) in enumerate(metrics)
        normalization_results[i, 1] = high_end_winner_quality(electorate, metric, nwinners)
        normalization_results[i, 2] = low_end_winner_quality(electorate, metric, nwinners)
        for winnerset in winnersets
            winner_set_qualities[i][winnerset] = winner_set_quality(electorate, winnerset, metric)
        end
    end
    results = Matrix{Float64}(undef, length(methods), length(metrics))
    for i in eachindex(methods)
        for j in eachindex(metrics)
            results[i, j] = winner_set_qualities[j][winnersetlookup[i]]
        end
    end
    return results, normalization_results
end