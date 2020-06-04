If .po in 0_source/ or 1_template/ is modified, run tools/add_context.py to convert 0.5_template_without_context/ to 1_template/ (with context)

If .po in 3_i18n/ are modified, use tool to generate .mo, then use csv2po.py `generateProd()` to generate 4_prod/

csv2po.py:
* `exec()`: generate 2_dev/, 3_i18n/, 4_prod/
* `generateDevAndI18n()`: generate 2_dev/, 3_i18n/
* `generateProd()`: generate 4_prod/ (2_dev/, 3_i18n/ exist)
* `generateDevOnly()`: generate 2_dev/

Run tools/make_postprod.py to generate 5_postprod/

Make 6_setup/ with tools/make_setup.py

Update tools/versions.py When updating
