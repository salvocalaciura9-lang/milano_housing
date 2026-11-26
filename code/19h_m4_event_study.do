*==============================================================================*
* 19h_m4_event_study.do
* M4: event study con bande di confidenza e composizione per semestre
*
* Stima (stessa del modulo 19, programma csatt): ATT(g,t) di Callaway e
* Sant'Anna con riferimento g-1, controlli abbinati + non ancora trattati.
* Aggregazione per tempo dall'apertura e = (t - g)/step:
*     ES(e) = sum_g n_g ATT(g, g + e) / sum_g n_g,
* sui soli gruppi che hanno la cella e nei dati. ES(-1) = 0 per costruzione.
* Composizione: n_e = aree che entrano in ES(e). Con OMI fino al 2026S1 i
* semestri da +3 a +6 vengono solo dalla tratta 1 (una zona, D12): la media
* cambia composizione lungo l'asse e va letta con questa avvertenza.
*
* Bande (dalla stessa permutazione dei gruppi di apertura del modulo 19):
*   puntuali al 95%:   ES(e) +/- c_e, c_e = 95-esimo percentile di |ES_perm(e)|
*                      (inversione del test, effetto costante);
*   simultanee al 95%: ES(e) +/- c_sup * sd_e, sd_e = dev. st. di ES_perm(e),
*                      c_sup = 95-esimo percentile di max_e |ES_perm(e)|/sd_e
*                      sulla finestra mostrata (banda "sup-t": copre tutti i
*                      coefficienti insieme; Montiel Olea e Plagborg-Moller, 2019).
*
* Esiti: ln affitto e ln prezzo (zone, semestri -12..+6); uscite verso altri
* comuni per 1.000 residenti (NIL abbinati, anni -8..+1).
* Grafici in italiano e in inglese (suffisso _en).
*
* Input:  $WORK/m4_zone_panel.dta, m4_nil_panel.dta (modulo 19)
* Output: $TAB/m4_event_study.csv;
*         $FIG/m4_cs_event_rent.png, m4_cs_event_price.png, m4_cs_event_exits.png
*         (e versioni _en)
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "19h - M4: EVENT STUDY CON BANDE" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in RAW:data/raw WORK:data/work TAB:output/tables FIG:output/figures CODE:code {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}
if "$SEED" == "" global SEED 20261119
if "$M4_PERMS" == "" global M4_PERMS 999
if "$M4_TLAST" == "" global M4_TLAST 2026
foreach f in "$WORK/m4_zone_panel.dta" "$WORK/m4_nil_panel.dta" {
    capture confirm file "`f'"
    if _rc {
        di as error "  manca `f' (modulo 19): 19h saltato"
        exit
    }
}
do "$CODE/m4_programs.do"
set seed $SEED

* esagg: da un frame di ATT(g,t) (g t att nT) all'event study per e
capture program drop esagg
program define esagg
    args fr step emin emax
    frame `fr' {
        gen double e = round((t - g)/`step')
        keep if inrange(e, `emin', `emax')
        gen double wa = att*nT
        gen byte one = 1
        collapse (sum) wa nT ng = one, by(e)
        gen double att = wa/nT
        drop wa
    }
end

* esrun: stima, permutazioni, bande; risultati nel frame esout
capture program drop esrun
program define esrun
    syntax varname, Unit(varname) Time(varname) Cohort(varname) Sample(varname) ///
        Step(real) Tmax(real) Perms(integer) Emin(integer) Emax(integer) Name(string)
    local y `varlist'
    capture frame drop es0
    csatt `y', unit(`unit') time(`time') cohort(`cohort') sample(`sample') step(`step') ///
        tmax(`tmax') esframe(es0)
    esagg es0 `step' `emin' `emax'
    capture frame drop acc
    frame create acc long j double e double att
    tempvar first cpf cp
    quietly bysort `unit' (`time'): gen byte `first' = _n == 1 & `sample'
    forvalues j = 1/`perms' {
        quietly {
            capture drop `cpf' `cp'
            gen double `cpf' = .
            mata: m4_perm("`cohort'", "`first'", "`cpf'")
            bysort `unit': egen double `cp' = max(`cpf')
        }
        capture frame drop esp
        csatt `y', unit(`unit') time(`time') cohort(`cp') sample(`sample') step(`step') ///
            tmax(`tmax') esframe(esp)
        esagg esp `step' `emin' `emax'
        frame esp {
            quietly count
            forvalues r = 1/`r(N)' {
                frame post acc (`j') (e[`r']) (att[`r'])
            }
        }
    }
    frame acc {
        * il riferimento e = -1 vale 0 in ogni permutazione: escluso dalle bande
        quietly drop if e == -1
        gen double a = abs(att)
        preserve
        collapse (p95) c = a (sd) sd = att (count) nperm = att, by(e)
        tempfile cs
        save `cs'
        restore
        merge m:1 e using `cs', nogen
        gen double tt = a/sd
        collapse (max) M = tt, by(j)
        _pctile M, p(95)
        local csup = r(r1)
    }
    frame es0 {
        merge 1:1 e using `cs', nogen
        gen double ci_lo = att - c
        gen double ci_hi = att + c
        gen double cs_lo = att - `csup'*sd
        gen double cs_hi = att + `csup'*sd
        foreach v in ci_lo ci_hi cs_lo cs_hi {
            replace `v' = 0 if e == -1
        }
        gen double c_sup = `csup'
        gen str12 outcome = "`name'"
        rename nT n_units
        rename ng n_groups
        keep outcome e att ci_lo ci_hi cs_lo cs_hi n_units n_groups nperm c_sup
        tempfile out
        save `out'
    }
    frame esout {
        append using `out'
    }
    di as txt "  -> event study `name': c_sup = " %5.3f `csup' "  (permutazioni `perms')"
end

capture frame drop esout
frame create esout str12 outcome

* --- zone: affitti e prezzi ------------------------------------------------------
use "$WORK/m4_zone_panel.dta", clear
esrun lnR, unit(zid) time(t) cohort(cohort) sample(s_match) step(0.5) tmax($M4_TLAST) ///
    perms($M4_PERMS) emin(-12) emax(6) name(rent)
esrun lnP, unit(zid) time(t) cohort(cohort) sample(s_match) step(0.5) tmax($M4_TLAST) ///
    perms($M4_PERMS) emin(-12) emax(6) name(price)

* --- NIL: uscite ----------------------------------------------------------------
use "$WORK/m4_nil_panel.dta", clear
local NP = max(199, floor($M4_PERMS/2))
esrun r_ac, unit(nil) time(t) cohort(cohort) sample(s_nilm) step(1) tmax(2024) ///
    perms(`NP') emin(-8) emax(1) name(exits)

frame esout {
    gen double att_pct = 100*(exp(att) - 1) if inlist(outcome, "rent", "price")
    order outcome e att att_pct ci_lo ci_hi cs_lo cs_hi n_units n_groups nperm c_sup
    sort outcome e
    format att ci_lo ci_hi cs_lo cs_hi %8.4f
    format att_pct %6.1f
    list outcome e att ci_lo ci_hi cs_lo cs_hi n_units n_groups, noobs sepby(outcome) abbrev(8)
    export delimited using "$TAB/m4_event_study.csv", replace
}

*------------------------------------------------------------------------------*
* Grafici
*------------------------------------------------------------------------------*
tempfile esall
frame esout: save `esall'
foreach o in rent price exits {
    foreach lang in it en {
        use `esall', clear
        keep if outcome == "`o'"
        quietly summarize e
        local e0 = r(min)
        local e1 = r(max)
        local step = cond("`o'" == "exits", 1, 2)
        quietly summarize cs_lo
        local ylo = r(min)
        quietly summarize cs_hi
        local yhi = r(max)
        local yr = `yhi' - `ylo'
        * riga con il numero di aree sotto il grafico
        gen double ylab = `ylo' - 0.12*`yr'
        gen str4 nlab = string(n_units)
        * punti da un solo gruppo di apertura: marcatore vuoto
        gen double att1 = att if n_groups == 1
        gen double attm = att if n_groups > 1
        if "`lang'" == "it" {
            local xt = cond("`o'" == "exits", "Anni dall'apertura della propria tratta", "Semestri dall'apertura della propria tratta")
            local yt = cond("`o'" == "rent", "ln affitto, trattate - controlli", cond("`o'" == "price", "ln prezzo, trattate - controlli", "Uscite per 1.000 residenti, trattati - controlli"))
            local l1 "IC 95% puntuale (permutazione)"
            local l2 "Banda simultanea 95%"
            local l3 "Stima (piu' gruppi di apertura)"
            local l4 "Stima (un solo gruppo di apertura)"
            local nt "Numeri in basso: aree che entrano nella stima. Callaway e Sant'Anna, riferimento = periodo -1; controlli abbinati e non ancora trattati."
            local fn "m4_cs_event_`o'"
        }
        else {
            local xt = cond("`o'" == "exits", "Years since opening of own section", "Semesters since opening of own section")
            local yt = cond("`o'" == "rent", "Log rent, treated - control", cond("`o'" == "price", "Log price, treated - control", "Out-migration per 1,000 residents, treated - control"))
            local l1 "Pointwise 95% CI (permutation)"
            local l2 "Simultaneous 95% band"
            local l3 "Estimate (several opening groups)"
            local l4 "Estimate (single opening group)"
            local nt "Bottom row: number of treated units. Callaway-Sant'Anna, reference period -1; matched and not-yet-treated controls."
            local fn "m4_cs_event_`o'_en"
        }
        twoway (rarea ci_lo ci_hi e, color("37 106 191%20") lwidth(none)) ///
            (line cs_lo e, lcolor("37 106 191") lpattern(dash) lwidth(thin)) ///
            (line cs_hi e, lcolor("37 106 191") lpattern(dash) lwidth(thin)) ///
            (connected attm e, lcolor("37 106 191") mcolor("37 106 191") msymbol(O) msize(small)) ///
            (scatter att1 e, mcolor("37 106 191") msymbol(Oh) msize(medsmall)) ///
            (scatter ylab e, msymbol(none) mlabel(nlab) mlabposition(0) mlabsize(vsmall) mlabcolor(gs6)), ///
            yline(0, lcolor(gs8)) xline(-0.5, lcolor("230 100 50") lpattern(dash)) ///
            xlabel(`e0'(`step')`e1') ylabel(, format(%4.2f) angle(0)) xtitle("`xt'") ytitle("`yt'") ///
            legend(order(1 "`l1'" 2 "`l2'" 4 "`l3'" 5 "`l4'") rows(2) size(small) position(6)) ///
            graphregion(color(white)) note("`nt'", size(vsmall))
        graph export "$FIG/`fn'.png", replace width(2400)
    }
}
