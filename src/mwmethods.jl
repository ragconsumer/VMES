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

"""
    zeroquota(_, _)

A quota of 0. Used as a hack for making block methods.
"""
zeroquota(_, _) = 0

"Single Nontransferable Vote (limited voting)"
struct SNTV <: PluralityMethod
end
@namevm sntv = SNTV()

struct LimitedVoting <: ApprovalMethod
    numvotes::Int
end

struct RCV <: RankedChoiceVoting
    quota
end

struct BottomsUpIRV <: RankedChoiceVoting
end
@namevm buirv = BottomsUpIRV()

InstantRunoffVoting = RankedChoiceVoting #Single-winner is implemented as a special case of STV.
SingleTransferableVote = RankedChoiceVoting
@namevm rcv = RCV(droop)
irv = rcv
stv = rcv

"""
    rcv_resort!(piles, allballots, indiciestosort, candsleft)

Sort the indicies into the piles for the remaining candidates and return the weight given to each.
"""
function rcv_resort!(piles, allballots, indiciestosort, candsleft, weights)
    transfertotals = zeros(Float64, size(allballots, 1))
    for i in indiciestosort
        vote, bestRank = 0, 0
        for c in candsleft
            if allballots[c, i] > bestRank
                vote, bestRank = c, allballots[c, i]
            end
        end
        if vote != 0
            push!(piles[vote], i)
            transfertotals[vote] += weights[i]
        end
    end
    return transfertotals
end

"""
    tabulate(ballots, method::RCV, nwinners)

    Tabulate an STV or IRV election.
    Weighted Inclusive Gregory, with candidates who achieve the quota skipped for transfers.
"""
function tabulate(ballots, method::RCV, nwinners::Int)
    ncand, nvot = size(ballots)
    optionally_fradulent_rcv_tabulation(
        ballots, nwinners, method.quota(nvot, nwinners),false, zeros(Float64, ncand), 0.0, Random.Xoshiro())
end

"""
    optionally_fradulent_rcv_tabulation(ballots, nwinners::Integer, quota, scale_results::Bool,
                                             noisevector, iidnoise=0.)

Tabulate an RCV election with the option of added noise.

Scale_results specifies whether the results shouldbe give as a fraction of total ballots or
as a number of (weighted) ballots.
Quota is the support needed to be elected. It should be a number of voters if scale_results is false,
or a fraction of voters if scale_results is true.
"""
function optionally_fradulent_rcv_tabulation(ballots, nwinners::Integer, quota, scale_results::Bool,
                                             noisevector, iidnoise=0., rng=Random.Xoshiro())
    ncand, nvot = size(ballots)
    piles = [Set{Int}() for _ in 1:ncand]
    weights = ones(Float64, size(ballots, 2))
    candsleft = BitSet(1:ncand)
    candselected = Set{Int}()
    tosort = 1:nvot
    nelected = 0
    results = zeros(Float64, ncand, 0) #The tabulation results that will ultimately be returned
    totals = zeros(Float64, ncand) #How much support each candidate is said to have at each point
    #The amount of support that can apparently be transfered; may differ from the actual total weight available.
    amount_ostensibly_transferable = scale_results ? 1.0 : Float64(nvot) 
    while nelected < nwinners && nelected + length(candsleft) > nwinners
        transfers = rcv_resort!(piles, ballots, tosort, candsleft, weights)
        #rescale the transfers and add noise
        if sum(weights[collect(tosort)]) > 0
            noisytransfers = transfers .* amount_ostensibly_transferable/sum(weights[collect(tosort)])
        else
            noisytransfers = transfers
        end
        transfertotal = sum(noisytransfers)
        cl = collect(candsleft)
        noisytransfers[cl] += transfertotal .* (noisevector[cl] + (iidnoise == 0 ?
                            zeros(Float64, length(cl)) : iidnoise .* randn(rng, length(candsleft))))
        clamptosum!(noisytransfers, transfertotal, transfertotal)
        #perform the remainder of the tabulation round legitmately, based on potentially bogus numbers
        totals[cl] += noisytransfers[cl]
        resultline = [c in candsleft ? totals[c] : c in candselected ? float(quota) : 0.0 for c in 1:ncand]
        results = hcat(results, resultline)
        new_winners = [c for c in 1:ncand if totals[c] >= quota]
        nelected += length(new_winners)
        if isempty(new_winners) #transfer from eliminated candidates
            fewestvotes = minimum(totals[c] for c in candsleft)
            if length(filter(c -> totals[c]==fewestvotes, candsleft)) == 0
                print(totals, fewestvotes)
            end
            loser = maximum(filter(c -> totals[c]==fewestvotes, candsleft))
            tosort = piles[loser]
            amount_ostensibly_transferable = totals[loser]
            totals[loser] = 0.
            delete!(candsleft, loser)
        elseif nelected < nwinners #transfer excess from winners
            tosort = Set()
            amount_ostensibly_transferable = 0
            for c in new_winners
                push!(candselected, c)
                union!(tosort, piles[c])
                delete!(candsleft,c)
                amount_ostensibly_transferable += totals[c] - quota
                totals[c] = 0
                weightfactor = (resultline[c] - quota)/resultline[c]
                for i in piles[c]
                    weights[i] *= weightfactor
                end
            end
        end
        #stop tabulation if further transfers are superfluous
    end
    return results
end

tabulate(ballots, method::RCV) = tabulate(ballots, method::RCV, 1)

function tabulate(ballots, method::BottomsUpIRV, nwinners::Int)
    ncand, nvot = size(ballots)
    piles = [Set{Int}() for _ in 1:ncand]
    candsleft = BitSet(1:ncand)
    tosort = 1:nvot
    totals = rcv_resort!(piles, ballots, 1:nvot, candsleft, ones(Int, nvot))
    results = totals
    while length(candsleft) > nwinners
        fewestvotes = minimum(totals[c] for c in candsleft)
        if length(filter(c -> totals[c]==fewestvotes, candsleft)) == 0
            print(totals, fewestvotes)
        end
        loser = maximum(filter(c -> totals[c]==fewestvotes, candsleft))
        delete!(candsleft, loser)
        tosort = piles[loser]
        transfers = rcv_resort!(piles, ballots, piles[loser], candsleft, ones(Int, nvot))
        totals += transfers
        totals[loser] = 0
        results = hcat(results, totals)
    end
    return results
end

function placementsfromtab(tabulation::AbstractArray, method::RankedChoiceVoting, nwinners=1)
    if size(tabulation, 2) == 1
        return indices_by_sorted_values(tabulation[:, 1])
    end
    quota = Inf
    ncand, nrounds = size(tabulation)
    if nwinners != 1
        for c in 1:ncand, r in 2:nrounds
            if tabulation[c,r] < tabulation[c, r-1] && tabulation[c,r] > 0
                quota = tabulation[c,r]
                break
            end
        end
    end
    placements = indices_by_sorted_values(tabulation[:, end])
    #from here, we just need to correct the placements of candidates who
    #were elected or eliminated before the final round.
    candsleft = BitSet(1:ncand)
    nelected, neliminated = 0, 0
    for round in 1:nrounds
        eliminated = Vector{Int}()
        elected = Vector{Int}()
        for cand in candsleft
            if tabulation[cand, round] == 0
                push!(eliminated, cand)
            elseif tabulation[cand, round] >= quota
                push!(elected, cand)
            end
        end
        sort!(elected,
            lt=(c1, c2)->tabulation[c1]<tabulation[c2] ? true :
                tabulation[c1] == tabulation[c2] && c1<c2 ? true : false,
                rev = true)
        sort!(eliminated,
            lt=(c1, c2)->tabulation[c1]<tabulation[c2] ? true :
                tabulation[c1] == tabulation[c2] && c1<c2 ? true : false,)
        for winner in elected
            nelected += 1
            placements[nelected] = winner
            delete!(candsleft, winner)
        end
        for loser in eliminated
            placements[ncand - neliminated] = loser
            neliminated += 1
            delete!(candsleft, loser)
        end
    end
    return placements
end

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
@namevm ashare = ScorePRTemplate(
    5, exacthare, weightedscorecount, norunoffs, nothing,
    asreweight!, allweight, weightedpriority
)
@namevm ashu = ScorePRTemplate(
    5, exacthare, weightedscorecount, norunoffs, nothing,
    asreweight!, allweight, justscore
)
@namevm ashfr = ScorePRTemplate(
    5, exacthare, weightedscorecount, runofflastround, weightedstarrunoff,
    asreweight!, allweight, weightedpriority
)
@namevm ashr = ScorePRTemplate(
    5, exacthare, weightedscorecount, allrunoffs, weightedstarrunoff,
    asreweight!, allweight, weightedpriority
)
@namevm s5hw = ScorePRTemplate(
    5, droop, weightedscorecount, norunoffs, nothing,
    asreweight!, sssweight, weightedpriority
)
@namevm s5hwr = ScorePRTemplate(
    5, droop, weightedscorecount, allrunoffs, weightedstarrunoff,
    asreweight!, sssweight, weightedpriority
)

@namevm blockstar = ScorePRTemplate(
    5, zeroquota, weightedscorecount, allrunoffs, weightedstarrunoff,
    asreweight!, allweight, justscore
)

struct AllocatedRankedRobin <: RankedMethod
    quota
    reweight!
    weightgiven
    quotapriority
end

function tabulate(ballots, method::AllocatedRankedRobin, nwinners::Int)
    ncand, nvot = size(ballots)
    weights = ones(Float64, nvot)
    electedcands = Set{Int}()
    winnerdisplays = zeros(Float64, ncand)
    results = zeros(Float64, ncand, 0)
    while length(electedcands) < nwinners
        compmat = pairwisematrix(ballots, weights, electedcands)
        round = tabulatefromcompmat(compmat, RankedRobin())
        round[:, end] = [i in electedcands ? winnerdisplays[i] : round[i, end] for i in 1:ncand]
        results = hcat(results, round)
        new_winner, winnertotal = addwinner!(electedcands, round[:, end])
        winnerdisplays[new_winner] = winnertotal
        method.reweight!(weights, method, ballots, new_winner, nwinners, electedcands)
    end
    results = hcat(results, [c in electedcands ? winnerdisplays[c] : -1. for c in 1:ncand])
    return results
end

@namevm allocatedrankedrobin = AllocatedRankedRobin(exacthare, asreweight!, allweight, justscore)
@namevm arrdroop = AllocatedRankedRobin(droop, asreweight!, allweight, justscore)

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
    weight_totals = [cand ∈ electedcands ? -1. :
                        sum((weights[i] for i in 1:nvot if ballots[cand, i] > 0), init=0.) for cand in 1:ncand]
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
@namevm mesapproval = MES(1, exacthare, positiveweightapproval!)
@namevm mesapprovaldroop = MES(1, droop, positiveweightapproval!)

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
            rhos = [2.0 for _ in 1:ncand]
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

struct CascadingScoreMethod <: ScoringMethod
    orderingmethod
    quota
    maxscore::Int
    elect_runoff::Bool
    elim_runoff::Bool
end

struct CascadingRankedMethod <: RankedMethod
    orderingmethod
    quota
    elect_runoff::Bool
    elim_runoff::Bool
end

CascadingVoteMethod = Union{CascadingRankedMethod, CascadingScoreMethod}

"""
    cascade_one_vote!(supportersets::Vector{AbstractSet}, ballot, voter_index, candsleft)

Have the voter offer votes to all of their top-rated remaining candidates.

Adds voter to the relevant supportersets.
"""
function cascade_one_vote!(supportersets::Vector{<:AbstractSet}, ballot, voter_index, candsleft)
    supportlevel = maximum(ballot[c] for c in candsleft)
    if supportlevel > 0
        for c in candsleft
            if ballot[c] == supportlevel
                push!(supportersets[c], voter_index)
            end
        end
    end
end

function tabulate(ballots, method::CascadingVoteMethod, nwinners::Int)
    ncand, nvot = size(ballots)
    quota::Float64 = method.quota(nvot, nwinners)
    weights = ones(Float64, nvot)
    supportersets = [BitSet() for _ in 1:ncand]
    #supportersets[cand] contains every voter who's offering a vote to cand
    orderingresults::Array{Float64} = tabulate(ballots, method.orderingmethod, 1)
    total_pref_order = placementsfromtab(orderingresults, method.orderingmethod)
    results = orderingresults
    
    if method.elect_runoff || method.elim_runoff
        compmat = pairwisematrix(ballots)
        results = hcat(results, compmat)
    end

    candsleft = BitSet(1:ncand)
    winners = BitSet()
    nelected = 0
    neliminated = 0
    for i in 1:nvot
        cascade_one_vote!(supportersets, ballots[:, i], i, candsleft)
    end
    while nelected < nwinners && length(candsleft) + nelected > nwinners
        offeredvotecounts = zeros(Float64, ncand)
        for c in candsleft
            for v in supportersets[c]
                offeredvotecounts[c] += weights[v]
            end
        end
        results = hcat(results, [c ∈ winners ? quota : offeredvotecounts[c] for c in 1:ncand])
        quotamakers = [c for c in candsleft if offeredvotecounts[c] >= quota]
        if length(quotamakers) > 0
            #elect someone
            
            results = hcat(results, [c ∈ quotamakers ? orderingresults[c] : 0. for c in 1:ncand])

            #find a winner based on the total preferences order
            finalist1i = 1
            while total_pref_order[finalist1i] ∉ quotamakers
                finalist1i += 1
            end
            if method.elect_runoff && length(quotamakers) >= 2
                finalist2i = finalist1i + 1
                while total_pref_order[finalist2i] ∉ quotamakers
                    finalist2i += 1
                end
                f1, f2 = total_pref_order[finalist1i], total_pref_order[finalist2i]
                if compmat[f1, f2] >= compmat[f2, f1]
                    winner = f1
                else
                    winner = f2
                end
            else
                winner = total_pref_order[finalist1i]
            end
            
            delete!(candsleft, winner)
            nelected += 1
            push!(winners, winner)

            if nelected == nwinners
                results = hcat(results, [c ∈ winners ? quota : offeredvotecounts[c] for c in 1:ncand])
            end

            weightfactor = (offeredvotecounts[winner] - quota)/offeredvotecounts[winner]
            for voter in supportersets[winner]
                weights[voter] *= weightfactor
                cascade_one_vote!(supportersets, ballots[:, voter], voter, candsleft)
            end
        else
            #eliminate someone
            loseri = ncand
            while total_pref_order[loseri] ∉ candsleft
                loseri -= 1
            end
            if method.elim_runoff && length(candsleft) >= 2
                loser2i = loseri - 1
                while total_pref_order[loser2i] ∉ candsleft
                    loser2i -= 1
                end
                l1, l2 = total_pref_order[loseri], total_pref_order[loser2i]
                if compmat[l1, l2] <= compmat[l2, l1]
                    loser = l1
                else
                    loser = l2
                end
            else
                loser = total_pref_order[loseri]
            end
            delete!(candsleft, loser)
            neliminated += 1
            for voter in supportersets[loser]
                cascade_one_vote!(supportersets, ballots[:, voter], voter, candsleft)
            end
        end
    end
    if nelected < nwinners
        #ensure the winners have higher totals than the losers
        for c in candsleft
            results[c, end] = max(results[c, end], 1)
        end
        union!(winners, candsleft)
    end
    if method.elect_runoff || method.elim_runoff
        #the final line of the results may be deceptive if we don't add this
        results = hcat(results, [c ∈ winners ? quota : 0. for c in 1:ncand])
    end
    return results
end

"""
A ranked proportional voting method that does elections and transfers like STV,
but handles eliminations with eliminationfunciton that takes the remaining candidates
and the pairwis comparison matrix as arguments

eliminationmethod must be an instance of CondorcetCompMatOnly
"""
struct STVCompMatMethod <: RankedMethod
    eliminationmethod
    quota
end

function tabulate(ballots, method::STVCompMatMethod, nwinners::Int)
    ncand, nvot = size(ballots)
    quota = method.quota(nvot, nwinners)
    piles = [Set{Int}() for _ in 1:ncand]
    weights = ones(Float64, size(ballots, 2))
    candsleft = BitSet(1:ncand)
    candselected = Set{Int}()
    tosort = 1:nvot
    nelected = 0
    compmat = pairwisematrix(ballots)
    results = Float64.(compmat) #The tabulation results that will ultimately be returned
    totals = zeros(Float64, ncand)
    revcompmat = transpose(pairwisematrix(ballots)) #with preferences reversed to determine losers
    while nelected < nwinners && nelected + length(candsleft) > nwinners
        transfers = rcv_resort!(piles, ballots, tosort, candsleft, weights)
        cl = collect(candsleft)
        totals[cl] += transfers[cl]
        resultline = [c in candsleft ? totals[c] : c in candselected ? float(quota) : 0.0 for c in 1:ncand]
        results = hcat(results, resultline)
        new_winners = [c for c in 1:ncand if totals[c] >= quota]
        nelected += length(new_winners)
        if isempty(new_winners) #transfer from eliminated candidates
            fewestvotes = minimum(totals[c] for c in candsleft)
            if length(filter(c -> totals[c]==fewestvotes, candsleft)) == 0
                print(totals, fewestvotes)
            end
            candlist = collect(candsleft)
            smallcompmat = revcompmat[candlist, candlist] #only includes remaining candidates
            loserindex = winnersfromtab(tabulatefromcompmat(smallcompmat, method.eliminationmethod),
                                    method.eliminationmethod)[1]
            loser = candlist[loserindex]
            tosort = piles[loser]
            amount_ostensibly_transferable = totals[loser]
            totals[loser] = 0.
            delete!(candsleft, loser)
        elseif nelected < nwinners #transfer excess from winners
            tosort = Set()
            amount_ostensibly_transferable = 0
            for c in new_winners
                push!(candselected, c)
                union!(tosort, piles[c])
                delete!(candsleft,c)
                amount_ostensibly_transferable += totals[c] - quota
                totals[c] = 0
                weightfactor = (resultline[c] - quota)/resultline[c]
                for i in piles[c]
                    weights[i] *= weightfactor
                end
            end
        end
        #stop tabulation if further transfers are superfluous
    end
    return results
end

"""
Sequential Proportional Approval Voting

weightfunc is a function that takes the number of winners a ballot has voted for
as its argument and returns the weight of that ballot
"""
struct SPAV <: ApprovalMethod
    weightfunc::Function
end

@namevm spav = SPAV(x -> 1/(x+1)) #d'Hondt/Jefferson reweighting
@namevm spav_sl = SPAV(x -> 1/(2x+1)) #Sainte-Laguë reweighting
@namevm spav_msl = SPAV(x -> x==0 ? 5/7 : 1/(2x+1)) #modified Sainte-Laguë reweighting

function tabulate(ballots, method::SPAV, nwinners::Int)
    winners = BitSet()
    ncand = size(ballots, 1)
    results = Array{Float64}(undef, ncand, 0)
    while length(winners) < nwinners
        totals = [c in winners ? -1 : Float64(sum(
                        (method.weightfunc(sum(ballot[d] for d in winners; init=0))
                    for ballot in eachslice(ballots, dims=2) if ballot[c] > 0), init=0))
                for c in 1:ncand]
        winner = argmax(totals)
        results = hcat(results, [c in winners ? results[c,end] : totals[c] for c in 1:ncand])
        push!(winners, winner)
    end
    return results
end