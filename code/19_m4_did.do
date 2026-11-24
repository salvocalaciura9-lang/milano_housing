*==============================================================================*
* 19_m4_did.do
* M4 e mercato della casa: differenza nelle differenze con aperture scaglionate
* e controlli migliori (versione che risponde ai commenti del TA)
*
* Commenti del TA e risposta del disegno
*  1. "La M4 e' stata aperta in momenti diversi"  -> ogni zona ha la data della
*     propria tratta; stimatore di Callaway e Sant'Anna (2021): ogni gruppo di
*     apertura e' confrontato solo con zone non ancora trattate o mai esposte,
*     mai con zone gia' trattate (che distorcono il modello classico a effetti
*     fissi: Goodman-Bacon, 2021).
*  2. "Servono quartieri con dinamiche simili prima della metro e magari
*     candidati per il percorso" -> due gruppi di controllo:
*       (a) NON ANCORA TRATTATE: le zone delle tratte aperte dopo, scelte dallo
*           stesso progetto della linea (i "candidati al percorso");
*       (b) ABBINATE: per ogni zona trattata, le 3 zone mai esposte piu' simili
*           prima della metro (livello e crescita di affitti, livello dei prezzi,
*           composizione dei residenti nel 2014).
*  3. "Anticipazione all'annuncio" -> event study per semestre con riferimento
*     al semestre prima dell'apertura e media dei coefficienti pre-apertura.
*     Il pannello parte dal 2014 (zonizzazione OMI coerente): l'annuncio della
*     linea e l'avvio dei cantieri sono precedenti e non si possono testare.
*  4. "Prezzi e altre dinamiche di gentrificazione" -> esiti: affitti e prezzi
*     di compravendita (zone OMI, semestri) e, per NIL, uscite, ingressi,
*     quota di stranieri, di famiglie unipersonali, di over 65, residenti.
*
* Aperture (fonti nel documento del gruppo)
*   tratta 1  Linate - Dateo                 26/11/2022  -> primo semestre trattato 2023S1
*   tratta 2  Dateo - San Babila (Tricolore, San Babila)  04/07/2023 -> 2023S2
*   tratta 3  San Babila - San Cristoforo    12/10/2024  -> 2025S1
*   Per i dati annuali per NIL: 2023, 2024, 2025 (fuori dal pannello: non ancora trattati).
*
* Trattamento (fissato prima di guardare i risultati, come nella versione precedente)
*   Punto della griglia "servito di nuovo" = entro $M4_RADIUS m da una stazione M4 e
*   oltre $M4_RADIUS m da stazioni di altre linee. Esposizione di un'area alla tratta p =
*   quota dei suoi punti serviti di nuovo da stazioni della tratta p. Gruppo di
*   apertura = prima tratta con esposizione >= $M4_TREAT. Mai esposte = nessun punto
*   entro $M4_RADIUS m da una stazione M4. Le altre aree (esposte solo in parte o
*   gia' servite da altre linee) sono escluse.
*
* Esiti
*   Zone OMI, semestri 2014S1-2025S2: ln affitto (principale) e ln prezzo.
*   Nota: con un reddito unico per tutta Milano, ln(affitto/reddito mediano) =
*   ln affitto - ln reddito_t; il secondo termine e' uguale per tutte le zone in un
*   periodo e si cancella nel confronto: l'effetto su ln affordability coincide con
*   quello su ln affitto, e si possono usare anche i semestri del 2025.
*   NIL, anni 2008-2024: trasferimenti verso altri comuni (r_ac) e ingressi da altri
*   comuni e dall'estero per 1.000 residenti (dal 2012); dal modulo 03c migrazione
*   netta per coorte 20-29, 30-39 e 0-9 anni (traslochi dentro Milano compresi),
*   quota di 25-39enni, di stranieri, di stranieri da paesi ad alto reddito, di
*   famiglie con capofamiglia sotto i 35 anni, ln residenti. Controlli: tutti i NIL
*   mai esposti, oppure i 3 piu' simili nella composizione 2014 (modulo 20).
*
* Inferenza: con poche zone trattate gli errori cluster non sono affidabili
* (Conley e Taber, 2011; MacKinnon e Webb, 2018). Si usa un test di permutazione:
* i gruppi di apertura vengono riassegnati a caso alle aree del campione
* ($M4_PERMS volte) e si conta quante volte l'effetto e' grande come quello stimato.
*
* Output: $TAB/m4_groups.csv, m4_cs_results.csv, m4_cs_event.csv;
*         $FIG/m4_cs_event_rent.png, m4_cs_event_price.png
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "19 - M4: DIFF-IN-DIFF CON APERTURE SCAGLIONATE E CONTROLLI MIGLIORI" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in RAW:data/raw WORK:data/work TAB:output/tables FIG:output/figures {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}
if "$SEED" == "" global SEED 20261119
if "$M4_RADIUS" == "" global M4_RADIUS 800
if "$M4_TREAT" == "" global M4_TREAT 0.20
if "$M4_PERMS" == "" global M4_PERMS 999
if "$SMALL_NIL" == "" global SMALL_NIL 500
local NMATCH 3

foreach f in "$RAW/ds535_tpl_metrofermate.csv" "$WORK/omi_zone21_sem.dta" {
    capture confirm file "`f'"
    if _rc {
        di as error "  manca `f' (stazioni ATM / modulo 18): 19 saltato"
        exit
    }
}

*------------------------------------------------------------------------------*
* 0. Programmi
*------------------------------------------------------------------------------*
* csatt: ATT di Callaway e Sant'Anna con periodo base universale (g - step).
*   Per ogni gruppo g e periodo t:
*   ATT(g,t) = media [Y_t - Y_base] dei trattati g - media [Y_t - Y_base] dei controlli,
*   controlli = aree del campione mai esposte o con apertura dopo max(t, base).
*   r(att) = media degli ATT(g,t) dopo l'apertura (t da g a tmax), pesata per la
*            numerosita' del gruppo;
*   r(pre) = stessa media sugli anni prima (da g - prewin*step a g - 2*step): placebo.
capture program drop csatt
program define csatt, rclass
    syntax varname, Unit(varname) Time(varname) Cohort(varname) Sample(varname) ///
        Step(real) Tmax(real) [Prewin(integer 8) ESframe(string)]
    local y `varlist'
    tempvar yb dy trt ctl mT mC
    quietly levelsof `cohort' if `cohort' > 0 & `sample', local(G)
    local num 0
    local den 0
    local nump 0
    local denp 0
    if "`esframe'" != "" {
        capture frame drop `esframe'
        frame create `esframe' double g double t double att long nT
    }
    foreach g of local G {
        local b = `g' - `step'
        quietly {
            capture drop `yb' `dy' `trt' `ctl' `mT' `mC'
            bysort `unit': egen double `yb' = max(cond(abs(`time' - `b') < 1e-6, `y', .))
            gen double `dy' = `y' - `yb' if `sample'
            gen byte `trt' = abs(`cohort' - `g') < 1e-6 & `sample'
            gen byte `ctl' = `sample' & !`trt' & (`cohort' == 0 | `cohort' > max(`time', `b') + 1e-6)
            bysort `time': egen double `mT' = mean(cond(`trt', `dy', .))
            bysort `time': egen double `mC' = mean(cond(`ctl', `dy', .))
            count if `trt' & abs(`time' - `b') < 1e-6 & !missing(`yb')
            local ng = r(N)
            levelsof `time' if `time' <= `tmax' + 1e-6, local(T)
        }
        if `ng' == 0 continue
        foreach t of local T {
            quietly summarize `mT' if abs(`time' - `t') < 1e-6, meanonly
            local a = r(mean)
            quietly summarize `mC' if abs(`time' - `t') < 1e-6, meanonly
            local a = `a' - r(mean)
            if missing(`a') continue
            if `t' >= `g' - 1e-6 {
                local num = `num' + `ng'*`a'
                local den = `den' + `ng'
            }
            if `t' <= `g' - 2*`step' + 1e-6 & `t' >= `g' - `prewin'*`step' - 1e-6 {
                local nump = `nump' + `ng'*`a'
                local denp = `denp' + `ng'
            }
            if "`esframe'" != "" frame post `esframe' (`g') (`t') (`a') (`ng')
        }
    }
    return scalar att = cond(`den' > 0, `num'/`den', .)
    return scalar pre = cond(`denp' > 0, `nump'/`denp', .)
end

* permutazione dei gruppi di apertura tra le aree del campione
capture mata: mata drop m4_perm()
mata:
void m4_perm(string scalar c, string scalar sel, string scalar out)
{
    real colvector v
    v = st_data(., c, sel)
    st_store(., out, sel, jumble(v))
}
end

* m4run: stima, permutazione, salvataggio di una riga dei risultati
capture program drop m4run
program define m4run
    syntax varname, Unit(varname) Time(varname) Cohort(varname) Sample(varname) ///
        Step(real) Tmax(real) Spec(string) Perms(integer) [Prewin(integer 8) ESframe(string)]
    local y `varlist'
    csatt `y', unit(`unit') time(`time') cohort(`cohort') sample(`sample') step(`step') ///
        tmax(`tmax') prewin(`prewin') esframe(`esframe')
    local att = r(att)
    local pre = r(pre)
    tempvar first cpf cp
    quietly {
        bysort `unit' (`time'): gen byte `first' = _n == 1 & `sample'
        count if `first' & `cohort' > 0
        local nT = r(N)
        count if `first' & `cohort' == 0
        local nC = r(N)
    }
    local ext 0
    local extp 0
    local ok 0
    forvalues j = 1/`perms' {
        quietly {
            capture drop `cpf' `cp'
            gen double `cpf' = .
            mata: m4_perm("`cohort'", "`first'", "`cpf'")
            bysort `unit': egen double `cp' = max(`cpf')
        }
        csatt `y', unit(`unit') time(`time') cohort(`cp') sample(`sample') step(`step') ///
            tmax(`tmax') prewin(`prewin')
        if !missing(r(att)) {
            local ++ok
            if abs(r(att)) >= abs(`att') - 1e-12 local ++ext
            if abs(r(pre)) >= abs(`pre') - 1e-12 local ++extp
        }
    }
    local p = (`ext' + 1)/(`ok' + 1)
    local pp = (`extp' + 1)/(`ok' + 1)
    frame post m4cs ("`spec'") ("`y'") (`att') (`p') (`pre') (`pp') (`nT') (`nC')
    di as txt "  -> " as res "`spec'" as txt " [`y']: effetto " as res %8.4f `att' ///
        as txt "  p perm = " as res %5.3f `p' as txt "   placebo pre " as res %8.4f `pre' ///
        as txt "  p perm = " as res %5.3f `pp' as txt "   trattate " `nT' "  controlli " `nC'
end

capture frame drop m4cs
frame create m4cs str90 spec str16 outcome double att double p_perm double pre double p_perm_pre long nT long nC

*------------------------------------------------------------------------------*
* 1. Stazioni ed esposizione dei punti della griglia
*------------------------------------------------------------------------------*
import delimited using "$RAW/ds535_tpl_metrofermate.csv", clear delimiter(";") ///
    varnames(1) encoding("utf-8") stringcols(_all)
rename (long_x_4326 lat_y_4326) (lon lat)
destring lon lat, replace
replace nome = ustrupper(ustrtrim(nome))
replace linee = subinstr(linee, " ", "", .)
gen byte m4 = strpos("," + linee + ",", ",4,") > 0
gen byte other = ustrregexm(linee, "[1235]")
gen byte phase = .
replace phase = 1 if m4 & inlist(nome, "LINATE AEROPORTO", "REPETTI", "STAZIONE FORLANINI", "ARGONNE", "SUSA", "DATEO")
replace phase = 2 if m4 & inlist(nome, "TRICOLORE", "SAN BABILA")
replace phase = 3 if m4 & missing(phase)
quietly count if m4
di as txt "  Stazioni M4: " as res r(N)
keep if m4 | other
keep nome lon lat m4 other phase
local n = _N
forvalues i = 1/`n' {
    local x`i' = lon[`i']
    local y`i' = lat[`i']
    local m4`i' = m4[`i']
    local ot`i' = other[`i']
    local ph`i' = phase[`i']
}

use "$WORK/xwa_grid.dta", clear
keep pid lon lat zona nil
local R = 6371000
local k = _pi/180
foreach v in d1 d2 d3 d4 doth {
    gen double `v' = .
}
forvalues i = 1/`n' {
    tempvar dd
    quietly gen double `dd' = 2*`R'*asin(sqrt(sin((lat - `y`i'')*`k'/2)^2 + ///
        cos(lat*`k')*cos(`y`i''*`k')*sin((lon - `x`i'')*`k'/2)^2))
    if `ot`i'' quietly replace doth = min(doth, `dd')
    if `m4`i'' {
        quietly replace d4 = min(d4, `dd')
        quietly replace d`ph`i'' = min(d`ph`i'', `dd')
    }
    drop `dd'
}
local r $M4_RADIUS
forvalues p = 1/3 {
    gen byte e`p' = d`p' <= `r' & doth > `r'
}
gen byte eany = d4 <= `r'
tempfile pts
save `pts'

* gruppo di apertura di un'area: prima tratta con esposizione >= soglia
capture program drop m4groups
program define m4groups
    args unitvar t1 t2 t3
    collapse (mean) e1 e2 e3 eany (count) npts = pid, by(`unitvar')
    gen double cohort = .
    replace cohort = `t3' if e3 >= $M4_TREAT
    replace cohort = `t2' if e2 >= $M4_TREAT
    replace cohort = `t1' if e1 >= $M4_TREAT
    replace cohort = 0 if eany == 0
    label variable cohort "Primo periodo dopo l'apertura (0 = mai esposta; . = esclusa)"
end

use `pts', clear
keep if zona != ""
m4groups zona 2023 2023.5 2025
tempfile zgroups
save `zgroups'

use `pts', clear
keep if !missing(nil)
m4groups nil 2023 2024 2025
tempfile ngroups
save `ngroups'

*------------------------------------------------------------------------------*
* 2. Pannello zona x semestre e controlli abbinati
*------------------------------------------------------------------------------*
* composizione dei residenti nel 2014 portata sulle zone (pesi di superficie)
use "$WORK/ds205_nil_year.dta", clear
keep if year == 2014
keep nil sh_foreign sh_a65 sh_fam1
tempfile comp14
save `comp14'
use `pts', clear
keep if zona != "" & !missing(nil)
merge m:1 nil using `comp14', keep(match) nogen
collapse (mean) sh_foreign sh_a65 sh_fam1, by(zona)
tempfile zcomp
save `zcomp'

use "$WORK/omi_zone21_sem.dta", clear
gen double t = year + (sem - 1)/2
keep if inrange(t, 2014.5, 2025.5)     // la zonizzazione 2021 vale dal 2014S2
gen int tid = round(2*t)
gen double lnR = ln(R)
gen double lnP = ln(P)
bysort zona: egen int nR = count(lnR)
quietly summarize nR
keep if nR == r(max)            // zone con affitto in tutti i semestri
drop nR
merge m:1 zona using `zgroups', keep(match) nogen
merge m:1 zona using `zcomp', keep(master match) nogen
encode zona, gen(zid)

* covariate pre-metro per l'abbinamento
bysort zona: egen double x_lnR = mean(cond(t <= 2016.5, lnR, .))
bysort zona: egen double x_lnP = mean(cond(t <= 2016.5, lnP, .))
bysort zona: egen double lnR14 = max(cond(abs(t - 2014.5) < 1e-6, lnR, .))
bysort zona: egen double lnR19 = max(cond(abs(t - 2019.5) < 1e-6, lnR, .))
gen double x_dlnR = lnR19 - lnR14
drop lnR14 lnR19

preserve
bysort zona: keep if _n == 1
keep zona cohort x_lnR x_lnP x_dlnR sh_foreign sh_a65 sh_fam1
foreach v in x_lnR x_lnP x_dlnR sh_foreign sh_a65 sh_fam1 {
    quietly summarize `v'
    gen double z_`v' = (`v' - r(mean))/r(sd)
}
tempfile zc
save `zc'
* distanza euclidea sulle covariate standardizzate: zone dei gruppi di apertura x mai esposte
keep if cohort > 0 & !missing(cohort)
keep zona z_*
rename (zona z_*) (zt t_*)
tempfile tz
save `tz'
use `zc', clear
keep if cohort == 0
keep zona z_*
cross using `tz'
gen double dist = 0
foreach v in x_lnR x_lnP x_dlnR sh_foreign sh_a65 sh_fam1 {
    replace dist = dist + (z_`v' - t_`v')^2
}
bysort zt (dist): gen int rk = _n
keep if rk <= `NMATCH'
di as txt _n "  Controlli abbinati (3 zone mai esposte piu' simili prima della metro):"
list zt zona dist, noobs sepby(zt)
keep zona
duplicates drop
gen byte matched = 1
tempfile mt
save `mt'
restore
merge m:1 zona using `mt', keep(master match) nogen
replace matched = 0 if missing(matched)

gen byte s_all = !missing(cohort)                         // gruppi + tutte le mai esposte
gen byte s_match = cohort > 0 & !missing(cohort) | matched   // gruppi + mai esposte abbinate
gen byte s_nyt = cohort > 0 & !missing(cohort)            // solo zone M4: le tratte successive fanno da controllo

* elenco dei gruppi
preserve
bysort zona: keep if _n == 1
merge 1:1 zona using "$WORK/omi_zone_dict.dta", keep(master match) nogen keepusing(zona_descr)
gen str24 ruolo = cond(missing(cohort), "esclusa", cond(cohort == 0, cond(matched, "mai esposta (abbinata)", "mai esposta"), ///
    "apertura " + string(cohort, "%6.1f")))
sort cohort zona
list zona ruolo e1 e2 e3 eany x_dlnR zona_descr, noobs sep(0) abbrev(12)
export delimited zona ruolo cohort e1 e2 e3 eany matched x_lnR x_dlnR x_lnP sh_foreign sh_a65 sh_fam1 zona_descr ///
    using "$TAB/m4_groups.csv", replace
restore

*------------------------------------------------------------------------------*
* 3. Stime per zona (semestri)
*------------------------------------------------------------------------------*
set seed $SEED
di as txt _n "  {ul:Zone OMI, semestri 2014-2025}"

* (0) per confronto: modello classico a effetti fissi (distorto con aperture scaglionate)
gen byte D = cohort > 0 & !missing(cohort) & t >= cohort - 1e-6
quietly regress lnR D i.zid i.tid if s_all, vce(cluster zid)
di as txt "  (0) TWFE classico, ln affitto: " as res %8.4f _b[D] as txt "  (p cluster = " ///
    %5.3f 2*ttail(e(df_r), abs(_b[D]/_se[D])) ")"
frame post m4cs ("(0) TWFE classico, tutte le mai esposte (solo confronto)") ("lnR") (_b[D]) (.) (.) (.) (.) (.)

m4run lnR, unit(zid) time(t) cohort(cohort) sample(s_match) step(0.5) tmax(2025.5) ///
    spec("(1) PRINCIPALE: controlli abbinati + non ancora trattate") perms($M4_PERMS) esframe(es_rent)
m4run lnR, unit(zid) time(t) cohort(cohort) sample(s_all) step(0.5) tmax(2025.5) ///
    spec("(2) tutte le zone mai esposte + non ancora trattate") perms($M4_PERMS)
m4run lnR, unit(zid) time(t) cohort(cohort) sample(s_nyt) step(0.5) tmax(2024.5) ///
    spec("(3) solo non ancora trattate (zone delle tratte successive)") perms($M4_PERMS)
m4run lnP, unit(zid) time(t) cohort(cohort) sample(s_match) step(0.5) tmax(2025.5) ///
    spec("(4) prezzi di compravendita, controlli abbinati") perms($M4_PERMS) esframe(es_price)

*------------------------------------------------------------------------------*
* 4. Stime per NIL (anni): altre dinamiche di gentrificazione
*------------------------------------------------------------------------------*
* Esiti per NIL: cancellazioni e iscrizioni (DS205/DS1600/DS1596, 2012-2024) e,
* dal modulo 03c (ds27, ds1440), composizione e migrazione netta per eta' per
* coorte (2008-2024), che comprende anche i traslochi dentro Milano.
* Controlli: (5) tutti i NIL mai esposti + non ancora trattati;
*            (6) per ogni NIL trattato i 3 NIL mai esposti piu' simili nella
*                composizione del 2014 (variabili della tipologia, modulo 20).
di as txt _n "  {ul:NIL, anni 2008-2024: dinamiche dei residenti}"
capture confirm file "$WORK/nil_composition_year.dta"
local has27 = _rc == 0
if `has27' {
    use "$WORK/nil_composition_year.dta", clear
    merge 1:1 nil year using "$WORK/ds205_nil_year.dta", keepusing(r_ac isc_ac isc_es pop_lag) keep(master match) nogen
    gen double pop = pop27
}
else {
    use "$WORK/ds205_nil_year.dta", clear
}
keep if inrange(year, 2008, 2024)
bysort nil: egen double pop19 = max(cond(year == 2019, pop, .))
drop if pop19 < $SMALL_NIL
gen double r_in = 1000*(isc_ac + isc_es)/pop_lag
gen double lnpop = ln(pop)
label variable r_in "Ingressi da altri comuni e dall'estero per 1.000 residenti t-1"
merge m:1 nil using `ngroups', keep(match) nogen
gen byte s_nil = !missing(cohort)

* controlli abbinati sulla composizione 2014
gen byte matchedn = 0
capture confirm file "$WORK/nil_typology.dta"
if _rc == 0 {
    preserve
    bysort nil: keep if _n == 1
    keep nil cohort
    merge 1:1 nil using "$WORK/nil_typology.dta", keep(match) nogen keepusing(type z_*)
    tempfile nz
    save `nz'
    keep if cohort > 0 & !missing(cohort)
    keep nil type z_*
    rename (nil type z_*) (nt typet t_*)
    tempfile nt
    save `nt'
    use `nz', clear
    keep if cohort == 0
    keep nil type z_*
    cross using `nt'
    gen double dist = 0
    foreach v of varlist z_* {
        local s = substr("`v'", 3, .)
        replace dist = dist + (`v' - t_`s')^2
    }
    bysort nt (dist): gen int rk = _n
    keep if rk <= `NMATCH'
    di as txt _n "  NIL trattati o non ancora trattati e i 3 NIL mai esposti piu' simili (composizione 2014):"
    list nt typet nil type dist, noobs sepby(nt)
    keep nil
    duplicates drop
    gen byte mflag = 1
    tempfile nm
    save `nm'
    restore
    merge m:1 nil using `nm', keep(master match) nogen
    replace matchedn = 1 if mflag == 1
    drop mflag
}
gen byte s_nilm = (cohort > 0 & !missing(cohort)) | matchedn

preserve
bysort nil: keep if _n == 1
gen str24 ruolo = cond(missing(cohort), "escluso", cond(cohort == 0, cond(matchedn, "mai esposto (abbinato)", "mai esposto"), ///
    "apertura " + string(cohort)))
tab ruolo
restore
gen double t = year
local NP = max(199, floor($M4_PERMS/2))
local NILY "r_ac r_in lnpop"
if `has27' local NILY "r_ac r_in nm_c2029 nm_c3039 nm_c0009 sh_g2539 sh_hi sh_for27 sh_head35 lnpop"
foreach v of local NILY {
    m4run `v', unit(nil) time(t) cohort(cohort) sample(s_nil) step(1) tmax(2024) prewin(8) ///
        spec("(5) NIL: mai esposti + non ancora trattati") perms(`NP') esframe(es_`v')
    m4run `v', unit(nil) time(t) cohort(cohort) sample(s_nilm) step(1) tmax(2024) prewin(8) ///
        spec("(6) NIL: abbinati per composizione + non ancora trattati") perms(`NP')
}

frame m4cs: export delimited using "$TAB/m4_cs_results.csv", replace

*------------------------------------------------------------------------------*
* 5. Event study (zone, semestri) e grafici
*------------------------------------------------------------------------------*
foreach o in rent price {
    frame es_`o' {
        gen double e = round((t - g)/0.5)       // semestri dall'apertura (0 = primo semestre trattato)
        collapse (mean) att [aw = nT], by(e)
        keep if inrange(e, -12, 5)
        gen str8 outcome = "`o'"
        tempfile e_`o'
        save `e_`o''
    }
}
preserve
use `e_rent', clear
append using `e_price'
export delimited using "$TAB/m4_cs_event.csv", replace
foreach o in rent price {
    local lab = cond("`o'" == "rent", "ln affitto", "ln prezzo")
    twoway (connected att e if outcome == "`o'", lcolor("37 106 191") mcolor("37 106 191") msize(small)), ///
        yline(0, lcolor(gs8)) xline(-0.5, lcolor("230 100 50") lpattern(dash)) ///
        xlabel(-12(2)5) xtitle("Semestri dall'apertura della propria tratta") ///
        ytitle("Differenza trattate - controlli, `lab'") ///
        title("M4: `lab', zone servite vs controlli abbinati e non ancora trattate", size(medsmall)) ///
        legend(off) graphregion(color(white)) ///
        note("Callaway e Sant'Anna, base = semestre prima dell'apertura (-1). Media pesata dei gruppi di apertura.", size(vsmall))
    graph export "$FIG/m4_cs_event_`o'.png", replace width(2400)
}
restore
