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

function Base.:(==)(x::BasicPollSpec, y::BasicPollSpec)
    x.method == y.method && x.estrat == y.estrat
end

function Base.:(==)(x::WinProbSpec, y::WinProbSpec)
    x.pollspec == y.pollspec && x.uncertainty == y.uncertainty
end

function Base.:(==)(x::TieForTwoSpec, y::TieForTwoSpec)
    x.winprobspec == y.winprobspec
end

function Base.hash(x::BasicPollSpec, h::UInt)
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

"""
    administerpolls(electorate, (strats, methods),
                        correlatednoise::Number, iidnoise::Number, samplesize=nothing)

Conduct all polls that are required for the given strategies.

The strategies can be any combinations of electorate strategies and voter strategies.
strats and methods must be vectors of the same length.
"""
function administerpolls(electorate, (strats, methods),
                        correlatednoise::Number, iidnoise::Number, samplesize=nothing)
    infodict = Dict()
    if samplesize === nothing
        respondants = nothing
    else
        respondants = rand(1:size(electorate,2), samplesize) #drawing WITH replacement
    end
    noisevector = correlatednoise .* randn(size(electorate,1))
    for i in eachindex(strats, methods)
        for spec in neededinfo(strats[i], methods[i])
            addinfo!(infodict, electorate, spec, noisevector, iidnoise, respondants)
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
function addinfo!(infodict, electorate, spec::InfoSpec, noisevector, iidnoise=0, respondants=nothing)
    if haskey(infodict, spec)
        return infodict[spec]
    end
    for dependency in neededinfo(spec)
        if !haskey(infodict, dependency)
            addinfo!(infodict, electorate, dependency, noisevector, iidnoise, respondants)
        end
    end
    addspecificinfo!(infodict, electorate, spec, noisevector, iidnoise, respondants)
end

"""
    addspecificinfo!(infodict, electorate, spec::PollSpec, noisevector, iidnoise, respondants)

Add the specified poll to infodict
"""
function addspecificinfo!(infodict, electorate, spec::PollSpec, noisevector, iidnoise, respondants)
    if respondants === nothing
        ballots = castballots(electorate, spec.estrat, spec.method, infodict)
    else
        ballots = castballots(electorate, spec.estrat, spec.method, infodict)[:,respondants]
    end
    infodict[spec] = makepoll(ballots, spec, noisevector, iidnoise)
end

"""
    makepoll(ballots, spec::BasicPollSpec, noisevector, iidnoise)

Convert the ballots into polling information with added noise.
"""
function makepoll(ballots, spec::BasicPollSpec, noisevector, iidnoise)
    unscaledresults = tabulate(ballots, spec.method)
    results = unscaledresults .* pollscalefactor(spec.method, ballots)
    results += noisevector + iidnoise .* randn(size(results))
    clamp!(results, 0, 1)
    return results
end

"""
    addspecificinfo!(infodict, electorate, spec::WinProbSpec, noisevector, iidnoise, respondants)

Add the data for spec to infodict.
"""
function addspecificinfo!(infodict, electorate, spec::WinProbSpec, noisevector, iidnoise, respondants)
    infodict[spec] = betaprobs(infodict[spec.pollspec], spec.uncertainty)
end

function addspecificinfo!(infodict, electorate, spec::TieForTwoSpec, noisevector, iidnoise, respondants)
    #NYI
    #infodict[spec] = betaprobs(infodict[spec.wimprobspec], spec.uncertainty)
end

"""
    neededinfo(strat::VoterStrategy, ::VotingMethod)

Specify the info (polls or estimated probabilities) needed to use the strategy.

Must return a set.
"""
neededinfo(strat::VoterStrategy, ::VotingMethod) = Set([strat.neededinfo])
neededinfo(::BlindStrategy, ::VotingMethod) = Set()
neededinfo(spec::BasicPollSpec) = neededinfo(spec.estrat, spec.method)
neededinfo(spec::WinProbSpec) = Set([spec.pollspec])
neededinfo(spec::TieForTwoSpec) = Set([spec.winprobspec])

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