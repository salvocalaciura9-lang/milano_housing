*==============================================================================*
* m3_replica_manuale.do
* Replica "a mano" del modello M3, da eseguire riga per riga.
* Prerequisito: aver eseguito una volta code/00_master.do (crea i file in data/work).
*
* Modello:  r_{j,t+1} = a_j + l_t + b * ln(A_jt) + e_jt
*   r = trasferimenti di residenza verso altri comuni italiani per 1.000 residenti
*   A = affitto annuo di 60 m2 (OMI, punto medio) / reddito imponibile medio (IRPEF)
*   a_j = effetti fissi di CAP, l_t = effetti fissi di anno
*==============================================================================*
clear all
set more off
global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"   // <- cambiare
global WORK "$ROOT/data/work"

*--- 1. Dati: pannello CAP x anno costruito dai moduli 01-12 -----------------*
use "$WORK/cap_panel_main_est.dta", clear
xtset capid year                  // capid = CAP numerato 1..38, year = 2011-2024

* esito in t+1 (F. = valore dell'anno successivo)
gen double y   = F.r_ac           // trasferimenti verso altri comuni, t+1
gen double lnR = ln(R_mid)        // ln affitto OMI (EUR/m2/mese)
gen double lnY = ln(ybar_imp)     // ln reddito imponibile medio
* lnAR esiste gia': ln(12*60*R_mid/ybar_imp)

* campione: affordability 2019-2023, CAP con copertura OMI >= 80%
gen byte s = inrange(year, 2019, 2023) & !missing(lnAR, y) & cover_ok == 1
count if s                        // 175 = 35 CAP x 5 anni

*--- 2. Descrittive: varianza totale, tra CAP (between) e dentro il CAP (within)
xtsum y lnAR if s

*--- 3. Il problema del TA: correlazione reddito-affitto prima e dopo gli FE --*
corr lnY lnR if s                                 // grezza: ~0.93
quietly regress lnY i.capid i.year if s
predict double wY if s, residuals
quietly regress lnR i.capid i.year if s
predict double wR if s, residuals
corr wY wR if s                                   // dopo FE CAP e anno: ~0.11

*--- 4. Stima principale ------------------------------------------------------*
* (0) senza effetti fissi, solo per confronto
regress y lnAR if s, vce(cluster capid)
* (1) PRINCIPALE: effetti fissi di CAP e anno, errori raggruppati per CAP
regress y lnAR i.year i.capid if s, vce(cluster capid)
* stessa stima con lo stimatore within
xtreg y lnAR i.year if s, fe vce(cluster capid)
* inferenza con pochi cluster: wild cluster bootstrap (ssc install boottest)
regress y lnAR i.year i.capid if s, vce(cluster capid)
boottest lnAR, reps(9999) weighttype(webb) seed(20261119) nograph

* lettura: effetto di +10% del rapporto affitto/reddito
display "+10% -> " _b[lnAR]*ln(1.1) " trasferimenti per 1.000"

*--- 5. Frisch-Waugh-Lovell: la stessa stima sui residui ----------------------*
quietly regress y i.capid i.year if s
predict double ry if s, residuals
quietly regress lnAR i.capid i.year if s
predict double rx if s, residuals
regress ry rx if s                                 // stessa pendenza della (1)
twoway (scatter ry rx if s) (lfit ry rx if s), legend(off) ///
    xtitle("ln(affitto/reddito), scarto da CAP e anno") ytitle("Trasferimenti, scarto")

*--- 6. Controlli predefiniti --------------------------------------------------*
gen double lnpop = ln(pop_al)
gen double pct65 = 100*sh_a65
regress y lnAR lnpop pct65 i.year i.capid if s, vce(cluster capid)         // demografia
gen double y2 = F2.r_ac
regress y2 lnAR i.year i.capid if inrange(year,2019,2023) & cover_ok==1, vce(cluster capid)  // t+2
regress y lnAR i.year i.capid if s & !inlist(year+1, 2020, 2021), vce(cluster capid)         // no pandemia
gen double Dy = D.y
gen double DlnAR = D.lnAR
regress Dy DlnAR i.year if s & L.s, vce(cluster capid)                    // differenze prime
gen double E1 = F.canc_ac_al
poisson E1 lnAR i.year i.capid if s, exposure(pop_al) vce(cluster capid)  // Poisson
gen double ylag = L.r_ac
regress ylag lnAR i.year i.capid if s, vce(cluster capid)                 // PLACEBO: atteso ~0

*--- 7. Scomposizione del rapporto: ln A = ln 720 + ln R - ln Y ----------------*
regress y lnR lnY i.year i.capid if s, vce(cluster capid)
test lnR + lnY = 0             // H0: effetti uguali e opposti (restrizione del rapporto)
