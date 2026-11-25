*==============================================================================*
* m4_programs.do
* Programmi del diff-in-diff sulla M4, usati dai moduli 19 e 19b:
*   csatt    ATT di Callaway e Sant'Anna con periodo base universale
*   m4_perm  (Mata) permutazione dei gruppi di apertura tra le aree
*   m4run    stima + test di permutazione, una riga nel frame m4cs
*   m4groups gruppo di apertura di un'area dalla sua esposizione alle tratte
*==============================================================================*
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

* gruppo di apertura di un'area: prima tratta con esposizione >= soglia
capture program drop m4groups
program define m4groups
    args unitvar t1 t2 t3
    collapse (mean) e1 e2 e3 eany enew (count) npts = pid, by(`unitvar')
    gen double cohort = .
    replace cohort = `t3' if e3 >= $M4_TREAT
    replace cohort = `t2' if e2 >= $M4_TREAT
    replace cohort = `t1' if e1 >= $M4_TREAT
    replace cohort = 0 if eany == 0
    label variable cohort "Primo periodo dopo l'apertura (0 = mai esposta; . = esclusa)"
end
