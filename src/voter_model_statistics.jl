function condorcet_cycle_frequency(niter::Int,
                                   vmodel::VoterModel,
                                   nvot::Int,
                                   ncand::Int)
    count = 0
    for _ in 1:niter
        electorate = make_electorate(vmodel, nvot, ncand)
        if hascondorcetcycle(electorate)
            count += 1
        end
    end
    return count/niter
end

function hascondorcetcycle(ballots_or_electorate)
    compmat = pairwisematrix(ballots_or_electorate)
    ncand = size(compmat,1)
    return !any(all(compmat[c1,c2] >= compmat[c2,c1] for c2 in 1:ncand) for c1 in 1:ncand)
end