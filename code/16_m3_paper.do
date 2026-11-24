*==============================================================================*
* 16_m3_paper.do  -  analisi del modello M3 per il paper
*
* Specificazione principale (fissata prima di guardare i risultati):
*   r_{j,t+1} = a_j + l_t + b ln(A_jt) + e_jt
*   r   = trasferimenti di residenza verso ALTRI COMUNI ITALIANI per 1.000
*         residenti t-1 (DS1600/DS1956, allocati al CAP): esclusi le
*         cancellazioni d'ufficio e i trasferimenti all'estero
*   A   = affitto annuo di 60 m2 (punto medio OMI) / reddito imponibile medio IRPEF
*   a_j = effetti fissi di CAP, l_t = effetti fissi di anno
*   t   = 2019-2023 (esito 2020-2024); 35 CAP con copertura OMI >= 80%
*   errori raggruppati per CAP; wild cluster bootstrap (Webb) per pochi cluster
*
* Controlli (ognuno risponde a una minaccia specifica):
*   T1 descrittive: varianza totale, between e within
*   T2 correlazioni prima/dopo gli effetti fissi (il problema del TA)
*   T3 principale + controlli predefiniti: demografia, t+2, senza anni
*      pandemici, differenze prime, Poisson, placebo (uscite t-1)
*   T4 scomposizione del rapporto: ln affitto e ln reddito separati
*   T5 senza reddito: solo ln affitto (+ distorsione da variabile omessa) e
*      prezzi di compravendita (rapporto, solo prezzo, prezzo + reddito)
*   F1 Frisch-Waugh-Lovell: dati grezzi vs dati dopo gli effetti fissi
*   F2 leave-one-CAP-out
*
* Output: $TAB/m3_*.csv, $FIG/m3_*.png
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "16 - MODELLO M3 PER IL PAPER" _n "{hline 78}"
if $XW_OK == 0 {
    di as error "  16 saltato: raccordo non disponibile"
    exit
}

use "$WORK/cap_panel_main_est.dta", clear
xtset capid year
gen double lnY = ln(ybar_imp)
gen double lnR = ln(R_mid)
gen double lnP = ln(P_mid)
* esito principale: trasferimenti verso altri comuni italiani (DS1600/DS1956),
* esclusi le cancellazioni d'ufficio ("Altro") e i trasferimenti all'estero
local Y r_ac_lead1
capture confirm variable r_ac
if _rc {
    di as error "  r_ac non disponibile (modulo 03b): uso tutte le cancellazioni del DS205"
    gen double r_ac = r_emig
    gen double r_mov = r_emig
    gen double canc_ac_al = emig_al
}
gen double r_ac_lead1  = F.r_ac
gen double r_ac_lead2  = F2.r_ac
gen double r_ac_lag1   = L.r_ac
gen double E_ac_lead1  = F.canc_ac_al
gen double r_tot_lead1 = F.r_emig
gen double r_mov_lead1 = F.r_mov
gen byte s_m3 = inrange(year, $Y0A, $Y1) & !missing(lnAR, r_ac_lead1) & cover_ok == 1
label variable `Y' "Trasferimenti verso altri comuni per 1.000 residenti, t+1"
label variable lnAR    "ln(affitto annuo 60 m2 / reddito medio), t"
quietly levelsof capid if s_m3
local G = r(r)

capture frame drop m3
frame create m3 str70 spec str12 coef double b double se double lb double ub ///
    double p double p_boot double lb_boot double ub_boot long N long G
capture program drop m3post
program define m3post
    syntax , Spec(string) Coef(string) [Boot]
    tempname b se
    scalar `b' = _b[`coef']
    scalar `se' = _se[`coef']
    local df = e(df_r)
    if missing(`df') {
        local crit = invnormal(0.975)
        local p = 2*normal(-abs(`b'/`se'))
    }
    else {
        local crit = invttail(`df', 0.025)
        local p = 2*ttail(`df', abs(`b'/`se'))
    }
    local pb = .
    local lbb = .
    local ubb = .
    if "`boot'" != "" {
        capture noisily boottest `coef', reps($BOOTREPS) weighttype(webb) seed($SEED) nograph
        if _rc == 0 {
            local pb = r(p)
            capture matrix CI = r(CI)
            if _rc == 0 {
                local lbb = CI[1,1]
                local ubb = CI[1,2]
            }
        }
    }
    local g = e(N_clust)
    frame post m3 ("`spec'") ("`coef'") (`b') (`se') (`b' - `crit'*`se') (`b' + `crit'*`se') ///
        (`p') (`pb') (`lbb') (`ubb') (e(N)) (`g')
    di as txt "  -> " as res "`spec'" as txt ": " as res %8.3f `b' as txt "  IC95 [" %7.3f `b' - `crit'*`se' ///
        "; " %7.3f `b' + `crit'*`se' "]  p = " %5.3f `p' "  p boot = " %5.3f `pb' "  N = " e(N)
end

*------------------------------------------------------------------------------*
* T1. Descrittive: quanta variazione resta dopo gli effetti fissi
*------------------------------------------------------------------------------*
di as txt _n "  {ul:T1. Descrittive del campione M3 (35 CAP x 5 anni)}"
capture frame drop t1
frame create t1 str40 var double mean double sd_tot double sd_between double sd_within double r2_fe
foreach v in `Y' lnAR lnR lnY {
    quietly summarize `v' if s_m3
    local m = r(mean)
    local st = r(sd)
    preserve
    quietly keep if s_m3
    quietly collapse (mean) mv = `v', by(capid)
    quietly summarize mv
    local sb = r(sd)
    restore
    quietly regress `v' i.capid i.year if s_m3
    local r2 = e(r2)
    tempvar w
    quietly predict double `w' if s_m3, residuals
    quietly summarize `w'
    local sw = r(sd)
    local lab : variable label `v'
    frame post t1 ("`v'") (`m') (`st') (`sb') (`sw') (`r2')
    di as txt "  " %-8s "`v'" "  media " as res %8.3f `m' as txt "  sd tot " as res %7.4f `st' ///
        as txt "  sd between " as res %7.4f `sb' as txt "  sd within " as res %7.4f `sw' ///
        as txt "  R2 FE " as res %5.3f `r2'
}
frame t1: export delimited using "$TAB/m3_t1_descriptives.csv", replace

*------------------------------------------------------------------------------*
* T2. Correlazioni tra ln reddito e ln affitto: grezze e dopo gli effetti fissi
*------------------------------------------------------------------------------*
di as txt _n "  {ul:T2. Correlazione ln reddito - ln affitto}"
quietly corr lnY lnR if s_m3
local c_raw = r(rho)
foreach v in lnY lnR {
    quietly regress `v' i.capid if s_m3
    predict double c_`v' if s_m3, residuals
    quietly regress `v' i.capid i.year if s_m3
    predict double w_`v' if s_m3, residuals
}
quietly corr c_lnY c_lnR if s_m3
local c_cap = r(rho)
quietly corr w_lnY w_lnR if s_m3
local c_two = r(rho)
di as txt "  grezza (tra CAP e anni):        " as res %6.3f `c_raw'
di as txt "  dopo effetti fissi di CAP:      " as res %6.3f `c_cap'
di as txt "  dopo effetti fissi CAP e anno:  " as res %6.3f `c_two' ///
    as txt "   (VIF = " as res %5.2f 1/(1 - `c_two'^2) as txt ")"
capture frame drop t2
frame create t2 str40 stage double corr_lnY_lnR
frame post t2 ("grezza") (`c_raw')
frame post t2 ("effetti fissi CAP") (`c_cap')
frame post t2 ("effetti fissi CAP e anno") (`c_two')
frame t2: export delimited using "$TAB/m3_t2_correlations.csv", replace

*------------------------------------------------------------------------------*
* T3. Stima principale e controlli predefiniti
*------------------------------------------------------------------------------*
di as txt _n "  {ul:T3. Stima principale e controlli}"
local FE "i.year i.capid"

regress `Y' lnAR if s_m3, vce(cluster capid)
m3post, spec("(0) senza effetti fissi (solo confronto)") coef(lnAR) boot

regress `Y' lnAR `FE' if s_m3, vce(cluster capid)
m3post, spec("(1) PRINCIPALE: FE CAP e anno") coef(lnAR) boot
estimates store m3main
local bmain = _b[lnAR]
local semain = _se[lnAR]

regress `Y' lnAR lnpop_t pct65_t `FE' if s_m3, vce(cluster capid)
m3post, spec("(2) + ln residenti e % 65+ (t)") coef(lnAR) boot

gen byte s_m32 = inrange(year, $Y0A, $Y1) & !missing(lnAR, r_ac_lead2) & cover_ok == 1
regress r_ac_lead2 lnAR `FE' if s_m32, vce(cluster capid)
m3post, spec("(3) esito in t+2") coef(lnAR) boot

regress `Y' lnAR `FE' if s_m3 & !inlist(year + 1, 2020, 2021), vce(cluster capid)
m3post, spec("(4) esclusi esiti 2020-21 (pandemia)") coef(lnAR) boot

gen double D_r = D.`Y'
gen double D_lnAR = D.lnAR
regress D_r D_lnAR i.year if s_m3 & L.s_m3, vce(cluster capid)
m3post, spec("(5) differenze prime") coef(D_lnAR) boot

poisson E_ac_lead1 lnAR `FE' if s_m3, exposure(pop_al) vce(cluster capid)
m3post, spec("(6) Poisson con esposizione (semi-elasticita')") coef(lnAR)

regress r_ac_lag1 lnAR `FE' if s_m3 & !missing(r_ac_lag1), vce(cluster capid)
m3post, spec("(7) PLACEBO: trasferimenti in t-1") coef(lnAR) boot

* confronto con le misure di uscita usate prima (stesso campione)
regress r_tot_lead1 lnAR `FE' if s_m3, vce(cluster capid)
m3post, spec("(9) esito precedente: tutte le cancellazioni (DS205)") coef(lnAR) boot
regress r_mov_lead1 lnAR `FE' if s_m3, vce(cluster capid)
m3post, spec("(10) altri comuni + estero (senza d'ufficio)") coef(lnAR) boot

*------------------------------------------------------------------------------*
* T4. Scomposizione: ln A = ln(720) + ln R - ln Y
*------------------------------------------------------------------------------*
di as txt _n "  {ul:T4. Scomposizione del rapporto}"
regress `Y' lnR lnY `FE' if s_m3, vce(cluster capid)
test lnR + lnY = 0
local p_restr = r(p)
m3post, spec("(8) ln affitto [con ln reddito]") coef(lnR) boot
m3post, spec("(8) ln reddito [con ln affitto]") coef(lnY) boot
di as txt "  Test della restrizione del rapporto (b_R = -b_Y): p = " as res %6.4f `p_restr'
frame post m3 ("test b_R = -b_Y (p nella colonna p)") ("") (.) (.) (.) (.) (`p_restr') (.) (.) (.) (.) (.)

*------------------------------------------------------------------------------*
* T5. Robustezza: senza reddito (solo affitto) e con i prezzi di compravendita
*     Domanda: il reddito per CAP limita il pannello al 2019-2023; quanto cambia
*     la stima se lo si toglie? Formula della variabile omessa:
*       b_R(senza ln Y) = b_R(con ln Y) + b_Y * delta,
*     delta = pendenza within di ln Y su ln R (dopo gli effetti fissi).
*------------------------------------------------------------------------------*
di as txt _n "  {ul:T5. Senza reddito e con i prezzi di compravendita}"
regress `Y' lnR `FE' if s_m3, vce(cluster capid)
m3post, spec("(11) solo ln affitto (senza reddito)") coef(lnR) boot
local bR_short = _b[lnR]

quietly regress lnY lnR `FE' if s_m3
local delta = _b[lnR]
quietly regress `Y' lnR lnY `FE' if s_m3
local bR_long = _b[lnR]
local ovb = _b[lnY]*`delta'
di as txt "  Variabile omessa: delta = " as res %6.4f `delta' as txt "   b_Y*delta = " as res %6.3f `ovb' ///
    as txt "   b_R lungo + b_Y*delta = " as res %6.3f `bR_long' + `ovb' as txt "  (= b_R corto " as res %6.3f `bR_short' as txt ")"
frame post m3 ("OVB: b_Y*delta (colonna b), delta (colonna se)") ("") (`ovb') (`delta') (.) (.) (.) (.) (.) (.) (.) (.)

gen double lnPY = ln(60*P_mid/ybar_imp)
regress `Y' lnPY `FE' if s_m3, vce(cluster capid)
m3post, spec("(12) ln(prezzo 60 m2 / reddito)") coef(lnPY) boot
regress `Y' lnP `FE' if s_m3, vce(cluster capid)
m3post, spec("(13) solo ln prezzo (senza reddito)") coef(lnP) boot
regress `Y' lnP lnY `FE' if s_m3, vce(cluster capid)
test lnP + lnY = 0
local p_restrP = r(p)
m3post, spec("(14) ln prezzo [con ln reddito]") coef(lnP) boot
di as txt "  Test b_P = -b_Y: p = " as res %6.4f `p_restrP'
frame post m3 ("test b_P = -b_Y (p nella colonna p)") ("") (.) (.) (.) (.) (`p_restrP') (.) (.) (.) (.) (.)

frame m3: export delimited using "$TAB/m3_t3_results.csv", replace

* lettura dell'effetto
di as txt _n "  Lettura della stima principale:"
di as txt "   +10% del rapporto affitto/reddito -> " as res %5.2f `bmain'*ln(1.1) ///
    as txt " trasferimenti per 1.000 (IC " %5.2f (`bmain' - 2.03*`semain')*ln(1.1) "; " %5.2f (`bmain' + 2.03*`semain')*ln(1.1) ")"
quietly summarize `Y' if s_m3
di as txt "   media dell'esito: " as res %5.1f r(mean) as txt " per 1.000"
di as txt "   effetto minimo rilevabile (80% potenza, 5%): " as res %5.2f 2.8*`semain'*ln(1.1) ///
    as txt " trasferimenti per 1.000 per +10% del rapporto"

*------------------------------------------------------------------------------*
* F1. Frisch-Waugh-Lovell: prima e dopo gli effetti fissi
*------------------------------------------------------------------------------*
quietly regress `Y' i.capid i.year if s_m3
predict double ry if s_m3, residuals
quietly regress lnAR i.capid i.year if s_m3
predict double rx if s_m3, residuals
quietly regress ry rx if s_m3
di as txt "  FWL: pendenza sui residui = " as res %8.4f _b[rx] as txt " (uguale alla stima principale)"
twoway (scatter `Y' lnAR if s_m3, msize(small) mcolor("57 135 229%60")) ///
       (lfit `Y' lnAR if s_m3, lcolor("230 100 50") lwidth(medthick)), ///
       title("A. Dati grezzi (confronto tra CAP)", size(medsmall)) ///
       xtitle("ln(affitto/reddito), t") ytitle("Trasferimenti ad altri comuni per 1.000, t+1") legend(off) ///
       graphregion(color(white)) name(g_raw, replace)
twoway (scatter ry rx if s_m3, msize(small) mcolor("57 135 229%60")) ///
       (lfit ry rx if s_m3, lcolor("230 100 50") lwidth(medthick)), ///
       title("B. Dopo effetti fissi di CAP e anno", size(medsmall)) ///
       xtitle("ln(affitto/reddito), scarto dal CAP e dall'anno") ytitle("Trasferimenti, scarto") legend(off) ///
       graphregion(color(white)) name(g_fe, replace)
graph combine g_raw g_fe, cols(2) graphregion(color(white)) xsize(10) ysize(4.5) ///
    note("Pannello B: la pendenza e' esattamente il coefficiente del modello M3 (teorema di Frisch-Waugh-Lovell).", size(vsmall))
graph export "$FIG/m3_f1_fwl.png", replace width(2400)

*------------------------------------------------------------------------------*
* F2. Leave-one-CAP-out
*------------------------------------------------------------------------------*
capture frame drop loo3
frame create loo3 long cap double b double lb double ub
quietly levelsof capid if s_m3, local(cl)
foreach c of local cl {
    quietly regress `Y' lnAR `FE' if s_m3 & capid != `c', vce(cluster capid)
    quietly summarize cap if capid == `c', meanonly
    local cc = r(mean)
    local cr = invttail(e(df_r), 0.025)
    frame post loo3 (`cc') (_b[lnAR]) (_b[lnAR] - `cr'*_se[lnAR]) (_b[lnAR] + `cr'*_se[lnAR])
}
frame loo3 {
    export delimited using "$TAB/m3_f2_loo.csv", replace
    sort b
    gen int k = _n
    twoway (rcap lb ub k, lcolor(gs10)) (scatter b k, mcolor("37 106 191") msize(small)), ///
        yline(`bmain', lcolor("230 100 50") lpattern(dash)) yline(0, lcolor(gs8)) ///
        xtitle("Stima escludendo un CAP alla volta (ordinate)") ytitle("Coefficiente di ln(affitto/reddito)") ///
        title("Leave-one-CAP-out", size(medsmall)) legend(off) graphregion(color(white)) ///
        note("Linea tratteggiata: stima con tutti i 35 CAP. Barre: IC 95% (errori raggruppati per CAP).", size(vsmall))
    graph export "$FIG/m3_f2_loo.png", replace width(2400)
    summarize b
}
