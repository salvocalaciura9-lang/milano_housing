*==============================================================================*
* 00_programs.do  -  programmi di supporto usati da tutti i moduli
*
*  imp_csv     importa un CSV come testo (prova ";" e poi ",")
*  tonum       converte stringhe in numeri (virgola decimale, punti migliaia,
*              N.D.), segnalando i valori non convertibili
*  findvar     trova UNA colonna cercando una regex nel nome e nell'etichetta
*              (import delimited conserva l'intestazione originale come etichetta)
*  getvar      come findvar, poi rinomina la colonna con il nome canonico
*  detectcode  individua la colonna i cui valori seguono un formato (CAP, zona OMI)
*  rq7         quantile con la definizione "type 7" di R (default di R)
*  rpar        mediana e IQR (type 7) di una variabile
*  checkval    confronta un valore calcolato con un valore atteso del documento
*  saveres     salva coefficiente, IC e N dell'ultima stima nel frame "results"
*==============================================================================*

version 16

*------------------------------------------------------------------------------*
capture program drop imp_csv
program define imp_csv
    version 16
    syntax using/ [, Delim(string)]
    if `"`delim'"' != "" {
        import delimited using `"`using'"', delimiters(`"`delim'"') varnames(1) ///
            stringcols(_all) encoding("utf-8") bindquote(strict) clear
    }
    else {
        import delimited using `"`using'"', delimiters(";") varnames(1) ///
            stringcols(_all) encoding("utf-8") bindquote(strict) clear
        if c(k) <= 1 {
            import delimited using `"`using'"', delimiters(",") varnames(1) ///
                stringcols(_all) encoding("utf-8") bindquote(strict) clear
        }
    }
    di as txt "  importato " as res `"`using'"' as txt ": " c(N) " righe, " c(k) " colonne"
end

*------------------------------------------------------------------------------*
capture program drop tonum
program define tonum
    version 16
    syntax varlist
    foreach v of local varlist {
        capture confirm string variable `v'
        if _rc continue
        quietly {
            replace `v' = ustrtrim(`v')
            replace `v' = "" if inlist(upper(`v'), "N.D.", "N.D", "ND", "NA", "N/A", "-", ".", "NULL", "NAN")
            replace `v' = subinstr(`v', " ", "", .)
            * con la virgola decimale i punti sono separatori delle migliaia
            replace `v' = subinstr(`v', ".", "", .) if strpos(`v', ",") > 0
            replace `v' = subinstr(`v', ",", ".", .)
            * piu' di un punto e nessuna virgola: punti delle migliaia
            replace `v' = subinstr(`v', ".", "", .) if length(`v') - length(subinstr(`v', ".", "", .)) > 1
        }
        tempvar x
        quietly gen double `x' = real(`v')
        quietly count if missing(`x') & `v' != ""
        if r(N) > 0 {
            di as error "  tonum: `v' ha " r(N) " valori non numerici, posti a missing"
        }
        local lab : variable label `v'
        order `x', after(`v')
        drop `v'
        rename `x' `v'
        label variable `v' `"`lab'"'
    }
end

*------------------------------------------------------------------------------*
capture program drop findvar
program define findvar, rclass
    version 16
    syntax , Pattern(string) [EXclude(string) Required]
    local hits
    foreach v of varlist _all {
        local lab : variable label `v'
        local s = ustrlower(`"`v' `lab'"')
        if ustrregexm(`"`s'"', `"`pattern'"') {
            if `"`exclude'"' == "" {
                local hits `hits' `v'
            }
            else if !ustrregexm(`"`s'"', `"`exclude'"') {
                local hits `hits' `v'
            }
        }
    }
    local n : word count `hits'
    if `n' == 1 {
        return local varname `hits'
        exit
    }
    if `n' == 0 & "`required'" == "" {
        return local varname ""
        exit
    }
    di as error "findvar: il criterio [`pattern'] trova `n' colonne: `hits'"
    di as error "Colonne disponibili:"
    describe, simple
    exit 111
end

*------------------------------------------------------------------------------*
capture program drop getvar
program define getvar
    version 16
    syntax anything(name=canon), Pattern(string) [EXclude(string) OPTional]
    local req = cond("`optional'" == "", "required", "")
    findvar, pattern(`"`pattern'"') exclude(`"`exclude'"') `req'
    local v `r(varname)'
    if "`v'" == "" {
        di as txt "  (colonna facoltativa assente: `canon')"
        exit
    }
    if "`v'" != "`canon'" {
        capture confirm new variable `canon'
        if _rc {
            di as error "getvar: esiste gia' una variabile chiamata `canon'"
            exit 110
        }
        rename `v' `canon'
    }
    di as txt "  `canon' <- `v'"
end

*------------------------------------------------------------------------------*
* Restituisce in r(varname) la colonna con la quota piu' alta di valori che
* rispettano la regex (minimo 50%); r(share) e' quella quota.
capture program drop detectcode
program define detectcode, rclass
    version 16
    syntax , Regex(string)
    local best ""
    local bestk = 0
    foreach v of varlist _all {
        if inlist("`v'", "_ID", "_CX", "_CY") continue
        tempvar s
        capture confirm string variable `v'
        if _rc {
            quietly gen `s' = string(`v', "%12.0f")
        }
        else {
            quietly gen `s' = upper(ustrtrim(`v'))
        }
        quietly count if ustrregexm(`s', `"`regex'"')
        local k = r(N)
        drop `s'
        if `k' > `bestk' {
            local best `v'
            local bestk = `k'
        }
    }
    if "`best'" == "" | `bestk' < 0.5*_N {
        di as error "detectcode: nessuna colonna con valori del tipo [`regex']. Indicare il campo nel master."
        exit 111
    }
    di as txt "  colonna individuata: `best' (" %4.1f 100*`bestk'/_N "% dei valori nel formato atteso)"
    return local varname `best'
    return scalar share = `bestk'/_N
end

*------------------------------------------------------------------------------*
* Quantile "type 7" (R, default di quantile() e IQR()): h = (n-1)p + 1
capture mata mata drop _rq7()
mata:
void _rq7(string scalar v, string scalar touse, real scalar p)
{
    real colvector x
    real scalar n, h, lo, hi
    x = st_data(., v, touse)
    x = select(x, x :< .)
    n = rows(x)
    st_numscalar("__rq7n", n)
    if (n == 0) {
        st_numscalar("__rq7q", .)
        return
    }
    x = sort(x, 1)
    h = (n - 1) * p + 1
    lo = floor(h)
    hi = ceil(h)
    st_numscalar("__rq7q", x[lo] + (h - lo) * (x[hi] - x[lo]))
}
end

capture program drop rq7
program define rq7, rclass
    version 16
    syntax varname(numeric) [if] [in], P(real)
    marksample touse
    mata: _rq7("`varlist'", "`touse'", `p')
    return scalar q = scalar(__rq7q)
    return scalar N = scalar(__rq7n)
    scalar drop __rq7q __rq7n
end

capture program drop rpar
program define rpar, rclass
    version 16
    syntax varname(numeric) [if] [in]
    marksample touse
    tempname m q1 q3
    rq7 `varlist' if `touse', p(0.5)
    scalar `m' = r(q)
    local n = r(N)
    rq7 `varlist' if `touse', p(0.25)
    scalar `q1' = r(q)
    rq7 `varlist' if `touse', p(0.75)
    scalar `q3' = r(q)
    if (`q3' - `q1') == 0 {
        di as error "  rpar: IQR nullo per `varlist'"
    }
    return scalar med = `m'
    return scalar q1  = `q1'
    return scalar q3  = `q3'
    return scalar iqr = `q3' - `q1'
    return scalar N   = `n'
end

*------------------------------------------------------------------------------*
capture program drop checkval
program define checkval
    version 16
    syntax , Label(string) Expected(real) [Value(string) Tol(real 0.01)]
    if "`value'" == "" | "`value'" == "." {
        di as error "  [MANCANTE] `label': valore non calcolabile"
        exit
    }
    local d = abs(`value' - `expected')
    if `d' <= `tol' {
        di as txt "  [OK] `label': " as res %14.4f `value' as txt "  (atteso " %14.4f `expected' ")"
    }
    else {
        di as error "  [DIVERSO] `label': " %14.4f `value' "  (atteso " %14.4f `expected' ") -> verificare i dati"
    }
end

*------------------------------------------------------------------------------*
capture program drop saveres
program define saveres
    version 16
    syntax , Model(string) Spec(string) Coef(string) [Note(string) ///
        PBoot(real -999) LBBoot(real -999) UBBoot(real -999)]
    capture confirm frame results
    if _rc {
        frame create results str244 model str244 spec str60 coef double b double se ///
            double lb double ub double p double p_boot double lb_boot double ub_boot ///
            long N str20 cmd str244 note
    }
    tempname b se crit lb ub p
    capture scalar `b' = _b[`coef']
    if _rc {
        di as error "saveres: coefficiente `coef' non presente nell'ultima stima"
        exit 111
    }
    scalar `se' = _se[`coef']
    if missing(e(df_r)) {
        scalar `crit' = invnormal(0.975)
        scalar `p'    = 2*normal(-abs(`b'/`se'))
    }
    else {
        scalar `crit' = invttail(e(df_r), 0.025)
        scalar `p'    = 2*ttail(e(df_r), abs(`b'/`se'))
    }
    scalar `lb' = `b' - `crit'*`se'
    scalar `ub' = `b' + `crit'*`se'
    local pb  = cond(`pboot'  == -999, ., `pboot')
    local lbb = cond(`lbboot' == -999, ., `lbboot')
    local ubb = cond(`ubboot' == -999, ., `ubboot')
    local cmd "`e(cmd)'"
    frame post results ("`model'") ("`spec'") ("`coef'") (`b') (`se') (`lb') (`ub') ///
        (`p') (`pb') (`lbb') (`ubb') (e(N)) ("`cmd'") ("`note'")
    di as txt "  -> " as res "`spec'" as txt ": `coef' = " as res %9.4f `b' ///
        as txt "  IC95 [" %9.4f `lb' "; " %9.4f `ub' "]  N = " e(N)
end
