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
"""

function vse_ncand_chart(df::DataFrame)
    df2 = copy(df)
    df2.Method = string.(df2.Method)
    plot(df2, x=:ncand, y=:VSE, color=:Method, Geom.point, Geom.line, Guide.xlabel("Number of candidates"),
        Guide.colorkey(title="Method", labels=["Choose One", "Choosen One + Top 2","Approval","Approval Top 2","RCV","STAR","Ranked Robin"]))
end

"""
stratdf = VMES.calc_vses(10000, VMES.dcc, repeat([VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.star, VMES.rankedrobin], 21), reduce(vcat, [repeat([VMES.ElectorateStrategy(VMES.hon, 0, 1000-k, k)], 7) for k in 0:50:1000]), 1000, 6)
"""

function vse_bullet_chart(df::DataFrame)
    df2 = copy(df)
    df2.Method = string.(df2.Method)
    df2.estrat = string.(df2[!,"Electorate Strategy"])
    df2.bullets = bulletfraction.(df2.estrat,df2.nvot)
    plot(df2, x=:bullets, y=:VSE, color=:Method, Geom.point, Geom.line,
        Guide.xlabel("% non-strategic bullet voters"),
        Guide.colorkey(title="Method", labels=["Choose One", "Choosen One + Top 2","Approval","Approval Top 2","RCV","STAR","Ranked Robin"]))
end

function bulletfraction(estratstr::String, nvot::Int)
    r = r"(BulletVote:)([0-9]+)"
    nbullet = parse(Int, match(r, estratstr).captures[2])
    return nbullet*100/nvot
end

"""
vadf = VMES.calc_vses(100, VMES.dcc,
    repeat([VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.star], 21),
    reduce(vcat, [reduce(vcat, [VMES.ESTemplate(0, [[(VMES.hon,1,100)], [(VMES.pluralityvatemplate, 1, k)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,100)], [(VMES.pluralityvatemplate, 1, k)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,100)], [(VMES.approvalvatemplate, 1, k)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,100)], [(VMES.approvalvatemplate, 1, k)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,100)], [(VMES.irvvatemplate, 1, k)]]),
        VMES.ESTemplate(0, [[(VMES.hon,1,100)], [(VMES.starvatemplate, 1, k)]])]) for k in 0:5:100]),
        100, 6)
"""

function vse_va_chart(df::DataFrame)
    df2 = copy(df)
    df2.Method = string.(df2.Method)
    df2.estrat = string.(df2[!,"Electorate Strategy"])
    df2.vas = vafraction.(df2.estrat,df2.nvot)
    plot(df2, x=:vas, y=:VSE, color=:Method, Geom.point, Geom.line,
        Guide.xlabel("% viability-aware"),
        Guide.colorkey(title="Method", labels=["Choose One", "Choosen One + Top 2","Approval","Approval Top 2","RCV","STAR"]))
end

function vafraction(estratstr::String, nvot::Int)
    r = r"VA(\[.*\])?:([0-9]+)"
    nva = parse(Int, match(r, estratstr).captures[2])
    return nva*100/nvot
end
"""
df = VMES.calc_cid(100, VMES.dcc,
    [VMES.plurality, VMES.pluralitytop2, VMES.approval, VMES.approvaltop2, VMES.rcv, VMES.star, VMES.rankedrobin],
    repeat([VMES.ElectorateStrategy(VMES.hon, 72)], 7), 24, 6)
"""
function cidmethodchart(df::DataFrame)
    df = copy(df)
    df.Method = string.(df.Method)
    df.estrat = string.(df[!,"Electorate Strategy"])
    df.x = (df.Bucket.-1)/(df[1, "Total Buckets"]-1)
    plot(df, x=:x, y=:CID, color=:Method, Geom.line,
         Scale.x_continuous(labels = cidxticklabel), Scale.y_continuous(labels = cidyticklabel),
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
         Coord.cartesian(xmin=minimum(distancedf.ncand)), Guide.colorkey(title="Method", labels=[
         "Choose One", "Choosen One + Top 2","Approval","Approval + Top 2","Ranked Choice","Ranked Robin","STAR"]),
         Scale.color_discrete_manual("#D55E00","#E69F00","#0072B2","#56B4E9","#009E73","#CC79A7","#F0E442"))
end