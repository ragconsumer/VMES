abstract type VoterStrategy end
abstract type BlindStrategy <: VoterStrategy end
abstract type InformedStrategy <: VoterStrategy end

stratnames = Dict{VoterStrategy, String}()

struct HonestVote <: BlindStrategy; end
@namestrat hon = HonestVote()

struct BulletVote <: BlindStrategy; end
@namestrat bullet = BulletVote()

struct Abstain <: BlindStrategy; end
@namestrat abstain = Abstain()

struct ViabilityAware <: VoterStrategy
    neededpolls::Vector
    pollinguncertainty::Float64
end

include("pollstoprobs.jl")
include("approvalstrats.jl")
include("scorestrats.jl")
include("rankedstrats.jl")
include("top2strats.jl")
include("experimentalstrats.jl")

function Base.:(==)(x::T, y::T) where T <: VoterStrategy
    all(getfield(x, fname) == getfield(y, fname) for fname in fieldnames(T))
end

function Base.hash(s::T, h::UInt) where T <: VoterStrategy
    h = hash(T, h)
    for field in fieldnames(T)
        h = hash(getfield(s, field), h)
    end
    return h
end


function Base.show(io::IO, s::S) where {S <: BlindStrategy}
    if s in keys(stratnames)
        print(io, stratnames[s])
    else
        print(io, S)
        if Base.issingletontype(S)
            return
        end
        print(io, "(")
        for field in [getfield(s, i) for i in 1:fieldcount(S)-1]
            print(io, field, ", ")
        end
        print(io, getfield(s, fieldcount(S)))
        print(io, ")")
    end
end

function Base.show(io::IO, s::S) where {S <: InformedStrategy}
    if fieldcount(S) > 1
        print(io, S, [getfield(s, fname) for fname in fieldnames(S) if fname != :neededinfo])
    else
        print(io, S)
    end
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

vote(voter, ::HonestVote, method::PluralityMethod) = vote(voter, bullet, method)

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
topballotmark(voter, method::Top2Method) = topballotmark(voter, method.basemethod)

function vote(voter, ::BulletVote, method::OneRoundMethod)
    ballot = zeros(Int, length(voter))
    favorite = argmax(voter)
    ballot[favorite] = topballotmark(voter, method)
    return ballot
end

function vote(voter, strat::InformedStrategy, method::OneRoundMethod, infodict::Dict)
    vote(voter, strat, method, infodict[neededinfo(strat, method)])
end