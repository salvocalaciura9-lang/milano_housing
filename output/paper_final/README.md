# Paper finale: progetto LaTeX (template PNAS)

Contenuto della cartella:

| File | Cosa contiene |
|---|---|
| `main.tex` | paper completo, struttura IMRaD, classe `pnas-new`, `\templatetype{pnasresearcharticle}` |
| `references.bib` | bibliografia, stile numerico PNAS; le voci incomplete hanno una nota `TO COMPLETE` o `VERIFY` |
| `figures/` | Fig. 1 e 2 (dalla bozza Word del gruppo) e Fig. 3 (event study M4, `output/figures/m4_cs_event_rent_en.png`) |
| `significance_statement_DRAFT.txt` | bozza della Significance Statement richiesta dal template, da approvare |
| `RESOCONTO_MODIFICHE.md` | resoconto delle modifiche e dei punti aperti (non fa parte del paper) |

## Come compilare su Overleaf

I file di classe ufficiali (`pnas-new.cls`, `pnasresearcharticle.sty`, `pnas-new.bst`, `widetext.sty`, loghi) non sono inclusi: si ottengono solo aprendo il template ufficiale.

1. Apri il template ufficiale PNAS 2025 e clicca "Open as Template":
   https://www.overleaf.com/latex/templates/template-for-preparing-your-research-report-submission-to-pnas-using-overleaf-2025/whbdryzwztnd
2. Nel progetto creato carica `main.tex`, `references.bib` e la cartella `figures/`.
3. Dal menu di Overleaf imposta `main.tex` come file principale (il template usa `Research_report.tex`). Puoi cancellare il vecchio file principale, `pnas-sample.bib` e le immagini della rana.
4. Compila con pdfLaTeX (il default del template).

Il documento non è stato compilato in locale perché su questo computer non c'è una distribuzione LaTeX. Ho controllato la struttura con uno script:
- ambienti e parentesi bilanciati;
- nessun riferimento indefinito;
- tutte le citazioni presenti nel `.bib`;
- figure presenti;
- Abstract e Literature Review identici alla bozza.
