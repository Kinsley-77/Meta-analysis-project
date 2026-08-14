#  Jaccard similarity: AI extraction vs manual gold standard


library(readxl)

## File paths 
human_file  <- "20_test_set.xlsx"

# AI extraction results 
ai_dev_file <- "meta_analysis_extracted_results30.csv"  # 30 development papers 
ai_val_file <- "test_set_20_results.csv"                # 20 validation papers

## two multi-label + three single-label
FIELDS <- c("taxon_common", "sampling_method", "intervention_level_3",
            "control_type_level_1", "control_type_level_2")

##1. Setting
# lower-case, trim, blanks -> NA
norm <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x[x %in% c("", "na", "null")] <- NA
  x
}

# Jaccard of two value sets 
jaccard <- function(a, b) {
  a <- unique(a[!is.na(a)]); b <- unique(b[!is.na(b)])
  if (length(a) == 0 && length(b) == 0) return(NA_real_)
  if (length(a) == 0 || length(b) == 0) return(0)    
  length(intersect(a, b)) / length(union(a, b))
}

# 2. Load human gold standard
# Header is on row 2; row 3 is a note row; data start on row 4.
h <- read_excel(human_file, sheet = "data_extraction", skip = 1)
h <- h[-1, , drop = FALSE]# drop the note row
human <- h[, c("author", "year", FIELDS)]
human$author <- tolower(as.character(human$author))
human$year   <- suppressWarnings(as.integer(human$year))
for (f in FIELDS) human[[f]] <- norm(human[[f]])
human <- human[!is.na(human$author), ]

# match human rows by author-surname
hmatch <- function(surname, yr) {
  ok <- grepl(surname, human$author, fixed = TRUE)
  if (!is.na(yr)) ok <- ok & (!is.na(human$year) & human$year == yr)
  human[ok, , drop = FALSE]
}

# 3. Paper maps 
dev_map <- data.frame(
  key = c("bickerton","blaauw_2012","blaauw_2014","boetzl","campbell_main","campbell_dose",
          "carvell_2004","carvell_2007","dale","kohler","frank_2009","gardiner","griffiths",
          "huusela","karimi","joshua","kati","marko_2012","marko_2014","marshall","norton",
          "poole","pywell_2004","pywell_2008","rischen","shrewsbury","sutton","turo",
          "venturini","zhang"),
  surname = c("bickerton","blaauw","blaauw","boetzl","alistair","campbell, aj",
              "carvell","carvell","dale","kohler","frank","gardiner","griffiths",
              "huusela","karimi","joshua","kati","marko","marko","marshall","norton",
              "poole","pywell","pywell","rischen","shrewsbury","sutton, p","turo",
              "venturini","zhang"),
  year = c(2012,2012,2014,2022,2017,2017,2004,2007,2020,2008,2009,2020,2022,2016,2024,
           2017,2021,2012,2014,2007,2019,2024,2004,2008,2022,2004,2017,2021,2017,2019),
  stringsAsFactors = FALSE)

pkey_dev <- function(pid) {
  p <- tolower(pid)
  if (grepl("joshua", p))        return("joshua")
  if (grepl("dose", p))          return("campbell_dose")
  if (grepl("campbell_2017", p)) return("campbell_main")
  keys <- c("bickerton","boetzl","carvell_2004","carvell_2007","dale_2020","kohler",
            "frank_2009","gardiner","griffiths","huusela","karimi","kati","marko_2012",
            "marko_2014","marshall","norton","poole","pywell_2004","pywell_2008","rischen",
            "shrewsbury","sutton","turo","venturini","zhang","blaauw_2012","blaauw_2014")
  for (k in keys) if (grepl(k, p)) { if (k == "dale_2020") return("dale"); return(k) }
  NA_character_
}

val_map <- data.frame(
  key = c("2008_woodcock","aschwanden","aviron_07","aviron_11","blumel","buhk","frank_04",
          "frank_06","heard","jacot","khongruang","killewald","madeira","magagnoli","mateos",
          "sydenham","piko","pywell","schubert","konig"),
  surname = c("woodcock","aschwanden","aviron","aviron","blümel","bukh","frank","frank",
              "heard","jacot","khongruang","killewald","madeira","magagnoli","mateos",
              "sydenham","piko","pywell","schubert","könig"),
  year = c(2008,2007,2007,2011,2024,2018,2004,2006,2012,2007,2025,NA,2022,2024,NA,2023,
           2021,2006,2022,2022),
  stringsAsFactors = FALSE)

pkey_val <- function(pid) {
  p <- tolower(pid)
  km <- c("blümel" = "blumel", "könig" = "konig")   # accented names
  keys <- c("2008_woodcock","aschwanden","aviron_07","aviron_11","blümel","buhk","frank_04",
            "frank_06","heard","jacot","khongruang","killewald","madeira","magagnoli","mateos",
            "sydenham","piko","pywell","schubert","könig")
  for (k in keys) if (grepl(k, p, fixed = TRUE)) return(if (k %in% names(km)) km[[k]] else k)
  NA_character_
}

#4. Core computation
compute_jaccard <- function(ai_file, map, pkey, label) {
  ai <- read.csv(ai_file, stringsAsFactors = FALSE, check.names = FALSE)
  for (f in FIELDS) ai[[f]] <- norm(ai[[f]])
  ai$key <- vapply(ai$paper_id, pkey, character(1))

  res <- data.frame(paper = map$key, human = NA_integer_, ai = NA_integer_,
                    stringsAsFactors = FALSE)
  for (f in FIELDS) res[[f]] <- NA_real_

  for (i in seq_len(nrow(map))) {
    hm <- hmatch(map$surname[i], map$year[i])
    am <- ai[!is.na(ai$key) & ai$key == map$key[i], , drop = FALSE]
    res$human[i] <- nrow(hm); res$ai[i] <- nrow(am)
    for (f in FIELDS) res[i, f] <- jaccard(am[[f]], hm[[f]])
  }

  cat("\n====", label, "====\n")
  bad <- res[res$human == 0 | res$ai == 0, "paper"]
  if (length(bad)) cat("  WARNING - unmatched papers:", paste(bad, collapse = ", "), "\n")
  means <- sapply(FIELDS, function(f) mean(res[[f]], na.rm = TRUE))
  print(round(means, 3))
  cat("  OVERALL:", round(mean(unlist(res[FIELDS]), na.rm = TRUE), 3), "\n")
  invisible(res)
}

# 5. Run:  DEVELOPMENT (n = 30)/VALIDATION (n = 20)
dev_res <- compute_jaccard(ai_dev_file, dev_map, pkey_dev, "DEVELOPMENT set (n = 30)")
val_res <- compute_jaccard(ai_val_file, val_map, pkey_val, "VALIDATION set (n = 20)")

## per-paper tables are in dev_res / val_res if you want to inspect them:
# print(dev_res); print(val_res)
