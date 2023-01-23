abstract type VoterModel end
abstract type SpatialModel <: VoterModel end
abstract type SampleModel <: VoterModel end

struct ImpartialCulture <: VoterModel
    distribution
end

struct DimModel <: SpatialModel
    ndims
    dimweights
end

struct DCCModel <: SpatialModel
    viewdecaydist
    viewcut
    dimdecaydist
    dimcut
    clusteralpha
    caringdist
end

"""
Use the defaults from the Python VSE code.
"""
dcc = DCCModel(Distributions.Uniform(), 0.2,
                        Distributions.Uniform(), 0.2,
                        1, Distributions.Beta(6, 3))

"""
A container for containing both an electorate and the seed that generated it.
"""
struct SeededElectorate <: AbstractMatrix{Float64}
    data::Matrix{Float64}
    seed::Int
end

Base.size(e::SeededElectorate) = Base.size(e.data)
Base.getindex(e::SeededElectorate, I::Vararg{Int,N}) where {N} = e.data[I...]
Base.setindex!(e::SeededElectorate, v::Float64, I::Vararg{Int,N}) where N = (e.data[I] = v)
getseed(e::SeededElectorate) = e.seed
getseed(::Any) = 0

DimModel(dim::Int) = DimModel(dim, ones(Int, dim))

ic = ImpartialCulture(randn)

"""
    make_electorate(model::VoterModel, nvot::Int, ncand::Int)

Create an electorate according to the voter model. Creates a random seed.
"""
function make_electorate(model::VoterModel, nvot::Int, ncand::Int)
    seed = abs(rand(Int))
    make_electorate(model, nvot, ncand, seed)
end

"""
    make_electorate(model::ImpartialCulture, nvot::Int, ncand::Int, seed::Int)

Create an electorate in which all preferences are uncorrelated. Very unrealistic.
"""
function make_electorate(model::ImpartialCulture, nvot::Int, ncand::Int, seed::Int)
    rng = Random.Xoshiro(seed)
    SeededElectorate(model.distribution(rng, ncand, nvot), seed)
end

"""
    make_electorate(model::DimModel, nvot::Int, ncand::Int, seed::Int)

Create an electorate under a spatial model.

Utilities are minus the cartesian distance between a voter and a candidate.
"""
function make_electorate(model::DimModel, nvot::Int, ncand::Int, seed::Int)
    rng = Random.Xoshiro(seed)
    voterpositions = randn(rng, model.ndims, nvot)
    candpositions = randn(rng, model.ndims, ncand)
    utilmatrix = Matrix{Float64}(undef, ncand, nvot)
    for (i, voter) in enumerate(eachcol(voterpositions))
        for (j, cand) in enumerate(eachcol(candpositions))
            utilmatrix[j, i] = -sqrt(
                sum((model.dimweights[k]*(voter[k] - cand[k]))^2 for k in eachindex(model.dimweights)))
        end
    end
    return SeededElectorate(utilmatrix, seed)
end

"""
    make_electorate(model::DCCModel, nvot::Int, ncand::Int, seed::Int)

Create an electorate under a Dirichlet CrossCat model.

See https://jmlr.org/papers/volume17/11-392/11-392.pdf for a description of CrossCat.

Designed and originally written in Python by Jameson Quinn.
"""
function make_electorate(model::DCCModel, nvot::Int, ncand::Int, seed::Int)
    rng = Random.Xoshiro(seed)
    viewdims, dimweights = makeviews(model, rng)
    nviews = length(viewdims)
    views, clustercounts = assignclusters(model, nvot + ncand, nviews, rng)
    clustermeans, clusterimportances = makeclusterprefs(model, nviews, viewdims, clustercounts, rng)
    votersandcands, weights = makeprefpoints(model, views, viewdims, dimweights, clustermeans, clusterimportances, nviews, rng)
    utilmatrix = positions_to_utils(model, votersandcands, weights, nvot, ncand)
    return SeededElectorate(utilmatrix, seed)
end

"""
    makeviews(model::DCCModel, rng)

Create views for the CrossCat model and weight their relative importance.

Also creates dimensions wthin each view and weights the imprtance of each dimension.
Returns (viewdims, dimweights), where viewdims is a vector giving the number of dimensions
with each view, and dimweights is a vector with the weights giving the importance of each
dimension.
"""
function makeviews(model::DCCModel, rng)
    viewdims = Int[] #number of dimensions in each view
    dimweights = Float64[] #unnormalized raw importance of each dimension, regardless of view
    view_weight = 1
    while view_weight > model.viewcut
        dimweight = view_weight
        dimnum = 0
        while dimweight > model.dimcut
            append!(dimweights, dimweight)
            dimnum += 1
            dimweight *= rand(rng, model.dimdecaydist)
        end
        append!(viewdims, dimnum)
        view_weight *= rand(rng, model.viewdecaydist)
    end
    return (viewdims, dimweights)
end

"""
    assignclusters(model::DCCModel, npoints::Int, nviews::Int, rng)

Use a Chinese Restaurant model to assign voters and candidates to clusters for each view.

A point can represent a voter or a candidate.

Returns (views, clustercounts).
views is an (nviews by npoints) matrix in which views[view, point] gives the cluster index
assigned to the point for a given view.
clustercounts is a vector s.t. clustercounts[view] is the total number of clusters within
the given view.
"""
function assignclusters(model::DCCModel, npoints::Int, nviews::Int, rng)
    views = Matrix{Int}(undef, nviews, npoints)
    clustercounts = zeros(Int, nviews)
    for i in 1:npoints #voter and/or candidate index
        for view in 1:nviews
            r = (i - 1 + model.clusteralpha) * rand(rng)
            if r > i - 1
                clustercounts[view] += 1
                views[view, i] = clustercounts[view]
            else
                views[view, i] = views[view, floor(Int, r) + 1]
            end
        end
    end
    return views, clustercounts
end

"""
    makeclusterprefs(model::DCCModel, views::Matrix{Int}, viewdims::Vector{Int}, clustercounts::Int, rng)

Create a mean preference for each cluster within each view in each of the view's dimensions in "policyspace"

Returns (clustermeans, clusterimportances).
clustermeans[dim_within_view, cluster, view] is the mean along dim_within_view of the cluster for the view.
clusterimportances[cluster, view] is the importance of the given view to the cluster
"""
function makeclusterprefs(model::DCCModel, nviews::Int, viewdims::Vector{Int}, clustercounts::Vector{Int}, rng)
    maxviewsize = maximum(viewdims)
    clustermeans = Array{Float64, 3}(undef, maxviewsize, maximum(clustercounts), length(viewdims))
    clusterimportances = zeros(Float64, maximum(clustercounts), length(viewdims))
    for view in 1:nviews
        for cluster in 1:clustercounts[view]
            cares = rand(rng, model.caringdist) #How extreme the cluster's preferences are expected to be
            for dim in 1:viewdims[view]
                clustermeans[dim, cluster, view] = randn(rng)*sqrt(cares)
            end
            clusterimportances[cluster, view] = rand(rng, model.caringdist)
        end
    end
    return clustermeans, clusterimportances
end

"""
    makeprefpoints(model::DCCModel,
                        views::Matrix{Int},
                        viewdims::Vector{Int},
                        clustermeans::Array{Float64},
                        clusterimportances::Matrix{Float64},
                        nviews::Int, rng)

Create points in "policyspace" for all voters and candidates.

Returns (points, weights).
points: the position in policyspace of all voters and candidates
weights[dimension, voter] is the weight assigned by voter to dimension
"""
function makeprefpoints(model::DCCModel,
                        views::Matrix{Int},
                        viewdims::Vector{Int},
                        dimweights::Vector{Float64},
                        clustermeans::Array{Float64},
                        clusterimportances::Matrix{Float64},
                        nviews::Int, rng)
    npoints = size(views, 2)
    totaldims = sum(viewdims)
    points = Matrix{Float64}(undef, totaldims, npoints)
    weights = Matrix{Float64}(undef, totaldims, npoints)
    for p in 1:npoints
        dim = 1
        for view in 1:nviews
            cluster = views[view, p]
            endindex = dim + viewdims[view]-1
            centerofmass = clustermeans[1:viewdims[view], cluster, view]
            clusterweight = clusterimportances[cluster, view]
            points[dim:endindex , p] = centerofmass + (
                 randn(rng, viewdims[view]) .* sqrt(1 - clusterweight)
            )
            weights[dim:endindex , p] = dimweights[dim:endindex] .* clusterweight
            dim += viewdims[view]
        end
    end
    return points, weights
end

"""
    positions_to_utils(model::DCCModel, votersandcands, weights, nvot, ncand)

Convert the weights and voter/candidate positions in policyspace to a utility matrix.
"""
function positions_to_utils(model::DCCModel, votersandcands, weights, nvot, ncand)
    ndims = size(votersandcands, 1)
    weight_totals = [sum((weights[dim, voter])^2
                    for dim in 1:ndims) for voter in 1:nvot]
    utilmatrix = Matrix{Float64}(undef, ncand, nvot)
    voterpositions = view(votersandcands, :, 1:nvot)
    candpositions = view(votersandcands, :, nvot+1:nvot+ncand)
    for voter in 1:nvot
        for cand in 1:ncand
            utilmatrix[cand, voter] = -sqrt(sum(
                ((voterpositions[d, voter] - candpositions[d, cand])*weights[d, voter])^2
                for d in 1:ndims) / weight_totals[voter])
        end
    end
    return utilmatrix
end