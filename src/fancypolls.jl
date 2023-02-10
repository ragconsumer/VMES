struct StarPollSpec <: PollSpec
    method::STARVoting
    estrat::ElectorateStrategy
end

#Base.:(==)(x::StarPollSpec, y::StarPollSpec) = x.estrat == y.estrat
#Base.hash(s::StarPollSpec, h::UInt) = hash(s.estrat, hash(6148376, h))

function makepoll(ballots, spec::StarPollSpec, noisevector, iidnoise)
    ncand, nvot = size(ballots)
    unscaledr1 = tabulate(ballots, ScoreVoting(spec.method.maxscore))
    r1 = unscaledr1 .* pollscalefactor(spec.method, ballots)
    r1 += noisevector + iidnoise .* randn(ncand)
    clamp!(r1, 0, 1)
    finalists = top2(r1)
    unscaledr2 = star_runoff(ballots, finalists...)
    r2 = unscaledr2 ./ nvot
    r2total = sum(r2)
    r2[finalists] += noisevector[finalists] + iidnoise .* iidnoise*randn(2)
    r2 .*= r2total/sum(r2)
    clamp!(r2, 0, 1)
    return [r1 r2]
end

struct CondorcetPollSpec <: PollSpec
    method::CondorcetCompMatOnly
    estrat::ElectorateStrategy
end

function makepoll(ballots, spec::CondorcetPollSpec, noisevector, iidnoise)
    ncand, nvot = size(ballots)
    unscaledcompmat = pairwisematrix(ballots)
    compmat = unscaledcompmat ./ nvot
    for topcand in 1:ncand
        for leftcand in 1:ncand
            compmat[leftcand, topcand] += (noisevector[leftcand] - noisevector[topcand]
                                           + iidnoise*randn())
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

function makepoll(ballots, spec::RCVPollSpec, noisevector, iidnoise)
    optionally_fradulent_rcv_tabulation(
        ballots, spec.nwinners,
        spec.method.quota(size(ballots, 2), spec.nwinners)/size(ballots, 2),
        true, noisevector, iidnoise)
end
    
