*==============================================================================*
* 19g_m4_tabella_stime.do
* M4: tabella unica di tutte le stime e tabella delle date di trattamento
*
* 1. m4_estimates_all.csv: per ogni stima dei moduli 19-19f
*      modulo, stima, esito, metodo di stima, coefficiente, IC95 (estremi),
*      p-value, metodo di inferenza, aree trattate, controlli, periodi usati,
*      periodi dopo l'apertura per gruppo, placebo prima dell'apertura e suo p.
*    Per gli esiti in logaritmo (lnR, lnP) anche coefficiente e IC in %.
*    IC95: C&S ed esposizione continua -> inversione del test di permutazione
*    (stima +/- 95-esimo percentile dei valori assoluti delle stime permutate);
*    synthetic DiD -> stima +/- 1,96 x errore standard placebo; TWFE -> errori
*    cluster. Controllo sintetico per zona (19f): p di Cavallo et al. (2013),
*    senza IC.
* 2. m4_treatment_timing.csv: date di apertura, primo periodo trattato, periodi
*    dopo l'apertura effettivamente nei dati (zone: semestri OMI; NIL: anni con
*    le uscite), aree trattate per gruppo nel disegno principale.
*
* Input:  i CSV dei moduli 19-19f in $TAB; m4_zone_panel.dta, m4_nil_panel.dta
* Output: $TAB/m4_estimates_all.csv, $TAB/m4_treatment_timing.csv
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "19g - M4: TABELLA UNICA DELLE STIME" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in RAW:data/raw WORK:data/work TAB:output/tables CODE:code {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}

tempfile all
local first 1

* --- risultati nel formato m4cs (C&S) ------------------------------------------
foreach f in "m4_cs_results|19 principale" "m4_cs_results_r800|19b raggio 800 m" ///
    "m4_cs_results_r1000|19b raggio 1.000 m" "m4_cs_results_t10|19b soglia 10%" ///
    "m4_cs_results_t30|19b soglia 30%" "m4_loo|19b senza un'area" ///
    "m4_cantieri_results|19c inizio cantieri" "m4_sdid_cs_compare|19e C&S sul campione sdid" ///
    "m4_timing_robustness|19b periodo di apertura" ///
    "m4_dr_results|19f Daniele-Romito" {
    gettoken fn mod : f, parse("|")
    local mod = substr("`mod'", 2, .)
    capture confirm file "$TAB/`fn'.csv"
    if _rc {
        di as txt "  (manca `fn'.csv)"
        continue
    }
    import delimited using "$TAB/`fn'.csv", clear varnames(1) stringcols(_all)
    capture confirm variable ci_lo
    if _rc {
        di as error "  `fn'.csv senza IC: rieseguire il modulo che lo produce"
        continue
    }
    destring att p_perm pre p_perm_pre nt nc ci_lo ci_hi, replace force
    gen str40 modulo = "`mod'"
    gen str40 metodo_stima = cond(regexm(spec, "TWFE"), "TWFE (effetti fissi)", "Callaway-Sant'Anna")
    rename (att p_perm pre p_perm_pre nt nc metodo) (coef p pre p_pre n_trattate n_controlli metodo_inferenza)
    keep modulo spec outcome metodo_stima coef ci_lo ci_hi p metodo_inferenza n_trattate n_controlli ///
        periodi post pre p_pre
    if !`first' append using `all'
    save `all', replace
    local first 0
}

* --- esposizione continua (19d) ------------------------------------------------
capture confirm file "$TAB/m4_dose_results.csv"
if !_rc {
    import delimited using "$TAB/m4_dose_results.csv", clear varnames(1) stringcols(_all)
    capture confirm variable ci_lo
    if !_rc {
        destring b p_perm pre p_perm_pre nd nc ci_lo ci_hi dose_mean, replace force
        gen str40 modulo = "19d esposizione continua"
        gen str40 metodo_stima = "C&S continuo (pendenza, esposizione 0-1)"
        rename (b p_perm pre p_perm_pre nd nc metodo) (coef p pre p_pre n_trattate n_controlli metodo_inferenza)
        gen str160 post = "pendenza per quota servita = 1; esposizione media " + string(dose_mean, "%4.2f")
        keep modulo spec outcome metodo_stima coef ci_lo ci_hi p metodo_inferenza n_trattate n_controlli ///
            periodi post pre p_pre
        append using `all'
        save `all', replace
    }
}

* --- synthetic DiD (19e, 19f) ----------------------------------------------------
foreach f in "m4_sdid_results|19e synthetic DiD|campione" "m4_dr_sdid|19f Daniele-Romito|spec" {
    gettoken fn rest : f, parse("|")
    local rest = substr("`rest'", 2, .)
    gettoken mod sv : rest, parse("|")
    local sv = substr("`sv'", 2, .)
    capture confirm file "$TAB/`fn'.csv"
    if _rc continue
    import delimited using "$TAB/`fn'.csv", clear varnames(1) stringcols(_all)
    capture confirm variable ci_lo
    if _rc continue
    destring att p nt nc ci_lo ci_hi, replace force
    capture destring pre, replace force
    capture confirm variable pre
    if _rc gen double pre = .
    gen double p_pre = .
    gen str40 modulo = "`mod'"
    gen str40 metodo_stima = cond(metodo == "sdid", "synthetic DiD", cond(metodo == "did", "DiD classico (stesso campione)", "controllo sintetico"))
    rename (`sv' att nt nc metodo_inf) (spec coef n_trattate n_controlli metodo_inferenza)
    gen str160 post = ""
    keep modulo spec outcome metodo_stima coef ci_lo ci_hi p metodo_inferenza n_trattate n_controlli ///
        periodi post pre p_pre
    append using `all'
    save `all', replace
}

* --- controllo sintetico zona per zona (19f) ------------------------------------
capture confirm file "$TAB/m4_dr_sc_summary.csv"
if !_rc {
    import delimited using "$TAB/m4_dr_sc_summary.csv", clear varnames(1) stringcols(_all)
    destring att p_agg nt j n_p10, replace force
    gen str40 modulo = "19f Daniele-Romito"
    gen str90 spec = cond(set == "A", "SC per zona: centroide entro 1 km, donatori oltre 2 km", ///
        "SC per zona: trattate principali, donatori oltre 2 km") + " (" + versione + ")"
    gen str16 outcome = "lnR"
    gen str40 metodo_stima = "controllo sintetico per zona, media"
    rename (att p_agg nt j) (coef p n_trattate n_controlli)
    gen double ci_lo = .
    gen double ci_hi = .
    gen str70 metodo_inferenza = "placebo aggregati (Cavallo et al. 2013)"
    gen str20 periodi = ""
    gen str160 post = "zone con p di rango <= 0,10: " + string(n_p10)
    gen double pre = .
    gen double p_pre = .
    keep modulo spec outcome metodo_stima coef ci_lo ci_hi p metodo_inferenza n_trattate n_controlli ///
        periodi post pre p_pre
    append using `all'
    save `all', replace
}

use `all', clear
gen double coef_pct  = 100*(exp(coef) - 1)  if inlist(outcome, "lnR", "lnP")
gen double ci_lo_pct = 100*(exp(ci_lo) - 1) if inlist(outcome, "lnR", "lnP")
gen double ci_hi_pct = 100*(exp(ci_hi) - 1) if inlist(outcome, "lnR", "lnP")
order modulo spec outcome metodo_stima coef ci_lo ci_hi coef_pct ci_lo_pct ci_hi_pct p metodo_inferenza ///
    n_trattate n_controlli periodi post pre p_pre
format coef ci_lo ci_hi pre %9.4f
format coef_pct ci_lo_pct ci_hi_pct %6.1f
format p p_pre %5.3f
sort modulo outcome spec metodo_stima
di as txt _n "  Stime principali (affitti, prezzi, uscite)"
list modulo spec outcome coef ci_lo ci_hi p n_trattate n_controlli if regexm(modulo, "^19 |^19e|^19f") & ///
    inlist(outcome, "lnR", "lnP", "r_ac"), noobs sep(0) abbrev(10)
export delimited using "$TAB/m4_estimates_all.csv", replace
quietly count
di as txt "  m4_estimates_all.csv: " r(N) " stime"

*------------------------------------------------------------------------------*
* 2. Date di trattamento e periodi dopo l'apertura effettivamente disponibili
*------------------------------------------------------------------------------*
capture confirm file "$WORK/m4_zone_panel.dta"
if _rc exit
use "$WORK/m4_zone_panel.dta", clear
quietly summarize t if !missing(lnR)
local zlast = r(max)
bysort zona: keep if _n == 1
local nz1 = 0
local nz2 = 0
local nz3 = 0
quietly count if abs(cohort - 2023) < 1e-6
local nz1 = r(N)
quietly count if abs(cohort - 2023.5) < 1e-6
local nz2 = r(N)
quietly count if abs(cohort - 2025) < 1e-6
local nz3 = r(N)
use "$WORK/m4_nil_panel.dta", clear
quietly summarize year if !missing(r_ac)
local nlast = r(max)
capture confirm variable nm_c2029
local nmlast = .
if !_rc {
    quietly summarize year if !missing(nm_c2029)
    local nmlast = r(max)
}
bysort nil: keep if _n == 1
quietly count if cohort == 2023
local nn1 = r(N)
quietly count if cohort == 2024
local nn2 = r(N)
quietly count if cohort == 2025
local nn3 = r(N)

clear
set obs 3
gen byte tratta = _n
gen str60 percorso = ""
replace percorso = "Linate - Dateo (Linate, Repetti, Forlanini, Argonne, Susa, Dateo)" in 1
replace percorso = "Dateo - San Babila (Tricolore, San Babila)" in 2
replace percorso = "San Babila - San Cristoforo (stazioni restanti)" in 3
gen str10 apertura = ""
replace apertura = "26/11/2022" in 1
replace apertura = "04/07/2023" in 2
replace apertura = "12/10/2024" in 3
* Regola: primo periodo trattato = primo semestre (anno, per i NIL) servito per
* tutto o quasi tutto il periodo. Quote servite calcolate dalle date di apertura.
gen int d_ap = cond(_n == 1, mdy(11, 26, 2022), cond(_n == 2, mdy(7, 4, 2023), mdy(10, 12, 2024)))
format d_ap %td
gen int y_ap = year(d_ap)
gen byte s_ap = 1 + (month(d_ap) >= 7)
gen int s_ini = cond(s_ap == 1, mdy(1, 1, y_ap), mdy(7, 1, y_ap))
gen int s_fin = cond(s_ap == 1, mdy(7, 1, y_ap), mdy(1, 1, y_ap + 1))
gen double quota_sem_apertura = (s_fin - d_ap)/(s_fin - s_ini)
gen double quota_anno_apertura = (mdy(1, 1, y_ap + 1) - d_ap)/(mdy(1, 1, y_ap + 1) - mdy(1, 1, y_ap))
gen str8 sem_apertura = string(y_ap) + "S" + string(s_ap)
* zone OMI: il semestre di apertura e' trattato se servito per almeno il 90%
gen double g_zone = cond(quota_sem_apertura >= 0.9, y_ap + (s_ap - 1)/2, y_ap + s_ap/2)
gen str8 primo_sem = string(floor(g_zone)) + "S" + string(1 + round(2*(g_zone - floor(g_zone))))
gen str8 sem_riferimento = string(floor(g_zone - 0.5)) + "S" + string(1 + round(2*(g_zone - 0.5 - floor(g_zone - 0.5))))
gen double quota_servita_riferimento = cond(sem_riferimento == sem_apertura, quota_sem_apertura, 0)
format quota_* %4.2f
assert abs(g_zone - cond(_n == 1, 2023, cond(_n == 2, 2023.5, 2025))) < 1e-6   // coerente con il modulo 19
gen int sem_dopo = round(2*(`zlast' - g_zone)) + 1
gen int zone_trattate = cond(_n == 1, `nz1', cond(_n == 2, `nz2', `nz3'))
* NIL: il primo anno trattato e' il primo anno solare interamente dopo l'apertura;
* l'anno di riferimento (g-1) e' l'anno di apertura, servito in parte
gen int g_nil = y_ap + 1
gen double quota_servita_anno_rif = quota_anno_apertura
format quota_servita_anno_rif %4.2f
assert g_nil == cond(_n == 1, 2023, cond(_n == 2, 2024, 2025))   // coerente con il modulo 19
gen int anni_dopo_uscite = max(0, `nlast' - g_nil + 1)
gen str40 anni_uscite = cond(anni_dopo_uscite > 0, string(g_nil) + cond(anni_dopo_uscite > 1, "-" + string(`nlast'), ""), "nessuno (fa da non ancora trattato)")
gen int anni_dopo_var_coorte = max(0, `nmlast' - g_nil + 1)
gen int nil_trattati = cond(_n == 1, `nn1', cond(_n == 2, `nn2', `nn3'))
local zl = string(floor(`zlast')) + "S" + string(1 + round(2*(`zlast' - floor(`zlast'))))
gen str80 nota = "ultimo semestre OMI `zl'; ultimo anno uscite `nlast'; ultimo anno variazione netta di coorte `nmlast'"
drop d_ap y_ap s_ap s_ini s_fin quota_anno_apertura
order tratta percorso apertura sem_apertura quota_sem_apertura primo_sem sem_riferimento ///
    quota_servita_riferimento sem_dopo zone_trattate g_nil quota_servita_anno_rif anni_dopo_uscite ///
    anni_uscite anni_dopo_var_coorte nil_trattati nota
list, noobs sep(0) abbrev(12)
export delimited using "$TAB/m4_treatment_timing.csv", replace
