library(ggplot2); library(dplyr); library(tidyr); library(forcats)

# Agreement rate per field, development set (%)
dat <- tribble(
  ~field,                 ~Match, ~Partial, ~`No match`,
  "control_type_level_1",  20,      4,        6,
  "intervention_level_3",  16,      1,       13,
  "sampling_method",       15,     11,        4,
  "control_type_level_2",  15,      6,        9,
  "taxon_common",          11,     18,        1
)

long <- dat %>%
  pivot_longer(-field, names_to = "Agreement", values_to = "count") %>%
  group_by(field) %>% mutate(pct = count/sum(count)*100) %>% ungroup() %>%
  mutate(Agreement = factor(Agreement, levels = c("No match","Partial","Match")))

# Sort by Match rate, high to low
ord <- dat %>% arrange(Match) %>% pull(field)
long$field <- factor(long$field, levels = ord)

p <- ggplot(long, aes(field, pct, fill = Agreement)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = ifelse(pct >= 1, paste0(round(pct), "%"), "")),
            position = position_stack(vjust = 0.5), size = 3.2, colour = "white") +
  coord_flip() +
  scale_fill_manual(values = c("Match" = "#A0CBEB",
                               "Partial" = "#F5BE81",
                               "No match" = "#F8B6BF"),
                    breaks = c("Match", "Partial", "No match"),
                    labels = c("Exact match", "Partial match", "Complete mismatch")) +
  labs(x = NULL, y = "Percentage of papers (%)", fill = NULL,
       title = "Agreement between AI and manual coding for five moderator variables")+
  theme_minimal(base_size = 12) +
  theme(legend.position = "top", panel.grid.major.y = element_blank())

print(p)
ggsave("Figure1_agreement.png", p, width = 10, height = 4.5, dpi = 300)

