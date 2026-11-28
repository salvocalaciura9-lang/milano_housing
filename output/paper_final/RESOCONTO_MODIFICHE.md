# Resoconto delle modifiche (non fa parte del paper)

**Fonte di partenza.** Nel messaggio non c'era un allegato. Ho usato il documento più recente nella cartella Download, `Housing affordability Milan (1).docx` (modificato il 28/11/2026 alle 17:24). Contiene:
- titolo, domande di ricerca, Abstract, Introduction e Literature Review;
- Data & Methodology;
- Results sull'affordability, con Fig. 1–2 e Tabelle 1–2;
- la "M4 Draft Section".

Se l'allegato era un altro file, va controllato.

## 1. Riorganizzazione delle sezioni (IMRaD, Methods prima di Results)

| Sezione nel `main.tex` | Contenuto | Da dove viene |
|---|---|---|
| Abstract | testo invariato | docx |
| Introduction | motivazione, 3 domande di ricerca riformulate, sintesi dei risultati, schema del paper | docx (Introduction + Research Question) e intro M4, riscritte e unite |
| └ Literature Review | testo invariato, con i titoli 2.1 / 2.2 / 2.4 | docx |
| Methods | due geografie (NIL e zone OMI) e perché; fonti; affitti per NIL (Eq. 1); reddito mediano netto (Eq. 2); indice (Eq. 3); M4: panel, esposizione, tempi (Tab. 1), controlli abbinati, stimando e identificazione, Callaway–Sant'Anna ed event study (Eq. 4–6), permutazioni, IC per inversione, banda sup-t, MDE (Eq. 7), robustezza e SDID | docx (Data & Methodology) + sezione M4 verificata |
| Results | quota di NIL fuori portata (Fig. 1); geografia e quartili (Fig. 2, Tab. 2); scenari di famiglia (Tab. 3); sintesi degli scenari fiscali; M4: stima principale, event study (Fig. 3), quattro implicazioni della robustezza | docx (Results) + M4 |
| Discussion | affordability (interpretazione e limiti); M4 (interpretazione e sei limiti); Conclusion come sottosezione; disponibilità dei dati | docx (Limitations / Conclusion M4) + parti nuove sull'affordability |
| References | `references.bib`, stile numerico PNAS | — |
| Appendix (SI) | Tab. S1 controlli alternativi; TWFE; Tab. S2 robustezza; Tab. S3 SDID; altri outcome (prezzi, uscite); Tab. S4 scenari fiscali | M4 + modulo 18b |

**Note sulla struttura:**
- Il template PNAS mette Materials and Methods in fondo con `\matmethods{}`. Non l'ho usato: Methods è una sezione normale subito dopo l'Introduction, come chiede la prof.
- PNAS suggerisce di non scrivere il titolo "Introduction". L'ho tenuto per rispettare l'IMRaD.

## 2. Analisi incluse ed escluse

**Incluse** (confermate dalla bozza e dalle scelte prese insieme):
- indice di affordability per NIL 2015–2024, 75 NIL;
- scenari di famiglia (40 m², due redditi);
- scenari fiscali, in appendice;
- M4 sugli affitti: Callaway–Sant'Anna con controlli abbinati, event study, permutazioni, IC per inversione, MDE;
- controlli alternativi, TWFE, robustezza e SDID, in appendice;
- prezzi e uscite: un paragrafo in appendice senza tabella, come già concordato.

**Escluse:**
- **raccordo e analisi per CAP** (moduli 10, 11, 12, 15, 16 e le figure/tabelle per CAP): scartati, non compaiono da nessuna parte;
- **serie 2004–2013** e **anno 2014** dell'indice: tolti dalla pipeline;
- **indice di gentrification** e tipologie NIL (moduli 07, 07b, 09, 20): la tipologia serve solo all'abbinamento dei NIL nell'analisi sulle uscite;
- **affordability "native" per zone OMI 2019–2023** (modulo 06) e **confronto con Immobiliare.it** (modulo 17): non sono nella bozza;
- **M4:**
  - esposizione continua (dose, 19d);
  - trattamento dall'inizio dei cantieri (19c);
  - protocollo Daniele–Romito e controllo sintetico per zona (19f), citati solo come letteratura;
  - misure demografiche per coorte (03c, saldi per età);
- **"cohort population changes"** citate nel paragrafo sui dati demografici della bozza: nessun risultato le usa, quindi le ho tolte.

## 3. Incoerenze risolte rispetto alla bozza

1. **Periodo e campione dell'indice.** La sezione dati diceva 2014–2024 e 825 osservazioni, con il 2014 basato solo sul 2014S2 e una "serie 2004–2013 tenuta a parte". I Results usavano già il 2015–2024. Ora è tutto 2015–2024: 75 NIL, 750 osservazioni. La serie 2004–2013 non c'è più.
2. **Reddito.** Il testo citava DS531 2008–2024, l'estensione MEF 2004–2007 e la verifica sulle imposte "2004–2011". Ora indica gli anni d'imposta 2015–2024 e la verifica su DS312. Ho aggiunto il confronto numerico: aliquota media simulata circa 31%, effettiva circa 27%.
3. **Intervallo di confidenza M4.** La bozza M4 riportava [−10,4%, +1,7%] e diceva che si otteneva "invertendo il test" come ATT ± c. In realtà quella è l'approssimazione. Nel paper c'è l'inversione esatta del test, [−9,7%, +2,2%] (`output/tables/m4_ci_inversion.csv`). L'approssimazione è usata solo per l'event study e i controlli secondari, ed è dichiarata.
4. **Garanzie dell'inferenza.** La bozza diceva che il test "remains valid with few treated units" ed è "exact under its assumptions". Ora il testo dice che l'esattezza vale solo sotto scambiabilità delle date di apertura, che è un'ipotesi, e che il test è condizionato al campione abbinato.
5. **TWFE.** La bozza lo descriveva nel corpo del testo. Ora è in appendice, con il campione corretto (5 trattate e 20 mai esposte), l'intervallo cluster e il motivo del divario: il periodo di riferimento, non lo scaglionamento.
6. **Uscite.** La bozza diceva "neither shows a robust effect" senza dire che con 800 m e con soglia 10% la stima diventa significativa (p = 0,008). Ora è scritto.
7. **Domande di ricerca.** La bozza parlava di reddito "disponibile medio dei residenti". L'indice usa il reddito netto simulato del contribuente mediano: le domande sono riformulate così.
8. **Unità geografiche.** Il Methods spiega perché l'affordability è per NIL e la M4 per zone OMI, e che il contrasto in log affitto equivale a quello in log affitto/reddito.
9. **Revisione 2024 delle zone OMI.** Descritta esplicitamente, con la nota che non tocca il campione M4.
10. **Refusi corretti fuori da Abstract e Literature Review:** "mititgating"; "Pta Romana" diventa "Porta Romana".

Tutti i numeri sono ricontrollati sugli output:
- `aff_nil_year.csv`, `aff_city_year.csv`, `aff_net_city_year.csv`, `income_net_*.csv`;
- `m4_estimates_all.csv`, `m4_ci_inversion.csv`, `m4_event_study.csv`.

## 4. Problemi da verificare

**A. Incoerenze tra Abstract / Literature Review e analisi finali.** Le segnalo soltanto, non ho toccato il testo.
1. L'Abstract parla di confronto tra "neighbourhoods" vicini alle stazioni M4. La stima M4 è su **zone OMI**, non su NIL.
2. L'Abstract dice "The analysis will inform…", al futuro, mentre i risultati ci sono già.
3. La Literature Review descrive Banca d'Italia (2026) con il **reddito netto medio**. Il nostro indice usa la **mediana** simulata, e la frase "Our index adapts this approach" non dice che la misura cambia.
4. La Literature Review salta da **2.2 a 2.4**: manca la 2.3. Inoltre i numeri 2.x restano nei titoli anche se la Literature Review ora è una sottosezione dell'Introduction.
5. Refuso nella Literature Review: "a limitation acknowledge" invece di "acknowledged".
6. La Literature Review cita in formato **autore-anno, come testo semplice**. Per non modificarla non ho usato `\cite`: le voci sono nella bibliografia con `\nocite`, ma nel testo non c'è il numero. Il resto del paper usa i numeri PNAS. Questa disomogeneità si risolve solo se il gruppo accetta di modificare la Literature Review.

**B. Bibliografia incompleta.** Non ho inventato dati:
- mancano titolo e sede per Banca d'Italia (2026), Scottish Government (2019), Bricocoli & Peverini (2024), Bricocoli, Peverini & Caresana (2025), Melser (2020), Bortolotti & Grassi (2025), Daniele & Romito (2022);
- per Zheng & Kahn (2013) non è chiaro quale articolo sia;
- le voci con nota `VERIFY` vengono dalla memoria: volume e pagine vanno controllati;
- gli URL dei dataset del Comune vanno aggiunti.

**C. Front matter da completare:**
- affiliazioni, autore principale (ho messo Calaciura, da confermare), autore corrispondente, contributi, dichiarazione sui conflitti d'interesse, classificazione PNAS;
- la Significance Statement è in `significance_statement_DRAFT.txt`, da approvare;
- nel `main.tex` `\significancestatement{}` è vuoto: se il template stampa un riquadro vuoto, va incollata la versione approvata.

**D. Compilazione.** Non ho potuto compilare: in locale non c'è LaTeX e i file di classe PNAS si ottengono solo aprendo il template su Overleaf. Lo script di controllo non ha trovato errori. Su Overleaf vanno controllati soprattutto:
- la Tab. 2 dei quartili (38 righe, larghezza piena) e l'impaginazione dell'appendice dopo la bibliografia;
- che `booktabs` non entri in conflitto con la classe (l'ho caricato esplicitamente).

**E. Figure.**
- Fig. 1 e 2 sono prese dal docx: non ho trovato nel repo lo script che le produce. Conviene caricare gli originali ad alta risoluzione, meglio se PDF, come chiede la PNAS.
- La Fig. 3 viene da `output/figures/m4_cs_event_rent_en.png`.

**F. Lunghezza.** Il testo principale è di circa 6.000–6.500 parole più le tabelle. È sopra lo standard PNAS di circa 4.000 parole per 6 pagine, ma sotto il massimo di 12 pagine. Se la prof chiede un limite, i primi candidati da accorciare sono la Tab. 2 dei quartili e la descrizione dell'inferenza.
