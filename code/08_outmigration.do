*==============================================================================*
* 08_outmigration.do
* Tassi di uscita anagrafica da Milano per NIL e indicatori di composizione.
*   r_post = 1000 * (E2022 + E2023 + E2024) / (N2021 + N2022 + N2023)
*   r_pre  = 1000 * (E2017 + E2018 + E2019) / (N2016 + N2017 + N2018)
* Intensita' annua di uscite per 1.000 residenti, non probabilita' di espulsione.
* Converte anche lo shapefile dei NIL, se presente (usato da 09 e 14).
*
* Output: $WORK/outmig_nil.dta     una riga per NIL
*         $WORK/outmig_city.dta    tasso cittadino per anno
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "08 - USCITE ANAGRAFICHE E COMPOSIZIONE" _n "{hline 78}"

use "$WORK/ds205_nil_year.dta", clear

* tasso cittadino annuo (somma dei NIL con denominatore valido)
preserve
keep if pop_lag > 0 & !missing(pop_lag)
collapse (sum) emig immig pop_lag, by(year)
gen double r_emig_city  = 1000*emig/pop_lag
gen double r_immig_city = 1000*immig/pop_lag
label variable r_emig_city  "Uscite per 1.000 residenti, Milano"
label variable r_immig_city "Ingressi per 1.000 residenti, Milano"
list year emig pop_lag r_emig_city r_immig_city, noobs
save "$WORK/outmig_city.dta", replace
export delimited using "$TAB/outmig_city_year.csv", replace
restore

* somme pre e post
gen double E_pre_i     = emig    if inrange(year, 2017, 2019)
gen double N_pre_i     = pop     if inrange(year, 2016, 2018)
gen double E_post_i    = emig    if inrange(year, 2022, 2024)
gen double N_post_i    = pop     if inrange(year, 2021, 2023)
gen double Navg_post_i = pop_avg if inrange(year, 2022, 2024)
gen double Navg_pre_i  = pop_avg if inrange(year, 2017, 2019)
preserve
collapse (sum) E_pre=E_pre_i N_pre=N_pre_i E_post=E_post_i N_post=N_post_i ///
    Navg_post=Navg_post_i Navg_pre=Navg_pre_i ///
    (count) cE_pre=E_pre_i cN_pre=N_pre_i cE_post=E_post_i cN_post=N_post_i ///
    cNa_post=Navg_post_i cNa_pre=Navg_pre_i, by(nil)
gen double r_pre      = 1000*E_pre/N_pre      if cE_pre == 3  & cN_pre == 3   & N_pre > 0
gen double r_post     = 1000*E_post/N_post    if cE_post == 3 & cN_post == 3  & N_post > 0
gen double r_pre_avg  = 1000*E_pre/Navg_pre   if cE_pre == 3  & cNa_pre == 3  & Navg_pre > 0
gen double r_post_avg = 1000*E_post/Navg_post if cE_post == 3 & cNa_post == 3 & Navg_post > 0
gen double r_change   = r_post - r_pre
label variable r_pre      "Uscite per 1.000, 2017-19 (denominatori 2016-18)"
label variable r_post     "Uscite per 1.000, 2022-24 (denominatori 2021-23)"
label variable r_pre_avg  "Uscite per 1.000, 2017-19 (popolazione media)"
label variable r_post_avg "Uscite per 1.000, 2022-24 (popolazione media)"
label variable r_change   "r_post - r_pre"
label variable E_post     "Emigrati 2022-24"
label variable N_post     "Residenti 2021-23 (somma)"
drop cE_* cN_* cNa_*
tempfile prepost
save `prepost'
restore

* condizioni iniziali e composizione
bysort nil (year): gen name_last = name[_N]
keep nil name_last year pop sh_minors sh_a65 sh_a80 sh_foreign sh_fam1
keep if inlist(year, 2011, 2019, 2021, 2023, 2024)
reshape wide pop sh_minors sh_a65 sh_a80 sh_foreign sh_fam1, i(nil) j(year)
gen double lnpop2019  = ln(pop2019) if pop2019 > 0 & !missing(pop2019)
gen double pct65_2019 = 100*sh_a652019
gen byte   small2019  = (pop2019 < $SMALL_NIL) if !missing(pop2019)
label variable lnpop2019  "Log residenti 2019"
label variable pct65_2019 "% residenti 65+ nel 2019"
label variable small2019  "NIL con meno di $SMALL_NIL residenti nel 2019"
foreach s in minors a65 a80 foreign fam1 {
    gen double d_`s'_1923 = 100*(sh_`s'2023 - sh_`s'2019)
    gen double d_`s'_1121 = 100*(sh_`s'2021 - sh_`s'2011)
    label variable d_`s'_1923 "Variazione quota `s' 2019-23 (punti)"
    label variable d_`s'_1121 "Variazione quota `s' 2011-21 (punti)"
}
merge 1:1 nil using `prepost', nogen

quietly count if missing(r_post)
di as txt "  NIL senza tasso post valido (denominatore nullo, atteso Parco Sempione): " r(N)
list nil name_last N_post if missing(r_post), noobs
summarize r_pre r_post r_change
correlate r_pre r_post

di as txt "  Triangolazione descrittiva: variazione delle uscite e della composizione 2019-23"
pwcorr r_change d_minors_1923 d_a65_1923 d_foreign_1923 d_fam1_1923, obs

sort nil
save "$WORK/outmig_nil.dta", replace
export delimited using "$TAB/outmig_nil.csv", replace

*------------------------------------------------------------------------------*
* Shapefile dei NIL (facoltativo, coordinate WGS84)
*------------------------------------------------------------------------------*
global SHP_OK 0
capture confirm file "$GEO/$SHP_NIL.shp"
if !_rc {
    local here "`c(pwd)'"
    quietly cd "$GEO"
    capture noisily spshape2dta $SHP_NIL, replace saving(nil_shape)
    local rc = _rc
    quietly cd "`here'"
    if `rc' == 0 {
        use "$GEO/nil_shape.dta", clear
        local lc = lower("$SHP_NIL_ID")
        capture noisily getvar nil_shp, pattern("^`lc'( |$)")
        if _rc == 0 {
            tonum nil_shp
            capture drop nil
            rename nil_shp nil
            duplicates report nil
            save "$GEO/nil_shape.dta", replace
            global SHP_OK 1
            di as txt "  Shapefile NIL convertito: $GEO/nil_shape.dta"
        }
    }
}
else {
    di as txt "  Shapefile NIL assente ($GEO/$SHP_NIL.shp): niente mappe ne' test spaziali"
}
