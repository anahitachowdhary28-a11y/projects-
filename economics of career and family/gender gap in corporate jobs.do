* Anahita Chowdhary
* EC57 S26: PSET 3
* 5/9/26


clear all
set more off 
capture log close _all


*DEFINE FOLDER PATHS

* define globals containing folder paths
global main "/Users/anahitachowdhary/Stata/econ_57/pset3"
global logs "${main}/logs"
global input "${main}/input"
global output "${main}/output"



* start a log file:
log using "${logs}/log_pset3_answers", replace

* Load the data:
use "${input}/Execucomp_92_24.dta"

* I installed tabout in command bar so it doesn't install more than once


** Question 1:

** a)

** marking observations of the same executive appearing more than once in the the year:

* sorting by year, and then by company name within each year:
sort year coname 
* creating groups for each combo of executive id and year | sorting by company name within those groups | generating a dummy that =1 if there's more than one entry in each execid/year group (indicating the same exec appears in a year more than once):
bysort execid year (coname): gen duplicate = (_n > 1)
*flags 2,781 duplicates


* setting directory to output folder
cd "${main}/output"


** finding the percentage of total executives that have the specified title in each year, restricting for non duplicates | note: c() tells stata to put output in cells

tabout titlenew2 year using "table1_all.xls" if (year==1995 | year==2010 | year==2024) & duplicate==0, c(col) replace

** finding the percentage of each exec group that are women (restricting for non duplicates) | saving each table as an excel sheet

tabout titlenew2 gender using "table1_w_1995.xls" if year == 1995 & duplicate==0, c(row) replace

tabout titlenew2 gender using "table1_w_2010.xls" if year == 2010 & duplicate==0, c(row) replace

tabout titlenew2 gender using "table1_w_2024.xls" if year == 2024 & duplicate==0, c(row) replace


** b)

* calculating the percentage of female CEOs in each year by grouping by year, then generating a variable equal to the mean of the female dummy, restricting for non duplicates:
bysort year: egen pctfemale_ceo = mean(female) if titlenew2==10 & duplicate==0
* multiplying by 100 to make it a percentage
replace pctfemale_ceo = pctfemale_ceo * 100


* calculating the percentage of female non CEO executives in each year by grouping by year, then generating a variable equal to the mean of the female dummy, restricting for non duplicates:
bysort year: egen pctfemale_nonceo = mean(female) if titlenew2!=10 & duplicate==0
* multiplying by 100 to make it a percentage
replace pctfemale_nonceo = pctfemale_nonceo * 100


* graphing both lines on the same graph, adding axis labels and a legend
twoway (line pctfemale_ceo year) (line pctfemale_nonceo year), ///
	xtitle("Year") ytitle("Percent Female") title("Percentage of Female Top Executives") ///
	legend(label(1 "percentage of female CEOs") label(2 "percentage of female top-executives non-CEO") position(6))

* save the graph
graph export "$main/output/Q1b.png", replace


** Question 2:

** a)

* starting excel sheet with all ttest info:
* creating file
putexcel set "${output}/Q2a.xlsx", replace
* labeling top row
putexcel A1 = "" B1 = "Women" C1 = "Men" D1 = "Difference" E1 = "p-value" F1 = "Female to male ratio"
* labeling second row
putexcel A2 = (1995)

*generating new variable for salary + bonus
gen real_salary_and_bonus = real_salary + real_bonus

* ttest for 1995
ttest real_salary if year==1995, by(gender)
* saving information in excel
	* mu_1 is mean for women (since female comes before male)
	* mu_2 is mean for men
	* r(mu_1) and r(mu_2) returns these values
	* r(mu_2)-r(mu_1) shows the difference
	* r(p) returns the p values
	* r(mu_1)/r(mu_2) returns the ratio
putexcel A3 = "Mean Salary" B3 = (r(mu_1)) C3 = (r(mu_2)) D3 = (r(mu_2)-r(mu_1)) E3 = (r(p)) F3 = (r(mu_1)/r(mu_2))

* repeating for remaining 1995 ttests:

ttest real_salary_and_bonus if year==1995, by(gender)
putexcel A4 = "Mean Salary + Bonus" B4 = (r(mu_1)) C4 = (r(mu_2)) D4 = (r(mu_2)-r(mu_1)) E4 = (r(p)) F4 = (r(mu_1)/r(mu_2))

ttest real_tdc if year==1995, by(gender)
putexcel A5 = "Mean Total Compensation (TDC1)" B5 = (r(mu_1)) C5 = (r(mu_2)) D5 = (r(mu_2)-r(mu_1)) E5 = (r(p)) F5 = (r(mu_1)/r(mu_2))

* 2010:

putexcel A6 = (2010)

ttest real_salary if year==2010, by(gender)
putexcel A7 = "Mean Salary" B7 = (r(mu_1)) C7 = (r(mu_2)) D7 = (r(mu_2)-r(mu_1)) E7 = (r(p)) F7 = (r(mu_1)/r(mu_2))

ttest real_salary_and_bonus if year==2010, by(gender)
putexcel A8 = "Mean Salary + Bonus" B8 = (r(mu_1)) C8 = (r(mu_2)) D8 = (r(mu_2)-r(mu_1)) E8 = (r(p)) F8 = (r(mu_1)/r(mu_2))

ttest real_tdc if year==2010, by(gender)
putexcel A9 = "Mean Total Compensation (TDC1)" B9 = (r(mu_1)) C9 = (r(mu_2)) D9 = (r(mu_2)-r(mu_1)) E9 = (r(p)) F9 = (r(mu_1)/r(mu_2))

* 2024:

putexcel A10 = (2024)

ttest real_salary if year==2024, by(gender)
putexcel A11 = "Mean Salary" B11 = (r(mu_1)) C11 = (r(mu_2)) D11 = (r(mu_2)-r(mu_1)) E11 = (r(p)) F11 = (r(mu_1)/r(mu_2))

ttest real_salary_and_bonus if year==2024, by(gender)
putexcel A12 = "Mean Salary + Bonus" B12 = (r(mu_1)) C12 = (r(mu_2)) D12 = (r(mu_2)-r(mu_1)) E12 = (r(p)) F12 = (r(mu_1)/r(mu_2))

ttest real_tdc if year==2024, by(gender)
putexcel A13 = "Mean Total Compensation (TDC1)" B13 = (r(mu_1)) C13 = (r(mu_2)) D13 = (r(mu_2)-r(mu_1)) E13 = (r(p)) F13 = (r(mu_1)/r(mu_2))


** b)

* first for CEOs:

* starting new excel sheet:
putexcel set "${output}/Q2b1.xlsx", replace
putexcel A1 = "" B1 = "Women" C1 = "Men" D1 = "Difference" E1 = "p-value" F1 = "Female to male ratio"
putexcel A2 = (1995)

* ttest for 1995, but restricting for CEOs by doing titlenew2==10
ttest real_salary if year==1995 & titlenew2==10, by(gender)
putexcel A3 = "Mean Salary" B3 = (r(mu_1)) C3 = (r(mu_2)) D3 = (r(mu_2)-r(mu_1)) E3 = (r(p)) F3 = (r(mu_1)/r(mu_2))

* remaining 1995 CEO ttests:

ttest real_salary_and_bonus if year==1995 & titlenew2==10, by(gender)
putexcel A4 = "Mean Salary + Bonus" B4 = (r(mu_1)) C4 = (r(mu_2)) D4 = (r(mu_2)-r(mu_1)) E4 = (r(p)) F4 = (r(mu_1)/r(mu_2))

ttest real_tdc if year==1995 & titlenew2==10, by(gender)
putexcel A5 = "Mean Total Compensation (TDC1)" B5 = (r(mu_1)) C5 = (r(mu_2)) D5 = (r(mu_2)-r(mu_1)) E5 = (r(p)) F5 = (r(mu_1)/r(mu_2))

* 2010:

putexcel A6 = (2010)

ttest real_salary if year==2010 & titlenew2==10, by(gender)
putexcel A7 = "Mean Salary" B7 = (r(mu_1)) C7 = (r(mu_2)) D7 = (r(mu_2)-r(mu_1)) E7 = (r(p)) F7 = (r(mu_1)/r(mu_2))

ttest real_salary_and_bonus if year==2010 & titlenew2==10, by(gender)
putexcel A8 = "Mean Salary + Bonus" B8 = (r(mu_1)) C8 = (r(mu_2)) D8 = (r(mu_2)-r(mu_1)) E8 = (r(p)) F8 = (r(mu_1)/r(mu_2))

ttest real_tdc if year==2010 & titlenew2==10, by(gender)
putexcel A9 = "Mean Total Compensation (TDC1)" B9 = (r(mu_1)) C9 = (r(mu_2)) D9 = (r(mu_2)-r(mu_1)) E9 = (r(p)) F9 = (r(mu_1)/r(mu_2))

* 2024:

putexcel A10 = (2024)

ttest real_salary if year==2024 & titlenew2==10, by(gender)
putexcel A11 = "Mean Salary" B11 = (r(mu_1)) C11 = (r(mu_2)) D11 = (r(mu_2)-r(mu_1)) E11 = (r(p)) F11 = (r(mu_1)/r(mu_2))

ttest real_salary_and_bonus if year==2024 & titlenew2==10, by(gender)
putexcel A12 = "Mean Salary + Bonus" B12 = (r(mu_1)) C12 = (r(mu_2)) D12 = (r(mu_2)-r(mu_1)) E12 = (r(p)) F12 = (r(mu_1)/r(mu_2))

ttest real_tdc if year==2024 & titlenew2==10, by(gender)
putexcel A13 = "Mean Total Compensation (TDC1)" B13 = (r(mu_1)) C13 = (r(mu_2)) D13 = (r(mu_2)-r(mu_1)) E13 = (r(p)) F13 = (r(mu_1)/r(mu_2))


* next for CFOs:

* starting new excel sheet:
putexcel set "${output}/Q2b2.xlsx", replace
putexcel A1 = "" B1 = "Women" C1 = "Men" D1 = "Difference" E1 = "p-value" F1 = "Female to male ratio"
putexcel A2 = (1995)

* ttest for 1995, but restricting for CFOs by doing titlenew2==30
ttest real_salary if year==1995 & titlenew2==30, by(gender)
putexcel A3 = "Mean Salary" B3 = (r(mu_1)) C3 = (r(mu_2)) D3 = (r(mu_2)-r(mu_1)) E3 = (r(p)) F3 = (r(mu_1)/r(mu_2))

* remaining 1995 CEO ttests:

ttest real_salary_and_bonus if year==1995 & titlenew2==30, by(gender)
putexcel A4 = "Mean Salary + Bonus" B4 = (r(mu_1)) C4 = (r(mu_2)) D4 = (r(mu_2)-r(mu_1)) E4 = (r(p)) F4 = (r(mu_1)/r(mu_2))

ttest real_tdc if year==1995 & titlenew2==30, by(gender)
putexcel A5 = "Mean Total Compensation (TDC1)" B5 = (r(mu_1)) C5 = (r(mu_2)) D5 = (r(mu_2)-r(mu_1)) E5 = (r(p)) F5 = (r(mu_1)/r(mu_2))

* 2010:

putexcel A6 = (2010)

ttest real_salary if year==2010 & titlenew2==30, by(gender)
putexcel A7 = "Mean Salary" B7 = (r(mu_1)) C7 = (r(mu_2)) D7 = (r(mu_2)-r(mu_1)) E7 = (r(p)) F7 = (r(mu_1)/r(mu_2))

ttest real_salary_and_bonus if year==2010 & titlenew2==30, by(gender)
putexcel A8 = "Mean Salary + Bonus" B8 = (r(mu_1)) C8 = (r(mu_2)) D8 = (r(mu_2)-r(mu_1)) E8 = (r(p)) F8 = (r(mu_1)/r(mu_2))

ttest real_tdc if year==2010 & titlenew2==30, by(gender)
putexcel A9 = "Mean Total Compensation (TDC1)" B9 = (r(mu_1)) C9 = (r(mu_2)) D9 = (r(mu_2)-r(mu_1)) E9 = (r(p)) F9 = (r(mu_1)/r(mu_2))

* 2024:

putexcel A10 = (2024)

ttest real_salary if year==2024 & titlenew2==30, by(gender)
putexcel A11 = "Mean Salary" B11 = (r(mu_1)) C11 = (r(mu_2)) D11 = (r(mu_2)-r(mu_1)) E11 = (r(p)) F11 = (r(mu_1)/r(mu_2))

ttest real_salary_and_bonus if year==2024 & titlenew2==30, by(gender)
putexcel A12 = "Mean Salary + Bonus" B12 = (r(mu_1)) C12 = (r(mu_2)) D12 = (r(mu_2)-r(mu_1)) E12 = (r(p)) F12 = (r(mu_1)/r(mu_2))

ttest real_tdc if year==2024 & titlenew2==30, by(gender)
putexcel A13 = "Mean Total Compensation (TDC1)" B13 = (r(mu_1)) C13 = (r(mu_2)) D13 = (r(mu_2)-r(mu_1)) E13 = (r(p)) F13 = (r(mu_1)/r(mu_2))


** Question 3:

* getting rid of executives not in the top 5
keep if execrankann <= 5
* getting rid of observations without defined industry
drop if sic_group== .
* results in 37,046 observations from 1992-1997


* creating a dummy for the first time period:

gen period1 = inrange(year, 1992, 1997)

* generating number of execs in industry
bysort sic_group: egen num_ind_p1 = count(execid) if period1==1

* generating percent female in each industry
bysort sic_group: egen pctfemale_ind_p1 = mean(female) if period1==1
replace pctfemale_ind_p1 = pctfemale_ind_p1 * 100

* generating industry wage/market wage
	
	* calculating market wage 
	summarize real_tdc if period1==1
	local mkt_wage_p1 = r(mean)
	
	* generating avg wage for each industry
	bysort sic_group: egen ind_wage_p1 = mean(real_tdc) if period1==1
	
	* generating ratio
	gen wage_ratio_p1 = ind_wage_p1/`mkt_wage_p1'
	
* generating female/male wage gap

	* generating female and male wage variables (used to calculate means later):
	gen wage_f = real_tdc if female==1
	gen wage_m = real_tdc if female==0
	
	
	* calculating avgs by industry:
	bysort sic_group: egen avg_fwage_p1 = mean(wage_f) if period1==1
	bysort sic_group: egen avg_mwage_p1 = mean(wage_m) if period1==1
	
	* calculating the ratio/gap
	gen mf_ratio_p1 = avg_fwage_p1/avg_mwage_p1
	
* now collapsing all the variables by industry to get one number per industry for period 1:

	* preserving the original, non-collapsed data
	preserve

	* collapsing by industry
	collapse (mean) num_ind_p1 pctfemale_ind_p1 wage_ratio_p1 mf_ratio_p1, by(sic_group)
	
	* making sure all entries have two decimal points
	format num_ind_p1 pctfemale_ind_p1 wage_ratio_p1 mf_ratio_p1 %9.2f

	* exporting to a table
	export excel using "${output}/table4_panelA.xlsx", firstrow(variables) replace

	* restoring the data to the way it was
	restore


** repeating process for time period 2:

gen period2 = inrange(year, 1998, 2017)

bysort sic_group: egen num_ind_p2 = count(execid) if period2==1

* generating percent female in each industry
bysort sic_group: egen pctfemale_ind_p2 = mean(female) if period2==1
replace pctfemale_ind_p2 = pctfemale_ind_p2 * 100

* generating industry wage/market wage
	
	summarize real_tdc if period2==1
	local mkt_wage_p2 = r(mean)
	
	bysort sic_group: egen ind_wage_p2 = mean(real_tdc) if period2==1
	
	gen wage_ratio_p2 = ind_wage_p2/`mkt_wage_p2'
	
* generating female/male wage gap

	* (no need to make female and male wage variables again)
	
	* calculating avgs by industry:
	bysort sic_group: egen avg_fwage_p2 = mean(wage_f) if period2==1
	bysort sic_group: egen avg_mwage_p2 = mean(wage_m) if period2==1
	
	* calculating the ratio/gap
	gen mf_ratio_p2 = avg_fwage_p2/avg_mwage_p2
	
* now collapsing all the variables by industry to get one number per industry for period 1:

	preserve

	collapse (mean) num_ind_p2 pctfemale_ind_p2 wage_ratio_p2 mf_ratio_p2, by(sic_group)

	format num_ind_p2 pctfemale_ind_p2 wage_ratio_p2 mf_ratio_p2 %9.2f

	export excel using "${output}/table4_panelB.xlsx", firstrow(variables) replace
	
	restore


** Question 4:

* generating log of total real compensation
gen ln_real_tdc = ln(real_tdc) 

* generating dummy variables for all neccessary titles
gen CEOchair_dummy = (titlenew2 == 10 | titlenew2 == 12)
gen ViceChair_dummy = (titlenew2 == 15)
gen Pres_dummy = (titlenew2 == 20)
gen CFO_dummy = (titlenew2 == 30)
gen COO_dummy = (titlenew2 == 40)
gen CO_dummy = (titlenew2 == 50)


* Column 1: regressing lncomp on female dummy, with year fixed effects (which B&H add for all regressions), adding robustness
eststo col1: reg ln_real_tdc female i.year if period1==1, robust

* Column 2: regressing lncomp on female dummy and CEO dummy
eststo col2: reg ln_real_tdc female CEOchair_dummy i.year if period1==1, robust

* Column 6: regressing lncomp on female dummy and the 6 title dummies:
eststo col3: reg ln_real_tdc female CEOchair_dummy ViceChair_dummy Pres_dummy CFO_dummy COO_dummy CO_dummy i.year if period1==1, robust

esttab col1 col2 col3 using "Q4a.csv", replace ///
    stats(N r2, labels("N" "R-squared"))
	

* repeating for period 2:


* Column 1: regressing lncomp on female dummy, with year fixed effects (which B&H add for all regressions)
eststo col1: reg ln_real_tdc female i.year if period2==1, robust

* Column 2: regressing lncomp on female dummy and CEO dummy
eststo col2: reg ln_real_tdc female CEOchair_dummy i.year if period2==1, robust

* Column 6: regressing lncomp on female dummy and the 6 title dummies:
eststo col3: reg ln_real_tdc female CEOchair_dummy ViceChair_dummy Pres_dummy CFO_dummy COO_dummy CO_dummy i.year if period2==1, robust

esttab col1 col2 col3 using "Q4b.csv", replace ///
    stats(N r2, labels("N" "R-squared"))

	

log close








