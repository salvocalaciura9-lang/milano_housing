*==============================================================================*
* 09_model_nil.do
* Primo modello, gia' realizzabile senza redditi CAP:
*   r_post_i = a + b G_social_i + rho r_pre_i + g' Z_i0 + e_i
*   Z = log residenti 2019, % 65+ 2019 (precedono l'esito, non il periodo di
*   upgrading: non sono controlli pre-trattamento). Errori robusti.
* Associazione, non effetto causale. Le uscite successive al 2021 non misurano
* espulsioni gia' avvenute nel decennio: un b nullo o negativo non le esclude.
*
* Campione principale: NIL vigenti con almeno SMALL_NIL residenti nel 2019;
* misure dell'indice portate dai NIL PGT 2012 ai NIL vigenti (modulo 07b).
* Sensibilita': NIL piccoli inclusi, solo NIL senza valori sospetti,
* denominatore medio, WLS, Poisson con esposizione, indice completo a scala
* comune, pesi uguali, indice pubblicato, componenti separate, variazione delle
* uscite. Dipendenza spaziale: Moran sui residui ed errore spaziale (se c'e'
* lo shapefile dei NIL).
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "09 - MODELLO NIL: UPGRADING 2011-21 E USCITE 2022-24" _n "{hline 78}"

if $IX_OK == 0 {
    di as error "  09 saltato: file dell'indice non disponibile o non configurato"
    exit
}

use "$WORK/outmig_nil.dta", clear
* misure dell'indice portate sui NIL vigenti (07b); in mancanza, abbinamento per numero
local gfile "$WORK/gentrif_nilnew.dta"
capture confirm file "`gfile'"
if _rc | "$NILNEW_OK" != "1" {
    local gfile "$WORK/gentrif_nil.dta"
    di as error "  Attenzione: uso l'abbinamento per numero tra NIL vecchi e vigenti"
}
merge 1:1 nil using "`gfile'"
di as txt "  NIL solo nel DS205 (_merge = 1) o solo nel file dell'indice (_merge = 2):"
list nil name_last _merge if _merge != 3, noobs
keep if _merge == 3
drop _merge

* campione principale: NIL con almeno $SMALL_NIL residenti nel 2019. Nei NIL
* quasi vuoti (parchi, aree agricole o in trasformazione) poche persone fanno
* oscillare i tassi per 1.000 di decine di punti e l'upgrading misura poche famiglie.
gen byte s_all  = !missing(r_post, G_social, r_pre, lnpop2019, pct65_2019)
gen byte s_main = s_all & small2019 == 0
quietly count if s_main
di as txt "  Campione principale: " r(N) " NIL (con almeno $SMALL_NIL residenti nel 2019)"
di as txt "  NIL esclusi dal campione principale:"
list nil name_last pop2019 if s_main == 0, noobs
save "$WORK/nil_analysis.dta", replace

local M  "M1 NIL: uscite 2022-24 su upgrading 2011-21"
local X  "r_pre lnpop2019 pct65_2019"

*------------------------------------------------------------------------------*
* Specificazioni principali
*------------------------------------------------------------------------------*
regress r_post G_social if s_main, vce(robust)
saveres, model("`M'") spec("bivariata") coef(G_social)
regress r_post G_social r_pre if s_main, vce(robust)
saveres, model("`M'") spec("+ uscite 2017-19") coef(G_social)
regress r_post G_social `X' if s_main, vce(robust)
saveres, model("`M'") spec("principale: + log residenti e % 65+ 2019") coef(G_social)
estimates store m1_main
predict double res_m1 if e(sample), residuals
quietly summarize G_social if e(sample), detail
local iqrG = r(p75) - r(p25)
di as txt "  Lettura: una differenza di G_social pari all'IQR (" %5.2f `iqrG' ///
    ") e' associata a " %6.2f _b[G_social]*`iqrG' " uscite annue per 1.000 residenti, a parita' dei controlli"

*------------------------------------------------------------------------------*
* Sensibilita' (stessi controlli)
*------------------------------------------------------------------------------*
regress r_post G_social `X' if s_all, vce(robust)
saveres, model("`M'") spec("inclusi NIL < $SMALL_NIL residenti 2019") coef(G_social)

regress r_post G_social `X' if s_main & valid_full == 1, vce(robust)
saveres, model("`M'") spec("solo NIL senza valori sospetti nell'indice") coef(G_social)

regress r_post_avg G_social r_pre_avg lnpop2019 pct65_2019 if s_main, vce(robust)
saveres, model("`M'") spec("denominatore: popolazione media") coef(G_social)

regress r_post G_social `X' if s_main [aweight = N_post], vce(robust)
saveres, model("`M'") spec("ponderata per residenti (WLS)") coef(G_social)

regress r_change G_social lnpop2019 pct65_2019 if s_main, vce(robust)
saveres, model("`M'") spec("esito: r_post - r_pre") coef(G_social)

poisson E_post G_social `X' if s_main, exposure(N_post) vce(robust)
saveres, model("`M'") spec("Poisson con esposizione (semi-elasticita')") coef(G_social) ///
    note("coefficiente su scala log: variazione proporzionale del tasso")

foreach g in dI_common dI_eq dI_paper {
    regress r_post `g' `X' if s_main & !missing(`g'), vce(robust)
    saveres, model("`M'") spec("misura alternativa: `g'") coef(`g') ///
        note("unita' diverse da G_social; indice completo include prezzi e redditi")
}

regress r_post d_edu_std d_emp_std `X' if s_main, vce(robust)
saveres, model("`M'") spec("componenti separate: istruzione") coef(d_edu_std)
saveres, model("`M'") spec("componenti separate: occupazione") coef(d_emp_std)

*------------------------------------------------------------------------------*
* Dipendenza spaziale (shapefile dei NIL in WGS84)
*------------------------------------------------------------------------------*
if $SHP_OK == 1 {
    preserve
    keep if s_main
    keep nil r_post G_social r_pre lnpop2019 pct65_2019
    tempfile est
    save `est'
    local here "`c(pwd)'"
    quietly cd "$GEO"
    capture noisily {
        use "nil_shape.dta", clear
        merge 1:1 nil using `est', keep(match) nogen
        spset
        spmatrix create contiguity W, normalize(row) replace
        quietly regress r_post G_social r_pre lnpop2019 pct65_2019
        estat moran, errorlag(W)
        spregress r_post G_social r_pre lnpop2019 pct65_2019, gs2sls errorlag(W)
        saveres, model("`M'") spec("errore spaziale (contiguita', GS2SLS)") coef(G_social)
    }
    local rc = _rc
    quietly cd "`here'"
    restore
    if `rc' di as error "  Blocco spaziale non completato (rc = `rc'): controllare shapefile e codici NIL"
}
else {
    di as txt "  (test spaziali saltati: shapefile dei NIL non disponibile)"
}

estimates restore m1_main
estimates replay m1_main
