*==============================================================================*
* 11_integrated_cap.do
* Pannello integrato alla risoluzione CAP (i redditi restano ai 38 CAP nativi;
* quotazioni, popolazione e uscite vengono portate al CAP con i pesi).
*
* Affordability (s = superficie convenzionale, m2 lordi):
*   A^R_jt = 12 s R_jt / Ybar_jt          affitto annuo / reddito imponibile medio
*   A^P_jt = s P_jt / Ybar_jt             anni di reddito per il prezzo
*   A^R,base_jt = 12 s R_jt / (Ybar_j,Y0 * CPI_t/CPI_Y0)   benchmark iniziale reale
* Varianti: min/max OMI, reddito da lavoro, 40/60/80 m2, due percettori
* (superficie e percettori cambiano i livelli, non le variazioni log).
* Copertura: per ogni CAP la quota di peso in zone quotate; regola fissata
* prima: CAP inclusi se copertura >= COVER_MIN in tutti gli anni.
*
* Modello 2 (sezione trasversale, 38 CAP al massimo):
*   dlog A_j = a + b G_social_j + g' Z_j0 + u_j     errori HC3
*
* Output: $WORK/cap_panel_<v>.dta, $WORK/cap_cross_<v>.dta
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "11 - PANNELLO CAP INTEGRATO E MODELLO DELLE VARIAZIONI" _n "{hline 78}"

if $XW_OK == 0 {
    di as error "  11 saltato: raccordo geografico non disponibile (vedi modulo 10)"
    exit
}

*------------------------------------------------------------------------------*
* Programma: quotazioni di zona -> CAP con pesi e copertura
*------------------------------------------------------------------------------*
capture program drop omi2cap
program define omi2cap
    args xwfile omifile y0 y1
    use "`xwfile'", clear
    keep zona cap w
    local ny = `y1' - `y0' + 1
    expand `ny'
    bysort zona cap: gen int anno = `y0' - 1 + _n
    merge m:1 zona anno using "`omifile'", keep(master match) ///
        keepusing(R_mid R_min R_max P_mid P_min P_max) nogen
    foreach v in R_mid R_min R_max P_mid P_min P_max {
        gen double num_`v' = w*`v'
        gen double den_`v' = w if !missing(`v')
    }
    gen double wsum = w
    collapse (sum) num_* den_* wsum, by(cap anno)
    foreach v in R_mid R_min R_max P_mid P_min P_max {
        gen double `v' = num_`v'/den_`v' if den_`v' > 0
    }
    gen double cov_R = den_R_mid/wsum
    gen double cov_P = den_P_mid/wsum
    drop num_* den_* wsum
    rename anno year
    label variable cov_R "Quota del CAP in zone con locazione quotata"
    label variable cov_P "Quota del CAP in zone con compravendita quotata"
end

* popolazione 2011 dei NIL (pesi per portare l'upgrading al CAP)
use "$WORK/ds205_nil_year.dta", clear
keep if year == 2011
keep nil pop
rename pop pop2011
tempfile pop11
save `pop11'

local S = $S_MAIN

foreach xv of global XW_VERSIONS {
    di as txt _n "  {ul:Raccordo: `xv'}"

    *--- (a) quotazioni al CAP ---------------------------------------------*
    omi2cap "$WORK/xw_omi_cap_`xv'.dta" "$WORK/omi_zone_year.dta" $Y0 $Y1
    tempfile omicap
    save `omicap'

    *--- (b) redditi, CPI e affordability -----------------------------------*
    use "$WORK/irpef_cap_year.dta", clear
    keep cap anno year ncontrib imp_f imp_a ybar_imp lav_f lav_a ybar_lav nlow15 sh_low15 nlow26 sh_low26
    merge 1:1 cap year using `omicap'
    di as txt "  CAP-anno: solo IRPEF (_merge = 1), solo quotazioni (_merge = 2):"
    tab year _merge
    keep if _merge == 3
    drop _merge
    capture confirm file "$WORK/cpi.dta"
    if !_rc {
        merge m:1 year using "$WORK/cpi.dta", keep(master match) nogen
    }
    else {
        gen double cpi = .
    }

    gen double AR     = 12*`S'*R_mid/ybar_imp
    gen double AR_min = 12*`S'*R_min/ybar_imp
    gen double AR_max = 12*`S'*R_max/ybar_imp
    gen double AR_lav = 12*`S'*R_mid/ybar_lav
    gen double AR_2p  = 12*`S'*R_mid/(2*ybar_imp)
    gen double AP     = `S'*P_mid/ybar_imp
    gen double AP_min = `S'*P_min/ybar_imp
    gen double AP_max = `S'*P_max/ybar_imp
    gen double AP_lav = `S'*P_mid/ybar_lav
    foreach s of global S_LIST {
        gen double AR_s`s' = 12*`s'*R_mid/ybar_imp
        gen double AP_s`s' = `s'*P_mid/ybar_imp
    }
    bysort cap: egen double y_base = max(cond(year == $Y0A, ybar_imp, .))
    egen double cpi_base = max(cond(year == $Y0A, cpi, .))
    gen double ybench  = y_base*cpi/cpi_base
    gen double AR_base = 12*`S'*R_mid/ybench
    gen double AP_base = `S'*P_mid/ybench
    gen double gap_lnAR = ln(AR_base) - ln(AR)
    label variable AR       "Affitto annuo di `S' m2 / reddito imponibile medio"
    label variable AP       "Prezzo di `S' m2 / reddito imponibile medio (anni)"
    label variable AR_base  "Come AR con reddito $Y0A del CAP rivalutato col CPI"
    label variable AP_base  "Come AP con reddito $Y0A del CAP rivalutato col CPI"
    label variable AR_lav   "Come AR con reddito da lavoro dipendente medio"
    label variable AR_2p    "Come AR con due percettori"
    label variable gap_lnAR "log A base - log A corrente"

    foreach a in AR AR_min AR_max AR_lav AR_base AP AP_min AP_max AP_lav AP_base {
        gen double ln`a' = ln(`a')
        bysort cap: egen double t0 = max(cond(year == $Y0A, ln`a', .))
        bysort cap: egen double t1 = max(cond(year == $Y1,  ln`a', .))
        gen double dln`a' = t1 - t0
        drop t0 t1
    }

    bysort cap: egen double covR_min = min(cov_R)
    bysort cap: egen double covP_min = min(cov_P)
    gen byte cover_ok = (covR_min >= $COVER_MIN & !missing(covR_min))
    egen byte tagc = tag(cap)
    di as txt "  Copertura minima delle zone quotate per CAP (regola: >= $COVER_MIN):"
    tabstat covR_min covP_min if tagc, stats(n min p25 p50 max)
    list cap covR_min covP_min if tagc & cover_ok == 0, noobs
    quietly count if tagc & cover_ok == 1
    di as txt "  CAP che rispettano la regola di copertura: " r(N)
    drop tagc

    tabstat AR AR_base AP AP_base, by(year) stats(n p25 p50 p75) format(%9.3f)
    tempfile aff
    save `aff'

    *--- (c) residenti e uscite allocati al CAP ------------------------------*
    use "$WORK/ds205_nil_year.dta", clear
    local mv ""
    capture confirm variable canc_ac
    if !_rc local mv "canc_ac canc_es canc_alt canc_ac_it canc_ac_st"
    keep nil year pop emig immig pop65 minors foreign fam fam1 `mv'
    joinby nil using "$WORK/xw_nil_cap_`xv'.dta"
    foreach v in pop emig immig pop65 minors foreign fam fam1 `mv' {
        quietly replace `v' = `v'*w
    }
    collapse (sum) pop emig immig pop65 minors foreign fam fam1 `mv', by(cap year)
    foreach v in pop emig immig pop65 minors foreign fam fam1 `mv' {
        rename `v' `v'_al
        label variable `v'_al "`v' allocato al CAP (stima con pesi `xv')"
    }
    xtset cap year
    gen double r_emig  = 1000*emig_al/L.pop_al  if L.pop_al > 0 & !missing(L.pop_al)
    gen double r_immig = 1000*immig_al/L.pop_al if L.pop_al > 0 & !missing(L.pop_al)
    gen double sh_a65  = pop65_al/pop_al
    gen double sh_foreign = foreign_al/pop_al
    gen double sh_fam1 = fam1_al/fam_al
    label variable r_emig "Uscite per 1.000 residenti (allocate)"
    if "`mv'" != "" {
        gen double r_ac  = 1000*canc_ac_al/L.pop_al if L.pop_al > 0 & !missing(L.pop_al)
        gen double r_mov = 1000*(canc_ac_al + canc_es_al)/L.pop_al if L.pop_al > 0 & !missing(L.pop_al)
        label variable r_ac  "Trasferimenti verso altri comuni italiani per 1.000 (allocati)"
        label variable r_mov "Trasferimenti verso altri comuni o l'estero per 1.000 (allocati)"
    }

    *--- (d) pannello CAP x anno 2011-2024 con affordability 2019-2023 -------*
    merge 1:1 cap year using `aff', keep(master match)
    di as txt "  CAP-anno con affordability: " _N " righe totali; abbinate:"
    tab _merge
    drop _merge

    bysort cap: egen double pop2019c    = max(cond(year == 2019, pop_al, .))
    bysort cap: egen double pct65_2019c = max(cond(year == 2019, 100*sh_a65, .))
    gen double lnpop2019c = ln(pop2019c)
    bysort cap: egen double shlow_base  = max(cond(year == $Y0A, sh_low15, .))
    bysort cap: egen byte   cover_okc   = max(cover_ok)
    replace cover_ok = cover_okc
    drop cover_okc
    egen byte tagc = tag(cap)
    quietly summarize shlow_base if tagc, detail
    gen byte vuln = (shlow_base > r(p50)) if !missing(shlow_base)
    drop tagc
    label variable vuln "Quota 0-15.000 EUR nel $Y0A sopra la mediana dei CAP (definita prima)"

    *--- (e) upgrading sociale portato al CAP ---------------------------------*
    if $IX_OK == 1 {
        preserve
        local gfile "$WORK/gentrif_nilnew.dta"
        if "$NILNEW_OK" != "1" local gfile "$WORK/gentrif_nil.dta"
        use "`gfile'", clear
        keep nil G_social dI_common dI_paper
        merge 1:1 nil using `pop11', keep(master match) nogen
        joinby nil using "$WORK/xw_nil_cap_`xv'.dta"
        gen double a = w*pop2011
        foreach g in G_social dI_common dI_paper {
            gen double ag_`g' = a*`g'
            gen double ao_`g' = a if !missing(`g')
        }
        collapse (sum) ag_* ao_* a, by(cap)
        foreach g in G_social dI_common dI_paper {
            gen double `g'_cap = ag_`g'/ao_`g' if ao_`g' > 0
            gen double cov_`g' = ao_`g'/a
        }
        keep cap *_cap cov_*
        label variable G_social_cap  "Upgrading sociale medio del CAP (pesi: residenti 2011 x quota NIL)"
        label variable dI_common_cap "Variazione indice comune media del CAP"
        tempfile gcap
        save `gcap'
        restore
        merge m:1 cap using `gcap', keep(master match) nogen
    }

    sort cap year
    save "$WORK/cap_panel_`xv'.dta", replace

    *--- (f) sezione trasversale delle variazioni ----------------------------*
    preserve
    keep if year == $Y1
    local kc cap dln* lnpop2019c pct65_2019c shlow_base vuln cover_ok covR_min covP_min ///
        AR AR_base AP AP_base cov_R cov_P
    capture confirm variable G_social_cap
    if !_rc local kc `kc' G_social_cap dI_common_cap dI_paper_cap cov_G_social cov_dI_common cov_dI_paper
    keep `kc'
    save "$WORK/cap_cross_`xv'.dta", replace
    if "`xv'" == "main" export delimited using "$TAB/cap_affordability_change.csv", replace
    restore

    *--- (g) modello 2 ------------------------------------------------------*
    if $IX_OK == 1 {
        preserve
        use "$WORK/cap_cross_`xv'.dta", clear
        local M2 "M2 CAP: variazione log affordability affitto $Y0A-$Y1"
        local Zc "lnpop2019c pct65_2019c"
        di as txt "  Nota: indice completo e rapporto costo/reddito condividono prezzi e redditi;"
        di as txt "  la loro correlazione e' in parte costruita dalle formule."
        pwcorr dlnAR dlnAP G_social_cap dI_common_cap if cover_ok == 1, obs

        * ogni stima viene salvata solo se riesce (es. dlnAR_base richiede il CPI)
        capture noisily regress dlnAR G_social_cap if cover_ok == 1, vce(hc3)
        if _rc == 0 saveres, model("`M2'") spec("bivariata [`xv']") coef(G_social_cap)
        capture noisily regress dlnAR G_social_cap `Zc' if cover_ok == 1, vce(hc3)
        if _rc == 0 saveres, model("`M2'") spec("principale [`xv']") coef(G_social_cap)

        if "`xv'" == "main" {
            foreach y in dlnAP dlnAR_lav dlnAR_base dlnAR_min dlnAR_max {
                capture noisily regress `y' G_social_cap `Zc' if cover_ok == 1, vce(hc3)
                if _rc == 0 saveres, model("M2 CAP: `y'") spec("principale") coef(G_social_cap)
            }
            capture noisily regress dlnAR G_social_cap `Zc', vce(hc3)
            if _rc == 0 saveres, model("`M2'") spec("tutti i CAP (senza regola di copertura)") coef(G_social_cap)
            capture noisily regress dlnAR dI_common_cap `Zc' if cover_ok == 1, vce(hc3)
            if _rc == 0 saveres, model("`M2'") spec("indice completo a scala comune") ///
                coef(dI_common_cap) note("in parte meccanica: l'indice contiene prezzi e redditi")
        }
        restore
    }
}

*------------------------------------------------------------------------------*
* Estensione descrittiva al 2024: soli primi semestri, stessa definizione
*------------------------------------------------------------------------------*
local xv : word 1 of $XW_VERSIONS
omi2cap "$WORK/xw_omi_cap_`xv'.dta" "$WORK/omi_zone_s1.dta" $Y0 2024
tempfile s1cap
save `s1cap'
use "$WORK/irpef_cap_year.dta", clear
keep cap year ybar_imp
merge 1:1 cap year using `s1cap', keep(match) nogen
gen double AR_s1 = 12*`S'*R_mid/ybar_imp
gen double AP_s1 = `S'*P_mid/ybar_imp
bysort cap: egen double covR_min = min(cov_R)
di as txt "  Affordability con i soli primi semestri, $Y0A-2024 (CAP con copertura >= $COVER_MIN):"
tabstat AR_s1 AP_s1 if covR_min >= $COVER_MIN, by(year) stats(n p25 p50 p75) format(%9.3f)
save "$WORK/cap_s1_extension.dta", replace
