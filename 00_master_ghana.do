/*  00_master_ghana.do 
  Author: Vanika Sok
  Date  : 2/26/2026

  Description: Master do-file for RCTs Ghana project on mental health program. The 
			   only do file professor need to run. I set up the do-files this way for scalability. 
			   When working with complex  datasets, it is easier to debug and 
			   the code is more organized.
			   
  
  Inputs:
    - $dataraw/   (raw task files, note "data" folder is the original dataset)

  Outputs:
    - $dataclean/ (cleaned tidy datasets + analysis datasets)
    - $output/    (logs, tex)
*/

version 19.5
clear all
set more off

**********************************************************************
****************************** 01 Set Up *****************************
**********************************************************************
* project root - edit to your own path
cd "/Users/vanikasok/Desktop/SOK_Ghana_GT_2026"

global ROOT "`c(pwd)'"

global code      "$ROOT/code"
global dataraw   "$ROOT/dataraw"
global dataclean "$ROOT/dataclean"
global output    "$ROOT/output"

capture log close
log using "$output/logs/master_ghana.log", replace text

* set seed for reproducibility
set seed 200330926

**********************************************************************
************************ 02 Clean + Analysis *************************
**********************************************************************
* 3 sub-do files

do "$code/01_cleaning.do"        // cleaning all 3 datasets
do "$code/02_part1.do"        // analysis on wave 1 
do "$code/03_part2.do"     // analysis on wave 2

display "00_master_ghana.do completed successfully."
log close

