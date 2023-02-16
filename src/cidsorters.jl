function normalizedUtilDeviation(voter, cand)
    (voter[cand] - Statistics.mean(voter))/Statistics.std(voter, corrected=false)
end