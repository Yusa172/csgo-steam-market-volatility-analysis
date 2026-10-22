# CS2 Steam Market Volatility Analysis

Recolha do histórico de preços do Steam Community Market e análise de preço, volume, volatilidade e choques de mercado em skins, facas, cases e stickers de CS2/CS:GO.

Este repositório acompanha o trabalho **"O poder de mercado da Valve nas skins do Counter-Strike 2"** (Simão Fiúza, UC de Economia do Desporto, Licenciatura em Economia, Universidade da Beira Interior, 2025/2026). Todos os gráficos e o teste de volatilidade do Anexo 4 do trabalho são gerados pelos scripts daqui.

📄 **Trabalho completo (PDF):** [`paper/poder_mercado_valve_skins_cs2.pdf`](paper/poder_mercado_valve_skins_cs2.pdf)

## Pergunta de investigação

Até que ponto a Valve detém poder sobre o mercado de skins do Counter-Strike 2? Os preços resultam da oferta e da procura no Steam Market, mas a Valve controla os mecanismos que definem a oferta (cases, drop rates, trade-ups, updates e taxas).

## Principais resultados

| Caso | Resultado | Onde |
| --- | --- | --- |
| Update dos knife trade-ups (23/10/2025) | Facas Paracord **−31 % a −36 %** e volume **+538 % a +1045 %**; Galil Chatterbox (Covert) **+35 %** | [`robustness/RESULTADOS.md`](robustness/RESULTADOS.md#3-choque-de-oferta-update-dos-knife-trade-ups-23102025) |
| Anúncio do CS2 (22/03/2023) | Weapon cases **+44 % a +92 %** e Desert Eagle Blaze **+22 %** em 30 dias; o lançamento quase não mexeu nos preços | [`robustness/RESULTADOS.md`](robustness/RESULTADOS.md#4-choque-de-procura-anúncio-vs-lançamento-do-cs2) |
| Desert Eagle Blaze em 2024 | Volatilidade anualizada de **165,7 %** (método do trabalho), **117 %** corrigida e **38,5 %** com preços semanais | [`desert_eagle_blaze/`](desert_eagle_blaze/) e [`robustness/`](robustness/RESULTADOS.md#1-desert-eagle-blaze-em-2024-anexo-4-revisto) |
| Liquidez | Quanto menos vendas por dia, maior a volatilidade medida (Spearman ρ = −0,92) | [`robustness/RESULTADOS.md`](robustness/RESULTADOS.md#2-liquidez-vs-volatilidade) |

Interpretação: o update dos trade-ups é um **choque de oferta** (preço das facas desce, quantidade sobe) e cria uma **procura derivada** pelas skins Covert usadas como *input*. O anúncio do CS2 é um **choque de procura antecipado pelo mercado**.

## Estrutura

| Pasta / ficheiro | Conteúdo |
| --- | --- |
| `weapon_cases/` | Operation Breakout, Chroma e Revolver Case (Anexo 2 do trabalho). |
| `galil_ar_chatterbox/` | Galil AR \| Chatterbox (FT), skin Covert usada nos trade-ups (Anexo 3). |
| `desert_eagle_blaze/` | Desert Eagle \| Blaze (FN), efeito do hype e teste de volatilidade de 2024 (Gráficos 2 e 3, Anexo 4). |
| `paracord_knives/` | Quatro Paracord Knives e o impacto do update dos trade-ups (Gráfico 4). |
| `major_stickers/` | Stickers de Majors e o efeito dos esports (Gráfico 1). |
| `robustness/` | Análise revista: limpeza dos dados, liquidez, testes estatísticos e estudos de evento. |
| `paper/` | O trabalho em PDF. |
| `R/steam_helpers.R` | Funções partilhadas da análise revista. |
| `run_all.R` | Corre todos os scripts R de uma vez. |
| `generate_all_datasets.py` | Recolhe todos os datasets da Steam. |
| `for-links.py` | Exemplo simples e didático para recolher preços de qualquer item. |
| `ANALYSIS_GUIDE.md` | Explicação das variáveis, métricas e interpretação da volatilidade. |

Cada pasta de itens tem o dataset original (`*_dataset.csv`), o script de análise (`analyze_*.R`), o dataset tratado (`*_volatility_dataset.csv`), o resumo (`*_volatility_summary.csv`) e os gráficos (`graphs/`).

## Como reproduzir

### 1. Análise em R (os dados já estão no repositório)

```r
install.packages("tidyverse")
```

A partir da raiz do repositório:

```powershell
Rscript run_all.R
```

Ou só a análise revista:

```powershell
Rscript robustness/analyze_robustness.R
```

### 2. Voltar a recolher os dados (opcional)

```powershell
py -m pip install -r requirements.txt
py generate_all_datasets.py
```

O script abre o Chrome com Selenium, pede login manual na Steam e lê o JSON de:

```text
https://steamcommunity.com/market/pricehistory/?appid=730&market_hash_name=ITEM_NAME
```

Para estudar outros itens, basta editar a lista `ITEMS` em `for-links.py` e correr `py for-links.py`. Os nomes têm de ser exatamente iguais aos do Steam Market.

Notas sobre os dados da Steam:

- os preços estão na moeda da conta e incluem a taxa de 15 %;
- os dados antigos são diários, mas os últimos ~30 dias vêm por hora;
- dias sem vendas não aparecem na série;
- o mesmo item junta floats, padrões e stickers diferentes.

A pasta `robustness/` explica como cada um destes pontos afeta a volatilidade e como foi corrigido.

## Metodologia

- Retornos logarítmicos: `log(preço_t / preço_t-1)`.
- Volatilidade anualizada: `sd(retornos) * sqrt(365) * 100`. Usa-se 365 e não 252 porque o Steam Market funciona todos os dias.
- Movimento forte: variação absoluta diária ≥ 5 %.
- Análise revista: preço diário ponderado pelo volume, filtro de Hampel para outliers, retornos ajustados aos dias sem vendas, volatilidade com preços semanais, testes de Jarque-Bera e ARCH-LM, e estudos de evento com testes de Welch, Wilcoxon e F.

Mais detalhe em [`ANALYSIS_GUIDE.md`](ANALYSIS_GUIDE.md) e [`robustness/RESULTADOS.md`](robustness/RESULTADOS.md).

## Fontes

- [The Motley Fool - How to Calculate Annualized Volatility](https://www.fool.com/investing/how-to-calculate/annualized-volatility/)
- [Loris Tools - Historical Volatility Calculator](https://loris.tools/tools/volatility-calculator)
- [HLTV - Knife trade-ups and return of retakes headline CS2 update](https://www.hltv.org/news/43004/knife-trade-ups-and-return-of-retakes-headline-cs2-update)
- Reichenbach, F. (2025). Skin in the game: The returns of digital assets from computer games. *Finance Research Letters*, 83. <https://doi.org/10.1016/j.frl.2025.107670>
- Dobrynskaya, V., & Strelnikov, V. (2025). Videogame Attributes as Alternative Investments. <https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5209656>
