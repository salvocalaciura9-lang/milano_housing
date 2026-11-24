*==============================================================================*
* 05_import_index.do
* File dell'indice del paper (Biferale et al., Cities 2026): 88 NIL, misure
* 2011 e 2021, indici e geometrie WKT. 88 righe, 29 colonne.
*
* Al primo run stampa le colonne (nome Stata | intestazione | esempio) e si
* ferma se in 00_master.do mancano i nomi IX_*. Il resto della pipeline gira.
*
* Output: $TAB/index_codebook.csv
*         $WORK/index_nil.dta          una riga per NIL, nomi canonici, flag
*         $WORK/nil_geometry_wkt.csv   codice NIL + WKT (per mappe fuori Stata)
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "05 - IMPORT FILE DELL'INDICE" _n "{hline 78}"

global IX_OK 0
capture confirm file "$RAW/$F_INDEX"
if _rc {
    di as error "  $RAW/$F_INDEX non trovato: moduli 07 e 09 saltati"
    exit
}
imp_csv using "$RAW/$F_INDEX"
di as txt "  colonne: " c(k) " (attese 29); righe: " _N " (attese 88)"

* codebook per compilare la configurazione
di as txt _n "  {ul:Nome Stata}                       {ul:Intestazione originale}           {ul:Valore riga 1}"
foreach v of varlist _all {
    local lab : variable label `v'
    local val = substr(`v'[1], 1, 40)
    di as txt "  " %-32s "`v'" " " %-32s `"`lab'"' " " as res `"`val'"'
}
preserve
describe, replace clear
keep name varlab
export delimited using "$TAB/index_codebook.csv", replace
restore

* verifica della configurazione
local need IX_ID IX_NAME IX_INC11 IX_INC21 IX_PRICE11 IX_PRICE21 IX_EDU11 IX_EDU21 ///
    IX_EMP11 IX_EMP21 IX_IDX11 IX_IDX21
local bad
foreach g of local need {
    local vn = lower("${`g'}")
    if "`vn'" == "" {
        local bad `bad' `g'
        continue
    }
    capture confirm variable `vn'
    if _rc local bad `bad' `g'(`vn')
}
if "`bad'" != "" {
    di as error _n "  CONFIGURARE in 00_master.do (sezione 4) le colonne: `bad'"
    di as error "  Usare i nomi Stata elencati sopra (anche in $TAB/index_codebook.csv)."
    di as error "  I moduli 07 e 09 vengono saltati finche' la configurazione non e' completa."
    exit
}

* rinomina in due passaggi per evitare conflitti tra nomi
local pairs IX_ID:nil IX_NAME:name_ix IX_INC11:inc2011 IX_INC21:inc2021 ///
    IX_PRICE11:price2011 IX_PRICE21:price2021 IX_EDU11:edu2011 IX_EDU21:edu2021 ///
    IX_EMP11:emp2011 IX_EMP21:emp2021 IX_IDX11:idx2011 IX_IDX21:idx2021 ///
    IX_DELTA:delta_pub IX_GEOM:geom ///
    IX_ZINC11:zy_inc2011 IX_ZINC21:zy_inc2021 IX_ZPRICE11:zy_price2011 IX_ZPRICE21:zy_price2021 ///
    IX_ZEDU11:zy_edu2011 IX_ZEDU21:zy_edu2021 IX_ZEMP11:zy_emp2011 IX_ZEMP21:zy_emp2021
local i 0
local finals
foreach pr of local pairs {
    gettoken g fin : pr, parse(":")
    local fin = subinstr("`fin'", ":", "", 1)
    local vn = lower("${`g'}")
    if "`vn'" == "" continue
    capture confirm variable `vn'
    if _rc {
        di as txt "  (colonna facoltativa non trovata: `g' = `vn')"
        continue
    }
    local ++i
    rename `vn' __ix`i'
    local finals `finals' `fin'
}
keep __ix*
forvalues j = 1/`i' {
    local fin : word `j' of `finals'
    rename __ix`j' `fin'
}

capture confirm variable geom
if !_rc {
    preserve
    keep nil geom
    export delimited using "$WORK/nil_geometry_wkt.csv", replace
    restore
    drop geom
}
local gm geom
local keepl : list finals - gm
keep `keepl'
local nm name_ix
local numl : list keepl - nm
tonum `numl'
replace name_ix = ustrtrim(name_ix)

isid nil
di as txt "  NIL nel file dell'indice: " _N

*------------------------------------------------------------------------------*
* Valori sospetti (non trattati come condizioni economiche reali)
*------------------------------------------------------------------------------*
gen byte flag_inc0   = (inc2011 == 0 | inc2021 == 0)
gen byte flag_price0 = (price2011 == 0 | price2021 == 0)
gen byte flag_edu0   = (edu2011 == 0 | edu2021 == 0)
gen byte flag_emp0   = (emp2011 == 0 | emp2021 == 0)
gen byte flag_miss   = missing(inc2011, inc2021, price2011, price2021, edu2011, edu2021, emp2011, emp2021)
gen byte valid_full   = !(flag_inc0 | flag_price0 | flag_edu0 | flag_emp0 | flag_miss)
gen byte valid_social = !missing(edu2011, edu2021, emp2011, emp2021) & flag_edu0 == 0 & flag_emp0 == 0
label variable valid_full   "Tutte e quattro le componenti valide (non nulle, non mancanti)"
label variable valid_social "Istruzione e occupazione valide in entrambi gli anni"
di as txt "  NIL con valori sospetti (attesi: Giardini Porta Venezia, Muggiano, Chiaravalle,"
di as txt "  Quintosole, Ronchetto delle Rane, Parco Sempione):"
list nil name_ix flag_inc0 flag_price0 flag_edu0 flag_emp0 flag_miss if valid_full == 0, noobs
capture confirm variable delta_pub
if !_rc {
    di as txt "  Variazione pubblicata per i NIL con reddito nullo (0/0 e' indefinito):"
    list nil name_ix inc2011 inc2021 delta_pub if flag_inc0 == 1, noobs
}

* redditi ripetuti su NIL distinti (non sommare i totali)
duplicates tag inc2011 inc2021, gen(dup_inc)
di as txt "  NIL distinti con redditi identici in entrambi gli anni:"
list nil name_ix inc2011 inc2021 if dup_inc > 0 & flag_inc0 == 0, noobs sepby(inc2011)
drop dup_inc

*------------------------------------------------------------------------------*
* Corrispondenza con il DS205 per codice (i nomi da soli non bastano)
*------------------------------------------------------------------------------*
preserve
use "$WORK/ds205_nil_year.dta", clear
keep if year == 2021
keep nil name
tempfile n205
save `n205'
restore
merge 1:1 nil using `n205'
gen k1 = ustrregexra(ustrlower(name_ix), "[^a-z0-9]", "")
gen k2 = ustrregexra(ustrlower(name), "[^a-z0-9]", "")
di as txt "  Stesso codice, nome diverso (attesi ID 73 e 74; nessuna correzione automatica):"
list nil name_ix name if _merge == 3 & k1 != k2, noobs
di as txt "  Codici presenti in un solo file:"
list nil name_ix name _merge if _merge != 3, noobs
drop if _merge == 2
drop _merge k1 k2 name

sort nil
save "$WORK/index_nil.dta", replace
global IX_OK 1
