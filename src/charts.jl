"""
df = vcat([VMES.calc_vses(10000, VMES.dcc, [VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.borda, VMES.score, VMES.star, VMES.minimax, VMES.rankedrobin], repeat([VMES.ElectorateStrategy(VMES.hon, 100)], 10), 100, m) for m in 2:7]...)

dfmixedncands = vcat([VMES.calc_vses(1000, VMES.dcc,
    [VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.star, VMES.rankedrobin],
    [VMES.ESTemplate(0, [[(VMES.hon,1,75), (VMES.bullet, 76,100)], [(VMES.pluralityvatemplate, 1, 25)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,75), (VMES.bullet, 76,100)], [(VMES.pluralityvatemplate, 1, 25)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,75), (VMES.bullet, 76,100)], [(VMES.approvalvatemplate, 1, 25)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,75), (VMES.bullet, 76,100)], [(VMES.approvalvatemplate, 1, 25)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,75), (VMES.bullet, 76,100)], [(VMES.irvvatemplate, 1, 25)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,75), (VMES.bullet, 76,100)], [(VMES.starvatemplate, 1, 25)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,75), (VMES.bullet, 76,100)]])],
    100, n) for n in 2:7]...)

df3types = vcat([VMES.calc_vses(30000, VMES.dcc,
    [VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.star, VMES.rankedrobin],
    [VMES.ESTemplate(1000, [[(VMES.hon, 1, 710), (VMES.bullet, 711, 1000)], [(strat_temp, 1, 200)]]) for strat_temp in
        [VMES.pluralityvatemplate, VMES.pluralitytop2vatemplate, VMES.approvalvatemplate, VMES.approvaltop2vatemplate,
        VMES.irvvatemplate, VMES.starvatemplate, VMES.condorcetva]],
    1000, n) for n in 2:7]...)
"""

function vse_ncand_chart(df::DataFrame)
    df2 = copy(df)
    df2.Method = string.(df2.Method)
    plot(df2, x=:ncand, y=:VSE, color=:Method, Geom.line, Guide.xlabel("Number of candidates"),
        Guide.ylabel("Voter Satisfaction Efficiency"),
        Theme(major_label_color="black", minor_label_color="black", key_label_color="black"),
        Scale.y_continuous(labels=vse -> "$(round(Int, vse*100))%"),
        Guide.colorkey(title="Method",
            labels=["Choose One", "Choosen One + Top 2","Approval","Approval + Top 2","RCV","STAR","Ranked Robin"]),
        Scale.color_discrete_manual("#D55E00","#E69F00","#0072B2","#56B4E9","#009E73","#CC79A7","#F0E442"))
end
function vse_ncand_chart_no_plurality(df::DataFrame)
    df2 = copy(df)
    df2.Method = string.(df2.Method)
    plot(df2, x=:ncand, y=:VSE, color=:Method, Geom.line, Guide.xlabel("Number of candidates"),
        Guide.ylabel("Voter Satisfaction Efficiency"),
        Theme(major_label_color="black", minor_label_color="black", key_label_color="black"),
        Scale.y_continuous(labels=vse -> "$(round(Int, vse*100))%"),
        Guide.colorkey(title="Method",
            labels=["Choosen One + Top 2","Approval","Approval + Top 2","RCV","STAR","Ranked Robin"]),
        Scale.color_discrete_manual("#E69F00","#0072B2","#56B4E9","#009E73","#CC79A7","#F0E442"))
end

"""
stratdf = VMES.calc_vses(10000, VMES.dcc, repeat([VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.star, VMES.rankedrobin], 21), reduce(vcat, [repeat([VMES.ElectorateStrategy(VMES.hon, 0, 1000-k, k)], 7) for k in 0:50:1000]), 1000, 5)
"""

function vse_bullet_chart(df::DataFrame)
    df2 = copy(df)
    df2.Method = string.(df2.Method)
    df2.estrat = string.(df2[!,"Electorate Strategy"])
    df2.bullets = bulletfraction.(df2.estrat,df2.nvot)
    plot(df2, x=:bullets, y=:VSE, color=:Method, Geom.point, Geom.line,
        Guide.xlabel("% non-strategic bullet voters"),
        Theme(major_label_color="black", minor_label_color="black", key_label_color="black"),
        Guide.colorkey(title="Method", labels=["Choose One", "Choosen One + Top 2","Approval","Approval + Top 2","RCV","STAR","Ranked Robin"]))
end

"""
vadf = VMES.calc_vses(100, VMES.dcc,
    repeat([VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.star], 21),
    reduce(vcat, [reduce(vcat, [VMES.ESTemplate(0, [[(VMES.hon,1,100)], [(VMES.pluralityvatemplate, 1, k)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,100)], [(VMES.pluralitytop2vatemplate, 1, k)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,100)], [(VMES.approvalvatemplate, 1, k)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,100)], [(VMES.approvaltop2vatemplate, 1, k)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,100)], [(VMES.irvvatemplate, 1, k)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,100)], [(VMES.starvatemplate, 1, k)]])]) for k in 0:5:100]),
        100, 5)
"""

function vse_va_chart(df::DataFrame)
    df2 = copy(df)
    df2.Method = string.(df2.Method)
    df2.estrat = string.(df2[!,"Electorate Strategy"])
    df2.vas = vafraction.(df2.estrat,df2.nvot)
    plot(df2, x=:vas, y=:VSE, color=:Method, Geom.line,
        Guide.xlabel("% viability-aware"),
        Theme(major_label_color="black", minor_label_color="black", key_label_color="black"),
        Guide.colorkey(title="Method", labels=[
            "Choose One", "Choosen One + Top 2","Approval","Approval + Top 2","Ranked Choice","STAR"]),
        Scale.color_discrete_manual("#D55E00","#E69F00","#0072B2","#56B4E9","#009E73","#F0E442"))
end

function vafraction(estratstr::String, nvot::Int)
    r = r"VA(\[.*\])?:([0-9]+)"
    nva = parse(Int, match(r, estratstr).captures[2])
    return nva*100/nvot
end

function bulletfraction(estratstr::String, nvot::Int)
    r = r"BulletVote:([0-9]+)"
    nbullet = parse(Int, match(r, estratstr).captures[1])
    return nbullet*100/nvot
end

"""
df = VMES.calc_cid(1000, VMES.dcc,
    [VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.star, VMES.rankedrobin],
    repeat([VMES.ElectorateStrategy(VMES.hon, 72)], 7), 24, 5)
"""
function cidmethodchart(df::DataFrame)
    df = copy(df)
    df.Method = string.(df.Method)
    df.estrat = string.(df[!,"Electorate Strategy"])
    df.x = (df.Bucket.-1)/(df[1, "Total Buckets"]-1)
    plot(df, x=:x, y=:CID, color=:Method, Geom.line,
         Scale.x_continuous(labels = cidxticklabel), Scale.y_continuous(labels = cidyticklabel),
         Theme(major_label_color="black", minor_label_color="black", key_label_color="black"),
         Guide.xlabel("Voter's support for candidate"),
         Guide.ylabel("Candidate's incentive to appeal to voter"),
         Guide.colorkey(title="Method", labels=[
            "Choose One", "Choosen One + Top 2","Approval","Approval + Top 2","Ranked Choice","Ranked Robin","STAR"]),
         Scale.color_discrete_manual("#D55E00","#E69F00","#0072B2","#56B4E9","#009E73","#CC79A7","#F0E442"))
end

function cidyticklabel(y::Real)
    if y == 1
        return "Average"
    elseif y == 0
        return "0"
    elseif isinteger(y)
        return string(Int(y), "x Avg")
    else
        string(y, "xAvg")
    end
end

cidxticklabel(x::Real) = string(round(Int, x*100), "%")

#=
df = VMES.calc_cid(5000, VMES.dcc,
    [VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.score, VMES.star, VMES.minimax],
    repeat([VMES.ElectorateStrategy(VMES.hon, 72)], 8), 24, 5)

df = VMES.calc_cid(500, VMES.dcc,
    [VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.score, VMES.star, VMES.minimax],
    [VMES.ESTemplate(72, [[(VMES.hon, 1, 72)], [(strat_temp, 1, 72)]]) for strat_temp in
        [VMES.pluralityvatemplate, VMES.pluralitytop2vatemplate, VMES.approvalvatemplate, VMES.approvaltop2vatemplate,
    VMES.irvvatemplate, VMES.BasicWinProbTemplate(VMES.ApprovalVA, VMES.score, []), VMES.starvatemplate, VMES.hon]], 24, 5)

df = VMES.calc_cid(500, VMES.dcc,
    [VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.score, VMES.star, VMES.minimax],
    repeat([VMES.ESTemplate(72, [[(VMES.bullet, 1, 21), (VMES.hon, 22, 72)]])], 8), 24, 5)

df = VMES.calc_cid(50, VMES.dcc,
    repeat([VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.score, VMES.star, VMES.minimax], 2),
    vcat(repeat([VMES.ElectorateStrategy(VMES.hon, 72)], 8),
        repeat([VMES.ESTemplate(72, [[(VMES.bullet, 1, 21), (VMES.hon, 22, 72)]])], 8)),
    24, 5)
=#
function cidchartpaper(df::DataFrame)
    df = copy(df)
    df.Method = string.(df.Method)
    df.estrat = string.(df[!,"Electorate Strategy"])
    df.x = (df.Bucket.-1)/(df[1, "Total Buckets"]-1)
    plot(df, x=:x, y=:CID, color=:Method, Geom.line,
            Scale.x_continuous(labels = cidxticklabel),
            Theme(major_label_color="black", minor_label_color="black", key_label_color="black"),
            Guide.xlabel("Voter's support for candidate"),
            Guide.ylabel("Candidate's incentive to appeal to voter"),
            Guide.colorkey(title="Method", labels=[
            "Plurality", "Plurality Top 2","Approval","Approval Top 2","IRV","Score","STAR","Minimax"]),
            Scale.color_discrete_manual("#D55E00","#E69F00","#0072B2","#56B4E9","#009E73","#CC79A7","#F0E442","black"))
end

"""
cidlist = ([VMES.calc_cid(1000, VMES.dcc,
    [VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.rankedrobin, VMES.star],
    repeat([VMES.ElectorateStrategy(VMES.hon, 72)], 7), 24, m) for m in 2:10])
bigdf = reduce(vcat, cidlist)
"""
function cid_cdf_ncand_chart(df, threshold)
    influencedf = influence_cdf(df, threshold)
    influencedf.Method = string.(influencedf.Method)
    influencedf.estrat = string.(influencedf[!,"Electorate Strategy"])
    plot(influencedf, x=:ncand, y="CS$threshold", color=:Method, Geom.point, Geom.line,
         Guide.xlabel("Number of candidates"),
         Theme(major_label_color="black", minor_label_color="black", key_label_color="black"),
         #Guide.ylabel("Incentive to appeal to least supportive $(Int(threshold*100)) of voters"),
         Coord.cartesian(xmin=minimum(influencedf.ncand)), Guide.colorkey(title="Method", labels=[
         "Choose One", "Choosen One + Top 2","Approval","Approval + Top 2","Ranked Choice","Ranked Robin","STAR"]),
         Scale.color_discrete_manual("#D55E00","#E69F00","#0072B2","#56B4E9","#009E73","#CC79A7","#F0E442"))
end

function cid_distance_ncand_chart(df, distance_metric)
    distancedf = distance_from_uniform(distance_metric, df)
    distancedf.Method = string.(distancedf.Method)
    distancedf.estrat = string.(distancedf[!,"Electorate Strategy"])
    plot(distancedf, x=:ncand, y=:DFU, color=:Method, Geom.point, Geom.line,
         Guide.xlabel("Number of candidates"), Guide.ylabel("Deviation from uniform incentives"),
         Theme(major_label_color="black", minor_label_color="black", key_label_color="black"),
         Coord.cartesian(xmin=minimum(distancedf.ncand)), Guide.colorkey(title="Method", labels=[
         "Choose One", "Choosen One + Top 2","Approval","Approval + Top 2","Ranked Choice","Ranked Robin","STAR"]),
         Scale.color_discrete_manual("#D55E00","#E69F00","#0072B2","#56B4E9","#009E73","#CC79A7","#F0E442"))
end

"""
dfs = [VMES.calc_cid(100, VMES.dcc,
    [VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.score, VMES.star, VMES.minimax],
    repeat([VMES.ElectorateStrategy(VMES.hon, 72)], 8), 24, m) for m in 3:10]
"""
function paper_distance_ncand_chart(dfarray::Array)
    df = vcat(dfarray...)
    distancedf = distance_from_uniform(earth_movers_distance_from_uniform, df)
    distancedf.Method = string.(distancedf.Method)
    distancedf.estrat = string.(distancedf[!,"Electorate Strategy"])
    plot(distancedf, x=:ncand, y=:DFU, color=:Method, Geom.point, Geom.line,
         Guide.xlabel("Number of candidates"), Guide.ylabel("Earth Mover's Distance"),
         Theme(major_label_color="black", minor_label_color="black", key_label_color="black"),
         Coord.cartesian(xmin=minimum(distancedf.ncand)), Guide.colorkey(title="Method", labels=[
            "Plurality", "Plurality Top 2","Approval","Approval Top 2","IRV","Score","STAR","Minimax"]),
        Scale.color_discrete_manual("#D55E00","#E69F00","#0072B2","#56B4E9","#009E73","#CC79A7","#F0E442","black"))
end

"""
df = VMES.calc_cid(1000, VMES.dcc,
    repeat([VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2,
        VMES.rcv, VMES.score, VMES.star, VMES.minimax], 13),
    [VMES.ESTemplate(72, [[(VMES.hon, 1, 72)], [(strat_temp, 1, m)]]) for m in 0:6:72 for strat_temp in
        [VMES.pluralityvatemplate, VMES.pluralitytop2vatemplate, VMES.approvalvatemplate, VMES.approvaltop2vatemplate,
        VMES.irvvatemplate, VMES.BasicWinProbTemplate(VMES.ApprovalVA, VMES.score, []), VMES.starvatemplate, VMES.condorcetva]],
    24, 5)
"""
function paper_vafraction_chart(df)
    distancedf = distance_from_uniform(earth_movers_distance_from_uniform, df)
    distancedf.Method = string.(distancedf.Method)
    distancedf.estrat = string.(distancedf[!,"Electorate Strategy"])
    distancedf.vas = vafraction.(distancedf.estrat, df[1, "Total Buckets"]*df[1, "Voters per Bucket"])
    plot(distancedf, x=:vas, y=:DFU, color=:Method, Geom.line,
         Guide.xlabel("% viability-aware"), Guide.ylabel("Earth Mover's Distance"),
         Theme(major_label_color="black", minor_label_color="black", key_label_color="black"),
         Coord.cartesian(xmin=minimum(distancedf.ncand)), Guide.colorkey(title="Method", labels=[
            "Plurality", "Plurality Top 2","Approval","Approval Top 2","IRV","Score","STAR","Minimax"]),
        Scale.color_discrete_manual("#D55E00","#E69F00","#0072B2","#56B4E9","#009E73","#CC79A7","#F0E442","black"))
end

"""
bulletdf = VMES.calc_cid(5000, VMES.dcc,
           repeat([VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2,
               VMES.rcv, VMES.score, VMES.star, VMES.minimax], 13),
           vcat([repeat([VMES.ESTemplate(72, [[(VMES.bullet, 1, m), (VMES.hon, m+1, 72)]])], 8) for m in 0:6:72]...),
           24, 5)
"""
function paper_bullet_fraction_chart(df)
    distancedf = distance_from_uniform(earth_movers_distance_from_uniform, df)
    distancedf.Method = string.(distancedf.Method)
    distancedf.estrat = string.(distancedf[!,"Electorate Strategy"])
    distancedf.bullets = bulletfraction.(distancedf.estrat, df[1, "Total Buckets"]*df[1, "Voters per Bucket"])
    plot(distancedf, x=:bullets, y=:DFU, color=:Method, Geom.line,
         Guide.xlabel("% dogmatic bullet voters"), Guide.ylabel("Earth Mover's Distance"),
         Theme(major_label_color="black", minor_label_color="black", key_label_color="black"),
         Coord.cartesian(xmin=minimum(distancedf.ncand)), Guide.colorkey(title="Method", labels=[
            "Plurality", "Plurality Top 2","Approval","Approval Top 2","IRV","Score","STAR","Minimax"]),
        Scale.color_discrete_manual("#D55E00","#E69F00","#0072B2","#56B4E9","#009E73","#CC79A7","#F0E442","black"))
end

"""
df = VMES.calc_esif(1000, VMES.dcc,
    [([VMES.star], [VMES.ElectorateStrategy(VMES.ExpScale(x), 31) for x in 1:0.2:5],
        [VMES.ExpScale(x) for x in 1:0.2:5])],
    31, 5)
df = VMES.calc_esif(10, VMES.dcc,
    [([VMES.sss, VMES.mesdroop, VMES.teadroop, VMES.ashare, VMES.allocatedscore, VMES.ashfr, VMES.ashr, VMES.asr, VMES.s5h, VMES.s5hr, VMES.s5hwr], [VMES.ElectorateStrategy(VMES.ExpScale(2^x), 25) for x in 1:0.4:4.2],
        [VMES.ExpScale(2^x) for x in 1:0.2:4.2])], 25, 10, nwinners=4, iter_per_update=1)
"""
function esif_contour_chart(df, parsefunc)
    df.estrat = string.(df[!,"Base Strategy"])
    df.strat = string.(df[!,"Strategy"])
    df[!, "Background Value"] = parsefunc.(df.estrat)
    df[!, "User's Value"] = parsefunc.(df.strat)
    gdf = groupby(df, Symbol("Background Value"))
    bestvaluedf = combine(gdf, ["User's Value", "ESIF"] =>
                              ((v, e) -> v[argmax(e)]) => :Maximum)
    linelayer = layer(bestvaluedf, x=Symbol("Background Value"), y=:Maximum,
                    Geom.line, Geom.point)
    contours = layer(df, x=Symbol("Background Value"), y=Symbol("User's Value"), z=:ESIF, Geom.contour)
    plot(contours, linelayer,
        Coord.cartesian(xmin=minimum(df[!, "Background Value"]), ymin=minimum(df[!, "User's Value"])),
        Theme(major_label_color="black", minor_label_color="black", key_label_color="black"))
end

function esif_basic_chart(df, parsefunc)
    df.strat = string.(df[!,"Strategy"])
    df[!, "User's Value"] = parsefunc.(df.strat)
    plot(df, x="User's Value", y=:ESIF, Geom.line,
        Theme(major_label_color="black", minor_label_color="black", key_label_color="black"))
end

"""
df = VMES.calc_esif(1000, VMES.dcc,
    [([VMES.irv], [VMES.ElectorateStrategy(VMES.hon, 31)],
        [VMES.ApprovalWinProbTemplate(VMES.IRVVA, 0.1, VMES.TopMeanThreshold(x), [0.0]) for x in -0.2:0.05:.5]),
    ([VMES.pluralitytop2], [VMES.ElectorateStrategy(VMES.hon, 31)],
        [VMES.ApprovalWinProbTemplate(VMES.PluralityTop2VA, 0.1, VMES.TopMeanThreshold(x), []) for x in -0.2:0.05:.5]),
    ([VMES.approvaltop2], [VMES.ElectorateStrategy(VMES.hon, 31)],
        [VMES.ApprovalWinProbTemplate(VMES.ApprovalTop2VA, 0.1, VMES.TopMeanThreshold(x), []) for x in -0.2:0.05:.5])],
    31, 5)
"""
function esif_multimethod_chart(df, parsefunc, xlabel="User's Value")
    df.strat = string.(df[!,"Strategy"])
    df.Method = string.(df.Method)
    df[!, "User's Value"] = parsefunc.(df.strat)
    plot(df, x="User's Value", y=:ESIF, color=:Method, Geom.line,
        Guide.xlabel(xlabel),
        Theme(major_label_color="black", minor_label_color="black", key_label_color="black"),
        Coord.cartesian(xmax=maximum(df[!,"User's Value"])), Guide.colorkey(title="Method", labels=[
            "IRV", "Plurality Top 2", "Approval Top 2"]),
        Scale.color_discrete_manual("#009E73","#E69F00","#56B4E9")
        )
end

function parse_expscale(str)
    r = r"ex(\d*\.\d*)"
    parse(Float64, match(r, str).captures[1])
end

function parse_threshold(str)
    r = r"hreshold\((-?\d*\.\d*)\)"
    parse(Float64, match(r, str).captures[1])
end

function parse_template_arg(str)
    r = r"Any\[(\d*\.\d*)\]"
    parse(Float64, match(r, str).captures[1])
end



#=
df75 = VMES.calc_esif(50000, VMES.dcc,
[([VMES.plurality], [VMES.ElectorateStrategy(VMES.hon, 75)], [VMES.plurality_pos_template, VMES.pluralityvatemplate]),
([VMES.approval], [VMES.ElectorateStrategy(VMES.hon, 75)],
    [VMES.approval_pos_template, VMES.approvalvatemplate,
    VMES.PositionalStratTemplate(VMES.PluralityPositional, VMES.BasicPollSpec, VMES.approval, 2, 0, [])]),
([VMES.pluralitytop2], [VMES.ElectorateStrategy(VMES.hon, 75)],
    [VMES.pluralitytop2_pos_template(false, false, false),
    VMES.pluralitytop2_pos_template(true, false, false),
    VMES.pluralitytop2_pos_template(true, true, false),
    VMES.pluralitytop2_pos_template(false, false, true),
    VMES.pluralitytop2vatemplate]),
([VMES.approvaltop2], [VMES.ElectorateStrategy(VMES.hon, 75)],
    [VMES.approvaltop2_pos_template(false, false),
    VMES.approvaltop2_pos_template(true, false),
    VMES.approvaltop2_pos_template(false, true),
    VMES.approvaltop2_pos_template(true, true),
    VMES.approvaltop2vatemplate]),
([VMES.irv], [VMES.ElectorateStrategy(VMES.hon, 75)],
    [VMES.irv_pos_template(false, false, false),
    VMES.irv_pos_template(true, false, false),
    VMES.irv_pos_template(true, true, false),
    VMES.irv_pos_template(false, false, true),
    VMES.irv_pos_template(true, false, true),
    VMES.irvvatemplate]),
([VMES.star], [VMES.ElectorateStrategy(VMES.hon, 75)],
    [VMES.star_pos_template(false, false),
    VMES.star_pos_template(true, false),
    VMES.star_pos_template(false, true),
    VMES.star_pos_template(true, true),
    VMES.starvatemplate])
],
75, 5, correlatednoise=0.05)
=#
