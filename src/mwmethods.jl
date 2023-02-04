"""
    droop(nvot, nwinners)

Calcuate the Droop quota.
"""
droop(nvot, nwinners) = Int(floor(nvot/(nwinners+1))) + 1
"""
    exacthare(nvot, nwinners)

Calculate the exact Hare quota
"""
exacthare(nvot, nwinners) = nvot/nwinners

"Single Nontransferable Vote (limited voting)"
struct SNTV <: PluralityMethod
end
@namevm sntv = SNTV()

struct RCV <: RankedChoiceVoting
    quota
end
InstantRunoffVoting = RankedChoiceVoting #Single-winner is implemented as a special case of STV.
SingleTransferableVote = RankedChoiceVoting
@namevm rcv = RCV(droop)
irv = rcv

"""
    rcv_resort!(piles, allballots, indiciestosort, candsleft)

Sort the indicies into the piles for the remaining candidates.
"""
function rcv_resort!(piles, allballots, indiciestosort, candsleft)
    for i in indiciestosort
        vote, bestRank = 0, 0
        for c in candsleft
            if allballots[c, i] > bestRank
                vote, bestRank = c, allballots[c, i]
            end
        end
        if vote != 0
            push!(piles[vote], i)
        end
    end
end

"""
    tabulate(ballots, method::RCV, nwinners)

    Tabulate an STV or IRV election.
    Weighted Inclusive Gregory, with candidates who achieve the quota skipped for transfers.
"""
function tabulate(ballots, method::RCV, nwinners::Int)
    ncands = size(ballots, 1)
    nvot = size(ballots, 2)
    quota = method.quota(nvot, nwinners)
    piles = [Set{Int}() for _ in 1:ncands]
    weights = ones(Float64, size(ballots, 2))
    candsleft = BitSet(1:ncands)
    candselected = Set{Int}()
    tosort = 1:nvot
    nelected = 0
    results = zeros(Float64, ncands, 0)
    while nelected < nwinners && nelected + length(candsleft) > nwinners
        #stop if you've elected enough candidates or if only nwinners candidates remain un-eliminated.
        rcv_resort!(piles, ballots, tosort, candsleft)
        resultline = [c in candsleft ? sum([weights[i] for i in piles[c]], init=0) : c in candselected ? float(quota) : 0.0 for c in 1:ncands]
        results = hcat(results, resultline)
        new_winners = [c for c in 1:ncands if resultline[c] >= quota && !(c in candselected)]
        nelected += length(new_winners)
        if isempty(new_winners) #transfer excess from winners
            fewestvotes = minimum(resultline[c] for c in candsleft)
            loser = maximum(cand for cand in filter(
                c -> resultline[c]==fewestvotes, candsleft))
            tosort = piles[loser]
            delete!(candsleft, loser)
        elseif nelected < nwinners #transfer from eliminated candidates; stop tabulation if further transfers are superfluous.
            tosort = Set()
            for c in new_winners
                push!(candselected, c)
                union!(tosort, piles[c])
                delete!(candsleft,c)
                weightfactor = (resultline[c] - quota)/resultline[c]
                for i in piles[c]
                    weights[i] *= weightfactor
                end
            end
        end
    end
    return results
end

tabulate(ballots, method::RCV) = tabulate(ballots, method::RCV, 1)

abstract type ScorePR <: ScoringMethod end

"""
Template that handles Allocated Score, Sequentially Spent Score, Sequential Monroe,
and variants involving runoffs, different methods of reweighting ballots, and quotas.

maxscore: The maximum score allowed on ballots.
quota: The quota function (nvot, ncand) -> quotasize
mainroundresults: (ballots, weights, electedcands) -> resultvector
use_runoffs: (cands_still_to_be_elected) -> true/false
runoffs: (results from mainroundresults, ballots, weights) -> runoffresultvector
reweight!: (weights, method, ballots, new_winner, electedcands) -> (); modifies weights
weightgiven: (score, weight, method) -> number in [1,0] that is the total weight offered
    by the voter to help a candidate with the given score
quotapriority: Function that gives the priority for putting a ballot in the quota.
    (score, weight) -> score
"""
struct ScorePRTemplate <: ScorePR
    maxscore::Int
    quota
    mainroundresults
    use_runoffs
    runoffs
    reweight!
    weightgiven
    quotapriority
end

"""
    weightedscorecount(ballots, weights, _)

A round of score voting with weighted ballots.
"""
function weightedscorecount(ballots, weights, _)
    [sum(ballots[c, v]*weights[v] for v in eachindex(weights)) for c in 1:size(ballots,1)]
end

norunoffs(::Int) = false
allrunoffs(::Int) = true
runofflastround(candsleft::Int) = candsleft == 1

function weightedstarrunoff(prev_results, ballots, weights)
    finalist1, finalist2 = top2(prev_results)
    tallies = zeros(Float64, size(ballots, 1))
    for v in 1:size(ballots,2)
        if ballots[finalist1, v] > ballots[finalist2, v]
            tallies[finalist1] += weights[v]
        elseif ballots[finalist1, v] < ballots[finalist2, v]
            tallies[finalist2] += weights[v]
        end
    end
    return tallies
end

#weightgiven options
allweight(_, weight, _) = weight
sssweight(score, weight, method) = weight*score/method.maxscore

#quota priority options
justscore(score, weight) = score
weightedpriority(score, weight) = score*weight

"""
    sssreweight!(weights::Vector{Float64}, method::VotingMethod, ballots::Matrix, new_winner::Int, nwinners::Int, _)

Reweight in accordance with Sequentially Spent Score.
"""
function sssreweight!(weights::Vector{Float64}, method::VotingMethod, ballots::Matrix, new_winner::Int, nwinners::Int, _)
    nvot = size(ballots, 2)
    quota = method.maxscore*method.quota(nvot, nwinners)
    winnertotal = sum(ballots[new_winner, i]*weights[i] for i in 1:nvot)
    winnersurplus = max(winnertotal - quota, 0)
    weightlossfactor = (1 - winnersurplus/winnertotal)/method.maxscore
    for i in 1:nvot
        weights[i] *= (1 - weightlossfactor*method.quotapriority(ballots[new_winner, i], weights[i]))
    end
end

"""
    asreweight!(weights::Vector{Float64}, method::VotingMethod, ballots::Matrix, new_winner::Int, nwinners::Int, _)

    Reweight in accordance with Allocated Score or a variant like S5H.
"""
function asreweight!(weights::Vector{Float64}, method::VotingMethod, ballots::Matrix, new_winner::Int, nwinners::Int, _)
    nvot = size(ballots, 2)
    #wsi = weight, score, index
    wsis = [(method.weightgiven(ballots[new_winner, i], weights[i], method),
            method.quotapriority(ballots[new_winner, i], weights[i]),
            i)
            for i in eachindex(weights)]
    sort!(wsis, by= wsi -> -wsi[2])
    total = wsis[1][1]
    quota = method.quota(nvot, nwinners)
    quota_edge = 1
    while total < quota && quota_edge < nvot && wsis[quota_edge+1][2] > 0
        quota_edge += 1
        total += wsis[quota_edge][1]
    end
    #If there isn't a full quota, use all ballots with a positive score
    if total < quota
        for i in 1:quota_edge
            weights[wsis[i][3]] -= wsis[i][1]
        end
        return
    end
    #Otherwise, use fractional surplus handling.
    edgescore = wsis[quota_edge][2]
    edgetotal = wsis[quota_edge][1]
    fulltotal = total - edgetotal
    edgestart, edgefinish = quota_edge, quota_edge
    while edgestart > 1 && wsis[edgestart-1][2] ≈ edgescore
        edgestart -= 1
        fulltotal -= wsis[edgestart][1]
        edgetotal += wsis[edgestart][1]
    end
    while edgefinish < nvot && wsis[edgefinish+1][2] ≈ edgescore
        edgefinish += 1
        edgetotal += wsis[edgefinish][1]
    end
    #Reduce ballot weight
    edgefraction = (quota - fulltotal)/edgetotal
    for i in 1:edgestart-1
        weights[wsis[i][3]] -= wsis[i][1]
    end
    for i in edgestart:edgefinish
        weights[wsis[i][3]] -= wsis[i][1]*edgefraction
    end
end
    

"""
    addwinner!(electedcands, totals)

Add the winner determined by totals to electedcands and return the winner's result
"""
function addwinner!(electedcands::Set{Int}, totals::Vector{<:Real})
    winner, winnerscore = 0, -1
    for i in eachindex(totals)
        if totals[i] > winnerscore && i ∉ electedcands
            winner, winnerscore = i, totals[i]
        end
    end
    push!(electedcands, winner)
    return winner, winnerscore
end

function tabulate(ballots, method::ScorePRTemplate, nwinners::Int)
    ncand, nvot = size(ballots)
    weights = ones(Float64, nvot)
    electedcands = Set{Int}()
    winnerdisplays = zeros(Float64, ncand)
    results = zeros(Float64, ncand, 0)
    while length(electedcands) < nwinners
        round = method.mainroundresults(ballots, weights, electedcands)
        resultline = [i in electedcands ? winnerdisplays[i] : round[i] for i in 1:ncand]
        results = hcat(results, resultline)
        if method.use_runoffs(nwinners-length(electedcands))
            for i in eachindex(round)
                i ∉ electedcands || (round[i] = -1)
            end
            runoffresults= method.runoffs(round, ballots, weights)
            runoffline = [i in electedcands ? winnerdisplays[i] : runoffresults[i] for i in 1:ncand]
            results = hcat(results, runoffline)
            new_winner, _ = addwinner!(electedcands, runoffresults)
            winnerdisplays[new_winner] = round[new_winner]
        else
            new_winner, winnertotal = addwinner!(electedcands, round)
            winnerdisplays[new_winner] = winnertotal
        end
        method.reweight!(weights, method, ballots, new_winner, nwinners, electedcands)
    end
    return results
end

@namevm allocatedscore = ScorePRTemplate(
    5, droop, weightedscorecount, norunoffs, nothing,
    asreweight!, allweight, weightedpriority
)
@namevm sss = ScorePRTemplate(
    5, droop, weightedscorecount, norunoffs, nothing,
    sssreweight!, sssweight, justscore
)
@namevm s5h = ScorePRTemplate(
    5, droop, weightedscorecount, norunoffs, nothing,
    asreweight!, sssweight, justscore
)
@namevm asr = ScorePRTemplate(
    5, droop, weightedscorecount, allrunoffs, weightedstarrunoff,
    asreweight!, allweight, weightedpriority
)
@namevm sssr = ScorePRTemplate(
    5, droop, weightedscorecount, allrunoffs, weightedstarrunoff,
    sssreweight!, sssweight, justscore
)
@namevm s5hr = ScorePRTemplate(
    5, droop, weightedscorecount, allrunoffs, weightedstarrunoff,
    asreweight!, sssweight, justscore
)
@namevm asfr = ScorePRTemplate(
    5, droop, weightedscorecount, runofflastround, weightedstarrunoff,
    asreweight!, allweight, weightedpriority
)
@namevm sssfr = ScorePRTemplate(
    5, droop, weightedscorecount, runofflastround, weightedstarrunoff,
    sssreweight!, sssweight, justscore
)
@namevm s5hfr = ScorePRTemplate(
    5, droop, weightedscorecount, runofflastround, weightedstarrunoff,
    asreweight!, sssweight, justscore
)
@namevm asu = ScorePRTemplate(
    5, droop, weightedscorecount, norunoffs, nothing,
    asreweight!, allweight, justscore
)
@namevm asur = ScorePRTemplate(
    5, droop, weightedscorecount, allrunoffs, weightedstarrunoff,
    asreweight!, allweight, justscore
)

"""
    mes_min_rho(weightsandscores, quota)

Determine the value of rho that will be used for MES.

weightsandscores is a vector of (weight, score) tuples.
All scores must be positive and the total weight must exceed the quota.
Quota is the total weight needed to be elected.
"""
function mes_min_rho(weightsandscores, quota)
    #sort by weight/score
    sortedws = sort(weightsandscores, lt=((w1,s1),(w2,s2)) -> w1*s2 < w2*s1)
    scoresums = similar(sortedws, Int)
    #scoresums[i] is the total score given by all ballots from the ith on.
    currentsum = 0
    for i in length(sortedws):-1:1
        currentsum += sortedws[i][2]
        scoresums[i] = currentsum
    end
    weightsum = 0
    for (i, (weight, score)) in enumerate(sortedws)
        if weightsum + scoresums[i]*weight/score >= quota
            return (quota-weightsum)/scoresums[i]
        else
            weightsum += weight
        end
    end
    if weightsum ≈ quota
        return 1
    end
    throw(ArgumentError("Insuffienct weight for mes_min_rho"))
end

"""
Method of Equal Shares
"""
struct MES <: ScorePR
    maxscore
    quota
    fallbackround!
end

function positiveweightapproval!(electedcands, weights, ballots)
    ncand, nvot = size(ballots)
    weight_totals = [cand ∈ electedcands ? -1 :
                        sum((weights[i] for i in 1:nvot if ballots[cand, i] > 0), init=0) for cand in 1:ncand]
    winner = argmax(weight_totals)
    push!(electedcands, winner)
    for i in eachindex(weights)
        if ballots[winner, i] > 0
            weights[i] = 0
        end
    end
    return winner, weight_totals
end

function weightedscorefallback!(electedcands, weights, ballots)
    resultline = weightedscorecount(ballots, weights, nothing)
    for c in electedcands
        resultline[c] = -1
    end
    winner = argmax(resultline)
    push!(electedcands, winner)
    for i in eachindex(weights)
        if ballots[winner, i] > 0
            weights[i] = 0
        end
    end
    return winner, resultline
end

@namevm mes = MES(5, exacthare, positiveweightapproval!)
@namevm mesdroop = MES(5, droop, positiveweightapproval!)

function tabulate(ballots, method::MES, nwinners::Int)
    ncand, nvot = size(ballots)
    quota = method.quota(nvot, nwinners)
    weights = ones(Float64, nvot)
    electedcands = Set{Int}()
    winnerdisplays = zeros(Float64, ncand)
    results = zeros(Float64, ncand, 0)
    while length(electedcands) < nwinners
        weight_totals = [cand ∈ electedcands ? -1 :
                        sum((weights[i] for i in 1:nvot if ballots[cand, i] > 0), init=0) for cand in 1:ncand]
        if any(weight_totals .> quota)
            rhos = ones(Float64, ncand)
            for cand in 1:ncand
                if weight_totals[cand] > quota
                    weightsandscores = [(weights[b], ballots[cand, b]) for b in 1:nvot if weights[b] > 0 && ballots[cand, b] > 0]
                    rhos[cand] = mes_min_rho(weightsandscores, quota)
                end
            end
            winner = argmin(rhos)
            push!(electedcands, winner)
            rho = rhos[winner]
            winnerdisplays[winner] = quota/rho
            for i in 1:nvot
                weights[i] = max(weights[i] - rho*ballots[winner, i], 0)
            end
            resultline = Vector{Float64}(undef, ncand)
            for c in 1:ncand
                if c in electedcands
                    resultline[c] = winnerdisplays[c]
                elseif weight_totals[c] > quota
                    resultline[c] = quota/rhos[c]
                else
                    resultline[c] = weight_totals[c]
                end
            end
        else
            winner, resultline = method.fallbackround!(electedcands, weights, ballots)
            winnerdisplays[winner] = resultline[winner]
            for c in electedcands
                resultline[c] = winnerdisplays[c]
            end
        end
        results = hcat(results, resultline)
    end
    return results
end

"""
Threshold Equal Approval
See https://electowiki.org/wiki/Threshold_Equal_Approval
"""
struct TEA <: ScorePR
    maxscore
    quota
    fallbackround!
end

@namevm tea = TEA(5, exacthare, weightedscorefallback!)
@namevm teadroop = TEA(5, droop, weightedscorefallback!)

function tabulate(ballots, method::TEA, nwinners::Int)
    FLOATING_POINT_EPSILON = 1e-7
    threshold = method.maxscore #The lowest score that counts as an appoval
    ncand, nvot = size(ballots)
    quota = method.quota(nvot, nwinners)
    weights = ones(Float64, nvot)
    electedcands = Set{Int}()
    winnerdisplays = zeros(Float64, ncand)
    results = zeros(Float64, ncand, 0)
    while threshold > 0 && length(electedcands) < nwinners
        weight_totals = [cand ∈ electedcands ? -1 :
                        sum((weights[i] for i in 1:nvot if ballots[cand, i] >= threshold), init=0)
                        for cand in 1:ncand]
        resultline = [c ∈ electedcands ? winnerdisplays[c] : weight_totals[c]
                        for c in 1:ncand]
        if any(weight_totals .> quota - FLOATING_POINT_EPSILON)
            #elect someone according to MES
            rhos = fill(2.0, ncand)
            for cand in 1:ncand
                if weight_totals[cand] > quota - FLOATING_POINT_EPSILON
                    weightsandones = [
                        (weights[b], 1) for b in 1:nvot
                        if weights[b] > 0 && ballots[cand, b] >= threshold]
                    rhos[cand] = mes_min_rho(weightsandones, quota)
                    resultline[cand] = quota/rhos[cand]
                end
            end
            winner = argmin(rhos)
            push!(electedcands, winner)
            rho = rhos[winner]
            winnerdisplays[winner] = quota/rho
            for i in 1:nvot
                if ballots[winner, i] >= threshold
                    weights[i] = max(weights[i] - rho, 0)
                end
            end
            results = hcat(results, resultline)
        else
            threshold -= 1
            results = hcat(results, resultline,
                [c ∈ electedcands ? max(winnerdisplays[c], threshold+1) : threshold
                for c in 1:ncand])
        end
    end
    #Handle the case that we need to elect people who don't have a full quota at any threshold
    while length(electedcands) < nwinners
        winner, resultline = method.fallbackround!(electedcands, weights, ballots)
        winnerdisplays[winner] = resultline[winner]
        resultline ./= method.maxscore
        for c in electedcands
            resultline[c] = winnerdisplays[c]
        end
        results = hcat(results, resultline)
    end
    return results
end