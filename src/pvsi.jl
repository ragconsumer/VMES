#PVSI (Pivotal Voter Strategic Incentive) is not currently implemented.
#This file is a work in progress.

abstract type StrategicVoterSorter end

struct PositionalSorter <: StrategicVoterSorter
    help_pos
    hurt_pos
end

function calc_pvsi(niter::Integer, vmodel::VoterModel, methodsandstrats::Vector,
                   nvot::Integer, ncand::Integer,
                   correlatednoise::Number=0.1, iidnoise::Number=0, nwinners::Integer=1,
                   strategic_weight_function=(x -> 1))
    calc_stratmetric(PVSI(), niter, vmodel, methodsandstrats, nvot, ncand, correlatednoise,
                     iidnoise, nwinners, (strategic_weight_function,))
end

function innerstratmetric!(utiltotals, ::PVSI, electorate,
                           methods::Vector{<:VotingMethod},
                           strat_tuples::Vector, basestrat::ElectorateStrategy, 
                           baseballots, basewinnersets, infodict::Dict,
                           noisevector::Vector{Float64}, correlatednoise::Float64, iidnoise::Float64,
                           nwinners::Int, utindex::Int,
                           (strategic_weight_function, vse_reweight))
    strats, sorters = process_strat_tuples(strat_tuples)
    for (method_i, method) in enumerate(methods)
        for (strat_i, strat) in enumerate(strats)
            candtohelp, candtohurt = pvsitargets(sorters[strat_i], baseballots, noisevector)
            sortedvoterids = sortvoters(sorters[strat_i], electorate, candtohelp, candtohurt)
            newballots = deepcopy(baseballots)
            for i in sortedvotersids
                newballots[:, i] = vote(electorate[:, i], strat, method, infodict[infoused(strat)])
            end
            full_strategic_winners = getwinners(newballots, method, nwinners)
            if Set(full_strategic_winners) != Set(basewinnersets[method_i])
                pivotid, new_winners = find_pivotal_voter_and_outcome(
                    baseballots, newballots, sortedvoterids, basewinnersets[method_i], method, nwinners)
                pivotalvoter = electorate[:, pivotid]
                utiltotals[:, utindex] = (calc_utils(pivotalvoter, new_winners, nwinners)
                                        - calc_utils(pivotalvoter, basewinners, nwinners))
                if vse_reweight
                    utiltotals[:, utindex] ./= (maximum(pivotalvoter) - Statistics.mean(pivotalvoter))
                end
            end
            utindex += 1
        end
    end
end

function pvsitargets(sorter, ballots, noisevector)
end

function sortvoters(sorter, elecotrate, candtohelp, candtohurt)
end

function find_pivotal_voter_and_outcome(
    baseballots, newballots, sortedvoterids, basewinners, method, nwinners)
end