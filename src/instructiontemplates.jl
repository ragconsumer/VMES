abstract type InstructionStratTemplate end
abstract type InstructionSelectorTemplate end

struct BasicPollIStratTemplate <: InstructionStratTemplate
    basestrat::Union{DataType, Function}
    method::VotingMethod
    stratargs::Vector{Any}
end

struct CopySupporterITemplate <: InstructionStratTemplate end

struct BasicSelectorTemplate <: InstructionSelectorTemplate
    selector::Union{DataType, Function}
    method::VotingMethod
    selectorargs::Vector{Any}
end

isfromtemplate(template::InstructionStrategy, _, _) = template

selectorfromtemplate(template::InstructionSelector, _, _) = template

function selectorfromtemplate(template::BasicSelectorTemplate, pollestrat, pollinguncertainty::Number)
    template.selector(BasicPollSpec(template.method, pollestrat), template.selectorargs...)
end
