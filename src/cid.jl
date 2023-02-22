include("cidtools.jl")

"""
    calc_cid(niter::Int,
                  vmodel::VoterModel,
                  methods::Vector{<:VotingMethod},
                  estrats::Vector{ElectorateStrategy},
                  nbucket::Int, ncand::Int, nwinners::Int=1,
                  votersperbucket::Int=3, util_change::Float64=0.05,
                  sorter=normalizedUtilDeviation, pollafterpert=false,
                  which_changes=(true, true, true, true),
                  correlatednoise::Float64=0.1, iidnoise::Float64=0.0)

Determine the Candidate Incentive Distributions of the given methods and estrats.
"""
function calc_cid(niter::Int,
                  vmodel::VoterModel,
                  methods::Vector{<:VotingMethod},
                  estrats::Vector{ElectorateStrategy},
                  nbucket::Int, ncand::Int, nwinners::Int=1,
                  votersperbucket::Int=3, util_change::Float64=0.05,
                  sorter=normalizedUtilDeviation, pollafterpert=false,
                  which_changes=(true, true, true, true),
                  correlatednoise::Float64=0.1, iidnoise::Float64=0.0)
    ITER_PER_SUM = 1000
    nmethod = length(methods)
    entries = Array{Int, 3}(undef, nmethod, nbucket, niter)
    counts = zeros(Int, nmethod, nbucket)
    iterleft = niter
    for _ in 1:ceil(Int, niter/ITER_PER_SUM)
        Threads.@threads for i in 1:min(iterleft, ITER_PER_SUM)
            entries[:, :, i] = one_cid_iter(vmodel, methods, estrats, nbucket, ncand, nwinners,
                votersperbucket, util_change, sorter, pollafterpert, which_changes,
                correlatednoise, iidnoise)
        end
        iterleft -= ITER_PER_SUM
        counts += dropdims(sum(entries, dims=3), dims=3)
    end
    totalincentives = sum(counts, dims=2)
    cids = Matrix{Float64}(undef, nmethod, nbucket)
    df = DataFrame()
    for m_i in eachindex(methods, estrats), b_i in 1:nbucket
        cids[m_i, b_i] = counts[m_i, b_i]*nbucket/totalincentives[m_i]
    end
    df[!, :Method] = reduce(vcat, repeat([method], nbucket) for method in methods)
    df[!, "Electorate Strategy"] = reduce(vcat, repeat([estrat], nbucket) for estrat in estrats)
    df[!, :Bucket] = repeat(1:nbucket, nmethod)
    df[!, :CID] = reshape(transpose(cids), nbucket*nmethod)
    df[!, :Total] = reshape(transpose(counts), nbucket*nmethod)
    df[!, "Total Buckets"] .= nbucket
    df[!, "Voters per Bucket"] .= votersperbucket
    df[!, "ncand"] .= ncand
    df[!, "Utility Change"] .= util_change
    df[!, "Polling Mode"] .= pollafterpert ? "After Perturbation" : "Once per iteration"
    df[!, "Sorter"] .= sorter
    (losewinplus, winloseminus, losewinminus, winloseplus) = which_changes
    df[!, :LWP] .= losewinplus
    df[!, :WLM] .= winloseminus
    df[!, :LWM] .= losewinminus
    df[!, :WLP] .= winloseplus
    df[!, "Correlated Noise"] .= correlatednoise
    df[!, "IID Noise"] .= iidnoise
    df[!, "Iterations"] .= niter
    df[!, "Voter Model"] .= [vmodel]
    return df
end

function calc_cid(niter::Int,
                  vmodel::VoterModel,
                  methods::Vector{<:VotingMethod},
                  estrats::Vector,
                  nbucket::Int, ncand::Int, nwinners::Int=1,
                  votersperbucket::Int=3, util_change::Float64=0.1,
                  sorter=normalizedUtilDeviation, pollafterpert=false,
                  which_changes=(true, true, true, true),
                  correlatednoise::Float64=0.1, iidnoise::Float64=0.0)
    calc_cid(niter, vmodel, methods,
             [esfromtemplate(template, hypot(correlatednoise, iidnoise)) for template in estrats],
             nbucket, ncand, nwinners, votersperbucket, util_change, sorter,
             pollafterpert, which_changes, correlatednoise, iidnoise)
end

"""
    one_cid_iter(vmodel::VoterModel,
                      methods::Vector{<:VotingMethod},
                      estrats::Vector{ElectorateStrategy},
                      nbucket::Int, ncand::Int, nwinners::Int=1,
                      votersperbucket::Int=3, util_change::Float64=0.05,
                      sorter=nothing, pollafterpert=false, which_changes=false,
                      correlatednoise::Float64=0.1, iidnoise::Float64=0.0)

Determine how many candidates are incentivized to appeal to each bucket of voters.
"""
function one_cid_iter(vmodel::VoterModel,
                      methods::Vector{<:VotingMethod},
                      estrats::Vector{ElectorateStrategy},
                      nbucket::Int, ncand::Int, nwinners::Int=1,
                      votersperbucket::Int=3, util_change::Float64=0.1,
                      sorter=normalizedUtilDeviation, pollafterpert=false,
                      which_changes=(true, true, true, true),
                      correlatednoise::Float64=0.1, iidnoise::Float64=0.0)
    electorate = make_electorate(vmodel, nbucket*votersperbucket, ncand)
    nsettings = length(methods)
    #create a noise vector for the entire iteration so that polling bias doesn't change
    #when utilities are perturbed. The iid noise can still be different though.
    noisevector = correlatednoise .* randn(size(electorate,1))
    infodict = administerpolls(electorate, (estrats, methods), noisevector, iidnoise)
    baseballotarrays = castballots.((electorate,), estrats, methods, (infodict,))
    basewinnersets = getwinners.(baseballotarrays, methods, nwinners)
    incentivecounts = zeros(Int, nsettings, nbucket)
    for candi in 1:ncand
        #buckets[:,i] gives the indicies of all voters in the ith bucket
        buckets = assignbuckets(electorate, candi, nbucket, votersperbucket, sorter)
        for bucketi in 1:nbucket
            bucket = buckets[:,bucketi]
            voters = electorate[:, bucket]
            for sign in [1, -1]
                voters = electorate[:, bucket]
                perturbedvoters = copy(voters)
                perturbedvoters[candi, :] .+= sign*util_change
                if pollafterpert
                    innercidnewpolls!(incentivecounts, candi,
                        perturbedvoters, bucketi, bucket,
                        electorate, basewinnersets, noisevector, iidnoise,
                        methods, estrats,
                        nwinners, sign, which_changes)
                else
                    innercidbasic!(incentivecounts, candi,
                        perturbedvoters, bucketi, bucket,
                        baseballotarrays, basewinnersets, infodict, methods, estrats,
                        nwinners, sign, which_changes)
                end
            end
        end
    end
    return incentivecounts
end

"""
    innercidbasic!(incentivecounts, cand,
                        perturbedvoters, bucketindex, voterindices,
                        baseballots, basewinnersets, infodict, 
                        methods, estrats,
                        sign, which_changes)

Have the perturbed voters vote again using old polls and update incentivecounts
"""
function innercidbasic!(incentivecounts::Matrix{Int}, cand::Int,
                        perturbedvoters, bucketindex::Int, voterindices::Vector{Int},
                        baseballotarrays::Vector, basewinnersets::Vector, infodict::Dict, 
                        methods::Vector{<:VotingMethod}, estrats::Vector{ElectorateStrategy},
                        nwinners::Int, sign::Int, which_changes::NTuple{4, Bool})
    for i in eachindex(methods, estrats)
        newballots = cidrevote(
            perturbedvoters, voterindices, estrats[i],
            methods[i], infodict)
        ballots = baseballotarrays[i]
        oldballots = ballots[:, voterindices]
        ballots[:, voterindices] = newballots
        new_winners = getwinners(ballots, methods[i], nwinners)
        updateincentivecounts!(incentivecounts, i, bucketindex, new_winners, basewinnersets[i],
                                cand, sign, which_changes)
        ballots[:, voterindices] = oldballots
    end
end

"""
    innercidnewpolls!(incentivecounts, cand,
                           perturbedvoters, bucketindex, voterindices,
                           electorate, basewinnersets, noisevector,
                           methods, estrats,
                           sign, which_changes)

Redo polling with perturbed voters, repeat the election, and update incentivecounts.
"""
function innercidnewpolls!(incentivecounts::Matrix{Int}, cand::Int,
                           perturbedvoters, bucketindex::Int, voterindices::Vector{Int},
                           electorate, basewinnersets::Vector, noisevector::Vector, iidnoise::Float64,
                           methods::Vector{<:VotingMethod}, estrats::Vector{ElectorateStrategy},
                           nwinners::Int, sign::Int, which_changes::NTuple{4, Bool})
    basevoters = electorate[:, voterindices]
    electorate[:, voterindices] = perturbedvoters
    infodict = administerpolls(
        electorate, (estrats, methods), noisevector, iidnoise)
    ballots = castballots.((electorate,), estrats, methods, (infodict,))
    for i in eachindex(methods)
        new_winners = getwinners(ballots[i], methods[i], nwinners)
        updateincentivecounts!(incentivecounts, i, bucketindex, new_winners, basewinnersets[i],
                                cand, sign, which_changes)
    end
    electorate[:, voterindices] = basevoters
end

function assignbuckets(electorate, cand::Int, nbucket::Int, votersperbucket::Int, sorter)
    numbered_voters = [(i, voter) for (i, voter) in enumerate(eachslice(electorate,dims=2))]
    sort!(numbered_voters, by=(((i,v),)->sorter(v, cand)))
    sorted_indices = [i for (i, _) in numbered_voters]
    return reshape(sorted_indices, votersperbucket, nbucket)
end

"""
    cidrevote(perturbedvoters, voterindices, estrat, method, infodict)

Create new ballots for the perturbed voters.
"""
function cidrevote(perturbedvoters, voterindices, estrat, method, infodict)
    ncand, nvot = size(perturbedvoters)
    newballots = Matrix{ballotmarktype(method)}(
                        undef, getballotsize(method,ncand), nvot)
    for i in 1:nvot
        strat = stratatindex(estrat, voterindices[i])
        info_for_strat = infodict[info_used(strat, method)]
        newballots[:, i] = vote(
            perturbedvoters[:,i], strat, method, info_for_strat)
    end
    return newballots
end

"""
    updateincentivecounts!(incentivecounts, settingindex, bucketindex, new_winners, old_winners,
                                cand, sign, (losewinplus, winloseminus, losewinminus, winloseplus))

Update incentivecoutns for the given indices based the changed performance of cand.

# Arguments
`losewinplus::Boolean`: Specifies whether to include candidates who lose in the base election,
    have their support increased, and win in the new election.
`winloseminus::Boolean`: Specifies whether to include candidates who win in the base election,
    have their support decreased, and lose in the new election.
`losewinminus::Boolean`: Specifies whether to include candidates who lose in the base election,
    have their support decreased, and win in the new election.
`winloseplus::Boolean`: Specifies whether to include candidates who win in the base election,
    have their support plus, and lose in the new election.

The latter two are for capturing the effects of non-monotonicity.
"""
function updateincentivecounts!(incentivecounts, settingindex, bucketindex, new_winners, old_winners,
                                cand, sign, (losewinplus, winloseminus, losewinminus, winloseplus))
    if cand ∈ new_winners && cand ∉ old_winners
        if sign == 1 && losewinplus
            incentivecounts[settingindex, bucketindex] += 1
        elseif sign == -1 && losewinminus
            incentivecounts[settingindex, bucketindex] -= 1
        end
    elseif cand ∉ new_winners && cand ∈ old_winners
        if sign == -1 && winloseminus
            incentivecounts[settingindex, bucketindex] += 1
        elseif sign == 1 && winloseplus
            incentivecounts[settingindex, bucketindex] -= 1
        end
    end
end