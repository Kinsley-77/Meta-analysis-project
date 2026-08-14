#  jaccard_validation_set_DRAFT.R

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(purrr)

 ai <- read.csv("/Users/wangyuqi/Desktop/20test_/test_set_20_results.csv", stringsAsFactors = FALSE)

# Manual workbook: header on row 2, data starts row 4
hum_raw <- read_excel("/Users/wangyuqi/Desktop/test_set_20.xlsx", sheet = "data_extraction",
                      skip = 1)                 # skip row 1 -> row 2 becomes column names？
hum <- hum_raw[-1, ]

fields <- c("taxon_common","sampling_method","intervention_level_3",
            "control_type_level_1","control_type_level_2")

# 1
norm <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x[x %in% c("", "na", "null")] <- NA
  x
}
ai[fields]  <- lapply(ai[fields],  norm)
hum[fields] <- lapply(hum[fields], norm)
hum$author  <- tolower(as.character(hum$author))
hum$year    <- suppressWarnings(as.integer(hum$year))

# 2. Map the 20 AI papers to (surname, year) ----
map <- tibble::tribble(
  ~paper,          ~surname,      ~year,
  "2008_woodcock", "woodcock",    2008,
  "aschwanden",    "aschwanden",  2007,
  "aviron_07",     "aviron",      2007,
  "aviron_11",     "aviron",      2011,
  "blümel",        "blümel",      2024,
  "buhk",          "bukh",        2018,
  "frank_04",      "frank",       2004,
  "frank_06",      "frank",       2006,
  "heard",         "heard",       2012,
  "jacot",         "jacot",       2007,
  "khongruang",    "khongruang",  2025,
  "killewald",     "killewald",   NA,     # year differs - match by surname only
  "madeira",       "madeira",     2022,
  "magagnoli",     "magagnoli",   2024,
  "mateos",        "mateos",      NA,     # year disagrees between the two sides, match by surname only
  "sydenham",      "sydenham",    2023,
  "piko",          "piko",        2021,
  "pywell",        "pywell",      2006,
  "schubert",      "schubert",    2022,
  "könig",         "könig",       2022
)

# Tag each AI row with a paper key
ai$paper <- NA_character_
for (i in seq_len(nrow(map))) {
  hit <- str_detect(tolower(ai$paper_id), fixed(map$paper[i]))
  ai$paper[hit] <- map$paper[i]
}

# 3. Compute Jaccard per paper, per field
jaccard <- function(a, b) {
  a <- unique(a[!is.na(a)]); b <- unique(b[!is.na(b)])
  if (length(a) == 0 && length(b) == 0) return(NA_real_)
  if (length(a) == 0 || length(b) == 0) return(0)
  length(intersect(a, b)) / length(union(a, b))
}

results <- data.frame(paper = map$paper, stringsAsFactors = FALSE)
for (f in fields) results[[f]] <- NA_real_

for (i in seq_len(nrow(map))) {
  sn <- map$surname[i]; yr <- map$year[i]
  h <- hum[str_detect(hum$author, fixed(sn)) &
             (is.na(yr) | hum$year == yr), ]
  a <- ai[!is.na(ai$paper) & ai$paper == map$paper[i], ]
  # Print how many rows matched, can confirm nothing was missed
  cat(sprintf("%-14s human=%d  ai=%d\n", map$paper[i], nrow(h), nrow(a)))
  for (f in fields) results[i, f] <- jaccard(a[[f]], h[[f]])
}

print(results)

# 4. Per-field mean + overall
field_means <- sapply(fields, function(f) mean(results[[f]], na.rm = TRUE))
print(round(field_means, 3))
cat("OVERALL:", round(mean(unlist(results[fields]), na.rm = TRUE), 3), "\n")

print(overall)
library(ggplot2)

# 5. Arrange each Jaccard into a table for plotting
plot_df <- data.frame(
  field = fields,
  jaccard = sapply(fields, function(f) mean(results[[f]], na.rm = TRUE))
)
plot_df <- plot_df[order(-plot_df$jaccard), ]          # sort high to low
plot_df$field <- factor(plot_df$field, levels = plot_df$field)

ggplot(plot_df, aes(x = field, y = jaccard, fill = jaccard)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = sprintf("%.2f", jaccard)), vjust = -0.4, size = 4) +
  scale_fill_gradient(low = "#F4A582", high = "#4393C3", guide = "none") +
  scale_y_continuous(limits = c(0, 1), expand = expansion(mult = c(0, 0.08))) +
  labs(title = "Jaccard similarity: AI vs human (20-paper test set)",
       x = NULL, y = "Mean Jaccard") +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

