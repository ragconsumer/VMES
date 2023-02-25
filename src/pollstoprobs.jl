"""
    simpleprobs(polls, uncertainty)

Calculate a crude estimate of a candidate winning an election.
"""
function simpleprobs(polls, uncertainty)
    unnormalizedprobs = [exp(p/uncertainty) for p in polls]
    return unnormalizedprobs ./ sum(unnormalizedprobs)
end

"""
    betaprobs(polls, uncertainty)

Calculate a more sophisticated estimate of the probability of each candidate winning.

The uncertainty is the standard deviation (of the mean) of the polls.

Algorithm originally written in Python by Jameson Quinn.
"""
function betaprobs(polls, uncertainty)
    clampedpolls = reshape(clamp.(polls, 0.01, 0.99), length(polls))
    betasize = margintobetasize(uncertainty)
    betas = [Distributions.Beta(betasize*p, betasize*(1-p)) for p in clampedpolls]
    return multi_beta_probs_of_highest(betas)
end

margintobetasize(sigma) = (1 / 4sigma^2) - 1

function multi_beta_cdf_loss(betas, x)
    p = prod(Distributions.cdf(beta, x) for beta in betas) #need to have a package that actually gives betacdf
    return (0.5-p)^2
end

function multi_beta_probs_of_highest(betas)
    res = Optim.optimize(x -> multi_beta_cdf_loss(betas, x[1]), [0.5])
    medianofmax = Optim.minimizer(res)[1]
    probs = [Distributions.ccdf(beta, medianofmax) for beta in betas]
    return probs ./ sum(probs)
end

"""
    tiefortwoprob(winprobs)

Estimate the probability of each candidate being in a tie for second place.

Algorithm designed by Jameson Quinn.
"""
function tiefortwoprob(winprobs)
    EXP = 2
    logprobs = clamp.(log.(winprobs), -1e9, 0)
    logconv = clamp.(log.(1 .- winprobs), -1e9, 0)
    unnormalized_log = [logprobs[i] + logconv[i] + (LogExpFunctions.logsumexp([
        LogExpFunctions.logsumexp([(logprobs[j] + logprobs[k])*EXP for (k, z) in enumerate(winprobs) if i != k != j])
                for (j, y) in enumerate(winprobs) if i != j])
            - LogExpFunctions.logsumexp([logprobs[j]*EXP for (j, y) in enumerate(winprobs) if i != j]))/EXP
        for (i, _) in enumerate(winprobs)]
    unnormalized = exp.(unnormalized_log .- maximum(unnormalized_log))
    normFactor = sum(unnormalized)
    return [float(u/normFactor) for u in unnormalized]
end

"""
    crudetop3probs(polls, uncertainty)

Crudely estimates the probability of each candidate in finishing in the top three.

Treats the the three top-polling candidates as being equally likely to finish in the top three.
"""
function crudetop3probs(polls::Vector, uncertainty::Float64)
    UNCERTAINTY_FACTOR = sqrt(2)
    thirdplace = sort(polls, rev=true)[3]
    clampedpolls = clamp.(polls, 0, thirdplace)
    unnormalized_probs = [Distributions.ccdf(Distributions.Normal(poll, uncertainty*UNCERTAINTY_FACTOR),thirdplace)
                          for poll in clampedpolls]
    return unnormalized_probs .* (3/sum(unnormalized_probs))
end

crudetop3probs(polls::Matrix, uncertainty::Float64) = crudetop3probs(dropdims(polls, dims=2), uncertainty)