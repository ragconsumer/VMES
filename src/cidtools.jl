function normalizedUtilDeviation(voter, cand)
    (voter[cand] - Statistics.mean(voter))/Statistics.std(voter, corrected=false)
end

"""
    util_pert_on_score_stats(niter::Int,
    vmodel::VoterModel, method::VotingMethod, strat::BlindStrategy,
    nvot::Int, ncand::Int, util_shift::Real)

Determine how much a voter increasing their opinion of a candidate by util_shift
increases the support shown on their ballot, in expectation

Also determines how much this added support decreases the support of all other candidates.
"""
function util_pert_on_score_stats(niter::Int,
    vmodel::VoterModel, method::VotingMethod, strat::BlindStrategy,
    nvot::Int, ncand::Int, util_shift::Real)
    selftotal = 0
    othertotal = 0
    for _ in 1:niter
        electorate = make_electorate(vmodel, nvot, ncand)
        for v in 1:nvot
            oldballot = vote(electorate[:, v], strat, method)
            for c in 1:ncand
                electorate[c, v] += util_shift
                newballot = vote(electorate[:, v], strat, method)
                electorate[c, v] -= util_shift
                for c2 in 1:ncand
                    if c == c2
                        selftotal += newballot[c2] - oldballot[c2]
                    else
                        othertotal += newballot[c2] - oldballot[c2]
                    end
                end
            end
        end
    end
    return selftotal/(niter*nvot*ncand), othertotal/(niter*nvot*ncand*(ncand-1))
end

"""
    influence_cdf(cid_df, threshold)

Determine how much influence the least supportive voters have.
"""
function influence_cdf(cid_df::DataFrame, threshold::Real)
    gdf = groupby(cid_df, ["Method", "Electorate Strategy", "ncand", "Utility Change"])
    combine(gdf, [:CID, :Bucket, Symbol("Total Buckets")] =>
        ((c, b, nb) -> sum(c[i] for i in 1:nb[1] if b[i]//nb[i] <= threshold)/nb[1]) =>
        "CS$threshold")
end

"""
    total_variation_distance_from_uniform(dist)

Calculate the total variation distance from the uniform distribution
"""
function total_variation_distance_from_uniform(dist)
    avg = Statistics.mean(dist)
    return sum(max((val-avg),0) for val in dist)/(avg*length(dist))
end

"""
    earth_movers_distance_from_uniform(dist)

Calculate the earth mover's distance fromt eh uniform distribution
"""
function earth_movers_distance_from_uniform(dist)
    avg = Statistics.mean(dist)
    earth_held = 0.
    movetotal = 0.
    for val in dist
        movetotal += abs(earth_held)
        earth_held += val - avg
    end
    return movetotal/(avg*length(dist)^2)
end

function use_metric_on_pair(cidvector, buckets, metric)
    pairs = collect(zip(cidvector, buckets))
    sortedpairs = sort(pairs, by=x->x[2])
    sortedvector = [c for (c, _) in sortedpairs]
    return metric(sortedvector)
end

function distance_from_uniform(metric::Function, cid_df::DataFrame)
    gdf = groupby(cid_df, ["Method", "Electorate Strategy", "ncand", "Utility Change"])
    combine(gdf, [:CID, :Bucket] =>
        ((c, b) -> use_metric_on_pair(c, b, metric)) =>
        :DFU)
end