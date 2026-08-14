
# Sensitivity check: re-extract the 3 papers over 120,000 characters
library(pdftools)
library(openai)
library(jsonlite)
library(dplyr)

dev_folder  <- "/Users/wangyuqi/Desktop/30 test_"   # development set
test_folder <- "/Users/wangyuqi/Desktop/20test_"    # test set
out_csv     <- file.path(test_folder, "recheck_full_text_3papers.csv")

model_name <- "gpt-5.5"

# These 3 papers are the only ones among all 50 that exceed 120,000 characters
targets <- c(
  file.path(test_folder, "Heard_12_Quantifying the effects of Entry Level Stewardship (ELS) on biodiversity at the farm scale- the hillesden experiment_ID-2611.pdf"),
  file.path(test_folder, "Killewald_23_AgriAndForestEntomology_ID-859.pdf"),
  file.path(dev_folder,  "Pywell_2004.pdf")
)

missing <- targets[!file.exists(targets)]
if (length(missing) > 0) {
  stop("Could not find these files, please check the paths:\n", paste(missing, collapse = "\n"))
}

# Source prompts_final.R directly so the prompt wording matches exactly.
source("/Users/wangyuqi/Desktop/prompts_final.R")
stopifnot("extraction_prompt not found in prompts_final.R" = exists("extraction_prompt"))

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

extract_one_paper_full <- function(pdf_path) {
  paper_id <- basename(pdf_path)
  paper_text <- paste(pdf_text(pdf_path), collapse = "\n")

  message(sprintf("Processing: %s  (%d characters, full text submitted)", paper_id, nchar(paper_text)))

  response <- create_chat_completion(
    model    = model_name,
    messages = list(
      list(role = "system", content = "You are an expert ecological meta-analysis coder."),
      list(role = "user",   content = paste(extraction_prompt, "\n\nPaper text:\n", paper_text))
    )
  )
  result_text <- response$choices$message.content

  fail_row <- function(note) data.frame(
    paper_id = paper_id, row_id = NA, taxon_common = NA, sampling_method = NA,
    intervention_level_3 = NA, control_type_level_1 = NA, control_type_level_2 = NA,
    description_of_control = NA, supporting_evidence = NA, confidence = NA,
    notes_on_ambiguity = note, raw_response = result_text %||% ""
  )

  if (length(result_text) == 0 || is.na(result_text) || !nzchar(result_text)) {
    message("  -> Empty response"); return(fail_row("EMPTY_RESPONSE"))
  }
  result_text <- trimws(gsub("```json|```", "", result_text))

  tryCatch({
    parsed <- as.data.frame(fromJSON(result_text))
    parsed$paper_id <- paper_id
    parsed$n_chars_submitted <- nchar(paper_text)
    parsed
  }, error = function(e) {
    message("  -> Parse failed: ", e$message)
    fail_row(paste("PARSE_ERROR:", e$message))
  })
}

# Run these 3 papers
new_results <- bind_rows(lapply(targets, function(f) {
  tryCatch(extract_one_paper_full(f),
           error = function(e) { message("  -> Whole-paper failure: ", basename(f), " | ", e$message); NULL })
}))

write.csv(new_results, out_csv, row.names = FALSE, fileEncoding = "UTF-8")
cat("\n>> Full-text extraction results saved to:", out_csv, "\n\n")

# Compare against the original results
old_csv <- file.path(test_folder, "test_set_20_results.csv")
if (file.exists(old_csv)) {
  old <- read.csv(old_csv, stringsAsFactors = FALSE)

  key_cols <- c("taxon_common", "sampling_method", "intervention_level_3",
                "control_type_level_1", "control_type_level_2")

  for (pid in unique(new_results$paper_id)) {
    cat("==================================================\n")
    cat("Paper:", pid, "\n")
    o <- old[old$paper_id == pid, intersect(key_cols, names(old)), drop = FALSE]
    n <- new_results[new_results$paper_id == pid, intersect(key_cols, names(new_results)), drop = FALSE]

    if (nrow(o) == 0) {
      cat("  (Not found in the original results -- likely a dev-set paper, compare manually)\n\n"); next
    }
    cat("\n-- Truncated version (first 120,000 characters) --\n"); print(o)
    cat("\n-- Full-text version --\n"); print(n)
    cat(sprintf("\nRow count: truncated %d rows -> full-text %d rows\n", nrow(o), nrow(n)))
    same <- identical(
      o[order(do.call(paste, o)), , drop = FALSE],
      n[order(do.call(paste, n)), , drop = FALSE]
    )
    cat("Key fields identical:", ifelse(same, "yes", "no"), "\n\n")
  }
} else {
  cat("Original results file not found, skipping comparison:", old_csv, "\n")
}
