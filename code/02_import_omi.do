*==============================================================================*
* 02_import_omi.do
* Quotazioni OMI DS1996, 2004-2025 (44 semestri). Unita': zona x semestre x
* tipologia x stato. Locazioni in EUR/m2 al mese, compravendite in EUR/m2,
* superficie lorda (flag L). Selezione principale: Cod_Tip 20 (Abitazioni
* civili), stato NORMALE. Punto medio dell'intervallo come scenario centrale.
*
* Output: $WORK/omi_all.dta           tutte le righe di Milano, pulite
*         $WORK/omi_civ_sem.dta       abitazioni civili NORMALE, zona x semestre
*         $WORK/omi_zone_year.dta     media dei due semestri, zona x anno
*         $WORK/omi_zone_s1.dta       solo primi semestri (serie coerente 2019-2024)
*         $WORK/omi_zone_dict.dta     zona, LinkZona, fascia (+ descrizione)
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "02 - IMPORT QUOTAZIONI OMI" _n "{hline 78}"

imp_csv using "$RAW/$F_OMI"
capture confirm variable anno
if _rc getvar anno, pattern("anno( |$)")     // es. intestazione con BOM
foreach v in anno periodo zona linkzona cod_tip descr_tipologia stato compr_min compr_max ///
    sup_nl_compr loc_min loc_max sup_nl_loc {
    capture confirm variable `v'
    if _rc {
        di as error "Colonna OMI attesa non trovata: `v'"
        describe, simple
        exit 111
    }
}
tonum anno cod_tip compr_min compr_max loc_min loc_max

capture confirm variable comune_descrizione
if !_rc {
    quietly count if upper(ustrtrim(comune_descrizione)) != "MILANO"
    if r(N) > 0 {
        di as txt "  elimino " r(N) " righe di altri comuni"
        keep if upper(ustrtrim(comune_descrizione)) == "MILANO"
    }
}
foreach v in zona linkzona stato descr_tipologia sup_nl_compr sup_nl_loc fascia {
    capture confirm string variable `v'
    if !_rc quietly replace `v' = upper(ustrtrim(`v'))
}
* Semestri successivi al DS1996 del Comune, scaricati dal sito dell'Agenzia delle
* Entrate (formato "Valori di Mercato": una riga di titolo, decimali con la virgola,
* senza colonne anno/periodo). File: $RAW/omi_agenzia_AAAAsS_valori.csv
local agz : dir "$RAW" files "omi_agenzia_*_valori.csv"
capture confirm string variable periodo
if _rc tostring periodo, replace
foreach f of local agz {
    if !regexm("`f'", "omi_agenzia_([0-9][0-9][0-9][0-9])s([12])_valori") continue
    local ya = regexs(1)
    local sa = regexs(2)
    quietly count if anno == `ya' & ustrtrim(periodo) == "`sa'"
    if r(N) > 0 continue                       // semestre gia' nel DS1996
    preserve
    import delimited using "$RAW/`f'", clear delimiter(";") varnames(2) rowrange(3) ///
        stringcols(_all) encoding("latin1")
    rename *, lower
    keep if upper(ustrtrim(comune_descrizione)) == "MILANO"
    foreach v in cod_tip compr_min compr_max loc_min loc_max {
        replace `v' = subinstr(ustrtrim(`v'), ",", ".", .)
        destring `v', replace
    }
    foreach v in zona linkzona stato descr_tipologia sup_nl_compr sup_nl_loc fascia {
        capture confirm string variable `v'
        if !_rc replace `v' = upper(ustrtrim(`v'))
    }
    gen anno = `ya'
    gen str2 periodo = "`sa'"
    keep anno periodo zona linkzona fascia cod_tip descr_tipologia stato compr_min compr_max ///
        sup_nl_compr loc_min loc_max sup_nl_loc comune_descrizione
    tempfile agz1
    save `agz1'
    restore
    append using `agz1'
    di as txt "  aggiunto il semestre `ya'/`sa' dal file dell'Agenzia delle Entrate (`f')"
}
gen byte sem = real(substr(ustrtrim(periodo), 1, 1))
assert inlist(sem, 1, 2)
gen double t = anno + (sem - 1)/2

egen byte tag_t = tag(anno sem)
quietly count if tag_t
di as txt "  righe: " _N " (attese 27.284); semestri: " r(N) " (attesi 44)"
drop tag_t
duplicates report anno sem zona cod_tip stato

gen double R_mid = (loc_min + loc_max)/2
gen double P_mid = (compr_min + compr_max)/2
rename (loc_min loc_max compr_min compr_max) (R_min R_max P_min P_max)
label variable R_mid "Locazione: punto medio OMI (EUR/m2 lordo/mese)"
label variable R_min "Locazione: minimo OMI (EUR/m2 lordo/mese)"
label variable R_max "Locazione: massimo OMI (EUR/m2 lordo/mese)"
label variable P_mid "Compravendita: punto medio OMI (EUR/m2 lordo)"
label variable P_min "Compravendita: minimo OMI (EUR/m2 lordo)"
label variable P_max "Compravendita: massimo OMI (EUR/m2 lordo)"
label variable sem   "Semestre"
save "$WORK/omi_all.dta", replace

di as txt "  Flag di superficie per le abitazioni civili (attesi tutti L = lorda):"
tab sup_nl_loc sup_nl_compr if cod_tip == 20, missing

* zone con abitazioni civili quotate solo in stati diversi da NORMALE (es. C13)
preserve
keep if cod_tip == 20 & inrange(anno, $Y0, $Y1)
gen byte isnorm = (stato == "NORMALE")
collapse (max) isnorm, by(zona)
di as txt "  Zone con abitazioni civili ma senza stato NORMALE in $Y0-$Y1 (non sostituite):"
list zona if isnorm == 0, noobs
restore

*------------------------------------------------------------------------------*
* Selezione principale
*------------------------------------------------------------------------------*
keep if cod_tip == 20 & stato == "NORMALE"
capture isid zona anno sem
if _rc {
    di as error "Piu' righe per zona-semestre dopo la selezione: verificare"
    duplicates list zona anno sem
    exit 459
}

preserve
keep if inrange(anno, $Y0, $Y1)
egen byte tz = tag(zona)
quietly count if tz
di as txt "  Abitazioni civili NORMALE $Y0-$Y1: " r(N) " zone (attese 39), " _N " righe (attese 390)"
bysort zona: gen nsem = _N
di as txt "  Zone senza tutti i semestri del periodo:"
list zona nsem if tz & nsem < 2*($Y1 - $Y0 + 1), noobs
bysort zona (linkzona): gen byte lzchg = linkzona[1] != linkzona[_N]
quietly count if lzchg
if r(N) > 0 di as error "  LinkZona cambia nel periodo per alcune zone: controllare le geometrie"
quietly count if missing(R_mid)
di as txt "  semestri con locazione mancante: " r(N)
quietly count if missing(P_mid)
di as txt "  semestri con compravendita mancante: " r(N)
restore

* cambi di codice nel 2024 (D15 e D30 scompaiono, D37-D40 compaiono)
preserve
keep if anno == 2024
gen byte s1 = (sem == 1)
gen byte s2 = (sem == 2)
collapse (max) s1 s2, by(zona)
di as txt "  Zone presenti nel 1 sem. 2024 ma non nel 2 sem.:"
list zona if s1 == 1 & s2 == 0, noobs
di as txt "  Zone nuove nel 2 sem. 2024:"
list zona if s1 == 0 & s2 == 1, noobs
restore

capture confirm variable fascia
if _rc gen fascia = ""
keep anno sem t zona linkzona fascia R_mid R_min R_max P_mid P_min P_max sup_nl_loc sup_nl_compr
sort zona anno sem
save "$WORK/omi_civ_sem.dta", replace

* dizionario delle zone (ultima osservazione nel periodo principale)
preserve
keep if inrange(anno, $Y0, $Y1)
bysort zona (anno sem): keep if _n == _N
keep zona linkzona fascia
save "$WORK/omi_zone_dict.dta", replace
restore

* serie dei soli primi semestri (estensione coerente al 2024)
preserve
keep if sem == 1
keep zona anno R_mid R_min R_max P_mid P_min P_max
isid zona anno
save "$WORK/omi_zone_s1.dta", replace
restore

* indicatore annuale: media dei due semestri (missing se manca un semestre)
collapse (mean) R_mid R_min R_max P_mid P_min P_max (count) nR=R_mid nP=P_mid, by(zona anno)
foreach v in R_mid R_min R_max {
    quietly replace `v' = . if nR < 2
}
foreach v in P_mid P_min P_max {
    quietly replace `v' = . if nP < 2
}
label variable R_mid "Locazione, punto medio, media dei due semestri (EUR/m2 lordo/mese)"
label variable P_mid "Compravendita, punto medio, media dei due semestri (EUR/m2 lordo)"
label variable nR    "Semestri con locazione osservata"
label variable nP    "Semestri con compravendita osservata"
isid zona anno
save "$WORK/omi_zone_year.dta", replace

*------------------------------------------------------------------------------*
* Descrizioni delle zone (facoltativo; il CSV non contiene geometrie)
*------------------------------------------------------------------------------*
capture confirm file "$RAW/$F_OMIZONE"
if !_rc {
    preserve
    capture noisily {
        imp_csv using "$RAW/$F_OMIZONE"
        getvar zona, pattern("(^| )zona( |$)")
        getvar zona_descr, pattern("^zona_?descr") optional
        capture confirm variable zona_descr
        if _rc gen zona_descr = ""
        keep zona zona_descr
        replace zona = upper(ustrtrim(zona))
        duplicates drop zona, force
        tempfile zd
        save `zd'
        use "$WORK/omi_zone_dict.dta", clear
        merge 1:1 zona using `zd', keep(master match) nogen
        save "$WORK/omi_zone_dict.dta", replace
    }
    if _rc di as txt "  (descrizioni delle zone non aggiunte: struttura del CSV diversa dal previsto)"
    restore
}
