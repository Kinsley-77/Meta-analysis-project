#  compare_to_manual_EARLY_DRAFT.R
#  EARLY DRAFT - superseded by compare_to_manual_v2.R.


library(readxl); library(dplyr); library(stringr); library(tidyr)
install.packages("writexl")
library(writexl)

write_xlsx(list(data_extraction = dat),
           "/Users/wangyuqi/Desktop/data_extraction_Kinsley.xlsx")

cat("Generated data_extraction_Kinsley.xlsx\n")

#Setting
ai_csv      <- "/Users/wangyuqi/Desktop/30 test_/meta_analysis_extracted_results30.csv"
manual_xlsx <- "/Users/wangyuqi/Desktop/data_extraction_Kinsley.xlsx"   
manual_sheet<- "data_extraction"
fields <- c("taxon_common","sampling_method","intervention_level_3",
            "control_type_level_1","control_type_level_2")

# Read data 
ai  <- read.csv(ai_csv, stringsAsFactors = FALSE, check.names = FALSE)
man <- readxl::read_excel(manual_xlsx, sheet = manual_sheet, skip = 0)  # header is on row 2

# Normalise to lower-case, trimmed, to make comparison easier
norm <- function(x) tolower(trimws(as.character(x)))

# Matching
ai$key  <- ai$paper_id |> str_remove("\\.pdf$") |> str_remove("^paper\\d+_") |>
           str_extract("^[A-Za-z]+") |> tolower()
# Manual workbook: first word of author (surname)
man$key <- man$author |> str_extract("^[A-Za-zÀ-ÿ]+") |> tolower()
# Strip accents (Blümel -> blumel) so both sides can match
deaccent <- function(x) iconv(x, to = "ASCII//TRANSLIT") |> str_remove_all("[^a-z]")
ai$key  <- deaccent(ai$key);  man$key <- deaccent(man$key)

# De-duplicate each paper to unique combinations (the
keep <- c("key", fields)
man_u <- man %>% mutate(across(all_of(fields), norm)) %>% distinct(across(all_of(keep)))
ai_u  <- ai  %>% mutate(across(all_of(fields), norm)) %>% distinct(across(all_of(keep)))

# Compare agreement paper by paper, field by field
papers <- sort(unique(man_u$key))
report <- list(); mism <- list()
for (p in papers) {
  m <- man_u %>% filter(key==p)
  a <- ai_u  %>% filter(key==p)
  if (nrow(a)==0) { report[[p]] <- data.frame(key=p, note="No AI match for this paper (name mismatch?)"); next }
  for (f in fields) {
    man_vals <- unique(m[[f]]); ai_vals <- unique(a[[f]])
    hit <- mean(ai_vals %in% man_vals)
    report[[paste(p,f)]] <- data.frame(key=p, field=f,
        manual=paste(man_vals,collapse=" | "),
        ai=paste(ai_vals,collapse=" | "),
        match=ifelse(setequal(man_vals,ai_vals),"match",
                     ifelse(hit>0,"partial","no_match")))
  }
}
res <- bind_rows(report)

# Summary
summ <- res %>% filter(!is.na(field)) %>%
  group_by(field) %>%
  summarise(exact_match = mean(match=="match"),
            partial_match = mean(match=="partial"),
            no_match = mean(match=="no_match"), .groups="drop")
cat("\n===== Agreement rate by field (per paper) =====\n"); print(summ)

cat("\n===== Mismatch detail (for manual review) =====\n")
print(head(as.data.frame(res %>% filter(match != "match") %>% select(key, field, manual, ai)), 200))

# Save
out <- file.path(dirname(ai_csv), "agreement_report.csv")
write.csv(res, out, row.names=FALSE, fileEncoding="UTF-8")
cat("\n>> Detail saved to:", out, "\n")
# Check
ai$paper_id[grepl("arshall|ywell", ai$paper_id, ignore.case = TRUE)]
list.files(out, pattern = "arshall|ywell", ignore.case = TRUE)
