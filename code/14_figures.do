*==============================================================================*
* 14_figures.do
* Figure consigliate dalla proposta:
*  1. stime e intervalli di confidenza (modello NIL e pannello)
*  2. uscite 2022-24 e upgrading sociale (dispersione)
*  3. tasso di uscita cittadino 2012-2024
*  4. variazione delle quotazioni per zona OMI
*  5. benchmark reddituale corrente e iniziale (contesto cittadino e CAP)
*  6. contribuenti nelle fasce basse: numero e quota (due pannelli, un asse ciascuno)
*  7. variazione dell'affordability per CAP e upgrading sociale
*  8. mappe NIL (upgrading, indice comune, uscite) e mappa CAP dell'affordability
* Ogni figura e' in un blocco separato: se mancano i dati viene saltata.
*==============================================================================*
version 16
di as txt _n "{hline 78}" _n "14 - FIGURE E MAPPE" _n "{hline 78}"

* palette (blu, arancio, verde acqua) e rampa sequenziale blu per le mappe
global C1 "42 120 214"
global C2 "235 104 52"
global C3 "27 175 122"
global SEQ5 `""205 226 251" "134 182 239" "57 135 229" "37 106 191" "16 66 129""'
local base graphregion(color(white)) plotregion(color(white))

*------------------------------------------------------------------------------*
* 1. Grafici delle stime
*------------------------------------------------------------------------------*
capture program drop coefplot_res
program define coefplot_res
    syntax , Keep(string) File(string) Title(string) Xtitle(string)
    use "$WORK/results.dta", clear
    keep if `keep'
    if _N == 0 {
        di as txt "  (nessuna stima per `file')"
        exit
    }
    gen int ord = _n
    forvalues i = 1/`=_N' {
        local l = spec[`i']
        label define ordl `i' `"`l'"', add
    }
    label values ord ordl
    local n = _N
    twoway (rcap lb ub ord, horizontal lcolor("$C1") lwidth(medthick)) ///
           (scatter ord b, mcolor("$C1") msymbol(circle) msize(medium)), ///
        xline(0, lcolor(gs9) lpattern(dash)) ///
        ylabel(1(1)`n', valuelabel angle(0) labsize(vsmall) nogrid) yscale(reverse) ///
        xlabel(, grid glcolor(gs15) labsize(small)) ytitle("") xtitle("`xtitle'", size(small)) ///
        legend(off) title("`title'", size(medsmall)) ///
        graphregion(color(white)) plotregion(color(white)) xsize(8) ysize(5)
    graph export "$FIG/`file'.png", replace width(2400)
end

capture noisily coefplot_res, ///
    keep(ustrregexm(model, "^M1") & coef == "G_social" & cmd == "regress") ///
    file("fig1a_coef_nil") title("Upgrading sociale 2011-21 e uscite 2022-24 (IC 95%)") ///
    xtitle("Uscite annue per 1.000 residenti per unita' di G_social")
capture noisily coefplot_res, ///
    keep(ustrregexm(model, "^M3 ") & coef == "lnAR" & cmd == "regress") ///
    file("fig1b_coef_panel") title("Pressione abitativa (t) e uscite (t+1), effetti fissi (IC 95%)") ///
    xtitle("Uscite per 1.000 residenti per unita' di log affordability")

*------------------------------------------------------------------------------*
* 2. Uscite e upgrading sociale
*------------------------------------------------------------------------------*
capture confirm file "$WORK/nil_analysis.dta"
if !_rc {
    capture noisily {
        use "$WORK/nil_analysis.dta", clear
        keep if s_main == 1
        twoway (scatter r_post G_social, mcolor("$C1%70") msymbol(circle) msize(small)) ///
               (lfit r_post G_social, lcolor("$C2") lwidth(medthick)), ///
            xtitle("Upgrading sociale 2011-21 (G_social)") ///
            ytitle("Uscite per 1.000 residenti, media 2022-24") ///
            ylabel(, angle(0) glcolor(gs15)) xlabel(, grid glcolor(gs15)) ///
            legend(order(1 "NIL" 2 "Retta OLS bivariata") position(6) rows(1) size(small)) ///
            title("Upgrading e uscite successive per NIL", size(medsmall)) `base'
        graph export "$FIG/fig2_scatter_nil.png", replace width(2400)
    }
}

*------------------------------------------------------------------------------*
* 3. Tasso di uscita cittadino
*------------------------------------------------------------------------------*
capture noisily {
    use "$WORK/outmig_city.dta", clear
    keep if !missing(r_emig_city)
    twoway (connected r_emig_city year, lcolor("$C1") mcolor("$C1") lwidth(medthick) msize(small)), ///
        xlabel(2012(2)2024, grid glcolor(gs15)) ylabel(, angle(0) glcolor(gs15)) ///
        xtitle("") ytitle("Uscite per 1.000 residenti dell'anno precedente") ///
        title("Uscite anagrafiche da Milano, somma dei NIL", size(medsmall)) legend(off) `base'
    graph export "$FIG/fig3_outmig_city.png", replace width(2400)
}

*------------------------------------------------------------------------------*
* 4. Variazione delle quotazioni per zona OMI
*------------------------------------------------------------------------------*
capture noisily {
    use "$WORK/omi_zone_change.dta", clear
    histogram dlnR, frequency bin(12) fcolor("$C1") lcolor(white) ///
        xtitle("Variazione log locazione $Y0-$Y1") ytitle("Zone OMI") ///
        ylabel(, angle(0) glcolor(gs15)) title("Locazioni", size(medsmall)) ///
        name(gR, replace) nodraw `base'
    histogram dlnP, frequency bin(12) fcolor("$C1") lcolor(white) ///
        xtitle("Variazione log compravendita $Y0-$Y1") ytitle("Zone OMI") ///
        ylabel(, angle(0) glcolor(gs15)) title("Compravendite", size(medsmall)) ///
        name(gP, replace) nodraw `base'
    graph combine gR gP, rows(1) graphregion(color(white)) ///
        title("Abitazioni civili, stato NORMALE, punto medio OMI", size(medsmall))
    graph export "$FIG/fig4_omi_change.png", replace width(2400)
}

*------------------------------------------------------------------------------*
* 5. Benchmark reddituale corrente e iniziale (contesto cittadino)
*------------------------------------------------------------------------------*
capture noisily {
    use "$WORK/city_context.dta", clear
    capture confirm variable AR_city_base
    if _rc == 0 {
        twoway (connected AR_city year, lcolor("$C1") mcolor("$C1") lwidth(medthick)) ///
               (connected AR_city_base year, lcolor("$C2") mcolor("$C2") lwidth(medthick) msymbol(square)), ///
            xlabel($Y0A(1)$Y1, grid glcolor(gs15)) ylabel(, angle(0) glcolor(gs15)) ///
            xtitle("") ytitle("Affitto annuo di $S_MAIN m2 / reddito fiscale") ///
            legend(order(1 "Reddito medio corrente" 2 "Reddito $Y0A rivalutato col CPI") ///
                position(6) rows(1) size(small)) ///
            title("Contesto cittadino: mediana delle zone e media fiscale (non misura locale)", size(medsmall)) ///
            `base'
        graph export "$FIG/fig5_city_benchmark.png", replace width(2400)
    }
}

*------------------------------------------------------------------------------*
* 6. Contribuenti fino a 15.000 euro: numero e quota
*------------------------------------------------------------------------------*
capture noisily {
    use "$WORK/irpef_city_year.dta", clear
    gen double nlow15_k = nlow15/1000
    twoway (connected nlow15_k year, lcolor("$C1") mcolor("$C1") lwidth(medthick)), ///
        ytitle("Migliaia di contribuenti") xtitle("") xlabel(, grid glcolor(gs15)) ///
        ylabel(, angle(0) glcolor(gs15)) title("Numero", size(medsmall)) legend(off) ///
        name(gN, replace) nodraw `base'
    twoway (connected sh15_city year, lcolor("$C1") mcolor("$C1") lwidth(medthick)), ///
        ytitle("% su Numero contribuenti") xtitle("") xlabel(, grid glcolor(gs15)) ///
        ylabel(, angle(0) glcolor(gs15)) title("Quota", size(medsmall)) legend(off) ///
        name(gS, replace) nodraw `base'
    graph combine gN gS, rows(1) graphregion(color(white)) ///
        title("Contribuenti con reddito complessivo >0 e <=15.000 euro (soglie nominali)", size(medsmall))
    graph export "$FIG/fig6_low_income.png", replace width(2400)
}

*------------------------------------------------------------------------------*
* 7. CAP: variazione dell'affordability, benchmark e upgrading
*------------------------------------------------------------------------------*
capture confirm file "$WORK/cap_cross_main.dta"
if !_rc {
    capture noisily {
        use "$WORK/cap_cross_main.dta", clear
        keep if cover_ok == 1
        quietly summarize AR
        local lo = r(min)
        local hi = r(max)
        quietly summarize AR_base
        local lo = min(`lo', r(min))
        local hi = max(`hi', r(max))
        twoway (function y = x, range(`lo' `hi') lcolor(gs10) lpattern(dash)) ///
               (scatter AR_base AR, mcolor("$C1%80") msize(small)), ///
            xtitle("Con reddito medio corrente ($Y1)") ytitle("Con reddito $Y0A rivalutato ($Y1)") ///
            ylabel(, angle(0) glcolor(gs15)) xlabel(, grid glcolor(gs15)) ///
            legend(order(1 "Uguaglianza" 2 "CAP") position(6) rows(1) size(small)) ///
            title("Affitto annuo di $S_MAIN m2 / reddito: due benchmark", size(medsmall)) `base'
        graph export "$FIG/fig7a_cap_benchmarks.png", replace width(2400)

        capture confirm variable G_social_cap
        if _rc == 0 {
            twoway (scatter dlnAR G_social_cap, mcolor("$C1%80") msize(small)) ///
                   (lfit dlnAR G_social_cap, lcolor("$C2") lwidth(medthick)), ///
                xtitle("Upgrading sociale 2011-21, media del CAP") ///
                ytitle("Variazione log affordability affitto $Y0A-$Y1") ///
                ylabel(, angle(0) glcolor(gs15)) xlabel(, grid glcolor(gs15)) ///
                legend(order(1 "CAP" 2 "Retta OLS bivariata") position(6) rows(1) size(small)) ///
                title("Affordability e upgrading per CAP", size(medsmall)) `base'
            graph export "$FIG/fig7b_cap_affordability_upgrading.png", replace width(2400)
        }
    }
}

*------------------------------------------------------------------------------*
* 8. Mappe
*------------------------------------------------------------------------------*
capture which spmap
local havespmap = (_rc == 0)

capture program drop nilmap
program define nilmap
    syntax varname, File(string) Title(string) Legtitle(string)
    capture noisily spmap `varlist' using "$GEO/nil_shape_shp.dta", id(_ID) ///
        clmethod(quantile) clnumber(5) fcolor($SEQ5) ///
        ocolor(white white white white white) osize(vthin vthin vthin vthin vthin) ///
        ndfcolor(gs14) ndocolor(white) ndsize(vthin) ///
        legend(position(7) size(small)) legtitle("`legtitle'") legstyle(2) ///
        title("`title'", size(medsmall))
    if _rc == 0 graph export "$FIG/`file'.png", replace width(2400)
end

if $SHP_OK == 1 & `havespmap' {
    capture noisily {
        use "$GEO/nil_shape.dta", clear
        merge 1:1 nil using "$WORK/outmig_nil.dta", keep(master match) nogen
        capture confirm file "$WORK/gentrif_nilnew.dta"
        if !_rc merge 1:1 nil using "$WORK/gentrif_nilnew.dta", keep(master match) nogen
        nilmap r_post, file("map_nil_r_post") title("Uscite per 1.000 residenti, 2022-24") ///
            legtitle("Quintili")
        nilmap r_change, file("map_nil_r_change") ///
            title("Variazione delle uscite: 2022-24 meno 2017-19") legtitle("Quintili")
        capture confirm variable G_social
        if !_rc {
            nilmap G_social, file("map_nil_G_social") title("Upgrading sociale 2011-21") ///
                legtitle("Quintili")
            nilmap dI_common, file("map_nil_dI_common") ///
                title("Variazione indice a scala comune 2011-21 (punti)") legtitle("Quintili")
        }
    }
}
else {
    di as txt "  (mappe NIL saltate: shapefile o spmap non disponibili)"
}

* mappe e dipendenza spaziale per zona OMI (poligoni creati dal modulo 10a)
capture confirm file "$GEO/omi_zone_shape.dta"
local hasomishp = (_rc == 0)
capture confirm file "$WORK/omi_zone_change.dta"
if _rc local hasomishp 0
if `hasomishp' & `havespmap' {
    preserve
    local here "`c(pwd)'"
    quietly cd "$GEO"
    capture noisily {
        use "omi_zone_shape.dta", clear
        spset, modify coordsys(latlong, kilometers)
        spset, modify shpfile(omi_zone_shape_shp)
        merge 1:1 zona using "$WORK/omi_zone_change.dta", keep(master match) nogen
        foreach v in R P {
            local lab = cond("`v'" == "R", "affitti", "prezzi di compravendita")
            spmap dln`v' using "omi_zone_shape_shp.dta", id(_ID) ///
                clmethod(quantile) clnumber(5) fcolor($SEQ5) ///
                ocolor(white white white white white) osize(vthin vthin vthin vthin vthin) ///
                ndfcolor(gs14) ndocolor(white) ndsize(vthin) ///
                legend(position(7) size(small)) legtitle("Quintili") legstyle(2) ///
                title("Variazione log `lab' OMI, $Y0-$Y1, per zona", size(medsmall)) ///
                note("Abitazioni civili, stato NORMALE, punto medio. Grigio: zona senza quotazioni (es. C13)", size(vsmall))
            graph export "$FIG/map_omi_dln`v'.png", replace width(2400)
        }
        * I di Moran (contiguita', pesi standardizzati per riga), solo descrittivo
        drop if missing(dlnR) | missing(dlnP)
        spmatrix create contiguity Womi, normalize(row) replace
        foreach v in dlnR dlnP {
            quietly regress `v'
            di as txt _n "  I di Moran sulla variazione `v' tra zone OMI (N = " e(N) "):"
            estat moran, errorlag(Womi)
        }
    }
    local rc = _rc
    quietly cd "`here'"
    restore
    if `rc' di as error "  Mappe/test per zona OMI non completati (rc = `rc')"
}
else {
    di as txt "  (mappe per zona OMI saltate: poligoni OMI o spmap non disponibili)"
}

* mappa CAP (richiede poligoni CAP e raccordo)
capture confirm file "$WORK/cap_cross_main.dta"
local hascross = (_rc == 0)
capture confirm file "$GEO/$SHP_CAP.shp"
local hascapshp = (_rc == 0)
if `hascross' & `hascapshp' & `havespmap' {
    capture noisily {
        capture confirm file "$GEO/cap_shape.dta"
        if _rc {
            local here "`c(pwd)'"
            quietly cd "$GEO"
            spshape2dta $SHP_CAP, replace saving(cap_shape)
            quietly cd "`here'"
        }
        use "$GEO/cap_shape.dta", clear
        if "$SHP_CAP_ID" != "" {
            local lc = lower("$SHP_CAP_ID")
            getvar capcode, pattern("^`lc'( |$)")
        }
        else {
            detectcode, regex("^201[0-9][0-9]$")
            rename `r(varname)' capcode
        }
        tonum capcode
        capture drop cap
        rename capcode cap
        merge m:1 cap using "$WORK/cap_cross_main.dta", keep(master match) nogen
        replace dlnAR = . if cover_ok != 1
        spmap dlnAR using "$GEO/cap_shape_shp.dta", id(_ID) ///
            clmethod(quantile) clnumber(5) fcolor($SEQ5) ///
            ocolor(white white white white white) osize(vthin vthin vthin vthin vthin) ///
            ndfcolor(gs14) ndocolor(white) ndsize(vthin) ///
            legend(position(7) size(small)) legtitle("Quintili") legstyle(2) ///
            title("Variazione log affordability affitto $Y0A-$Y1 per CAP", size(medsmall)) ///
            note("Grigio: CAP sotto la soglia di copertura delle zone OMI quotate", size(vsmall))
        graph export "$FIG/map_cap_dlnAR.png", replace width(2400)
    }
}

di as txt "  Figure salvate in $FIG"
