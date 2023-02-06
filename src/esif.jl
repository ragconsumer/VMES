"""
Expected Strategic Influence Factors
See https://voting-in-the-abstract.medium.com/expected-strategic-influence-factors-20b3791ecbcd
"""

"""
    calc_esif(niter::Integer, vmodel::VoterModel, methodsandstrats::Vector, nvot::Integer, ncand::Integer,
                   correlatednoise::Number, iidnoise::Number, nwinners::Integer)

Determine the ESIFs of the given strategies.

# Arguments
- `niter::Integer`: The number of iterations (i.e. randomly generated electorates) of the simulation
- `vmodel::VoterModel`: The voter model used to generate electorates
- `methodsandstrats::Vector{Tuple{Vector{VotingMethod}, Vector{ElectorateStrategy}, Vector{VoterStrategy}}}`
A vector of tuples that specify voting methods and strategies.
Each tuple in the vector is of the form (methods, basestrats, strats)
    - methods: An array of voting methods, all of which will use to the same strategies
    - basestrats: An array of electorate strategies, each of which will be used by default
    as the background strategy. Estrat templates can be used in place of electorate strategies.
    - strats: The voter strategies under consideration. These are the foci of the ESIF simulations.
    Voter strategy templates can be used in place of svoter strategies, in which case they will use
    the basestrats for polling information.
- `nvot::Integer`: The number of voters. Should match the number of voters given in basestrats.
- `ncand::Integer`: The number of candidates.
- `correlatednoise::Real` The amount of correlated polling noise, give in standard deviations. 
- `iidnoise::Real` The amount of uncorrelated polling noise, give in standard deviations.
`nwinners::Integer` The number of winners of each election.
"""
function calc_esif(niter::Integer, vmodel::VoterModel, methodsandstrats::Vector, nvot::Integer, ncand::Integer,
                   correlatednoise::Number=0.1, iidnoise::Number=0, nwinners::Integer=1)
    methodsandstrats = buildfromtemplatesforesif(methodsandstrats, hypot(correlatednoise, iidnoise))
    m_and_s_abstain = [(methods, basestrats, cat(abstain, strats, dims=1))
                        for (methods, basestrats, strats) in methodsandstrats]
    results = Array{Float64}(undef, numutilmetrics(nwinners), num_esif_columns(m_and_s_abstain), niter)
    Threads.@threads for i in 1:niter
        results[:, :, i] = one_esif_iter(vmodel, m_and_s_abstain, nvot, ncand,
                                        correlatednoise, iidnoise, nwinners)
    end
    totals = dropdims(sum(results, dims=3), dims=3) #memory inefficient summation
    return totals_to_esif(totals, methodsandstrats)
end

"""
    totals_to_esif(totals::Matrix{Float64}, methodsandstrats)

Convert utility totals to ESIFs.
"""
function totals_to_esif(totals::Matrix{Float64}, methodsandstrats)
    nmetrics = numutilmetrics(size(totals, 1))
    ncolumns = num_esif_columns(methodsandstrats)
    numentries = ncolumns*nmetrics
    basestratentries = Vector{ElectorateStrategy}(undef, numentries)
    methodentries = Vector{VotingMethod}(undef, numentries)
    stratentries = Vector{VoterStrategy}(undef, numentries)
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
    one_esif_iter(vmodel::VoterModel, methodsandstrats::Vector, nvot::Integer, ncand::Integer,
                       correlatednoise::Number, iidnoise::Number, nwinners::Integer)

A single iteration for ESIF.
"""
function one_esif_iter(vmodel::VoterModel, methodsandstrats::Vector, nvot::Integer, ncand::Integer,
                       correlatednoise::Number, iidnoise::Number, nwinners::Integer)
    electorate = make_electorate(vmodel, nvot, ncand)
    admininput = getadminpollsinput(methodsandstrats)
    infodict = administerpolls(electorate, admininput, correlatednoise, iidnoise)
    utiltotals = zeros(Float64, numutilmetrics(nwinners), num_esif_columns(methodsandstrats))
    bigutindex = 1
    for (methods, basestrats, strat_templates) in methodsandstrats
        midutindex = 0
        for basestrat in basestrats
            strats = [vsfromtemplate(template, basestrat, hypot(correlatednoise, iidnoise))
                      for template in strat_templates]
            baseballots = castballots(electorate, basestrat, methods[1], infodict)
            basewinnersets = [getwinners(baseballots, method, nwinners) for method in methods]
            for voterindex in 1:basestrat.flexible_strategists
                voter = electorate[:, voterindex]
                smallutindex = 0
                possibleballots, ballotlookup = stratballotdict(voter, strats, methods[1], baseballots[:, voterindex], infodict)
                brm = ballotresultmap(possibleballots, baseballots, methods, basewinnersets, voter, voterindex, nwinners)
                for method_i in eachindex(methods)
                    for strat_i in eachindex(strats)
                        utiltotals[:, bigutindex + midutindex + smallutindex] += brm[:, ballotlookup[strat_i], method_i]
                        smallutindex += 1
                    end
                end
            end
            midutindex += length(methods)*length(strat_templates)
        end
        bigutindex += length(methods)*length(strat_templates)*length(basestrats)
    end
    return utiltotals  
end

"""
    getadminpollsinput(methodsandstrats)

Convert the vector of (methods, basestrats, strats) tuple to something compatible with administerpolls()
"""
function getadminpollsinput(methodsandstrats)
    total_length = sum(length(basestrats)+length(strats)
                        for (methods, basestrats, strats) in methodsandstrats)
    stratinputs = Vector{Union{VoterStrategy, ElectorateStrategy}}(undef, total_length)
    methodinputs = Vector{VotingMethod}(undef, total_length)
    i = 1
    for (methods, basestrats, strats) in methodsandstrats
        for strat in [basestrats; strats]
            methodinputs[i] = methods[1]
            stratinputs[i] = strat
            i += 1
        end
    end
    return stratinputs, methodinputs
end

"""
    stratballotdict(voter, strats, method, baseballot, infodict)

Create the possible ballots and a mapping from strategy indicies to ballot indicies.

Returns (possibleballots, ballotlookup). possibleballots is an array with all the unique
ballots that are cast under the given strategies.
ballotlookup is a dict s.t. ballotlookup[i] is the index of the ballot cast according to the ith
srategy in possibleballots.

"""
function stratballotdict(voter, strats, method, baseballot, infodict)
    possibleballots = Matrix{ballotmarktype(method)}(undef, getballotsize(method, length(voter)), length(strats)+1)
    possibleballots[:, 1] = baseballot
    ballotlookup = Dict{Int, Int}()
    distinctballots = 1
    for (i, strat) in enumerate(strats)
        ballot = vote(voter, strat, method, infodict[info_used(strat, method)])
        #Check if the ballot has already been cast with another strategy.
        found = false
        for j in 1:distinctballots
            if ballot == possibleballots[:, j]
                ballotlookup[i] = j
                found = true
                break
            end
        end
        if !found
            distinctballots += 1
            possibleballots[:, distinctballots] = ballot
            ballotlookup[i] = distinctballots
        end
    end
    return view(possibleballots, :, 1:distinctballots), ballotlookup
end

"""
    ballotresultmap(possibleballots, bgballots, methods, basewinnersets, voter, voterindex, nwinners)

Create a mapping from (ballot indicies * method indicies) to results

Returns utiltable, where utiltable[metricindex, ballotindex, methodindex] is the utility gained
by casting the ballot at ballotindex instead of using the background strategy.
"""
function ballotresultmap(possibleballots, bgballots, methods, basewinnersets, voter, voterindex, nwinners)
    utiltable = Array{Float64}(undef, numutilmetrics(nwinners), size(possibleballots, 2), length(methods))
    for (m_i, method) in enumerate(methods) #voting method index
        basewinners = basewinnersets[m_i]
        baseutils = calc_utils(voter, basewinners, nwinners)
        for b_i in 1:size(possibleballots, 2) #ballot index
            if b_i == 1
                utiltable[:, b_i, m_i] .= 0.0
            else
                #replace the ballot in bgballots to avoid copying the whole array, then switch it back.
                oldballot = bgballots[:, voterindex]
                bgballots[:, voterindex] = possibleballots[:, b_i]
                winners = getwinners(bgballots, method, nwinners)
                bgballots[:, voterindex] = oldballot
                utiltable[:, b_i, m_i] = calc_utils(voter, winners, nwinners) - baseutils
            end
        end
    end
    return utiltable
end

function num_esif_columns(methodsandstrats)
    return sum(length(basestrats)*length(strats)*length(methods)
               for (methods, basestrats, strats) in methodsandstrats)
end

"""
    buildfromtemplatesforesif(methodsandstrats::Vector, uncertainty::Float64)

Convert electorate strat templates to estrats in methodsandstrats
"""
function buildfromtemplatesforesif(methodsandstrats::Vector, uncertainty::Float64)
    return [(m, [esfromtemplate(basestrat, uncertainty) for basestrat in basestrats], s)
            for (m, basestrats, s) in methodsandstrats]
end