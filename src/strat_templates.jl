"""
A voter strategy template contains the necessary information
to create a voter strategy when given an electorate strategy
for polling and an estimate of polling noise.

For each template, basestrat is the type of the strategy that
will be created, and stratargs is a vector of additional arguments
for the strategy.
"""
abstract type VoterStratTemplate end

struct BasicPollStratTemplate <: VoterStratTemplate
    basestrat::Union{DataType, Function}
    method::VotingMethod
    stratargs::Vector{Any}
end

struct BasicWinProbTemplate <: VoterStratTemplate
    basestrat::Union{DataType, Function}
    extrauncertainty::Float64
    method::VotingMethod
    stratargs::Vector{Any}
end

struct TieForTwoTemplate <: VoterStratTemplate
    basestrat::Union{DataType, Function}
    extrauncertainty::Float64
    method::VotingMethod
    stratargs::Vector{Any}
end

struct CrudeTop3Template <: VoterStratTemplate
    basestrat::Union{DataType, Function}
    extrauncertainty::Float64
    method::VotingMethod
    stratargs::Vector{Any}
end

function BasicWinProbTemplate(basestrat::Union{DataType, Function}, method::VotingMethod, stratargs::Vector)
    BasicWinProbTemplate(basestrat, 0.0, method, stratargs)
end

approvalvatemplate = BasicWinProbTemplate(ApprovalVA, approval, [])
pluralityvatemplate = BasicWinProbTemplate(PluralityVA, plurality, [])
starvatemplate = BasicWinProbTemplate(STARVA, score, [0.1])
bordavatemplate = BasicWinProbTemplate(BordaVA, borda, [])

struct ApprovalWinProbTemplate <: VoterStratTemplate
    basestrat::Union{DataType, Function}
    extrauncertainty::Float64
    approvalstrat::VoterStrategy
    stratargs::Vector{Any}
end

struct CondorcetPollStratTemplate <: VoterStratTemplate
    basestrat::Union{DataType, Function}
    method::CondorcetCompMatOnly
    stratargs::Vector{Any}
end

struct RCVPollStratTemplate <: VoterStratTemplate
    basestrat::Union{DataType, Function}
    nwinners::Int
    stratargs::Vector{Any}
end

#These setting are approximately optimal for each of these voting methods.
#However, with only 3 winners it helps to use a lower approval threshold in the polls.
irvvatemplate = ApprovalWinProbTemplate(IRVVA, 0.1, TopMeanThreshold(0.1), [0.0])
approvaltop2vatemplate = ApprovalWinProbTemplate(ApprovalTop2VA, 0.1, TopMeanThreshold(0.1), [])
pluralitytop2vatemplate = ApprovalWinProbTemplate(PluralityTop2VA, 0.1, TopMeanThreshold(0.1), [])

struct PositionalStratTemplate <: VoterStratTemplate
    basestrat::Union{DataType, Function}
    pollspecfunc::Union{DataType, Function}
    method::VotingMethod
    finalnumcands::Int
    penultimatenumcands::Int
    stratargs::Vector{Any}
end

struct CondorcetPositionalStratTemplate <: VoterStratTemplate
    basestrat::Union{DataType, Function}
    pollspecfunc::Union{DataType, Function}
    method::VotingMethod
    numfrontrunners::Int
    stratargs::Vector{Any}
end

plurality_pos_template = PositionalStratTemplate(PluralityPositional, BasicPollSpec, plurality, 2, 0, [])
approval_pos_template = PositionalStratTemplate(ApprovalPositional, BasicPollSpec, approval, 2, 0, [])
pluralitytop2_pos_template(args...) = PositionalStratTemplate(PluralityTop2Positional, Top2PollSpec, pluralitytop2, 2, 3, collect(args))
approvaltop2_pos_template(args...) = PositionalStratTemplate(ApprovalTop2Positional, Top2PollSpec, approvaltop2, 2, 3, collect(args))
irv_pos_template(args...) = PositionalStratTemplate(IRVPositional, RCVPollSpec, irv, 2, 3, collect(args))
star_pos_template(args...) = PositionalStratTemplate(STARPositional, STARPollSpec, star, 2, 3, collect(args))
minimax_pos_template(args...) = CondorcetPositionalStratTemplate(MinimaxPositional, CondorcetPollSpec, minimax, 3, collect(args))

"""
Contains the information needed to conventiently construct an electorate strategy.

The basic procedure is to have one or more rounds of polling, with an
electorate strategy for each round. The polls in the ith round depend on the
electorate strategy from (i-1)th round; the polls in the first round must use
exclusively blind strategies.

rounds[i] describes the electorate strategy for the ith round as a vector of
(vstemplate, startindex, endindex tuples). vstemplate is the voter strategy
template (it can also be a blind strategy). startindex is the index of the first
voter who uses this strategy, and endindex is the index of the last voter who uses
it. The [startindex, endindex] intervals for multiple templates within a round must
not overlap. If a voter is not in any of the intervals in the ith round, the voter
will behave as they did in the (i-1)th round.
"""
struct ESTemplate
    flexible_strategists::Int
    rounds::Vector{Vector{Tuple{Union{VoterStrategy, VoterStratTemplate}, Int, Int}}}
end

"""
    esfromtemplate(estemplate::ESTemplate, pollinguncertainty::Float64)

Convert an ESTemplate into an electorate strategy. See ESTemplate.
"""
function esfromtemplate(estemplate::ESTemplate, pollinguncertainty::Float64=0.1)
    lastroundestrat = nothing
    for vstemplatelist in estemplate.rounds
        sort!(vstemplatelist, by=r->r[2])
        lastend = 0
        stratlist = Vector{VoterStrategy}()
        userslist = Vector{Tuple{Int,Int}}()
        for (template, startindex, endindex) in vstemplatelist
            append_estrat_specs!(stratlist, userslist, lastroundestrat, lastend+1, startindex-1)
            push!(stratlist, vsfromtemplate(template, lastroundestrat, pollinguncertainty))
            push!(userslist, (startindex, endindex))
            lastend = endindex
        end
        if lastroundestrat !== nothing
            append_estrat_specs!(stratlist, userslist, lastroundestrat, lastend+1, lastroundestrat.stratusers[end][2])
        end
        lastroundestrat = ElectorateStrategy(estemplate.flexible_strategists, stratlist, userslist)
    end
    return lastroundestrat
end

esfromtemplate(estrat::ElectorateStrategy, _) = estrat

"""
    vsfromtemplate(template::BasicPollStratTemplate, pollestrat::ElectorateStrategy, _::Float64)

Produce a voter strategy from a template, electorate strategy, and an estimate of the uncertainty.
"""
function vsfromtemplate(template::BasicPollStratTemplate, pollestrat::ElectorateStrategy, _::Float64)
    return template.basestrat(BasicPollSpec(template.method, pollestrat), template.stratargs...)
end
function vsfromtemplate(template::BasicWinProbTemplate, pollestrat::ElectorateStrategy, pollinguncertainty::Float64)
    return template.basestrat(
        WinProbSpec(BasicPollSpec(template.method, pollestrat), pollinguncertainty + template.extrauncertainty), template.stratargs...)
end
function vsfromtemplate(template::ApprovalWinProbTemplate, base_estrat::ElectorateStrategy, pollinguncertainty::Float64)
    estrat = ElectorateStrategy(base_estrat.flexible_strategists,
            [strat === bullet ? bullet : template.approvalstrat for strat in base_estrat.stratlist],
            base_estrat.stratusers)
    return template.basestrat(
        WinProbSpec(BasicPollSpec(approval, estrat),
                    pollinguncertainty + template.extrauncertainty), template.stratargs...)
end
function vsfromtemplate(template::CondorcetPollStratTemplate, pollestrat::ElectorateStrategy, _::Float64)
    return template.basestrat(CondorcetPollSpec(template.method, pollestrat), template.stratargs...)
end
function vsfromtemplate(template::RCVPollStratTemplate, pollestrat::ElectorateStrategy, _::Float64)
    return template.basestrat(RCVPollSpec(pollestrat, template.nwinners), template.stratargs...)
end
function vsfromtemplate(template::TieForTwoTemplate, pollestrat::ElectorateStrategy, pollinguncertainty::Float64)
    wps = WinProbSpec(BasicPollSpec(template.method, pollestrat), pollinguncertainty + template.extrauncertainty)
    return template.basestrat(TieForTwoSpec(wps), template.stratargs...)
end
function vsfromtemplate(template::CrudeTop3Template, pollestrat::ElectorateStrategy, pollinguncertainty::Float64)
    return template.basestrat(
        CrudeTop3Spec(BasicPollSpec(template.method, pollestrat), pollinguncertainty + template.extrauncertainty), template.stratargs...)
end
function vsfromtemplate(template::PositionalStratTemplate, pollestrat::ElectorateStrategy, _::Float64)
    ps = PositionSpec(template.pollspecfunc(template.method, pollestrat), template.finalnumcands, template.penultimatenumcands)
    return template.basestrat(ps, template.stratargs...)
end
function vsfromtemplate(template::CondorcetPositionalStratTemplate, pollestrat::ElectorateStrategy, _::Float64)
    s = CompMatPosSpec(template.pollspecfunc(template.method, pollestrat), template.numfrontrunners)
    return template.basestrat(s, template.stratargs...)
end
vsfromtemplate(template::VoterStrategy, _, _) = template

"""
    append_estrat_specs!(stratlist::Vector, userslist::Vector, estrat::ElectorateStrategy, beginindex::Int, endindex::Int)

Append the strategies and user totals from estrat for the voters from beginindex to endindex
"""
function append_estrat_specs!(stratlist::Vector, userslist::Vector,
                              estrat::ElectorateStrategy, beginindex::Int, endindex::Int)
    if endindex >= beginindex
        s, u = strats_and_users_in_range(estrat, beginindex, endindex)
        append!(stratlist, s)
        append!(userslist, u)
    end
end
append_estrat_specs!(::Vector, ::Vector, ::Nothing, ::Int, ::Int) = nothing #do nothing if there's no estrat

"""
    strats_and_users_in_range(estrat::ElectorateStrategy, beginindex, endindex)

Determine the strategies and numbers of voters using them between beginindex and endindex.

Returns (strats, user_ranges), where strats is a vector of voter strategies and
user_ranges is a vector of tuples of the minimum and maximum indicies of voters who use a strat.
"""
function strats_and_users_in_range(estrat::ElectorateStrategy, beginindex, endindex)
    #get to beginindex and find the strategy there
    strati = 1 #the current index within estrat.stratusers and estrat.stratlist
    while estrat.stratusers[strati][2] < beginindex
        strati += 1
    end
    user_ranges = Vector{Tuple{Int,Int}}([(beginindex, min(endindex, estrat.stratusers[strati][2]))])
    strats = Vector{VoterStrategy}([estrat.stratlist[strati]])
    #loop through the strategies used by voters in the interval
    while estrat.stratusers[strati][2] < endindex
        strati += 1
        push!(user_ranges, (estrat.stratusers[strati][1], min(endindex, estrat.stratusers[strati][2])))
        push!(strats, estrat.stratlist[strati])
    end
    return strats, user_ranges
end