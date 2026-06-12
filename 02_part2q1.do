*******************************************************
* 02_part2q1.do
* Output: $dataclean/02_part2q1.dta
*******************************************************

version 19.5
clear all
set more off

capture log close
log using "$output/logs/02_part2q1.log", replace text

*******************************************************
* Exploratory and Causal Analysis
*******************************************************
use "$dataclean/final_dataset.dta", clear

keep if wave == 1
keep if !missing(kessler_score) //only interested in those who have kessler score

* drop extreme asset outliers for descriptive analysis
drop if extreme_asset_flag == 1
count  

* summary stat
summarize kessler_score, detail
tab kessler_categories
summarize value_total, detail

* specifically flag severe depression (category 4) as a binary outcome
gen severe_dep = (kessler_categories == 4)
label variable severe_dep "=1 if severe depression (Kessler category 4)"

* create wealth quartile variable
xtile wealth_q = value_total, nquantiles(4)

label define wealth_lbl     ///
    1 "Q1 (Poorest)"        ///
    2 "Q2"                  ///
    3 "Q3"                  ///
    4 "Q4 (Wealthiest)"
label values wealth_q wealth_lbl
label variable wealth_q "Household wealth quartile (total asset value)"

* proportion with severe depression by quartile
tabstat severe_dep, by(wealth_q) stats(mean n)

*******************************************************
* table 2: Kessler Score and Household Weaalth (Wave 1)
*******************************************************

* using linear-log model
* model 1: wealth alone
eststo w1: regress kessler_score log_wealth, vce(cluster hhid)

* model 2: + individual demographics
eststo w2: regress kessler_score log_wealth female age age_sq, ///
    vce(cluster hhid)

* model 3: full model
eststo w3: regress kessler_score log_wealth female age age_sq  ///
    i.maritalstatus  ///
    hh_size i.fathereduc_cat, vce(cluster hhid)
	
* export table // the tex file is uploaded to Overleaf and modified there
esttab w1 w2 w3 using "$output/tex/table1_wealth.tex", replace        ///
    booktabs label                                                   ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01)                      ///
    mtitles("Bivariate" "+ Demographics" "Full model")             ///
    title("Kessler Score and Household Wealth (Wave 1)")  ///
    addnote("Clustered standard errors at household level."         ///
            "Reference categories: Male, Married, Father educ = None." ///
            "* p<0.10, ** p<0.05, *** p<0.01")                    ///
    stats(N r2, fmt(%9.0f %9.3f) labels("Observations" "R-squared")) ///
    keep(log_wealth female age age_sq                               ///
         2.maritalstatus 3.maritalstatus 4.maritalstatus            ///
         5.maritalstatus 6.maritalstatus hh_size)                   ///
    order(log_wealth female age age_sq                              ///
          2.maritalstatus 3.maritalstatus 4.maritalstatus           ///
          5.maritalstatus 6.maritalstatus hh_size)                  ///
    varlabels(2.maritalstatus "Consensual union"                    ///
              3.maritalstatus "Separated"                           ///
              4.maritalstatus "Divorced"                            ///
              5.maritalstatus "Widowed"                             ///
              6.maritalstatus "Never married")

*******************************************************
* table 3: Kessler Score and Marital Status (Wave 1)
*******************************************************

* model 1: marital status alone
eststo m1: regress kessler_score i.maritalstatus , vce(cluster hhid)

* model 2: + individual demographics
eststo m2: regress kessler_score i.maritalstatus female age age_sq, vce(cluster hhid)

* model 3: full model — adding wealth here is the key test:
* does widowhood effect shrink when we control for wealth?
* if yes: part of the effect runs through material deprivation
* if no:  the effect is genuinely about social loss
eststo m3: regress kessler_score i.maritalstatus female age age_sq  ///
    log_wealth hh_size i.fathereduc_cat, vce(cluster hhid)

* export table // the tex file is uploaded to Overleaf and modified there
esttab m1 m2 m3 using "$output/tex/table2_marital.tex", replace      ///
    booktabs label                                                   ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01)                      ///
    mtitles("Bivariate" "+ Demographics" "Full model")             ///
    title("Kessler Score and Marital Status (Wave 1)")    ///
    addnote("Clustered standard errors at household level."         ///
            "Reference category: Married."                         ///
            "* p<0.10, ** p<0.05, *** p<0.01")                    ///
    stats(N r2, fmt(%9.0f %9.3f) labels("Observations" "R-squared")) ///
    keep(2.maritalstatus 3.maritalstatus 4.maritalstatus            ///
         5.maritalstatus 6.maritalstatus                            ///
         female age age_sq log_wealth hh_size)                      ///
    order(2.maritalstatus 3.maritalstatus 4.maritalstatus           ///
          5.maritalstatus 6.maritalstatus                           ///
          female age age_sq log_wealth hh_size)                     ///
    varlabels(2.maritalstatus "Consensual union"                    ///
              3.maritalstatus "Separated"                           ///
              4.maritalstatus "Divorced"                            ///
              5.maritalstatus "Widowed"                             ///
              6.maritalstatus "Never married")
log close		
		