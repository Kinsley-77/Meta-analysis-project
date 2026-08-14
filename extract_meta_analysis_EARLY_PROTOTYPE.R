
# EARLY PROTOTYPE -- ecological meta-analysis paper extraction script
# An early draft of the extraction pipeline, superseded by
# extraction/run_extraction_dev_set.R. Kept for the record: it used
# gpt-4o-mini (not gpt-5.5).


#load packages
library(openai)
library(pdftools)
library(jsonlite)
library(dplyr)

# Read the API key 
stopifnot(Sys.getenv("OPENAI_API_KEY") != "")

# Folder containing the paper PDFs
pdf_folder <- "/Users/wangyuqi/Desktop/test_30 paper"

# Output path for results
output_csv <- "/Users/wangyuqi/Desktop/test_30 paper/meta_analysis_extracted_results.csv"


#Part 2: prompt template
extraction_prompt <- r"(
Extract the following four fields from the attached paper. You are simulating an experienced
human coder for a systematic ecological meta-analysis. Your job is NOT to summarize the paper.
Your job is to assign standardized codes to fixed fields, exactly as a trained meta-analysis
coder would, following the coding rules below. When the paper's language doesn't map cleanly
onto a standardized category, choose the closest matching category from the controlled
vocabulary — do not invent a free-text description, and do not return a multi-clause sentence
as a value.

FIELD 1: taxon_common
Definition: The most specific focal taxonomic group that is the actual subject of data
collection/analysis (the organisms whose abundance, diversity, or behavior was measured as
a response variable) — NOT background or contextual taxa mentioned in the introduction.
Rules:
- Use the finest taxonomic resolution explicitly studied, formatted as
  "[broad group] - [specific common name]", e.g. "flies - hoverflies", "bees - bumblebees",
  "beetles - ground beetles".
- Do NOT use broad functional/ecological umbrella terms (e.g. "pollinators", "natural
  enemies", "insects") as the final answer. These are aggregator terms, not focal taxa.
- If multiple specific taxa were studied with equal weight, separate with ";".
- If a single named species was studied, give the species (plus common name if available).

FIELD 2: sampling_method
Definition: The physical technique or instrument used to capture, trap, or observe the
focal organisms. NOT the spatial layout, plot size/shape, replicate count, or survey design.
Rules:
- Map to the closest term from this canonical list: sweep net, pan trap, pitfall trap,
  pollard walk / transect survey, vane trap, malaise trap, light trap, direct observation /
  timed count, hand collection, sticky trap [extend list as relevant to your taxa].
- Plot dimensions, number of plots, transect length, and sampling frequency describe
  sampling DESIGN, not METHOD — do not report them in this field.
- If multiple methods were used, list all separated by ";", in order of appearance.

FIELD 3: intervention_level_3
Definition: The standardized intervention category (Level 3) that the studied treatment
maps onto — NOT a verbatim description of the treatment as written by the paper's authors.
Controlled vocabulary: [INSERT YOUR LEVEL 3 CATEGORY LIST HERE, e.g. "Wildflower strips",
"Hedgerow planting/restoration", "Reduced mowing frequency", "Reduced grazing intensity",
"Organic farming", "Beetle banks", "Set-aside/fallow land", ...]
Rules:
- Map the described intervention onto exactly ONE category from the list above.
- If the paper combines two interventions corresponding to two separate categories (e.g.
  reduced mowing + flower sowing), select the category matching the PRIMARY intervention
  stated in the paper's aim/hypothesis, and note the secondary intervention in
  Supporting_Evidence rather than in Extracted_Value.
- If no category fits, return "Other - [3-5 word description]" rather than a long sentence.

FIELD 4: description_of_control
Definition: Only populate this field if the control treatment is non-standard, ambiguous,
or needs clarification beyond what the intervention category already implies.
Rules:
- If the control is simply "conventional/standard management" (i.e. absence of the Level 3
  intervention, with no further distinguishing detail needed), return NA — absence of the
  intervention is already implied by the intervention field.
- Only describe the control if it is itself a distinct, active alternative treatment
  (not merely "no intervention").
- When in doubt, prefer NA, consistent with standard meta-analysis convention of recording
  controls only when they add information beyond "did not receive treatment."

For each field, return:
- Extracted_Value (a standardized code per the rules above — never a full sentence)
- Supporting_Evidence (≤25 words, the textual basis for the choice)
- Confidence (High/Medium/Low — use Low whenever mapping required a judgment call or the
  controlled vocabulary had no good fit)

Use only information explicitly reported in the paper. Do not infer unstated information.

Return ONLY a valid JSON array, no explanation, no preamble, no markdown code fences:
[
  {"field": "taxon_common", "extracted": "...", "supporting_evidence": "...", "confidence": "..."},
  {"field": "sampling_method", "extracted": "...", "supporting_evidence": "...", "confidence": "..."},
  {"field": "intervention_level_3", "extracted": "...", "supporting_evidence": "...", "confidence": "..."},
  {"field": "description_of_control", "extracted": "...", "supporting_evidence": "...", "confidence": "..."}
]
)"


#Part 3: core function

extract_one_paper <- function(pdf_path) {

  paper_id <- basename(pdf_path)
  message("Processing: ", paper_id)

  # Read PDF text
  paper_text <- pdf_text(pdf_path)
  paper_text <- paste(paper_text, collapse = "\n")

  # the API
  response <- create_chat_completion(
    model = "gpt-4o-mini",
    messages = list(
      list(role = "system", content = "You are an expert ecological meta-analysis coder."),
      list(role = "user", content = paste(extraction_prompt, "\n\nPaper text:\n", paper_text))
    ),
    temperature = 0   ## set to 0 to reduce formatting randomness, more stable across a batch
  )

  result_text <- response$choices$message.content

  # Clean up
  result_text <- gsub("```json|```", "", result_text)
  result_text <- trimws(result_text)

  # Defensive fix: NA/High/Medium/Low values
  result_text <- gsub(':\\s*NA\\s*([,}])', ': "NA"\\1', result_text)
  result_text <- gsub(':\\s*(High|Medium|Low)\\s*([,}])', ': "\\1"\\2', result_text)

  # JSON
  df <- tryCatch({
    parsed <- fromJSON(result_text)
    parsed$paper_id <- paper_id
    parsed
  }, error = function(e) {
    message("  -> Parse failed: ", paper_id, " | error: ", e$message)
    data.frame(
      field = NA, extracted = NA, supporting_evidence = NA, confidence = NA,
      paper_id = paper_id, raw_response = result_text,
      stringsAsFactors = FALSE
    )
  })

  return(df)
}


#Part 4: loop over all PDFs

pdf_files <- list.files(pdf_folder, pattern = "\\.pdf$", full.names = TRUE)
message("Found ", length(pdf_files), " papers, starting processing...")

all_results <- list()

for (i in seq_along(pdf_files)) {
  all_results[[i]] <- tryCatch({
    extract_one_paper(pdf_files[i])
  }, error = function(e) {
    message("  -> Whole-paper processing failed: ", basename(pdf_files[i]), " | ", e$message)
    NULL
  })
}

# Results
final_df <- bind_rows(all_results)


##Part 5: save results
write.csv(final_df, output_csv, row.names = FALSE)
message("Done! Results saved to: ", output_csv)

# Quick check: which papers failed to parse
failed_papers <- final_df %>% filter(is.na(field)) %>% distinct(paper_id)
if (nrow(failed_papers) > 0) {
  message("The following papers failed to parse and need manual review: ")
  print(failed_papers)
} else {
  message("All papers parsed successfully!")
}
