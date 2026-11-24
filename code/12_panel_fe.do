*==============================================================================*
* 12_panel_fe.do
* Pressione abitativa e uscite annue, effetti fissi di CAP e anno:
*   r_j,t+1 = a_j + l_t + b log A_jt + g' X_jt + e_jt
* t = 2019-2023 (esito 2020-2024). Al massimo 38 x 5 = 190 osservazioni.
* Errori raggruppati per CAP + wild cluster bootstrap (pochi cluster).
* Gli effetti fissi non assorbono shock locali variabili, selezione
* residenziale o errori di misura; le uscite sono allocate al CAP (stima).
* Un indice storico costante verrebbe assorbito dagli effetti fissi: non e'
* incluso qui.
*
* Estensioni: Poisson con esposizione (log residenti t come offset, nessun +1
* agli zeri), ritardo di due anni, esclusione degli anni pandemici, controlli
* variabili nel tempo, eterogeneita' per vulnerabilita' iniziale (definita sul
* $Y0A, non su composizione futura), altri raccordi.
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "12 - PANNELLO CON EFFETTI FISSI" _n "{hline 78}"

if $XW_OK == 0 {
    di as error "  12 saltato: raccordo geografico non disponibile"
    exit
}

foreach xv of global XW_VERSIONS {
    di as txt _n "  {ul:Raccordo: `xv'}"
    use "$WORK/cap_panel_`xv'.dta", clear
    egen int capid = group(cap)
    xtset capid year
    gen double r_lead1 = F.r_emig
    gen double r_lead2 = F2.r_emig
    gen double E_lead1 = F.emig_al
    gen double E_lead2 = F2.emig_al
    gen double N_lead1 = F.pop_al
    gen double lnpop_t = ln(pop_al)
    gen double pct65_t = 100*sh_a65
    gen double lnAR_x_vuln = lnAR*vuln
    label variable r_lead1 "Uscite per 1.000 in t+1 (allocate)"
    label variable lnAR    "log affitto annuo standard / reddito medio, anno t"

    gen byte s_fe = inrange(year, $Y0A, $Y1) & !missing(lnAR, r_lead1) & cover_ok == 1
    quietly count if s_fe
    local nobs = r(N)
    quietly levelsof capid if s_fe
    di as txt "  Osservazioni CAP-anno: `nobs'; CAP: " r(r)

    local M3 "M3 panel FE: uscite t+1 su log affordability t"

    * --- principale con wild cluster bootstrap ---
    capture noisily regress r_lead1 lnAR i.year i.capid if s_fe, vce(cluster capid)
    if _rc == 0 {
        local pb  = -999
        local lbb = -999
        local ubb = -999
        capture noisily boottest lnAR, reps($BOOTREPS) weighttype(webb) seed($SEED) nograph
        if _rc == 0 {
            local pb = r(p)
            capture matrix CI = r(CI)
            if _rc == 0 {
                local lbb = CI[1,1]
                local ubb = CI[1,2]
            }
        }
        saveres, model("`M3'") spec("principale [`xv']") coef(lnAR) ///
            pboot(`pb') lbboot(`lbb') ubboot(`ubb') note("p e IC bootstrap: wild cluster, pesi Webb")
    }

    if "`xv'" != "main" continue

    * --- misure alternative di pressione ---
    foreach a in lnAR_min lnAR_max lnAR_lav lnAP lnAR_base {
        local nt ""
        if "`a'" == "lnAR_base" local nt "con effetti fissi di CAP e anno equivale quasi al solo canone"
        capture noisily regress r_lead1 `a' i.year i.capid if s_fe & !missing(`a'), vce(cluster capid)
        if _rc == 0 saveres, model("`M3'") spec("pressione: `a'") coef(`a') note("`nt'")
    }

    * --- ritardo di due anni ---
    capture noisily regress r_lead2 lnAR i.year i.capid ///
        if inrange(year, $Y0A, $Y1) & !missing(lnAR, r_lead2) & cover_ok == 1, vce(cluster capid)
    if _rc == 0 saveres, model("`M3'") spec("esito in t+2") coef(lnAR)

    * --- esclusione degli esiti 2020-2021 ---
    capture noisily regress r_lead1 lnAR i.year i.capid if s_fe & !inlist(year + 1, 2020, 2021), ///
        vce(cluster capid)
    if _rc == 0 saveres, model("`M3'") spec("esclusi esiti pandemici 2020-21") coef(lnAR)

    * --- controlli variabili nel tempo ---
    capture noisily regress r_lead1 lnAR lnpop_t pct65_t i.year i.capid if s_fe, vce(cluster capid)
    if _rc == 0 saveres, model("`M3'") spec("+ log residenti e % 65+ in t") coef(lnAR)

    * --- senza regola di copertura ---
    capture noisily regress r_lead1 lnAR i.year i.capid ///
        if inrange(year, $Y0A, $Y1) & !missing(lnAR, r_lead1), vce(cluster capid)
    if _rc == 0 saveres, model("`M3'") spec("tutti i CAP (senza regola di copertura)") coef(lnAR)

    * --- Poisson con esposizione ---
    capture noisily poisson E_lead1 lnAR i.year i.capid if s_fe, exposure(pop_al) vce(cluster capid)
    if _rc == 0 saveres, model("`M3'") spec("Poisson FE, esposizione residenti t") coef(lnAR) ///
        note("semi-elasticita'; conteggi allocati, quasi-verosimiglianza")

    * --- eterogeneita' per vulnerabilita' iniziale ---
    capture noisily regress r_lead1 lnAR lnAR_x_vuln i.year i.capid if s_fe & !missing(vuln), ///
        vce(cluster capid)
    if _rc == 0 {
        saveres, model("`M3'") spec("eterogeneita': pendenza CAP non vulnerabili") coef(lnAR)
        saveres, model("`M3'") spec("eterogeneita': differenza CAP vulnerabili") coef(lnAR_x_vuln)
    }

    * --- associazione tra pressione e composizione fiscale (triangolazione) ---
    capture noisily regress sh_low15 lnAR i.year i.capid if inrange(year, $Y0A, $Y1) & cover_ok == 1, ///
        vce(cluster capid)
    if _rc == 0 saveres, model("M3b panel FE: composizione") spec("quota contribuenti 0-15.000 su log A") ///
        coef(lnAR) note("composizione fiscale, non uscite di persone povere")

    save "$WORK/cap_panel_`xv'_est.dta", replace
}
