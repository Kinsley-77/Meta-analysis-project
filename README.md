# LLM-assisted moderator extraction for ecological meta-analysis

Code for the thesis validating LLM (GPT-5.5) extraction of meta-analysis moderator
variables against manual coding, using a systematic review of flower and
wildflower interventions on pollinators / natural enemies.

**Note on version history:** this repository was created on 2026-08-14 by
consolidating scripts that had previously been kept as separate dated files
on a local machine. It does not contain the original development history of
the prompt or analysis code -- commits from this point onward reflect real
changes, but earlier iterations are not individually recorded here. Several
early/draft scripts are kept in the repo (clearly labelled) rather than
deleted, so the record of what was tried is honest rather than tidied up
after the fact.

## Structure

```
prompts/
  prompts_final.R                        # final, frozen extraction prompt (row-level + binary task)

extraction/
  run_extraction_dev_set.R               # FINAL: produced meta_analysis_run1.csv (the run reported
                                          # in Results 4.1 for the 30-paper development set)
  run_extraction_validation_set.R        # same script, re-pointed at the 20-paper validation set;
                                          # produced test_set_20_results.csv
  recheck_truncated_3.R                  # sensitivity check: re-extracts the 3 papers over 120,000
                                          # characters using full text (no truncation)
  extract_meta_analysis_EARLY_PROTOTYPE.R # EARLY DRAFT, superseded -- used gpt-4o-mini, a simpler
                                          # field-level output format, and a placeholder (not final)
                                          # controlled vocabulary. Kept for the record only.

analysis/R/
  compare_to_manual_v2.R                 # match/partial/no-match + Cohen's kappa + bootstrap 95% CI,
                                          # matched by study_ID lookup (surname + year)
  compare_to_manual_EARLY_DRAFT.R        # EARLY DRAFT, superseded -- matched by surname only, no
                                          # study_ID; produced the stale agreement_report.csv (23
                                          # papers), which is NOT the source of Results 4.1's numbers
  jaccard_analysis.R                     # FINAL Jaccard similarity, dev (n=30) + validation (n=20),
                                          # matched by surname + year
  jaccard_validation_set_DRAFT.R         # EARLY DRAFT of the validation-set Jaccard calculation,
                                          # superseded by jaccard_analysis.R -- contains an
                                          # undefined-variable bug (`print(overall)`); see the
                                          # comment at the top of the file
  table2_kappa_dev_and_validation.R      # compact script: kappa + bootstrap CI for dev AND
                                          # validation sets in one run, matched by filename "ID-<n>"
                                          # pattern + a manual override list (NOT surname/year --
                                          # see note below)
  confusion_intervention_L3_FINAL.R      # intervention_level_3 confusion matrix, validation set,
                                          # matched by filename "ID-<n>" + manual override list
  figures/
    figure1_agreement_dev.R              # ggplot bar chart: match/partial/no-match, dev set
    figure2_agreement_validation.R       # ggplot bar chart: match/partial/no-match, validation set
    figure_kappa_forest.R                # ggplot forest plot: kappa + CI, dev vs validation

analysis/verification_python/
  # Independent Python re-implementations used to cross-check the R analysis
  # above against the numbers already reported in the thesis (Table 2, Results 4.1).
  jaccard_repro.py         # reproduces jaccard_analysis.R
  match_partial_nomatch.py # reproduces compare_to_manual_v2.R's match/partial/no-match logic
  confusion_matrix.py      # intervention_level_3 confusion matrix, validation set
  complexity_analysis.py   # effect-size count vs extraction accuracy (exploratory)
  exact_match_summary.py   # per-field exact-match %, dev vs validation
  make_figures.py          # renders the three PNGs in figures/

figures/
  Figure_jaccard_by_field.png            # mean Jaccard by field, dev vs validation
  Figure_confusion_intervention_L3.png   # confusion matrix heatmap, validation set (n=20)
  Figure_complexity_vs_accuracy.png      # effect-size count vs mean Jaccard, all 50 papers
```

## Two matching methods -- cross-checked, they agree

Two different methods are used across these scripts to match validation-set
(20-paper) AI results to the manual gold standard:

1. **Author surname + year** (used by `jaccard_analysis.R`, `compare_to_manual_v2.R`,
   `jaccard_validation_set_DRAFT.R`) -- matches by parsing the author's surname
   and publication year out of both the AI's `paper_id` and the manual
   workbook's `author`/`year` columns.
2. **Filename "ID-<n>" pattern + manual override list** (used by
   `table2_kappa_dev_and_validation.R` and `confusion_intervention_L3_FINAL.R`,
   the script explicitly named "FINAL") -- matches by an ID embedded in the
   PDF filename, with 8 papers that lack this pattern mapped by hand.

**Verified 2026-08-14:** running both methods against the real
`test_set_20_results.csv` and the manual workbook, all 20 papers resolve to
the identical `study_ID` under both approaches. So Table 2's Jaccard numbers
(method 1) and the confusion matrix / kappa numbers (method 2) are built on
the same 20-paper correspondence -- the two code paths are redundant, not
inconsistent.

## Data

Raw data (AI extraction CSVs, the manual gold-standard Excel workbooks) are
**not included** in this repository. The manual data-extraction spreadsheet
was designed by Alexa Varah as part of a larger, not-yet-published systematic
review; check with her / the project team before deciding whether and how to
share it publicly. Scripts expect the following files in the same folder
(paths are set at the top of each script and will need editing):

- `meta_analysis_run1.csv`, `meta_analysis_extracted_results30.csv`, `test_set_20_results.csv` — AI extraction output
- `dev_set_30.xlsx` (30 papers), `test_set_20.xlsx` (20 papers), sheet `data_extraction` — manual gold standard

## Reproducing the figures

```r
# from analysis/R/
source("jaccard_analysis.R")                     # prints Jaccard means for Table 2
source("confusion_intervention_L3_FINAL.R")      # prints confusion matrix + saves heatmap PNG
source("figures/figure1_agreement_dev.R")        # match/partial/no-match bar chart, dev set
source("figures/figure2_agreement_validation.R") # match/partial/no-match bar chart, validation set
source("figures/figure_kappa_forest.R")          # kappa forest plot, dev vs validation
```
