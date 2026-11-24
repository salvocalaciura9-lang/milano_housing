*==============================================================================*
* 15_robustness.do
* Controlli di robustezza, con attenzione alla correlazione tra redditi e
* prezzi (affitto/compravendita):
*   A. diagnostica: correlazioni pooled, between e WITHIN (dopo effetti fissi)
*      tra log reddito, log affitto e log prezzo; VIF; NIL 2011-21
*   B. pannello FE: scomposizione di log(A) = log(affitto) - log(reddito),
*      test della restrizione del rapporto, affitto e reddito separati
*   C. pannello FE: xtreg, differenze prime, trend lineari per CAP, placebo
*      temporale, leave-one-CAP-out, wild cluster bootstrap delle stime
*      significative
*   D. modello CAP (variazioni): scomposizione della variazione di A, livelli
*      iniziali come controlli (con VIF), effetti fissi di fascia OMI,
*      regressione robusta, I di Moran sui residui (contiguita' CAP)
*   E. modello NIL: NIL con codici dubbi, outlier (dfbeta), regressione
*      robusta e mediana, effetti fissi di fascia OMI, reddito e prezzo 2011
*      come controlli (con VIF)
*
* Output: $TAB/robustness.csv/.xlsx, $TAB/robust_correlations.csv,
*         $TAB/robust_loo.csv
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "15 - ROBUSTEZZA E CORRELAZIONE REDDITI-PREZZI" _n "{hline 78}"

if $XW_OK == 0 | $IX_OK == 0 {
    di as error "  15 saltato: servono indice (05) e raccordo (10)"
    exit
}

capture frame drop rob
frame create rob str40 block str90 spec str16 coef double b double se double p ///
    double p_boot long N str160 note
capture frame drop corrs
frame create corrs str60 level str8 pair double r double vif long N

capture program drop robsave
program define robsave
    syntax , Block(string) Spec(string) Coef(string) [Note(string) PBoot(real -999)]
    tempname b se p
    scalar `b'  = _b[`coef']
    scalar `se' = _se[`coef']
    if missing(e(df_r)) scalar `p' = 2*normal(-abs(`b'/`se'))
    else                scalar `p' = 2*ttail(e(df_r), abs(`b'/`se'))
    local pb = cond(`pboot' == -999, ., `pboot')
    frame post rob ("`block'") ("`spec'") ("`coef'") (`b') (`se') (`p') (`pb') (e(N)) ("`note'")
    local pbs ""
    if `pb' < . local pbs = ", p boot " + string(`pb', "%5.3f")
    di as txt "  -> " as res "`spec'" as txt ": `coef' = " as res %9.4f `b' ///
        as txt " (se " %7.4f `se' ", p " %5.3f `p' "`pbs')  N = " e(N)
end

capture program drop bootp
program define bootp, rclass
    args coef
    capture noisily boottest `coef', reps($BOOTREPS) weighttype(webb) seed($SEED) nograph
    if _rc return scalar p = -999
    else   return scalar p = r(p)
end

capture program drop postcorr
program define postcorr
    syntax varlist(min=3 max=3) [if], Level(string)
    quietly corr `varlist' `if'
    tempname C
    matrix `C' = r(C)
    local n = r(N)
    local names "Y-R Y-P R-P"
    local k 0
    foreach ij in "1 2" "1 3" "2 3" {
        local ++k
        tokenize `ij'
        local r = `C'[`1', `2']
        local pr : word `k' of `names'
        frame post corrs ("`level'") ("`pr'") (`r') (1/(1 - `r'^2)) (`n')
    }
    di as txt "  " %-44s "`level'" "  r(Y,R) = " as res %6.3f `C'[1,2] ///
        as txt "  r(Y,P) = " as res %6.3f `C'[1,3] as txt "  r(R,P) = " as res %6.3f `C'[2,3] ///
        as txt "  N = " `n'
end

*==============================================================================*
* A. DIAGNOSTICA DELLE CORRELAZIONI
*==============================================================================*
di as txt _n "  {ul:A. Correlazioni tra reddito (Y), affitto (R) e prezzo (P), in log}"
use "$WORK/cap_panel_main_est.dta", clear
xtset capid year
gen double lnY  = ln(ybar_imp)
gen double lnR  = ln(R_mid)
gen double lnP  = ln(P_mid)
gen double lnYl = ln(ybar_lav)
label variable lnY "log reddito imponibile medio"
label variable lnR "log affitto OMI (EUR/m2/mese)"
label variable lnP "log prezzo OMI (EUR/m2)"
gen byte s_c = inrange(year, $Y0A, $Y1) & cover_ok == 1 & !missing(lnY, lnR, lnP)

* (1) pooled: confronta CAP diversi e anni diversi insieme
postcorr lnY lnR lnP if s_c, level("CAP-anno, pooled (livelli)")

* (2) between: medie di CAP (differenze permanenti tra CAP)
preserve
keep if s_c
collapse (mean) lnY lnR lnP, by(capid)
postcorr lnY lnR lnP, level("CAP, between (medie 2019-23)")
restore

* (3) within: residui dopo effetti fissi di CAP e anno = variazione usata in M3
foreach v in lnY lnR lnP {
    quietly regress `v' i.capid i.year if s_c
    local r2_`v' = e(r2)
    predict double w_`v' if s_c, residuals
    quietly summarize w_`v'
    local sdw_`v' = r(sd)
    quietly summarize `v' if s_c
    local sdt_`v' = r(sd)
}
postcorr w_lnY w_lnR w_lnP if s_c, level("CAP-anno, within (dopo FE CAP e anno)")
di as txt "  Quota della varianza assorbita dagli effetti fissi (R2) e dev. std. residua:"
foreach v in lnY lnR lnP {
    di as txt "    `v': R2 FE = " as res %5.3f `r2_`v'' as txt ",  sd totale = " as res %6.4f `sdt_`v'' ///
        as txt ",  sd within = " as res %6.4f `sdw_`v''
}

* (4) variazioni 2019-23 (sezione trasversale del modello M2)
foreach v in lnY lnR lnP lnYl {
    bysort cap: egen double t0 = max(cond(year == $Y0A, `v', .))
    bysort cap: egen double t1 = max(cond(year == $Y1,  `v', .))
    gen double d`v' = t1 - t0
    bysort cap: egen double `v'0 = max(cond(year == $Y0A, `v', .))
    drop t0 t1
}
preserve
keep if year == $Y1 & cover_ok == 1
postcorr dlnY dlnR dlnP, level("CAP, variazioni 2019-23")
postcorr lnY0 lnR0 lnP0, level("CAP, livelli 2019")
restore
save "$WORK/rob_cap_panel.dta", replace

* (5) NIL: componenti dell'indice 2011 e 2021
use "$WORK/nil_analysis.dta", clear
gen double lninc11 = ln(inc2011)   if inc2011 > 0
gen double lninc21 = ln(inc2021)   if inc2021 > 0
gen double lnpr11  = ln(price2011) if price2011 > 0
gen double lnpr21  = ln(price2021) if price2021 > 0
gen double dlninc  = lninc21 - lninc11
gen double dlnpr   = lnpr21 - lnpr11
postcorr lninc11 lnpr11 edu2011 if valid_full == 1, level("NIL 2011: reddito, prezzo, istruzione")
postcorr lninc21 lnpr21 edu2021 if valid_full == 1, level("NIL 2021: reddito, prezzo, istruzione")
postcorr dlninc dlnpr G_social if valid_full == 1, level("NIL var. 2011-21: reddito, prezzo, G_social")
di as txt "  (nella riga NIL, 'R' = prezzo e 'P' = terza variabile: vedi etichetta)"
save "$WORK/rob_nil.dta", replace

frame corrs: export delimited using "$TAB/robust_correlations.csv", replace

*==============================================================================*
* B. PANNELLO FE: SCOMPOSIZIONE DEL RAPPORTO AFFITTO/REDDITO
*    log A = log(12*60) + log R - log Y. Se l'effetto passa davvero dal
*    rapporto, i coefficienti di log R e log Y sono uguali e opposti.
*==============================================================================*
di as txt _n "  {ul:B. Pannello FE: affitto e reddito separati}"
use "$WORK/rob_cap_panel.dta", clear
xtset capid year
local FE "i.year i.capid"
local B "B. FE: scomposizione"

regress r_lead1 lnAR `FE' if s_fe, vce(cluster capid)
robsave, block("`B'") spec("riferimento: log affitto/reddito") coef(lnAR)

regress r_lead1 lnR lnY `FE' if s_fe, vce(cluster capid)
test lnR + lnY = 0
local pt = r(p)
robsave, block("`B'") spec("log affitto e log reddito insieme") coef(lnR) ///
    note("test b(R) = -b(Y): p = `: di %5.3f `pt''")
robsave, block("`B'") spec("log affitto e log reddito insieme") coef(lnY) ///
    note("test b(R) = -b(Y): p = `: di %5.3f `pt''")

regress r_lead1 lnR `FE' if s_fe, vce(cluster capid)
robsave, block("`B'") spec("solo log affitto") coef(lnR)
regress r_lead1 lnY `FE' if s_fe, vce(cluster capid)
robsave, block("`B'") spec("solo log reddito") coef(lnY)

regress r_lead1 lnP lnY `FE' if s_fe, vce(cluster capid)
test lnP + lnY = 0
local pt = r(p)
robsave, block("`B'") spec("log prezzo e log reddito insieme") coef(lnP) ///
    note("test b(P) = -b(Y): p = `: di %5.3f `pt''")
robsave, block("`B'") spec("log prezzo e log reddito insieme") coef(lnY) ///
    note("test b(P) = -b(Y): p = `: di %5.3f `pt''")

* affitto e prezzo insieme: collinearita' within (VIF calcolato sotto)
quietly regress lnR lnP `FE' if s_fe
local vifRP = 1/(1 - e(r2))
regress r_lead1 lnR lnP lnY `FE' if s_fe, vce(cluster capid)
robsave, block("`B'") spec("log affitto, log prezzo e log reddito insieme") coef(lnR) ///
    note("VIF di lnR (FE inclusi) = `: di %6.1f `vifRP''")
robsave, block("`B'") spec("log affitto, log prezzo e log reddito insieme") coef(lnP) ///
    note("VIF di lnR (FE inclusi) = `: di %6.1f `vifRP''")
di as txt "  VIF di log affitto rispetto a log prezzo + effetti fissi: " as res %6.1f `vifRP'

*==============================================================================*
* C. PANNELLO FE: ROBUSTEZZA
*==============================================================================*
di as txt _n "  {ul:C. Pannello FE: robustezza}"
local C "C. FE: robustezza"

* stimatore within (xtreg) = LSDV: controllo di coerenza
xtreg r_lead1 lnAR i.year if s_fe, fe vce(cluster capid)
robsave, block("`C'") spec("xtreg, fe (equivale a LSDV)") coef(lnAR) ///
    note("R2 within = `: di %5.3f e(r2_w)'")

* differenze prime
gen double D_r    = D.r_lead1
gen double D_lnAR = D.lnAR
regress D_r D_lnAR i.year if s_fe & L.s_fe, vce(cluster capid)
robsave, block("`C'") spec("differenze prime (al posto degli effetti fissi)") coef(D_lnAR)

* trend lineari specifici per CAP
regress r_lead1 lnAR i.year i.capid i.capid#c.year if s_fe, vce(cluster capid)
robsave, block("`C'") spec("+ trend lineare per CAP") coef(lnAR) ///
    note("molto esigente: 5 anni per CAP")

* placebo temporale: l'affordability di oggi non dovrebbe 'spiegare' le uscite passate
gen double r_lag1 = L.r_emig
regress r_lag1 lnAR `FE' if s_fe & !missing(r_lag1), vce(cluster capid)
robsave, block("`C'") spec("placebo: uscite in t-1 su log A in t") coef(lnAR) ///
    note("atteso ~0; un effetto segnala trend comuni o causalita' inversa")
regress r_emig lnAR `FE' if s_fe, vce(cluster capid)
robsave, block("`C'") spec("uscite nello stesso anno t") coef(lnAR)

* CAP con il salto anomalo dei contribuenti nel 2023
regress r_lead1 lnAR `FE' if s_fe & cap != 20121, vce(cluster capid)
robsave, block("`C'") spec("escluso CAP 20121 (salto contribuenti 2023)") coef(lnAR)

* errori standard: cluster per CAP vs robusti semplici
regress r_lead1 lnAR `FE' if s_fe, vce(robust)
robsave, block("`C'") spec("errori robusti non raggruppati (confronto)") coef(lnAR)

* wild cluster bootstrap delle specificazioni significative (pochi cluster)
regress r_lead1 lnAR_base `FE' if s_fe & !missing(lnAR_base), vce(cluster capid)
bootp lnAR_base
robsave, block("`C'") spec("bootstrap: pressione con reddito 2019 rivalutato") coef(lnAR_base) pboot(`r(p)')
gen byte s_fe2 = inrange(year, $Y0A, $Y1) & !missing(lnAR, r_lead2) & cover_ok == 1
regress r_lead2 lnAR `FE' if s_fe2, vce(cluster capid)
bootp lnAR
robsave, block("`C'") spec("bootstrap: esito in t+2") coef(lnAR) pboot(`r(p)')
regress r_lead1 lnAR lnAR_x_vuln `FE' if s_fe & !missing(vuln), vce(cluster capid)
bootp lnAR_x_vuln
robsave, block("`C'") spec("bootstrap: differenza CAP vulnerabili") coef(lnAR_x_vuln) pboot(`r(p)')
regress r_lead1 lnR lnY `FE' if s_fe, vce(cluster capid)
bootp lnR
robsave, block("`C'") spec("bootstrap: log affitto (con log reddito)") coef(lnR) pboot(`r(p)')

* leave-one-CAP-out
capture frame drop loo
frame create loo str40 spec long capid_out long cap_out double b double p
capture program drop loorun
program define loorun
    args spec dep x cond
    quietly levelsof capid if `cond', local(cl)
    foreach c of local cl {
        quietly regress `dep' `x' i.year i.capid if `cond' & capid != `c', vce(cluster capid)
        quietly summarize cap if capid == `c', meanonly
        local cc = r(mean)
        frame post loo ("`spec'") (`c') (`cc') (_b[`x']) (2*ttail(e(df_r), abs(_b[`x']/_se[`x'])))
    }
end
loorun "principale" r_lead1 lnAR "s_fe"
loorun "pressione: lnAR_base" r_lead1 lnAR_base "s_fe & !missing(lnAR_base)"
loorun "esito in t+2" r_lead2 lnAR "s_fe2"
frame loo {
    export delimited using "$TAB/robust_loo.csv", replace
    di as txt "  Leave-one-CAP-out (35 stime per specificazione):"
    gen byte sig = p < 0.05
    gen byte pos = b > 0
    tabstat b p sig pos, by(spec) stats(min max mean) format(%8.3f)
}

*==============================================================================*
* D. MODELLO CAP DELLE VARIAZIONI (M2)
*==============================================================================*
di as txt _n "  {ul:D. Modello CAP delle variazioni: robustezza}"
local D "D. CAP variazioni"
use "$WORK/rob_cap_panel.dta", clear
keep if year == $Y1
keep cap dlnY dlnR dlnP dlnYl lnY0 lnR0 lnP0 dlnAR dlnAP G_social_cap lnpop2019c pct65_2019c cover_ok

* fascia OMI prevalente del CAP (B centro, C semicentro, D periferia, E/R suburbana)
preserve
use "$WORK/xw_omi_cap_main.dta", clear
drop if zona == "NESSUNA"
gsort cap -w
by cap: keep if _n == 1
gen str1 fascia = substr(zona, 1, 1)
replace fascia = "E" if fascia == "R"
keep cap fascia
tempfile fc
save `fc'
restore
merge 1:1 cap using `fc', keep(master match) nogen
encode fascia, gen(fasc)
tab fascia if cover_ok == 1

local Zc "lnpop2019c pct65_2019c"
local s "cover_ok == 1"
regress dlnAR G_social_cap `Zc' if `s', vce(hc3)
robsave, block("`D'") spec("riferimento: var. log affitto/reddito") coef(G_social_cap)

* scomposizione: dlnAR = dlnR - dlnY
foreach y in dlnR dlnY dlnP dlnYl {
    regress `y' G_social_cap `Zc' if `s', vce(hc3)
    robsave, block("`D'") spec("esito: `y' (componente)") coef(G_social_cap)
}

* livelli iniziali come controlli (fortemente correlati: VIF)
foreach c in "lnY0" "lnR0" "lnY0 lnR0" "lnY0 lnP0" {
    quietly regress dlnAR G_social_cap `Zc' `c' if `s'
    quietly estat vif
    local vmax = r(vif_1)
    forvalues k = 2/`=wordcount("G_social_cap `Zc' `c'")' {
        if r(vif_`k') > `vmax' local vmax = r(vif_`k')
    }
    regress dlnAR G_social_cap `Zc' `c' if `s', vce(hc3)
    robsave, block("`D'") spec("+ livelli 2019: `c'") coef(G_social_cap) note("VIF massimo = `: di %5.1f `vmax''")
}
quietly regress dlnAR G_social_cap `Zc' lnY0 lnR0 if `s'
di as txt "  VIF con log reddito e log affitto 2019 insieme:"
estat vif

* effetti fissi di fascia OMI
regress dlnAR G_social_cap `Zc' i.fasc if `s', vce(hc3)
robsave, block("`D'") spec("+ effetti fissi di fascia OMI") coef(G_social_cap)

* regressione robusta agli outlier
rreg dlnAR G_social_cap `Zc' if `s'
robsave, block("`D'") spec("regressione robusta (rreg)") coef(G_social_cap)

* I di Moran sui residui (contiguita' dei poligoni CAP)
quietly regress dlnAR G_social_cap `Zc' if `s'
predict double res_m2 if e(sample), residuals
keep cap res_m2 dlnAR G_social_cap `Zc' cover_ok
tempfile m2
save `m2'
local here "`c(pwd)'"
quietly cd "$GEO"
capture noisily {
    use "cap_poste.dta", clear
    gen long cap = real(CAP)
    merge 1:1 cap using `m2', keep(match) nogen
    keep if cover_ok == 1
    spset, modify coordsys(latlong, kilometers)
    spmatrix create contiguity Wcap, normalize(row) replace
    regress dlnAR G_social_cap `Zc'
    estat moran, errorlag(Wcap)
    local pm = r(p)
    di as txt "  I di Moran sui residui del modello CAP: p = " as res %5.3f `pm'
    spregress dlnAR G_social_cap `Zc', gs2sls errorlag(Wcap)
    robsave, block("`D'") spec("errore spaziale (contiguita' CAP, GS2SLS)") coef(G_social_cap) ///
        note("Moran sui residui OLS: p = `: di %5.3f `pm''")
}
quietly cd "`here'"

*==============================================================================*
* E. MODELLO NIL (M1)
*==============================================================================*
di as txt _n "  {ul:E. Modello NIL: robustezza}"
local E "E. NIL"
use "$WORK/rob_nil.dta", clear

* fascia OMI prevalente del NIL
preserve
import delimited using "$AUX/xw_nil_omi_area.csv", clear varnames(1)
gsort nil -w
by nil: keep if _n == 1
gen str1 fascia = substr(zona, 1, 1)
replace fascia = "E" if fascia == "R"
keep nil fascia
tempfile fn
save `fn'
restore
merge 1:1 nil using `fn', keep(master match) nogen
encode fascia, gen(fasc)

local X "r_pre lnpop2019 pct65_2019"
regress r_post G_social `X' if s_main, vce(robust)
robsave, block("`E'") spec("riferimento") coef(G_social)

regress r_post G_social `X' if s_all, vce(robust)
robsave, block("`E'") spec("inclusi NIL < $SMALL_NIL residenti 2019") coef(G_social)

* osservazioni influenti
quietly regress r_post G_social `X' if s_main
dfbeta G_social, stub(dfb_)
quietly count if s_main
gen byte infl = abs(dfb_1) > 2/sqrt(r(N)) if s_main
quietly count if infl == 1
local ninf = r(N)
di as txt "  NIL influenti (|dfbeta| > 2/sqrt(N)): `ninf'"
list nil name_last r_post G_social dfb_1 if infl == 1, noobs
regress r_post G_social `X' if s_main & infl == 0, vce(robust)
robsave, block("`E'") spec("esclusi NIL influenti (dfbeta)") coef(G_social) note("`ninf' NIL esclusi")

rreg r_post G_social `X' if s_main
robsave, block("`E'") spec("regressione robusta (rreg)") coef(G_social)
qreg r_post G_social `X' if s_main, vce(robust)
robsave, block("`E'") spec("regressione mediana (qreg)") coef(G_social)

regress r_post G_social `X' i.fasc if s_main, vce(robust)
robsave, block("`E'") spec("+ effetti fissi di fascia OMI") coef(G_social)

* reddito e prezzo iniziali: correlati tra loro (VIF)
foreach c in "lninc11" "lnpr11" "lninc11 lnpr11" {
    quietly regress r_post G_social `X' `c' if s_main & valid_full == 1
    quietly estat vif
    local vmax = r(vif_1)
    forvalues k = 2/`=wordcount("G_social `X' `c'")' {
        if r(vif_`k') > `vmax' local vmax = r(vif_`k')
    }
    regress r_post G_social `X' `c' if s_main & valid_full == 1, vce(robust)
    robsave, block("`E'") spec("+ livelli 2011: `c'") coef(G_social) note("VIF massimo = `: di %5.1f `vmax''")
}
quietly regress r_post G_social `X' lninc11 lnpr11 if s_main & valid_full == 1
di as txt "  VIF con log reddito e log prezzo 2011 insieme:"
estat vif

*==============================================================================*
frame rob {
    export delimited using "$TAB/robustness.csv", replace
    export excel using "$TAB/robustness.xlsx", firstrow(variables) replace
    di as txt _n "  Stime di robustezza: " _N " (in $TAB/robustness.xlsx)"
}
