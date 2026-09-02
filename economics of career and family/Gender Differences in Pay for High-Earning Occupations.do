* Anahita Chowdhary
* EC57 S26: PSET 2
* 4/28/26


clear all
set more off 
capture log close _all


*DEFINE FOLDER PATHS

* define globals containing folder paths
global main "/Users/anahitachowdhary/Stata/econ_57/pset2"
global logs "${main}/logs"
global input "${main}/input"


* start a log file:
log using "${logs}/log_pset2_answers", replace


* Load the data:
use "${input}/Goldin2014_regsdata.dta"

* ------------------------------------------------------------------------------------------------------------------------------------------------------------------

* Question 1)


* creating loops for my DIY x-axis:

	* list of tick marks:
	local ticks "10.8 10.9 11.0 11.1 11.2 11.3 11.4 11.5 11.6 11.7 11.8 11.9 12.0 12.1"
	* empty lists for little lines (Paired Coordinate Immediates) and tick labels:
	local pcis ""
	local labels ""

	* using the numbers in the tick list to add to the list of pcis and labels in order to add these into the scatterplot:
	foreach tick of local ticks {
		local pcis "`pcis' (pci 0 `tick' -0.01 `tick', lcolor(black) lwidth(thin))"
		local labels "`labels' text(0 `tick' "`tick'", placement(s))"
		}


* making Figure 2B

graph set window fontface "Arial"
		
* making the scatter plot with different symbols for each category of occupation:
		* I do the following:
			* remove the occupations where the number of men and women is not at least 25 (as Goldin does)
			* use RGB colors (got by using eyedropper tool)
			* modify the size of the symbols
twoway (scatter GG meanincwbf_m if category=="health" & cnt_f >= 25 & cnt_m >= 25, msymbol(diamond) mcolor("97 150 202") msize(medlarge)) ///
       (scatter GG meanincwbf_m if category=="business" & cnt_f >= 25 & cnt_m >= 25, msymbol(square) mcolor("205 104 96") msize(medlarge)) ///
       (scatter GG meanincwbf_m if category=="tech" & cnt_f >= 25 & cnt_m >= 25, msymbol(triangle) mcolor("171 197 109") msize(medlarge)) ///
       (scatter GG meanincwbf_m if category=="science" & cnt_f >= 25 & cnt_m >= 25, msymbol(triangle) mcolor("254 205 162") msize(medlarge)) ///
       (scatter GG meanincwbf_m if category=="other" & cnt_f >= 25 & cnt_m >= 25, msymbol(circle) mcolor("182 182 183") msize(medlarge)) ///
	   ///
	   /// * add regression fit line for relevant occupations:
	   (lfit GG meanincwbf_m if category != "" & cnt_f >= 25 & cnt_m >= 25) ///
	   /// * adding the tick marks for the DIY x-axis: 
	   `pcis', ///
	   ///
	   /// * removing the margins, drawing a new line at y=0, and removing the built-in x-axis and label:
       plotregion(margin(zero)) ///
	   yline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
	   xscale(noline) ///
	   xlabel(none) ///
	   ///
	   /// * adding the axis labels for the DIY x-axis:
	   `labels' ///
	   ///
	   /// * establishing the range for the y-axis and fixing the gridlines: 
	   ylabel(-0.7(0.1)0.2, grid glcolor(gs14) glpattern(solid)) ///
	   ///
	   /// * axis titles:
       xtitle("ln (Male wage and business income)") ytitle("Coefficient on female x occupation") title("Figure 2B") scale(0.8) ///
	   /// * legend (making sure only the five categories are in the legend, they are placed at the bottom, and the are placed next to each other horizontally)
       legend(order(1 2 3 4 5) label(1 "Health") label(2 "Business") label(3 "Tech") label(4 "Science") label(5 "Other") position(6) col(5))

* ------------------------------------------------------------------------------------------------------------------------------------------------------------------
	   
* Question 2)


* 2a)

* creating the DIY x-axis again:
local ticks_two "9.5 10.0 10.5 11.0 11.5 12.0"
local pcis_two ""
local labels_two ""
foreach tick of local ticks_two {
	local pcis_two "`pcis_two' (pci 0 `tick' -0.01 `tick', lcolor(black) lwidth(thin))"
	local labels_two "`labels_two' text(0 `tick' "`tick'", placement(s))"
	}
	
* scatterplot for all occupations:
twoway (scatter GG meanincwbf_m) ///
	 (lfit GG meanincwbf_m) ///
	`pcis_two', ///
	 plotregion(margin(zero)) ///
	 xscale(noline) ///
     yline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
	 xlabel(none) ///
	`labels_two' ///
	 xtitle("ln (Male wage and business income)") ytitle("Coefficient on female x occupation") title("Gender wage gap by ln(male wage), all occupations") ///
	 legend(off)


* 2b)


* sorting the occupations by avg male income:
sort meanincwbf_m


* creating DIY x-axes for the relevant ranges, same as in previous parts:
local ticks_three "10.9 11.1 11.3 11.5 11.7 11.9 12.1"
local pcis_three ""
local labels_three ""
foreach tick of local ticks_three {
	local pcis_three "`pcis_three' (pci 0 `tick' -0.01 `tick', lcolor(black) lwidth(thin))"
	local labels_three "`labels_three' text(0 `tick' "`tick'", placement(s))"
	}

local ticks_four "9.5 9.7 9.9 10.1 10.3 10.5 10.7"
local pcis_four ""
local labels_four ""
foreach tick of local ticks_four {
	local pcis_four "`pcis_four' (pci 0 `tick' -0.01 `tick', lcolor(black) lwidth(thin))"
	local labels_four "`labels_four' text(0 `tick' "`tick'", placement(s))"
	}

	
* creating scatterplot for 150 top earning occupations and saving the graph:
twoway (scatter GG meanincwbf_m if _n > 469 - 150) ///
	 (lfit GG meanincwbf_m if _n > 469 - 150) ///
	`pcis_three', ///
	 plotregion(margin(zero)) ///
	 xscale(noline) ///
     yline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
     xlabel(none) ///
	`labels_three' ///
	 xtitle("ln (Male wage and business income)") ytitle("Coefficient on female x occupation") title("Figure 2B.1: Top 150 occupations") ///
	 legend(off)
	 graph save panel_one, replace

	 
* creating scatterplot for 150 bottom earning occupations and saving the graph:
twoway (scatter GG meanincwbf_m if _n <= 150) ///
	 (lfit GG meanincwbf_m if _n <= 150) ///
	`pcis_four', ///
	 plotregion(margin(zero)) ///
	 xscale(noline) ///
     yline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
	 xlabel(none) ///
	`labels_four' ///
	 xtitle("ln (Male wage and business income)") ytitle("Coefficient on female x occupation") title("Figure 2B.2: Bottom 150 occupations") ///
	 legend(off)
	 graph save panel_two, replace

* combining the two graphs into one and putting them side by side:
graph combine panel_one.gph panel_two.gph, cols(2)


* ------------------------------------------------------------------------------------------------------------------------------------------------------------------
	   

* Question 3)

* generating a variable representing the share of women in an occupation:
gen share_women = cnt_f/count

* creating a scatterplot for wage gap vs. share of women in occupation: 
twoway (scatter GG share_women) ///
	 (lfit GG share_women), ///
	 plotregion(margin(zero)) ///
	 xscale(noline) ///
     yline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
	 xtitle("Share of Women in Occupation") ytitle("Coefficient on female x occupation") title("Gender Earnings Gap by Share of Women in Occupation") ///
	 legend(off)



* ------------------------------------------------------------------------------------------------------------------------------------------------------------------
	   
* Question 4)

* 4a)

* merging datasets:
merge 1:1 occ2 using "${input}/Goldin2014_ONet.dta"
keep if _merge==3


* 4b)

* variables used by Goldin according to the provided pdf: interpers_rel, freq_dec, structwork, timepress, contact
* Note: Goldin uses free_decision rather than freq_dec as highlighted peach in the OccCharacteristicsONet.pdf, so I also include free_decision and see how those numbers compare to Goldin's

* generating new category for science and tech:
gen tech_science = (tech==1 | science==1)

sum timepress contact interpers_rel structwork free_decision freq_dec
* mean and standard deviation of these variables are clearly not 0 and 1, so I will need to standardize to reproduce Table 2

* generating standardized versions (mean 0 std 1) of each ONet characteristic:
egen timepress_std = std(timepress)
egen contact_std = std(contact)
egen interpers_rel_std = std(interpers_rel)
egen structwork_std = std(structwork)
egen free_decision_std = std(free_decision)
egen freq_dec_std = std(freq_dec)

sum timepress_std if tech_science==1
sum contact_std if tech_science==1
sum interpers_rel_std if tech_science==1
sum structwork_std if tech_science==1
sum free_decision_std if tech_science==1
sum freq_dec_std if tech_science==1

sum timepress_std if business==1
sum contact_std if business==1
sum interpers_rel_std if business==1
sum structwork_std if business==1
sum free_decision_std if business==1
sum freq_dec_std if business==1

sum timepress_std if health==1
sum contact_std if health==1
sum interpers_rel_std if health==1
sum structwork_std if health==1
sum free_decision_std if health==1
sum freq_dec_std if health==1

sum timepress_std if law==1
sum contact_std if law==1
sum interpers_rel_std if law==1
sum structwork_std if law==1
sum free_decision_std if law==1
sum freq_dec_std if law==1


* fixing the issue with natural science managers being classified under tech/science rather than health by using category from the original dataset:

sum timepress_std if category=="tech" | category=="science"
sum contact_std if category=="tech" | category=="science"
sum interpers_rel_std if category=="tech" | category=="science"
sum structwork_std if category=="tech" | category=="science"
sum free_decision_std if category=="tech" | category=="science"
sum freq_dec_std if category=="tech" | category=="science"

sum timepress_std if category=="health"
sum contact_std if category=="health"
sum interpers_rel_std if category=="health"
sum structwork_std if category=="health"
sum free_decision_std if category=="health"
sum freq_dec_std if category=="health"


* 4c)


* generating flexibility index by taking the average of interpers_rel, freq_dec, structwork, timepress, and contact:
gen flexibility = (timepress_std + contact_std + interpers_rel_std + structwork_std + freq_dec_std)/5
* ranking the occupations from smallest to largest by this index:
sort flexibility


* creating DIY x-axis, same as before:
local ticks_five "-2.0 -1.5 -1.0 -0.5 0 0.5 1.0 1.5 2.0"
local pcis_five ""
local labels_five ""
foreach tick of local ticks_five {
	local pcis_five "`pcis_five' (pci 0 `tick' -0.01 `tick', lcolor(black) lwidth(thin))"
	local labels_five "`labels_five' text(0 `tick' "`tick'", placement(s))"
	}

* this time, I also need to create a DIY y-axis that lands at x=0:
local ticks_six "-0.6 -0.5 -0.4 -0.3 -0.2 -0.1 0.0 0.1"
local pcis_six ""
local labels_six ""
foreach tick of local ticks_six {
	local pcis_six "`pcis_six' (pci `tick' -0.01 `tick' 0.01, lcolor(black) lwidth(thin))"
	local labels_six "`labels_six' text(`tick' 0 "`tick'", placement(w))"
	}


* creating the scatterplots of gender gap by flexibility for each category, with the DIY axes and a legend and titles:
twoway (scatter GG flexibility if category=="health" & cnt_f >= 25 & cnt_m >= 25, msymbol(diamond) mcolor("97 150 202") msize(medlarge)) ///
       (scatter GG flexibility if category=="business" & cnt_f >= 25 & cnt_m >= 25, msymbol(square) mcolor("205 104 96") msize(medlarge)) ///
       (scatter GG flexibility if category=="tech" & cnt_f >= 25 & cnt_m >= 25, msymbol(triangle) mcolor("171 197 109") msize(medlarge)) ///
       (scatter GG flexibility if category=="science" & cnt_f >= 25 & cnt_m >= 25, msymbol(triangle) mcolor("254 205 162") msize(medlarge)) ///
       (scatter GG flexibility if category=="other" & cnt_f >= 25 & cnt_m >= 25, msymbol(circle) mcolor("182 182 183") msize(medlarge)) ///
	   (lfit GG flexibility if cnt_f >= 25 & cnt_m >= 25)
	   	`pcis_five' `pcis_six', ///
		plotregion(margin(zero)) ///
		xscale(noline) yscale(noline) ///
		yline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
		xline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
		xlabel(none) ylabel(-0.6(0.1)0.1, grid glcolor(gs14) nolabels noticks glpattern(solid)) ///
		`labels_five' `labels_six' ///
		xtitle("Average of five normalized characteristics") ytitle("Coefficient on female x occupation") title("Figure 5. O*Net Characteristics and the Residual College Gender Earnings Gap by Occupation") scale(0.8) ///
		legend(order(1 2 3 4 5) label(1 "Health") label(2 "Business") label(3 "Tech") label(4 "Science") label(5 "Other") position(6) col(5))

		
* 4d)

* creating the y-axis!
local ticks_sev "0.0 0.2 0.4 0.6 0.8 1.0"
local pcis_sev ""
local labels_sev ""
foreach tick of local ticks_sev {
	local pcis_sev "`pcis_sev' (pci `tick' -0.01 `tick' 0.01, lcolor(black) lwidth(thin))"
	local labels_sev "`labels_sev' text(`tick' 0 "`tick'", placement(w))"
	}

* creating the scatterplot showing flexibility index vs. share of women in an occupation:
twoway (scatter share_women flexibility) ///
	   (lfit share_women flexibility) ///
	   	`pcis_sev', ///
		plotregion(margin(zero)) ///
		xline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
		`labels_sev' ///
		ylabel(0.0(0.2)1.0, grid glcolor(gs14) nolabels noticks glpattern(solid)) ///
		yscale(noline) ///
		xtitle("flexibility index") ytitle("share of women in occupation") title("Occupational Segregation and Flexibility") ///
	   legend(off)

	 
* 4e)

*choosing to look at competition (comp):
egen comp_std = std(comp)

* summary statistics:
sum comp_std if tech_science==1
sum comp_std if business==1
sum comp_std if health==1
sum comp_std if law==1

* creating x and y axes:
local ticks_eigh "-2.0 -1.5 -1.0 -0.5 0.0 0.5 1.0 1.5 2.0 2.5 3.0"
local pcis_eigh ""
local labels_eigh ""
foreach tick of local ticks_eigh {
	local pcis_eigh "`pcis_eigh' (pci 0 `tick' -0.01 `tick', lcolor(black) lwidth(thin))"
	local labels_eigh "`labels_eigh' text(0 `tick' "`tick'", placement(s))"
	}
	
local ticks_nine "-0.6 -0.5 -0.4 -0.3 -0.2 -0.1 0.0 0.1"
local pcis_nine ""
local labels_nine ""
foreach tick of local ticks_nine {
	local pcis_nine "`pcis_nine' (pci `tick' -0.01 `tick' 0.01, lcolor(black) lwidth(thin))"
	local labels_nine "`labels_nine' text(`tick' 0 "`tick'", placement(w))"
	}

* creating scatterplot showing relationship between competition level and gender earnings gap:
twoway (scatter GG comp_std if category=="health", msymbol(diamond) mcolor("97 150 202") msize(medlarge)) ///
       (scatter GG comp_std if category=="business", msymbol(square) mcolor("205 104 96") msize(medlarge)) ///
       (scatter GG comp_std if category=="tech", msymbol(triangle) mcolor("171 197 109") msize(medlarge)) ///
       (scatter GG comp_std if category=="science", msymbol(triangle) mcolor("254 205 162") msize(medlarge)) ///
       (scatter GG comp_std if law==1, msymbol(circle) mcolor("182 182 183") msize(medlarge)) ///
	   (lfit GG comp_std) ///
	   `pcis_eigh' `pcis_nine', ///
		plotregion(margin(zero)) ///
	    xscale(noline) yscale(noline) ///
        yline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
		xline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
	    xlabel(none) ylabel(-0.6(0.1)0.1, grid glcolor(gs14) nolabels noticks glpattern(solid)) ///
		`labels_eigh' `labels_nine' ///
		xtitle("Level of Competition") ytitle("Coefficient on female x occupation") title("Gender Earnings Gap by Level of Competition") scale(0.8) ///
	   	legend(order(1 2 3 4 5) label(1 "Health") label(2 "Business") label(3 "Tech") label(4 "Science") label(5 "Law") position(6) col(5))
		

* creating the "cooperation" index:
egen develop_teams_std = std(develop_teams)
egen team_std = std(team)
egen communicate_std = std(communicate)
egen coordinating_std = std(coordinating)

gen cooperation = (develop_teams_std+team_std+communicate_std+coordinating_std)/4

*creating x and y axes again:
local ticks_ten "-2.0 -1.5 -1.0 -0.5 0.0 0.5 1.0 1.5 2.0"
local pcis_ten ""
local labels_ten ""
foreach tick of local ticks_ten {
	local pcis_ten "`pcis_ten' (pci 0 `tick' -0.01 `tick', lcolor(black) lwidth(thin))"
	local labels_ten "`labels_ten' text(0 `tick' "`tick'", placement(s))"
	}
	
local ticks_nine "-0.6 -0.5 -0.4 -0.3 -0.2 -0.1 0.0 0.1"
local pcis_nine ""
local labels_nine ""
foreach tick of local ticks_nine {
	local pcis_nine "`pcis_nine' (pci `tick' -0.01 `tick' 0.01, lcolor(black) lwidth(thin))"
	local labels_nine "`labels_nine' text(`tick' 0 "`tick'", placement(w))"
	}

* creating scatterplot showing relationship between cooperation and gender earnings gap:
twoway (scatter GG cooperation if category=="health", msymbol(diamond) mcolor("97 150 202") msize(medlarge)) ///
       (scatter GG cooperation if category=="business", msymbol(square) mcolor("205 104 96") msize(medlarge)) ///
       (scatter GG cooperation if category=="tech", msymbol(triangle) mcolor("171 197 109") msize(medlarge)) ///
       (scatter GG cooperation if category=="science", msymbol(triangle) mcolor("254 205 162") msize(medlarge)) ///
       (scatter GG cooperation if law==1, msymbol(circle) mcolor("182 182 183") msize(medlarge)) ///
	   (lfit GG cooperation) ///
	    `pcis_ten' `pcis_nine', ///
		plotregion(margin(zero)) ///
	    xscale(noline) yscale(noline) ///
        yline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
		xline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
	    xlabel(none) ylabel(-0.6(0.1)0.1, grid glcolor(gs14) nolabels noticks glpattern(solid)) ///
		`labels_ten' `labels_nine' ///
		xtitle("Level of Cooperation") ytitle("Coefficient on female x occupation") title("Gender Earnings Gap by Level of Cooperation") scale(0.8) ///
	   	legend(order(1 2 3 4 5) label(1 "Health") label(2 "Business") label(3 "Tech") label(4 "Science") label(5 "Law") position(6) col(5))
		
		
* ------------------------------------------------------------------------------------------------------------------------------------------------------------------


* Note: I also made another version of 2B to more closely match Goldin's by adding in the same domain/range restrictions as she does:

	local ticks "11.0 11.1 11.2 11.3 11.4 11.5 11.6 11.7 11.8 11.9 12.0 12.1"
	local pcis ""
	local labels ""

	foreach tick of local ticks {
		local pcis "`pcis' (pci 0 `tick' -0.01 `tick', lcolor(black) lwidth(thin))"
		local labels "`labels' text(0 `tick' "`tick'", placement(s))"
		}
		

twoway (scatter GG meanincwbf_m if category=="health" & GG >= -0.5 & GG <= 0.2 & meanincwbf_m >= 11.0 & meanincwbf_m <= 12.1 & cnt_f >= 25 & cnt_m >= 25, msymbol(diamond) mcolor("97 150 202") msize(medlarge)) ///
       (scatter GG meanincwbf_m if category=="business" & GG >= -0.5 & GG <= 0.2 & meanincwbf_m >= 11.0 & meanincwbf_m <= 12.1  & cnt_f >= 25 & cnt_m >= 25, msymbol(square) mcolor("205 104 96") msize(medlarge)) ///
       (scatter GG meanincwbf_m if category=="tech" & GG >= -0.5 & GG <= 0.2 & meanincwbf_m >= 11.0 & meanincwbf_m <= 12.1  & cnt_f >= 25 & cnt_m >= 25, msymbol(triangle) mcolor("171 197 109") msize(medlarge)) ///
       (scatter GG meanincwbf_m if category=="science" & GG >= -0.5 & GG <= 0.2 & meanincwbf_m >= 11.0 & meanincwbf_m <= 12.1  & cnt_f >= 25 & cnt_m >= 25, msymbol(triangle) mcolor("254 205 162") msize(medlarge)) ///
       (scatter GG meanincwbf_m if category=="other" & GG >= -0.5 & GG <= 0.2 & meanincwbf_m >= 11.0 & meanincwbf_m <= 12.1  & cnt_f >= 25 & cnt_m >= 25, msymbol(circle) mcolor("182 182 183") msize(medlarge)) ///
	   ///
	   /// * add regression fit line for relevant occupations:
	   (lfit GG meanincwbf_m if category != "" & GG >= -0.5 & GG <= 0.2 & meanincwbf_m >= 11.0 & meanincwbf_m <= 12.1 & cnt_f >= 25 & cnt_m >= 25) ///
	   /// * adding the tick marks for the DIY x-axis: 
	   `pcis', ///
	   ///
	   /// * removing the margins, drawing a new line at y=0, and removing the built-in x-axis and label:
       plotregion(margin(zero)) ///
	   xscale(noline) ///
       yline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
	   xlabel(none) ///
	   ///
	   /// * adding the axis labels for the DIY x-axis:
	   `labels' ///
	   ///
	   /// * establishing the range for the y-axis and fixing the gridlines: 
	   ylabel(-0.5(0.1)0.2, grid glcolor(gs14) glpattern(solid)) ///
	   ///
	   /// * axis titles:
       xtitle("ln (Male wage and business income)") ytitle("Coefficient on female x occupation") title("Figure 2B") scale(0.8) ///
	   /// * legend (making sure only the five categories are in the legend, they are placed at the bottom, and the are placed next to each other horizontally)
       legend(order(1 2 3 4 5) label(1 "Health") label(2 "Business") label(3 "Tech") label(4 "Science") label(5 "Other") position(6) col(5))


* Second note: I used Claude to help me fix the formatting of many of the graphs, specifically using the pci technique and the loops to construct makeshift axes at x=0 and y=0, since I couldn't find a tool within Stata that would allow me to easily do that.

log close





	   
	   