*==============================================================================*
* 06_affordability_native.do
* (a) CPI per il benchmark reddituale iniziale reale
* (b) Redditi fiscali alla risoluzione CAP: livelli, variazioni, numero vs
*     quota dei contribuenti nelle fasce basse
* (c) Quotazioni OMI alla risoluzione di zona: livelli e variazioni
* (d) Contesto cittadino: rapporti costo/reddito con mediana delle zone e media
*     fiscale cittadina. NON e' una misura locale: serve solo come contesto
*     finche' il raccordo geografico non e' disponibile.
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "06 - AFFORDABILITY ALLE GEOGRAFIE NATIVE" _n "{hline 78}"

*------------------------------------------------------------------------------*
* (a) CPI
*------------------------------------------------------------------------------*
global CPI_OK 0
capture confirm file "$AUX/$F_CPI"
if !_rc {
    imp_csv using "$AUX/$F_CPI"
    getvar year, pattern("(^| )(anno|year)( |$)")
    getvar cpi,  pattern("(^| )cpi( |$)")
    keep year cpi
    tonum year cpi
    drop if missing(year)
    isid year
    sort year
    list, noobs
    local okcpi 1
    forvalues y = $Y0A/$Y1 {
        quietly count if year == `y' & !missing(cpi)
        if r(N) == 0 {
            di as error "  CPI mancante per il `y'"
            local okcpi 0
        }
    }
    save "$WORK/cpi.dta", replace
    global CPI_OK `okcpi'
}
else {
    di as error "  $AUX/$F_CPI assente: benchmark iniziale reale non calcolato"
}

*------------------------------------------------------------------------------*
* (b) Redditi per CAP
*------------------------------------------------------------------------------*
use "$WORK/irpef_cap_year.dta", clear
tabstat ybar_imp ybar_lav sh_low15 sh_low26, by(year) stats(n mean p50 min max) format(%10.3f)

foreach v in ybar_imp ybar_lav ncontrib nlow15 sh_low15 nlow26 sh_low26 {
    bysort cap: egen double `v'_0 = max(cond(year == $Y0A, `v', .))
    bysort cap: egen double `v'_1 = max(cond(year == $Y1,  `v', .))
}
gen double dln_ybar_imp = ln(ybar_imp_1) - ln(ybar_imp_0)
gen double dln_ybar_lav = ln(ybar_lav_1) - ln(ybar_lav_0)
gen double d_nlow15  = nlow15_1 - nlow15_0
gen double d_shlow15 = 100*(sh_low15_1 - sh_low15_0)
gen double d_nlow26  = nlow26_1 - nlow26_0
gen double d_shlow26 = 100*(sh_low26_1 - sh_low26_0)
gen str32 low15_pattern = cond(d_nlow15 < 0 & d_shlow15 < 0, "numero e quota in calo", ///
    cond(d_nlow15 >= 0 & d_shlow15 < 0, "solo la quota in calo", ///
    cond(d_nlow15 < 0 & d_shlow15 >= 0, "solo il numero in calo", "nessun calo"))) ///
    if !missing(d_nlow15, d_shlow15)
label variable dln_ybar_imp "Variazione log reddito imponibile medio $Y0A-$Y1 (nominale)"
label variable d_shlow15    "Variazione quota 0-15.000 (punti percentuali)"

if $CPI_OK {
    preserve
    use "$WORK/cpi.dta", clear
    quietly summarize cpi if year == $Y0A, meanonly
    scalar cpi_0 = r(mean)
    quietly summarize cpi if year == $Y1, meanonly
    scalar cpi_1 = r(mean)
    restore
    gen double dln_ybar_imp_real = dln_ybar_imp - ln(cpi_1/cpi_0)
    label variable dln_ybar_imp_real "Variazione log reddito imponibile medio $Y0A-$Y1 (reale)"
}

egen byte tagc = tag(cap)
di as txt _n "  Contribuenti fino a 15.000 EUR, $Y0A-$Y1: numero e quota per CAP"
tab low15_pattern if tagc
summarize dln_ybar_imp* d_nlow15 d_shlow15 if tagc

preserve
keep if tagc
keep cap ybar_imp_0 ybar_imp_1 dln_ybar_imp* ybar_lav_0 ybar_lav_1 dln_ybar_lav ///
    ncontrib_0 ncontrib_1 nlow15_0 nlow15_1 sh_low15_0 sh_low15_1 d_nlow15 d_shlow15 ///
    nlow26_0 nlow26_1 sh_low26_0 sh_low26_1 d_nlow26 d_shlow26 low15_pattern
export delimited using "$TAB/cap_fiscal_change_${Y0A}_${Y1}.csv", replace
save "$WORK/cap_fiscal_change.dta", replace
restore

*------------------------------------------------------------------------------*
* (c) Quotazioni per zona OMI
*------------------------------------------------------------------------------*
use "$WORK/omi_zone_year.dta", clear
keep if inrange(anno, $Y0, $Y1)
tabstat R_mid P_mid, by(anno) stats(n p25 p50 p75) format(%9.2f)
foreach v in R_mid R_min R_max P_mid P_min P_max {
    bysort zona: egen double `v'_0 = max(cond(anno == $Y0, `v', .))
    bysort zona: egen double `v'_1 = max(cond(anno == $Y1, `v', .))
}
gen double dlnR     = ln(R_mid_1) - ln(R_mid_0)
gen double dlnR_min = ln(R_min_1) - ln(R_min_0)
gen double dlnR_max = ln(R_max_1) - ln(R_max_0)
gen double dlnP     = ln(P_mid_1) - ln(P_mid_0)
gen double dlnP_min = ln(P_min_1) - ln(P_min_0)
gen double dlnP_max = ln(P_max_1) - ln(P_max_0)
label variable dlnR "Variazione log locazione (punto medio) $Y0-$Y1"
label variable dlnP "Variazione log compravendita (punto medio) $Y0-$Y1"
egen byte tagz = tag(zona)
summarize dlnR dlnR_min dlnR_max dlnP dlnP_min dlnP_max if tagz
preserve
keep if tagz
keep zona R_mid_0 R_mid_1 P_mid_0 P_mid_1 dlnR dlnR_min dlnR_max dlnP dlnP_min dlnP_max
merge 1:1 zona using "$WORK/omi_zone_dict.dta", keep(master match) nogen
sort zona
export delimited using "$TAB/omi_zone_change_${Y0}_${Y1}.csv", replace
save "$WORK/omi_zone_change.dta", replace
restore

* serie dei primi semestri 2019-2024 (estensione coerente)
use "$WORK/omi_zone_s1.dta", clear
keep if inrange(anno, $Y0, 2024)
di as txt "  Primi semestri $Y0-2024 (stessa definizione in tutti gli anni):"
tabstat R_mid P_mid, by(anno) stats(n p25 p50 p75) format(%9.2f)

*------------------------------------------------------------------------------*
* (d) Contesto cittadino (non e' affordability locale)
*------------------------------------------------------------------------------*
use "$WORK/omi_zone_year.dta", clear
keep if inrange(anno, $Y0, $Y1)
bysort zona: egen nyR = count(R_mid)
bysort zona: egen nyP = count(P_mid)
keep if nyR == $Y1 - $Y0 + 1 & nyP == $Y1 - $Y0 + 1
collapse (median) R_med=R_mid P_med=P_mid (count) nzone=R_mid, by(anno)
rename anno year
merge 1:1 year using "$WORK/irpef_city_year.dta", keep(match) nogen keepusing(ybar_city)
gen double AR_city = 12*$S_MAIN*R_med/ybar_city
gen double AP_city = $S_MAIN*P_med/ybar_city
label variable AR_city "Affitto annuo di $S_MAIN m2 / media fiscale cittadina (contesto)"
label variable AP_city "Prezzo di $S_MAIN m2 / media fiscale cittadina, in anni (contesto)"
if $CPI_OK {
    merge 1:1 year using "$WORK/cpi.dta", keep(master match) nogen
    egen double yb0  = max(cond(year == $Y0A, ybar_city, .))
    egen double cpib = max(cond(year == $Y0A, cpi, .))
    gen double AR_city_base = 12*$S_MAIN*R_med/(yb0*cpi/cpib)
    gen double AP_city_base = $S_MAIN*P_med/(yb0*cpi/cpib)
    label variable AR_city_base "Come AR_city, con reddito iniziale $Y0A rivalutato col CPI"
    label variable AP_city_base "Come AP_city, con reddito iniziale $Y0A rivalutato col CPI"
    drop yb0 cpib
}
di as txt "  Contesto cittadino (mediana non ponderata di zone a serie completa; media fiscale cittadina):"
list, noobs abbreviate(14)
save "$WORK/city_context.dta", replace
export delimited using "$TAB/city_context.csv", replace
