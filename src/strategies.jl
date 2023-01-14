export vote
export hon, bullet, abstain

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

"""
    vote(voter, strat::BulletVote, method::RankedMethod)

Bullet vote.
"""
function vote(voter, strat::BulletVote, method::RankedMethod)
    ballot = zeros(Int, length(voter))
    favorite = argmax(voter)
    ballot[favorite] = length(voter)
    return ballot
end

"""
    vote(voter, strat::BulletVote, method::ApprovalMethod)

Bullet vote.
"""
function vote(voter, strat::BulletVote, method::ApprovalMethod)
    ballot = zeros(Int, length(voter))
    favorite = argmax(voter)
    ballot[favorite] = 1
    return ballot
end

"""
    vote(voter, strat::BulletVote, method::ScoringMethod)

Bullet vote.
"""
function vote(voter, strat::BulletVote, method::ScoringMethod)
    ballot = zeros(Int, length(voter))
    favorite = argmax(voter)
    ballot[favorite] = method.maxscore
    return ballot
end

"""
    vote(voter, strat::BulletVote, method::Top2Method)

Bullet vote in the first election. Vote honestly in the runoff.
"""
function vote(voter, strat::BulletVote, method::Top2Method)
    r1ballot = vote(voter, strat, method.basemethod)
    runoffprefs = vote(voter, hon, irv)
    return [r1ballot;;runoffprefs]
end

"""
    vote(voter, strat::Abstain, method::OneRoundMethod)

Cast a blank ballot.
"""
function vote(voter, strat::Abstain, method::OneRoundMethod)
    return zeros(Int, length(voter))
end

"""
    vote(voter, strat::Abstain, method::Top2Method)

Cast a blank ballot in both rounds.
"""
function vote(voter, strat::Abstain, method::Top2Method)
    return zeros(Int, length(voter)*2)
end
#=
function everyonevote(electorate::Matrix, strat::VoterStrategy, method::VotingMethod)
    return cat([vote(voter, strat, method) for voter in eachslice(electorate,dims=2)]...; dims=2)
end
=#
"""
    neededpolls(strat::VoterStrategy, ::VotingMethod)

Specify the polls needed to use the strategy.
"""
neededpolls(strat::VoterStrategy, ::VotingMethod) = strat.neededpolls

neededpolls(::BlindStrategy, ::VotingMethod) = []