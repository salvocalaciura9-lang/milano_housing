*==============================================================================*
* 04_import_ds1960.do
* DS1960 - cancellazioni anagrafiche per luogo di destinazione, 2020-2024
* Livello cittadino: NON fornisce la matrice NIL di origine x destinazione,
* quindi le quote non vanno attribuite ai singoli NIL.
*
* Output: $WORK/ds1960_dest_year.dta
*         $TAB/ds1960_destinations_grouped.csv
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "04 - IMPORT DS1960 DESTINAZIONI" _n "{hline 78}"

imp_csv using "$RAW/$F_DS1960"
getvar year, pattern("anno")
getvar dest, pattern("luogo|dest")
getvar flow, pattern("numer")
keep year dest flow
tonum year flow
replace dest = ustrtrim(dest)

gen byte dest_nd = inlist(ustrlower(dest), "n.d.", "n.d", "nd")
gen str24 dest_grp = ""
replace dest_grp = "Provincia di Milano"   if ustrlower(dest) == "prov. mi"
replace dest_grp = "Altre prov. Lombardia" if ustrregexm(ustrlower(dest), "altre prov")
replace dest_grp = "Estero"                if ustrlower(dest) == "estero"
replace dest_grp = "N.D."                  if dest_nd == 1
replace dest_grp = "Altre regioni"         if dest_grp == ""
bysort year: egen double tot_year = total(flow)
gen double share = 100*flow/tot_year
label variable flow  "Cancellazioni (numerosita')"
label variable share "% delle cancellazioni dell'anno"
save "$WORK/ds1960_dest_year.dta", replace

preserve
collapse (sum) flow, by(year dest_grp)
bysort year: egen double tot_year = total(flow)
gen double share = 100*flow/tot_year
list year dest_grp flow share, sepby(year) noobs
export delimited using "$TAB/ds1960_destinations_grouped.csv", replace
quietly summarize share if year == 2020 & dest_grp == "N.D.", meanonly
checkval, label("Quota destinazione N.D. 2020 (%)") value(`r(mean)') expected(15.61) tol(0.01)
quietly summarize share if year == 2024 & dest_grp == "N.D.", meanonly
checkval, label("Quota destinazione N.D. 2024 (%)") value(`r(mean)') expected(7.12) tol(0.01)
restore

* riconciliazione con gli Emigrati del DS205
preserve
collapse (sum) flow, by(year)
rename flow emig_ds1960
merge 1:1 year using "$WORK/ds205_city_year.dta", keep(master match) nogen keepusing(emig_ds205)
gen double diff = emig_ds1960 - emig_ds205
list year emig_ds1960 emig_ds205 diff, noobs
foreach pr in "2020 41153" "2021 43816" "2022 42705" "2023 44588" "2024 44468" {
    tokenize `pr'
    quietly summarize emig_ds1960 if year == `1', meanonly
    checkval, label("Cancellazioni DS1960 `1'") value(`r(mean)') expected(`2') tol(0.5)
    quietly summarize emig_ds205 if year == `1', meanonly
    checkval, label("Emigrati DS205 `1'") value(`r(mean)') expected(`2') tol(0.5)
}
restore
