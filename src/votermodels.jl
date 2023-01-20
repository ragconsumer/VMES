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