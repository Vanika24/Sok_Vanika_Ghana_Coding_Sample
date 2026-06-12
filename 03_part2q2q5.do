*******************************************************
* 03_part2q2q5.do
* Output: $dataclean/03_part2q2q5.dta
*******************************************************

version 19.5
clear all
set more off

capture log close
log using "$output/logs/03_part2q2q5.log", replace text

*******************************************************
* part 2 evaluating RCT
*******************************************************
use "$dataclean/final_dataset.dta", clear

keep if wave == 2
keep if !missing(kessler_score)

gen severe_dep = (kessler_categories == 4)
label variable severe_dep "=1 if severe depression (Kessler cat. 4)"

*******************************************************
* Group therapy effective & interaction term
*******************************************************
gen treat_female = treat_hh * female
label variable treat_female "Interaction: Treated household x Female"

*******************************************************
* table 4: Treatment Effect of GT Sessions on Kessler Score (Wave 2)
*******************************************************

* model 1: Bivariate
eststo q2_m1: regress kessler_score treat_hh, vce(cluster hhid)

* model 2: + demographics
eststo q2_m2: regress kessler_score treat_hh female age age_sq, ///
    vce(cluster hhid)

* model 3: Full model
eststo q2_m3: regress kessler_score treat_hh female age age_sq hh_size log_wealth, ///
    vce(cluster hhid)

* export Q2 table // the tex file is uploaded to Overleaf and modified there	
esttab q2_m1 q2_m2 q2_m3 using "$output/tex/table_q2_treatment.tex", replace   ///
    booktabs label                                                    ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01)                       ///
    mtitles("Bivariate" "+ Demographics" "Full model")              ///
    title("Treatment Effect of GT Sessions on Kessler Score (Wave 2)") ///
    note("Outcome: Kessler-10 score (10-50). Clustered SE at household level. * p<0.10, ** p<0.05, *** p<0.01") ///
    stats(N r2, fmt(%9.0f %9.3f) labels("Observations" "R-squared")) ///
    keep(treat_hh female age age_sq hh_size)                        ///
    order(treat_hh female age age_sq hh_size)
	
* supplementary: LPM on severe depression
eststo q2_lpm: regress severe_dep treat_hh female age age_sq hh_size, ///
    vce(cluster hhid)

*******************************************************
* table 5: Heterogeneous Treatment Effects by Gender (Wave 2)
*******************************************************

* effect differ by gender
eststo q3_interact: regress kessler_score female treat_hh treat_female, ///
    vce(cluster hhid)

* export Q3 table // the tex file is uploaded to Overleaf and modified there
esttab q3_interact using "$output/tex/table_q3_interaction.tex", replace           ///
    booktabs label                                                       ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01)                          ///
    mtitle("Kessler Score")                                             ///
    title("Heterogeneous Treatment Effects by Gender (Wave 2)") ///
    note("Reference group: Male in control household."                  ///
         "Clustered standard errors at household level in parentheses." ///
         "* p<0.10, ** p<0.05, *** p<0.01")                           ///
    stats(N r2, fmt(%9.0f %9.3f) labels("Observations" "R-squared"))

	
lincom _cons                          // male x control
lincom _cons + treat_hh               // male x treated
lincom _cons + female                 // female x control
lincom _cons + female + treat_hh + treat_female  // female x treated

sum kessler_score
tabstat severe_dep if wave == 2, by(treat_hh) stats(mean n)

* note: I created Table 1 (Descriptive Statistics for Wave 1 and Wave 2) manually
* in LaTeX to better fit the data structure and formatting style.
log close
