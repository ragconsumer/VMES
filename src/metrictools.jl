function harmonic_mean(xs::Vector{<:Real})
    sum(x/i for (i,x) in enumerate(sort(xs, rev=true))) / sum(1/i for i in 1:length(xs))
end
"""
    harmonic_sl(xs::Vector{<:Real})

Harmonic mean variant with Saint-Lague weights.
"""
function harmonic_sl(xs::Vector{<:Real})
    sum(x/(2i-1) for (i,x) in enumerate(sort(xs, rev=true))) / sum(1/(2i-1) for i in 1:length(xs))
end

"""
    calc_utils(voter::Vector{<:Real}, winners::Vector{Int}, nwinners::Int)

Determine utility metrics for a given voter given the winners.
"""
function calc_utils(voter::Vector{<:Real}, winners::Vector{Int}, nwinners::Int)
    if nwinners == 1
        return [voter[winners[1]]]
    else
        winnerutils = [voter[winner] for winner in winners]
        return [harmonic_mean(winnerutils),
                harmonic_sl(winnerutils),
                Statistics.mean(winnerutils),
                maximum(winnerutils),
                Statistics.median(winnerutils)]
    end
end

numutilmetrics(nwinners::Int) = nwinners == 1 ? 1 : 5
numutilmetrics(nwinners::Int, voter_model) = nwinners == 1 ? 1 : 3
numutilmetrics(nwinners::Int, voter_model::SpatialModel) = nwinners == 1 ? 1 : 4
metricnames(metricindex::Integer) = ["Harmonic","Harmonic SL","Mean Winner","Maximum Winner","Median Winner"][metricindex]