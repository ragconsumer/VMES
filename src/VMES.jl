module VMES

export tabulate, winnersfromtab, getwinners
export plurality, pluralitytop2, approval, approvaltop2, score, star, irv, rcv, borda, minimax, rankedrobin
export sss, allocatedscore, s5h, sssr, asr, s5hr, sssfr, asfr, s5hfr, asu, asur, mes
export vote
export hon, bullet, abstain, TopBottomThreshold, TopMeanThreshold, StdThreshold
export ExpScale, topbotem, topmeanem, scorebystd
export PluralityVA, ApprovalVA, BordaVA, IRVVA, STARVA
export ElectorateStrategy, castballots
export ESTemplate, BasicPollStratTemplate, esfromtemplate
export BasicWinProbTemplate, approvalvatemplate, pluralityvatemplate, starvatemplate, irvvatemplate, esfromtemplate
export make_electorate, ic, ImpartialCulture, DimModel, DCCModel, dcc, RepDrawModel
export calc_vses, calc_esif


import Statistics, Random
import Distributions
import Optim
using DataFrames

include("macros.jl")
include("vms.jl")
include("strategies.jl")
include("electoratestrategies.jl")
include("strat_templates.jl")
include("polls.jl")
include("fancypolls.jl")
include("votermodels.jl")
include("vse.jl")
include("esif.jl")
include("fixedelectorates.jl")
include("metrictools.jl")

end
