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
    clampedpolls = clamp.(polls, 0.01, 0.99)
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