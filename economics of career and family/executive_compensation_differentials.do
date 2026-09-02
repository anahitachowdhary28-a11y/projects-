* Econ 57 final project final do-file
* Authors: Anahita Chowdhary, Ahaan Jindal, Torsha Chakraverty

clear all
set more off
capture log close _all

* define globals
global main "/Users/torshachakraverty/Desktop/ec57final"
global log "${main}/log"
global input "${main}/input"
global output "${main}/outputs"

************************* Data Cleaning ****************************************
* Load the data
use "${input}/lastcompustat.dta"

* renaming year variable
rename fyear year

* dropping the second observation in a year 
duplicates drop gvkey year, force

* merging with execucomp data
* our execucomp data was run through the pset 3 cleaning code first to create variables like titlenew2 and to CPI-adjust our compensation metrics
merge 1:m gvkey year using "${input}/lastcleanexecucomp.dta"

* drops items that are not matched across datasets
drop if _merge != 3

save "${input}/lastcleandata.dta", replace

************************* Analysis ****************************************
*==================================================================
* SECTION 1: CREATING PERFORMANCE DUMMIES
*==================================================================

*------------------------------------------------------------------
* STEP 0: Load data and clean up
*------------------------------------------------------------------
log using "${log}/analysis_log.txt", replace text

use "${input}/lastcleandata.dta", clear

* Save the executive-level dataset to a tempfile so we can merge
* the firm-year flags back onto it at the end
tempfile fulldata
save `fulldata', replace

*------------------------------------------------------------------
* STEP 1: Collapse to firm-year level
*
* The original data has multiple executives per firm-year (one row per exec).
* Firm financials are identical across execs at the same firm-year, so we drop duplicates to get one row per gvkey-year before running panel operations.
*------------------------------------------------------------------
keep gvkey year gsector mkvalt revt prcc_f
duplicates drop gvkey year, force


*------------------------------------------------------------------
* STEP 2: Compute gap-aware growth, industry average, and underperform dummy
*
* Standard L.v requires consecutive years. 
* Many firms have gaps in Compustat coverage, so we instead grab the most recent prior
* observation regardless of how many years back it is, then annualize the growth rate by the size of the gap. 
* Capped at gap <= 3 since longer gaps stretch the "executive performance" interpretation too thin.
*
* For each variable v:
*   growth_v     = firm's annualized YoY growth in v
*   indavg_v     = mean of growth_v across all firms in the same gsector-year
*   gap_v        = firm growth minus industry average growth
*   underperform_v = 1 if firm growth < industry avg, 0 otherwise
*------------------------------------------------------------------
local yvars  "mkvalt revt prcc_f"
local indvar "gsector"

foreach v of local yvars {

    * Prior observation within each firm (gap-aware)
    bysort gvkey (year): gen double `v'_prev   = `v'[_n-1]
    bysort gvkey (year): gen int    yr_prev_`v' = year[_n-1]
    gen int yr_gap_`v' = year - yr_prev_`v'

    * Annualized growth rate: (v_t / v_{t-gap})^(1/gap) - 1
    * Restricted to valid positive prior values and gaps of 1-3 years
    gen double growth_`v' = (`v' / `v'_prev)^(1 / yr_gap_`v') - 1 ///
        if !missing(`v'_prev) & `v'_prev > 0 & yr_gap_`v' > 0 & yr_gap_`v' <= 3

    drop `v'_prev yr_prev_`v' yr_gap_`v'

    * Industry-year average growth
    bysort `indvar' year: egen double indavg_`v' = mean(growth_`v')

    * Gap: how far firm growth is from industry average
    gen double gap_`v' = growth_`v' - indavg_`v'
    label variable gap_`v' "Gap in `v' growth vs `indvar' avg"

    * Underperformance dummy
    gen byte underperform_`v' = .
    replace underperform_`v' = 1 if growth_`v' <  indavg_`v' & growth_`v' < . & indavg_`v' < .
    replace underperform_`v' = 0 if growth_`v' >= indavg_`v' & growth_`v' < . & indavg_`v' < .
    label variable underperform_`v' "=1 if YoY growth in `v' below `indvar' avg"
}


*------------------------------------------------------------------
* STEP 4: Create bottom-third and top-third dummies within industry-year
*
* Middle third is the omitted category in all regressions.
* bottom_third_v = 1 if in the worst-performing third among underperformers
* top_third_v = 1 if in the best-performing third among overperformers
*------------------------------------------------------------------
foreach v of local yvars {
    * Underperformers: bottom third of the gap distribution
    bysort `indvar' year: egen p33_under_`v' = pctile(gap_`v') if underperform_`v' == 1, p(33)
    gen byte bottom_third_`v' = 0 if !missing(gap_`v')
    replace bottom_third_`v' = 1 if (gap_`v' <= p33_under_`v') & underperform_`v' == 1 & !missing(gap_`v')

    * Overperformers: top third of the gap distribution
    bysort `indvar' year: egen p67_over_`v' = pctile(gap_`v') if underperform_`v' == 0, p(67)
    gen byte top_third_`v' = 0 if !missing(gap_`v')
    replace top_third_`v' = 1 if (gap_`v' >= p67_over_`v') & underperform_`v' == 0 & !missing(gap_`v')

    drop p33_under_`v' p67_over_`v'
}


*------------------------------------------------------------------
* STEP 5: Save the firm-year flag dataset to a tempfile
*------------------------------------------------------------------
keep gvkey year growth_* indavg_* underperform_* gap_* bottom_third_* top_third_*
tempfile firmflags
save `firmflags', replace


*------------------------------------------------------------------
* STEP 6: Reload executive-level data and merge the flags back
*
* m:1 because many exec rows per firm-year match one firm-year row.
*------------------------------------------------------------------
use `fulldata', clear

capture drop _merge
capture drop _merge_perf

merge m:1 gvkey year using `firmflags', gen(_merge_perf)


*------------------------------------------------------------------
* STEP 7: Check distribution of the dummies
*------------------------------------------------------------------
tab1 underperform_mkvalt underperform_revt underperform_prcc_f, missing


*------------------------------------------------------------------
* STEP 8: Save the dataset with performance flags
*------------------------------------------------------------------
save "${input}/lastcleandata_with_underperform.dta", replace


*==================================================================
* SECTION 2: SAMPLE RESTRICTIONS AND VARIABLE CONSTRUCTION
*==================================================================

use "${input}/lastcleandata_with_underperform.dta", clear

* Keep only CEOs and CFOs
keep if titlenew2 == 10 | titlenew2 == 30

* Drop pre-1998 observations (because mkvalt is missing before 1998)
drop if year < 1998

* gsector is stored as a string — convert to numeric before labelling
destring gsector, replace

* Sector labels
label define gsector_lbl ///
    10 "Energy"                  ///
    15 "Materials"               ///
    20 "Industrials"             ///
    25 "Consumer Discretionary"  ///
    30 "Consumer Staples"        ///
    35 "Health Care"             ///
    40 "Financials"              ///
    45 "Information Technology"  ///
    50 "Communication Services"  ///
    55 "Utilities"               ///
    60 "Real Estate"
label values gsector gsector_lbl


*------------------------------------------------------------------
* Earnings variables
*------------------------------------------------------------------
gen real_nonsalary_tdc1          = real_tdc1 - real_salary
gen real_nonsalary_tdc2          = real_tdc2 - real_salary
gen real_nonsalary_nonbonus_tdc1 = real_tdc1 - real_salary - real_bonus
gen real_nonsalary_nonbonus_tdc2 = real_tdc2 - real_salary - real_bonus

* Log earnings and firm characteristics
foreach v in real_tdc1 real_tdc2 real_nonsalary_tdc1 real_nonsalary_tdc2 ///
             real_nonsalary_nonbonus_tdc1 real_nonsalary_nonbonus_tdc2 ///
             mkvalt revt prcc_f emp {
    gen ln_`v' = ln(`v') if `v' > 0
}


*------------------------------------------------------------------
* Age dummies
*------------------------------------------------------------------
gen age_sq = age^2

*------------------------------------------------------------------
* Interaction terms
*
* For each performance metric we create:
*   female_bottom_v  = female x bottom_third_v
*   female_top_v     = female x top_third_v
*   female_gap_v     = female x gap_v  (continuous version)
*------------------------------------------------------------------
foreach v in mkvalt revt prcc_f {
    gen female_bottom_`v' = female * bottom_third_`v'
    gen female_top_`v'    = female * top_third_`v'
    gen female_gap_`v'    = female * gap_`v'
}

* --- Post-Dodd-Frank dummy ---
gen byte post2010 = (year >= 2010)
label variable post2010 "=1 if year >= 2010 (post Dodd-Frank)"

* DiD interaction: gender x time (no performance split)
gen female_post2010 = female * post2010

* DiD interactions: time x performance (market cap)
gen post2010_bottom_mv = post2010 * bottom_third_mkvalt

* DiDiD interactions: gender x time x performance (market cap)
gen female_post2010_bottom_mv = female * post2010 * bottom_third_mkvalt  // underperformers
gen female_post2010_top_mv    = female * post2010 * top_third_mkvalt     // overperformers

* DiDiD interactions: gender x time x performance (revenue growth)
gen female_post2010_bottom_revt = female * post2010 * bottom_third_revt  // underperformers
gen female_post2010_top_revt    = female * post2010 * top_third_revt     // overperformers

* DiDiD interactions: gender x time x performance (stock price)
gen female_post2010_bottom_prcc = female * post2010 * bottom_third_prcc_f  // underperformers
gen female_post2010_top_prcc    = female * post2010 * top_third_prcc_f     // overperformers


*==================================================================
* SECTION 3: SUMMARY STATISTICS
*==================================================================

*------------------------------------------------------------------
* Summary stats for CEOs and CFOs + testing if the gaps are statistically significant
*------------------------------------------------------------------

* Observation counts
tab titlenew2 female, row col

foreach v in mkvalt revt prcc_f {
    tab female bottom_third_`v' if titlenew2 == 10
    tab female bottom_third_`v' if titlenew2 == 30
    tab female top_third_`v'    if titlenew2 == 10
    tab female top_third_`v'    if titlenew2 == 30
}

* T-tests with results table
local vars real_tdc1 real_tdc2 real_nonsalary_tdc1 real_nonsalary_tdc2 mkvalt revt prcc_f ///
           gap_mkvalt gap_prcc_f underperform_mkvalt underperform_prcc_f ///
           bottom_third_mkvalt bottom_third_prcc_f top_third_mkvalt top_third_prcc_f

foreach subset in 10 30 99 {
    if `subset' == 99 {
        local cond ""
        local label "All"
    }
    else {
        local cond "if titlenew2 == `subset'"
        local label "`subset'"
    }
    di "===== `label' ====="
    di "{txt}{hline 60}"
    di "{txt}Variable{col 30}Male Mean{col 42}Female Mean{col 54}p-value"
    di "{txt}{hline 60}"
    foreach v of local vars {
        quietly ttest `v' `cond', by(female)
        di "{txt}`v'{col 30}" %9.3f r(mu_1) "{col 42}" %9.3f r(mu_2) "{col 54}" %6.3f r(p)
    }
    di "{txt}{hline 60}"
}

*------------------------------------------------------------------
* Summary statistics graphs
*------------------------------------------------------------------

* 1. Share of female CEOs/CFOs over time
preserve
collapse (mean) female, by(year titlenew2)
twoway (line female year if titlenew2==10) (line female year if titlenew2==30), ///
    legend(label(1 "CEO") label(2 "CFO")) ///
    title("Share of Female Executives Over Time") ///
    ytitle("Proportion Female") xtitle("Year")
graph export "${output}/female_share_over_time.png", replace
restore

* 2. Average compensation by gender for CEOs over time (salary and nonsalary)
preserve
collapse (mean) real_nonsalary_tdc1 real_tdc1, by(year female titlenew2)
twoway (line real_nonsalary_tdc1 year if female==0 & titlenew2==10) ///
       (line real_nonsalary_tdc1 year if female==1 & titlenew2==10) ///
       (line real_tdc1 year if female==0 & titlenew2==10, lpattern(dash)) ///
       (line real_tdc1 year if female==1 & titlenew2==10, lpattern(dash)), ///
    legend(label(1 "Male CEO (non-salary)") label(2 "Female CEO (non-salary)") ///
           label(3 "Male CEO (total)") label(4 "Female CEO (total)")) ///
    title("Average Compensation Over Time: CEOs") ///
    ytitle("Mean Real Compensation ($000s)") xtitle("Year")
graph export "${output}/comp_over_time_ceos.png", replace
restore

* 3a. Share of CEOs in bottom third of industry market cap growth (by gender)
preserve
collapse (mean) bottom_third_mkvalt, by(year female titlenew2)
twoway (line bottom_third_mkvalt year if female==0 & titlenew2==10, lcolor(blue)) ///
       (line bottom_third_mkvalt year if female==1 & titlenew2==10, lcolor(red)) ///
       (lfit bottom_third_mkvalt year if female==0 & titlenew2==10, lcolor(blue) lpattern(dash)) ///
       (lfit bottom_third_mkvalt year if female==1 & titlenew2==10, lcolor(red) lpattern(dash)), ///
    legend(label(1 "Male CEO") label(2 "Female CEO") label(3 "Male Avg") label(4 "Female Avg")) ///
    title("Share of CEOs in Bottom Third of Industry Mkt Cap Growth") ///
    ytitle("Proportion Underperforming") xtitle("Year")
graph export "${output}/underperformance_rate_ceos.png", replace
restore

* 3b. Share of CEOs in top third of industry market cap growth (by gender)
preserve
collapse (mean) top_third_mkvalt, by(year female titlenew2)
twoway (line top_third_mkvalt year if female==0 & titlenew2==10, lcolor(blue)) ///
       (line top_third_mkvalt year if female==1 & titlenew2==10, lcolor(red)) ///
       (lfit top_third_mkvalt year if female==0 & titlenew2==10, lcolor(blue) lpattern(dash)) ///
       (lfit top_third_mkvalt year if female==1 & titlenew2==10, lcolor(red) lpattern(dash)), ///
    legend(label(1 "Male CEO") label(2 "Female CEO") label(3 "Male Avg") label(4 "Female Avg")) ///
    title("Share of CEOs in Top Third of Industry Mkt Cap Growth") ///
    ytitle("Proportion Overperforming") xtitle("Year")
graph export "${output}/overperformance_rate_ceos.png", replace
restore

* 3c. Share of CFOs in top third of industry market cap growth (by gender)
preserve
collapse (mean) bottom_third_mkvalt, by(year female titlenew2)
twoway (line bottom_third_mkvalt year if female==0 & titlenew2==30, lcolor(blue)) ///
       (line bottom_third_mkvalt year if female==1 & titlenew2==30, lcolor(red)) ///
       (lfit bottom_third_mkvalt year if female==0 & titlenew2==30, lcolor(blue) lpattern(dash)) ///
       (lfit bottom_third_mkvalt year if female==1 & titlenew2==30, lcolor(red) lpattern(dash)), ///
    legend(label(1 "Male CFO") label(2 "Female CFO") label(3 "Male Avg") label(4 "Female Avg")) ///
    title("Share of CFOs in Bottom Third of Industry Mkt Cap Growth") ///
    ytitle("Proportion Underperforming") xtitle("Year")
graph export "${output}/underperformance_rate_cfos.png", replace
restore

* 3d. Share of CFOs in top third of industry market cap growth (by gender)
preserve
collapse (mean) top_third_mkvalt, by(year female titlenew2)
twoway (line top_third_mkvalt year if female==0 & titlenew2==30, lcolor(blue)) ///
       (line top_third_mkvalt year if female==1 & titlenew2==30, lcolor(red)) ///
       (lfit top_third_mkvalt year if female==0 & titlenew2==30, lcolor(blue) lpattern(dash)) ///
       (lfit top_third_mkvalt year if female==1 & titlenew2==30, lcolor(red) lpattern(dash)), ///
    legend(label(1 "Male CFO") label(2 "Female CFO") label(3 "Male Avg") label(4 "Female Avg")) ///
    title("Share of CFOs in Top Third of Industry Mkt Cap Growth") ///
    ytitle("Proportion Overperforming") xtitle("Year")
graph export "${output}/overperformance_rate_cfos.png", replace
restore

* 4a. Mean non-salary compensation by gender and underperformance status (CEOs)
preserve
collapse (mean) real_nonsalary_tdc1, by(female bottom_third_mkvalt titlenew2)
graph bar real_nonsalary_tdc1 if titlenew2==10, ///
    over(bottom_third_mkvalt) by(female, title("Mean Non-Salary Comp by Gender and Underperformance: CEOs") note("")) ///
    ytitle("Mean Real Non-Salary Comp ($000s)")
restore

* 4b. Mean non-salary compensation by gender and underperformance status (CFOs)
preserve
collapse (mean) real_nonsalary_tdc1, by(female bottom_third_mkvalt titlenew2)
graph bar real_nonsalary_tdc1 if titlenew2==30, ///
    over(bottom_third_mkvalt) by(female, title("Mean Non-Salary Comp by Gender and Underperformance: CFOs") note("")) ///
    ytitle("Mean Real Non-Salary Comp ($000s)")
restore

* 5. Female CEO representation by sector
preserve
collapse (mean) female if titlenew2==10, by(gsector)
graph bar female, over(gsector, relabel(1 "Energy" 2 "Materials" 3 "Industrials" ///
    4 "Cons. Disc" 5 "Cons. Staples" 6 "Health Care" 7 "Financials" ///
    8 "Info Tech" 9 "Comm. Services" 10 "Utilities" 11 "Real Estate") ///
    label(angle(45))) ///
    title("Share of Female CEOs by Sector") ///
    ytitle("Proportion Female")
graph export "${output}/female_share_by_sector.png", replace
restore

* 6. Compensation gap over time at underperforming firms (CEOs) with Dodd-Frank line
preserve
keep if titlenew2==10 & bottom_third_mkvalt==1
collapse (mean) real_nonsalary_tdc1, by(year female)
reshape wide real_nonsalary_tdc1, i(year) j(female)
gen comp_gap = real_nonsalary_tdc10 - real_nonsalary_tdc11
twoway (line comp_gap year), ///
xline(2010, lcolor(red) lpattern(dash)) ///
xline(2017, lcolor(orange) lpattern(dash)) ///
xline(2020, lcolor(green) lpattern(dash)) ///
    title("Compensation Gap at Underperforming Firms Over Time (CEOs)") ///
    ytitle("Male minus Female Non-Salary Comp ($000s)") xtitle("Year") ///
    note("Red = Dodd-Frank (2010); Orange = #MeToo (2017); Green = COVID (2020)")
graph export "${output}/comp_gap_over_time.png", replace
restore

* 6b. Compensation gap over time by performance tercile with Dodd-Frank line
preserve
keep if titlenew2 == 10

gen byte middle_two_thirds_mkvalt = 0 if !missing(gap_mkvalt)
replace middle_two_thirds_mkvalt = 1 if bottom_third_mkvalt == 0 & top_third_mkvalt == 0 & !missing(gap_mkvalt)

gen byte perf_tercile = .
replace perf_tercile = 1 if bottom_third_mkvalt == 1
replace perf_tercile = 2 if middle_two_thirds_mkvalt == 1
replace perf_tercile = 3 if top_third_mkvalt == 1
label define perf_lbl 1 "Bottom Third" 2 "Middle" 3 "Top Third"
label values perf_tercile perf_lbl

collapse (mean) real_nonsalary_tdc1, by(year perf_tercile female)
reshape wide real_nonsalary_tdc1, i(year perf_tercile) j(female)
gen comp_gap = real_nonsalary_tdc10 - real_nonsalary_tdc11

twoway (line comp_gap year if perf_tercile == 1, lcolor(blue)) ///
       (line comp_gap year if perf_tercile == 2, lcolor(gs12)) ///
       (line comp_gap year if perf_tercile == 3, lcolor(green)), ///
    xline(2010, lcolor(red) lpattern(dash)) ///
    legend(order(1 "Bottom Third" 2 "Middle" 3 "Top Third") ring(0) pos(6) cols(1) size(small) title("Performance Category")) ///
    graphregion(margin(6 6 6 6)) ///
    title("Male–Female Non-Salary Compensation Gap", size(medium)) ///
    subtitle("By Performance Category (CEOs) — Red dashed line = Dodd-Frank (2010)", size(small)) ///
    ytitle("Male minus Female Mean Non-Salary Comp ($000s)") xtitle("Year")
graph export "${output}/comp_gap_terciles_doddfrank.png", replace
restore

* 6c. Compensation gap over time by performance category for CEOs using logged non-salary comp
preserve
keep if titlenew2 == 10

gen byte middle_two_thirds_mkvalt = 0 if !missing(gap_mkvalt)
replace middle_two_thirds_mkvalt = 1 if bottom_third_mkvalt == 0 & top_third_mkvalt == 0 & !missing(gap_mkvalt)

gen byte perf_tercile = .
replace perf_tercile = 1 if bottom_third_mkvalt == 1
replace perf_tercile = 2 if middle_two_thirds_mkvalt == 1
replace perf_tercile = 3 if top_third_mkvalt == 1
label define perf_lbl 1 "Bottom Third" 2 "Middle" 3 "Top Third"
label values perf_tercile perf_lbl

collapse (mean) ln_real_nonsalary_tdc1, by(year perf_tercile female)
reshape wide ln_real_nonsalary_tdc1, i(year perf_tercile) j(female)
gen comp_gap_ln = ln_real_nonsalary_tdc10 - ln_real_nonsalary_tdc11

twoway (line comp_gap_ln year if perf_tercile == 1, lcolor(blue)) ///
       (line comp_gap_ln year if perf_tercile == 2, lcolor(gs12)) ///
       (line comp_gap_ln year if perf_tercile == 3, lcolor(green)), ///
    xline(2010, lcolor(red) lpattern(dash)) ///
    legend(order(1 "Bottom Third" 2 "Middle" 3 "Top Third") ring(0) pos(6) cols(1) size(small) title("Performance Category")) ///
    graphregion(margin(6 6 6 6)) ///
    title("Male–Female Log Non-Salary Compensation Gap", size(medium)) ///
    subtitle("By Performance Category (CEOs) — Red dashed line = Dodd-Frank (2010)", size(small)) ///
    ytitle("Male minus Female Mean Log Non-Salary Comp") xtitle("Year")
graph export "${output}/comp_gap_terciles_doddfrank_ln.png", replace
restore

*==================================================================
* SECTION 4: MAIN REGRESSIONS
*
* Middle two-thirds is the omitted performance category for parts A and B.
* Part C compares only the top third of overperformers and and bottom third of underperformers.
* All regressions include year and sector fixed effects and standard errors clustered on firm.
*
* Outcomes: ln_real_tdc1 (total compensation) & ln_real_nonsalary_tdc1 (non-salary compensation)
* Performance metrics: mkvalt (market value), revt (revenue)
* Groups: CEOs and CFOs
*==================================================================

*------------------------------------------------------------------
* 4A. All years, CEOs only
*------------------------------------------------------------------

* 4A: CEOs, All Years, Market Cap

* Total compensation
regress ln_real_tdc1 female ///
    bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 10, cluster(gvkey)

* Non-salary compensation
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 10, cluster(gvkey)


* 4A: CEOs, All Years, Revenue

* Total compensation
regress ln_real_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 10, cluster(gvkey)

* Non-salary compensation
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 10, cluster(gvkey)


* 4A: CEOs, All Years, Stock Price

* Total compensation
regress ln_real_tdc1 female ///
    bottom_third_prcc_f top_third_prcc_f ///
    female_bottom_prcc_f female_top_prcc_f ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 10, cluster(gvkey)

* Non-salary compensation
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_prcc_f top_third_prcc_f ///
    female_bottom_prcc_f female_top_prcc_f ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 10, cluster(gvkey)


* 4B: CFOs, All Years, Revenue

* Total compensation
regress ln_real_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 30, cluster(gvkey)

* Non-salary compensation
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 30, cluster(gvkey)


* 4B: CFOs, All Years, Stock Price

* Total compensation
regress ln_real_tdc1 female ///
    bottom_third_prcc_f top_third_prcc_f ///
    female_bottom_prcc_f female_top_prcc_f ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 30, cluster(gvkey)

* Non-salary compensation
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_prcc_f top_third_prcc_f ///
    female_bottom_prcc_f female_top_prcc_f ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 30, cluster(gvkey)

*------------------------------------------------------------------
* 4C: All years, CEOs — Bottom vs Top only
*------------------------------------------------------------------

* 4C: CEOs, All Years, Market Cap — Bottom vs Top only

* Total compensation
regress ln_real_tdc1 female ///
    bottom_third_mkvalt ///
    female_bottom_mkvalt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 10 & (bottom_third_mkvalt == 1 | top_third_mkvalt == 1), cluster(gvkey)

* Non-salary compensation
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_mkvalt ///
    female_bottom_mkvalt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 10 & (bottom_third_mkvalt == 1 | top_third_mkvalt == 1), cluster(gvkey)

* 4C: CEOs, All Years, Revenue — Bottom vs Top only

* Total compensation
regress ln_real_tdc1 female ///
    bottom_third_revt ///
    female_bottom_revt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 10 & (bottom_third_revt == 1 | top_third_revt == 1), cluster(gvkey)

* Non-salary compensation
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_revt ///
    female_bottom_revt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 10 & (bottom_third_revt == 1 | top_third_revt == 1), cluster(gvkey)

* 4C: CEOs, All Years, Stock Price — Bottom vs Top only

* Total compensation
regress ln_real_tdc1 female ///
    bottom_third_prcc_f ///
    female_bottom_prcc_f ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 10 & (bottom_third_prcc_f == 1 | top_third_prcc_f == 1), cluster(gvkey)

* Non-salary compensation
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_prcc_f ///
    female_bottom_prcc_f ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 10 & (bottom_third_prcc_f == 1 | top_third_prcc_f == 1), cluster(gvkey)


*------------------------------------------------------------------
* 4D: All years, CFOs — Bottom vs Top only
*------------------------------------------------------------------

* 4D: CFOs, All Years, Market Cap — Bottom vs Top only

* Total compensation
regress ln_real_tdc1 female ///
    bottom_third_mkvalt ///
    female_bottom_mkvalt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 30 & (bottom_third_mkvalt == 1 | top_third_mkvalt == 1), cluster(gvkey)

* Non-salary compensation
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_mkvalt ///
    female_bottom_mkvalt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 30 & (bottom_third_mkvalt == 1 | top_third_mkvalt == 1), cluster(gvkey)

* 4D: CFOs, All Years, Revenue — Bottom vs Top only

* Total compensation
regress ln_real_tdc1 female ///
    bottom_third_revt ///
    female_bottom_revt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 30 & (bottom_third_revt == 1 | top_third_revt == 1), cluster(gvkey)

* Non-salary compensation
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_revt ///
    female_bottom_revt ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 30 & (bottom_third_revt == 1 | top_third_revt == 1), cluster(gvkey)

* 4D: CFOs, All Years, Stock Price — Bottom vs Top only

* Total compensation
regress ln_real_tdc1 female ///
    bottom_third_prcc_f ///
    female_bottom_prcc_f ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 30 & (bottom_third_prcc_f == 1 | top_third_prcc_f == 1), cluster(gvkey)

* Non-salary compensation
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_prcc_f ///
    female_bottom_prcc_f ///
    age age_sq ///
    ln_emp i.year i.gsector ///
    if titlenew2 == 30 & (bottom_third_prcc_f == 1 | top_third_prcc_f == 1), cluster(gvkey)


*==================================================================
* SECTION 5: DODD-FRANK DiD and DDD
*==================================================================


*------------------------------------------------------------------
* 5A. Triple difference
* Coefficient of interest: female_post2010_bottom_mv
* Answers whether the post-Dodd-Frank gender gap widened more for underperformers than overperformers, using overperforming firms as the reference group.
*------------------------------------------------------------------

preserve
keep if titlenew2 == 10
keep if bottom_third_mkvalt == 1 | top_third_mkvalt == 1

* all interaction terms generated in Section 2

regress ln_real_tdc1 female bottom_third_mkvalt ///
        female_post2010 female_bottom_mkvalt post2010_bottom_mv ///
        female_post2010_bottom_mv ///
        age age_sq ln_emp i.year i.gsector, cluster(gvkey)

restore

preserve
keep if titlenew2 == 10
keep if bottom_third_mkvalt == 1 | top_third_mkvalt == 1

* all interaction terms generated in Section 2

regress ln_real_nonsalary_tdc1 female bottom_third_mkvalt ///
        female_post2010 female_bottom_mkvalt post2010_bottom_mv ///
        female_post2010_bottom_mv ///
        age age_sq ln_emp i.year i.gsector, cluster(gvkey)

restore




*------------------------------------------------------------------
* 5B. Regular DiDs
* We include post2010 and its interactions in these regressions so we can read see the change in gender penalty pre and post Dodd Frank.
* The coefficient of tnterest is female_post2010_bottom_v, which answers: Did the penalty for female executives at underperforming firms change after Dodd-Frank?
* * 2 roles x 3 metrics x 2 outcomes = 12 regressions
*------------------------------------------------------------------

* --- CEOs, Market Cap ---

* Total compensation — CEOs, Market Cap
regress ln_real_tdc1 female ///
    bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    female_post2010 ///
    female_post2010_bottom_mv female_post2010_top_mv ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10, cluster(gvkey)

* Non-salary compensation — CEOs, Market Cap
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    female_post2010 ///
    female_post2010_bottom_mv female_post2010_top_mv ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10, cluster(gvkey)

* --- CEOs, Revenue ---

* Total compensation — CEOs, Revenue
regress ln_real_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    female_post2010 ///
    female_post2010_bottom_revt female_post2010_top_revt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10, cluster(gvkey)

* Non-salary compensation — CEOs, Revenue
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    female_post2010 ///
    female_post2010_bottom_revt female_post2010_top_revt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10, cluster(gvkey)

* --- CEOs, Stock Price ---

* Total compensation — CEOs, Stock Price
regress ln_real_tdc1 female ///
    bottom_third_prcc_f top_third_prcc_f ///
    female_bottom_prcc_f female_top_prcc_f ///
    female_post2010 ///
    female_post2010_bottom_prcc female_post2010_top_prcc ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10, cluster(gvkey)

* Non-salary compensation — CEOs, Stock Price
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_prcc_f top_third_prcc_f ///
    female_bottom_prcc_f female_top_prcc_f ///
    female_post2010 ///
    female_post2010_bottom_prcc female_post2010_top_prcc ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10, cluster(gvkey)

* --- CFOs, Market Cap ---

* Total compensation — CFOs, Market Cap
regress ln_real_tdc1 female ///
    bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    female_post2010 ///
    female_post2010_bottom_mv female_post2010_top_mv ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 30, cluster(gvkey)

* Non-salary compensation — CFOs, Market Cap
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    female_post2010 ///
    female_post2010_bottom_mv female_post2010_top_mv ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 30, cluster(gvkey)

* --- CFOs, Revenue ---

* Total compensation — CFOs, Revenue
regress ln_real_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    female_post2010 ///
    female_post2010_bottom_revt female_post2010_top_revt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 30, cluster(gvkey)

* Non-salary compensation — CFOs, Revenue
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    female_post2010 ///
    female_post2010_bottom_revt female_post2010_top_revt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 30, cluster(gvkey)

* --- CFOs, Stock Price ---

* Total compensation — CFOs, Stock Price
regress ln_real_tdc1 female ///
    bottom_third_prcc_f top_third_prcc_f ///
    female_bottom_prcc_f female_top_prcc_f ///
    female_post2010 ///
    female_post2010_bottom_prcc female_post2010_top_prcc ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 30, cluster(gvkey)

* Non-salary compensation — CFOs, Stock Price
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_prcc_f top_third_prcc_f ///
    female_bottom_prcc_f female_top_prcc_f ///
    female_post2010 ///
    female_post2010_bottom_prcc female_post2010_top_prcc ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 30, cluster(gvkey)


*==================================================================
* SECTION 6: COEFFICIENT PLOTS
* 
* Three shocks: Dodd-Frank, #MeToo, and Covid
* Only running regressions for CEOs and mkvalt
* Storing two estimates so we can display them side by side on a coefficient plot
*==================================================================

*------------------------------------------------------------------
* 6A. pre vs post Dodd-Frank
*------------------------------------------------------------------

* total earnings, pre dodd
regress ln_real_tdc1 female bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10 & year <  2010, cluster(gvkey)
estimates store pre_dodd_tdc1

* total earnings, post dodd
regress ln_real_tdc1 female bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10 & year >= 2010, cluster(gvkey)
estimates store post_dodd_tdc1

coefplot pre_dodd_tdc1 post_dodd_tdc1, keep(female_bottom_mkvalt female_top_mkvalt) ///
    coeflabels(female_bottom_mkvalt="Female x Bottom Third" female_top_mkvalt="Female x Top Third") ///
    legend(order(1 "Pre-Dodd-Frank" 2 "Post-Dodd-Frank") ring(0) pos(6) cols(1) size(small) title("Period")) ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Performance Penalty", size(medium)) ///
    subtitle("Pre vs. Post Dodd-Frank — Total Comp", size(small)) ///
    ytitle("Coefficient") levels(90)
graph export "${output}/coefplot_doddfrank_totalearnings.png", replace

* non-salary earnings, pre dodd
regress ln_real_nonsalary_tdc1 female bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10 & year <  2010, cluster(gvkey)
estimates store pre_dodd_ns

* non-salary earnings, post dodd
regress ln_real_nonsalary_tdc1 female bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10 & year >= 2010, cluster(gvkey)
estimates store post_dodd_ns

coefplot pre_dodd_ns post_dodd_ns, keep(female_bottom_mkvalt female_top_mkvalt) ///
    coeflabels(female_bottom_mkvalt="Female x Bottom Third" female_top_mkvalt="Female x Top Third") ///
    legend(order(1 "Pre-Dodd-Frank" 2 "Post-Dodd-Frank") ring(0) pos(6) cols(1) size(small) title("Period")) ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Performance Penalty", size(medium)) ///
    subtitle("Pre vs. Post Dodd-Frank — Non-Salary Comp", size(small)) ///
    ytitle("Coefficient") levels(90)
graph export "${output}/coefplot_doddfrank_nonsalary.png", replace

*------------------------------------------------------------------
* 6B. pre vs post #MeToo
*------------------------------------------------------------------

* total earnings, pre #MeToo
regress ln_real_tdc1 female bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10 & inrange(year, 2010, 2016), cluster(gvkey)
estimates store pre_metoo_tdc1_mv

* total earnings, post #MeToo
regress ln_real_tdc1 female bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10 & inrange(year, 2017, 2024), cluster(gvkey)
estimates store pst_metoo_tdc1_mv

coefplot pre_metoo_tdc1_mv pst_metoo_tdc1_mv, keep(female_bottom_mkvalt female_top_mkvalt) ///
    coeflabels(female_bottom_mkvalt="Female x Bottom Third" female_top_mkvalt="Female x Top Third") ///
    legend(order(1 "Pre-MeToo" 2 "Post-MeToo") ring(0) pos(6) cols(1) size(small) title("Period")) ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Performance Penalty", size(medium)) ///
    subtitle("Pre vs. Post #MeToo — Total Comp", size(small)) ///
    ytitle("Coefficient") levels(90)
graph export "${output}/coefplot_metoo_totalearnings.png", replace

* non-salary earnings, pre #MeToo
regress ln_real_nonsalary_tdc1 female bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10 & inrange(year, 2010, 2016), cluster(gvkey)
estimates store pre_metoo_ns_mv

* non-salary earnings, post #MeToo
regress ln_real_nonsalary_tdc1 female bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10 & inrange(year, 2017, 2024), cluster(gvkey)
estimates store pst_metoo_ns_mv

coefplot pre_metoo_ns_mv pst_metoo_ns_mv, keep(female_bottom_mkvalt female_top_mkvalt) ///
    coeflabels(female_bottom_mkvalt="Female x Bottom Third" female_top_mkvalt="Female x Top Third") ///
    legend(order(1 "Pre-MeToo" 2 "Post-MeToo") ring(0) pos(6) cols(1) size(small) title("Period")) ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Performance Penalty", size(medium)) ///
    subtitle("Pre vs. Post #MeToo — Non-Salary Comp", size(small)) ///
    ytitle("Coefficient") levels(90)
graph export "${output}/coefplot_metoo_nonsalary.png", replace

*------------------------------------------------------------------
* 6C. pre vs. post Covid
*------------------------------------------------------------------

* total earnings, pre Covid
regress ln_real_tdc1 female bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10 & inrange(year, 2016, 2019), cluster(gvkey)
estimates store pre_covid_tdc1_mv

* total earnings, post Covid
regress ln_real_tdc1 female bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10 & inrange(year, 2021, 2024), cluster(gvkey)
estimates store pst_covid_tdc1_mv

coefplot pre_covid_tdc1_mv pst_covid_tdc1_mv, keep(female_bottom_mkvalt female_top_mkvalt) ///
    coeflabels(female_bottom_mkvalt="Female x Bottom Third" female_top_mkvalt="Female x Top Third") ///
    legend(order(1 "Pre-COVID" 2 "Post-COVID") ring(0) pos(6) cols(1) size(small) title("Period")) ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Performance Penalty", size(medium)) ///
    subtitle("Pre vs. Post COVID — Total Comp", size(small)) ///
    ytitle("Coefficient") levels(90)
graph export "${output}/coefplot_covid_totalearnings.png", replace

* non-salary earnings, pre Covid
regress ln_real_nonsalary_tdc1 female bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10 & inrange(year, 2016, 2019), cluster(gvkey)
estimates store pre_covid_ns_mv

* non-salary earnings, post Covid
regress ln_real_nonsalary_tdc1 female bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector ///
    if titlenew2 == 10 & inrange(year, 2021, 2024), cluster(gvkey)
estimates store pst_covid_ns_mv

coefplot pre_covid_ns_mv pst_covid_ns_mv, keep(female_bottom_mkvalt female_top_mkvalt) ///
    coeflabels(female_bottom_mkvalt="Female x Bottom Third" female_top_mkvalt="Female x Top Third") ///
    legend(order(1 "Pre-COVID" 2 "Post-COVID") ring(0) pos(6) cols(1) size(small) title("Period")) ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Performance Penalty", size(medium)) ///
    subtitle("Pre vs. Post COVID — Non-Salary Comp", size(small)) ///
    ytitle("Coefficient") levels(90)
graph export "${output}/coefplot_covid_nonsalary.png", replace

*==================================================================
* SECTION 7: AGE HETEROGENEITY
*
* pooling all CEOs and CFOs
* All regressions include year, sector, and title fixed effects and cluster on firm.
* Outcomes: ln_real_tdc1 (total compensation) & ln_real_nonsalary_tdc1 (non-salary compensation)
* Performance metric: mkvalt (market value), revt (revenue)
*
* A) Original specifications (top and bottom third dummies) run separately for each age tercile, mkvalt.
* B) Original specifications (top and bottom third dummies) run separately for each age tercile, revt.
* C) Split-sample by age tercile — bottom only, mkvalt.
* D) Split-sample by age tercile — bottom only, revt.
*==================================================================

* Create age terciles (1=youngest, 3=oldest)
capture drop age_tercile
xtile age_tercile = age, n(3)

* Check composition of terciles
tab age_tercile female if titlenew2 == 10 | titlenew2 == 30, row
tabstat ln_real_tdc1 ln_real_nonsalary_tdc1 age ln_emp mkvalt ///
    if titlenew2 == 10 | titlenew2 == 30, by(age_tercile) stat(mean sd n)

*------------------------------------------------------------------
* 7A: Full regressions, split by age tercile
* Includes both bottom and top third female interactions to see penalty for underperformance/reward for overperformance relative to middle.
* Creates coefficient plots for each tercile
*------------------------------------------------------------------

* 7A: Total Comp — Age Tercile 1 (Youngest)
regress ln_real_tdc1 female ///
    bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 1, cluster(gvkey)
estimates store full_t1_tdc1

* 7A: Total Comp — Age Tercile 2 (Middle)
regress ln_real_tdc1 female ///
    bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 2, cluster(gvkey)
estimates store full_t2_tdc1

* 7A: Total Comp — Age Tercile 3 (Oldest)
regress ln_real_tdc1 female ///
    bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 3, cluster(gvkey)
estimates store full_t3_tdc1

* Build coefficient plot
coefplot full_t1_tdc1 full_t2_tdc1 full_t3_tdc1, ///
    keep(female_bottom_mkvalt female_top_mkvalt) ///
    coeflabels(female_bottom_mkvalt="Female x Bottom Third" female_top_mkvalt="Female x Top Third") ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Performance Penalty by Age Tercile", size(medium)) ///
    subtitle("Total Comp (mkvalt) — CEOs + CFOs", size(small)) ///
    ytitle("Coefficient") levels(90) ///
    legend(label(1 "Youngest Third") label(2 "Middle Third") label(3 "Oldest Third"))
graph export "${output}/coefplot_age_full_tdc1_mkvalt.png", replace

* 7A: Non-Salary Comp — Age Tercile 1 (Youngest)
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 1, cluster(gvkey)
estimates store full_t1_ns

* 7A: Non-Salary Comp — Age Tercile 2 (Middle)
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 2, cluster(gvkey)
estimates store full_t2_ns

* 7A: Non-Salary Comp — Age Tercile 3 (Oldest)
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_mkvalt top_third_mkvalt ///
    female_bottom_mkvalt female_top_mkvalt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 3, cluster(gvkey)
estimates store full_t3_ns

* Build coefficient plot
coefplot full_t1_ns full_t2_ns full_t3_ns, ///
    keep(female_bottom_mkvalt female_top_mkvalt) ///
    coeflabels(female_bottom_mkvalt="Female x Bottom Third" female_top_mkvalt="Female x Top Third") ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Performance Penalty by Age Tercile", size(medium)) ///
    subtitle("Non-Salary Comp (mkvalt) — CEOs + CFOs", size(small)) ///
    ytitle("Coefficient") levels(90) ///
    legend(label(1 "Youngest Third") label(2 "Middle Third") label(3 "Oldest Third"))
graph export "${output}/coefplot_age_full_ns_mkvalt.png", replace

*------------------------------------------------------------------
* 7B: Full regressions using revenue (revt), split by age tercile.
* Same as 7A but uses revt as the performance metric.
*------------------------------------------------------------------

* 7B: Total Comp -- Age Tercile 1 (Youngest)
regress ln_real_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 1, cluster(gvkey)
estimates store full_t1_tdc1_rv

* 7B: Total Comp -- Age Tercile 2 (Middle)
regress ln_real_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 2, cluster(gvkey)
estimates store full_t2_tdc1_rv

* 7B: Total Comp -- Age Tercile 3 (Oldest)
regress ln_real_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 3, cluster(gvkey)
estimates store full_t3_tdc1_rv

* Build coefficient plot
coefplot full_t1_tdc1_rv full_t2_tdc1_rv full_t3_tdc1_rv, ///
    keep(female_bottom_revt female_top_revt) ///
    coeflabels(female_bottom_revt="Female x Bottom Third" female_top_revt="Female x Top Third") ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Performance Penalty by Age Tercile", size(medium)) ///
    subtitle("Total Comp (revt) — CEOs + CFOs", size(small)) ///
    ytitle("Coefficient") levels(90) ///
    legend(label(1 "Youngest Third") label(2 "Middle Third") label(3 "Oldest Third"))
graph export "${output}/coefplot_age_full_tdc1_revt.png", replace

* 7B: Non-Salary Comp -- Age Tercile 1 (Youngest)
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 1, cluster(gvkey)
estimates store full_t1_ns_rv

* 7B: Non-Salary Comp -- Age Tercile 2 (Middle)
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 2, cluster(gvkey)
estimates store full_t2_ns_rv

* 7B: Non-Salary Comp -- Age Tercile 3 (Oldest)
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_revt top_third_revt ///
    female_bottom_revt female_top_revt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 3, cluster(gvkey)
estimates store full_t3_ns_rv

* Build coefficient plot
coefplot full_t1_ns_rv full_t2_ns_rv full_t3_ns_rv, ///
    keep(female_bottom_revt female_top_revt) ///
    coeflabels(female_bottom_revt="Female x Bottom Third" female_top_revt="Female x Top Third") ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Performance Penalty by Age Tercile", size(medium)) ///
    subtitle("Non-Salary Comp (revt) — CEOs + CFOs", size(small)) ///
    ytitle("Coefficient") levels(90) ///
    legend(label(1 "Youngest Third") label(2 "Middle Third") label(3 "Oldest Third"))
graph export "${output}/coefplot_age_full_ns_revt.png", replace

*------------------------------------------------------------------
* 7C: Bottom/top performers only, mkvalt, split by age tercile.
* Drops top_third and female_top dummies, restricts to only the top/bottom third.
*------------------------------------------------------------------

* 7C: Total Comp, Bottom Only — Age Tercile 1 (Youngest)
regress ln_real_tdc1 female ///
    bottom_third_mkvalt ///
    female_bottom_mkvalt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 1 & (bottom_third_mkvalt == 1 | top_third_mkvalt == 1), cluster(gvkey)
estimates store bot_t1_tdc1

* 7C: Total Comp, Bottom Only — Age Tercile 2 (Middle)
regress ln_real_tdc1 female ///
    bottom_third_mkvalt ///
    female_bottom_mkvalt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 2 & (bottom_third_mkvalt == 1 | top_third_mkvalt == 1), cluster(gvkey)
estimates store bot_t2_tdc1

* 7C: Total Comp, Bottom Only — Age Tercile 3 (Oldest)
regress ln_real_tdc1 female ///
    bottom_third_mkvalt ///
    female_bottom_mkvalt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 3 & (bottom_third_mkvalt == 1 | top_third_mkvalt == 1), cluster(gvkey)
estimates store bot_t3_tdc1

* Build coefficient plot
coefplot bot_t1_tdc1 bot_t2_tdc1 bot_t3_tdc1, ///
    keep(female_bottom_mkvalt) ///
    coeflabels(female_bottom_mkvalt="Female x Bottom Third") ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Underperformance Penalty by Age Tercile", size(medium)) ///
    subtitle("Total Comp (mkvalt) — CEOs + CFOs", size(small)) ///
    ytitle("Coefficient on Female x Bottom Third") levels(90) ///
    legend(label(1 "Youngest Third") label(2 "Middle Third") label(3 "Oldest Third"))
graph export "${output}/coefplot_age_bot_tdc1_mkvalt.png", replace

* 7C: Non-Salary Comp, Bottom Only — Age Tercile 1 (Youngest)
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_mkvalt ///
    female_bottom_mkvalt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 1 & (bottom_third_mkvalt == 1 | top_third_mkvalt == 1), cluster(gvkey)
estimates store bot_t1_ns

* 7C: Non-Salary Comp, Bottom Only — Age Tercile 2 (Middle)
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_mkvalt ///
    female_bottom_mkvalt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 2 & (bottom_third_mkvalt == 1 | top_third_mkvalt == 1), cluster(gvkey)
estimates store bot_t2_ns

* 7C: Non-Salary Comp, Bottom Only — Age Tercile 3 (Oldest)
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_mkvalt ///
    female_bottom_mkvalt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 3 & (bottom_third_mkvalt == 1 | top_third_mkvalt == 1), cluster(gvkey)
estimates store bot_t3_ns

* Build coefficient plot
coefplot bot_t1_ns bot_t2_ns bot_t3_ns, ///
    keep(female_bottom_mkvalt) ///
    coeflabels(female_bottom_mkvalt="Female x Bottom Third") ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Underperformance Penalty by Age Tercile", size(medium)) ///
    subtitle("Non-Salary Comp (mkvalt) — CEOs + CFOs", size(small)) ///
    ytitle("Coefficient on Female x Bottom Third") levels(90) ///
    legend(label(1 "Youngest Third") label(2 "Middle Third") label(3 "Oldest Third"))
graph export "${output}/coefplot_age_bot_ns_mkvalt.png", replace

*------------------------------------------------------------------
* 7D: Bottom/top performers only, revt, split by age tercile.
* Same as 7C but uses revt as the performance metric.
*------------------------------------------------------------------

* 7D: Total Comp, Bottom Only -- Age Tercile 1 (Youngest)
regress ln_real_tdc1 female ///
    bottom_third_revt ///
    female_bottom_revt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 1 & (bottom_third_revt == 1 | top_third_revt == 1), cluster(gvkey)
estimates store bot_t1_tdc1_rv

* 7D: Total Comp, Bottom Only -- Age Tercile 2 (Middle)
regress ln_real_tdc1 female ///
    bottom_third_revt ///
    female_bottom_revt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 2 & (bottom_third_revt == 1 | top_third_revt == 1), cluster(gvkey)
estimates store bot_t2_tdc1_rv

* 7D: Total Comp, Bottom Only -- Age Tercile 3 (Oldest)
regress ln_real_tdc1 female ///
    bottom_third_revt ///
    female_bottom_revt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 3 & (bottom_third_revt == 1 | top_third_revt == 1), cluster(gvkey)
estimates store bot_t3_tdc1_rv

* Build coefficient plot
coefplot bot_t1_tdc1_rv bot_t2_tdc1_rv bot_t3_tdc1_rv, ///
    keep(female_bottom_revt) ///
    coeflabels(female_bottom_revt="Female x Bottom Third") ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Underperformance Penalty by Age Tercile", size(medium)) ///
    subtitle("Total Comp (revt) — CEOs + CFOs", size(small)) ///
    ytitle("Coefficient on Female x Bottom Third") levels(90) ///
    legend(label(1 "Youngest Third") label(2 "Middle Third") label(3 "Oldest Third"))
graph export "${output}/coefplot_age_bot_tdc1_revt.png", replace

* 7D: Non-Salary Comp, Bottom Only -- Age Tercile 1 (Youngest)
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_revt ///
    female_bottom_revt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 1 & (bottom_third_revt == 1 | top_third_revt == 1), cluster(gvkey)
estimates store bot_t1_ns_rv

* 7D: Non-Salary Comp, Bottom Only -- Age Tercile 2 (Middle)
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_revt ///
    female_bottom_revt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 2 & (bottom_third_revt == 1 | top_third_revt == 1), cluster(gvkey)
estimates store bot_t2_ns_rv

* 7D: Non-Salary Comp, Bottom Only -- Age Tercile 3 (Oldest)
regress ln_real_nonsalary_tdc1 female ///
    bottom_third_revt ///
    female_bottom_revt ///
    age age_sq ln_emp i.year i.gsector i.titlenew2 ///
    if (titlenew2 == 10 | titlenew2 == 30) & age_tercile == 3 & (bottom_third_revt == 1 | top_third_revt == 1), cluster(gvkey)
estimates store bot_t3_ns_rv

* Build coefficient plot
coefplot bot_t1_ns_rv bot_t2_ns_rv bot_t3_ns_rv, ///
    keep(female_bottom_revt) ///
    coeflabels(female_bottom_revt="Female x Bottom Third") ///
    vertical yline(0, lcolor(red) lpattern(dash)) ///
    title("Gender x Underperformance Penalty by Age Tercile", size(medium)) ///
    subtitle("Non-Salary Comp (revt) — CEOs + CFOs", size(small)) ///
    ytitle("Coefficient on Female x Bottom Third") levels(90) ///
    legend(label(1 "Youngest Third") label(2 "Middle Third") label(3 "Oldest Third"))
graph export "${output}/coefplot_age_bot_ns_revt.png", replace


*==================================================================
* END
*==================================================================
log close


















