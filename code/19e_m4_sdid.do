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
* Confronto alla pari con Callaway e Sant'Anna (C&S). Sullo stesso campione
* bilanciato e con lo stesso orizzonte del synthetic DiD si stimano anche:
*   C&S con controlli solo mai esposti (come sdid, che non usa i non ancora
*   trattati) e C&S con anche i non ancora trattati. L'aggregazione e' la
*   stessa: C&S pesa ogni ATT(g,t) per il numero di aree del gruppo, sdid pesa
*   l'ATT di ogni gruppo per aree x periodi dopo l'apertura, quindi i pesi dei
*   gruppi coincidono. Cambia solo il riferimento prima dell'apertura: C&S usa
*   il periodo g-1; il DiD classico la media di tutti i periodi prima; sdid
*   una media pesata (pesi lambda) e controlli pesati (pesi omega).
* Andamento prima dell'apertura, misurato allo stesso modo per tutti i metodi:
*   pre = media, sui periodi da g-8 a g-2, di [(Ytr - Yco)_t - (Ytr - Yco)_(g-1)],
*   dove Yco e' il controllo del metodo (media semplice per DiD e C&S, sintetico
*   per sdid e sc), pesata per numero di trattate del gruppo. E' lo stesso
*   placebo riportato da C&S (colonna pre).
* IC95 di sdid: ATT +/- 1,96 x errore standard placebo.
*
* Input:  $WORK/m4_zone_panel.dta, m4_nil_panel.dta (e _r800)
* Output: $TAB/m4_sdid_results.csv, m4_sdid_cs_compare.csv, m4_sdid_weights.csv;
*         $FIG/m4_sdid_rent*.png
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
if "$M4_PERMS" == "" global M4_PERMS 999
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
do "$CODE/m4_programs.do"     // m4run (con opzione never), m4cs_init, m4tlab
m4cs_init

capture frame drop sd
frame create sd str60 campione str10 outcome str6 metodo double att double se double p ///
    double ci_lo double ci_hi double pre long nT long nC long nT_post double neff double wmax ///
    str60 metodo_inf str20 periodi
capture frame drop sdw
frame create sdw str60 campione str10 outcome str6 tipo str8 gruppo str12 id double peso

* etichetta di un periodo dall'indice: tid = 2 x (anno + (sem-1)/2) per le zone, anno per i NIL
capture program drop sdlab
program define sdlab, rclass
    args v semestri
    if `semestri' return local s = string(floor(`v'/2)) + "S" + string(`v' - 2*floor(`v'/2) + 1)
    else return local s = string(`v')
end

capture program drop sdrun
program define sdrun
    syntax varname, Unit(varname) Time(varname) Treat(varname) Campione(string) Reps(integer) ///
        Semestri(integer) [GRaph(string) Labelvar(varname)]
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
        * primo periodo trattato di ogni area (per il numero di trattate per gruppo)
        bysort `unit': egen double __a = min(cond(`treat', `time', .))
        summarize `time', meanonly
        local tmn = r(min)
        local tmx = r(max)
    }
    sdlab `tmn' `semestri'
    local per `r(s)'
    sdlab `tmx' `semestri'
    local per "`per'-`r(s)'"
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
        * andamento prima dell'apertura dalla traiettoria trattate - controllo del metodo
        capture matrix __S = e(series)
        if _rc matrix __S = J(1, 2*rowsof(e(adoption)) + 1, .)
        matrix __A = e(adoption)
        matrix __O = e(omega)
        matrix __L = e(lambda)
        local num 0
        local den 0
        local ne 0
        local wm 0
        forvalues k = 1/`=rowsof(__A)' {
            local a = __A[`k', 1]
            quietly count if __f & abs(__a - `a') < 1e-6
            local ng = r(N)
            * colonne di e(series): tid, poi Yco e Ytr per ogni gruppo
            local cco = 2*`k'
            local ctr = 2*`k' + 1
            local db .
            forvalues r = 1/`=rowsof(__S)' {
                if abs(__S[`r', 1] - (`a' - 1)) < 1e-6 local db = __S[`r', `ctr'] - __S[`r', `cco']
            }
            local s 0
            local c 0
            forvalues r = 1/`=rowsof(__S)' {
                local tt = __S[`r', 1]
                if `tt' >= `a' - 8 - 1e-6 & `tt' <= `a' - 2 + 1e-6 {
                    local s = `s' + (__S[`r', `ctr'] - __S[`r', `cco']) - `db'
                    local ++c
                }
            }
            if `c' > 0 & !missing(`db') {
                local num = `num' + `ng'*`s'/`c'
                local den = `den' + `ng'
            }
            * pesi delle unita' del gruppo k: numero effettivo di controlli e peso massimo
            local s2 0
            local mx 0
            * l'ultima riga di e(omega) ed e(lambda) contiene le date di apertura, non pesi
            forvalues r = 1/`=rowsof(__O) - 1' {
                local w = __O[`r', `k']
                if missing(`w') continue
                local s2 = `s2' + `w'^2
                local mx = max(`mx', `w')
                if "`m'" == "sdid" & `w' > 0.001 {
                    local idv = __O[`r', colsof(__O)]
                    local idl = "`idv'"
                    if "`labelvar'" != "" {
                        quietly levelsof `labelvar' if `unit' == `idv', local(idl) clean
                    }
                    sdlab `a' `semestri'
                    frame post sdw ("`campione'") ("`y'") ("unita'") ("`r(s)'") ("`idl'") (`w')
                }
            }
            local ne = `ne' + (`s2' > 0)/max(`s2', 1e-12)/rowsof(__A)
            local wm = max(`wm', `mx')
            if "`m'" == "sdid" {
                forvalues r = 1/`=rowsof(__L) - 1' {
                    local w = __L[`r', `k']
                    if `w' > 0.001 & !missing(`w') {
                        sdlab `=__L[`r', colsof(__L)]' `semestri'
                        local tl `r(s)'
                        sdlab `a' `semestri'
                        frame post sdw ("`campione'") ("`y'") ("periodo") ("`r(s)'") ("`tl'") (`w')
                    }
                }
            }
        }
        local pre = cond(`den' > 0, `num'/`den', .)
        if "`m'" == "did" local wm = .
        if "`m'" == "did" local ne = .
        frame post sd ("`campione'") ("`y'") ("`m'") (`att') (`se') (`p') (`att' - 1.96*`se') (`att' + 1.96*`se') ///
            (`pre') (`nT') (`nC') (`nTp') (`ne') (`wm') ("errore standard placebo (`reps' repliche)") ("`per'")
        di as txt "  -> `campione' [`y'] " as res "`m'" as txt ": effetto " as res %8.4f `att' ///
            as txt " [IC95 " %7.4f `att' - 1.96*`se' ", " %7.4f `att' + 1.96*`se' "]  p " %5.3f `p' ///
            "  pre " %7.4f `pre' "   trattate `nT', controlli `nC', periodi `per'"
    }
    drop __tr __f __a
end

set seed $SEED
local NP = max(199, floor($M4_PERMS/2))

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
        sdrun `y', unit(zid) time(tid) treat(D) campione("`lab'") reps(`REPS') graph(`g') ///
            semestri(1) labelvar(zona)
        * C&S sullo stesso campione e orizzonte
        gen byte s_sd = 1
        quietly summarize t
        local tm = r(max)
        m4run `y', unit(zid) time(t) cohort(cohort) sample(s_sd) step(0.5) tmax(`tm') ///
            spec("`lab': C&S, controlli solo mai esposti (campione sdid)") perms($M4_PERMS) never
        m4run `y', unit(zid) time(t) cohort(cohort) sample(s_sd) step(0.5) tmax(`tm') ///
            spec("`lab': C&S, mai esposti + non ancora trattati (campione sdid)") perms($M4_PERMS)
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
    sdrun r_ac, unit(nil) time(year) treat(D) campione("`lab'") reps(`REPS') semestri(0)
    gen byte s_sd = 1
    m4run r_ac, unit(nil) time(t) cohort(cohort) sample(s_sd) step(1) tmax(2024) prewin(8) ///
        spec("`lab': C&S, controlli solo mai esposti (campione sdid)") perms(`NP') never
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
    format att se ci_lo ci_hi pre %8.4f
    format p neff wmax %5.3f
    format att_pct %6.1f
    list campione outcome metodo att ci_lo ci_hi p pre nT nC neff wmax, noobs sepby(campione outcome) abbrev(10)
    export delimited using "$TAB/m4_sdid_results.csv", replace
}
frame m4cs {
    format att ci_lo ci_hi pre %8.4f
    list spec outcome att ci_lo ci_hi p_perm pre p_perm_pre nT nC, noobs sep(0) abbrev(10)
    export delimited using "$TAB/m4_sdid_cs_compare.csv", replace
}
frame sdw {
    format peso %6.3f
    gsort campione outcome tipo gruppo -peso
    export delimited using "$TAB/m4_sdid_weights.csv", replace
}
