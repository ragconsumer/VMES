"""
    (tabulation::AbstractArray, maxmargin::Int, method::ApprovalMethod)

Returns true unless we can show that the addition or removal of up to maxmargin additional ballots cannot change the winners
"""
function(tabulation::AbstractArray, maxmargin::Int, method::ApprovalMethod)
    sortedtab = sorted(tabulation)
    if sortedtab[end] - sortedtab[end-1] > maxmargin
        return true
    else
        return false
    end
end

isclose(tabulation::AbstractArray, maxmargin::Int, method::VotingMethod) = true