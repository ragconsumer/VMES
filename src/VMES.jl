module VMES

export tabulate, getwinners
export plurality, pluralitytop2, approval, approvaltop2, star, irv, rcv, borda, minimax, rankedrobin
export vote
export hon, bullet, abstain, TopBottomThreshold, TopMeanThreshold, StdThreshold
export ExpScale, topbotem, topmeanem, scorebystd
export PluralityVA, ApprovalVA
export ElectorateStrategy, castballots


import Statistics
import Distributions
import Optim

include("vms.jl")
include("strategies.jl")
include("electoratestrategies.jl")
include("polls.jl")
include("fixedelectorates.jl")

end
