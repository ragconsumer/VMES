"""
    droop(nvot, nwinners)

Calcuate the Droop quota.
"""
droop(nvot, nwinners) = Int(floor(nvot/(nwinners+1))) + 1

struct RCV <: RankedChoiceVoting
    quota
end
InstantRunoffVoting = RankedChoiceVoting #Single-winner is implemented as a special case of STV.
SingleTransferableVote = RankedChoiceVoting
rcv = RCV(droop)
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

allocatedscore = ScorePRTemplate(
    5, droop, weightedscorecount, norunoffs, nothing,
    asreweight!, allweight, weightedpriority
)
sss = ScorePRTemplate(
    5, droop, weightedscorecount, norunoffs, nothing,
    sssreweight!, sssweight, justscore
)
s5h = ScorePRTemplate(
    5, droop, weightedscorecount, norunoffs, nothing,
    asreweight!, sssweight, justscore
)
asr = ScorePRTemplate(
    5, droop, weightedscorecount, allrunoffs, weightedstarrunoff,
    asreweight!, allweight, weightedpriority
)
sssr = ScorePRTemplate(
    5, droop, weightedscorecount, allrunoffs, weightedstarrunoff,
    sssreweight!, sssweight, justscore
)
s5hr = ScorePRTemplate(
    5, droop, weightedscorecount, allrunoffs, weightedstarrunoff,
    asreweight!, sssweight, justscore
)
asfr = ScorePRTemplate(
    5, droop, weightedscorecount, runofflastround, weightedstarrunoff,
    asreweight!, allweight, weightedpriority
)
sssfr = ScorePRTemplate(
    5, droop, weightedscorecount, runofflastround, weightedstarrunoff,
    sssreweight!, sssweight, justscore
)
s5hfr = ScorePRTemplate(
    5, droop, weightedscorecount, runofflastround, weightedstarrunoff,
    asreweight!, sssweight, justscore
)
asu = ScorePRTemplate(
    5, droop, weightedscorecount, norunoffs, nothing,
    asreweight!, allweight, justscore
)
asur = ScorePRTemplate(
    5, droop, weightedscorecount, allrunoffs, weightedstarrunoff,
    asreweight!, allweight, weightedpriority
)