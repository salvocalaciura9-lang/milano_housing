*==============================================================================*
* 03b_import_moves.do
* Cancellazioni e iscrizioni anagrafiche per NIL e MOTIVO, 2004-2024
*   DS1600 (cancellazioni 2004-19) + DS1956 (2020-24)
*   DS1596 (iscrizioni 2004-19)    + DS1954 (2020-24)
* Motivi: altro comune italiano / estero / "Altro" (cancellazioni d'ufficio,
* es. irreperibilita': il picco 2013-14 del DS205 e' tutto in questa voce).
* La somma dei tre motivi coincide con Emigrati/Immigrati del DS205.
*
* I file riportano solo il nome del quartiere: il codice NIL si recupera dai
* nomi del DS205 (tutti gli anni), dopo normalizzazione.
*
* Output: variabili aggiunte a $WORK/ds205_nil_year.dta
*   canc_ac canc_es canc_alt   cancellazioni per altro comune / estero / altro
*   canc_ac_it canc_ac_st      di cui cittadini italiani / stranieri (altro comune)
*   isc_ac isc_es isc_alt      iscrizioni per motivo
*   r_ac  = 1000 canc_ac / residenti t-1     (esito principale del paper)
*   r_mov = 1000 (canc_ac + canc_es) / residenti t-1
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "03b - CANCELLAZIONI E ISCRIZIONI PER MOTIVO" _n "{hline 78}"

global MOVES_OK 0
local fc1 "$RAW/ds1600-popolazione-cancellazioni-evento-quartiere.csv"
local fc2 "$RAW/ds1956_popolazione_cancellazioni_evento_quartiere.csv"
local fi1 "$RAW/ds1596-popolazione-iscrizioni-evento-quartiere.csv"
local fi2 "$RAW/ds1954_popolazione_iscrizioni_evento_quartiere.csv"
foreach f in fc1 fc2 fi1 fi2 {
    capture confirm file "``f''"
    if _rc {
        di as error "  manca ``f'': 03b saltato"
        exit
    }
}

* chiave dei nomi: minuscole, solo lettere e cifre
capture program drop namekey
program define namekey
    args src dst
    gen `dst' = ustrlower(ustrtrim(`src'))
    replace `dst' = ustrregexra(`dst', "[^a-z0-9]", "")
end

* tabella nome -> NIL dal DS205 (tutti gli anni)
use "$WORK/ds205_nil_year.dta", clear
keep nil name
namekey name k
keep nil k
duplicates drop
duplicates tag k, gen(dupk)
quietly count if dupk
if r(N) > 0 {
    di as error "  nomi DS205 associati a piu' codici NIL:"
    list if dupk, noobs
}
drop dupk
duplicates drop k, force
tempfile names
save `names'

* import e unione dei due periodi
foreach kind in canc isc {
    local parts = cond("`kind'" == "canc", "fc1 fc2", "fi1 fi2")
    local first 1
    tempfile acc_`kind'
    foreach f of local parts {
        import delimited using "``f''", delimiters(";") varnames(1) stringcols(_all) ///
            encoding("utf-8") clear
        rename (*) (anno quartiere motivo genere cittadinanza n)
        destring anno n, replace
        if !`first' append using `acc_`kind''
        save `acc_`kind'', replace
        local first 0
    }
    use `acc_`kind'', clear
    gen str4 m = ""
    replace m = "ac"  if ustrregexm(ustrlower(motivo), "altro comune")
    replace m = "es"  if ustrregexm(ustrlower(motivo), "estero")
    replace m = "alt" if ustrlower(ustrtrim(motivo)) == "altro"
    assert m != ""
    gen byte st = ustrregexm(ustrlower(cittadinanza), "stranier")
    namekey quartiere k
    merge m:1 k using `names', keep(master match)
    quietly count if _merge == 1
    if r(N) > 0 {
        di as txt "  `kind': righe senza codice NIL (N.D. o nomi non riconosciuti), per quartiere:"
        tab quartiere if _merge == 1
    }
    gen byte nd = (_merge == 1)
    drop _merge
    * totali cittadini (inclusi N.D.) per la verifica con il DS205
    preserve
    collapse (sum) n, by(anno)
    rename (anno n) (year `kind'_tot_city)
    tempfile city_`kind'
    save `city_`kind''
    restore
    drop if nd
    gen str12 v = "`kind'_" + m
    preserve
    keep if m == "ac"
    replace v = "`kind'_ac_" + cond(st, "st", "it")
    tempfile byc
    save `byc'
    restore
    append using `byc'
    collapse (sum) n, by(nil anno v)
    reshape wide n, i(nil anno) j(v) string
    rename n`kind'_* `kind'_*
    rename anno year
    foreach x in ac es alt ac_it ac_st {
        capture confirm variable `kind'_`x'
        if _rc gen double `kind'_`x' = 0
        quietly replace `kind'_`x' = 0 if missing(`kind'_`x')
    }
    tempfile nil_`kind'
    save `nil_`kind''
}

* verifica: somma dei motivi = Emigrati / Immigrati del DS205 (citta', N.D. inclusi)
use `city_canc', clear
merge 1:1 year using `city_isc', nogen
merge 1:1 year using "$WORK/ds205_city_year.dta", keep(master match) nogen keepusing(emig_ds205 immig_ds205)
gen double d_emig  = canc_tot_city - emig_ds205
gen double d_immig = isc_tot_city - immig_ds205
di as txt "  Verifica con il DS205 (differenze attese nulle negli anni comuni):"
list year canc_tot_city emig_ds205 d_emig isc_tot_city immig_ds205 d_immig if !missing(emig_ds205), noobs

* aggiunta al pannello NIL del DS205
use "$WORK/ds205_nil_year.dta", clear
foreach v in canc_ac canc_es canc_alt canc_ac_it canc_ac_st isc_ac isc_es isc_alt isc_ac_it isc_ac_st {
    capture drop `v'
}
capture drop r_ac r_mov
merge 1:1 nil year using `nil_canc', keep(master match) nogen
merge 1:1 nil year using `nil_isc', keep(master match) nogen
gen double canc_tot = canc_ac + canc_es + canc_alt
gen double dchk = canc_tot - emig
di as txt "  Controllo NIL-anno: cancellazioni per motivo - Emigrati DS205"
summarize dchk if !missing(canc_tot), detail
drop dchk canc_tot
xtset nil year
gen double r_ac  = 1000*canc_ac/L.pop               if L.pop > 0 & !missing(L.pop, canc_ac)
gen double r_mov = 1000*(canc_ac + canc_es)/L.pop   if L.pop > 0 & !missing(L.pop, canc_ac)
label variable canc_ac  "Cancellazioni per altro comune italiano"
label variable canc_es  "Cancellazioni per l'estero"
label variable canc_alt "Cancellazioni per altri motivi (d'ufficio)"
label variable r_ac     "Trasferimenti verso altri comuni italiani per 1.000 residenti t-1"
label variable r_mov    "Trasferimenti verso altri comuni o l'estero per 1.000 residenti t-1"

di as txt "  Composizione delle cancellazioni per anno (somma NIL):"
preserve
collapse (sum) canc_ac canc_es canc_alt emig, by(year)
gen double sh_alt = 100*canc_alt/emig
list year canc_ac canc_es canc_alt emig sh_alt if year >= 2011, noobs
export delimited using "$TAB/cancellazioni_motivo_anno.csv", replace
restore

sort nil year
save "$WORK/ds205_nil_year.dta", replace
global MOVES_OK 1
