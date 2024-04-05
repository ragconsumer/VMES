#This file is not included in VMES.jl
#It is intended as a repository for code that can be copied-pasted into the REPL

@time df = VMES.calc_esif(10000, VMES.dcc,
    [([VMES.sss, VMES.mesdroop, VMES.teadroop, VMES.ashare, VMES.allocatedscore,
            VMES.ashfr, VMES.ashr, VMES.ashu, VMES.asr, VMES.s5h, VMES.s5hr, VMES.s5hwr, VMES.scv, VMES.scvr],
        [VMES.ElectorateStrategy(VMES.ExpScale(2^x), 29) for x in 1:0.4:4.2],
        [[VMES.ExpScale(2^x) for x in 1:0.2:4.2]; VMES.hon])], 29, 10, nwinners=4, iter_per_update=100)


fdf = subset(df, [:Metric, :Strategy] => (x,y) -> x.=="Median Winner" .&& y .!= [VMES.hon] .&& y != "hon") 
gdf = groupby(fdf, :Method)
VMES.esif_contour_chart(gdf[1], VMES.parse_expscale)

@time df = VMES.calc_esif(10000, VMES.dcc,
    [([VMES.spav, VMES.spav_sl, VMES.spav_msl, VMES.mesapproval, VMES.mesapprovaldroop],
        [VMES.ElectorateStrategy(VMES.TopMeanThreshold(x), 25) for x in 0.5:0.05:1],
        [VMES.TopMeanThreshold(x) for x in 0.5:0.05:1])], 25, 10, nwinners=4, iter_per_update=100)

@time df = VMES.calc_esif(10000, VMES.dcc,
    [([VMES.sss, VMES.mesdroop, VMES.teadroop, VMES.ashare, VMES.allocatedscore,
            VMES.ashfr, VMES.ashr, VMES.ashu, VMES.asr, VMES.s5h, VMES.s5hr, VMES.s5hwr, VMES.scv, VMES.scvr],
        [VMES.ElectorateStrategy(VMES.ExpScale(4), 29)],
        [[VMES.ExpScale(2^x) for x in 1:0.2:4.6]; VMES.hon;[VMES.TopMeanThreshold(x) for x in 0.5:0.02:1]])],
        29, 10, nwinners=4, iter_per_update=100)

@time df2 = VMES.calc_vses(3000, VMES.dcc,
    repeat([VMES.blockstar, VMES.ashare, VMES.allocatedscore,
        VMES.scv, VMES.sss, VMES.s5hr, VMES.tea, VMES.scvr], 41),
    [repeat([VMES.ElectorateStrategy(VMES.hon, 100)], 8)
    reduce(vcat,([repeat([VMES.ElectorateStrategy(VMES.ExpScale(2^x), 100)], 8) for x in 0.4:0.2:4.2]))
    reduce(vcat,([repeat([
        VMES.ESTemplate(100, [[(VMES.bullet, 1, 20), (VMES.hon, 21, 40), (VMES.ExpScale(2^x), 41, 100)]])], 8)
    for x in 0.4:0.2:4.2]))],
    100, 10, 4)

@time df = VMES.calc_vses(3000, VMES.dcc,
    repeat([VMES.blockstar, VMES.ashare, VMES.allocatedscore,
        VMES.scv, VMES.sss, VMES.s5hr, VMES.tea, VMES.scvr], 20),
    reduce(vcat,([repeat([VMES.ElectorateStrategy(VMES.ExpScale(2^x), 100)], 8) for x in 0.4:0.2:4.2])),
    100, 10, 4)

@time df2 = VMES.calc_vses(3000, VMES.dcc,
    repeat([VMES.blockstar, VMES.ashare, VMES.allocatedscore,
        VMES.scv, VMES.sss, VMES.s5hr, VMES.tea, VMES.scvr], 20),
    reduce(vcat,([repeat([
            VMES.ESTemplate(100, [[(VMES.bullet, 1, 20), (VMES.hon, 21, 40), (VMES.ExpScale(2^x), 41, 100)]])], 8)
        for x in 0.4:0.2:4.2])),
    100, 10, 4)

@time df = VMES.calc_cid(1000, VMES.dcc,
    [VMES.LimitedVoting(4), VMES.approval, VMES.sntv, VMES.stv, VMES.stvminimax],
    repeat([VMES.ElectorateStrategy(VMES.hon, 72)], 5), 24, 20, 4, iter_per_update=10)
    