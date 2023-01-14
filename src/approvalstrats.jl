import Statistics

vote(voter, ::HonestVote, method::ApprovalMethod) = vote(voter, TopMeanthreshold(0.4), method)

"""
threshold should be in (0, 1].
"""
struct TopBottomThreshold <: BlindStrategy
    threshold::Float64
end

"""
    vote(voter, strategy::TopBottomThreshold, method::CardinalMethod)

Linearly rescale utilities s.t. the best candidate is 1 and the worst is 0,
then vote for every candidate with a utility of at least the threshold.
"""
function vote(voter, strategy::TopBottomThreshold, method::CardinalMethod)
    top, bottom = maximum(voter), minimum(voter)
    [util - bottom >= strategy.threshold*(top-bottom) ? topballotmark(voter, method) : 0
        for util in voter]
end

struct TopMeanThreshold <: BlindStrategy
    threshold::Float64
end

"""
    vote(voter, strategy::TopMeanThreshold, method::CardinalMethod)

    Linearly rescale utilities s.t. the best candidate is 1 and the mean is 0,
    then vote for every candidate with a utility of at least the threshold.
"""
function vote(voter, strategy::TopMeanThreshold, method::CardinalMethod)
    top, mean = maximum(voter), Statistics.mean(voter)
    [util - mean >= strategy.threshold*(top-mean) ? topballotmark(voter, method) : 0
        for util in voter]
end

struct StdThreshold <: BlindStrategy
    threshold::Float64
end

"""
    vote(voter, strategy::TopMeanThreshold, method::CardinalMethod)

    Vote for every candidate whose utility is at least threhsold standard deviations above the mean.
    Also votes for the best candidate no matter what.
"""
function vote(voter, strategy::StdThreshold, method::CardinalMethod)
    mean = Statistics.mean(voter)
    std = Statistics.std(voter)
    top = maximum(voter)
    [util==top || util - mean >= strategy.threshold*std ? topballotmark(voter, method) : 0
        for util in voter]
end