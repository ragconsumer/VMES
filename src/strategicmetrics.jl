abstract type StrategicMetric end
struct ESIF <: StrategicMetric; end
struct PVSI <: StrategicMetric; end

function calc_stratmetric(metric::StrategicMetric, niter::Integer, vmodel::VoterModel, methodsandstrats::Vector,
                          nvot::Integer, ncand::Integer,
                          correlatednoise::Real=0.1, iidnoise::Real=0, nwinners::Integer=1,
                          innerstratargs=())
    methodsandstrats = build_methodsandstrats_from_templates(methodsandstrats, hypot(correlatednoise, iidnoise))
    m_and_s_abstain = maybe_add_abstain(metric, methodsandstrats)
    results = Array{Float64}(undef, numutilmetrics(nwinners), num_stratmetric_columns(m_and_s_abstain), niter)
    Threads.@threads for i in 1:niter
        results[:, :, i] = one_stratmetric_iter(metric, vmodel, m_and_s_abstain, nvot, ncand,
                                        correlatednoise, iidnoise, nwinners, innerstratargs)
    end
    totals = dropdims(sum(results, dims=3), dims=3) #memory inefficient summation
    results = strategic_totals_to_df(totals, methodsandstrats)
    results[!, "Voter Model"] .= [vmodel]
    results[!, "nvot"] .= nvot
    results[!, "ncand"] .= ncand
    results[!, "nwinners"] .= nwinners
    results[!, "Correlated Noise"] .= correlatednoise
    results[!, "IID Noise"] .= iidnoise
    results[!, "Iterations"] .= niter
    return results
end

"""
    totals_to_esif(totals::Matrix{Float64}, methodsandstrats)

Convert utility totals to ESIFs.
"""
function strategic_totals_to_df(totals::Matrix{Float64}, methodsandstrats)
    nmetrics = numutilmetrics(size(totals, 1))
    ncolumns = num_stratmetric_columns(methodsandstrats)
    numentries = ncolumns*nmetrics
    basestratentries = Vector{ElectorateStrategy}(undef, numentries)
    methodentries = Vector{VotingMethod}(undef, numentries)
    stratentries = Vector{Union{VoterStrategy, VoterStratTemplate}}(undef, numentries)
    metricentries = Vector{String}(undef, numentries)
    esifs = Vector{Float64}(undef, numentries)
    for metric in 1:nmetrics
        i = 1 #index of row of results being constructed
        totalsindex = 1 #index of 
        for (methods, basestrats, strats) in methodsandstrats
            for basestrat in basestrats
                for method in methods
                    abstain_util = totals[metric, totalsindex]
                    totalsindex += 1
                    for strat in strats
                        basestratentries[(metric-1)*ncolumns + i] = basestrat
                        methodentries[(metric-1)*ncolumns + i] = method
                        stratentries[(metric-1)*ncolumns + i] = strat
                        metricentries[(metric-1)*ncolumns + i] = metricnames(metric)
                        esifs[(metric-1)*ncolumns + i] = (abstain_util-totals[metric, totalsindex])/abstain_util
                        i += 1
                        totalsindex += 1
                    end
                end
            end
        end
    end
    return DataFrame(:Metric=>metricentries, :Method=>methodentries,
                     Symbol("Base Strategy")=>basestratentries, :Strategy=>stratentries,
                     :ESIF=>esifs)
    #return basestratentries, methodentries, stratentries, esifs
end

"""
    one_stratmetric_iter(metric::StrategicMetric, vmodel::VoterModel, methodsandstrats::Vector,
                              nvot::Integer, ncand::Integer,
                              correlatednoise::Number, iidnoise::Number, nwinners::Integer,
                              innerstratargs)

A single iteration of ESIF or PVSI"""
function one_stratmetric_iter(metric::StrategicMetric, vmodel::VoterModel, methodsandstrats::Vector,
                              nvot::Integer, ncand::Integer,
                              correlatednoise::Number, iidnoise::Number, nwinners::Integer,
                              innerstratargs)
    electorate = make_electorate(vmodel, nvot, ncand)
    admininput = getadminpollsinput(methodsandstrats, hypot(correlatednoise, iidnoise))
    noisevector = correlatednoise .* randn(size(electorate,1))
    infodict = administerpolls(electorate, admininput, noisevector, iidnoise)
    utiltotals = zeros(Float64, numutilmetrics(nwinners), num_stratmetric_columns(methodsandstrats))
    bigutindex = 1
    for (methods, basestrats, strat_templates) in methodsandstrats
        midutindex = 0
        for basestrat in basestrats
            baseballots = castballots(electorate, basestrat, methods[1], infodict)
            basewinnersets = [getwinners(baseballots, method, nwinners) for method in methods]
            innerstratmetric!(utiltotals, metric, electorate, basestrat.flexible_strategists,
                            methods, strat_templates, basestrat, 
                            baseballots, basewinnersets, infodict, 
                            noisevector, correlatednoise, iidnoise,
                            nwinners, bigutindex + midutindex, innerstratargs)
            midutindex += length(methods)*length(strat_templates)
        end
        bigutindex += length(methods)*length(strat_templates)*length(basestrats)
    end
    return utiltotals  
end





maybe_add_abstain(::Any, methodsandstrats) = methodsandstrats
maybe_add_abstain(::ESIF, methodsandstrats) = [(methods, basestrats, cat(abstain, strats, dims=1))
                                            for (methods, basestrats, strats) in methodsandstrats]
    
function num_stratmetric_columns(methodsandstrats)
    return sum(length(basestrats)*length(strats)*length(methods)
                for (methods, basestrats, strats) in methodsandstrats)
end

"""
    build_methodsandstrats_from_templates(methodsandstrats::Vector, uncertainty::Float64)

Convert electorate strat templates to estrats in methodsandstrats
"""
function build_methodsandstrats_from_templates(methodsandstrats::Vector, uncertainty::Float64)
    return [(m, [esfromtemplate(basestrat, uncertainty) for basestrat in basestrats], s)
            for (m, basestrats, s) in methodsandstrats]
end

"""
    getadminpollsinput(methodsandstrats)

Convert the vector of (methods, basestrats, strats) tuple to something compatible with administerpolls()
"""
function getadminpollsinput(methodsandstrats, uncertainty)
    total_length = sum(length(basestrats)*(1 + length(strats))
                        for (methods, basestrats, strats) in methodsandstrats)
    stratinputs = Vector{Union{VoterStrategy, ElectorateStrategy}}(undef, total_length)
    methodinputs = Vector{VotingMethod}(undef, total_length)
    i = 1
    for (methods, basestrats, strats) in methodsandstrats
        for basestrat in basestrats
            methodinputs[i] = methods[1]
            stratinputs[i] = basestrat
            i += 1
            for strat in strats
                methodinputs[i] = methods[1]
                stratinputs[i] = vsfromtemplate(strat, basestrat, uncertainty)
                i += 1
            end
        end
    end
    return stratinputs, methodinputs
end
