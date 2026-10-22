# Funcoes partilhadas para a analise de robustez.
# Os scripts originais de cada pasta ficam como estao (reproduzem os graficos do trabalho);
# estas funcoes corrigem problemas dos dados da Steam antes de medir a volatilidade.

library(tidyverse)
library(lubridate)

# Le um CSV recolhido com generate_all_datasets.py e devolve item/date/price/volume.
# A Steam devolve dados horarios no ultimo mes, por isso agrega-se tudo a um valor por dia:
# preco medio ponderado pelo volume (VWAP) e volume total do dia.
load_steam_history <- function(path){
  raw <- read_csv(path, show_col_types = FALSE)
  colnames(raw)[1:4] <- c("date_raw", "price_raw", "volume_raw", "item")

  raw %>%
    mutate(
      date = as.Date(str_extract(date_raw, "[A-Za-z]{3} [0-9]{1,2} [0-9]{4}"), format = "%b %d %Y"),
      price = as.numeric(str_replace(as.character(price_raw), ",", ".")),
      volume = as.numeric(str_replace_all(as.character(volume_raw), ",", ""))
    ) %>%
    drop_na(date, price, volume) %>%
    group_by(item, date) %>%
    summarise(
      price = sum(price * volume) / sum(volume),
      volume = sum(volume),
      .groups = "drop"
    ) %>%
    arrange(item, date)
}

# Filtro de Hampel sobre o log do preco: marca como outlier uma observacao que se afasta
# mais de k desvios robustos (MAD) da mediana das observacoes vizinhas.
# Exemplo real: a Paracord Fade (FN) aparece vendida a 1,41 em 21/01/2025, quando valia ~300.
flag_outliers <- function(price, half_window = 7, k = 5){
  log_price <- log(price)
  n <- length(log_price)

  sapply(seq_len(n), function(i){
    neighbours <- log_price[max(1, i - half_window):min(n, i + half_window)]
    centre <- median(neighbours)
    spread <- 1.4826 * median(abs(neighbours - centre))
    spread > 0 && abs(log_price[i] - centre) > k * spread
  })
}

# Retornos logaritmicos com o numero de dias entre observacoes.
# Quando nao ha vendas num dia, o retorno seguinte cobre varios dias; dividir por sqrt(gap)
# poe todos os retornos na escala de "um dia" antes de anualizar com sqrt(365).
add_returns <- function(data){
  data %>%
    group_by(item) %>%
    arrange(date, .by_group = TRUE) %>%
    mutate(
      gap_days = as.numeric(date - lag(date)),
      log_return = log(price / lag(price)),
      daily_scaled_return = log_return / sqrt(gap_days)
    ) %>%
    ungroup()
}

# Teste de Jarque-Bera (normalidade dos retornos). p-valor baixo = caudas pesadas.
jarque_bera_p <- function(x){
  x <- x[!is.na(x)]
  n <- length(x)
  z <- x - mean(x)
  skewness <- mean(z^3) / mean(z^2)^1.5
  kurtosis <- mean(z^4) / mean(z^2)^2
  statistic <- n / 6 * (skewness^2 + (kurtosis - 3)^2 / 4)
  pchisq(statistic, df = 2, lower.tail = FALSE)
}

# Teste ARCH-LM de Engle: regride r^2 nos seus lags. p-valor baixo = a volatilidade
# aparece em "clusters" (periodos calmos seguidos de periodos agitados).
arch_lm_p <- function(x, lags = 5){
  x <- x[!is.na(x)]
  squared <- (x - mean(x))^2
  if(length(squared) <= lags + 10){
    return(NA_real_)
  }
  lagged <- embed(squared, lags + 1)
  model <- lm(lagged[, 1] ~ lagged[, -1])
  statistic <- nrow(lagged) * summary(model)$r.squared
  pchisq(statistic, df = lags, lower.tail = FALSE)
}

# Volatilidade com precos semanais ponderados pelo volume. Reduz o ruido de dias com
# uma unica venda (o mercado da Steam mistura floats e stickers no mesmo item).
weekly_volatility <- function(data){
  weekly <- data %>%
    mutate(week = floor_date(date, "week", week_start = 1)) %>%
    group_by(week) %>%
    summarise(price = sum(price * volume) / sum(volume), .groups = "drop") %>%
    arrange(week) %>%
    mutate(log_return = log(price / lag(price)))

  sd(weekly$log_return, na.rm = TRUE) * sqrt(52) * 100
}

# Resumo de volatilidade e liquidez para um item num periodo.
# Inclui a metrica "naive" (a usada no trabalho original) ao lado das versoes corrigidas.
volatility_report <- function(data){
  data <- data %>% arrange(date)
  clean <- data %>% filter(!outlier) %>% add_returns()
  calendar_days <- as.numeric(max(data$date) - min(data$date)) + 1

  tibble(
    observations = nrow(data),
    calendar_days = calendar_days,
    days_without_trades_percent = (1 - nrow(data) / calendar_days) * 100,
    median_daily_volume = median(data$volume),
    days_with_1_or_2_sales_percent = mean(data$volume <= 2) * 100,
    outliers_removed = sum(data$outlier),
    first_price = first(data$price),
    last_price = last(data$price),
    total_change_percent = (last(data$price) / first(data$price) - 1) * 100,
    price_range_percent = (max(data$price) / min(data$price) - 1) * 100,
    naive_annualized_volatility_percent = sd(data$log_return, na.rm = TRUE) * sqrt(365) * 100,
    clean_annualized_volatility_percent = sd(clean$daily_scaled_return, na.rm = TRUE) * sqrt(365) * 100,
    weekly_vwap_annualized_volatility_percent = weekly_volatility(data %>% filter(!outlier)),
    clean_biggest_daily_gain_percent = max(clean$log_return, na.rm = TRUE) * 100,
    clean_biggest_daily_loss_percent = min(clean$log_return, na.rm = TRUE) * 100,
    amihud_illiquidity = mean(abs(clean$log_return) / (clean$price * clean$volume), na.rm = TRUE) * 1e6,
    jarque_bera_p_value = jarque_bera_p(clean$daily_scaled_return),
    arch_lm_p_value = arch_lm_p(clean$daily_scaled_return)
  )
}

# Estudo de evento simples: compara a janela antes e depois de uma data.
# O dia do evento fica fora das duas janelas porque o update saiu a meio do dia.
event_window_test <- function(data, event_date, window_days = 30){
  before <- data %>% filter(date >= event_date - window_days, date < event_date)
  after <- data %>% filter(date > event_date, date <= event_date + window_days)

  if(nrow(before) < 5 || nrow(after) < 5){
    return(NULL)
  }

  before_returns <- add_returns(before)$daily_scaled_return
  after_returns <- add_returns(after)$daily_scaled_return

  # Itens muito baratos podem ficar presos no preco minimo (ex.: 0,03) e ter variancia zero.
  has_variance <- sd(before_returns, na.rm = TRUE) > 1e-8 && sd(after_returns, na.rm = TRUE) > 1e-8

  tibble(
    window_days = window_days,
    observations_before = nrow(before),
    observations_after = nrow(after),
    median_price_before = median(before$price),
    median_price_after = median(after$price),
    median_price_change_percent = (median(after$price) / median(before$price) - 1) * 100,
    total_volume_before = sum(before$volume),
    total_volume_after = sum(after$volume),
    volume_change_percent = (sum(after$volume) / sum(before$volume) - 1) * 100,
    welch_t_p_value = t.test(log(after$price), log(before$price))$p.value,
    wilcoxon_p_value = wilcox.test(after$price, before$price, exact = FALSE)$p.value,
    volatility_before_percent = sd(before_returns, na.rm = TRUE) * sqrt(365) * 100,
    volatility_after_percent = sd(after_returns, na.rm = TRUE) * sqrt(365) * 100,
    variance_f_test_p_value = if(has_variance) var.test(after_returns, before_returns)$p.value else NA_real_
  )
}
