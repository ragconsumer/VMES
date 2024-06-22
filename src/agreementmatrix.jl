"""
    agreement_matrix(niter::Int,
                        vmodel::VoterModel,
                        methods::Vector{<:VotingMethod},
                        estrats::Vector{ElectorateStrategy},
                        nvot::Int, ncand::Int, nwinners::Int=1;
                        correlatednoise::Float64=0.1, iidnoise::Float64=0.0,
                        iter_per_update=0)

Calculate how often each (method, estrat) pair yields the same set of winners as each other
"""
function agreement_matrix(niter::Int,
                        vmodel::VoterModel,
                        methods::Vector{<:VotingMethod},
                        estrats::Vector{ElectorateStrategy},
                        nvot::Int, ncand::Int, nwinners::Int=1;
                        correlatednoise::Float64=0.1, iidnoise::Float64=0.0,
                        iter_per_update=0)
    total_agreements = zeros(Int, length(methods), length(methods), Threads.nthreads())
    Threads.@threads for tid in 1:Threads.nthreads()
        iterationsinthread = niter ÷ Threads.nthreads() + (tid <= niter % Threads.nthreads() ? 1 : 0)
        for i in 1:iterationsinthread
            if iter_per_update > 0 && i % iter_per_update == 0
                println("Iteration $i in thread $tid")
            end
            total_agreements[:, :, tid] += one_agreement_matrix_iter(
                vmodel, methods, estrats, nvot, ncand, nwinners, correlatednoise, iidnoise)
        end
    end
    return sum(total_agreements, dims=3)./niter
end

function agreement_matrix(niter::Int,
    vmodel::VoterModel,
    methods::Vector{<:VotingMethod},
    estrats::Vector,
    nvot::Int, ncand::Int, nwinners::Int=1;
    correlatednoise::Float64=0.1, iidnoise::Float64=0.0,
    iter_per_update=0)
    agreement_matrix(niter, vmodel, methods,
            [esfromtemplate(template, hypot(correlatednoise, iidnoise)) for template in estrats],
            nvot, ncand, nwinners,
            correlatednoise=correlatednoise, iidnoise=iidnoise; iter_per_update=iter_per_update)
end

function one_agreement_matrix_iter(vmodel::VoterModel,
                                    methods::Vector{<: VotingMethod},
                                    estrats::Vector{ElectorateStrategy},
                                    nvot::Int, ncand::Int, nwinners=1,
                                    correlatednoise::Float64=0.1, iidnoise::Float64=0.0)
    electorate = make_electorate(vmodel, nvot, ncand)
    infodict = administerpolls(electorate, (estrats, methods), correlatednoise, iidnoise)
    ballots = castballots.((electorate,), estrats, methods, (infodict,))
    winnersets = getwinners.(ballots, methods, nwinners)
    n = length(methods)
    agreement_matrix = Matrix{Int}(undef, n, n)
    for i in 1:n
        for j in 1:n
            if Set(winnersets[i]) == Set(winnersets[j])
                agreement_matrix[i, j] = 1
            else
                agreement_matrix[i, j] = 0
            end
        end
    end
    return agreement_matrix
end