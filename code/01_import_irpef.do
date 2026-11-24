*==============================================================================*
* 01_import_irpef.do
* Redditi e principali variabili IRPEF su base sub-comunale, anni d'imposta
* 2019-2024, 38 CAP. Ogni file e' in formato lungo: anno - CAP - voce - importo.
* Le intestazioni cambiano tra anni (Importi/Valori, IRPEF/Irpef, apostrofi
* doppi nel 2024, spazi finali), quindi le voci vengono normalizzate.
*
* Output: $WORK/irpef_long_all.dta  tutte le voci (chiave anno-CAP-voce)
*         $WORK/irpef_cap_year.dta  CAP x anno con le variabili usate
*         $WORK/irpef_city_year.dta totali cittadini per anno
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "01 - IMPORT IRPEF PER CAP" _n "{hline 78}"

tempfile acc
local first 1

forvalues y = 2019/2024 {
    local f "$RAW/${F_IRPEF_STUB}`y'.csv"
    capture confirm file "`f'"
    if _rc local f "$RAW/${F_IRPEF_STUB}`y' (1).csv"
    capture confirm file "`f'"
    if _rc {
        di as error "File IRPEF per l'anno `y' non trovato in $RAW"
        exit 601
    }
    imp_csv using "`f'"

    * colonne per contenuto dell'intestazione, con le posizioni come riserva
    local vy ""
    local vc ""
    local vd ""
    local vv ""
    capture findvar, pattern("anno")
    if !_rc local vy `r(varname)'
    capture findvar, pattern("(^| )cap( |$)")
    if !_rc local vc `r(varname)'
    capture findvar, pattern("variabil")
    if !_rc local vd `r(varname)'
    capture findvar, pattern("import|valor")
    if !_rc local vv `r(varname)'
    if "`vy'" == "" | "`vc'" == "" | "`vd'" == "" | "`vv'" == "" {
        di as txt "  intestazioni non riconosciute: uso le prime quattro colonne"
        unab allv : _all
        tokenize `allv'
        local vy `1'
        local vc `2'
        local vd `3'
        local vv `4'
    }
    keep `vy' `vc' `vd' `vv'
    local i 0
    foreach new in anno cap descr valore {
        local ++i
        local old : word `i' of `vy' `vc' `vd' `vv'
        if "`old'" != "`new'" rename `old' `new'
    }
    tonum anno cap valore
    quietly count if anno != `y'
    if r(N) > 0 di as error "  Attenzione: " r(N) " righe con anno diverso da `y'"

    * normalizzazione della voce: minuscole, spazi singoli, senza apostrofi
    gen d = ustrlower(stritrim(ustrtrim(descr)))
    quietly replace d = subinstr(d, "'", "", .)

    gen str12 code = ""
    quietly {
        replace code = "ncontrib"  if d == "numero contribuenti"
        replace code = "imp_f"     if ustrregexm(d, "^reddito imponibile ?- ?frequenza$")
        replace code = "imp_a"     if ustrregexm(d, "^reddito imponibile ?- ?ammontare")
        replace code = "lav_f"     if ustrregexm(d, "^reddito da lavoro dipendente e assimilati ?- ?frequenza")
        replace code = "lav_a"     if ustrregexm(d, "^reddito da lavoro dipendente e assimilati ?- ?ammontare")
        replace code = "pen_f"     if ustrregexm(d, "^reddito da pensione ?- ?frequenza")
        replace code = "pen_a"     if ustrregexm(d, "^reddito da pensione ?- ?ammontare")
        replace code = "tot_f"     if ustrregexm(d, "^reddito complessivo ?- ?frequenza")
        replace code = "tot_a"     if ustrregexm(d, "^reddito complessivo ?- ?ammontare")
        replace code = "cle0_f"    if ustrregexm(d, "minore o uguale a zero euro ?- ?frequenza")
        replace code = "cle0_a"    if ustrregexm(d, "minore o uguale a zero euro ?- ?ammontare")
        replace code = "c00_10_f"  if ustrregexm(d, "da 0 a 10000 euro ?- ?frequenza")
        replace code = "c00_10_a"  if ustrregexm(d, "da 0 a 10000 euro ?- ?ammontare")
        replace code = "c10_15_f"  if ustrregexm(d, "da 10000 a 15000 euro ?- ?frequenza")
        replace code = "c10_15_a"  if ustrregexm(d, "da 10000 a 15000 euro ?- ?ammontare")
        replace code = "c15_26_f"  if ustrregexm(d, "da 15000 a 26000 euro ?- ?frequenza")
        replace code = "c15_26_a"  if ustrregexm(d, "da 15000 a 26000 euro ?- ?ammontare")
        replace code = "c26_55_f"  if ustrregexm(d, "da 26000 a 55000 euro ?- ?frequenza")
        replace code = "c26_55_a"  if ustrregexm(d, "da 26000 a 55000 euro ?- ?ammontare")
        replace code = "c55_75_f"  if ustrregexm(d, "da 55000 a 75000 euro ?- ?frequenza")
        replace code = "c55_75_a"  if ustrregexm(d, "da 55000 a 75000 euro ?- ?ammontare")
        replace code = "c75_120_f" if ustrregexm(d, "da 75000 a 120000 euro ?- ?frequenza")
        replace code = "c75_120_a" if ustrregexm(d, "da 75000 a 120000 euro ?- ?ammontare")
        replace code = "c120p_f"   if ustrregexm(d, "oltre 120000 euro ?- ?frequenza")
        replace code = "c120p_a"   if ustrregexm(d, "oltre 120000 euro ?- ?ammontare")
    }

    foreach c in ncontrib imp_f imp_a lav_f lav_a c00_10_f c10_15_f c15_26_f {
        quietly count if code == "`c'"
        if r(N) != 38 di as error "  `y': voce `c' trovata per " r(N) " CAP (attesi 38)"
    }
    quietly count if missing(valore)
    local nmiss = r(N)
    quietly levelsof cap
    di as txt "  `y': " _N " righe, " r(r) " CAP, " `nmiss' " importi mancanti (oscurati)"

    keep anno cap descr d code valore
    if `first' == 0 append using `acc'
    quietly save `acc', replace
    local first 0
}

use `acc', clear
duplicates report anno cap d
capture isid anno cap d
if _rc di as error "  Attenzione: la chiave anno-CAP-voce non e' univoca"
gen int year = anno + $INC_SHIFT
label variable year "Anno di riferimento (anno d'imposta + INC_SHIFT)"
sort anno cap d
save "$WORK/irpef_long_all.dta", replace

*------------------------------------------------------------------------------*
* CAP x anno
*------------------------------------------------------------------------------*
keep if code != ""
keep anno cap code valore
isid anno cap code
reshape wide valore, i(anno cap) j(code) string
rename valore* *

foreach c in ncontrib imp_f imp_a lav_f lav_a pen_f pen_a tot_f tot_a cle0_f c00_10_f ///
    c10_15_f c15_26_f c26_55_f c55_75_f c75_120_f c120p_f {
    capture confirm variable `c'
    if _rc gen double `c' = .
}

gen int year = anno + $INC_SHIFT
gen double ybar_imp = imp_a / imp_f if imp_f > 0 & !missing(imp_f)
gen double ybar_lav = lav_a / lav_f if lav_f > 0 & !missing(lav_f)
gen double ybar_tot = tot_a / tot_f if tot_f > 0 & !missing(tot_f)
* le somme restano mancanti se una classe e' oscurata (nessuna somma "saltando" celle)
gen double nlow15   = c00_10_f + c10_15_f
gen double nlow26   = c00_10_f + c10_15_f + c15_26_f
gen double sh_low15 = nlow15 / ncontrib
gen double sh_low26 = nlow26 / ncontrib
egen byte nclass = rownonmiss(cle0_f c00_10_f c10_15_f c15_26_f c26_55_f c55_75_f c75_120_f c120p_f)

label variable anno     "Anno d'imposta"
label variable cap      "CAP"
label variable ncontrib "Numero contribuenti"
label variable ybar_imp "Reddito imponibile medio tra percettori con valore non nullo (EUR nominali)"
label variable ybar_lav "Reddito da lavoro dipendente e assimilati medio (EUR nominali)"
label variable ybar_tot "Reddito complessivo medio (solo anno d'imposta 2024)"
label variable nlow15   "Contribuenti con reddito complessivo >0 e <=15.000 EUR"
label variable nlow26   "Contribuenti con reddito complessivo >0 e <=26.000 EUR"
label variable sh_low15 "Quota su Numero contribuenti (denominatore include redditi nulli/negativi)"
label variable sh_low26 "Quota su Numero contribuenti (denominatore include redditi nulli/negativi)"
label variable nclass   "Classi di reddito complessivo osservate (su 8)"

* copertura delle classi (nel 2023 la classe oltre 120.000 e' oscurata in 11 CAP)
tab anno nclass
bysort cap: egen byte full_classes = min(cond(inrange(anno, 2019, 2023), nclass == 8, 1))
egen byte tagcap = tag(cap)
quietly count if tagcap & full_classes
di as txt "  CAP con tutte le 8 classi osservate in ogni anno 2019-2023: " r(N) " (atteso 20)"
drop tagcap

* variazioni anomale del numero di contribuenti (es. CAP 20121 nel 2023)
sort cap anno
by cap: gen double g_contrib = ncontrib/ncontrib[_n-1] - 1 if anno == anno[_n-1] + 1
di as txt "  Variazioni annue del numero di contribuenti oltre +/-20%:"
list cap anno ncontrib g_contrib if abs(g_contrib) > 0.20 & !missing(g_contrib), noobs
label variable g_contrib "Variazione annua del numero di contribuenti"

order anno year cap ncontrib imp_f imp_a ybar_imp lav_f lav_a ybar_lav nlow15 sh_low15 ///
    nlow26 sh_low26 nclass full_classes
sort cap anno
save "$WORK/irpef_cap_year.dta", replace

*------------------------------------------------------------------------------*
* Totali cittadini e controlli sui valori riportati nel documento
*------------------------------------------------------------------------------*
collapse (sum) imp_a imp_f nlow15 nlow26 ncontrib ///
    (count) n_imp=imp_a n_low15=nlow15 n_low26=nlow26, by(anno year)
foreach v in n_imp n_low15 n_low26 {
    quietly count if `v' != 38
    if r(N) > 0 di as error "  Totali cittadini: `v' < 38 in " r(N) " anni (somme parziali)"
}
gen double ybar_city = imp_a / imp_f
gen double sh15_city = 100 * nlow15 / ncontrib
gen double sh26_city = 100 * nlow26 / ncontrib
label variable ybar_city "Media imponibile ponderata (somma ammontari / somma frequenze)"
label variable sh15_city "% contribuenti con reddito complessivo >0 e <=15.000"
label variable sh26_city "% contribuenti con reddito complessivo >0 e <=26.000"
list anno ncontrib ybar_city nlow15 sh15_city nlow26 sh26_city, noobs abbreviate(12)

foreach pr in "2019 34226.60" "2023 39070.87" {
    tokenize `pr'
    quietly summarize ybar_city if anno == `1', meanonly
    checkval, label("Media imponibile ponderata `1'") value(`r(mean)') expected(`2') tol(1)
}
foreach pr in "2019 33.17" "2023 29.42" "2024 28.06" {
    tokenize `pr'
    quietly summarize sh15_city if anno == `1', meanonly
    checkval, label("Quota contribuenti 0-15.000 EUR, `1' (%)") value(`r(mean)') expected(`2') tol(0.01)
}
save "$WORK/irpef_city_year.dta", replace
export delimited using "$TAB/irpef_city_year.csv", replace
