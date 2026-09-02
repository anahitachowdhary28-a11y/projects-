* Anahita Chowdhary
* EC57 S26: PSET 1
* 4/17/26


clear all
set more off             //(tells Stata not to truncate output)
capture log close _all


*DEFINE FOLDER PATHS

* define globals containing folder paths
global main "/Users/anahitachowdhary/Stata/econ_57/pset1"
global logs "${main}/logs"
global input "${main}/input"
global output "${main}/output"


* start a log file:
log using "${logs}/log_pset1_answers", replace


* Load the file:
use "${input}/BK2017_PSID.dta"

* Data Notes
* wave = year
* region dummies: northeast, northcentral, southeast
* wage variables: hrwage, realhrwage, lnrealwg
* expf = years of FTE experience
* expp = years of PTE experience
* wagesamp25 is the sample BK use, smsa is controlling for metropolitan area
* wage gaps: rawgap10, rawgap50, rawgap90, rawmeangap
* also dummies for race, full time, and education

********************************************************************************
* Question 1: Replicating BK 2017 Table 1 Panel A

* You will need to transform the raw gaps to the ratios

	* raw gaps in data = ln(female wage) - ln(male wage) = ln(female wage/male wage) (based on log rules)
	* we need to get ratios: 
	* e^ln(f/m) = f/m = ratio 
	*notes under table 1 say "Entries are exp(D), where D is the female mean log wage minus the corresponding male log wage."
	
	gen ratiomean = exp(rawmeangap)*100
	gen ratio10 = exp(rawgap10)*100
	gen ratio50 = exp(rawgap50)*100
	gen ratio90 = exp(rawgap90)*100

* Replicating Table 1 Panel A: 

	*getting info on sample size of men and women
	tab female year if ft==1 & wagesamp25==1
	
	*remaining table with ratios
	tabstat ratiomean ratio10 ratio50 ratio90, by(year) stat(mean) 


********************************************************************************
* Question 2: Understanding BK 2017 Table 4

* There are 3 variables not included in the table provided in Q2 but are very important for the Oaxaca-Blinder Decomposition. Referencing the formula provided in your problem set, generate the 3 additional variables needed for the regression.

	* the oaxaca blinder formula requires mean log hourly earnings for men, mean log hourly earnings for women, and the gap
	
	gen meanmen = .
	gen meanwomen = .
	gen gap = .
	
	
* Calculating the means 

	*first, creating the additional variables included in the regression example provided
	gen expfsq=expf^2 
	gen exppsq=expp^2 

	*for all stats, use ft==1 and wagesamp25==1 to ensure the same people are used as in BK. use [aw=weight] to apply person weights.
	
	*men in 1980
	tabstat edyrs ba adv expf expp northeast northcentral south black hisp othrace smsa expfsq exppsq if female==0 & ft==1 & wagesamp25==1 & year==1981 [aw=weight]
	
	*women in 1980
	tabstat edyrs ba adv expf expp northeast northcentral south black hisp othrace smsa expfsq exppsq if female==1 & ft==1 & wagesamp25==1 & year==1981 [aw=weight]
	
	*men in 2010
	tabstat edyrs ba adv expf expp northeast northcentral south black hisp othrace smsa expfsq exppsq if female==0 & ft==1 & wagesamp25==1 & year==2011 [aw=weight]
	
	*women in 2010
	tabstat edyrs ba adv expf expp northeast northcentral south black hisp othrace smsa expfsq exppsq if female==1 & ft==1 & wagesamp25==1 & year==2011 [aw=weight]

	
* Calculating the regression coefficients

	*regression for men in 1980
	reg lnrealwg edyrs ba adv expf expp northeast northcentral south black hisp othrace smsa expfsq exppsq if female==0 & ft==1 & wagesamp25==1 & year==1981 [aw=weight]

	*regression for women in 1980
	reg lnrealwg edyrs ba adv expf expp northeast northcentral south black hisp othrace smsa expfsq exppsq if female==1 & ft==1 & wagesamp25==1 & year==1981 [aw=weight]

	*regression for men in 2010
	reg lnrealwg edyrs ba adv expf expp northeast northcentral south black hisp othrace smsa expfsq exppsq if female==0 & ft==1 & wagesamp25==1 & year==2011 [aw=weight]
	
	*regression for women in 2010
	reg lnrealwg edyrs ba adv expf expp northeast northcentral south black hisp othrace smsa expfsq exppsq if female==1 & ft==1 & wagesamp25==1 & year==2011 [aw=weight]

	
********************************************************************************
* Question 3: Using Oaxaca to replicate table 4

* Gathering the means for the 3 additional variables 
	
	*generating mean log hourly earnings for men in 1980
	sum lnrealwg if female==0 & ft==1 & wagesamp25==1 & year==1981 [aw=weight]
	replace meanmen = r(mean) if year==1981
	
	*generating mean log hourly earnings for women in 1980 
	sum lnrealwg if female==1 & ft==1 & wagesamp25==1 & year==1981 [aw=weight]
	replace meanwomen = r(mean) if year==1981
	
	*generating mean log hourly earnings for men in 2010 
	sum lnrealwg if female==0 & ft==1 & wagesamp25==1 & year==2011 [aw=weight]
	replace meanmen = r(mean) if year==2011
	
	*generating mean log hourly earnings for women in 2010 
	sum lnrealwg if female==1 & ft==1 & wagesamp25==1 & year==2011 [aw=weight]
	replace meanwomen = r(mean) if year==2011
	
	
* Calculate the raw wage gap: -- then subtract the difference (male - female)

	*generating the gap in mean log hourly earnings between men and women for BOTH 1981 and 2011
	replace gap = meanmen - meanwomen
	

log close
	
	
	
	
