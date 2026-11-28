*==============================================================================*
* m4_programs.do
* Programmi del diff-in-diff sulla M4, usati dai moduli 19 e 19b:
*   csatt    ATT di Callaway e Sant'Anna con periodo base universale
*   m4_perm  (Mata) permutazione dei gruppi di apertura tra le aree
*   m4run    stima + test di permutazione + IC95, una riga nel frame m4cs
*   m4cs_init crea il frame m4cs
*   m4groups gruppo di apertura di un'area dalla sua esposizione alle tratte
*==============================================================================*
* csatt: ATT di Callaway e Sant'Anna con periodo base universale (g - step).
*   Per ogni gruppo g e periodo t:
*   ATT(g,t) = media [Y_t - Y_base] dei trattati g - media [Y_t - Y_base] dei controlli,
*   controlli = aree del campione mai esposte o con apertura dopo max(t, base).
*   r(att) = media degli ATT(g,t) dopo l'apertura (t da g a tmax), pesata per la
*            numerosita' del gruppo;
*   r(pre) = stessa media sugli anni prima (da g - prewin*step a g - 2*step): placebo.
*   r(post) = per ogni gruppo: periodi dopo l'apertura usati (primo-ultimo, numero)
*   opzione never: controlli solo mai esposti (senza i non ancora trattati),
*   per il confronto con il synthetic DiD sullo stesso campione (modulo 19e).
* m4tlab: etichetta di un periodo (2023.5 -> 2023S2 se step 0,5; anno altrimenti)
capture program drop m4tlab
program define m4tlab, rclass
    args t step
    if `step' == 0.5 return local s = string(floor(`t' + 1e-6)) + "S" + string(1 + round(2*(`t' - floor(`t' + 1e-6))))
    else return local s = string(round(`t'))
end

capture program drop csatt
program define csatt, rclass
    syntax varname, Unit(varname) Time(varname) Cohort(varname) Sample(varname) ///
        Step(real) Tmax(real) [Prewin(integer 8) ESframe(string) NEVer Gap(integer 1)]
    * gap(k): periodo di riferimento g - k*step (default 1). Con gap(2) il periodo
    * g - step (apertura avvenuta in parte durante il periodo) non entra ne' nella
    * base ne' negli ATT: controllo per la classificazione dei periodi di apertura.
    local y `varlist'
    tempvar yb dy trt ctl mT mC
    quietly levelsof `cohort' if `cohort' > 0 & `sample', local(G)
    local num 0
    local den 0
    local nump 0
    local denp 0
    local postd
    if "`esframe'" != "" {
        capture frame drop `esframe'
        frame create `esframe' double g double t double att long nT
    }
    foreach g of local G {
        local b = `g' - `gap'*`step'
        quietly {
            capture drop `yb' `dy' `trt' `ctl' `mT' `mC'
            bysort `unit': egen double `yb' = max(cond(abs(`time' - `b') < 1e-6, `y', .))
            gen double `dy' = `y' - `yb' if `sample'
            gen byte `trt' = abs(`cohort' - `g') < 1e-6 & `sample'
            if "`never'" != "" gen byte `ctl' = `sample' & `cohort' == 0
            else gen byte `ctl' = `sample' & !`trt' & (`cohort' == 0 | `cohort' > max(`time', `b') + 1e-6)
            bysort `time': egen double `mT' = mean(cond(`trt', `dy', .))
            bysort `time': egen double `mC' = mean(cond(`ctl', `dy', .))
            count if `trt' & abs(`time' - `b') < 1e-6 & !missing(`yb')
            local ng = r(N)
            levelsof `time' if `time' <= `tmax' + 1e-6, local(T)
        }
        if `ng' == 0 continue
        local np 0
        local tp1 .
        local tp2 .
        foreach t of local T {
            quietly summarize `mT' if abs(`time' - `t') < 1e-6, meanonly
            local a = r(mean)
            quietly summarize `mC' if abs(`time' - `t') < 1e-6, meanonly
            local a = `a' - r(mean)
            if missing(`a') continue
            if `t' >= `g' - 1e-6 {
                local num = `num' + `ng'*`a'
                local den = `den' + `ng'
                local ++np
                local tp1 = min(`tp1', `t')
                local tp2 = cond(missing(`tp2'), `t', max(`tp2', `t'))
            }
            if `t' <= `b' - `step' + 1e-6 & `t' >= `g' - `prewin'*`step' - 1e-6 {
                local nump = `nump' + `ng'*`a'
                local denp = `denp' + `ng'
            }
            if "`esframe'" != "" frame post `esframe' (`g') (`t') (`a') (`ng')
        }
        m4tlab `g' `step'
        local gl `r(s)'
        if `np' > 0 {
            m4tlab `tp1' `step'
            local l1 `r(s)'
            m4tlab `tp2' `step'
            local postd "`postd' g`gl'(`ng'): `l1'-`r(s)' (`np');"
        }
        else local postd "`postd' g`gl'(`ng'): nessun periodo dopo;"
    }
    return scalar att = cond(`den' > 0, `num'/`den', .)
    return scalar pre = cond(`denp' > 0, `nump'/`denp', .)
    return local post = strtrim("`postd'")
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

* frame dei risultati (stesse colonne in tutti i moduli)
*   ci_lo, ci_hi: intervallo al 95% per inversione del test di permutazione,
*     att +/- c con c = 95-esimo percentile di |stime con gruppi permutati|
*     (approssimazione con effetto costante: Imbens e Rubin, 2015, cap. 5;
*     Conley e Taber, 2011)
*   periodi: primo periodo con dati - ultimo periodo usato; post: per ogni
*     gruppo di apertura g(numero di aree): periodi dopo l'apertura usati
capture program drop m4cs_init
program define m4cs_init
    capture frame drop m4cs
    frame create m4cs str90 spec str16 outcome double att double p_perm double pre double p_perm_pre ///
        long nT long nC double ci_lo double ci_hi double crit5 long nperm str70 metodo str20 periodi str160 post
end

* 95-esimo percentile dei valori assoluti di una colonna di stime permutate
capture mata: mata drop m4_crit()
mata:
real scalar m4_crit(real colvector e)
{
    real colvector a
    a = sort(abs(select(e, e :< .)), 1)
    if (rows(a) == 0) return(.)
    return(a[ceil(0.95*rows(a))])
}
end

* m4run: stima, permutazione, salvataggio di una riga dei risultati
capture program drop m4run
program define m4run
    syntax varname, Unit(varname) Time(varname) Cohort(varname) Sample(varname) ///
        Step(real) Tmax(real) Spec(string) Perms(integer) [Prewin(integer 8) ESframe(string) NEVer Gap(integer 1)]
    local y `varlist'
    csatt `y', unit(`unit') time(`time') cohort(`cohort') sample(`sample') step(`step') ///
        tmax(`tmax') prewin(`prewin') esframe(`esframe') `never' gap(`gap')
    local att = r(att)
    local pre = r(pre)
    local post `"`r(post)'"'
    tempvar first cpf cp
    quietly {
        bysort `unit' (`time'): gen byte `first' = _n == 1 & `sample'
        count if `first' & `cohort' > 0
        local nT = r(N)
        count if `first' & `cohort' == 0
        local nC = r(N)
        summarize `time' if `sample' & !missing(`y'), meanonly
        local t0 = r(min)
        local t1 = min(`tmax', r(max))
    }
    m4tlab `t0' `step'
    local per `r(s)'
    m4tlab `t1' `step'
    local per "`per'-`r(s)'"
    local ext 0
    local extp 0
    local ok 0
    mata: __m4e = J(0, 1, .)
    forvalues j = 1/`perms' {
        quietly {
            capture drop `cpf' `cp'
            gen double `cpf' = .
            mata: m4_perm("`cohort'", "`first'", "`cpf'")
            bysort `unit': egen double `cp' = max(`cpf')
        }
        csatt `y', unit(`unit') time(`time') cohort(`cp') sample(`sample') step(`step') ///
            tmax(`tmax') prewin(`prewin') `never' gap(`gap')
        if !missing(r(att)) {
            local ++ok
            mata: __m4e = __m4e \ `r(att)'
            if abs(r(att)) >= abs(`att') - 1e-12 local ++ext
            if abs(r(pre)) >= abs(`pre') - 1e-12 local ++extp
        }
    }
    mata: st_local("crit", strofreal(m4_crit(__m4e), "%21.0g"))
    local p = (`ext' + 1)/(`ok' + 1)
    local pp = (`extp' + 1)/(`ok' + 1)
    local met = cond("`never'" != "", "permutazione (`ok'), controlli solo mai esposti", "permutazione dei gruppi di apertura (`ok')")
    frame post m4cs ("`spec'") ("`y'") (`att') (`p') (`pre') (`pp') (`nT') (`nC') ///
        (`att' - `crit') (`att' + `crit') (`crit') (`ok') ("`met'") ("`per'") ("`post'")
    di as txt "  -> " as res "`spec'" as txt " [`y']: effetto " as res %8.4f `att' ///
        as txt " [IC95 " %7.4f `att' - `crit' ", " %7.4f `att' + `crit' "]  p perm = " as res %5.3f `p' ///
        as txt "   placebo pre " as res %8.4f `pre' as txt "  p perm = " as res %5.3f `pp' ///
        as txt "   trattate " `nT' "  controlli " `nC' "   periodi `per'"
    di as txt "     dopo l'apertura: `post'"
end

* m4invert: IC95 per inversione ESATTA del test di permutazione sotto un effetto
* costante additivo delta (Fisher; Imbens e Rubin, 2015, cap. 5).
*   Per un delta di prova: Y* = Y - delta x D_it (D = area trattata nei periodi dopo
*   la propria apertura), poi test di permutazione dell'ipotesi "nessun effetto" su
*   Y*. L'IC e' l'insieme dei delta non rifiutati al 5% (p > 0,05). Gli estremi si
*   trovano per bisezione; le permutazioni sono le stesse per ogni delta (stesso seme).
*   Differenza con l'IC di m4run (stima +/- c): li' la distribuzione delle stime
*   permutate e' quella sotto delta = 0 e si suppone che non cambi con delta.
capture program drop m4perm_p
program define m4perm_p, rclass
    syntax varname, Unit(varname) Time(varname) Cohort(varname) Sample(varname) ///
        Step(real) Tmax(real) Perms(integer) Seed(string)
    local y `varlist'
    csatt `y', unit(`unit') time(`time') cohort(`cohort') sample(`sample') step(`step') tmax(`tmax')
    local att = r(att)
    tempvar first cpf cp
    quietly bysort `unit' (`time'): gen byte `first' = _n == 1 & `sample'
    set seed `seed'
    local ext 0
    local ok 0
    forvalues j = 1/`perms' {
        quietly {
            capture drop `cpf' `cp'
            gen double `cpf' = .
            mata: m4_perm("`cohort'", "`first'", "`cpf'")
            bysort `unit': egen double `cp' = max(`cpf')
        }
        csatt `y', unit(`unit') time(`time') cohort(`cp') sample(`sample') step(`step') tmax(`tmax')
        if !missing(r(att)) {
            local ++ok
            if abs(r(att)) >= abs(`att') - 1e-12 local ++ext
        }
    }
    return scalar p = (`ext' + 1)/(`ok' + 1)
    return scalar att = `att'
end

capture program drop m4invert
program define m4invert, rclass
    syntax varname, Unit(varname) Time(varname) Cohort(varname) Sample(varname) ///
        Step(real) Tmax(real) Perms(integer) Seed(string) Lo(real) Hi(real) [Tol(real 0.001)]
    local y `varlist'
    tempvar D ys
    quietly gen byte `D' = `cohort' > 0 & !missing(`cohort') & `time' >= `cohort' - 1e-6
    * stima puntuale
    csatt `y', unit(`unit') time(`time') cohort(`cohort') sample(`sample') step(`step') tmax(`tmax')
    local att = r(att)
    foreach side in lo hi {
        * a = dentro l'IC (p > 0,05), b = fuori (p <= 0,05)
        local a = `att'
        local b = cond("`side'" == "lo", `lo', `hi')
        capture drop `ys'
        quietly gen double `ys' = `y' - `b'*`D'
        m4perm_p `ys', unit(`unit') time(`time') cohort(`cohort') sample(`sample') step(`step') ///
            tmax(`tmax') perms(`perms') seed(`seed')
        if r(p) > 0.05 {
            di as error "  m4invert: anche delta = `b' non e' rifiutato; allargare l'intervallo di ricerca"
            return scalar `side' = .
            continue
        }
        while abs(`b' - `a') > `tol' {
            local m = (`a' + `b')/2
            capture drop `ys'
            quietly gen double `ys' = `y' - `m'*`D'
            m4perm_p `ys', unit(`unit') time(`time') cohort(`cohort') sample(`sample') step(`step') ///
                tmax(`tmax') perms(`perms') seed(`seed')
            if r(p) > 0.05 local a = `m'
            else local b = `m'
        }
        return scalar `side' = (`a' + `b')/2
    }
    return scalar att = `att'
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
