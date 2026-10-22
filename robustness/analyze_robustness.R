library(tidyverse)
library(lubridate)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_dir <- if(length(file_arg) > 0){
  dirname(normalizePath(sub("^--file=", "", file_arg[1])))
} else {
  getwd()
}
if(!file.exists(file.path(script_dir, "analyze_robustness.R"))){
  script_dir <- file.path(getwd(), "robustness")
}
root_dir <- dirname(script_dir)

source(file.path(root_dir, "R", "steam_helpers.R"))

cat("==== Analise de robustez: limpeza, liquidez, testes e eventos ====\n")

graphs_folder <- file.path(script_dir, "graphs")
if(!dir.exists(graphs_folder)){
  dir.create(graphs_folder, recursive = TRUE)
}

dataset_files <- c(
  "Weapon Cases" = "weapon_cases/cases_dataset.csv",
  "Galil AR Chatterbox" = "galil_ar_chatterbox/chatterbox_dataset.csv",
  "Desert Eagle Blaze" = "desert_eagle_blaze/deagle_blaze_dataset.csv",
  "Paracord Knives" = "paracord_knives/paracord_dataset.csv",
  "Major Stickers" = "major_stickers/major_stickers_dataset.csv"
)

data <- map2_dfr(
  dataset_files,
  names(dataset_files),
  function(path, group_name){
    load_steam_history(file.path(root_dir, path)) %>%
      mutate(group = group_name)
  }
) %>%
  group_by(item) %>%
  mutate(outlier = flag_outliers(price)) %>%
  ungroup() %>%
  add_returns()

cat("Itens carregados:", n_distinct(data$item), "\n")
cat("Outliers removidos:", sum(data$outlier), "\n")

write_csv(
  data %>% filter(outlier) %>% select(group, item, date, price, volume),
  file.path(script_dir, "outliers_removed.csv")
)

# ---- 1. Volatilidade corrigida e liquidez -------------------------------------------

periods <- list(
  "Full period" = function(df) df,
  "2024" = function(df) df %>% filter(year(date) == 2024)
)

robust_summary <- imap_dfr(periods, function(period_filter, period_name){
  data %>%
    period_filter() %>%
    group_by(group, item) %>%
    filter(n() >= 20) %>%
    group_modify(~ volatility_report(.x), .keep = TRUE) %>%
    ungroup() %>%
    mutate(period = period_name, .after = item)
})

write_csv(robust_summary, file.path(script_dir, "robust_volatility_summary.csv"))

# ---- 2. Estudos de evento -------------------------------------------------------------

events <- tribble(
  ~event, ~event_date, ~items,
  "Trade-Up Update", "2025-10-23", c(
    "★ Paracord Knife | Fade (Factory New)",
    "★ Paracord Knife | Slaughter (Factory New)",
    "★ Paracord Knife | Crimson Web (Minimal Wear)",
    "★ Paracord Knife | Case Hardened (Factory New)",
    "Galil AR | Chatterbox (Field-Tested)"
  ),
  "CS2 Announcement", "2023-03-22", c(
    "Desert Eagle | Blaze (Factory New)",
    "Operation Breakout Weapon Case",
    "Chroma Case",
    "Revolver Case"
  ),
  "CS2 Release", "2023-09-27", c(
    "Desert Eagle | Blaze (Factory New)",
    "Operation Breakout Weapon Case",
    "Chroma Case",
    "Revolver Case"
  ),
  "FaZe win ESL Pro League S17", "2023-03-26", c("Sticker | FaZe Clan | Antwerp 2022"),
  "FaZe win IEM Sydney 2023", "2023-10-22", c("Sticker | FaZe Clan | Antwerp 2022")
) %>%
  mutate(event_date = as.Date(event_date)) %>%
  unnest(items) %>%
  rename(item = items)

event_results <- events %>%
  crossing(window_days = c(7, 30)) %>%
  pmap_dfr(function(event, event_date, item, window_days){
    item_data <- data %>% filter(item == !!item, !outlier)
    result <- event_window_test(item_data, event_date, window_days)
    if(is.null(result)){
      return(NULL)
    }
    bind_cols(tibble(event = event, event_date = event_date, item = item), result)
  }) %>%
  arrange(event_date, item, window_days)

write_csv(event_results, file.path(script_dir, "event_study_results.csv"))

# ---- 3. Graficos ---------------------------------------------------------------------

trade_up_date <- as.Date("2025-10-23")

trade_up_index <- data %>%
  filter(
    !outlier,
    item %in% (events %>% filter(event == "Trade-Up Update") %>% pull(item)),
    date >= trade_up_date - 45,
    date <= trade_up_date + 45
  ) %>%
  group_by(item) %>%
  mutate(
    base_price = median(price[date >= trade_up_date - 7 & date < trade_up_date]),
    price_index = price / base_price * 100,
    item = str_trim(str_replace_all(item, intToUtf8(9733), ""))
  ) %>%
  ungroup()

trade_up_plot <- ggplot(trade_up_index, aes(x = date, y = price_index, color = item)) +
  geom_hline(yintercept = 100, color = "#94a3b8", linewidth = 0.6) +
  geom_vline(xintercept = trade_up_date, color = "#334155", linetype = "dashed", linewidth = 0.8) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.2) +
  annotate("text", x = trade_up_date, y = max(trade_up_index$price_index) * 0.97, label = "Trade-Up Update (23/10/2025)", angle = 90, vjust = -0.6, hjust = 1, size = 3.4) +
  labs(
    title = "Choque de oferta: update dos knife trade-ups",
    subtitle = "Preco normalizado (mediana dos 7 dias antes do update = 100), 45 dias antes e depois",
    x = "Data",
    y = "Indice de preco (base 100)",
    color = NULL
  ) +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold", size = 18), plot.subtitle = element_text(color = "#475569"), panel.grid.minor = element_blank(), legend.position = "bottom") +
  guides(color = guide_legend(ncol = 2))

ggsave(file.path(graphs_folder, "trade_up_event_index.png"), trade_up_plot, width = 13, height = 7.5, dpi = 160)

deagle_2024 <- data %>%
  filter(item == "Desert Eagle | Blaze (Factory New)", year(date) == 2024) %>%
  mutate(sales = if_else(volume <= 2, "1-2 vendas no dia", "3 ou mais vendas no dia"))

deagle_weekly <- deagle_2024 %>%
  filter(!outlier) %>%
  mutate(week = floor_date(date, "week", week_start = 1)) %>%
  group_by(week) %>%
  summarise(price = sum(price * volume) / sum(volume), .groups = "drop")

deagle_report <- robust_summary %>%
  filter(item == "Desert Eagle | Blaze (Factory New)", period == "2024")

deagle_plot <- ggplot() +
  geom_line(data = deagle_2024, aes(x = date, y = price), color = "#cbd5e1", linewidth = 0.6) +
  geom_point(data = deagle_2024, aes(x = date, y = price, color = sales), size = 1.8) +
  geom_line(data = deagle_weekly, aes(x = week, y = price), color = "#0f766e", linewidth = 1.3) +
  scale_color_manual(values = c("1-2 vendas no dia" = "#f97316", "3 ou mais vendas no dia" = "#2563eb")) +
  labs(
    title = "Desert Eagle Blaze (FN) em 2024: ruido de liquidez vs. tendencia",
    subtitle = paste0(
      "Volatilidade diaria (metodo original): ", round(deagle_report$naive_annualized_volatility_percent, 1),
      "% | Com precos semanais ponderados pelo volume: ", round(deagle_report$weekly_vwap_annualized_volatility_percent, 1),
      "% | ", round(deagle_report$days_with_1_or_2_sales_percent, 1), "% dos dias com 1-2 vendas"
    ),
    x = "Data",
    y = "Preco",
    color = NULL
  ) +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold", size = 18), plot.subtitle = element_text(color = "#475569", size = 10.5), panel.grid.minor = element_blank(), legend.position = "top")

ggsave(file.path(graphs_folder, "desert_eagle_blaze_2024_liquidity_noise.png"), deagle_plot, width = 13, height = 7, dpi = 160)

liquidity_plot <- robust_summary %>%
  filter(period == "Full period") %>%
  mutate(
    label = item %>%
      str_replace_all(intToUtf8(9733), "") %>%
      str_replace("Paracord Knife \\| ", "Paracord ") %>%
      str_replace("Sticker \\| ", "") %>%
      str_replace(" Weapon Case", "") %>%
      str_trim()
  ) %>%
  ggplot(aes(x = median_daily_volume, y = naive_annualized_volatility_percent, color = group)) +
  geom_point(size = 3.5) +
  geom_text(aes(label = label), size = 3, hjust = -0.08, vjust = -0.6, show.legend = FALSE, check_overlap = TRUE) +
  scale_x_log10(labels = scales::label_comma(), expand = expansion(mult = c(0.05, 0.25))) +
  labs(
    title = "Liquidez vs. volatilidade medida",
    subtitle = "Itens com poucas vendas por dia mostram volatilidade muito maior: parte e ruido de liquidez, nao so especulacao",
    x = "Volume diario mediano (escala log)",
    y = "Volatilidade anualizada - metodo original (%)",
    color = NULL
  ) +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold", size = 18), plot.subtitle = element_text(color = "#475569"), panel.grid.minor = element_blank(), legend.position = "bottom")

ggsave(file.path(graphs_folder, "liquidity_vs_volatility.png"), liquidity_plot, width = 13, height = 8, dpi = 160)

cat("\nCorrelacao de Spearman entre volume mediano e volatilidade (periodo completo):\n")
full_period <- robust_summary %>% filter(period == "Full period")
print(cor.test(full_period$median_daily_volume, full_period$naive_annualized_volatility_percent, method = "spearman", exact = FALSE))

cat("\n==== Resultados guardados em ====\n")
cat(script_dir, "\n")
