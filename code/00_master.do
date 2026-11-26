*==============================================================================*
*  HOUSING AFFORDABILITY, GENTRIFICATION AND RESIDENTIAL OUTMIGRATION IN MILAN
*  00_master.do  -  imposta percorsi e parametri, poi esegue tutti i moduli
*
*  Requisiti: Stata 16 o successivo (usa i frame). Pacchetti SSC: boottest,
*  spmap, geoinpoly (installati automaticamente qui sotto se mancano).
*
*  Ordine dei moduli
*   01  IRPEF per CAP 2019-2024 (formato lungo -> CAP x anno)
*   02  Quotazioni OMI DS1996 (zona x semestre -> zona x anno)
*   03  DS205 quartieri 2011-2024 (NIL x anno, tassi di uscita)
*   03b Cancellazioni e iscrizioni per NIL e motivo, 2004-2024
*   04  DS1960 destinazioni e riconciliazione con DS205
*   05  File dell'indice del paper (88 NIL, 2011 e 2021)
*   06  CPI, redditi e quotazioni alle geografie native, contesto cittadino
*   07  Replica dell'indice, versione a scala comune, upgrading sociale
*   08  Tassi di uscita pre/post e composizione (NIL)
*   09  Primo modello NIL: upgrading 2011-21 e uscite 2022-24 (+ sensibilita')
*   10a Raccordi con pesi di superficie (griglia; richiede code/aux_geo_to_stata.py),
*       eseguito subito dopo il 05; 07b porta l'indice dai NIL 2012 ai NIL vigenti
*   10  Raccordo CAP-OMI-NIL (fornito oppure costruito dai civici DS634)
*   11  Pannello CAP integrato: affordability e modello delle variazioni
*   12  Pannello con effetti fissi, Poisson, eterogeneita'
*   13  Tabelle dei risultati e delle statistiche descrittive
*   14  Figure e mappe
*   15  Robustezza: correlazione redditi-prezzi, FE, scomposizioni, influenza
*   16  Modello M3 per il paper: tabelle, figura FWL, leave-one-out
*   17  Controllo della misura di affitto: OMI vs Immobiliare.it (31 macrozone)
*   18  Affordability per il cittadino tipico: affitto / reddito mediano di Milano
*   18b Reddito netto mediano (IRPEF, addizionali, bonus) e affordability sul netto
*       (ds531), soglia del 30%, NIL 2008-2024
*   19  Differenza nelle differenze sull'apertura della M4 (stazioni ds535)
*   20  Tipologia dei NIL per composizione dei residenti (eseguito prima del 19)
*   03c Composizione dei NIL e migrazione netta per eta' (ds27, ds1440, nascite)
*==============================================================================*

version 16
clear all
set more off
set varabbrev off
set linesize 160

*------------------------------------------------------------------------------*
* 1. PERCORSI  (modificare solo ROOT)
*------------------------------------------------------------------------------*
global ROOT "C:/Users/Salvatore/Downloads/milano_housing_stata/milano_housing"

global CODE "$ROOT/code"
global RAW  "$ROOT/data/raw"       // CSV originali
global GEO  "$ROOT/data/geo"       // shapefile (WGS84) e civici DS634, facoltativi
global AUX  "$ROOT/data/auxdata"       // cpi.csv e raccordi CAP-NIL / OMI-CAP
global WORK "$ROOT/data/work"      // file intermedi .dta
global TAB  "$ROOT/output/tables"
global FIG  "$ROOT/output/figures"
global LOGS "$ROOT/output/logs"

foreach d in "$ROOT/data" "$RAW" "$GEO" "$AUX" "$WORK" "$ROOT/output" "$TAB" "$FIG" "$LOGS" {
    capture mkdir "`d'"
}

*------------------------------------------------------------------------------*
* 2. NOMI DEI FILE
*------------------------------------------------------------------------------*
* IRPEF: il codice cerca <stub><anno>.csv e, se assente, <stub><anno> (1).csv
global F_IRPEF_STUB "redditi_e_principali_variabili_irpef_su_base_subcomunale_csv_"
global F_OMI        "ds1996_quotazioni_omi_compravendita_e_locazione_riepilogo.csv"
global F_OMIZONE    "zone_omi_2021_2.csv"
global F_DS205      "ds205_dati_quartieri_2011_2024_.csv"
global F_DS1960     "ds1960_popolazione_cancellazioni_evento_dest.csv"
global F_INDEX      "finaldataset_export_good.csv"
global F_CPI        "cpi.csv"

* Raccordi forniti dall'utente in $AUX (formato nel README). Se assenti, il
* modulo 10 prova a costruirli dai civici DS634 e dai poligoni CAP e OMI.
global F_XW_NILCAP       "xw_nil_cap.csv"
global F_XW_OMICAP       "xw_omi_cap.csv"
global F_XW_NILCAP_AREA  "xw_nil_cap_area.csv"     // facoltativo: pesi di superficie
global F_XW_OMICAP_AREA  "xw_omi_cap_area.csv"     // facoltativo: pesi di superficie

* Geometrie in $GEO: nome dello shapefile senza estensione (.shp e .dbf),
* coordinate in gradi WGS84 (EPSG:4326). Campo ID: vuoto = rilevamento automatico.
global SHP_NIL     "nil_milano"       // NIL vigenti (88 quartieri)
global SHP_NIL_ID  "id_nil"           // campo con il codice NIL
global SHP_OMI     "zone_omi_milano"  // perimetri OMI DS1997 (2021, 2 sem.)
global SHP_OMI_ID  ""                 // campo con il codice zona (es. B01)
global SHP_CAP     "CAPZONE_Milano"   // poligoni CAP (Poste Italiane, demo; WGS84)
global SHP_CAP_ID  ""                 // campo con il CAP
global F_CIVICI    "ds634_civici_coordinategeografiche.csv"   // CSV estratto dallo zip

*------------------------------------------------------------------------------*
* 3. PARAMETRI DELL'ANALISI  (fissarli prima di guardare i risultati)
*------------------------------------------------------------------------------*
global Y0        2019      // primo anno della finestra di affordability
global Y1        2023      // ultimo anno
global INC_SHIFT 0         // 0 = reddito all'anno d'imposta; 1 = reddito spostato
                           //     all'anno successivo (domicilio fiscale al 31/12
                           //     dell'anno di dichiarazione): sensibilita'
global Y0A = $Y0 + $INC_SHIFT   // primo anno con reddito disponibile
global S_MAIN    60        // superficie convenzionale principale (m2 lordi)
global S_LIST    "40 60 80"
global COVER_MIN 0.80      // quota minima del CAP coperta da zone OMI quotate
global SMALL_NIL 500       // soglia dei NIL piccoli (residenti 2019): esclusi dal campione principale NIL
global XW_NILCOV 0.80      // copertura minima per portare un valore dai NIL 2012 ai NIL vigenti
global W_PAPER   "0.42772 0.39892 0.24167 0.32761"   // reddito prezzi istruzione occupazione
global REAL_HIST 1         // 1 = converte reddito e prezzi 2021 a prezzi 2011 nella
                           //     versione a scala comune (se CPI 2011 e 2021 presenti)
global BOOTREPS  9999      // repliche wild cluster bootstrap
global SEED      20261119

*------------------------------------------------------------------------------*
* 4. COLONNE DEL FILE DELL'INDICE  (DA COMPILARE dopo il primo run)
*    Il modulo 05 stampa nome Stata, intestazione originale e un valore di
*    esempio per ogni colonna (anche in output/tables/index_codebook.csv).
*    Inserire qui i NOMI STATA (minuscoli). Finche' i campi obbligatori sono
*    vuoti, i moduli 07 e 09 vengono saltati e il resto gira comunque.
*------------------------------------------------------------------------------*
global IX_ID      "id_nil"                  // codice NIL (numerico, deve coincidere con DS205)
global IX_NAME    "nil"                     // nome del NIL
global IX_INC11   "avg_income11x"           // reddito 2011 (valore grezzo, non trasformato)
global IX_INC21   "avg_income21x"           // reddito 2021
global IX_PRICE11 "compr_max11x"            // valori immobiliari 2011
global IX_PRICE21 "compr_max21x"            // valori immobiliari 2021
global IX_EDU11   "census_edu11x"           // istruzione 2011
global IX_EDU21   "census_edu21x"           // istruzione 2021
global IX_EMP11   "census_employment11x"    // occupazione 2011
global IX_EMP21   "census_employment21x"    // occupazione 2021
global IX_IDX11   "compounded_indicator11"  // indice pubblicato 2011
global IX_IDX21   "compounded_indicator21"  // indice pubblicato 2021
* facoltativi
global IX_DELTA   "delta_gent"              // variazione pubblicata
global IX_GEOM    "geometry_x"              // geometria WKT
global IX_ZINC11  "avg_income11y"           // colonne ".y" gia' trasformate, per confronto
global IX_ZINC21  "avg_income21y"
global IX_ZPRICE11 "compr_max11y"
global IX_ZPRICE21 "compr_max21y"
global IX_ZEDU11  "census_edu11y"
global IX_ZEDU21  "census_edu21y"
global IX_ZEMP11  "census_employment11y"
global IX_ZEMP21  "census_employment21y"

*------------------------------------------------------------------------------*
* 5. PACCHETTI, PROGRAMMI, FRAME DEI RISULTATI
*------------------------------------------------------------------------------*
foreach p in boottest spmap geoinpoly {
    capture which `p'
    if _rc {
        di as txt "Installo `p' da SSC..."
        capture noisily ssc install `p', replace
    }
}

do "$CODE/00_programs.do"

capture frame drop results
frame create results str244 model str244 spec str60 coef double b double se ///
    double lb double ub double p double p_boot double lb_boot double ub_boot ///
    long N str20 cmd str244 note

* indicatori di disponibilita' (aggiornati dai moduli)
global IX_OK     0
global CPI_OK    0
global SHP_OK    0
global XW_OK     0
global NILNEW_OK 0
global MOVES_OK  0
global CAPSHP_OK 0
global XW_VERSIONS ""

*------------------------------------------------------------------------------*
* 6. ESECUZIONE
*------------------------------------------------------------------------------*
capture log close _all
log using "$LOGS/milano_housing.log", replace text name(main)

di as txt "Avvio: `c(current_date)' `c(current_time)'  -  Stata `c(stata_version)'"

do "$CODE/01_import_irpef.do"
do "$CODE/02_import_omi.do"
do "$CODE/03_import_ds205.do"
do "$CODE/03b_import_moves.do"     // cancellazioni/iscrizioni per motivo (DS1600/1956/1596/1954)
do "$CODE/03c_nil_composition.do"  // composizione per eta'/cittadinanza e migrazione netta per coorte (ds27, ds1440, nascite)
do "$CODE/04_import_ds1960.do"
do "$CODE/05_import_index.do"
do "$CODE/06_affordability_native.do"
do "$CODE/10a_crosswalk_area.do"   // raccordi di superficie: CAP, OMI, NIL vigenti e NIL 2012
do "$CODE/07_gentrification.do"
do "$CODE/07b_nil_vigenti.do"      // misure dell'indice dai NIL 2012 ai NIL vigenti
do "$CODE/08_outmigration.do"
do "$CODE/09_model_nil.do"
do "$CODE/10_crosswalk.do"
do "$CODE/11_integrated_cap.do"
do "$CODE/12_panel_fe.do"
do "$CODE/13_tables.do"
do "$CODE/14_figures.do"
do "$CODE/15_robustness.do"
do "$CODE/16_m3_paper.do"
do "$CODE/17_immobiliare_check.do"   // controllo: affitti OMI vs Immobiliare.it (macrozone)
do "$CODE/18_affordability_milano.do" // affordability sul reddito netto mediano, soglia 40% (OCSE), NIL 2007-2024; controllo 30% del lordo dal 2004
do "$CODE/18b_income_net.do"          // reddito netto mediano (scenari di detrazione) e soglia OCSE del 40% sul netto
do "$CODE/20_nil_typology.do"        // tipologia dei NIL per composizione dei residenti (2014)
do "$CODE/19_m4_did.do"              // differenza nelle differenze: apertura della M4 (usa 03c e 20)
do "$CODE/19b_m4_robustness.do"      // M4: potenza del test, senza un'area trattata, raggio e soglia
do "$CODE/19c_m4_cantieri.do"        // M4: anticipazione, trattamento dall'inizio dei cantieri (NIL)
do "$CODE/19d_m4_dose.do"            // M4: esposizione continua (quota dell'area servita di nuovo)
do "$CODE/19e_m4_sdid.do"            // M4: synthetic difference-in-differences (pacchetto sdid)
do "$CODE/19f_m4_daniele_romito.do"  // M4: controlli di Daniele e Romito (centroide 1 km, fascia 1-2 km, controllo sintetico per zona)
do "$CODE/19g_m4_tabella_stime.do"   // M4: tabella unica delle stime (IC95, inferenza, campioni, periodi) e date di trattamento

di as txt _n "Fine: `c(current_date)' `c(current_time)'"
di as txt "Moduli eseguiti con:  indice=" $IX_OK "  CPI=" $CPI_OK "  shapefile NIL=" $SHP_OK ///
    "  raccordo=" $XW_OK " ($XW_VERSIONS)"
log close main
