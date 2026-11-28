*==============================================================================*
* 19f_m4_daniele_romito.do
* M4: i controlli del protocollo di Daniele e Romito (2022), "The impact of
* Metro C in Rome on the housing market" (anche loro con le zone OMI)
*
* Cosa cambia rispetto al disegno principale (modulo 19)
*  1. Trattamento dal centroide: una zona e' trattata se il suo centroide e'
*     entro 1 km da una stazione M4; gruppo di apertura = tratta della stazione
*     piu' vicina entro 1 km aperta per prima (date di apertura come nel 19).
*  2. Fascia di esclusione 1-2 km: le zone con il centroide tra 1 e 2 km dalla
*     M4 non sono ne' trattate ne' controlli, perche' potrebbero risentire
*     indirettamente della linea (spillover); controlli = centroide oltre 2 km.
*  3. Controllo sintetico zona per zona (Abadie, Diamond e Hainmueller, 2010):
*     per ogni zona trattata, una media pesata delle zone di controllo (pesi
*     positivi che sommano a 1) che riproduce i suoi affitti prima
*     dell'apertura; l'effetto e' lo scarto dopo l'apertura.
*  4. Diagnostica: errore di adattamento prima dell'apertura (RMSPE pre),
*     rapporto RMSPE dopo/prima, p-value di rango con i placebo (ogni zona di
*     controllo trattata come finta trattata), lo stesso p escludendo i placebo
*     adattati male (MSPE pre oltre 5 volte quello della trattata, come in
*     Abadie et al. 2010), effetto medio con inferenza alla Cavallo, Galiani,
*     Noy e Pantano (2013).
*
* Varianti del diff-in-diff (Callaway e Sant'Anna + permutazione, come nel 19)
*   (DR)   centroide <= 1 km; controlli oltre 2 km (fascia 1-2 km esclusa)
*   (DRnb) come DR ma senza fascia: controlli = centroide oltre 1 km
*   (DRna) come DR, trattate solo se la M4 e' la stazione piu' vicina al
*          centroide (nuovo accesso: in centro M1 e M3 c'erano gia')
*   (MB)   disegno principale (500 m, quota servita >= 20%) con i controlli
*          ristretti alle zone mai esposte con il centroide oltre 2 km
* Esiti: ln affitto e ln prezzo (zone OMI, semestri); uscite verso altri
* comuni (NIL, anni). Synthetic DiD (pacchetto sdid) per gli affitti.
*
* Input:  $WORK/m4_zone_panel.dta, m4_nil_panel.dta (modulo 19), xwa_grid.dta,
*         $RAW/ds535_tpl_metrofermate.csv
* Output: $TAB/m4_dr_groups.csv, m4_dr_results.csv, m4_dr_sdid.csv,
*         m4_dr_sc_zones.csv, m4_dr_sc_summary.csv; $FIG/m4_dr_sc_gaps.png
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "19f - M4: CONTROLLI DI DANIELE E ROMITO (2022)" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in RAW:data/raw WORK:data/work TAB:output/tables FIG:output/figures CODE:code {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}
if "$SEED" == "" global SEED 20261119
if "$M4_PERMS" == "" global M4_PERMS 999
if "$M4_TLAST" == "" global M4_TLAST 2026
foreach f in "$RAW/ds535_tpl_metrofermate.csv" "$WORK/xwa_grid.dta" "$WORK/m4_zone_panel.dta" "$WORK/m4_nil_panel.dta" {
    capture confirm file "`f'"
    if _rc {
        di as error "  manca `f': 19f saltato"
        exit
    }
}
set seed $SEED
local DIN  1000      // trattata: centroide entro 1 km
local DOUT 2000      // controllo: centroide oltre 2 km
local SCDRAWS 10000

do "$CODE/m4_programs.do"
m4cs_init

*------------------------------------------------------------------------------*
* 0. Controllo sintetico in Mata
*------------------------------------------------------------------------------*
capture mata: mata drop m4_proj() m4_simplex() m4_scfit() m4_sc()
mata:
// proiezione sul simplesso (Duchi, Shalev-Shwartz, Singer e Chandra, 2008)
real colvector m4_proj(real colvector v)
{
    real scalar n, rho, theta
    real colvector u, css
    n = rows(v)
    u = sort(v, -1)
    css = runningsum(u)
    rho = max(selectindex(u :- (css :- 1):/(1::n) :> 0))
    theta = (css[rho] - 1)/rho
    return(rowmax((v :- theta, J(n, 1, 0))))
}
// min ||a - B w||^2 con w >= 0, sum(w) = 1 (gradiente proiettato accelerato)
real colvector m4_simplex(real colvector a, real matrix B)
{
    real scalar J, L, it, tk, tn
    real matrix BtB
    real colvector Bta, w, z, wn
    J = cols(B)
    w = J(J, 1, 1/J)
    if (J == 1) return(w)
    BtB = B'B
    Bta = B'a
    L = 2*max(symeigenvalues(BtB))
    if (L <= 0) return(w)
    z = w
    tk = 1
    for (it = 1; it <= 20000; it++) {
        wn = m4_proj(z - 2*(BtB*z - Bta)/L)
        tn = (1 + sqrt(1 + 4*tk^2))/2
        z = wn + ((tk - 1)/tn)*(wn - w)
        if (max(abs(wn - w)) < 1e-10) {
            w = wn
            break
        }
        w = wn
        tk = tn
    }
    return(w)
}
// una zona: pesi sul pre (periodi 1..g-1), scarti, effetto medio dopo, RMSPE
real rowvector m4_scfit(real colvector y, real matrix Y0, real scalar g, real scalar dm,
    real colvector gap, real colvector w)
{
    real scalar T, mpre, mpost
    real colvector yy, pre, post
    real matrix YY
    T = rows(y)
    pre = (1::g-1)
    post = (g::T)
    yy = y
    YY = Y0
    if (dm) {
        yy = y :- mean(y[pre])
        YY = Y0 :- mean(Y0[pre, .])
    }
    w = m4_simplex(yy[pre], YY[pre, .])
    gap = yy - YY*w
    mpre = mean(gap[pre]:^2)
    mpost = mean(gap[post]:^2)
    return((mean(gap[post]), sqrt(mpre), sqrt(mpost), sqrt(mpost/mpre)))
}
// tutte le zone trattate + placebo; dati ordinati per unita' e periodo
void m4_sc(string scalar yv, real scalar T, real scalar dm, real scalar ndraw)
{
    real scalar N, nT, J, k, i, g, j, p, pf, obs, ext, d, s
    real colvector y, role, gg, uid, idx, tr, dn, gap, w, gp, wp, pr, pm, others, ok
    real matrix Y, R, G, PA
    real rowvector r, rp
    y = st_data(., yv)
    role = st_data(., "__role")
    gg = st_data(., "__g")
    uid = st_data(., "__uid")
    N = rows(y)/T
    Y = colshape(y, T)'
    idx = (0::N-1):*T :+ 1
    role = role[idx]
    gg = gg[idx]
    uid = uid[idx]
    tr = selectindex(role :== 1)
    tr = tr[order(gg[tr], 1)]
    dn = selectindex(role :== 0)
    nT = rows(tr)
    J = rows(dn)
    R = J(nT, 10, .)
    G = J(0, 5, .)
    PA = J(nT, J, .)
    for (k = 1; k <= nT; k++) {
        i = tr[k]
        g = gg[i]
        r = m4_scfit(Y[., i], Y[., dn], g, dm, gap, w)
        G = G \ (J(T, 1, 1), J(T, 1, uid[i]), J(T, 1, g), (1::T) :- g, gap)
        pr = J(J, 1, .)
        pm = J(J, 1, .)
        for (j = 1; j <= J; j++) {
            others = dn[selectindex((1::J) :!= j)]
            rp = m4_scfit(Y[., dn[j]], Y[., others], g, dm, gp, wp)
            pr[j] = rp[4]
            pm[j] = rp[2]
            PA[k, j] = rp[1]
            if (k == 1) G = G \ (J(T, 1, 0), J(T, 1, uid[dn[j]]), J(T, 1, g), (1::T) :- g, gp)
        }
        p = (sum(pr :>= r[4]) + 1)/(J + 1)
        ok = selectindex(pm:^2 :<= 5*r[2]^2)
        pf = (rows(ok) > 0 ? (sum(pr[ok] :>= r[4]) + 1)/(rows(ok) + 1) : 1)
        R[k, .] = (uid[i], g, r[1], r[2], r[3], r[4], p, pf, max(w), sum(w :> 0.01))
    }
    // effetto medio: distribuzione dei placebo (un placebo a caso per ogni trattata)
    obs = mean(R[., 3])
    ext = 0
    for (d = 1; d <= ndraw; d++) {
        s = 0
        for (k = 1; k <= nT; k++) s = s + PA[k, ceil(runiform(1, 1)*J)]
        if (abs(s/nT) >= abs(obs) - 1e-12) ext++
    }
    st_matrix("__scR", R)
    st_matrix("__scG", G)
    st_numscalar("__scobs", obs)
    st_numscalar("__scp", (ext + 1)/(ndraw + 1))
    st_numscalar("__scJ", J)
}
end

*------------------------------------------------------------------------------*
* 1. Stazioni e distanze dai centroidi di zone OMI e NIL
*------------------------------------------------------------------------------*
import delimited using "$RAW/ds535_tpl_metrofermate.csv", clear delimiter(";") ///
    varnames(1) encoding("utf-8") stringcols(_all)
rename (long_x_4326 lat_y_4326) (lon lat)
destring lon lat, replace
replace nome = ustrupper(ustrtrim(nome))
replace linee = subinstr(linee, " ", "", .)
gen byte m4 = strpos("," + linee + ",", ",4,") > 0
gen byte other = ustrregexm(linee, "[1235]")
gen byte phase = .
replace phase = 1 if m4 & inlist(nome, "LINATE AEROPORTO", "REPETTI", "STAZIONE FORLANINI", "ARGONNE", "SUSA", "DATEO")
replace phase = 2 if m4 & inlist(nome, "TRICOLORE", "SAN BABILA")
replace phase = 3 if m4 & missing(phase)
keep if m4 | other
local n = _N
forvalues i = 1/`n' {
    local x`i' = lon[`i']
    local y`i' = lat[`i']
    local m4`i' = m4[`i']
    local ot`i' = other[`i']
    local ph`i' = phase[`i']
}

use "$WORK/xwa_grid.dta", clear
keep pid lon lat zona nil
tempfile grid
save `grid'
local R = 6371000
local k = _pi/180
foreach u in zona nil {
    use `grid', clear
    if "`u'" == "zona" keep if zona != ""
    else keep if !missing(nil)
    * centroide = media dei punti della griglia dell'area (griglia regolare)
    collapse (mean) lon lat, by(`u')
    foreach v in d1 d2 d3 d4 doth {
        gen double `v' = .
    }
    forvalues i = 1/`n' {
        tempvar dd
        quietly gen double `dd' = 2*`R'*asin(sqrt(sin((lat - `y`i'')*`k'/2)^2 + ///
            cos(lat*`k')*cos(`y`i''*`k')*sin((lon - `x`i'')*`k'/2)^2))
        if `ot`i'' quietly replace doth = min(doth, `dd')
        if `m4`i'' {
            quietly replace d4 = min(d4, `dd')
            quietly replace d`ph`i'' = min(d`ph`i'', `dd')
        }
        drop `dd'
    }
    if "`u'" == "zona" local tt "2023 2023.5 2025"
    else local tt "2023 2024 2025"
    tokenize `tt'
    gen double c_dr = .
    replace c_dr = `3' if d3 <= `DIN'
    replace c_dr = `2' if d2 <= `DIN'
    replace c_dr = `1' if d1 <= `DIN'
    replace c_dr = 0 if d4 > `DOUT'
    gen double c_nb = c_dr
    replace c_nb = 0 if d4 > `DIN'
    gen double c_na = c_dr
    replace c_na = . if c_dr > 0 & !missing(c_dr) & d4 >= doth
    label variable d4 "Distanza del centroide dalla stazione M4 piu' vicina (m)"
    label variable doth "Distanza del centroide dalla stazione piu' vicina delle altre linee (m)"
    keep `u' d1 d2 d3 d4 doth c_dr c_nb c_na
    tempfile cen_`u'
    save `cen_`u''
}

*------------------------------------------------------------------------------*
* 2. Zone OMI: gruppi e diff-in-diff
*------------------------------------------------------------------------------*
use "$WORK/m4_zone_panel.dta", clear
merge m:1 zona using `cen_zona', keep(master match) nogen
gen double c_mb = cohort
replace c_mb = . if cohort == 0 & d4 <= `DOUT'
tempfile zp
save `zp'

preserve
bysort zona: keep if _n == 1
di as txt _n "  Zone OMI: distanza del centroide dalla M4 e gruppi nelle varianti"
di as txt "  (cohort = disegno principale; . = esclusa; 0 = controllo)"
sort d4
list zona d4 doth cohort c_dr c_nb c_na c_mb, noobs sep(0) abbrev(8)
foreach v in c_dr c_nb c_na c_mb {
    quietly count if `v' > 0 & !missing(`v')
    local t1 = r(N)
    quietly count if `v' == 0
    di as txt "  `v': trattate " as res `t1' as txt ", controlli " as res r(N)
}
format d1 d2 d3 d4 doth %6.0f
export delimited zona d1 d2 d3 d4 doth cohort c_dr c_nb c_na c_mb using "$TAB/m4_dr_groups.csv", replace
keep zid zona
tempfile zmap
save `zmap'
restore

local L_dr   "(DR) centroide entro 1 km, controlli oltre 2 km"
local L_nb   "(DRnb) centroide entro 1 km, controlli oltre 1 km (senza fascia)"
local L_na   "(DRna) come DR, solo zone dove la M4 e' la stazione piu' vicina"
local L_mb   "(MB) principale 500 m, controlli mai esposti oltre 2 km"
foreach v in dr nb na mb {
    gen byte s_`v' = !missing(c_`v')
    foreach y in lnR lnP {
        m4run `y', unit(zid) time(t) cohort(c_`v') sample(s_`v') step(0.5) tmax($M4_TLAST) ///
            spec("`L_`v''") perms($M4_PERMS)
    }
}

*------------------------------------------------------------------------------*
* 3. NIL: uscite verso altri comuni
*------------------------------------------------------------------------------*
use "$WORK/m4_nil_panel.dta", clear
merge m:1 nil using `cen_nil', keep(master match) nogen
gen double c_mb = cohort
replace c_mb = . if cohort == 0 & d4 <= `DOUT'
preserve
bysort nil: keep if _n == 1
foreach v in c_dr c_nb c_na c_mb {
    quietly count if `v' > 0 & !missing(`v')
    local t1 = r(N)
    quietly count if `v' == 0
    di as txt "  NIL `v': trattati " as res `t1' as txt ", controlli " as res r(N)
}
restore
local NP = max(199, floor($M4_PERMS/2))
foreach v in dr nb na mb {
    gen byte s_`v' = !missing(c_`v')
    m4run r_ac, unit(nil) time(t) cohort(c_`v') sample(s_`v') step(1) tmax(2024) prewin(8) ///
        spec("NIL `L_`v''") perms(`NP')
}
frame m4cs {
    gen double att_pct = 100*(exp(att) - 1) if inlist(outcome, "lnR", "lnP")
    format att pre %8.4f
    format p_perm p_perm_pre %5.3f
    format att_pct %6.1f
    list spec outcome att att_pct p_perm pre p_perm_pre nT nC, noobs sep(0) abbrev(10)
    export delimited using "$TAB/m4_dr_results.csv", replace
}

*------------------------------------------------------------------------------*
* 4. Synthetic DiD sugli affitti (stesse varianti)
*------------------------------------------------------------------------------*
capture frame drop sd
frame create sd str90 spec str10 outcome str6 metodo double att double se double p long nT long nC ///
    double ci_lo double ci_hi str40 metodo_inf str20 periodi
use `zp', clear
quietly summarize t
local t1 = r(max)
m4tlab `r(min)' 0.5
local perz `r(s)'
m4tlab `t1' 0.5
local perz "`perz'-`r(s)'"
capture which sdid
if !_rc {
    foreach v in dr nb na mb {
        use `zp', clear
        keep if !missing(c_`v')
        gen byte D = c_`v' > 0 & t >= c_`v' - 1e-6
        foreach m in sdid did {
            capture noisily sdid lnR zid tid D, vce(placebo) reps(500) seed($SEED) method(`m')
            if _rc continue
            local att = e(ATT)
            local se = e(se)
            quietly count if tid == tid[1] & c_`v' > 0
            local nT = r(N)
            quietly count if tid == tid[1] & c_`v' == 0
            local nC = r(N)
            frame post sd ("`L_`v''") ("lnR") ("`m'") (`att') (`se') (2*normal(-abs(`att'/`se'))) (`nT') (`nC') ///
                (`att' - 1.96*`se') (`att' + 1.96*`se') ("errore standard placebo (500 repliche)") ("`perz'")
        }
    }
    frame sd {
        gen double att_pct = 100*(exp(att) - 1)
        format att se %8.4f
        format p %5.3f
        format att_pct %6.1f
        list, noobs sep(0) abbrev(10)
        export delimited using "$TAB/m4_dr_sdid.csv", replace
    }
}
else di as txt "  (sdid non installato: synthetic DiD saltato)"

*------------------------------------------------------------------------------*
* 5. Controllo sintetico zona per zona (affitti)
*   set A: trattate DR (centroide entro 1 km), donatori = controlli DR (oltre 2 km)
*   set B: trattate del disegno principale, donatori = mai esposte oltre 2 km
*   livelli (Abadie et al., come Daniele e Romito) e scarti dalla media pre
*   (controllo sintetico con intercetta: Doudchenko e Imbens, 2016; Ferman e
*   Pinto, 2021), utile per le zone centrali con affitti fuori dal range dei
*   donatori.
*------------------------------------------------------------------------------*
capture frame drop scs
frame create scs str2 set str8 versione double att double att_pct double p_agg long nT long J long n_p10

tempfile scz scg
local first 1
foreach s in A B {
    foreach dm in 0 1 {
        use `zp', clear
        if "`s'" == "A" {
            gen byte __role = 1 if c_dr > 0 & !missing(c_dr)
            replace __role = 0 if c_dr == 0
            gen double __c = c_dr
        }
        else {
            gen byte __role = 1 if cohort > 0 & !missing(cohort)
            replace __role = 0 if c_mb == 0
            gen double __c = cohort
        }
        keep if !missing(__role)
        quietly summarize tid
        local tmin = r(min)
        local T = r(max) - r(min) + 1
        gen int __g = round(2*__c) - `tmin' + 1 if __role == 1
        replace __g = 0 if __role == 0
        gen double __uid = zid
        sort zid tid
        by zid: assert _N == `T'
        mata: m4_sc("lnR", `T', `dm', `SCDRAWS')
        local ver = cond(`dm', "scarti", "livelli")
        local obs = __scobs
        local pagg = __scp
        local J = __scJ
        if "`s'" == "A" {
            clear
            matrix colnames __scG = tipo zid g e gap
            svmat double __scG, names(col)
            merge m:1 zid using `zmap', keep(master match) nogen
            gen str8 versione = "`ver'"
            if `dm' == 1 append using `scg'
            save `scg', replace
        }
        clear
        matrix colnames __scR = zid g att rmspe_pre rmspe_post ratio p p_fit wmax n_donors
        svmat double __scR, names(col)
        merge 1:1 zid using `zmap', keep(master match) nogen
        gen double cohort = (g - 1 + `tmin')/2
        gen str2 set = "`s'"
        gen str8 versione = "`ver'"
        gen double att_pct = 100*(exp(att) - 1)
        quietly count if p <= 0.10
        local np10 = r(N)
        frame post scs ("`s'") ("`ver'") (`obs') (100*(exp(`obs') - 1)) (`pagg') (_N) (`J') (`np10')
        if !`first' append using `scz'
        save `scz', replace
        local first 0
    }
}
use `scz', clear
order set versione zona cohort att att_pct rmspe_pre rmspe_post ratio p p_fit wmax n_donors
format att rmspe_pre rmspe_post %7.4f
format ratio wmax %6.2f
format p p_fit %5.3f
format att_pct %6.1f
di as txt _n "  Controllo sintetico zona per zona (affitti, ln)"
list set versione zona cohort att_pct rmspe_pre ratio p p_fit wmax n_donors, noobs sepby(set versione) abbrev(9)
export delimited set versione zona cohort att att_pct rmspe_pre rmspe_post ratio p p_fit wmax n_donors ///
    using "$TAB/m4_dr_sc_zones.csv", replace
frame scs {
    format att p_agg %7.4f
    format att_pct %6.1f
    di as txt _n "  Effetto medio del controllo sintetico (p: Cavallo et al. 2013)"
    list, noobs sep(0)
    export delimited using "$TAB/m4_dr_sc_summary.csv", replace
}

* grafici: scarti delle zone trattate (blu) e dei placebo (grigio), set A
*   m4_dr_sc_gaps.png         versione con intercetta (scarti dalla media pre)
*   m4_dr_sc_gaps_livelli.png versione in livelli (Abadie): mostra il cattivo adattamento
use `scg', clear
export delimited using "$TAB/m4_dr_sc_gaps.csv", replace
foreach ver in scarti livelli {
    use `scg', clear
    keep if versione == "`ver'"
    sort tipo zid e
    local cmd
    quietly levelsof zid if tipo == 0, local(P)
    foreach u of local P {
        local cmd `cmd' (line gap e if tipo == 0 & zid == `u', lcolor(gs12) lwidth(vthin))
    }
    quietly levelsof zid if tipo == 1, local(Q)
    foreach u of local Q {
        local cmd `cmd' (line gap e if tipo == 1 & zid == `u', lcolor(navy) lwidth(medthin))
    }
    local tt = cond("`ver'" == "scarti", "con intercetta", "in livelli")
    local fn = cond("`ver'" == "scarti", "m4_dr_sc_gaps", "m4_dr_sc_gaps_livelli")
    twoway `cmd', xline(-0.5, lpattern(dash) lcolor(cranberry)) yline(0, lcolor(gs8)) legend(off) ///
        xtitle("Semestri dall'apertura (0 = primo semestre servito)") ///
        ytitle("Scarto dal controllo sintetico (ln affitto)") ///
        title("Controllo sintetico zona per zona, `tt'", size(medium)) ///
        note("Blu: zone con il centroide entro 1 km da una stazione M4. Grigio: placebo (zone oltre 2 km, date della tratta 1).", size(vsmall)) ///
        graphregion(color(white))
    graph export "$FIG/`fn'.png", replace width(1600)
}
