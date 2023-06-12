struct Top2PollSpec <: PollSpec
    method::Top2Method
    estrat::ElectorateStrategy
end

function makepoll(ballots, spec::Top2PollSpec, noisevector, iidnoise, rng=Random.Xoshiro())
    ncand, nvot = size(ballots, 1)÷2, size(ballots, 2)
    unscaledr1 = tabulate(ballots[1:ncand, :], spec.method.basemethod)
    r1 = unscaledr1 .* pollscalefactor(spec.method.basemethod, ballots)
    r1 += noisevector + iidnoise .* randn(rng, ncand)
    clamp!(r1, 0, 1)
    finalists = top2(r1)
    tally1, tally2 = 0, 0
    for ranking in eachslice(view(ballots, ncand+1:2ncand, :),dims=2)
        if ranking[finalists[1]] > ranking[finalists[2]]
            tally1 += 1
        elseif ranking[finalists[1]] < ranking[finalists[2]]
            tally2 += 1
        end
    end
    r2 = zeros(Float64, ncand)
    r2[finalists[1]] = tally1/nvot + noisevector[finalists[1]] + iidnoise*randn(rng)
    r2[finalists[2]] = tally2/nvot + noisevector[finalists[2]] + iidnoise*randn(rng)
    return [r1 r2]
end

struct STARPollSpec <: PollSpec
    method::STARVoting
    estrat::ElectorateStrategy
end

#Base.:(==)(x::StarPollSpec, y::StarPollSpec) = x.estrat == y.estrat
#Base.hash(s::StarPollSpec, h::UInt) = hash(s.estrat, hash(6148376, h))

function makepoll(ballots, spec::STARPollSpec, noisevector, iidnoise, rng=Random.Xoshiro())
    ncand, nvot = size(ballots)
    unscaledr1 = tabulate(ballots, ScoreVoting(spec.method.maxscore))
    r1 = unscaledr1 .* pollscalefactor(spec.method, ballots)
    r1 += noisevector + iidnoise .* randn(rng, ncand)
    clamp!(r1, 0, 1)
    finalists = top2(r1)
    unscaledr2 = star_runoff(ballots, finalists...)
    r2 = unscaledr2 ./ nvot
    r2total = sum(r2)
    r2[finalists] += noisevector[finalists] + iidnoise .* iidnoise*randn(rng, 2)
    r2 .*= r2total/sum(r2)
    clamp!(r2, 0, 1)
    return [r1 r2]
end

struct CondorcetPollSpec <: PollSpec
    method::CondorcetCompMatOnly
    estrat::ElectorateStrategy
end

function makepoll(ballots, spec::CondorcetPollSpec, noisevector, iidnoise, rng=Random.Xoshiro())
    ncand, nvot = size(ballots)
    unscaledcompmat = pairwisematrix(ballots)
    compmat = unscaledcompmat ./ nvot
    for topcand in 1:ncand
        for leftcand in 1:ncand
            compmat[leftcand, topcand] += (noisevector[leftcand] - noisevector[topcand]
                                           + iidnoise*randn(rng))
        end
    end
    clamp!(compmat, 0, 1)
    return tabulatefromcompmat(compmat, spec.method)
end

struct RCVPollSpec <: PollSpec
    method::RankedChoiceVoting
    estrat::ElectorateStrategy
    nwinners::Int
end

RCVPollSpec(estrat::ElectorateStrategy, nwinners=1) = RCVPollSpec(rcv, estrat, nwinners)
RCVPollSpec(method::RankedChoiceVoting, estrat::ElectorateStrategy) = RCVPollSpec(rcv, estrat, 1)

function makepoll(ballots, spec::RCVPollSpec, noisevector, iidnoise, rng=Random.Xoshiro())
    optionally_fradulent_rcv_tabulation(
        ballots, spec.nwinners,
        spec.method.quota(size(ballots, 2), spec.nwinners)/size(ballots, 2),
        true, noisevector, iidnoise, rng)
end
    
