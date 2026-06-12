*******************************************************
* 01_cleaning.do
* Output: $dataclean/01_cleaning.dta
*******************************************************
version 19.5
clear all
set more off

capture log close
log using "$output/logs/01_cleaning.log", replace text

*******************************************************
* proxy variable
*******************************************************
use "$dataraw/demographics.dta", clear

bysort hhid: egen hh_size = count(hhmid) if wave == 1

* carry the wave 1 household size to wave 2
bysort hhid: egen hh_size_proxy = max(hh_size)
drop hh_size
rename hh_size_proxy hh_size

* label
label variable hh_size "Household size proxy (based on Wave 1 members surveyed)"

replace age = . if age == -999
replace agemarried = . if agemarried == -999

* stata stores string missing as "" but some entries are literal "."
* which would interfere with string operations in analysis
replace religionother   = "" if religionother   == "."
replace fathereducother = "" if fathereducother == "."
replace mothereducother = "" if mothereducother == "."

save "$dataclean/clean_demographics.dta", replace


*******************************************************
* calculate the monetary value 
*******************************************************
use "$dataraw/assets.dta", clear

* toolcode 19 and 35 both carry the label "Plough", I assume they meant the same thing
replace toolcode = 19 if toolcode == 35 & Asset_Type == 2

* step 1: tidying the three code columns of asset types into one
gen asset_code = .
replace asset_code = animaltype               if Asset_Type == 1
replace asset_code = toolcode         + 100   if Asset_Type == 2
replace asset_code = durablegood_code + 200   if Asset_Type == 3

label variable asset_code "Unified asset code (animals=1-8, tools=101+, durables=201+)"

* build unified string asset_name (for readability only)
decode animaltype,       gen(animal_name)
decode toolcode,         gen(tool_name)
decode durablegood_code, gen(durable_name)

gen asset_name = ""
replace asset_name = animal_name  if Asset_Type == 1
replace asset_name = tool_name    if Asset_Type == 2
replace asset_name = durable_name if Asset_Type == 3

drop animal_name tool_name durable_name
drop animaltype toolcode durablegood_code

label variable asset_name "Asset name (unified across all asset types)"

* step 2: clean currentvalue and quantity before imputation
sort hhid wave Asset_Type
//br hhid Asset_Type asset_code asset_name

* a current value of 0 for any real asset is meaningless and
* is almost certainly a data entry error, so I recode them to missing (.)
replace currentvalue = . if currentvalue == 0 | currentvalue == .d

* flag extreme quantity outliers
tabstat quantity, stats(p50 p75 p90 p95 p99 max)
tabstat quantity, by(Asset_Type) stats(n p50 p75 p90 p95 p99 max)
tabstat quantity if quantity > 20, by(asset_name) stats(n p50 p75 p90 p99 max)

replace quantity = . if asset_name == "Box Iron"  & quantity > 50
replace quantity = . if asset_name == "Coal Pot"  & quantity > 50
replace quantity = . if asset_name == "other"     & quantity > 200

* impute missing currentvalue with median by asset type

* use the median (not mean) because asset values are right-skewed.
* medians are pooled across both waves for stability.
* group by asset_code (numeric) to correctly handle the Plough fix above.
bysort asset_code: egen median_currentvalue = median(currentvalue)
label variable median_currentvalue "Median current value per asset type (imputation basis)"

gen currentvalue_imputed = currentvalue
replace currentvalue_imputed = median_currentvalue if missing(currentvalue)

label variable currentvalue_imputed "Current value per unit (missing and zeros imputed with group median)"

* verify
count if missing(currentvalue_imputed)   // should be 0
sort hhid wave Asset_Type



*******************************************************
* total monetary value per observation
*******************************************************
gen total_value = quantity * currentvalue_imputed

label variable total_value "Total monetary value of asset (quantity × imputed current value)"

count if missing(total_value)   // should be 0



*******************************************************
* collapse to household-wave level
*******************************************************
gen value_animals  = total_value if Asset_Type == 1
gen value_tools    = total_value if Asset_Type == 2
gen value_durables = total_value if Asset_Type == 3

replace value_animals  = 0 if missing(value_animals)
replace value_tools    = 0 if missing(value_tools)
replace value_durables = 0 if missing(value_durables)

collapse (sum) value_animals value_tools value_durables, by(hhid wave)

gen value_total = value_animals + value_tools + value_durables

label variable hhid           "Household ID"
label variable wave           "Survey wave"
label variable value_animals  "Total value of animals owned"
label variable value_tools    "Total value of tools owned"
label variable value_durables "Total value of durable goods owned"
label variable value_total    "Total value of all assets"

* double check each household should appear at most twice
bysort hhid: gen n_waves = _N
tab n_waves
drop n_waves

desc
sum

destring hhid, replace // destring for future merge
format hhid %9.0f

* 14 households have value_animals > 1,000,000 — retained but flagged
gen extreme_asset_flag = (value_total > 1000000)
label variable extreme_asset_flag "=1 if total asset value exceeds 1,000,000"

save "$dataclean/clean_assets.dta", replace


*******************************************************
* construct Kessler-10 score and categorical variable
*******************************************************
use "$dataraw/depression.dta", clear

*check any missing
tab tired
tab tired, nolabel

sum
desc

//br if tired == .

* number of K-10 items answered (out of 10)
egen n_answered = rownonmiss(tired nervous sonervous hopeless restless ///
                             sorestless depressed everythingeffort ///
                             nothingcheerup worthless)

* sum of answered items, the missing option skips missing rather than treating as 0
egen raw_sum = rowtotal(tired nervous sonervous hopeless restless ///
                        sorestless depressed everythingeffort ///
                        nothingcheerup worthless), missing

label variable n_answered "Number of K-10 items answered (out of 10)"
label variable raw_sum    "Raw sum of answered K-10 items"


* uncomment the following to only keep full responses
/* drops 291 partial + 22 all-missing
keep if n_answered == 10   
* score is the raw sum — already on 10-50 scale
gen kessler_score = raw_sum
label variable kessler_score ///
    "Kessler-10 psychological distress score (range 10-50)"
*/

* in this case, I will work with those missing
* prorate score to 10-50 scale
gen kessler_score = (raw_sum / n_answered) * 10

label variable kessler_score ///
    "Kessler-10 psychological distress score (range 10-50)"

* double check score should be bounded between 10 and 50
assert kessler_score >= 10 & kessler_score <= 50 if !missing(kessler_score)

sum kessler_score, detail
count if missing(kessler_score)    // should be 22

* construct kessler categories
gen kessler_categories = .
replace kessler_categories = 1 if kessler_score >= 10 & kessler_score < 20
replace kessler_categories = 2 if kessler_score >= 20 & kessler_score < 25
replace kessler_categories = 3 if kessler_score >= 25 & kessler_score < 30
replace kessler_categories = 4 if kessler_score >= 30 & kessler_score <= 50
* kessler_categories remains missing where kessler_score is missing

label define kessler_cat_lbl  ///
    1 "No significant depression" ///
    2 "Mild depression"           ///
    3 "Moderate depression"       ///
    4 "Severe depression"

label values kessler_categories kessler_cat_lbl
label variable kessler_categories "K-10 distress category (per manual thresholds)"

tab kessler_categories, missing

* confirm no observations fall outside valid category range
assert !missing(kessler_categories) if !missing(kessler_score)
count if missing(kessler_categories) & !missing(kessler_score)  // should be 0

* flag highly incomplete responses for sensitivity analysis
gen incomplete_flag = (n_answered < 5) & (n_answered > 0)
label variable incomplete_flag "=1 if fewer than 5 K-10 items answered (unreliable score)"
tab incomplete_flag   // shows how many to watch out for in regressions

tab n_answered
count if n_answered < 5

* clean up intermediate variables
drop n_answered raw_sum   

save "$dataclean/clean_depression.dta", replace

*******************************************************
* combining all three datasets
*******************************************************
use "$dataclean/clean_demographics.dta", clear

merge 1:1 hhid hhmid wave using "$dataclean/clean_depression.dta"
drop _merge
merge m:1 hhid wave using "$dataclean/clean_assets.dta"

sort hhid hhmid wave

bysort hhid hhmid: gen n_obs = _N
tab n_obs
assert n_obs <= 2
drop n_obs

gen female = (gender == 5)
label variable female "=1 if Female, =0 if Male"

gen age_sq = age^2
label variable age_sq "Age squared"

* recode education into 4 categories
gen fathereduc_cat = .
replace fathereduc_cat = 1 if fathereduc == 0
replace fathereduc_cat = 2 if fathereduc == 2
replace fathereduc_cat = 3 if inrange(fathereduc, 3, 7)
replace fathereduc_cat = 4 if inrange(fathereduc, 8, 11)

label define educ_cat_lbl       ///
    1 "None"                    ///
    2 "Primary"                 ///
    3 "Secondary"               ///
    4 "Post-secondary"
label values fathereduc_cat educ_cat_lbl
label variable fathereduc_cat "Father's education (4 categories)"
tab fathereduc_cat, missing

gen mothereduc_cat = .
replace mothereduc_cat = 1 if mothereduc == 0
replace mothereduc_cat = 2 if mothereduc == 2
replace mothereduc_cat = 3 if inrange(mothereduc, 3, 7)
replace mothereduc_cat = 4 if inrange(mothereduc, 8, 11)

// generate log_wealth for future use (more detial in supplementary PDF)
gen log_wealth = log(value_total)
label variable log_wealth "Log of total household asset value"
summarize log_wealth, detail

label values mothereduc_cat educ_cat_lbl
label variable mothereduc_cat "Mother's education (4 categories)"
tab mothereduc_cat, missing

drop _merge gender

order hhid hhmid wave villageid treat_hh ///
      female age relationship maritalstatus spouseinhouse agemarried ///
      religion religionother fatherinhouse fathereduc fathereducother ///
      motherinhouse mothereduc mothereducother hh_size ///
      tired nervous sonervous hopeless restless sorestless ///
      depressed everythingeffort nothingcheerup worthless ///
      kessler_score kessler_categories incomplete_flag ///
      value_animals value_tools value_durables value_total extreme_asset_flag 

save "$dataclean/final_dataset.dta", replace
log close
