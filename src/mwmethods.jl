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
        resultline = [c in candsleft ? sum(weights[i] for i in piles[c]) : c in candselected ? float(quota) : 0.0 for c in 1:ncands]
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