module VMES

export tabulate, winnersfromtab, getwinners
export plurality, pluralitytop2, approval, approvaltop2, score, star, irv, rcv, borda, minimax, rankedrobin
export sss, allocatedscore, s5h, sssr, asr, s5hr, sssfr, asfr, s5hfr, asu, asur, mes, mesdroop
export vote
export hon, bullet, abstain, TopBottomThreshold, TopMeanThreshold, StdThreshold
export ExpScale, topbotem, topmeanem, topmeanround, scorebystd
export PluralityVA, ApprovalVA, BordaVA, IRVVA, STARVA
export ElectorateStrategy, castballots
export ESTemplate, BasicPollStratTemplate, esfromtemplate
export BasicWinProbTemplate, approvalvatemplate, pluralityvatemplate, starvatemplate, irvvatemplate, esfromtemplate
export make_electorate, ic, ImpartialCulture, DimModel, DCCModel, dcc, RepDrawModel, BaseQualityNoiseModel
export calc_vses, calc_esif, calc_cid, collect_strat_stats, influence_cdf, distance_from_uniform
export util_pert_on_score_stats, total_variation_distance_from_uniform, earth_movers_distance_from_uniform


import Statistics, Random
import Distributions, LogExpFunctions
import Optim
using Gadfly
using DataFrames

include("macros.jl")
include("vms.jl")
include("strategies.jl")
include("electoratestrategies.jl")
include("strat_templates.jl")
include("polls.jl")
include("fancypolls.jl")
include("votermodels.jl")
include("strat_statistics.jl")
include("vse.jl")
include("strategicmetrics.jl")
include("esif.jl")
#include("pvsi.jl")
include("cid.jl")
include("fixedelectorates.jl")
include("metrictools.jl")
include("charts.jl")

end
