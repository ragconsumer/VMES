module VMES

export tabulate, winnersfromtab, getwinners
export plurality, pluralitytop2, approval, approvaltop2, score, star, irv, rcv, borda, minimax, rankedrobin
export vote
export hon, bullet, abstain, TopBottomThreshold, TopMeanThreshold, StdThreshold
export ExpScale, topbotem, topmeanem, scorebystd
export PluralityVA, ApprovalVA
export ElectorateStrategy, castballots
export make_electorate, ic, ImpartialCulture, DimModel, DCCModel, dcc, RepDrawModel
export calc_vses


import Statistics, Random
import Distributions
import Optim

include("vms.jl")
include("strategies.jl")
include("electoratestrategies.jl")
include("polls.jl")
include("votermodels.jl")
include("vse.jl")
include("fixedelectorates.jl")

end
