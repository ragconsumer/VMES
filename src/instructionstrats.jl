abstract type InstructionStrategy end
abstract type BlindInstructionStrategy <: InstructionStrategy end

istrat_names = Dict{InstructionStrategy, String}()

struct BulletInstruction <: BlindInstructionStrategy; end
@nameistrat bulletinstruction = BulletInstruction()
struct AbstainInstruction <: BlindInstructionStrategy; end
@nameistrat abstaininstruction = AbstainInstruction()

struct AssistInstruction <: BlindInstructionStrategy
    assist_level::Int
end

Base.show(io::IO, s::AssistInstruction) =
    print(io, "Assist(", s.assist_level, ")")

struct CopyNaturalSupporterInstruction <: InstructionStrategy
    strategy::VoterStrategy
end

Base.show(io::IO, s::CopyNaturalSupporterInstruction) =
    print(io, "NatCopy(", s.strategy, ")")

function Base.show(io::IO, s::IS) where {IS <: InstructionStrategy}
    if s in keys(istrat_names)
        print(io, istrat_names[s])
    else
        print(io, IS, [getfield(s, i) for i in 1:fieldcount(IS)])
    end
end

"""
    instruct_votes(controlling_cand::Int, istrat::InstructionStrategy, ndrones::Int, ncands::Int, method::VotingMethod,
                   info, targets...)
Create the ballots for ndrones voters, as determined by their controlling candidate and the instruction strategy.
"""
function instruct_votes(controlling_cand::Int, istrat::InstructionStrategy, ndrones::Int, ncands::Int, method::VotingMethod,
                        info::Nothing, targets...)
    instruct_votes(controlling_cand, istrat, ndrones, ncands, method, targets...)
end

function instruct_votes(controlling_cand::Int, istrat::BulletInstruction, ndrones::Int, ncands::Int, method::VotingMethod)
    preference = zeros(Int, ncands)
    preference[controlling_cand] = 1
    ballot = vote(preference, bullet, method)
    return repeat(ballot, 1, ndrones)
end

function instruct_votes(controlling_cand::Int, istrat::AbstainInstruction, ndrones::Int, ncands::Int, method::VotingMethod)
    return zeros(Int, ncands, ndrones)
end

function instruct_votes(controlling_cand::Int, istrat::AssistInstruction, ndrones::Int, ncands::Int, method::VotingMethod,
                        cand_to_help::Int)
    ballots = instruct_votes(controlling_cand, bulletinstruction, ndrones, ncands, method)
    ballots[cand_to_help,:] .= istrat.assist_level
    return ballots
end

function instruct_votes(controlling_cand::Int, istrat::CopyNaturalSupporterInstruction, ndrones::Int, ncands::Int,
                        method::VotingMethod, supporter_util_matrix::AbstractMatrix)
    ballot = vote(supporter_util_matrix[:, controlling_cand], istrat.strategy, method)
    return repeat(ballot, 1, ndrones)
end