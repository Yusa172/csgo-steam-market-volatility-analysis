# Guia da analise em R

Este ficheiro explica o que os scripts em R calculam, que variaveis aparecem nos datasets e como interpretar as metricas principais.

As formulas usadas seguem a logica comum de volatilidade historica: calcular retornos, medir o desvio padrao desses retornos e anualizar pela raiz quadrada do numero de periodos. As fontes usadas estao no fim deste ficheiro.

## Objetivo da analise

A analise serve para perceber como o mercado de cada item se comporta ao longo do tempo.

O foco principal e:

- acompanhar a evolucao do preco de mercado;
- comparar precos entre itens;
- medir a volatilidade;
- identificar dias com movimentos fortes;
- observar eventos importantes, como anuncio/lancamento do CS2 ou updates relevantes;
- criar graficos simples e graficos com indicadores estatisticos.

## Explicacao economica

Economicamente, a volatilidade representa o grau de incerteza ou risco associado ao preco de um ativo. No contexto deste trabalho, os ativos sao skins, knives, stickers e cases negociados no Steam Market.

Uma skin com preco estavel tende a ter variacoes pequenas ao longo do tempo. Uma skin volatil tem subidas e descidas fortes, o que significa que o seu preco e mais incerto. Isto pode acontecer por varias razoes:

- alteracoes na procura dos jogadores;
- baixa liquidez, ou seja, poucas vendas em alguns periodos;
- especulacao dos investidores;
- updates do jogo;
- alteracoes em sistemas como trade-ups;
- eventos competitivos ou anuncios importantes;
- raridade e oferta limitada de certos itens.

Por isso, a volatilidade nao mede se o item e "bom" ou "mau". Mede o quanto o preco varia. Um item pode subir muito e ainda assim ser volatil, porque tambem pode cair muito.

## Variaveis originais

Os dados recolhidos da Steam chegam normalmente com estas colunas:

| Variavel | Significado |
| --- | --- |
| `date_raw` | Data original como veio da Steam. Pode incluir hora e formato textual. |
| `price_raw` | Preco original como texto. |
| `volume_raw` | Volume original como texto. Representa o numero de vendas/registos nesse ponto. |
| `item`, `case` ou `sticker` | Nome do ativo analisado. O nome da coluna muda conforme a pasta. |

## Variaveis tratadas

Depois da limpeza em R, os scripts criam variaveis mais faceis de usar:

| Variavel | Significado |
| --- | --- |
| `date` | Data convertida para formato de data em R. |
| `price` | Preco convertido para numero. |
| `volume` | Volume convertido para numero. |

Estas variaveis sao a base dos graficos simples: `date` no eixo X e `price` no eixo Y.

## Variaveis de retorno e volatilidade

Os scripts tambem calculam variaveis novas para estudar risco e instabilidade de preco:

| Variavel | Formula / criterio | Significado |
| --- | --- | --- |
| `log_return` | `log(price / lag(price))` | Retorno logaritmico entre uma observacao e a anterior. Mede a variacao relativa do preco. |
| `percent_return` | `log_return * 100` | Retorno em percentagem. |
| `absolute_return` | `abs(log_return)` | Tamanho do movimento, ignorando se foi subida ou descida. |
| `big_move` | `absolute_return >= 0.05` | Marca dias com movimento absoluto igual ou superior a 5%. |
| `rolling_average_14` | Media movel de 14 observacoes | Suaviza o preco para mostrar tendencia. |
| `rolling_volume_14` | Media movel de 14 observacoes do volume | Usada nos scripts que tambem analisam volume. |
| `rolling_volatility_30` | Desvio padrao movel dos retornos, anualizado | Mostra como a volatilidade muda ao longo do tempo. |

## O que foi feito na analise

Em cada script R, o processo foi:

1. Carregar o dataset recolhido da Steam.
2. Converter datas, precos e volumes para formatos numericos utilizaveis.
3. Ordenar os dados por item e por data.
4. Calcular retornos entre observacoes consecutivas.
5. Calcular metricas de volatilidade e risco.
6. Criar resumos estatisticos em CSV.
7. Criar graficos de preco, volume, eventos e volatilidade.

O objetivo nao foi apenas mostrar o preco historico. O objetivo foi transformar o preco em indicadores que permitam argumentar se o mercado apresenta instabilidade.

## Como a volatilidade e calculada

A volatilidade e baseada no desvio padrao dos retornos logaritmicos.

Formula principal:

```r
annualized_volatility_percent = sd(log_return, na.rm = TRUE) * sqrt(365) * 100
```

Interpretacao:

- `sd(log_return)` mede a dispersao diaria dos retornos.
- `sqrt(365)` transforma a volatilidade diaria numa estimativa anual.
- Usa-se `365` porque o Steam Market esta aberto todos os dias, incluindo fins de semana.
- `* 100` converte o resultado para percentagem.

Quanto maior for a volatilidade anualizada, mais instavel e o preco do item.

Esta abordagem foi usada porque a volatilidade historica, em financas, normalmente mede a dispersao dos retornos de um ativo. Ou seja, nao se mede apenas o preco em si, mas sim a forma como esse preco varia entre observacoes.

## Porque foram usados retornos logaritmicos

Foi usado:

```r
log_return = log(price / lag(price))
```

Este tipo de retorno e comum em analise financeira porque compara precos de forma proporcional. O que interessa nao e apenas saber se o preco subiu 10 euros, mas sim quanto isso representa em percentagem face ao preco anterior.

Exemplo economico:

- uma subida de 10 euros num item de 50 euros e muito relevante;
- uma subida de 10 euros num item de 1000 euros e muito menos relevante.

Os retornos logaritmicos ajudam a comparar estes movimentos de forma mais justa entre itens com precos diferentes.

## Porque foi usado 365

Em mercados financeiros tradicionais, muitas vezes usa-se `sqrt(252)`, porque as bolsas costumam estar abertas apenas nos dias uteis.

Neste trabalho foi usado:

```r
sqrt(365)
```

A razao e economica e pratica: o Steam Market nao fecha ao fim de semana. Os jogadores podem comprar e vender itens todos os dias do ano. Por isso, usar 365 faz mais sentido do que usar 252, porque o mercado analisado funciona continuamente.

Este valor serve para anualizar a volatilidade. A ideia e transformar a volatilidade observada entre dias/observacoes numa medida anual comparavel. A variancia cresce aproximadamente com o tempo, e por isso o desvio padrao cresce com a raiz quadrada do tempo.

Nota importante: como alguns itens podem nao ter vendas todos os dias, a anualizacao e uma aproximacao. Mesmo assim, `365` e mais adequado para este mercado do que `252`, porque nao existe fecho regular ao fim de semana.

Esta escolha tambem aproxima o Steam Market de outros mercados digitais que funcionam 24/7, como cryptoativos. Nesses mercados, e comum usar 365 periodos diarios para anualizar, porque ha negociacao continua durante fins de semana e feriados.

## Resumo estatistico

Cada script cria um ficheiro de resumo com metricas como:

| Variavel | Significado |
| --- | --- |
| `observations` | Numero de observacoes usadas na analise. |
| `average_price` | Preco medio, quando aplicavel. |
| `min_price` | Preco minimo observado. |
| `max_price` | Preco maximo observado. |
| `price_range_percent` | Diferenca percentual entre preco maximo e minimo. |
| `daily_return_sd_percent` | Desvio padrao dos retornos diarios em percentagem. |
| `annualized_volatility_percent` | Volatilidade anualizada. |
| `average_absolute_daily_move_percent` | Movimento diario medio em valor absoluto. |
| `days_with_moves_above_5_percent` | Numero de dias com movimentos iguais ou superiores a 5%. |
| `share_of_days_above_5_percent` | Percentagem de dias com movimentos fortes. |
| `biggest_daily_gain_percent` | Maior subida diaria. |
| `biggest_daily_loss_percent` | Maior queda diaria. |

## Como interpretar a volatilidade

Um item mostra sinais de volatilidade quando:

- tem `annualized_volatility_percent` alta;
- apresenta muitos dias com `big_move = TRUE`;
- tem grande diferenca entre `min_price` e `max_price`;
- a linha de `rolling_volatility_30` sobe em determinados periodos;
- os graficos mostram saltos bruscos de preco.

Exemplo de interpretacao:

> Se uma skin tem muitos dias com movimentos acima de 5% e uma volatilidade anualizada elevada, isso sugere que o seu preco nao evolui de forma estavel. O mercado desse item tem maior risco e maior incerteza.

## Conclusoes economicas que se podem tirar

Com esta analise, e possivel concluir que existe volatilidade quando os dados mostram:

- precos com saltos visiveis nos graficos;
- muitos movimentos diarios acima de 5%;
- diferencas grandes entre preco minimo e preco maximo;
- volatilidade anualizada elevada;
- aumentos da volatilidade perto de eventos importantes.

No caso das skins e itens de CS2/CS:GO, isto sugere que o preco nao depende apenas do valor estetico do item. O preco tambem e influenciado por procura, oferta, especulacao, liquidez e alteracoes feitas ao jogo.

A principal conclusao do trabalho e que estes mercados funcionam como mercados digitais especulativos: os precos reagem a eventos, a interesse dos jogadores e a expectativas futuras. Por isso, alguns itens podem apresentar risco elevado para quem compra com objetivo de investimento.

Esta analise nao prova sozinha a causa exata de cada subida ou descida. O que ela prova e que a instabilidade existe e pode ser medida com indicadores quantitativos.

## Graficos gerados

Os scripts R criam dois tipos principais de graficos:

| Tipo | Localizacao | Objetivo |
| --- | --- | --- |
| Graficos basicos | `graphs/basic` | Mostrar apenas preco de mercado ao longo do tempo. |
| Graficos completos | `graphs` | Mostrar preco, media movel, movimentos grandes e eventos. |
| Graficos de volatilidade | `graphs` | Mostrar a volatilidade movel de 30 observacoes. |

## Eventos marcados

Alguns graficos incluem linhas verticais para eventos importantes:

- `CS2 Announcement`: 2023-03-22.
- `CS2 Release`: 2023-09-27.
- `Trade-Up Update`: 2025-10-23, usado especialmente nas Paracord knives.

Estas linhas ajudam a comparar movimentos de preco com acontecimentos que podem ter influenciado o mercado.

## Ficheiros de output

Cada pasta guarda outputs parecidos:

| Output | Significado |
| --- | --- |
| `*_volatility_dataset.csv` | Dataset tratado com retornos, movimentos e volatilidade. |
| `*_volatility_summary.csv` | Resumo estatistico da analise. |
| `*_volatility_test.txt` | Texto curto com conclusao sobre volatilidade, quando aplicavel. |
| `graphs/*.png` | Graficos principais da analise. |
| `graphs/basic/*.png` | Graficos simples de preco e data. |

## Conclusao esperada

A analise permite defender que existe volatilidade no mercado das skins quando os resultados mostram movimentos frequentes, amplitudes grandes entre minimo e maximo, e volatilidade anualizada elevada.

No caso da Desert Eagle Blaze em 2024, o teste extra foi criado para mostrar isso de forma direta, usando retornos, movimentos acima de 5% e volatilidade anualizada.

## Fontes usadas

- [The Motley Fool - How to Calculate Annualized Volatility](https://www.fool.com/investing/how-to-calculate/annualized-volatility/): usado para confirmar a logica geral da volatilidade anualizada, em que se multiplica o desvio padrao pela raiz quadrada do numero de periodos.
- [Loris Tools - Historical Volatility Calculator](https://loris.tools/tools/volatility-calculator): usado como referencia para o calculo de volatilidade historica com retornos logaritmicos, desvio padrao e anualizacao; tambem refere o uso de `sqrt(365)` em mercados que negociam todos os dias.

## Analise revista

A pasta `robustness/` repete a analise com os dados limpos (outliers, dias sem vendas, dados horarios), acrescenta metricas de liquidez, testes estatisticos (Jarque-Bera, ARCH-LM, Welch, Wilcoxon, F) e estudos de evento para o update dos trade-ups, o anuncio/lancamento do CS2 e as vitorias da FaZe. Os resultados e a interpretacao estao em `robustness/RESULTADOS.md`.
