library(readr)
library(tidyverse)
library(lubridate)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_dir <- if(length(file_arg) > 0){
  dirname(normalizePath(sub("^--file=", "", file_arg[1])))
} else {
  getwd()
}
if(!file.exists(file.path(script_dir, "deagle_blaze_dataset.csv"))){
  script_dir <- file.path(getwd(), "desert_eagle_blaze")
}

cat("==== Desert Eagle Blaze Analysis ====\n")

data <- read_csv(file.path(script_dir, "deagle_blaze_dataset.csv"))

colnames(data)[1:3] <- c(
  "date_raw",
  "price_raw",
  "volume_raw"
)

data <- data %>%
  mutate(
    date = str_extract(date_raw, "[A-Za-z]{3} \\d{1,2} \\d{4}"),
    date = as.Date(date, format = "%b %d %Y"),
    price = as.numeric(str_replace(as.character(price_raw), ",", ".")),
    volume = as.numeric(str_replace_all(as.character(volume_raw), ",", ""))
  ) %>%
  drop_na(date, price) %>%
  arrange(date)

graphs_folder <- file.path(script_dir, "graphs")

if(!dir.exists(graphs_folder)){
  dir.create(graphs_folder, recursive = TRUE)
}
basic_graphs_folder <- file.path(graphs_folder, "basic")
if(!dir.exists(basic_graphs_folder)){
  dir.create(basic_graphs_folder, recursive = TRUE)
}

events <- data.frame(
  event = c(
    "CS2 Announcement",
    "CS2 Release"
  ),
  event_date = as.Date(c(
    "2023-03-22",
    "2023-09-27"
  ))
)

plot_all <- ggplot(
  data,
  aes(
    x = date,
    y = price
  )
) +
  geom_line(
    linewidth = 0.9,
    color = "#2563eb"
  ) +
  geom_vline(
    data = events,
    aes(
      xintercept = event_date
    ),
    color = "#dc2626",
    linetype = "dashed",
    linewidth = 0.8
  ) +
  geom_text(
    data = events,
    aes(
      x = event_date,
      y = max(data$price, na.rm = TRUE) * 0.92,
      label = event
    ),
    angle = 90,
    size = 3.6
  ) +
  labs(
    title = "Desert Eagle Blaze Price - Full Period",
    x = "Date",
    y = "Price"
  ) +
  theme_minimal(base_size = 13)

print(plot_all)

ggsave(
  filename = file.path(
    graphs_folder,
    "desert_eagle_blaze_full_period.png"
  ),
  plot = plot_all,
  width = 12,
  height = 7,
  dpi = 160
)

# O retorno e calculado antes de filtrar o ano, para o primeiro dia de 2024 comparar com
# o ultimo preco de 2023 (e assim que foram obtidos os valores do Anexo 4 do trabalho).
data_2024 <- data %>%
  arrange(date) %>%
  mutate(log_return = log(price / lag(price))) %>%
  filter(year(date) == 2024) %>%
  mutate(
    absolute_return = abs(log_return),
    percent_return = log_return * 100,
    big_move = absolute_return >= 0.05,
    rolling_volatility_30 = sapply(
      seq_along(log_return),
      function(i){
        start_index <- max(1, i - 29)
        values <- log_return[start_index:i]
        if(sum(!is.na(values)) < 5){
          return(NA_real_)
        }
        sd(values, na.rm = TRUE) * sqrt(365) * 100
      }
    )
  )

volatility_summary <- data_2024 %>%
  summarise(
    observations = n(),
    average_price = mean(price, na.rm = TRUE),
    min_price = min(price, na.rm = TRUE),
    max_price = max(price, na.rm = TRUE),
    price_range_percent = ((max_price / min_price) - 1) * 100,
    daily_return_sd_percent = sd(percent_return, na.rm = TRUE),
    annualized_volatility_percent = sd(log_return, na.rm = TRUE) * sqrt(365) * 100,
    average_absolute_daily_move_percent = mean(abs(percent_return), na.rm = TRUE),
    days_with_moves_above_5_percent = sum(big_move, na.rm = TRUE),
    share_of_days_above_5_percent = mean(big_move, na.rm = TRUE) * 100,
    biggest_daily_gain_percent = max(percent_return, na.rm = TRUE),
    biggest_daily_loss_percent = min(percent_return, na.rm = TRUE)
  )

write_csv(
  data_2024,
  file.path(script_dir, "desert_eagle_blaze_2024_volatility_dataset.csv")
)

write_csv(
  volatility_summary,
  file.path(script_dir, "desert_eagle_blaze_2024_volatility_summary.csv")
)

volatility_test_text <- paste0(
  "Desert Eagle Blaze 2024 volatility test\n\n",
  "Annualization days: 365\n",
  "Observations: ", volatility_summary$observations, "\n",
  "Price range: ", round(volatility_summary$price_range_percent, 2), "%\n",
  "Daily return standard deviation: ", round(volatility_summary$daily_return_sd_percent, 2), "%\n",
  "Annualized volatility: ", round(volatility_summary$annualized_volatility_percent, 2), "%\n",
  "Average absolute daily move: ", round(volatility_summary$average_absolute_daily_move_percent, 2), "%\n",
  "Days with absolute movement above 5%: ", volatility_summary$days_with_moves_above_5_percent, "\n",
  "Share of days above 5%: ", round(volatility_summary$share_of_days_above_5_percent, 2), "%\n",
  "Biggest daily gain: ", round(volatility_summary$biggest_daily_gain_percent, 2), "%\n",
  "Biggest daily loss: ", round(volatility_summary$biggest_daily_loss_percent, 2), "%\n\n",
  "Interpretation: volatility exists because prices do not move smoothly; the log-return standard deviation, the annualized volatility and the number of days above 5% show measurable price instability."
)

writeLines(
  volatility_test_text,
  file.path(script_dir, "desert_eagle_blaze_2024_volatility_test.txt")
)

basic_full_plot <- ggplot(data, aes(x = date, y = price)) +
  geom_line(linewidth = 0.9, color = "#0f766e") +
  geom_vline(data = events, aes(xintercept = event_date), color = "#334155", linetype = "dashed", linewidth = 0.8) +
  geom_text(data = events, aes(x = event_date, y = max(data$price, na.rm = TRUE) * 0.96, label = event), angle = 90, size = 3, hjust = 1) +
  labs(
    title = "Desert Eagle Blaze - Market Price",
    x = "Date",
    y = "Market price"
  ) +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold", size = 18), panel.grid.minor = element_blank())

ggsave(file.path(basic_graphs_folder, "desert_eagle_blaze_basic_price.png"), basic_full_plot, width = 13, height = 7, dpi = 160)

basic_2024_plot <- ggplot(data_2024, aes(x = date, y = price)) +
  geom_line(linewidth = 0.9, color = "#0f766e") +
  labs(
    title = "Desert Eagle Blaze - 2024 Market Price",
    x = "Date",
    y = "Market price"
  ) +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold", size = 18), panel.grid.minor = element_blank())

ggsave(file.path(basic_graphs_folder, "desert_eagle_blaze_2024_basic_price.png"), basic_2024_plot, width = 13, height = 7, dpi = 160)

plot_2024 <- ggplot(
  data_2024,
  aes(
    x = date
  )
) +
  geom_ribbon(
    aes(
      ymin = min(price, na.rm = TRUE),
      ymax = max(price, na.rm = TRUE)
    ),
    fill = "#dbeafe",
    alpha = 0.35
  ) +
  geom_line(
    aes(
      y = price
    ),
    linewidth = 1,
    color = "#0f766e"
  ) +
  geom_line(
    aes(
      y = stats::filter(price, rep(1 / 14, 14), sides = 1)
    ),
    linewidth = 0.9,
    color = "#f97316",
    na.rm = TRUE
  ) +
  geom_point(
    data = data_2024 %>% filter(big_move),
    aes(
      y = price
    ),
    color = "#dc2626",
    size = 2.2
  ) +
  labs(
    title = "Desert Eagle Blaze - 2024 Price Volatility",
    subtitle = paste0(
      "Annualized volatility: ",
      round(volatility_summary$annualized_volatility_percent, 1),
      "% | Days above 5% move: ",
      volatility_summary$days_with_moves_above_5_percent
    ),
    x = "Date",
    y = "Price"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 18),
    plot.subtitle = element_text(color = "#475569"),
    panel.grid.minor = element_blank()
  )

print(plot_2024)

ggsave(
  filename = file.path(
    graphs_folder,
    "desert_eagle_blaze_2024.png"
  ),
  plot = plot_2024,
  width = 13,
  height = 7,
  dpi = 180
)

plot_volatility <- ggplot(
  data_2024,
  aes(
    x = date,
    y = rolling_volatility_30
  )
) +
  geom_area(
    fill = "#fecaca",
    alpha = 0.5
  ) +
  geom_line(
    linewidth = 1,
    color = "#b91c1c",
    na.rm = TRUE
  ) +
  labs(
    title = "Desert Eagle Blaze - 30 Observation Rolling Volatility",
    subtitle = "Calculated from log returns and annualized with sqrt(365)",
    x = "Date",
    y = "Annualized volatility (%)"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 18),
    plot.subtitle = element_text(color = "#475569"),
    panel.grid.minor = element_blank()
  )

print(plot_volatility)

ggsave(
  filename = file.path(
    graphs_folder,
    "desert_eagle_blaze_2024_volatility.png"
  ),
  plot = plot_volatility,
  width = 13,
  height = 7,
  dpi = 180
)

cat("\n==== Graficos e teste de volatilidade guardados em ====\n")
cat(script_dir)
