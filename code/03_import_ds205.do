*==============================================================================*
* 03_import_ds205.do
* DS205 - caratteristiche demografiche dei quartieri, 2011-2024
* 1.232 righe NIL-anno + 11 righe N.D. (tenute a parte per le riconciliazioni)
* Emigrati = cancellazioni verso altri comuni italiani o l'estero.
*
* Output: $WORK/ds205_nil_year.dta   NIL x anno, tassi e quote
*         $WORK/ds205_nd_rows.dta    righe N.D.
*         $WORK/ds205_city_year.dta  totali cittadini (N.D. inclusi)
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "03 - IMPORT DS205 QUARTIERI" _n "{hline 78}"

imp_csv using "$RAW/$F_DS205"

getvar year,    pattern("anno( |$)")
getvar name,    pattern("quartiere")
getvar nil,     pattern("(^| )nil( |$)")
getvar males,   pattern("(^| )uomini( |$)") optional
getvar females, pattern("(^| )donne( |$)") optional
getvar pop,     pattern("(^| )totale( |$)")
getvar minors,  pattern("(^| )minori( |$)")
getvar foreign, pattern("(^| )stranieri( |$)")
getvar fam,     pattern("famiglie ?registrate ?in ?anagrafe") exclude("unipersonali|soli")
getvar fam1,    pattern("unipersonali")
getvar births,  pattern("nati ?vivi") optional
getvar deaths,  pattern("(^| )morti( |$)") optional
getvar emig,    pattern("(^| )emigrati( |$)")
getvar immig,   pattern("(^| )immigrati( |$)")
getvar pop65,   pattern("65 ?e ?\+|(^|[^0-9])65e")
getvar pop80,   pattern("80 ?e ?\+|(^|[^0-9])80e") exclude("soli|fam")
getvar area,    pattern("(^| )area") optional

local keepv
foreach v in year name nil males females pop minors foreign fam fam1 births deaths emig immig pop65 pop80 area {
    capture confirm variable `v'
    if !_rc local keepv `keepv' `v'
}
keep `keepv'
local nm name
local numv : list keepv - nm
tonum `numv'
replace name = ustrtrim(name)

* righe N.D.
gen byte nd = missing(nil) | upper(name) == "N.D."
preserve
collapse (sum) emig immig pop, by(year)
rename (emig immig pop) (emig_ds205 immig_ds205 pop_ds205)
label variable emig_ds205 "Emigrati, somma DS205 (N.D. inclusi)"
save "$WORK/ds205_city_year.dta", replace
restore
preserve
keep if nd
save "$WORK/ds205_nd_rows.dta", replace
restore
drop if nd
drop nd

isid nil year
quietly count
di as txt "  righe NIL-anno: " r(N) " (attese 1.232)"
tab year

*------------------------------------------------------------------------------*
* Tassi e quote
*------------------------------------------------------------------------------*
xtset nil year
gen double pop_lag    = L.pop
gen double pop_avg    = (L.pop + pop)/2
gen double r_emig     = 1000*emig/pop_lag  if pop_lag > 0 & !missing(pop_lag)
gen double r_emig_avg = 1000*emig/pop_avg  if pop_avg > 0 & !missing(pop_avg)
gen double r_immig    = 1000*immig/pop_lag if pop_lag > 0 & !missing(pop_lag)
gen double sh_minors  = minors/pop  if pop > 0 & !missing(pop)
gen double sh_a65     = pop65/pop   if pop > 0 & !missing(pop)
gen double sh_a80     = pop80/pop   if pop > 0 & !missing(pop)
gen double sh_foreign = foreign/pop if pop > 0 & !missing(pop)
gen double sh_fam1    = fam1/fam    if fam > 0 & !missing(fam)

label variable pop        "Residenti (Totale)"
label variable emig       "Emigrati (uscite verso altri comuni o estero)"
label variable pop_lag    "Residenti anno precedente"
label variable r_emig     "Uscite per 1.000 residenti dell'anno precedente"
label variable r_emig_avg "Uscite per 1.000 residenti medi (t-1, t)"
label variable r_immig    "Ingressi per 1.000 residenti dell'anno precedente"
label variable sh_minors  "Quota minori"
label variable sh_a65     "Quota 65 anni e oltre"
label variable sh_a80     "Quota 80 anni e oltre"
label variable sh_foreign "Quota residenti con cittadinanza straniera"
label variable sh_fam1    "Quota famiglie anagrafiche unipersonali"

* esempio del documento: Adriano, 625 emigrati 2024 / 18.150 residenti 2023
quietly summarize r_emig if year == 2024 & ustrregexm(ustrlower(name), "adriano"), meanonly
checkval, label("Uscite per 1.000, Adriano 2024") value(`r(mean)') expected(34.44) tol(0.01)

di as txt "  NIL con popolazione nulla (tassi indefiniti):"
list nil name year pop if pop == 0, noobs sepby(nil)
quietly count if year == 2019 & pop < $SMALL_NIL
di as txt "  NIL con meno di $SMALL_NIL residenti nel 2019: " r(N) " (attesi 8)"
list nil name pop if year == 2019 & pop < $SMALL_NIL, noobs

capture confirm variable area
if !_rc {
    bysort nil (year): gen double area_chg = area/area[_n-1] - 1 if _n > 1
    di as txt "  Cambi del campo area oltre l'1% (non usare per densita' senza verifica, es. NIL 5, 16, 71):"
    list nil name year area area_chg if abs(area_chg) > 0.01 & !missing(area_chg), noobs
    drop area_chg
}

sort nil year
save "$WORK/ds205_nil_year.dta", replace
