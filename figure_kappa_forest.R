library(ggplot2); library(dplyr)

kap <- tribble(
  ~field,                  ~dataset,      ~kappa,  ~lo,    ~hi,
  "intervention_level_3",  "Development",  0.40,   0.22,   0.60,
  "control_type_level_1",  "Development",  0.35,  -0.02,   0.67,
  "control_type_level_2",  "Development",  0.51,   0.29,   0.71,
  "intervention_level_3",  "Validation",   0.38,   0.13,   0.64,
  "control_type_level_1",  "Validation",   0.41,  -0.09,   0.83,
  "control_type_level_2",  "Validation",   0.49,   0.26,   0.73
) %>%
  mutate(dataset = factor(dataset, levels = c("Development","Validation")),
         field   = factor(field, levels = c("control_type_level_2",
                                            "intervention_level_3",
                                            "control_type_level_1")))

p2 <- ggplot(kap, aes(x = kappa, y = field, colour = dataset)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_pointrange(aes(xmin = lo, xmax = hi),
                  position = position_dodge(width = 0.7), size = 0.5) +
  scale_colour_manual(values = c("Development" = "#2c7fb8", "Validation" = "#d95f0e")) +
  scale_x_continuous(limits = c(-0.1, 0.9), breaks = seq(-0.2, 1, 0.2)) +
  labs(x = "Cohen's kappa", y = NULL, colour = NULL,
       title = "Cohen's kappa in the development and validation datasets") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "top", panel.grid.minor = element_blank())

print(p2)
ggsave("Figure2_kappa.png", p2, width = 8, height = 4, dpi = 300)

