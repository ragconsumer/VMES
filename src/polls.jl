abstract type PollSpec end

"""
Handles polls for voting methods where the tabulation gives only a single line for each candidate.
"""
struct BasicPollSpec <: PollSpec
    method::VotingMethod
    estrat::ElectorateStrategy
end

"""
    administerpolls(electorate, estrats::Vector{ElectorateStrategy}, methods::Vector{VotingMethod},
                        correlatednoise::Number, iidnoise::Number, samplesize=nothing)

Conduct all polls that are required for the given electorate strategies.

estrats and methods must be vectors of the same length.
"""
function administerpolls(electorate, estrats::Vector{ElectorateStrategy}, methods::Vector,
                        correlatednoise::Number, iidnoise::Number, samplesize=nothing)
    polldict = Dict()
    if samplesize === nothing
        respondants = nothing
    else
        respondants = rand(1:size(electorate,2), samplesize) #drawing WITH replacement
    end
    noisevector = correlatednoise .* randn(size(electorate,1))
    for i in eachindex(estrats, methods)
        for spec in neededpolls(estrats[i], methods[i])
            addpoll!(polldict, electorate, spec, noisevector, iidnoise, respondants)
        end
    end
    return polldict
end
"""
    addpoll!(polldict, electorate, spec::PollSpec, noisevector, iidnoise=0, respondants=nothing)

Conduct the specified poll and add it to polldict, along with the polls required to conduct it.

#args
 - `polldict`: A dict in which the keys are poll specifications and the values are the poll results.
 - `electorate`: The electorate.
 - `spec`: The poll specifications, as determined by the strategy that will use it.
 - `noisevector`: A vector giving the poll's bias in favor of each individual candidate.
 - `iidnoise`: A float that determines how much noise is added to each result, uncorrelated from anything else
 - `respondants`: The indicies of the subset of the electorate that will be polled.
                    If set to nothing the whole electorate will be polled.
"""
function addpoll!(polldict, electorate, spec::PollSpec, noisevector, iidnoise=0, respondants=nothing)
    if haskey(polldict, spec)
        return polldict[spec]
    end
    for dependency in neededpolls(spec.estrat, spec.method) #I may want to turn this into a macro
        if !haskey(polldict, dependency)
            addpoll!(polldict, electorate, dependency, noisevector, iidnoise, respondants)
        end
    end
    if respondants === nothing
        ballots = castballots(electorate, spec.estrat, spec.method, polldict)
    else
        ballots = castballots(electorate, spec.estrat, spec.method, polldict)[:,respondants]
    end
    polldict[spec] = makepoll(ballots, spec, noisevector, iidnoise)
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
    neededpolls(strat::VoterStrategy, ::VotingMethod)

Specify the polls needed to use the strategy.
"""
neededpolls(strat::VoterStrategy, ::VotingMethod) = strat.neededpolls
neededpolls(::BlindStrategy, ::VotingMethod) = Set()

function neededpolls(estrat::ElectorateStrategy, method::VotingMethod)
    reduce(union, [neededpolls(strat, method) for strat in estrat.stratlist])
end

pollscalefactor(::ApprovalMethod, ballots) = 1/size(ballots, 2)
pollscalefactor(method::ScoringMethod, ballots) = 1/(method.maxscore*size(ballots, 2))
pollscalefactor(::BordaCount, ballots) = 1/((size(ballots,1) - 1)*size(ballots, 2))