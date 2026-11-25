*==============================================================================*
* 18b_income_net.do
* Reddito NETTO mediano dei contribuenti milanesi: scenari di detrazione,
* controllo con le imposte vere (ds312) e scenario calibrato.
* L'indice principale (modulo 18) usa lo scenario "dip"; questo modulo mostra
* quanto cambia il risultato con le altre ipotesi.
*
* Idea: il netto cresce sempre con il lordo, quindi chi sta in una classe di
* reddito lorda sta anche nella classe netta corrispondente. Si calcola il netto
* ai confini di ogni classe del ds531 (0, 10.000, 15.000, 26.000, 55.000, ...),
* si tengono le frequenze e si interpola la mediana sulle classi nette.
*
* Netto = reddito complessivo - IRPEF netta - addizionale regionale
*         - addizionale comunale + bonus in busta paga (80 EUR / trattamento integrativo)
* Il reddito complessivo e' gia' al netto dei contributi previdenziali.
*
* Scenari di detrazione (il ds531 non dice chi e' dipendente, pensionato o autonomo):
*   dip : detrazioni da lavoro dipendente + bonus 80 EUR / trattamento integrativo
*   pen : detrazioni da pensione (under 75)
*   aut : detrazioni da lavoro autonomo
*   nod : nessuna detrazione (limite massimo delle imposte)
* Non si considerano detrazioni personali (carichi di famiglia, spese mediche,
* mutuo) ne' trasferimenti non dichiarati (assegno unico).
*
* Parametri (anno d'imposta)
*   IRPEF: 2008-2021 23/27/38/41/43% (15/28/55/75 mila); 2022-2023 23/25/35/43%
*          (15/28/50 mila); 2024 23/35/43% (28/50 mila).
*   Detrazioni: art. 13 TUIR nelle versioni 2008-2013, 2014-2021, 2022-2023, 2024.
*   Bonus 80 EUR (DL 66/2014, 640 EUR nel 2014, 960 dal 2015; soglie 24.600/26.600
*   dal 2018); trattamento integrativo e ulteriore detrazione (DL 3/2020) da
*   luglio 2020; dal 2022 trattamento integrativo solo fino a 15.000 EUR.
*   Addizionale comunale Milano (MEF, banca dati addizionale comunale, F205):
*     2008-2010 non istituita; 2011 0,2%; 2012 0,2-0,8% per scaglioni;
*     esenzione 33.500 (2011-2012), 21.000 (2013-2019), 23.000 (2020-2024);
*     2013-2024 aliquota unica 0,8%. Sopra la soglia si paga su tutto il reddito.
*   Addizionale regionale Lombardia: 2011-2022 1,23/1,58/1,72/1,73/1,74%
*     (15/28/55/75 mila); 2023-2024 1,23/1,58/1,72/1,73% (15/28/50 mila).
*     Il 2011 usa gia' le aliquote 2012: il gettito vero 2011 (0,419 mld, MEF)
*     e' al livello del 2012 (0,424), non del 2010 (0,329).
*     2007-2010: APPROSSIMATA (0,9% fino a 15.493,71; 1,3% fino a 30.987,41;
*     1,4% oltre); il modello resta entro il 7% del gettito vero (sezione 4).
*   Le addizionali sono dovute solo se l'IRPEF netta e' positiva.
*
* Output
*   $WORK/milano_income_net.dta     reddito lordo e netto (mediano e medio) per scenario
*   $TAB/income_net_scenarios.csv   idem, con rapporto netto/lordo
*   $TAB/income_net_check.csv       netto calcolato per alcuni redditi di prova
*   $TAB/aff_net_city_year.csv      quota di residenti oltre 30% e 40% del netto
*   $FIG/aff_net_share.png          confronto delle soglie
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "18b - REDDITO NETTO MEDIANO E AFFORDABILITY SUL NETTO" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in RAW:data/raw WORK:data/work TAB:output/tables FIG:output/figures CODE:code {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}

*--- 0. Programma netinc (file condiviso con il modulo 18) ------------------*
do "$CODE/netinc_program.do"

*--- 1. Controllo su redditi di prova -----------------------------------------*
clear
input double R
10000
15000
20000
25000
26000
30000
40000
55000
end
expand 3
bysort R: gen year = cond(_n==1, 2010, cond(_n==2, 2018, 2024))
foreach s in dip pen aut nod {
    netinc R, year(year) type(`s') gen(net_`s')
}
sort year R
format R net_* %9.0fc
di as txt _n "  Netto per alcuni redditi lordi di prova:"
list year R net_dip net_pen net_aut net_nod, noobs sepby(year)
export delimited using "$TAB/income_net_check.csv", replace

*--- 2. Classi di reddito del ds531 -> classi nette ----------------------------*
* classi 2004-2024 preparate dal modulo 18 (ds531 + file MEF 2004-2007);
* il netto si calcola dal 2007, quando entrano in vigore le regole del TUIR usate qui
use "$WORK/milano_income_classes.dta", clear
keep if year >= 2007
gen double avg = amt/n
gen double share = (ntot/2 - cum0)/n if inmed
* lordo (come nel modulo 18)
gen double med_gross = lo + share*(hi - lo) if inmed
foreach s in dip pen aut nod {
    netinc lo,  year(year) type(`s') gen(nlo_`s')
    netinc hi,  year(year) type(`s') gen(nhi_`s')
    netinc avg, year(year) type(`s') gen(navg_`s')
    replace nlo_`s' = lo if lo < 0
    gen double med_`s' = nlo_`s' + share*(nhi_`s' - nlo_`s') if inmed
    gen double amtnet_`s' = n*navg_`s'
}
collapse (max) y_med = med_gross ymed_dip = med_dip ymed_pen = med_pen ymed_aut = med_aut ///
         ymed_nod = med_nod (sum) amt amtnet_* (first) ntot, by(year)
gen double y_mean = amt/ntot
foreach s in dip pen aut nod {
    gen double ymean_`s' = amtnet_`s'/ntot
    gen double ratio_`s' = ymed_`s'/y_med
}
drop amt amtnet_*
* controllo: il lordo mediano coincide con quello del modulo 18
preserve
use "$WORK/milano_income.dta", clear
keep year y_med
rename y_med y_med18
tempfile m18
save `m18'
restore
merge 1:1 year using `m18', assert(match using) keep(match) nogen
assert reldif(y_med, y_med18) < 1e-6
drop y_med18
label variable ymed_dip "Reddito netto mediano, detrazioni da lavoro dipendente"
label variable ymed_pen "Reddito netto mediano, detrazioni da pensione"
label variable ymed_aut "Reddito netto mediano, detrazioni da lavoro autonomo"
label variable ymed_nod "Reddito netto mediano, senza detrazioni"
format y_med ymed_* y_mean ymean_* %9.0fc
format ratio_* %5.3f
di as txt _n "  Reddito mediano lordo e netto (anno d'imposta), per scenario di detrazione:"
list year y_med ymed_dip ymed_pen ymed_aut ymed_nod ratio_dip ratio_nod, noobs sep(0) abbrev(10)
save "$WORK/milano_income_net.dta", replace
export delimited using "$TAB/income_net_scenarios.csv", replace

*--- 3. Affordability sul netto -------------------------------------------------*
use "$WORK/aff_nil_year.dta", clear
keep if balanced & year >= 2007
merge m:1 year using "$WORK/milano_income_net.dta", keepusing(ymed_*) keep(match) nogen
foreach s in dip pen aut nod {
    gen double An_`s' = 12*60*R/ymed_`s'
    foreach t in 30 40 {
        gen double p`t'_`s' = pop*(An_`s' > `t'/100) if !missing(An_`s')
    }
}
* il netto "dipendente" deve coincidere con quello dell'indice principale (modulo 18)
assert reldif(An_dip, A60) < 1e-6 if !missing(A60)
gen double p30_gross = pop*(A60g > .30) if !missing(A60g)
gen double p40_gross = pop*(A60g > .40) if !missing(A60g)
gen double pop_ok = pop if !missing(A60g)
collapse (sum) p30_* p40_* pop_ok (median) An_dip_median = An_dip A60_median = A60g, by(year)
foreach v of varlist p30_* p40_* {
    local nm = subinstr("`v'", "p", "sh", 1)
    gen double `nm' = `v'/pop_ok
}
drop p30_* p40_* pop_ok
order year A60_median An_dip_median sh30_gross sh40_gross sh30_dip sh40_dip ///
      sh40_pen sh40_aut sh40_nod
format sh* %4.2f
format A60_median An_dip_median %4.3f
di as txt _n "  Quota di residenti (74 NIL) in NIL oltre la soglia, 60 m2:"
list year sh30_gross sh40_gross sh30_dip sh40_dip sh40_pen sh40_aut sh40_nod, noobs sep(0) abbrev(10)
export delimited using "$TAB/aff_net_city_year.csv", replace

twoway (connected sh30_gross year, lcolor("37 106 191") mcolor("37 106 191") msize(small)) ///
       (connected sh40_dip year, lcolor("200 90 50") mcolor("200 90 50") msize(small)) ///
       (line sh40_nod year, lcolor("200 90 50%50") lpattern(dash)) ///
       (line sh40_aut year, lcolor("200 90 50%50") lpattern(shortdash)), ///
       ylabel(0(.2)1, format(%3.1f)) xlabel(2007(2)2023 2024) ///
       ytitle("Quota di residenti in NIL oltre la soglia") xtitle("") ///
       title("Affitto di 60 m2: 30% del lordo e 40% del netto (soglia OCSE)", size(medsmall)) ///
       legend(order(1 "30% del reddito lordo mediano" 2 "40% del netto, dipendente" ///
              3 "40% del netto, senza detrazioni" 4 "40% del netto, autonomo") ///
              rows(2) size(small) position(6)) ///
       graphregion(color(white)) ///
       note("Netto = reddito complessivo - IRPEF - addizionali regionale e comunale + bonus in busta paga." ///
            "Mediana stimata sulle classi di reddito del ds531 trasformate in classi nette.", size(vsmall))
graph export "$FIG/aff_net_share.png", replace width(2400)

*--- 4. Controllo con le imposte effettivamente pagate a Milano ---------------*
* Totali per anno d'imposta di imposta netta, addizionale regionale e comunale
* dovute: ds312 del Comune per il 2012-2024, file MEF comunali per il 2007-2011. Si confrontano con le imposte che il
* modello attribuisce a ogni classe (calcolate al reddito medio della classe).
* L'imposta netta vera comprende tutte le detrazioni (familiari, spese mediche,
* ristrutturazioni, mutuo) e si calcola sul reddito imponibile, non sul complessivo.
import delimited using "$RAW/ds312_variabili_irpef_addizionali.csv", clear ///
    delimiter(";") varnames(1) encoding("utf-8")
rename (annodiimposta variabile frequenza ammontareineuro) (year var freq amt)
gen str8 k = ""
replace k = "imp"   if var == "Reddito imponibile"
replace k = "irp"   if var == "Imposta netta"
replace k = "impad" if var == "Reddito imponibile addizionale"
replace k = "reg"   if var == "Addizionale regionale dovuta"
replace k = "com"   if var == "Addizionale comunale dovuta"
assert k != ""
keep year k freq amt
reshape wide freq amt, i(year) j(k) string
keep year amtimp amtirp amtreg amtcom freqcom freqirp
rename (amtimp amtirp amtreg amtcom freqcom freqirp) (act_imponibile act_irp act_reg act_com act_ncom act_nirp)
tempfile act
save `act'

* 2007-2011: riga di Milano dei file MEF "redditi e principali variabili IRPEF
* su base comunale" (2011: somma dei CAP del file subcomunale), estratta in
* data/raw/mef_comunale_milano.csv (formato lungo: anno;variabile;valore)
import delimited using "$RAW/mef_comunale_milano.csv", clear delimiter(";") ///
    varnames(1) encoding("utf-8") stringcols(2)
rename anno year
keep if inrange(year, 2007, 2011)
gen str8 k = ""
replace k = "imp"  if strpos(variabile, "Reddito imponibile - Ammontare")
replace k = "irp"  if strpos(variabile, "Imposta netta - Ammontare")
replace k = "nirp" if strpos(variabile, "Imposta netta - Frequenza")
replace k = "reg"  if strpos(variabile, "Addizionale regionale dovuta - Ammontare")
replace k = "com"  if strpos(variabile, "Addizionale comunale dovuta - Ammontare")
replace k = "ncom" if strpos(variabile, "Addizionale comunale dovuta - Frequenza")
keep if k != ""
keep year k valore
reshape wide valore, i(year) j(k) string
rename (valoreimp valoreirp valorenirp valorereg valorecom valorencom) ///
       (act_imponibile act_irp act_nirp act_reg act_com act_ncom)
append using `act'
sort year
save `act', replace

use "$WORK/milano_income_classes.dta", clear
keep if inrange(year, 2007, 2024)
gen double avg = amt/n
foreach s in dip pen aut nod {
    netinc avg, year(year) type(`s') gen(nt_`s') irpout(i_`s') regout(r_`s') comout(c_`s')
    foreach v in i r c {
        replace `v'_`s' = n*`v'_`s'
    }
}
* contribuenti sopra la soglia di esenzione comunale (uniformi dentro la classe)
* (fino al 2010 l'addizionale comunale di Milano non era istituita: soglia mancante, ncom = 0)
gen double thr = cond(year <= 2010, ., cond(year <= 2012, 33500, cond(year <= 2019, 21000, 23000)))
gen double ncom = cond(lo >= thr, n, cond(hi > thr & lo < thr, n*(hi - thr)/(hi - lo), 0))
replace ncom = n if missing(hi) & lo >= thr
collapse (sum) amt i_* r_* c_* ncom, by(year)
merge 1:1 year using `act', assert(match) nogen
foreach v of varlist amt i_* r_* c_* act_irp act_reg act_com act_imponibile {
    replace `v' = `v'/1e9
}
gen double eff_act = (act_irp + act_reg + act_com)/amt
foreach s in dip pen aut nod {
    gen double eff_`s' = (i_`s' + r_`s' + c_`s')/amt
}
gen double imp_ratio = act_imponibile/amt
format amt i_* r_* c_* act_irp act_reg act_com act_imponibile %6.2f
format eff_* imp_ratio %5.3f
format ncom act_ncom %9.0fc
di as txt _n "  Imposte su tutti i contribuenti milanesi, miliardi di EUR (vere vs modello):"
list year amt act_irp i_dip i_pen i_aut i_nod, noobs sep(0) abbrev(10)
list year act_reg r_dip act_com c_dip act_ncom ncom imp_ratio, noobs sep(0) abbrev(10)
di as txt _n "  Aliquota media effettiva (IRPEF + addizionali) / reddito complessivo:"
list year eff_act eff_dip eff_pen eff_aut eff_nod, noobs sep(0) abbrev(10)
export delimited using "$TAB/income_net_validation.csv", replace

*--- 5. Scenario calibrato sulle imposte vere ----------------------------------*
* k = imposte vere / imposte del modello "dipendente" sul totale dei contribuenti.
* Le imposte al reddito mediano si riducono dello stesso fattore. Ipotesi forte:
* le detrazioni non modellate pesano in proporzione uguale su tutti i redditi.
gen double k_cal = (act_irp + act_reg + act_com)/(i_dip + r_dip + c_dip)
keep year k_cal
merge 1:1 year using "$WORK/milano_income_net.dta", keepusing(y_med ymed_dip) keep(match) nogen
gen double ymed_cal = y_med - k_cal*(y_med - ymed_dip)
gen double ratio_cal = ymed_cal/y_med
tempfile cal
save `cal'
use "$WORK/aff_nil_year.dta", clear
keep if balanced
merge m:1 year using `cal', keep(match) nogen
gen double p40 = pop*(12*60*R/ymed_cal > .40) if !missing(R)
gen double pop_ok = pop if !missing(R)
collapse (sum) p40 pop_ok (first) k_cal y_med ymed_dip ymed_cal ratio_cal, by(year)
gen double sh40_cal = p40/pop_ok
drop p40 pop_ok
format y_med ymed_dip ymed_cal %9.0fc
format k_cal ratio_cal sh40_cal %5.3f
di as txt _n "  Scenario calibrato sulle imposte vere (MEF 2007-2011, ds312 2012-2024):"
list, noobs sep(0) abbrev(10)
export delimited using "$TAB/income_net_calibrated.csv", replace

*--- 6. Tipi di reddito dei contribuenti milanesi -------------------------------*
* Quanti contribuenti hanno redditi da lavoro dipendente, da pensione, da lavoro
* autonomo (file MEF comunali; 2011 somma dei CAP). Un contribuente puo' avere
* piu' tipi di reddito, quindi le quote non sommano a 1. Serve a motivare
* l'ipotesi sulle detrazioni dell'indice principale.
import delimited using "$RAW/mef_comunale_milano.csv", clear delimiter(";") ///
    varnames(1) encoding("utf-8") stringcols(2)
rename anno year
gen str4 k = ""
replace k = "n"   if strpos(variabile, "Numero contribuenti")
replace k = "dip" if strpos(variabile, "Reddito da lavoro dipendente") & strpos(variabile, "Frequenza")
replace k = "pen" if strpos(variabile, "Reddito da pensione") & strpos(variabile, "Frequenza")
replace k = "aut" if strpos(variabile, "Reddito da lavoro autonomo") & strpos(variabile, "Frequenza")
keep if k != ""
* (2004-2005: lavoro autonomo in due voci, sez. E-IA e E-IB: si sommano)
collapse (sum) valore, by(year k)
reshape wide valore, i(year) j(k) string
rename valore* *
foreach t in dip pen aut {
    gen double sh_`t' = `t'/n
}
format n dip pen aut %10.0fc
format sh_* %4.2f
di as txt _n "  Contribuenti milanesi per tipo di reddito:"
list year n dip pen aut sh_dip sh_pen sh_aut, noobs sep(0)
export delimited using "$TAB/income_types_milano.csv", replace
