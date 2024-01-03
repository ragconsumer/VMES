abstract type InfoSpec end
abstract type PollSpec <: InfoSpec end
abstract type ProbSpec <: InfoSpec end

"""
Handles polls for voting methods where the tabulation gives only a single line for each candidate.
"""
struct BasicPollSpec <: PollSpec
    method::VotingMethod
    estrat::ElectorateStrategy
end

struct WinProbSpec <: ProbSpec
    pollspec::PollSpec #the specification of the poll the probabilities are estimated from
    uncertainty::Float64
end

struct TieForTwoSpec <: ProbSpec
    winprobspec::WinProbSpec
end

struct CrudeTop3Spec <: ProbSpec
    pollspec::PollSpec
    uncertainty::Float64
end

"""
A specification that identifies the top finalnumcands in the final round
and the top penultimatenumcands in the next-to-last round, sorted by placements
but without any data related to margins of victory.
"""
struct PositionSpec <: InfoSpec
    pollspec::PollSpec
    finalnumcands::Int
    penultimatenumcands::Int
end

"""
A specification that identifies and sorts the frontrunners and provides the full
pairwise comparison matrix to the strategy function. Provides a (compmat, frontrunners) tuple.
"""
struct CompMatPosSpec <: InfoSpec
    pollspec::PollSpec
    numfrontrunners::Int
end

function Base.:(==)(x::PS, y::PS) where PS <: PollSpec
    x.method == y.method && x.estrat == y.estrat
end

function Base.:(==)(x::WinProbSpec, y::WinProbSpec)
    x.pollspec == y.pollspec && x.uncertainty == y.uncertainty
end

function Base.:(==)(x::TieForTwoSpec, y::TieForTwoSpec)
    x.winprobspec == y.winprobspec
end

function Base.:(==)(x::CrudeTop3Spec, y::CrudeTop3Spec)
    x.pollspec == y.pollspec && x.uncertainty == y.uncertainty
end

function Base.:(==)(x::PositionSpec, y::PositionSpec)
    x.pollspec == y.pollspec && x.finalnumcands == y.finalnumcands && x.penultimatenumcands == y.penultimatenumcands
end

function Base.:(==)(x::CompMatPosSpec, y::CompMatPosSpec)
    x.pollspec == y.pollspec && x.numfrontrunners == y.numfrontrunners
end

function Base.hash(x::PS, h::UInt) where PS <: PollSpec
    h = hash(PS, h)
    h = hash(x.method, h)
    h = hash(x.estrat, h)
    return h
end

function Base.hash(x::WinProbSpec, h::UInt)
    h = hash(x.pollspec, h)
    h = hash(x.uncertainty, h)
    return h
end

Base.hash(x::TieForTwoSpec, h::UInt) = hash(x.winprobspec, h)

function Base.hash(x::CrudeTop3Spec, h::UInt)
    h = hash(x.pollspec, h)
    h = hash(x.uncertainty, h)
    return h
end

function Base.hash(x::PositionSpec, h::UInt)
    h = hash(x.pollspec, h)
    h = hash(x.finalnumcands, h)
    h = hash(x.penultimatenumcands, h)
    return h
end

function Base.hash(x::CompMatPosSpec, h::UInt)
    h = hash(x.pollspec, h)
    h = hash(x.numfrontrunners, h)
    return h
end

"""
    administerpolls(electorate, (strats, methods),
                        correlatednoise::Number, iidnoise::Number, samplesize=nothing)

Conduct all polls that are required for the given strategies.

The strategies can be any combinations of electorate strategies and voter strategies.
strats and methods must be vectors of the same length.
"""
function administerpolls(electorate, (strats, methods),
                        correlatednoise::Number, iidnoise::Number, samplesize=nothing,
                        rng=Random.Xoshiro())
    noisevector = correlatednoise .* randn(rng, size(electorate,1))
    administerpolls(electorate, (strats, methods), noisevector, iidnoise, samplesize, rng)
end

function administerpolls(electorate, (strats, methods),
                         noisevector::Vector{Float64}, iidnoise::Number, samplesize=nothing,
                         rng=Random.Xoshiro())
    infodict = Dict()
    if samplesize === nothing
        respondants = nothing
    else
        respondants = rand(rng, 1:size(electorate,2), samplesize) #drawing WITH replacement
    end
    for i in eachindex(strats, methods)
        for spec in neededinfo(strats[i], methods[i])
            addinfo!(infodict, electorate, spec, noisevector, iidnoise, respondants, rng)
        end
    end
    infodict[nothing] = nothing
    return infodict
end
"""
    addinfo!(infodict, electorate, spec::InfoSpec, noisevector, iidnoise=0, respondants=nothing)

Conduct the specified poll and add it to polldict, along with the polls required to conduct it.

#args
 - `infodict`: A dict in which the keys are specifications for info
                and the values are the correcsponding info.
 - `electorate`: The electorate.
 - `spec`: The poll/info specifications, as determined by the strategy that will use it.
 - `noisevector`: A vector giving polling bias in favor of each individual candidate.
 - `iidnoise`: A float that determines how much noise is added to each result in each poll,
                uncorrelated from anything else
 - `respondants`: The indicies of the subset of the electorate that will be polled.
                    If set to nothing the whole electorate will be polled.
"""
function addinfo!(infodict, electorate, spec::InfoSpec, noisevector, iidnoise=0, respondants=nothing, rng=Random.Xoshiro())
    if haskey(infodict, spec)
        return infodict[spec]
    end
    for dependency in neededinfo(spec)
        if !haskey(infodict, dependency)
            addinfo!(infodict, electorate, dependency, noisevector, iidnoise, respondants, rng)
        end
    end
    addspecificinfo!(infodict, electorate, spec, noisevector, iidnoise, respondants, rng)
end

"""
    addspecificinfo!(infodict, electorate, spec::PollSpec, noisevector, iidnoise, respondants)

Add the specified poll to infodict
"""
function addspecificinfo!(infodict, electorate, spec::PollSpec, noisevector, iidnoise, respondants, rng=Random.Xoshiro())
    if respondants === nothing
        ballots = castballots(electorate, spec.estrat, spec.method, infodict)
    else
        ballots = castballots(electorate, spec.estrat, spec.method, infodict)[:,respondants]
    end
    infodict[spec] = makepoll(ballots, spec, noisevector, iidnoise, rng)
end

"""
    makepoll(ballots, spec::BasicPollSpec, noisevector, iidnoise)

Convert the ballots into polling information with added noise.
"""
function makepoll(ballots, spec::BasicPollSpec, noisevector, iidnoise, rng=Random.Xoshiro())
    unscaledresults = tabulate(ballots, spec.method)
    results = unscaledresults .* pollscalefactor(spec.method, ballots)
    results += noisevector + iidnoise .* randn(rng, size(results))
    clamp!(results, 0, 1)
    return results
end

"""
    addspecificinfo!(infodict, electorate, spec::WinProbSpec, noisevector, iidnoise, respondants)

Add the data for spec to infodict.
"""
function addspecificinfo!(infodict, electorate, spec::WinProbSpec, noisevector, iidnoise, respondants, rng=Random.Xoshiro())
    infodict[spec] = betaprobs(infodict[spec.pollspec], spec.uncertainty)
end

function addspecificinfo!(infodict, electorate, spec::TieForTwoSpec, noisevector, iidnoise, respondants, rng=Random.Xoshiro())
    infodict[spec] = tiefortwoprob(infodict[spec.winprobspec])
end

function addspecificinfo!(infodict, electorate, spec::CrudeTop3Spec, noisevector, iidnoise, respondants, rng=Random.Xoshiro())
    infodict[spec] = crudetop3probs(infodict[spec.pollspec], spec.uncertainty)
end

function addspecificinfo!(infodict, electorate, spec::PositionSpec,
                          noisevector, iidnoise, respondants, rng=Random.Xoshiro())
    if spec.penultimatenumcands == 0
        infodict[spec] = getfrontrunners(infodict[spec.pollspec][:, end], spec.finalnumcands)
    else
        if size(infodict[spec.pollspec],2) > 1
            infodict[spec] = (getfrontrunners(infodict[spec.pollspec][:, end], spec.finalnumcands),
                            getfrontrunners(infodict[spec.pollspec][:, end-1], spec.penultimatenumcands))
        else #if there's only one round of tabulation, use that round for everything
            infodict[spec] = (getfrontrunners(infodict[spec.pollspec][:, 1], spec.finalnumcands),
                            getfrontrunners(infodict[spec.pollspec][:, 1], spec.penultimatenumcands))
        end
    end
end

function addspecificinfo!(infodict, electorate, spec::CompMatPosSpec,
                          noisevector, iidnoise, respondants, rng=Random.Xoshiro())
    frontrunners = getfrontrunners(infodict[spec.pollspec][:, end], spec.numfrontrunners)
    infodict[spec] = (infodict[spec.pollspec], frontrunners)
end

"""
    neededinfo(strat::VoterStrategy, ::VotingMethod)

Specify the info (polls or estimated probabilities) needed to use the strategy.

Must return a set.
"""
neededinfo(strat::VoterStrategy, ::VotingMethod) = Set([strat.neededinfo])
neededinfo(::BlindStrategy, ::VotingMethod) = Set()
neededinfo(spec::PollSpec) = neededinfo(spec.estrat, spec.method)
neededinfo(spec::WinProbSpec) = Set([spec.pollspec])
neededinfo(spec::CrudeTop3Spec) = Set([spec.pollspec])
neededinfo(spec::TieForTwoSpec) = Set([spec.winprobspec])
neededinfo(spec::PositionSpec) = Set([spec.pollspec])
neededinfo(spec::CompMatPosSpec) = Set([spec.pollspec])

function neededinfo(estrat::ElectorateStrategy, method::VotingMethod)
    reduce(union, [neededinfo(strat, method) for strat in estrat.stratlist])
end

"""
    info_used(strat::VoterStrategy, ::VotingMethod)

Specify the info the will be provided to the strategy function.

Unlike neededinfo, returns the object rather than a set containing it, or nothing if no info is needed.
"""
info_used(strat::InformedStrategy, ::VotingMethod) = strat.neededinfo
info_used(::BlindStrategy, ::VotingMethod) = nothing

"""
    pollscalefactor(::VotingMethod, ballots)

The factor that all poll results must be multipied by to lie in [0, 1].
"""
pollscalefactor(::ApprovalMethod, ballots) = 1/size(ballots, 2)
pollscalefactor(method::ScoringMethod, ballots) = 1/(method.maxscore*size(ballots, 2))
pollscalefactor(::BordaCount, ballots) = 1/((size(ballots,1) - 1)*size(ballots, 2))
pollscalefactor(method::Top2Method, ballots) = pollscalefactor(method.basemethod, ballots)

"""
    clamptosum!(a::AbstractArray{<:Real}, total=1, high=1)

Minimally modify the array such that sum(a) = total, minimum(a)>=0, and maximum(a)<=high.
"""
function clamptosum!(a::AbstractArray{Float64}, total=1, high=1)
    #first deal with negative values
    if all(x <= 0 for x in a)
        a .= total/length(a)
        return a
    end
    clamp!(a, 0, Inf)
    a .*= total/sum(a)
    #repeatedly clamp the excess and rescale everything else, until there's nothing to clamp.
    #each iteration begins with sum(a) == total, up to floating point errors.
    while maximum(a) > high
        highvals = filter(>=(high), a)
        nhigh = length(highvals)
        excess = sum(highvals) - high*nhigh
        scalefactor = 1 + excess/(total - sum(highvals))
        clamp!(a, 0, high)
        for i in eachindex(a)
            if a[i] < high
                a[i] *= scalefactor
            end
        end
    end
    return a
end