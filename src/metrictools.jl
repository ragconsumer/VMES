function calc_utils(voter::Vector{<:Real}, winners::Vector{Int}, nwinners::Int)
    if nwinners == 1
        return [voter[winners[1]]]
    else
        winnerutils = [voter[winner] for winner in winners]
        return [Statistics.median(winnerutils),
                Statistics.mean(winnerutils),
                maximum(winnerutils)]
    end
end

numutilmetrics(nwinners::Int) = nwinners == 1 ? 1 : 3
numutilmetrics(nwinners::Int, voter_model) = nwinners == 1 ? 1 : 3
numutilmetrics(nwinners::Int, voter_model::SpatialModel) = nwinners == 1 ? 1 : 4
metricnames(metricindex::Integer) = ["Median Winner","Mean Winner","Favorite Winner", "Median Winner Position"][metricindex]