
"""
highfunc: A function that receives the voter as input and returns the high point of the initial scale
lowfunc: A function that receives the voter as input and returns the low point of the initial scale
highfraction: The high end of the actual scale that will be used compared to the inital points/
    highfraction = 1 means that the high point of the initial scale will be used,
    0 means the low point of the initial scale will be used
lowfraction: Same as highfraction, but for defining the low end.
    lowfraction must be less than highfraction, and it can be helpful to use negative numbers
roundingfunc: Takes the arguments(util, low, high, maxscore) and returns the score for a candidate with the giving util.
    low and high are the low and high ends of the scale, and maxscore is determined by the voting method.
"""
struct ArbitraryScoreScale <: BlindStrategy
    highfunc
    lowfunc
    highfraction
    lowfraction
    roundingfunc
end

struct ExpScale <: BlindStrategy
    exponent::Float64
    basescale::ArbitraryScoreScale
end

function mean_plus_std(itr)
    mean = Statistics.mean(itr)
    std = Statistics.stdm(itr, mean, corrected=false)
    return mean + std
end

"""
    equalmeasureforscore(util, low, high, maxscore)

Convert utilities to scores s.t. each score corresponds to an equal measure of possible utilities.
"""
function equalmeasureforscore(util, low, high, maxscore)
    util <= high || return maxscore
    util >= low || return 0
    return floor(Int, (maxscore + .999)*(util-low)/(high-low))
end

"""
    roundtoscore(util, low, high, maxscore)

Round utilies to the closest score on the scale.
"""
function roundtoscore(util, low, high, maxscore)
    util <= high || return maxscore
    util >= low || return 0
    round(Int, maxscore*(util-low)/(high-low))
end

topbotem = ArbitraryScoreScale(maximum, minimum, 1, 0, equalmeasureforscore)
topmeanem = ArbitraryScoreScale(maximum, Statistics.mean, 1, -1, equalmeasureforscore)
topmeanround = ArbitraryScoreScale(maximum, Statistics.mean, 1, -1, roundtoscore)

scorebystd(nstds) = ArbitraryScoreScale(mean_plus_std, Statistics.mean, nstds, -nstds, equalmeasureforscore)

ExpScale(exp) = ExpScale(exp, topmeanem)

"""
    vote(voter, strat::ArbitraryScoreScale, method::ScoringMethod)

Vote in accordance with the defined scale. The worst candidate always get a 0 and the best always gets the highest score.

See ArbitraryScaleScale
"""
function vote(voter, strat::ArbitraryScoreScale, method::ScoringMethod)
    maxutil, minutil = maximum(voter), minimum(voter)
    basehigh = strat.highfunc(voter)
    baselow = strat.lowfunc(voter)
    high = min(maxutil, baselow + strat.highfraction*(basehigh - baselow))
    low = max(minutil, baselow + strat.lowfraction*(basehigh - baselow))
    ballot = [strat.roundingfunc(util, low, high, method.maxscore) for util in voter]
    return ballot
end


"""
    vote(voter, strat::ExpScale, method::ScoringMethod)

Raise all utilities to the exponent (after scaling to a scale starting at 0) and then use the base scale.
"""
function vote(voter, strat::ExpScale, method::ScoringMethod)
    vote((voter .- minimum(voter)) .^ strat.exponent, strat.basescale, method)
end

vote(voter, ::HonestVote, method::ScoringMethod) = vote(voter, topmeanem, method)