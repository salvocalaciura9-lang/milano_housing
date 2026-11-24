*==============================================================================*
* netinc_program.do
* Programma netinc: reddito netto di un reddito complessivo IRPEF per anno
* d'imposta (2007-2024) e tipo di detrazione (dip, pen, aut, nod).
* Usato dai moduli 18 e 18b. Parametri e fonti: vedi intestazione di 18b.
*==============================================================================*
capture program drop netinc
program define netinc
    syntax varname(numeric), Year(varname numeric) Type(string) GENerate(name) ///
        [IRPout(name) REGout(name) COMout(name)]
    local R `varlist'
    local y `year'
    tempvar r g d irp bon areg acom
    quietly {
    gen double `r' = max(`R', 0)
    * IRPEF lorda
    gen double `g' = .23*min(`r',15000) + .27*max(min(`r',28000)-15000,0) + ///
        .38*max(min(`r',55000)-28000,0) + .41*max(min(`r',75000)-55000,0) + ///
        .43*max(`r'-75000,0) if `y' <= 2021
    replace `g' = .23*min(`r',15000) + .25*max(min(`r',28000)-15000,0) + ///
        .35*max(min(`r',50000)-28000,0) + .43*max(`r'-50000,0) if inrange(`y',2022,2023)
    replace `g' = .23*min(`r',28000) + .35*max(min(`r',50000)-28000,0) + ///
        .43*max(`r'-50000,0) if `y' >= 2024
    * detrazioni per tipo di reddito
    gen double `d' = 0
    if "`type'" == "dip" {
        replace `d' = cond(`r'<=8000, 1840, cond(`r'<=15000, 1338+502*(15000-`r')/7000, ///
            cond(`r'<=55000, 1338*(55000-`r')/40000, 0))) if `y' <= 2013
        replace `d' = `d' + 10*(`r'>23000 & `r'<=24000) + 20*(`r'>24000 & `r'<=25000) + ///
            30*(`r'>25000 & `r'<=26000) + 40*(`r'>26000 & `r'<=27700) + ///
            25*(`r'>27700 & `r'<=28000) if `y' <= 2013
        replace `d' = cond(`r'<=8000, 1880, cond(`r'<=28000, 978+902*(28000-`r')/20000, ///
            cond(`r'<=55000, 978*(55000-`r')/27000, 0))) if inrange(`y',2014,2021)
        replace `d' = cond(`r'<=15000, cond(`y'>=2024,1955,1880), ///
            cond(`r'<=28000, 1910+1190*(28000-`r')/13000, ///
            cond(`r'<=50000, 1910*(50000-`r')/22000, 0))) + ///
            65*(`r'>25000 & `r'<=35000) if `y' >= 2022
    }
    if "`type'" == "pen" {
        replace `d' = cond(`r'<=7500, 1725, cond(`r'<=15000, 1255+470*(15000-`r')/7500, ///
            cond(`r'<=55000, 1255*(55000-`r')/40000, 0))) if `y' <= 2015
        replace `d' = cond(`r'<=7750, 1783, cond(`r'<=15000, 1255+528*(15000-`r')/7250, ///
            cond(`r'<=55000, 1255*(55000-`r')/40000, 0))) if `y' == 2016
        replace `d' = cond(`r'<=8000, 1880, cond(`r'<=15000, 1297+583*(15000-`r')/7000, ///
            cond(`r'<=55000, 1297*(55000-`r')/40000, 0))) if inrange(`y',2017,2021)
        replace `d' = cond(`r'<=8500, 1955, cond(`r'<=28000, 700+1255*(28000-`r')/19500, ///
            cond(`r'<=50000, 700*(50000-`r')/22000, 0))) + ///
            50*(`r'>25000 & `r'<=29000) if `y' >= 2022
    }
    if "`type'" == "aut" {
        replace `d' = cond(`r'<=4800, 1104, cond(`r'<=55000, 1104*(55000-`r')/50200, 0)) if `y' <= 2021
        replace `d' = cond(`r'<=5500, 1265, cond(`r'<=28000, 500+765*(28000-`r')/22500, ///
            cond(`r'<=50000, 500*(50000-`r')/22000, 0))) + ///
            50*(`r'>11000 & `r'<=17000) if `y' >= 2022
    }
    gen double `irp' = max(`g' - `d', 0)
    * bonus in busta paga (solo dipendenti, se l'imposta lorda supera la detrazione)
    gen double `bon' = 0
    if "`type'" == "dip" {
        local cap (`g' > `d')
        replace `bon' = `cap'*cond(`r'<=24000, 640, cond(`r'<=26000, 640*(26000-`r')/2000, 0)) if `y' == 2014
        replace `bon' = `cap'*cond(`r'<=24000, 960, cond(`r'<=26000, 960*(26000-`r')/2000, 0)) if inrange(`y',2015,2017)
        replace `bon' = `cap'*cond(`r'<=24600, 960, cond(`r'<=26600, 960*(26600-`r')/2000, 0)) if inrange(`y',2018,2019)
        * 2020: bonus 80 EUR a gennaio-giugno, trattamento integrativo e ulteriore detrazione a luglio-dicembre
        replace `bon' = `cap'*cond(`r'<=24600, 480, cond(`r'<=26600, 480*(26600-`r')/2000, 0)) + ///
            `cap'*600*(`r'<=28000) + ///
            cond(`r'>28000 & `r'<=35000, 480+120*(35000-`r')/7000, ///
            cond(`r'>35000 & `r'<=40000, 480*(40000-`r')/5000, 0)) if `y' == 2020
        replace `bon' = `cap'*1200*(`r'<=28000) + ///
            cond(`r'>28000 & `r'<=35000, 960+240*(35000-`r')/7000, ///
            cond(`r'>35000 & `r'<=40000, 960*(40000-`r')/5000, 0)) if `y' == 2021
        replace `bon' = `cap'*1200*(`r'<=15000) if `y' >= 2022
    }
    * addizionale regionale Lombardia (aliquote per scaglioni)
    gen double `areg' = .009*min(`r',15493.71) + .013*max(min(`r',30987.41)-15493.71,0) + ///
        .014*max(`r'-30987.41,0) if `y' <= 2011
    replace `areg' = .0123*min(`r',15000) + .0158*max(min(`r',28000)-15000,0) + ///
        .0172*max(min(`r',55000)-28000,0) + .0173*max(min(`r',75000)-55000,0) + ///
        .0174*max(`r'-75000,0) if inrange(`y',2012,2022)
    replace `areg' = .0123*min(`r',15000) + .0158*max(min(`r',28000)-15000,0) + ///
        .0172*max(min(`r',50000)-28000,0) + .0173*max(`r'-50000,0) if `y' >= 2023
    * addizionale comunale Milano (soglia di esenzione: sopra la soglia si paga su tutto)
    gen double `acom' = 0
    replace `acom' = .002*`r'*(`r'>33500) if `y' == 2011
    replace `acom' = (.002*min(`r',15000) + .003*max(min(`r',28000)-15000,0) + ///
        .004*max(min(`r',55000)-28000,0) + .006*max(min(`r',75000)-55000,0) + ///
        .008*max(`r'-75000,0))*(`r'>33500) if `y' == 2012
    replace `acom' = .008*`r'*(`r'>21000) if inrange(`y',2013,2019)
    replace `acom' = .008*`r'*(`r'>23000) if `y' >= 2020
    * le addizionali non sono dovute se l'IRPEF netta e' zero
    replace `areg' = 0 if `irp' <= 0
    replace `acom' = 0 if `irp' <= 0
    gen double `generate' = `R' - `irp' - `areg' - `acom' + `bon'
    * regole fiscali implementate dal 2007 (TUIR riformato dalla Finanziaria 2007)
    replace `generate' = . if `y' < 2007
    if "`irpout'" != "" gen double `irpout' = `irp' if `y' >= 2007
    if "`regout'" != "" gen double `regout' = `areg' if `y' >= 2007
    if "`comout'" != "" gen double `comout' = `acom' if `y' >= 2007
    }
end
