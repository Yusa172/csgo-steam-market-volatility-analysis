# Corre toda a analise a partir da raiz do repositorio:
#   Rscript run_all.R
# Os datasets ja estao no repositorio; para os voltar a recolher usar generate_all_datasets.py.

scripts <- c(
  "weapon_cases/analyze_weapon_cases.R",
  "galil_ar_chatterbox/analyze_galil_ar_chatterbox.R",
  "desert_eagle_blaze/analyze_desert_eagle_blaze.R",
  "paracord_knives/analyze_paracord_knives.R",
  "major_stickers/analyze_major_stickers.R",
  "robustness/analyze_robustness.R"
)

for(script in scripts){
  cat("\n\n######## ", script, " ########\n")
  source(script, local = new.env())
}
