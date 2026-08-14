#  compare_to_manual_v2.R
library(readxl); library(dplyr); library(stringr)

ai_csv       <- "/Users/wangyuqi/Desktop/30 test_/meta_analysis_run1.csv"
manual_xlsx  <- "/Users/wangyuqi/Desktop/30 test_/data_extraction_Kinsley.xlsx"
manual_sheet <- "data_extraction"
fields <- c("taxon_common","sampling_method","intervention_level_3",
            "control_type_level_1","control_type_level_2")
single_label_fields <- c("intervention_level_3","control_type_level_1","control_type_level_2")
# AI
ai  <- read.csv(ai_csv, stringsAsFactors = FALSE, check.names = FALSE)
man <- readxl::read_excel(manual_xlsx, sheet = manual_sheet)
norm  <- function(x) tolower(trimws(as.character(x)))
deacc <- function(x) tolower(str_replace_all(iconv(x, to = "ASCII//TRANSLIT"), "[^A-Za-z]", ""))
# first word of surname + year
man <- man %>% mutate(fw = deacc(str_extract(author, "^[A-Za-zÀ-ÿ]+")),
                      yr = as.character(year))
uniq <- man %>% distinct(study_ID, fw, yr) %>%
        group_by(fw, yr) %>% filter(n() == 1) %>% ungroup()
lookup <- setNames(uniq$study_ID, paste(uniq$fw, uniq$yr))
# The two Campbell 2017 papers share author + year, so they are matched manually by filename
override <- c("Campbell_2017.pdf" = 190L, "Campbell_2017（Dose）.pdf" = 265L)
ai <- ai %>% mutate(
  fw = deacc(str_extract(paper_id, "^[A-Za-z]+")),
  yr = str_extract(paper_id, "\\d{4}"),
  study_ID = ifelse(paper_id %in% names(override),
                    override[paper_id],
                    lookup[paste(fw, yr)]))
ai$study_ID <- as.integer(ai$study_ID)
common <- sort(intersect(unique(ai$study_ID[!is.na(ai$study_ID)]), unique(man$study_ID)))
cat("Number of papers compared, n =", length(common), "\n")
miss <- setdiff(unique(ai$paper_id), unique(ai$paper_id[!is.na(ai$study_ID)]))
if (length(miss) > 0) { cat(">> Files that could not be matched to a study_ID (check these):\n"); print(miss) }
# 1) match / partial / no-match
status <- function(a, m) {
  a <- unique(a[!is.na(a) & a != ""]); m <- unique(m[!is.na(m) & m != ""])
  if (length(a) == 0 && length(m) == 0) return(NA_character_)
  if (setequal(a, m)) return("match")
  if (length(intersect(a, m)) > 0) return("partial")
  "no_match"
}
cat("\n===== Match / partial / no-match by field =====\n")
for (f in fields) {
  st <- sapply(common, function(k)
        status(norm(ai[[f]][ai$study_ID == k]), norm(man[[f]][man$study_ID == k])))
  st <- st[!is.na(st)]
  cat(sprintf("%-22s match=%3.0f%%  partial=%3.0f%%  no_match=%3.0f%%\n",
      f, mean(st == "match")*100, mean(st == "partial")*100, mean(st == "no_match")*100))
}
# 2) Cohen's kappa + bootstrap 95% CI
mode1 <- function(v) { v <- norm(v); v <- v[!is.na(v)]
  if (length(v) == 0) return(NA_character_)
  names(sort(table(v), decreasing = TRUE))[1] }
kappa <- function(a, b) {
  n <- length(a); po <- mean(a == b)
  cats <- union(a, b)
  pe <- sum(vapply(cats, function(c) mean(a == c) * mean(b == c), numeric(1)))
  (po - pe) / (1 - pe)
}
set.seed(1)
cat("\n===== Cohen's kappa + 95% CI (2000 bootstrap replications) =====\n")
for (f in single_label_fields) {
  A <- sapply(common, function(k) mode1(ai[[f]][ai$study_ID == k]))
  B <- sapply(common, function(k) mode1(man[[f]][man$study_ID == k]))
  ok <- !is.na(A) & !is.na(B); A <- A[ok]; B <- B[ok]; n <- length(A)
  k0 <- kappa(A, B)
  bs <- replicate(2000, { i <- sample(n, n, replace = TRUE); kappa(A[i], B[i]) })
  ci <- quantile(bs, c(.025, .975), na.rm = TRUE)
  cat(sprintf("%-22s kappa=%.2f  95%%CI[%.2f, %.2f]  (n=%d)\n", f, k0, ci[1], ci[2], n))
}
