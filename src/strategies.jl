export vote
export hon, bullet, abstain, TopBottomThreshold, TopMeanThreshold, StdThreshold

abstract type VoterStrategy end
abstract type BlindStrategy <: VoterStrategy end

struct HonestVote <: BlindStrategy; end
hon = HonestVote()

struct BulletVote <: BlindStrategy; end
bullet = BulletVote()

struct Abstain <: BlindStrategy; end
abstain = Abstain()

struct ViabilityAware <: VoterStrategy
    neededpolls::Vector
    pollinguncertainty::Float64
end

include("approvalstrats.jl")
include("scorestrats.jl")
include("rankedstrats.jl")
include("top2strats.jl")
include("experimentalstrats.jl")

"""
    vote(voter, strat::BlindStrategy, method::VotingMethod, polls)

Vote without using any polling data.
"""
function vote(voter, strat::BlindStrategy, method::VotingMethod, polls)
    vote(voter, strat, method)
end

"""
    vote(voter, strat::HonestVote, method::RankedMethod)

Fill a ranked ballot honestly (without tied rankings).
"""
function vote(voter, strat::HonestVote, method::RankedMethod)
    sortedutils = sort(collect(enumerate(voter)), lt=(((i1,u1),(i2,u2)) -> u1<u2 ? true : u1==u2 && i1>i2 ? true : false))
    ballot = zeros(Int, length(voter))
    for (score, (i, _)) in enumerate(sortedutils)
        ballot[i] = score - 1
    end
    return ballot
end

vote(voter, ::HonestVote, method::PluralityVoting) = vote(voter, bullet, method)

"""
    vote(voter, strat::Abstain, method::OneRoundMethod)

Cast a blank ballot.
"""
function vote(voter, ::Abstain, method::OneRoundMethod)
    return zeros(Int, length(voter))
end

"""
    vote(voter, strat::Abstain, method::Top2Method)

Cast a blank ballot in both rounds.
"""
function vote(voter, ::Abstain, ::Top2Method)
    return zeros(Int, length(voter)*2)
end



topballotmark(_, ::ApprovalMethod) = 1
topballotmark(_, method::ScoringMethod) = method.maxscore
topballotmark(voter, ::RankedMethod) = length(voter) - 1

function vote(voter, ::BulletVote, method::OneRoundMethod)
    ballot = zeros(Int, length(voter))
    favorite = argmax(voter)
    ballot[favorite] = topballotmark(voter, method)
    return ballot
end