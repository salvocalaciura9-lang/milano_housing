# Housing Affordability, Gentrification and Residential Outmigration in Milan — codice Stata

Codice per l'analisi descritta in *Milano_Research_Proposal.docx*. Stata 16 o successivo.

## 0. Repository

Il repository contiene codice, dati grezzi (`data/raw`), file intermedi (`data/work`) e
output. Due file superano il limite di 100 MB di GitHub e sono esclusi (`.gitignore`):

| File | Fonte | Usato da |
|---|---|---|
| `ds27_pop_sto_quartiere.csv` | Open Data Comune di Milano, dataset ds27 (residenti per età, cittadinanza e NIL) | modulo 03c; senza il file il modulo si salta, ma il suo output `data/work/nil_composition_year.dta` è già nel repository |
| `ds1441_popolazione_famiglie_tipologia_quartiere.csv` | Open Data Comune di Milano, dataset ds1441 | nessun modulo |

Per rieseguire 03c, scaricate ds27 dal portale Open Data del Comune e copiatelo in
`data/raw/` con questo nome. Le analisi richiedono Stata: in una sessione cloud si
possono leggere e modificare codice e testi, non eseguire i do-file.

## 1. Preparazione

1. In `code/00_master.do` imposta `global ROOT` sulla cartella del progetto.
2. Copia i file originali in `data/raw/` con i nomi della proposta:
   - `redditi_e_principali_variabili_irpef_su_base_subcomunale_csv_2019.csv` … `_2023.csv` e `_2024 (1).csv`
   - `ds1996_quotazioni_omi_compravendita_e_locazione_riepilogo.csv`
   - `zone_omi_2021_2.csv` (facoltativo)
   - `ds205_dati_quartieri_2011_2024_.csv`
   - `ds1960_popolazione_cancellazioni_evento_dest.csv`
   - `finaldataset_export_good(2).csv`
   Se i nomi sono diversi, cambiali nella sezione 2 del master.
3. Esegui `do code/00_master.do`. Pacchetti SSC installati se mancano: `boottest`, `spmap`, `geoinpoly`.

## 2. Primo run: colonne del file dell'indice

Le intestazioni del file del paper non sono documentate. Al primo run il modulo 05
stampa per ogni colonna **nome Stata | intestazione originale | valore di esempio**
(anche in `output/tables/index_codebook.csv`). Inserisci i nomi Stata nella sezione 4
del master (`IX_ID`, `IX_INC11`, … `IX_IDX21`) e rilancia. Finché mancano, i moduli
07 e 09 vengono saltati e tutto il resto gira.

Per i componenti servono i **valori grezzi** (non le colonne `.y`, già trasformate per
anno). Le colonne `.y` si possono indicare in `IX_Z*` per un confronto con la replica.

## 3. Dati facoltativi

| File | Cartella | A cosa serve |
|---|---|---|
| `cpi.csv` (già incluso: FOI senza tabacchi, base 2015=100) | `data/auxdata` | benchmark reddituale iniziale reale; 2011–2021 in termini reali |
| `xw_nil_cap.csv` (`nil,cap,w`, somma di w = 1 per NIL) | `data/auxdata` | raccordo NIL→CAP fornito da università o Comune |
| `xw_omi_cap.csv` (`zona,cap,w`, somma di w = 1 per CAP, incluse zone senza quotazioni) | `data/auxdata` | raccordo zona OMI→CAP |
| `xw_nil_cap_area.csv`, `xw_omi_cap_area.csv` | `data/auxdata` | sensibilità con pesi di superficie (calcolati in GIS) |
| shapefile NIL (`nil_milano.shp/.dbf`) | `data/geo` | mappe NIL, Moran, errore spaziale |
| shapefile CAP e OMI DS1997 + CSV dei civici DS634 (estratto dallo zip) | `data/geo` | costruzione automatica del raccordo con `geoinpoly` |

Gli shapefile devono essere in gradi WGS84 (EPSG:4326). Se non lo sono, riproiettali in
QGIS. I nomi e il campo identificativo si impostano nella sezione 2 del master; se il
campo è vuoto, il codice cerca da solo la colonna con valori del tipo 201xx (CAP) o
B01/C13/R2 (zone OMI).

Senza raccordo, i moduli 11 e 12 vengono saltati: restano le analisi alle geografie
native, come previsto dalla proposta.

## 4. Moduli e output principali

| Modulo | Contenuto | Output |
|---|---|---|
| 01 | IRPEF per CAP, normalizzazione delle voci, controlli (media 34.226,60 → 39.070,87; quota 0–15k 33,17% → 29,42% → 28,06%) | `irpef_cap_year.dta` |
| 02 | OMI: abitazioni civili NORMALE, 39 zone × 10 semestri, C13, cambi di codice 2024 | `omi_zone_year.dta`, `omi_zone_s1.dta` |
| 03 | DS205: tassi per 1.000, quote, controllo Adriano 34,44 | `ds205_nil_year.dta` |
| 04 | DS1960: destinazioni, N.D. 15,61% e 7,12%, riconciliazione con DS205 | tabella destinazioni |
| 05 | Indice del paper: codebook, valori sospetti, ID 73–74 | `index_nil.dta` |
| 06 | Redditi e quotazioni alle geografie native, numero vs quota, contesto cittadino | tabelle `cap_fiscal_change`, `omi_zone_change`, `city_context` |
| 07 | Replica indice (quantili tipo R), PCA, scala comune 2011, upgrading sociale, classificazione | `gentrif_nil.dta` |
| 08 | Tassi pre 2017–19 e post 2022–24, composizione | `outmig_nil.dta` |
| 09 | Modello NIL e sensibilità, Moran, errore spaziale | stime in `results_all.xlsx` |
| 10 | Raccordo CAP–OMI–NIL (fornito o costruito), controlli di copertura | `xw_*.dta` |
| 11 | Affordability CAP (affitto, acquisto, benchmark iniziale, min/max, lavoro, 40/60/80 m²), modello delle variazioni | `cap_panel_*.dta`, `cap_cross_*.dta` |
| 12 | Effetti fissi CAP e anno, wild cluster bootstrap, t+2, anni pandemici, Poisson, eterogeneità | stime |
| 13 | Tabelle di stime, sensibilità, descrittive | `output/tables` |
| 14 | Figure e mappe | `output/figures` |

Tutte le stime finiscono in `output/tables/results_all.xlsx` con coefficiente, IC 95%,
N, p bootstrap (dove calcolato) e una colonna che indica se il segno coincide con la
specificazione principale.

## 5. Cose da sapere

- Il codice non è stato eseguito: i dati non erano disponibili quando è stato scritto. Le
  intestazioni di IRPEF, OMI, DS205, DS1960 e DS634 sono state verificate sul portale del
  Comune; il file dell'indice e gli shapefile no. Leggi il log (`output/logs`) al primo run:
  le righe `[OK]` / `[DIVERSO]` confrontano i risultati con i valori riportati nella proposta.
- I parametri (superficie, soglia di copertura, soglia dei NIL piccoli, `INC_SHIFT`) vanno
  fissati prima di guardare le stime.
- Le stime sono associazioni. Le uscite osservate non sono displacement misurato.
