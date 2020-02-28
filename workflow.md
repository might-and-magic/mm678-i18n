tools/add_context.py to convert template_without_context/ to 1_template/ (with context)

csv2po.py `exec()` to generate 2_dev/, 3_i18n/, 4_prod/

if .po in 3_i18n/ are modified, use csv2po.py `generateProd()` to generate 4_prod/

csv2po.py:
* `exec()`: generate 2_dev/, 3_i18n/, 4_prod/
* `generateDevAndI18n()`: generate 2_dev/, 3_i18n/
* `generateProd()`: generate 4_prod/ (2_dev/, 3_i18n/ exist)
* `generateDevOnly()`: generate 2_dev/

make_postprod.py to generate 5_postprod/

make 6_finalprod semi-manually
