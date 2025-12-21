struct FreeRidingModel <: VoterModel
    base_model::VoterModel
    methods_and_estrats::Vector
    nwinners::Int
    freerider_base_score::Int
    first_winner_position::Int
    extra_margin::Int
end

"""
Free ride by giving new_score to candidate.

For ranked methods, other scores are adjusted accordingly.
For cardinal methods, the base strategy is used with shifted utilities so that
at least one candidate receives the maximum score.
"""
struct FreeRide <: BlindStrategy
    base_strategy::BlindStrategy
    new_score::Int
    candidate::Int
end

function vote(voter, strat::FreeRide, method::CardinalMethod)
    adjusted_utils = [i == strat.candidate ? Statistics.median(voter) : voter[i] for i in eachindex(voter)]
    ballot = vote(adjusted_utils, strat.base_strategy, method)
    ballot[strat.candidate] = strat.new_score
    return ballot
end

function vote(voter, strat::FreeRide, method::RankedMethod)
    ballot = vote(voter, strat.base_strategy, method)
    base_score = ballot[strat.candidate]
    for (i, rank) in enumerate(ballot)
        if rank < base_score && rank >= strat.new_score
            ballot[i] += 1
        elseif rank > base_score && rank <= strat.new_score
            ballot[i] -= 1
        end
    end
    ballot[strat.candidate] = strat.new_score
    return ballot
end

function make_electorate(model::FreeRidingModel, nvot::Int, ncand::Int, seed::Int)
    rng = Random.Xoshiro(seed)
    passes_tests = false
    attempts = 0
    winner, voter_id, electorate = 0, 0, Matrix{Float64}(undef, ncand, nvot)
    while !passes_tests
        attempts += 1
        if attempts == 100
            println("Warning: Free riding electorate generation taking over 100 attempts.")
        end
        if attempts > 10000
            error("Failed to generate free riding electorate after 10000 attempts.")
        end
        passes_tests = true
        electorate = make_electorate(model.base_model, nvot, ncand, abs(rand(rng, Int)))
        ballots = castballots(electorate, model.methods_and_estrats[1][2][1], model.methods_and_estrats[1][1][1])
        winner = getwinners(ballots, model.methods_and_estrats[1][1][1], model.nwinners)[model.first_winner_position]
        voter_id = find_ballot_with_score(ballots, winner, model.freerider_base_score)
        if voter_id == 0
            passes_tests = false
        else
            passes_tests = check_electorate(electorate, model, winner, voter_id)
        end
    end
    order_freeriding_electorate!(electorate, winner, voter_id)
end

"""
    check_electorate(electorate::AbstractArray, model::FreeRidingModel, winner, freerider::Int)

Check that winner will win under all methods and strategies even with freeriding by freerider.
Returns true if so, false otherwise.
"""
function check_electorate(electorate::AbstractArray, model::FreeRidingModel, winner::Int, freerider::Int)
    for (methods, estrats) in model.methods_and_estrats
        for method in methods
            for estrat in estrats
                ballots = castballots(electorate, estrat, method)
                ballots[:, freerider] = vote(
                    electorate[:, freerider],
                    FreeRide(stratatindex(estrat, freerider), 0, winner),
                    method)
                if model.extra_margin > 0
                    #Currently nonfunctional
                    ncand = size(electorate, 1)
                    bullet_ballots = [i==c ? topballotmark(electorate[:, 1], method) : 0
                                        for i in 1:ncand, c in 1:ncand if c != winner]
                end
                if winner ∉ getwinners(ballots, method, model.nwinners)
                    return false
                end
            end
        end
    end
    return true
end

function order_freeriding_electorate!(electorate::AbstractArray, safe_winner::Int, voter_id::Int)
    electorate[:, 1], electorate[:, voter_id] = electorate[:, voter_id], electorate[:, 1]
    electorate[1, :], electorate[safe_winner, :] = electorate[safe_winner, :], electorate[1, :]
    return electorate
end

"""
    find_ballot_with_score(ballots::AbstractArray, candidate::Int, score::Int)

Find the index of a voter who casts a ballot with the given score for the given candidate.
Returns 0 if no such ballot exists.
"""
function find_ballot_with_score(ballots::AbstractArray, candidate::Int, score::Int)
    for i in 1:size(ballots, 2)
        if ballots[candidate, i] == score
            return i
        end
    end
    return 0
end

function make_free_riding_estrat(original_estrat::ElectorateStrategy)
    if original_estrat.stratusers[1][2] == 1
        new_stratlist = [FreeRide(original_estrat.stratlist[1], 0, 1); original_estrat.stratlist[2:end]]
        new_stratusers = original_estrat.stratusers
    else
        new_stratlist = [FreeRide(original_estrat.stratlist[1], 0, 1); original_estrat.stratlist[1:end]]
        new_stratusers = [(1,1); (2,original_estrat.stratusers[1][2]); original_estrat.stratusers[2:end]]
    end
    return ElectorateStrategy(1, new_stratlist, new_stratusers)
end

function free_riding_incentives(niter::Integer, vmodel::VoterModel, methods_strats_and_scores::Vector, nvot::Integer, ncand::Integer,
                                nwinners::Integer, vote_base_score::Integer, first_winner_position::Integer; iter_per_update::Integer=0)
    methods_and_estrats = [(ms, ss) for (ms, ss, _) in methods_strats_and_scores]
    vmodel = FreeRidingModel(vmodel, methods_and_estrats, nwinners, vote_base_score, first_winner_position, 0)
    esif_input_vector = [(methods, [make_free_riding_estrat(es) for es in estrats],
                            [FreeRide(estrats[1].stratlist[1], score, 1) for score in scores])
                          for (methods, estrats, scores) in methods_strats_and_scores]
    return calc_esif(niter, vmodel, esif_input_vector, nvot, ncand, nwinners=nwinners,
                      iter_per_update=iter_per_update)
end