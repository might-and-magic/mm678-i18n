# Workflow

## Start a new language version

In settings.py, change `source_encoding`, also change `custom_list` and `conflict_priority` if necessary

Add 0_source/LANG/

Use csv2po.py `exec()` to generate files

## Updating & production making

If files in 0_source/ or 0.5_template_without_context are modified, run tools/add_context.py to convert 0.5_template_without_context/ to 1_template/ (with context), then use `generateDevOnly()` to generate 2_dev/, then update .po files in 3_i18n/ from source with tool (poedit)

If .po files in 3_i18n/ are modified, use tool (poedit) to generate .mo, then use csv2po.py `generateProd()` to generate 4_prod/

csv2po.py:
* `exec()`: generate 2_dev/, 3_i18n/, 4_prod/
* `generateDevAndI18n()`: generate 2_dev/, 3_i18n/
* `generateProd()`: generate 4_prod/ (2_dev/, 3_i18n/ exist)
* `generateDevOnly()`: generate 2_dev/

Run tools/make_postprod.py to generate 5_postprod/

Make 6_setup/ with tools/make_setup.py (open make_setup.py and follow the 3 steps)

## Simplified Chinese to Traditional Chinese

Run tools/zhconvert.py

## Everything that need to be done after an MM Merge update

Update tools/versions.py and 6_setup/dev/LANG/MMVER/mm_i18n.nsi

Replace MM Merge Version (date format) and Lang Versions (date format and dot format) in docs/zh/README.md, write changelog

Update non_text/scripts_datatables/LANG/mmmerge/

Then do what "Updating & production making" says
