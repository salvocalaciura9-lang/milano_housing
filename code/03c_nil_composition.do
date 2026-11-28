*==============================================================================*
* 03c_nil_composition.do
* Composizione della popolazione e variazione netta di coorte per eta', per NIL e anno
*
* Dati (Open Data Comune di Milano, in $RAW)
*   ds27   residenti per NIL, eta' (anni singoli), genere e cittadinanza, 1999-2025
*   ds1440 famiglie per NIL, eta' e genere del capofamiglia, componenti, 1999-2025
*   ds141 + ds1943  nati per NIL e cittadinanza dei genitori, 2003-2020 e 2021-2024
*   (ds135 e' un sottoinsieme di ds1440; ds1940/ds131 decessi: per NIL solo dal
*    2021, per municipio prima; nascite e decessi per NIL 2011-2024 sono gia' nel DS205)
*
* Misure costruite (NIL x anno)
*   Composizione: quote per eta' (0-14, 15-24, 25-39, 40-64, 65+), stranieri,
*     stranieri da paesi ad alto reddito (UE-15, Regno Unito, Svizzera, Nord America,
*     Giappone, Corea del Sud, Oceania, Israele, Singapore), famiglie unipersonali,
*     famiglie con capofamiglia sotto i 35 anni, componenti medi, quota di nati da
*     madre straniera.
*   Variazione netta di coorte (saldo residuo; variabili nm_*):
*     nm(a1-a2, t) = 1000 x [residenti di eta' a1+1..a2+1 in t - residenti di eta'
*     a1..a2 in t-1] / residenti di eta' a1..a2 in t-1  (eta' al 31/12, ds27).
*     NON e' un saldo migratorio osservato: e' la variazione della stessa coorte
*     in un anno, quindi somma iscrizioni e cancellazioni (anche i traslochi
*     DENTRO Milano tra NIL), i decessi e le rettifiche anagrafiche (es.
*     cancellazioni per irreperibilita'). Sotto i 65 anni i decessi sono pochi,
*     quindi e' un'approssimazione (per eccesso di uscite) del saldo migratorio
*     della coorte. Le nascite non entrano (eta' >= 1 in t).
*     Classi (eta' in t-1): 0-9 (famiglie con bambini), 20-29, 30-39, 40-64.
*
* Output: $WORK/nil_composition_year.dta, $TAB/nil_composition_check.csv
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "03c - COMPOSIZIONE DEI NIL E VARIAZIONE NETTA DI COORTE PER ETA'" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in RAW:data/raw WORK:data/work TAB:output/tables {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}
* Il CSV (157 MB) supera il limite di GitHub: nel repository c'e' lo zip.
* Se manca il CSV, lo si estrae dallo zip.
capture confirm file "$RAW/ds27_pop_sto_quartiere.csv"
if _rc {
    capture confirm file "$RAW/ds27_pop_sto_quartiere.zip"
    if _rc == 0 {
        local here `"`c(pwd)'"'
        quietly cd "$RAW"
        unzipfile "ds27_pop_sto_quartiere.zip", replace
        quietly cd `"`here'"'
    }
}
capture confirm file "$RAW/ds27_pop_sto_quartiere.csv"
if _rc {
    di as error "  manca ds27_pop_sto_quartiere.csv (o .zip): 03c saltato"
    exit
}

*--- 1. Residenti per eta' e cittadinanza (ds27) --------------------------------*
import delimited using "$RAW/ds27_pop_sto_quartiere.csv", clear delimiter(";") ///
    varnames(1) encoding("utf-8")
rename nil nilname
rename (anno idnil residenti) (year nil n)
gen int age = real(ustrregexs(0)) if ustrregexm(eta, "^[0-9]+")
assert !missing(age)
replace cittadinanza = ustrtrim(cittadinanza)
gen byte ita = cittadinanza == "Italia"
gen byte hi = inlist(cittadinanza, "Francia", "Regno Unito", "Spagna", "Germania", "Paesi Bassi", ///
        "Belgio", "Austria", "Svezia", "Danimarca") | ///
    inlist(cittadinanza, "Finlandia", "Irlanda", "Portogallo", "Lussemburgo", "Grecia", ///
        "Svizzera", "Norvegia", "Islanda") | ///
    inlist(cittadinanza, "Stati Uniti D'America", "Canada", "Giappone", "Corea del Sud, Rep.", ///
        "Australia", "Nuova Zelanda", "Israele", "Singapore")
* controllo della classificazione: paesi ad alto reddito trovati
preserve
keep if hi
collapse (sum) n, by(cittadinanza)
di as txt "  Paesi classificati ad alto reddito:"
list, noobs sep(0)
restore

gen byte g0014 = age <= 14
gen byte g1524 = inrange(age, 15, 24)
gen byte g2539 = inrange(age, 25, 39)
gen byte g4064 = inrange(age, 40, 64)
gen byte g65 = age >= 65
foreach g in g0014 g1524 g2539 g4064 g65 {
    gen double n_`g' = n*`g'
}
gen double n_for = n*!ita
gen double n_hi = n*hi

* coorti per la variazione netta di coorte: residenti per eta' singola fino a 66 anni
preserve
keep if age <= 66
collapse (sum) n, by(nil year age)
tempfile ages
save `ages'
restore

collapse (sum) pop27 = n n_g0014 n_g1524 n_g2539 n_g4064 n_g65 n_for n_hi, by(nil year)
foreach g in g0014 g1524 g2539 g4064 g65 {
    gen double sh_`g' = n_`g'/pop27
}
gen double sh_for27 = n_for/pop27
gen double sh_hi = n_hi/pop27
gen double sh_hi_for = n_hi/n_for
label variable pop27 "Residenti (ds27)"
label variable sh_g2539 "Quota di residenti 25-39 anni"
label variable sh_g0014 "Quota di residenti 0-14 anni"
label variable sh_g65 "Quota di residenti 65 anni e oltre"
label variable sh_for27 "Quota di stranieri (ds27)"
label variable sh_hi "Quota di stranieri da paesi ad alto reddito"
label variable sh_hi_for "Stranieri ad alto reddito / stranieri"
drop n_*
tempfile comp
save `comp'

* variazione netta di coorte (saldo residuo)
use `ages', clear
rename n n0
tempfile a0
save `a0'
use `ages', clear
replace age = age - 1
replace year = year - 1
rename n n1
merge 1:1 nil year age using `a0', keep(match) nogen
* ora n0 = eta' a nell'anno year, n1 = eta' a+1 nell'anno year+1
replace year = year + 1
gen str6 cls = ""
replace cls = "c0009" if inrange(age, 0, 9)
replace cls = "c2029" if inrange(age, 20, 29)
replace cls = "c3039" if inrange(age, 30, 39)
replace cls = "c4064" if inrange(age, 40, 64)
drop if cls == ""
collapse (sum) n0 n1, by(nil year cls)
gen double nm = 1000*(n1 - n0)/n0
keep nil year cls nm
reshape wide nm, i(nil year) j(cls) string
rename nm* nm_*
label variable nm_c2029 "Variazione netta di coorte 20-29 anni (saldo residuo, per 1.000 in t-1)"
label variable nm_c3039 "Variazione netta di coorte 30-39 anni (saldo residuo, per 1.000 in t-1)"
label variable nm_c0009 "Variazione netta di coorte 0-9 anni (saldo residuo, per 1.000 in t-1)"
label variable nm_c4064 "Variazione netta di coorte 40-64 anni (saldo residuo, per 1.000 in t-1)"
merge 1:1 nil year using `comp', nogen
tempfile comp2
save `comp2'

*--- 2. Famiglie (ds1440) -------------------------------------------------------*
import delimited using "$RAW/ds1440_popolazione_residenti_famiglie_quartiere.csv", clear ///
    delimiter(";") varnames(1) encoding("utf-8")
rename anno year
gen int nil = real(ustrregexs(1)) if ustrregexm(quartiere, "\(([0-9]+)\)")
assert !missing(nil)
gen int k = real(ustrregexs(0)) if ustrregexm(numero_componenti, "^[0-9]")
gen byte young = ustrregexm(classe_eta_capofamiglia, "Meno di 35")
gen double f1 = famiglie*(k == 1)
gen double fy = famiglie*young
gen double fk = famiglie*k
collapse (sum) fam = famiglie f1 fy fk, by(nil year)
gen double sh_fam1_h = f1/fam
gen double sh_head35 = fy/fam
gen double hh_size = fk/fam
label variable sh_fam1_h "Quota di famiglie unipersonali (ds1440)"
label variable sh_head35 "Quota di famiglie con capofamiglia sotto i 35 anni"
label variable hh_size "Componenti medi (5 e piu' contati come 5)"
keep nil year fam sh_fam1_h sh_head35 hh_size
merge 1:1 nil year using `comp2', nogen
save `comp2', replace

*--- 3. Nascite (ds141 + ds1943) ------------------------------------------------*
* abbinamento per nome con i nomi dei NIL del DS205 e del ds27
use "$WORK/ds205_nil_year.dta", clear
keep nil name
duplicates drop
gen str80 key = ustrupper(ustrtrim(name))
tempfile k205
save `k205'
import delimited using "$RAW/ds27_pop_sto_quartiere.csv", clear delimiter(";") varnames(1) encoding("utf-8") colrange(2:3)
duplicates drop
rename (idnil nil) (nilcode nilname)
gen str80 key = ustrupper(ustrtrim(nilname))
rename nilcode nil
keep nil key
append using `k205'
keep nil key
duplicates drop
* chiavi normalizzate: senza accenti, apostrofi e punteggiatura
replace key = ustrregexra(ustrto(ustrnormalize(key, "nfd"), "ascii", 2), "[^A-Z0-9]", "")
duplicates drop key, force
tempfile keys
save `keys'

clear
tempfile b
foreach f in "ds141-popolazione-nascite-quartiere.csv" "ds1943_popolazione-nascite-residenti-quartiere.csv" {
    capture confirm file "$RAW/`f'"
    if _rc continue
    import delimited using "$RAW/`f'", clear delimiter(";") varnames(1) encoding("utf-8")
    capture rename numerosit* nb
    capture rename numerosita nb
    rename anno_evento year
    keep year quartiere cittadinanza_madre2 nb
    capture append using `b'
    save `b', replace
}
gen str80 key = ustrregexra(ustrto(ustrnormalize(ustrupper(ustrtrim(quartiere)), "nfd"), "ascii", 2), "[^A-Z0-9]", "")
merge m:1 key using `keys', keep(master match)
quietly count if _merge == 1
if r(N) {
    di as txt "  Nascite: quartieri non abbinati a un NIL (esclusi):"
    tab quartiere if _merge == 1
}
keep if _merge == 3
drop _merge
gen double nbf = nb*(ustrtrim(cittadinanza_madre2) == "Straniera")
collapse (sum) births27 = nb nbf, by(nil year)
gen double sh_birth_for = nbf/births27
label variable sh_birth_for "Quota di nati da madre straniera"
keep nil year births27 sh_birth_for
merge 1:1 nil year using `comp2', nogen
gen double birth_rate = 1000*births27/pop27
label variable birth_rate "Nati per 1.000 residenti"

*--- 4. Controllo con il DS205 e salvataggio ------------------------------------*
merge 1:1 nil year using "$WORK/ds205_nil_year.dta", keepusing(pop sh_foreign) keep(master match)
gen double ratio = pop27/pop if _merge == 3
di as txt _n "  Controllo: residenti ds27 / residenti DS205 (anni in comune)"
summarize ratio, detail
quietly corr sh_for27 sh_foreign if _merge == 3
di as txt "  Correlazione quota stranieri ds27 - DS205: " as res %6.4f r(rho)
preserve
collapse (mean) ratio (min) rmin = ratio (max) rmax = ratio, by(year)
list if !missing(ratio), noobs sep(0)
export delimited using "$TAB/nil_composition_check.csv", replace
restore
drop _merge pop sh_foreign ratio
order nil year pop27
sort nil year
compress
save "$WORK/nil_composition_year.dta", replace
di as txt "  Salvato nil_composition_year.dta: " as res _N as txt " righe NIL x anno"
