
# intervention_level_3 confusion matrix (validation/test set, 20 papers)
library(readxl)
library(dplyr)
library(stringr)
library(ggplot2)

ai_path    <- "/Users/wangyuqi/Desktop/20test_/test_set_20_results.csv"
human_path <- "/Users/wangyuqi/Desktop/data_extraction_Alexa.xlsx"

# 8 papers whose filenames have no ID- pattern, manually mapped to study_ID
extra_map <- c(
  "2008_Woodcocketal.pdf" = 6,
  "Aviron_07_Effects of Swiss agri-environmental measures on arthropods_AAB.pdf" = 2668,
  "Blümel_24_JAE (1).pdf" = 1358,
  "Jacot_07_Improved field margins for a higher biodiversity_AAB.pdf" = 2617,
  "Magagnoli_24_InsectConservDiversity.pdf" = 790,
  "Schubert_22_Basic&ApplEcol.pdf" = 1473,
  "paper23_sydenham2023.pdf" = 1583,
  "von Königslöw_2022.pdf" = 407
)

to_sid <- function(p) {
  id <- str_match(p, "ID-(\\d+)")[,2]
  ifelse(!is.na(id), as.integer(id), unname(extra_map[p]))
}

# Take the most common category per paper 
mode_cat <- function(x) names(sort(table(x), decreasing = TRUE))[1]

#  AI
ai <- read.csv(ai_path, stringsAsFactors = FALSE, check.names = FALSE)
ai$study_ID <- to_sid(ai$paper_id)
ai$iv <- trimws(as.character(ai$intervention_level_3))
ai_study <- ai %>% group_by(study_ID) %>% summarise(ai = mode_cat(iv), .groups = "drop")

# Manual (header on row 2 -> skip = 1)
hu <- read_excel(human_path, sheet = "data_extraction", skip = 1)
hu$study_ID <- suppressWarnings(as.integer(as.numeric(hu$study_ID)))
hu$iv <- trimws(as.character(hu$intervention_level_3))
hu <- hu %>% filter(study_ID %in% ai_study$study_ID)
hu_study <- hu %>% group_by(study_ID) %>% summarise(human = mode_cat(iv), .groups = "drop")

# Merge+confusion matrix
m <- inner_join(hu_study, ai_study, by = "study_ID")
cat("matched studies:", nrow(m), "\n")

cats <- c("Wildflower strips","Wildflower areas","Wildflower margins",
          "Flower beds or planters",
          "Other flower planting - please specify in column K",
          "Other - sown hedge herb layer")
m$human <- factor(m$human, levels = cats)
m$ai    <- factor(m$ai,    levels = cats)

cm <- table(Human = m$human, AI = m$ai)
cat("\n=== Confusion matrix (rows = manual, columns = AI) ===\n"); print(cm)

agree <- sum(diag(cm)); tot <- sum(cm)
wf <- c("Wildflower strips","Wildflower areas","Wildflower margins")
wf_off <- sum(cm[wf, wf]) - sum(diag(cm[wf, wf]))
all_off <- tot - agree
cat(sprintf("\nAgreement rate = %d/%d = %.0f%%\n", agree, tot, 100*agree/tot))
cat(sprintf("Near-synonym errors (among strips/areas/margins) = %d/%d = %.0f%% of all errors\n",
            wf_off, all_off, 100*wf_off/all_off))

# Heatmap
plot_df <- as.data.frame(cm)
short <- function(x) x |>
  str_replace("Wildflower","WF") |>
  str_replace("Other flower planting.*","Other flower") |>
  str_replace("Other - sown hedge herb layer","Other")
plot_df$Human <- factor(short(as.character(plot_df$Human)), levels = short(cats))
plot_df$AI    <- factor(short(as.character(plot_df$AI)),    levels = short(cats))

p <- ggplot(plot_df, aes(AI, Human, fill = Freq)) +
  geom_tile(color = "grey85") +
  geom_text(aes(label = ifelse(Freq>0, Freq, "")), size = 4) +

  
  annotate("rect", xmin=0.5, xmax=3.5, ymin=3.5, ymax=6.5,
           fill=NA, color="#C1442E", linewidth=1) +
  scale_fill_gradient(low = "white", high = "#5A97D0") +
  scale_y_discrete(limits = rev) +
  labs(x = "LLM extraction", y = "Manual coding (gold standard)",
       title = "Confusion matrix: intervention_level_3 (test set, n = 20; 55% agreement)") +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1), panel.grid = element_blank())
print(p)
ggsave("/Users/wangyuqi/Desktop/20test_/Figure_confusion_intervention_L3.png", p, width = 7, height = 5.6, dpi = 300)
cat("\nHeatmap saved: Figure_confusion_intervention_L3.png\n")
