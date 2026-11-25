# Data and construction of the measures

> Bozza per il paper (sezioni 1–2 ≈ 1.200 parole, formule escluse, tabelle e appendice escluse).
> Ricostruita dai moduli 01–03c e 18 (sezioni 1–3) e dai file in `data/work`;
> le statistiche della Tabella 2 sono state calcolate dai file `.dta` del repository.
> Aggiornata il 25/11/2026 ai dati del commit f4d35f2 su `main` (correzione della zona C14: pannello bilanciato di 75 NIL).
> Le note di verifica per il gruppo sono in fondo, in italiano.

---

## 1. Data

**Rents.** Housing costs are measured with the quotations of the *Osservatorio del Mercato Immobiliare* (OMI) of the Italian Revenue Agency, distributed by the Comune di Milano open-data portal (dataset ds1996, first semester 2004 to second semester 2025). For each homogeneous zone, property type and state of repair, OMI publishes a minimum–maximum interval of market and rental values per m² (Agenzia delle Entrate, n.d.); in ds1996 rents are in EUR per m² of gross floor area per month and sale values in EUR per m². These intervals describe normal market values in the zone; they are neither averages of registered contracts nor transaction prices. We keep "civil dwellings" (type 20) in "normal" condition, one quotation per zone and semester, and use the midpoint of the range. The number of quoted zones falls from 55 (2004–2013) to 38 (from 2014; 39 from 2018) and rises to 40 after the 2024 revision (Appendix A).

**Income.** Dataset ds531 reports, for the whole municipality, the number of taxpayers (*persone fisiche*) and the amount of *reddito complessivo* in eight income classes, for tax years 2008–2024. Tax years 2004–2007 come from the municipal files of the Ministry of Economy and Finance (MEF), which use the same classes. *Reddito complessivo* is an individual taxpayer's total income before deductions and taxes. It is not household income, and it is not available below the city level. Tax year *t* (income earned in *t*, declared in *t*+1) is matched to rents of calendar year *t*. Postcode-level MEF data (module 01) are used only in CAP-level analyses.

**Population and moves.** DS205 provides residents, births, deaths, emigrants and immigrants for each *Nucleo di Identità Locale* (NIL) and year, 2011–2024. Four further datasets split registry cancellations and registrations into three reasons for 2004–2024: another Italian municipality, abroad, and "other" (administrative removals such as untraceable residents). Dataset ds27 gives residents by NIL and single year of age for 1999–2025. DS205 and ds27 are stocks; the movement data are flows, which never record moves between NILs.

**Metro stations.** Dataset ds535 (municipal public-transport stops) gives the name, lines and coordinates of each metro station, 21 of them on line M4. Opening dates of the three M4 sections are added by hand (26 November 2022, 4 July 2023 and 12 October 2024).

**Analytical sample.** The unit of observation is the NIL-year, on the 88 current NILs. We drop eight NILs with fewer than 500 residents in 2019 (parks, rail yards). Of the remaining 80, the main panel keeps the 75 NILs whose rent is observed in every year from 2004 to 2024. This balanced panel contains 1,350 NIL-years for the main index (2007–2024) and 1,575 for the gross-income control (2004–2024). Income is a single city-wide series. For 2004–2010, residents are set equal to their 2011 values.

## 2. Construction of the measures

### 2.1 From OMI zones to NILs

OMI zones and NILs do not nest. We therefore overlay a regular grid of points (about 27 × 28 m) on the city and assign each point to a NIL and to the OMI zone in force under each zoning scheme *k*. Point counts approximate intersection areas. For NIL *i* and semester *s* with scheme *k(s)*, the rent is

$$R_{is}=\frac{\sum_{z\in Q_s} n^{k(s)}_{iz}\,R_{zs}}{\sum_{z\in Q_s} n^{k(s)}_{iz}},\qquad 
c_{is}=\frac{\sum_{z\in Q_s} n^{k(s)}_{iz}}{N_i},$$

where $R_{zs}$ is the OMI midpoint, $n^{k}_{iz}$ is the number of points of NIL *i* in zone *z*, $Q_s$ is the set of zones quoted in *s*, and $N_i$ is the total number of points in the NIL. $R_{is}$ is set to missing when coverage $c_{is}<0.80$. The annual rent $R_{it}$ is the mean of the available semesters. Rents are intensive (EUR/m²): the weights average them and never allocate totals. The underlying assumption is that the quotation is uniform within a zone and that every part of the NIL counts in proportion to its area, so parks and rail yards weigh as much as residential blocks. NIL rents are thus estimates.

### 2.2 OMI zoning changes

Each semester is linked to the zoning in force at the time: the 2011 polygons up to 2013, the 2025 polygons with the zones split in 2024 recoded to their parents (D37+D38→D15, D39+D40→D30) for 2014S2–2024S1, and the 2025 polygons as published from 2024S2. The first semester of 2014 is a transition period, with half of the zones still carrying old codes, and is dropped. Across the 2013–2014 break, measured changes may partly reflect redrawn boundaries. Zone C14 (Porta Nuova), carved out of C12 but quoted only from 2018S2, takes the C12 rent until 2018S1 in the NIL series.

### 2.3 Median income from grouped data

Let classes $j=1,\dots,J$ have bounds $[L_j,U_j)$ and frequencies $f_j$. Let $N_t=\sum_j f_j$ count all taxpayers, including those with zero or negative income, and let $F_j$ be the cumulative frequency. The median class *m* satisfies $F_{m-1}<N_t/2\le F_m$. Assuming taxpayers are uniformly spread within it,

$$Y^{med}_t = L_m+\frac{N_t/2-F_{m-1}}{f_m}\,(U_m-L_m).$$

The median always lies in the EUR 15,000–26,000 class, so the open top class never matters. The distribution is city-wide, so no territorial medians are averaged. $Y^{med}_t$ is an interpolated estimate for the median taxpayer, not a microdata median. Net income replaces the class bounds with their after-tax values, $g_t(L_m)$ and $g_t(U_m)$. The function $g_t$ applies the national income tax (IRPEF), employee tax credits, the regional and municipal surcharges and the payroll bonuses in force in year *t* (scenario "employee"; alternatives in module 18b):

$$Y^{net}_t = g_t(L_m)+\frac{N_t/2-F_{m-1}}{f_m}\,[g_t(U_m)-g_t(L_m)].$$

### 2.4 Affordability index

The main index is the annual rent of a standard 60 m² dwelling in NIL *i* divided by the city's median net income:

$$A_{it}=\frac{12\cdot 60\cdot R_{it}}{Y^{net}_t},\qquad D_{it}=\mathbf 1[A_{it}>0.40].$$

$A_{it}$ is a ratio, reported in percent; a higher value means lower affordability. The denominator is the same for every NIL, so $A_{it}$ measures how much of the typical Milanese taxpayer's net income a standard rental in each NIL would absorb, and its variation across NILs comes only from rents. The 40% threshold is the OECD housing cost overburden standard: the share of households spending "more than 40% of their disposable income on housing costs (in line with Eurostat methodology)", where indicator HC1.2.3 uses the narrow definition of rent and mortgage costs (OECD, 2024; Eurostat, n.d.). Our numerator, rent only, matches that narrow definition and our denominator is after tax, but two adaptations remain. The OECD ratio uses each household's actual costs and equivalised household disposable income; $A_{it}$ uses a standardised market rent and one individual's estimated net income. A gross-income version, $A^{g}_{it}=12\cdot60\cdot R_{it}/Y^{med}_t$ with the 30% rule of thumb, is kept only as a robustness check from 2004. The headline statistic is the share of residents living in NILs above the threshold, $\sum_i P_{it}D_{it}/\sum_i P_{it}$, on the balanced panel. It says where a median earner could rent a standard flat at normal market rates, not how many households are actually overburdened. Sale values enter no price-to-income ratio and no threshold.

### 2.5 Exits and net migration by age

Out-migration is $r^{ac}_{it}=1000\cdot C^{ac}_{it}/P_{i,t-1}$, where $C^{ac}$ counts cancellations to another Italian municipality. This excludes moves abroad and administrative removals, which account for 42–46% of cancellations in 2013–2014. Registry flows ignore entries, as well as moves within Milan. For age group *c* we therefore follow cohorts in the ds27 stocks:

$$NM^{c}_{it}=1000\cdot\frac{\sum_{a\in c}P_{i,a+1,t}-\sum_{a\in c}P_{i,a,t-1}}{\sum_{a\in c}P_{i,a,t-1}},\quad c\in\{0\text{–}9,\,20\text{–}29,\,30\text{–}39,\,40\text{–}64\}.$$

$NM^{c}_{it}$ is the net change in cohort size. It nets out inflows against outflows, including moves between NILs. Births do not enter it, but it also absorbs deaths, which are small below age 65, and registry corrections. It is therefore net migration only in an approximate sense. A balance near zero may hide large gross flows. Neither measure separates voluntary mobility from involuntary displacement.

---

### References (verified 25 November 2026)

- Agenzia delle Entrate (n.d.). *Quotazioni immobiliari*, Osservatorio del Mercato Immobiliare. https://www.agenziaentrate.gov.it/portale/web/guest/schede/fabbricatiterreni/omi/banche-dati/quotazioni-immobiliari
- Eurostat (n.d.). *Glossary: Housing cost overburden rate*. Statistics Explained. https://ec.europa.eu/eurostat/statistics-explained/index.php?title=Glossary:Housing_cost_overburden_rate
- OECD (2024). *HC1.2 Housing costs over income*. OECD Affordable Housing Database, last updated 15/04/2024. https://www.oecd.org/content/dam/oecd/en/data/datasets/affordable-housing-database/hc1-2-housing-costs-over-income.pdf
- Comune di Milano, Open Data portal: datasets ds1996, ds531, DS205, ds1596, ds1600, ds1954, ds1956, ds27, ds535, DS964 (file names in `data/raw` and `data/geo`).

---

## Table 1 — Data sources and coverage

| Source (producer, dataset) | Content used | Original geography → final | Frequency, years | Use |
|---|---|---|---|---|
| OMI quotations, Agenzia delle Entrate, via Comune di Milano ds1996 | Min/max rent (EUR/m²/month) and sale value (EUR/m²), gross floor area; civil dwellings, normal condition; midpoint | OMI zone (55 → 38/39 → 40) → NIL (area weights) | Semester, 2004S1–2025S2 (2014S1 excluded) | $R_{it}$, numerator of $A_{it}$; sale values $P$ for module 19 |
| OMI zone polygons (2011 S1; 2025 S2) | Zone boundaries | — | Two vintages | Spatial weights $n^k_{iz}$ |
| Comune di Milano ds531 | Taxpayers and amounts by 8 classes of *reddito complessivo* | Municipality | Annual, tax years 2008–2024 | $Y^{med}_t$, $Y^{net}_t$ |
| MEF, IRPEF data by municipality | Same classes | Municipality | Annual, tax years 2004–2007 | $Y^{med}_t$ (net from 2007) |
| MEF, IRPEF data by CAP | Taxpayers, amounts, classes | 38 CAP | Annual, 2019–2024 | CAP analyses only (module 01) |
| Comune di Milano DS205 | Residents, births, deaths, emigrants, immigrants, age shares | NIL (88) | Annual, 2011–2024 | $P_{it}$, weights, $r^{emig}$ |
| ds1600/ds1956, ds1596/ds1954 | Cancellations / registrations by reason, sex, citizenship | NIL (by name → code) | Annual, 2004–2024 | $r^{ac}_{it}$ |
| ds27 | Residents by single year of age and citizenship | NIL | Annual, 1999–2025 | $NM^c_{it}$, composition |
| NIL polygons (DS964) | Current NIL boundaries | — | Current | Grid assignment |
| ATM stops, ds535 | Metro station coordinates and lines; M4 opening dates added by hand | Point → grid → NIL / OMI zone | Static (cohort by section) | M4 exposure (module 19) |

## Table 2 — Descriptive statistics

Balanced panel of 75 NILs. Unweighted statistics (each NIL-year counts once); no imputation; city-level income series have one observation per year. Computed (25/11/2026, data after commit f4d35f2) from `aff_nil_year.dta`, `milano_income.dta`, `ds205_nil_year.dta`, `nil_composition_year.dta`.

| Variable | Unit | Years | N | Mean | SD | Median | Min | Max |
|---|---|---|---|---|---|---|---|---|
| OMI rent $R_{it}$ | EUR/m²/month | 2007–24 | 1,350 | 9.15 | 3.12 | 8.23 | 5.26 | 25.11 |
| Affordability index $A_{it}$ (60 m², net) | % | 2007–24 | 1,350 | 37.27 | 12.13 | 34.19 | 22.14 | 94.79 |
| Gross control $A^g_{it}$ | % | 2004–24 | 1,575 | 30.83 | 9.97 | 28.31 | 18.06 | 77.24 |
| $D_{it}$: $A_{it}>40\%$ | % of NIL-years | 2007–24 | 1,350 | 27.93 | — | — | — | — |
| $A^g_{it}>30\%$ | % of NIL-years | 2004–24 | 1,575 | 40.57 | — | — | — | — |
| Median gross income $Y^{med}_t$ | EUR | 2004–24 | 21 | 21,053 | 2,056 | 20,947 | 17,344 | 25,919 |
| Median net income $Y^{net}_t$ | EUR | 2007–24 | 18 | 17,670 | 1,663 | 17,415 | 15,590 | 21,559 |
| Taxpayers $N_t$ | persons | 2004–24 | 21 | 980,597 | 18,191 | 974,592 | 953,140 | 1,013,593 |
| Residents $P_{it}$ | persons | 2012–24 | 975 | 17,871 | 12,022 | 16,608 | 367 | 63,073 |
| Exits to other municipalities $r^{ac}_{it}$ | per 1,000 | 2012–24 | 975 | 23.98 | 12.29 | 21.54 | 8.57 | 172.68 |
| All emigrants (DS205) $r^{emig}_{it}$ | per 1,000 | 2012–24 | 975 | 32.86 | 18.43 | 28.79 | 10.90 | 257.06 |
| Net migration, age 0–9 $NM^{0-9}$ | per 1,000 | 2012–24 | 975 | 4.24 | 47.97 | 0.00 | −285.7 | 750.0 |
| Net migration, age 20–29 $NM^{20-29}$ | per 1,000 | 2012–24 | 975 | 63.61 | 121.98 | 53.28 | −376.5 | 3,286.3 |
| Net migration, age 30–39 $NM^{30-39}$ | per 1,000 | 2012–24 | 975 | 19.31 | 52.26 | 14.31 | −234.4 | 754.1 |
| Net migration, age 40–64 $NM^{40-64}$ | per 1,000 | 2012–24 | 975 | −3.78 | 25.49 | −5.10 | −166.7 | 464.6 |

*Population-weighted share of residents in NILs with $A_{it}>40\%$ (city summary, `aff_city_year.csv`): 45.6% (2007), 27.1% (2018), 43.2% (2024). Extreme values of $NM^c$ come from small cohorts in sparsely populated NILs.*

---

## Appendix A — OMI zoning changes and spatial harmonisation

**Grid.** Points spaced 0.00035° in longitude and 0.00025° in latitude (≈27 × 28 m) over the extent of the 38 CAP polygons, giving 239,111 points (≈181 km²) inside the CAPs. Of these, 0.28% fall outside any NIL and 0.31% outside the 2025 OMI zones. A point on a shared boundary goes to the first polygon (164 points for the 2025 zones, 460 for the 2011 zones). Each point carries one NIL, one 2011 zone, one 2025 zone and its recoded 2014–2024 zone. The point × scheme structure is unique, so joining quotations to points (`joinby scheme z`) cannot duplicate observations. Coverage below 0.80 sets the rent to missing rather than rescaling it. This is why five NILs (34, 35, 39, 40, 59) leave the balanced panel after 2014: zone C13 is quoted only in "excellent" condition, and some peripheral zones have no civil-dwelling quotation.

| Period | Documented change (from the data) | Treatment in the project | Source of the information | Comparability |
|---|---|---|---|---|
| 2004S1–2013S2 | Same 55 zone codes every semester | 2011 S1 polygons applied to all years | ds1996 codes; `_expl_f205_2011_1.geojson` | Assumes boundaries constant 2004–2013 (unverified) |
| 2014S1 | Transition: 38 quoted zones, of which about half with old codes (B02–B06, C01–C09, D01–D09) and no matching polygon | Semester dropped; 2014 = 2014S2 only | ds1996; module 18 | 2014 annual value based on one semester |
| 2014S2 | New zoning: zones renumbered and redrawn (e.g. B15–B21, C15–C20, D30–D36, E5–E8); 40 zones in total, 38 quoted for civil/normal | 2025 S2 polygons with D37+D38→D15, D39+D40→D30 | ds1996; module 10a | Break between 2013 and 2014; no zone-to-zone correspondence imposed |
| 2018S2 | C14 (carved out of C12) first quoted for civil dwellings in normal condition (39 zones) | NIL series: C12 rent assigned to the C14 area 2014S2–2018S1; zone-level series (M4): C14 missing before 2018S2 | ds1996; module 18 | Imputation assumes C14 rents equal to C12 (15.0 vs 15.6 EUR/m² in 2018S2) |
| 2024S2 | D15 → D37 + D38; D30 → D39 + D40; Ortomercato moved from D15 to D16 (per module 10a); D39 quoted only in "excellent" condition | 2025 S2 polygons as published; 2024 = mean of S1 (old scheme) and S2 (new) | ds1996; module 10a header | Recoded D15 polygon for 2014–2024 omits the Ortomercato area |

---

## Variable dictionary

| Paper name | Symbol | Code name (file) | Definition | Unit |
|---|---|---|---|---|
| OMI rent (zone) | $R_{zs}$ | `R_mid` (`omi_civ_sem`) | Midpoint of min/max rent, civil dwellings, normal | EUR/m² gross/month |
| OMI sale value (zone) | $P_{zs}$ | `P_mid` | Midpoint of min/max sale value | EUR/m² gross |
| NIL rent | $R_{it}$ | `R` (`omi_nil_year_long`, `aff_nil_year`) | Area-weighted, mean of semesters | EUR/m²/month |
| OMI coverage | $c_{it}$ | `cov` | Minimum semester share of NIL area in quoted zones | share |
| Median gross income | $Y^{med}_t$ | `y_med` (`milano_income`) | Interpolated median *reddito complessivo*, city | EUR/year |
| Median net income | $Y^{net}_t$ | `y_med_net` | Same, after IRPEF, surcharges, bonuses (employee scenario) | EUR/year |
| Mean income | — | `y_mean` | Total amount / taxpayers | EUR/year |
| Taxpayers | $N_t$ | `n_contr` | All ds531 classes | persons |
| Affordability index | $A_{it}$ | `A60` | $12\cdot60\cdot R_{it}/Y^{net}_t$ | ratio (×100 = %) |
| Overburden indicator | $D_{it}$ | `off_A60` | $A_{it}>0.40$ | 0/1 |
| Gross control index | $A^g_{it}$ | `A60g`, `off_A60g` | $12\cdot60\cdot R_{it}/Y^{med}_t$; threshold 0.30 | ratio; 0/1 |
| Variants | — | `A40`, `A60d` | 40 m² one income; 60 m² two incomes | ratio |
| Balanced-panel flag | — | `balanced` | Rent observed every year 2004–2024 | 0/1 |
| Share of residents above threshold | $S_t$ | `sh_pop_A60` (`aff_city_year.csv`) | $\sum_i P_{it}D_{it}/\sum_i P_{it}$ | share |
| Residents | $P_{it}$ | `pop` (`ds205_nil_year`) | Registered residents (2004–10 = 2011) | persons |
| Exits to other municipalities | $r^{ac}_{it}$ | `r_ac` | $1000\cdot$`canc_ac`$/P_{i,t-1}$ | per 1,000 |
| Exits incl. abroad | — | `r_mov` | (`canc_ac`+`canc_es`)$/P_{i,t-1}$ ×1000 | per 1,000 |
| All emigrants (DS205) | $r^{emig}_{it}$ | `r_emig` | Includes administrative removals | per 1,000 |
| Net migration by age | $NM^c_{it}$ | `nm_c0009`, `nm_c2029`, `nm_c3039`, `nm_c4064` (`nil_composition_year`) | Cohort change, per 1,000 of cohort in $t-1$ | per 1,000 |

---

## Note di verifica per il gruppo

1. **Soglia e reddito: confermati.** Il gruppo ha deciso: reddito netto mediano di tutta Milano e soglia del 40% (standard OCSE). Corrisponde a quanto già implementato in `18_affordability_milano.do` (`A60`, `off_A60`), quindi non c'è niente da rieseguire. Il 30% sul lordo (`A60g`) resta nel codice solo come controllo di robustezza: se preferite toglierlo anche dal testo basta eliminare una frase della 2.4.
2. **Fonti verificate il 25/11/2026.** OCSE HC1.2 (PDF aggiornato al 15/04/2024: soglia 40% del reddito disponibile, HC1.2.3 = definizione ristretta affitto + mutuo, reddito equivalente delle famiglie), glossario Eurostat (costi abitativi totali, al netto dei sussidi per la casa) e pagina OMI dell'Agenzia delle Entrate (intervallo minimo/massimo per tipologia e stato di conservazione). Il sito HUD rifiuta le richieste automatiche (errore 403): per questo nel testo la soglia del 30% è chiamata *rule of thumb*, senza citare HUD. Se volete citarlo, aggiungete il riferimento a mano dopo averlo controllato.
3. **Possibile errore nel netto 2022–2023** (`netinc_program.do`, ereditato da 18 e 18b). Dal 2022 il trattamento integrativo di 1.200 € vale fino a 15.000 € e poi va a zero di colpo. Il netto al confine 15.000 include quindi il bonus, mentre appena sopra il confine non c'è: l'ipotesi "il netto cresce con il lordo" è violata. Con l'interpolazione la mediana netta risulta sovrastimata di circa 284 € nel 2022, 139 € nel 2023 e 9 € nel 2024 (calcolo mio da `milano_income_classes.dta`, assumendo il salto a 15.000), quindi `A60` è leggermente sottostimato. Correzione proposta: usare il limite destro, cioè il netto a 15.000,01. Va rieseguito in Stata (18, 18b e moduli a valle). Inoltre il programma applica l'imposta al reddito complessivo, senza oneri deducibili.
4. **Popolazione di ds531.** Nel 2019 ds531 conta 990.224 contribuenti, mentre i file MEF per CAP (modulo 01) ne contano 1.018.249 (circa il 2,8% in più). Bisogna verificare nei metadati di ds531 se "Anno" è l'anno d'imposta (l'andamento lo suggerisce) e quale popolazione è coperta.
5. **Confini OMI 2004–2013 non verificati.** I 55 codici sono identici in ogni semestre, ma per tutti gli anni si usano i poligoni del 1° semestre 2011. Se i confini sono cambiati prima del 2011, i valori 2004–2010 per NIL sono imprecisi.
6. **D15 ricodificata.** Per il 2014–2024 il poligono D15 è ricostruito come D37+D38, ma l'area dell'Ortomercato passata a D16 resta in D16 (`10a_crosswalk_area.do`). L'effetto è piccolo e circoscritto alla zona est.
7. **Pesi di superficie, non residenziali.** Parchi e scali pesano quanto le aree abitate (modulo 10a). Una robustezza con pesi per civici o popolazione resta possibile, da presentare come controllo e non come specificazione principale.
8. **Residenti 2004–2010 fissati al 2011** (modulo 18): le quote di residenti oltre soglia prima del 2011 usano pesi costanti. È da dire nel testo dei risultati.
9. **ds27 assente** (`03c_nil_composition.do`). Non ho potuto verificare la data di riferimento degli stock (31/12?), la codifica dell'età massima e le cittadinanze. `nil_composition_year.dta` coincide con DS205 negli anni 2011–2024 (rapporto = 1 in `nil_composition_check.csv`).
10. **Picco delle cancellazioni d'ufficio 2013–2014.** È il 42–46% delle cancellazioni (`cancellazioni_motivo_anno.csv`) e coincide con la revisione anagrafica post-censimento; questa interpretazione va verificata. Pesa su `r_emig` e potenzialmente su $NM^c$, non su `r_ac`.
11. **Linee guida del paper non trovate** nel repository: limite di parole e formato vanno controllati sul documento del corso. Il limite di 1.000–1.200 parole è applicato alle sezioni 1–2.
12. **Intestazione del master non aggiornata.** Per il modulo 18b l'intestazione di `00_master.do` riporta "soglia del 30%", in contrasto con il codice; da correggere in documentazione.
13. **Zona C14 (commit f4d35f2 su `main`).** Prima del 2018S2, nei NIL, all'area della C14 si attribuisce l'affitto della C12, da cui la C14 è stata ricavata. Nel 2018S2 i valori sono 15,0 € (C14) e 15,6 € (C12) al m²; per la C12 sono 15,2 € nel 2018S1. Così il NIL 9 (Porta Garibaldi) entra nel pannello bilanciato, che passa da 74 a 75 NIL, e sparisce il salto artificiale a Isola nel 2018S2. Le quote di residenti oltre soglia passano a 45,6% (2007), 27,1% (2018) e 43,2% (2024), contro i precedenti 45,4%, 26,8% e 42,9%: vanno aggiornate ovunque nel paper e nel documento del gruppo. È un'imputazione: se affitti di C14 e C12 differivano prima del 2018, l'errore ricade sui NIL 9 e Isola. A livello di zona (modulo 19) la C14 resta senza dati prima del 2018S2.
