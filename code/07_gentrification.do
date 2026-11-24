*==============================================================================*
* 07_gentrification.do
* A. Replica dell'indice pubblicato: per ciascun anno, componenti centrate
*    sulla mediana e divise per l'IQR dell'anno (quantili type 7 di R), pesi
*    del paper, costante 10 (non esplicitata nell'eq. 1 del paper):
*      I_it = 10 + .42772 z_inc + .39892 z_price + .24167 z_edu + .32761 z_emp
* B. Replica della PCA: 176 record NIL-anno con mediana e IQR comuni
* C. Versione comparabile nel tempo: centro e scala fissati sul 2011 (campione
*    valido), stessi pesi, importi 2021 convertiti a prezzi 2011 se c'e' il CPI.
*    Variazioni in punti, non percentuali (l'origine dell'indice e' arbitraria).
*    Sensibilita': pesi uguali.
* D. Upgrading sociale (misura alternativa per l'analisi con affordability):
*      G_social = 1/2 [ dEdu / IQR2011(Edu) + dEmp / IQR2011(Emp) ]
* E. Classificazione descrittiva trasparente e quartili (relativi al campione)
*
* Output: $WORK/gentrif_nil.dta, $WORK/index_replication_long.dta
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "07 - GENTRIFICAZIONE E UPGRADING SOCIALE" _n "{hline 78}"

if $IX_OK == 0 {
    di as error "  07 saltato: file dell'indice non disponibile o non configurato (vedi modulo 05)"
    exit
}

tokenize $W_PAPER
local w_inc   `1'
local w_price `2'
local w_edu   `3'
local w_emp   `4'

use "$WORK/index_nil.dta", clear

*------------------------------------------------------------------------------*
* A-B. Replica (formato lungo: 176 record NIL-anno)
*------------------------------------------------------------------------------*
preserve
local stubs inc price edu emp idx
foreach s in zy_inc zy_price zy_edu zy_emp {
    capture confirm variable `s'2011 `s'2021
    if !_rc local stubs `stubs' `s'
}
local kv nil name_ix valid_full valid_social
foreach s of local stubs {
    local kv `kv' `s'2011 `s'2021
}
keep `kv'
reshape long `stubs', i(nil) j(year)

foreach v in inc price edu emp {
    gen double zr_`v' = .
    foreach t in 2011 2021 {
        rpar `v' if year == `t'
        quietly replace zr_`v' = (`v' - r(med))/r(iqr) if year == `t'
    }
}
gen double idx_rep = 10 + `w_inc'*zr_inc + `w_price'*zr_price + `w_edu'*zr_edu + `w_emp'*zr_emp
gen double d_rep = idx_rep - idx
summarize d_rep
local maxd = max(abs(r(min)), abs(r(max)))
if `maxd' < 0.001 {
    di as txt "  [OK] replica dell'indice pubblicato: scarto massimo " %9.6f `maxd'
}
else {
    di as error "  [DIVERSO] scarto massimo " %9.6f `maxd' ": verificare colonne, campione e definizione dei quartili"
}
correlate idx_rep idx

foreach v in inc price edu emp {
    capture confirm variable zy_`v'
    if !_rc {
        gen double dz_`v' = zr_`v' - zy_`v'
        quietly summarize dz_`v'
        di as txt "  colonna .y di `v': scarto massimo " %9.6f max(abs(r(min)), abs(r(max)))
    }
}

* PCA sui 176 record con mediana e IQR comuni ai due anni
foreach v in inc price edu emp {
    rpar `v'
    gen double zp_`v' = (`v' - r(med))/r(iqr)
}
* il paper usa la PCA sulla matrice di covarianza delle variabili scalate (86,22%);
* la versione sulla correlazione e' riportata sotto solo per confronto
pca zp_inc zp_price zp_edu zp_emp, covariance
matrix Ev = e(Ev)
local cum2 = 100*(Ev[1,1] + Ev[1,2])/(Ev[1,1] + Ev[1,2] + Ev[1,3] + Ev[1,4])
checkval, label("Varianza spiegata dalle prime due componenti, PCA covarianza (%)") value(`cum2') expected(86.22) tol(0.05)
matrix list e(L), format(%8.5f)
di as txt "  Pesi usati (dal paper): `w_inc' `w_price' `w_edu' `w_emp'. Confrontare con i loading"
di as txt "  sopra seguendo la derivazione del paper (pp. 4-6) prima di riportarli come replicati."
pca zp_inc zp_price zp_edu zp_emp

save "$WORK/index_replication_long.dta", replace
restore

*------------------------------------------------------------------------------*
* C. Versione a scala comune (riferimento 2011, campione valido)
*------------------------------------------------------------------------------*
local realok 0
if $REAL_HIST == 1 {
    capture confirm file "$WORK/cpi.dta"
    if !_rc {
        preserve
        use "$WORK/cpi.dta", clear
        local c11 ""
        local c21 ""
        quietly summarize cpi if year == 2011, meanonly
        if r(N) == 1 local c11 = r(mean)
        quietly summarize cpi if year == 2021, meanonly
        if r(N) == 1 local c21 = r(mean)
        restore
        if "`c11'" != "" & "`c21'" != "" local realok 1
    }
}
gen double inc2011_r   = inc2011
gen double price2011_r = price2011
gen double inc2021_r   = inc2021
gen double price2021_r = price2021
if `realok' {
    replace inc2021_r   = inc2021   * `c11'/`c21'
    replace price2021_r = price2021 * `c11'/`c21'
    di as txt "  Reddito e prezzi 2021 convertiti a prezzi 2011 (CPI 2011 = `c11', 2021 = `c21')"
}
else {
    di as txt "  CPI 2011/2021 non disponibile o REAL_HIST = 0: versione comune in termini nominali"
}
label variable inc2021_r   "Reddito 2021 (a prezzi 2011 se CPI disponibile)"
label variable price2021_r "Valori immobiliari 2021 (a prezzi 2011 se CPI disponibile)"

foreach v in inc price edu emp {
    local suf = cond(inlist("`v'", "inc", "price"), "_r", "")
    rpar `v'2011`suf' if valid_full == 1
    scalar sc_m = r(med)
    scalar sc_s = r(iqr)
    di as txt "  `v': mediana 2011 = " %10.3f sc_m ", IQR 2011 = " %10.3f sc_s " (N = " r(N) ")"
    foreach t in 2011 2021 {
        gen double zc_`v'`t' = (`v'`t'`suf' - sc_m)/sc_s
    }
}
foreach t in 2011 2021 {
    gen double Ic`t'  = `w_inc'*zc_inc`t' + `w_price'*zc_price`t' + `w_edu'*zc_edu`t' + `w_emp'*zc_emp`t'
    gen double Ieq`t' = (zc_inc`t' + zc_price`t' + zc_edu`t' + zc_emp`t')/4
}
gen double dI_common = Ic2021 - Ic2011   if valid_full == 1
gen double dI_eq     = Ieq2021 - Ieq2011 if valid_full == 1
gen double dI_paper  = idx2021 - idx2011
gen double pct_paper = 100*dI_paper/idx2011
label variable dI_common "Variazione indice a scala comune 2011, pesi del paper (punti)"
label variable dI_eq     "Variazione indice a scala comune 2011, pesi uguali (punti)"
label variable dI_paper  "Variazione indice pubblicato (scala diversa per anno)"
label variable pct_paper "Variazione % indice pubblicato (dipende dalla costante 10)"

*------------------------------------------------------------------------------*
* D. Upgrading sociale
*------------------------------------------------------------------------------*
rpar edu2011 if valid_social == 1
scalar iqr_edu = r(iqr)
rpar emp2011 if valid_social == 1
scalar iqr_emp = r(iqr)
gen double d_edu_std = (edu2021 - edu2011)/iqr_edu if valid_social == 1
gen double d_emp_std = (emp2021 - emp2011)/iqr_emp if valid_social == 1
gen double G_social  = (d_edu_std + d_emp_std)/2
label variable d_edu_std "Variazione istruzione 2011-21 / IQR 2011"
label variable d_emp_std "Variazione occupazione 2011-21 / IQR 2011"
label variable G_social  "Upgrading sociale 2011-21 (media delle due variazioni standardizzate)"
summarize G_social d_edu_std d_emp_std dI_common dI_eq dI_paper

*------------------------------------------------------------------------------*
* E. Classificazione descrittiva (presentata come relativa al campione)
*------------------------------------------------------------------------------*
rpar inc2011 if valid_full == 1
gen byte low_inc11 = (inc2011 < r(med)) if valid_full == 1
rpar dI_common if valid_full == 1
gen byte up_score  = (dI_common > r(med)) if valid_full == 1
gen byte up_social = (G_social > 0) if valid_full == 1 & !missing(G_social)
gen byte gent_rule = (low_inc11 == 1 & up_score == 1 & up_social == 1) ///
    if valid_full == 1 & !missing(G_social)
rpar dI_paper if valid_full == 1
gen byte gent_rule_paper = (low_inc11 == 1 & dI_paper > r(med) & up_social == 1) ///
    if valid_full == 1 & !missing(G_social)
label variable low_inc11 "Reddito 2011 sotto la mediana"
label variable up_score  "Crescita dell'indice comune sopra la mediana"
label variable up_social "Upgrading sociale positivo"
label variable gent_rule "Segnali di gentrificazione: reddito iniziale basso, crescita indice e upgrading sociale"
label variable gent_rule_paper "Come gent_rule ma con la variazione dell'indice pubblicato"

tab gent_rule
di as txt "  NIL con segnali di gentrificazione (regola principale):"
list nil name_ix inc2011 dI_common G_social if gent_rule == 1, noobs
di as txt "  Stabilita' della classificazione rispetto all'indice pubblicato:"
tab gent_rule gent_rule_paper

xtile q_dIc = dI_common if valid_full == 1, nq(4)
xtile q_dIp = dI_paper  if valid_full == 1, nq(4)
xtile q_G   = G_social  if valid_full == 1, nq(4)
label variable q_dIc "Quartile della variazione dell'indice comune"
label variable q_dIp "Quartile della variazione dell'indice pubblicato"
label variable q_G   "Quartile dell'upgrading sociale"
tab q_dIc q_dIp
tab q_dIc q_G
spearman dI_common dI_paper dI_eq G_social if valid_full == 1, stats(rho obs)

sort nil
save "$WORK/gentrif_nil.dta", replace
export delimited nil name_ix valid_full valid_social dI_common dI_eq dI_paper pct_paper ///
    G_social d_edu_std d_emp_std gent_rule q_dIc q_G using "$TAB/gentrification_nil.csv", replace
