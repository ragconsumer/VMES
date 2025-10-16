"""
Calculate Candidate-Voter Instruction Incentives (CVII)

Determines the incentives for candidates to give various endorsements to one another.
The basic idea is that we model two types of voters: independents, who have
opinions on all the candidates and vote according to their preferences (generated from vmodel)
and an electorate strategy; and loyalists, who don't have meaningful opinions of their own and
vote according to the instructions of their preferred candidate. Each candidate is given the same
number of loyalists, though some will be more popular amoung independents than others.

As a baseline, each candidate instructs their loyalists to vote in accordance with the same
background instruction stategy. We then see whether using different foreground instruction strategies
can make a candidate win instead of lose, or vice versa. We report how effective each foreground
instruction is on a linear scale on which 1 corresponds to just using the background instruction strategy,
and 0 corresponds to telling one's loyalists to cast blank ballots.

# Arguments
- `niter::Integer`: The number of iterations (i.e. randomly generated electorates) of the simulation
- `vmodel::VoterModel`: The voter model used to generate electorates
- `arglist::Vector{Tuple{
   Vector{VotingMethod}, Vector{ElectorateStrategy}, Vector{InstructionSelector},
   Vector{Vector{InstructionStrategy}}, Vector{InstructionStrategy}}}`:
A vector of tuples of the form (methods, voterstrategies, selectors, fgistrats, bgistrats):
   - `methods::Vector{VotingMethod}`: A vector of voting methods
   - `voterstrategies::Vector{ElectorateStrategy}`: A vector of electorate strategies that
      describes how independent voters behave.
   - `bgistrats::Vector{InstructionStrategy}`: The background instruction strategies that all
      candidates use by default.
   - `selectors::Vector{InstructionSelector}`: A vector of instruction selectors. Each of them
      must involve the same number of instructing candidates. (If you want to incorporate selectors
      that use different numbers of instructing candidates, and another tuple to arglist.)
   - `fgistrats::Vector{Vector{InstructionStrategy}}`: The foreground instruction strategies.
      Each element whose ith element gives the instruction strategy used by the ith candidate chosen
      by the selector. Must be the same length as selectors.
CVII is calculated for each possible combination that takes one element from each of the above vectors,
except for selectors and fgistrats, for which selectors[i] is always paired with fgistrats[i].
- `independentvoters::Int`: The number of voters that vote independently, without taking instructions
   from a candidate.
- `loyalists_per_cand::Int` The number of voters assoicated with each candidate, who follow that
   candidate's instructions.
- `ncand::Int` The number of candidates.
- `nwinners::Int` The number of winners of each election.
- `correlatednoise::Real` The amount of correlated polling noise, given in standard deviations. 
- `iidnoise::Real` The amount of uncorrelated polling noise, given in standard deviations.
"""
function calc_cvii(niter::Int,
                   vmodel::VoterModel,
                   arglist::Vector,
                   independentvoters::Int, loyalists_per_cand::Int, ncand::Int,
                   nwinners::Int=1,
                   votercorrelatednoise::Float64=0.1, voteriidnoise::Float64=0.0,
                   candcorrelatednoise::Float64=0.1, candiidnoise::Float64=0.0;
                   iter_per_update=0, seed=abs(rand(Int)))
   threadtotals = [[empty_results(arglist) for _ in 1:Threads.nthreads()] for _ in 1:3]
   top_rng = Random.Xoshiro(seed)
   threadseeds = abs.(rand(top_rng, Int, Threads.nthreads()))
   Threads.@threads for tid in 1:Threads.nthreads()
      iterationsinthread = niter ÷ Threads.nthreads() + (tid <= niter % Threads.nthreads() ? 1 : 0)
      rng = Random.Xoshiro(threadseeds[tid])
      for i in 1:iterationsinthread
         if iter_per_update > 0 && i % iter_per_update == 0
               println("Iteration $i in thread $tid")
         end
         results = one_cvii_iter(vmodel, arglist,
                                 independentvoters, loyalists_per_cand, ncand,
                                 nwinners, votercorrelatednoise, voteriidnoise,
                                 candcorrelatednoise, candiidnoise)
         for i in 1:3
            for j in eachindex(arglist)
               threadtotals[i][tid][j] += results[i][j]
            end
         end
      end
   end
   #sum the results across threads
   totals = [empty_results(arglist) for i in 1:3]
   for i in 1:3
      for thread in 1:Threads.nthreads()
         for j in eachindex(arglist)
            totals[i][j] += threadtotals[i][thread][j]
         end
      end
   end
   return cvii_totals_to_df(arglist, totals...)
end


function one_cvii_iter(vmodel::VoterModel,
                       arglist::Vector,
                       independentvoters::Int, loyalists_per_cand::Int, ncand::Int,
                       nwinners::Int=1,
                       votercorrelatednoise::Float64=0.1, voteriidnoise::Float64=0.0,
                       candcorrelatednoise::Float64=0.1, candiidnoise::Float64=0.0,
                       rng=Random.Xoshiro())
   independents = make_electorate(vmodel, independentvoters, ncand)
   admininput = getadminpollsinput_instruction(arglist, votercorrelatednoise, voteriidnoise,
                                   candcorrelatednoise, candiidnoise)
   noisevector = randn(rng, ncand)
   infodict = administerpolls(independents, admininput, noisevector, nothing, rng)
   bgresults = empty_results(arglist)
   fgresults = empty_results(arglist)
   abstainresults = empty_results(arglist)
   for (argtupleindex, (methods, estrats, bgistrats, selectors, fgistrats)) in enumerate(arglist)
      for (estrat_i, estrat_template) in enumerate(estrats)
         # Create the electorate strategy and cast the independent ballots
         # Note that the independent ballots are cast using the first method in methods.
         estrat = esfromtemplate(estrat_template, hypot(votercorrelatednoise, voteriidnoise))
         independent_ballots = castballots(independents, estrat, methods[1], infodict)
         
         for (bgistrat_i, bgistrat_template) in enumerate(bgistrats)
            # Create the background instruction strategy and cast the base loyalist ballots
            # Note that the base loyalist ballots are cast using the first method in methods.
            bgistrat = isfromtemplate(bgistrat_template, estrat, hypot(candcorrelatednoise, candiidnoise))
            info_for_strat = isnothing(info_used(bgistrat, methods[1])) ? nothing : infodict[info_used(bgistrat, methods[1])]
            base_loyalist_ballots = reduce(hcat, [instruct_votes(i, bgistrat, loyalists_per_cand, ncand, methods[1],
                                          info_for_strat) for i in 1:ncand])
            base_ballots = [independent_ballots base_loyalist_ballots]
            ballots = copy(base_ballots)
            for (method_i, method) in enumerate(methods)
               basewinners = getwinners(ballots, method, nwinners)
               abstain_winners = Matrix{Int}(undef, nwinners, ncand)
               # For each candidate, find the results if that candidate's loyalists abstain
               for cand in 1:ncand
                  ballots[:, independentvoters+(cand-1)*loyalists_per_cand+1:independentvoters+(cand)*loyalists_per_cand] =
                     instruct_votes(cand, abstaininstruction, loyalists_per_cand, ncand, method)
                  abstain_winners[:, cand] = getwinners(ballots, method, nwinners)
                  ballots[:, independentvoters+(cand-1)*loyalists_per_cand+1:independentvoters+(cand)*loyalists_per_cand] =
                     base_ballots[:, independentvoters+(cand-1)*loyalists_per_cand+1:independentvoters+(cand)*loyalists_per_cand]
               end
               for (selector_i, (selector_template, fgistratvector)) in enumerate(zip(selectors, fgistrats))
                  # Choose the instructors and candidates to track
                  selector = selectorfromtemplate(selector_template, estrat, hypot(candcorrelatednoise, candiidnoise))
                  instructors, cands_to_track, targets = select_instructors_and_trackees(
                     selector, methods[1], infodict[info_used(selector)])
                  # Copy the ballots so that we can reset them later
                  oldballots = [ballots[:,
                     independentvoters+(cand_i-1)*loyalists_per_cand+1:independentvoters+(cand_i)*loyalists_per_cand]
                     for cand_i in instructors]
                  # For each instructor, cast the ballots according to the foreground instruction strategy
                  for (position, istrat_template) in zip(instructors, fgistratvector)
                     istrat = isfromtemplate(istrat_template, estrat, hypot(candcorrelatednoise, candiidnoise))
                     info_for_strat = isnothing(info_used(istrat, methods[1])) ? nothing : infodict[info_used(istrat, methods[1])]
                     ballots[:, independentvoters+(position-1)*loyalists_per_cand+1:independentvoters+(position)*loyalists_per_cand] =
                        instruct_votes(position, istrat, loyalists_per_cand, ncand, methods[1], info_for_strat, targets[position]...)
                  end
                  new_winners = getwinners(ballots, method, nwinners)
                  # Record the results
                  for (cand_position, cand) in enumerate(cands_to_track)
                     if cand in new_winners
                        fgresults[argtupleindex][method_i, estrat_i, bgistrat_i,
                           selector_i, cand_position] = 1
                     end
                     if cand in basewinners
                        bgresults[argtupleindex][method_i, estrat_i, bgistrat_i,
                           selector_i, cand_position] = 1
                     end
                     if cand in abstain_winners[:, cand]
                        abstainresults[argtupleindex][method_i, estrat_i, bgistrat_i,
                           selector_i, cand_position] = 1
                     end
                  end
                  #reset the ballots
                  for cand_i in instructors
                     ballots[:, independentvoters+(cand_i-1)*loyalists_per_cand+1:independentvoters+(cand_i)*loyalists_per_cand] =
                        oldballots[cand_i]
                  end
               end
            end
         end
      end
   end
   return fgresults, bgresults, abstainresults
end

function getadminpollsinput_instruction(arglist, votercorrelatednoise::Float64, voteriidnoise::Float64,
                                        candcorrelatednoise::Float64, candiidnoise::Float64)
   total_length = sum(length(estrats)*(1 + (length(bgistrats)*
                        (1 + length(methods)*length(fgistrats) + sum(length(fgis) for fgis in fgistrats))))
                        for (methods, estrats, bgistrats, selectors, fgistrats) in arglist)
   maininputs = Vector{Union{ElectorateStrategy, InstructionStrategy, InstructionSelector}}(undef, total_length)
   methodinputs = Vector{VotingMethod}(undef, total_length)
   correlated_noise_inputs = Vector{Float64}(undef, total_length)
   iid_noise_inputs = Vector{Float64}(undef, total_length)
   voter_uncertainty = hypot(votercorrelatednoise, voteriidnoise)
   candidate_uncertainty = hypot(candcorrelatednoise, candiidnoise)
   i = 1
   for (methods, estrats, bgistrats, selectors, fgistrats) in arglist
      for estrat in estrats
         methodinputs[i] = methods[1]
         maininputs[i] = esfromtemplate(estrat, voter_uncertainty)
         correlated_noise_inputs[i] = votercorrelatednoise
         iid_noise_inputs[i] = voteriidnoise
         i += 1
         for bgistrat in bgistrats
            methodinputs[i] = methods[1]
            maininputs[i] = isfromtemplate(bgistrat, estrat, candidate_uncertainty)
            correlated_noise_inputs[i] = candcorrelatednoise
            iid_noise_inputs[i] = candiidnoise
            i += 1
            for (selector, fgistrats_for_selector) in zip(selectors, fgistrats)
               for method in methods
                  methodinputs[i] = method
                  maininputs[i] = selectorfromtemplate(selector, estrat, candidate_uncertainty)
                  correlated_noise_inputs[i] = candcorrelatednoise
                  iid_noise_inputs[i] = candiidnoise
                  i += 1
               end
               for fgistrat in fgistrats_for_selector
                  methodinputs[i] = methods[1]
                  maininputs[i] = isfromtemplate(fgistrat, estrat, candidate_uncertainty)
                  correlated_noise_inputs[i] = candcorrelatednoise
                  iid_noise_inputs[i] = candiidnoise
                  i += 1
               end
            end
         end
      end
   end
   return maininputs, methodinputs, correlated_noise_inputs, iid_noise_inputs
end

function empty_results(arglist::Vector)
   [zeros(Int, length(methods), length(estrats), length(bgistrats),
         length(selectors), maximum(num_trackees(s) for s in selectors))
         for (methods, estrats, bgistrats,selectors, fgistrats) in arglist]
end

function cvii_totals_to_df(arglist::Vector, fgtotals::Vector,
                           bgtotals::Vector, abstaintotals::Vector)
   # Convert the totals to a DataFrame
   df = DataFrame("Method"=> String[],
                  "FG Instructions" => String[],
                  "Position" => Int[],
                  "CVII" => Float64[],
                  "Selector" => String[],
                  "BG Instruction" => String[],
                  "EStrat" => String[],
                  "FG Wins" => Int[],
                  "BG Wins" => Int[],
                  "Abstain Wins" => Int[])
   for (i, (methods, estrats, bgistrats, selectors, fgistrats)) in enumerate(arglist)
      for (method_i, method) in enumerate(methods)
         for (estrat_i, estrat) in enumerate(estrats)
            for (bgistrat_i, bgistrat) in enumerate(bgistrats)
               for (selector_i, selector) in enumerate(selectors)
                  for position in 1:num_trackees(selector)
                     fgwins = fgtotals[i][method_i, estrat_i, bgistrat_i, selector_i, position]
                     bgwins = bgtotals[i][method_i, estrat_i, bgistrat_i, selector_i, position]
                     abstainwins = abstaintotals[i][method_i, estrat_i, bgistrat_i, selector_i, position]
                     row = Dict(
                        "Method" => string(method),
                        "EStrat" => string(estrat),
                        "BG Instruction" => string(bgistrat),
                        "Selector" => string(selector),
                        "FG Instructions" => string([fgistrat for fgistrat in fgistrats[selector_i]]...),
                        "Position" => position,
                        "FG Wins" => fgwins,
                        "BG Wins" => bgwins,
                        "Abstain Wins" => abstainwins,
                        "CVII" => bgwins != abstainwins ? (fgwins - abstainwins)/(bgwins - abstainwins) - 1 : missing
                     )
                     push!(df, row)
                  end
               end
            end
         end
      end
   end
   return df
end