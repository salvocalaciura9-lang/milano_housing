*==============================================================================*
* 19e_m4_sdid.do
* M4: synthetic difference-in-differences (Arkhangelsky, Athey, Hirshberg,
* Imbens e Wager, 2021, American Economic Review)
*
* Perche'. Nel disegno ad esposizione continua (modulo 19d) gli affitti delle
* zone piu' servite stavano gia' scendendo rispetto ai controlli prima
* dell'apertura: i trend paralleli non reggono del tutto. Il synthetic DiD
* sceglie pesi per le aree di controllo (e per i periodi prima dell'apertura) in
* modo che il controllo "sintetico" segua lo stesso andamento delle aree M4 prima
* dell'apertura; poi confronta le variazioni dopo l'apertura.
*   - pesi delle unita': il controllo pesato riproduce la traiettoria media delle
*     trattate negli anni prima (con una penalita' che evita di concentrare il
*     peso su pochissime aree);
*   - pesi dei periodi: danno piu' peso ai periodi prima dell'apertura piu'
*     simili a quelli dopo;
*   - aperture scaglionate: una stima per gruppo di apertura, poi la media pesata
*     (comando sdid, Pailanir, Clarke e Ciccia; Clarke et al., Stata Journal).
* Inferenza: metodo placebo (le aree di controllo vengono trattate a turno come
*   finte trattate), adatto quando le trattate sono poche.
* Confronto nella stessa tabella: DiD classico e controllo sintetico (stessi dati).
*
* Campioni (trattamento binario del modulo 19, raggio $M4_RADIUS m):
*   zone OMI: trattate + tutte le mai esposte (i pesi li sceglie il metodo);
*   NIL: trattati con anni dopo l'apertura (aperture 2023 e 2024) + mai esposti,
*        anni con le uscite disponibili; i NIL della tratta 3 sono esclusi.
* Robustezza: stesse stime con il raggio di 800 m (pannelli _r800 del modulo 19b).
*
* Input:  $WORK/m4_zone_panel.dta, m4_nil_panel.dta (e _r800)
* Output: $TAB/m4_sdid_results.csv; $FIG/m4_sdid_rent*.png
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "19e - M4: SYNTHETIC DIFFERENCE-IN-DIFFERENCES" _n "{hline 78}"

if "$ROOT" == "" global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"
foreach g in RAW:data/raw WORK:data/work TAB:output/tables FIG:output/figures CODE:code {
    gettoken k p : g, parse(":")
    local p = subinstr("`p'", ":", "", 1)
    if "${`k'}" == "" global `k' "$ROOT/`p'"
}
if "$SEED" == "" global SEED 20261119
capture which sdid
if _rc {
    capture ssc install sdid
    capture which sdid
    if _rc {
        di as error "  comando sdid non disponibile (ssc install sdid): 19e saltato"
        exit
    }
}
capture confirm file "$WORK/m4_zone_panel.dta"
if _rc {
    di as error "  manca m4_zone_panel.dta (modulo 19): 19e saltato"
    exit
}
local REPS 500

capture frame drop sd
frame create sd str60 campione str10 outcome str6 metodo double att double se double p ///
    long nT long nC long nT_post

capture program drop sdrun
program define sdrun
    syntax varname, Unit(varname) Time(varname) Treat(varname) Campione(string) Reps(integer) ///
        [GRaph(string)]
    local y `varlist'
    quietly {
        bysort `unit': egen byte __tr = max(`treat')
        bysort `unit' (`time'): gen byte __f = _n == 1
        count if __f & __tr
        local nT = r(N)
        count if __f & !__tr
        local nC = r(N)
        count if `treat'
        local nTp = r(N)
        drop __tr __f
    }
    foreach m in sdid did sc {
        local gopt
        if "`m'" == "sdid" & "`graph'" != "" local gopt graph g1on graph_export("`graph'", .png)
        capture noisily sdid `y' `unit' `time' `treat', vce(placebo) reps(`reps') seed($SEED) ///
            method(`m') `gopt'
        if _rc {
            di as error "  sdid `m' non riuscito per `y' (`campione'): rc " _rc
            continue
        }
        local att = e(ATT)
        local se = e(se)
        local p = 2*normal(-abs(`att'/`se'))
        frame post sd ("`campione'") ("`y'") ("`m'") (`att') (`se') (`p') (`nT') (`nC') (`nTp')
        di as txt "  -> `campione' [`y'] " as res "`m'" as txt ": effetto " as res %8.4f `att' ///
            as txt "  se " %7.4f `se' "  p " %5.3f `p' "   trattate `nT', controlli `nC'"
    }
end

*--- Zone OMI: affitti e prezzi --------------------------------------------------*
foreach tag in "" "_r800" {
    capture confirm file "$WORK/m4_zone_panel`tag'.dta"
    if _rc continue
    local lab = cond("`tag'" == "", "zone, 500 m", "zone, 800 m")
    foreach y in lnR lnP {
        use "$WORK/m4_zone_panel`tag'.dta", clear
        keep if cohort == 0 | (cohort > 0 & !missing(cohort))
        * pannello bilanciato sull'esito
        bysort zid: egen int __n = count(`y')
        quietly summarize tid
        keep if __n == r(max) - r(min) + 1
        drop __n
        gen byte D = cohort > 0 & t >= cohort - 1e-6
        local g
        if "`y'" == "lnR" & "`tag'" == "" local g "$FIG/m4_sdid_rent"
        sdrun `y', unit(zid) time(tid) treat(D) campione("`lab'") reps(`REPS') graph(`g')
    }
}

*--- NIL: uscite verso altri comuni ----------------------------------------------*
foreach tag in "" "_r800" {
    capture confirm file "$WORK/m4_nil_panel`tag'.dta"
    if _rc continue
    local lab = cond("`tag'" == "", "NIL, 500 m", "NIL, 800 m")
    use "$WORK/m4_nil_panel`tag'.dta", clear
    keep if cohort == 0 | inlist(cohort, 2023, 2024)
    keep if !missing(r_ac)
    bysort nil: egen int __n = count(r_ac)
    quietly summarize year
    keep if __n == r(max) - r(min) + 1
    drop __n
    gen byte D = inlist(cohort, 2023, 2024) & year >= cohort
    sdrun r_ac, unit(nil) time(year) treat(D) campione("`lab'") reps(`REPS')
}

* grafici di sdid: nomi leggibili (4046 = 2023S1, tratta 1; 4050 = 2025S1, tratta 3)
foreach p in "4046 tratta1" "4050 tratta3" {
    tokenize `p'
    foreach k in trends weights {
        capture copy "$FIG/m4_sdid_rent`k'`1'.png" "$FIG/m4_sdid_rent_`k'_`2'.png", replace
        capture erase "$FIG/m4_sdid_rent`k'`1'.png"
    }
}

frame sd {
    gen double att_pct = 100*(exp(att) - 1) if inlist(outcome, "lnR", "lnP")
    format att se %8.4f
    format p %5.3f
    format att_pct %6.1f
    list, noobs sepby(campione outcome) abbrev(10)
    export delimited using "$TAB/m4_sdid_results.csv", replace
}
