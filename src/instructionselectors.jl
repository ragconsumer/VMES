abstract type InstructionSelector end
neededinfo(s::InstructionSelector) = s.neededinfo
selector_names = Dict{InstructionSelector, String}()

"""
Selects instructors based purely on candidate index, without using polls.
"""
struct ArbitrarySelector <: InstructionSelector
    ninstructors::Int
    ntrack::Int
end
ArbitrarySelector() = ArbitrarySelector(1,1)
num_trackees(s::ArbitrarySelector) = s.ntrack

struct OnePositionalSelector <: InstructionSelector
    neededinfo
    position::Int
end

num_trackees(s::OnePositionalSelector) = 1

struct TwoPositionalSelectorOneWay <: InstructionSelector
    neededinfo
    position1::Int
    position2::Int
end

num_trackees(s::TwoPositionalSelectorOneWay) = 2

struct TwoPositionalSelectorTwoWay <: InstructionSelector
    neededinfo
    position1::Int
    position2::Int
end

num_trackees(s::TwoPositionalSelectorTwoWay) = 2

selector_names = Dict{InstructionSelector, String}()

function Base.show(io::IO, s::IS) where {IS <: InstructionSelector}
    if s in keys(selector_names)
        print(io, selector_names[s])
    else
        print(io, IS, [getfield(s, i) for i in 1:fieldcount(IS)])
    end
end

"""
Select the instructors, candidates to track, and targets for the instruction strategies.

Returns a tuple of three vectors:
- The first contains the indices of the instructors.
- The second contains the indices of the candidates to track.
- The third contains vectors of candidate indices that are the targets for the instruction strategies;
    the ith vector has the targets of the ith instructor.
"""
function select_instructors_and_trackees(selector::ArbitrarySelector,_...)
    targets = [i for i in 1:selector.ninstructors] .% selector.ntrack .+ 1
    targets = [[i] for i in targets]
    return collect(1:selector.ninstructors), collect(1:selector.ntrack), targets
end
    
function select_instructors_and_trackees(selector::OnePositionalSelector, method::VotingMethod, poll::AbstractArray)
    c = placementsfromtab(poll, method)[selector.position]
    return [c], [c], [[]]
end

function select_instructors_and_trackees(selector::TwoPositionalSelectorOneWay, method::VotingMethod, poll::AbstractArray)
    placements = placementsfromtab(poll, method)
    instructor = placements[selector.position1]
    target = placements[selector.position2]
    return [instructor], [instructor, target], [[target]]
end

function select_instructors_and_trackees(selector::TwoPositionalSelectorTwoWay, method::VotingMethod, poll::AbstractArray)
    placements = placementsfromtab(poll, method)
    i1 = placements[selector.position1]
    i2 = placements[selector.position2] # i1 and i2 are the instructors
    return [i1, i2], [i1, i2], [[i2],[i1]]
end