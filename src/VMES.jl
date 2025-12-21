module VMES

export tabulate, winnersfromtab, getwinners
export plurality, pluralitytop2, approval, approvaltop2, score, star, irv, rcv, buirv, borda, minimax, rankedrobin
export smithirv, smithplurality, smithscore
export sss, allocatedscore, s5h, sssr, asr, s5hr, sssfr, asfr, s5hfr, asu, asur, mes, mesdroop, scv, scvr, blockstar
export stvminimax, stv, sntv, LimitedVoting
export spav, spav_sl, spav_msl
export vote
export hon, bullet, abstain, TopBottomThreshold, TopMeanThreshold, StdThreshold, smartblindstar, SmartBlindSTAR
export ExpScale, topbotem, topmeanem, topmeanround, scorebystd, HonLimRankings, HonLimTiedRankings
export PluralityVA, ApprovalVA, BordaVA, IRVVA, STARVA
export ElectorateStrategy, castballots
export ESTemplate, BasicPollStratTemplate, esfromtemplate
export BasicWinProbTemplate, approvalvatemplate, pluralityvatemplate, starvatemplate, irvvatemplate, esfromtemplate
export make_electorate, ic, ImpartialCulture, DimModel, DCCModel, dcc, RepDrawModel, BaseQualityNoiseModel, ExpPreferenceModel
export calc_vses, calc_primary_vse, calc_esif, calc_cid, calc_eve
export collect_strat_stats, influence_cdf, distance_from_uniform
export util_pert_on_score_stats, total_variation_distance_from_uniform, earth_movers_distance_from_uniform
export calc_cvii, bulletinstruction, abstaininstruction, AssistInstruction, CopyNaturalSupporterInstruction, BulletMixInstruction
export ArbitrarySelector, OnePositionalSelector, TwoPositionalSelectorOneWay, TwoPositionalSelectorTwoWay
export instruct_votes, select_instructors_and_trackees, num_trackees
export FreeRidingModel, FreeRide, free_riding_incentives


import Statistics, Random
import Distributions, LogExpFunctions
import Optim
using Gadfly
using DataFrames

include("macros.jl")
include("vms.jl")
include("strategies.jl")
include("electoratestrategies.jl")
include("instructionstrats.jl")
include("instructionselectors.jl")
include("polls.jl")
include("fancypolls.jl")
include("strat_templates.jl")
include("votermodels.jl")
include("freeriding.jl")
include("strat_statistics.jl")
include("agreementmatrix.jl")
include("vse.jl")
include("primaryvse.jl")
include("strategicmetrics.jl")
include("esif.jl")
include("eve.jl")
#include("pvsi.jl")
include("cid.jl")
include("fixedelectorates.jl")
include("metrictools.jl")
include("charts.jl")
include("voter_model_statistics.jl")
include("cvii.jl")
include("instructiontemplates.jl")

end
