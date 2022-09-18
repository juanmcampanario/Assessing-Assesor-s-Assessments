clear
estimates clear 
set more off
capture log close
*ssc install estout
*ssc install egenmore

local usr = c(username)
global user `usr'

global path "C:/Users/$user/Dropbox/Assessment Assessment/clean/"
global centr "C:/Users/$user/Downloads/centroiddec2019.csv" /* Parcel Centriod data  */
global prop "C:/Users/$user/Downloads/518b583f-7cc8-4f60-94d0-174cc98310dc.csv" /* Property Assessment data */
global tbl "C:/Users/$user/Dropbox/Assessment Assessment/tables/"
global vsl "C:/Users/$user/Dropbox/Assessment Assessment/visual/"



tempfile m3
/* Prepare Parcel Centriod data*/
import delimited $centr, clear 
keep pin blockce10 calcacreag shape_leng shape_leng_1 geo_name_t geo_name_b /*
*/ geo_id_blo /* geo_id_blo geo_id_tra  are useless*/ 
 * geo_name_t is the census track and the group is given in geo_name_b */ 
 
split geo_name_b, parse(" ") gen(zz)
ren zz5 group
drop zz* 

sort pin 
save "$path/parcels.dta", replace

/* Prepare Property Assessments data */
import delimited $prop, case(upper) clear

keep PARID PROPERTYCITY MUNICODE SCHOOLCODE NEIGHCODE OWNERCODE CLASSDESC /*
*/ USECODE LOTAREA CLEANGREEN ABATEMENTFLAG RECORDDATE SALEDATE SALEPRICE /* 
*/ SALEDESC PREVSALEDATE PREVSALEPRICE PREVSALEDATE2 PREVSALEPRICE2 COUNTYBUILDING /*
*/ COUNTYLAND COUNTYTOTAL LOCALBUILDING LOCALLAND LOCALTOTAL FAIRMARKETBUILDING /*
*/ FAIRMARKETLAND FAIRMARKETTOTAL YEARBLT STORIES GRADE CONDITION CDU ALT_ID TAXYEAR TOTALROOMS /*
*/ YEARBLT EXTERIORFINISH ROOF ROOFDESC BASEMENT BASEMENTDESC BEDROOMS FULLBATHS /*
*/ HEATINGCOOLING HEATINGCOOLINGDESC FIREPLACES BSMTGARAGE FINISHEDLIVINGAREA /*
*/ EXTFINISH_DESC

rename *, lower

tab classdesc, missing
encode classdesc, gen(class)
drop classdesc 

encode propertycity, gen(AAA)
drop propertycity 
ren AA propertcity

encode saledesc, gen(AAA)
drop saledesc 
ren AA saledesc

ren extfinish_desc exteriorfinishdesc

foreach x in roof basement heatingcooling exteriorfinish {
	drop `x'
	encode `x'desc, gen(`x')
	drop `x'desc
}

replace cdu="Excellent" if cdu=="EX"
replace cdu="Average" if cdu=="AV"
replace cdu="Fair" if cdu=="FR"
replace cdu="Poor" if cdu=="PR"
replace cdu="Very Poor" if cdu=="VP"
replace cdu="Unsound" if cdu=="UN"
replace cdu="Very Good" if cdu=="VG"
replace cdu="Good" if cdu=="GD"

encode cdu, gen(rating)
label var rating "Composite Rating"
drop cdu 

gen aircon = 1 if inlist(heating,2,4,6,8,9,13,15)
replace aircon = 0 if heating!=. & aircon!=1 

gen fire_oneplus = 1 if fireplace>0 & fireplace !=.
replace fire_oneplus =0 if fireplace==0

*drop things with blanks*

drop if grade == ""
drop if condition == .
drop if fairmarkettotal == 0
drop if stories == .

replace fireplaces = 0 if fireplaces == .
replace bsmtgarage = 0 if bsmtgarage == .
replace totalrooms = 0 if totalrooms == .
replace bedrooms = 0 if bedrooms == .
replace fullbaths = 0 if fullbaths == .
tab condition, gen(nc)

gen pla = .
replace pla =1 if condition==1
replace pla =2 if condition==7
replace pla =3 if condition==2
replace pla =4 if condition==3
replace pla =5 if condition==4
replace pla =6 if condition==5
replace pla =7 if condition==6
replace pla =8 if condition==8
drop condition
ren pla condition

rename parid pin
sort pin 
merge m:m pin using  "$path/parcels.dta" /* properties didn't find a home, no immediate reason*/
keep if _m==3
drop _m 

preserve 
use "$path/BG_Demos_Housing.dta", clear 
split id, parse("US") gen(pins)
drop pins1
ren pins2 geo_id_blo
destring geo_id_blo, replace
save `m3', replace
restore 

merge m:1 geo_id_blo using `m3' /*  properties didn't find a home, no immediate reason*/
keep if _m==3
drop _m 
drop geo_name_b group
save "$path/merged_data.dta", replace 

gen bgroup = substr(geog, 13, 1) + substr(geog, 29, 3)
destring bgroup, replace
encode neigh, gen(ncode)
gen saleyear = substr(saledate, 7, .)
destring saleyear, replace


foreach x in stories totalrooms bedrooms fullbaths fireplaces bsmtgarage /*
*/ finishedlivingarea lotarea roof basement heatingcooling exteriorfinish yearblt saleyear /*
*/ nc1 nc2 nc3 nc4 nc5 nc6 nc7 nc8  {
	bysort bgroup: egen samplemean_`x' = mean(`x')
	label var samplemean_`x' "Block Group Sample mean of `x'"
}


tab class, nol
keep if class==6 /*data now only contains residential properties */
drop class

*ratio of sale and assessment prices
gen ratoo = fairmarkettotal/saleprice
gen rto=log(ratoo)

gen sale_restrict=.
replace sale_restrict=1 if saleprice>=1000

gen fmt=log(fairmarkettotal)
gen sp=log(saleprice)

*create important demos
gen non_white = nh_Black + nh_Native + nh_Asian + nh_Hawaiian + nh_Other + nh_Two + Hispanic
gen HS = Less_HS + HighSchool

/* label the important stuff */
label define nc 1 "Excellent" 2 "Very Good" 3 "Good" 4 "Average" 5 "Fair" /*
*/ 6 "Poor" 7 "Very Poor" 8 "Unsound"
label var condition "Physical Condition"
label val condition nc 

label define yesno 0 no 1 yes
label var aircon "Air-Conditioning"
label val aircon yesno

label var fire_oneplus "Fireplace"
label val fire_oneplus yesno 

label var fairmarkettotal "Fair Market"
label var saleprice "Sale"
label var fmt "Log Fair Market Value"
label var sp "Log Sale Price" 

label var ratoo "Ratio of Fair Mkt and Sale"
label var rto "Log Ratio of Fair Market to Sale"

label var non_white "\% Non-White"
label var Public_Assistance "\% Public Assistance"
label var Public_Transit  "\% Public Transit"
label var All_Other_T  "\% Other Transportation"
label var HS "\% High School Degree"
label var stories "\# of Stories"
label var totalrooms "\# of Rooms"
label var bedrooms "\# of Bedrooms"
label var fullbaths "\# of Full Bathrooms"
label var fireplace "\# of Fireplaces"
label var bsmtgarage "Garage Space"
label var finishedlivingarea "Living Area ($\text{ft}^2$)"
label var lotarea "Land Area ($\text{ft}^2$)"
label var saleyear "Sale Year"
label var Under_Eighteen "\% Under 18"
label var Eighteen_to_Tw "\% 18 to 20"
label var Fortyfive_to_Six "\% 45 to 60"
label var Sixtyfive_up "\% 65+"
label var yearblt "Year Built"


save "$path/merged_data.dta", replace 

********************************************************************************
*Tables 
********************************************************************************
use "$path/merged_data.dta", clear
egen q_non_white = xtile(non_white), nq(4)
label define quarters 1 "$0-25^\text{th}$" 2 "$25-50^\text{th}$" 3 "$50-75^\text{th}$" 4 "$75-100^\text{th}$"
label val q_non_white quarters 


*All Assessments in Sample 
bysort q_non_white: eststo: estpost summarize fairmarkettotal saleprice  ratoo /* 
*/ finishedlivingarea lotarea stories condition  /*
*/ totalrooms bedrooms fullbaths fireplaces aircon yearblt saleyear non_white HS Public_Assistance /*
*/ Public_Transit Under_Eighteen Eighteen_to_Tw Fortyfive_to_Six Sixtyfive_up, listwise
esttab using "$tbl/fmt_quartiles_all.tex", replace ///
cells(mean(label("Mean") fmt(3)) sd(label("SD") par fmt(3))) ///
 booktabs label collabels(none) nodepvar nostar gaps  ///
 prehead("\begin{table}[htbp]\centering" ///
		"\begin{adjustbox}{width=.5\textwidth, center}" ///
		"\begin{threeparttable}" ///
		"\caption{Summary Statistics: Housing and Demographic Characteristics}" ///
		"\begin{tabular}{l*{4}{c}}" ///
		"\toprule") ///
 postfoot("\bottomrule" ///
 "\end{tabular}" ///
 "\end{threeparttable}" ///
 "\end{adjustbox}" ///
 "\end{table}")
estimates clear 

bysort q_non_white: eststo: estpost summarize fairmarkettotal saleprice ratoo  /* 
*/ finishedlivingarea lotarea stories condition /*
*/ totalrooms fullbaths fireplaces aircon yearblt saleyear, listwise
esttab using "$tbl/fmt_quartiles_house.tex", replace ///
cells(mean(label("Mean") fmt(3)) sd(label("SD") par fmt(3))) ///
 booktabs label collabels(none) nodepvar nostar gaps  ///
 prehead("\begin{table}[htbp]\centering" ///
		"\begin{adjustbox}{width=.5\textwidth, center}" ///
		"\begin{threeparttable}" ///
		"\caption{Summary Statistics: Housing Characteristics}" ///
		"\begin{tabular}{l*{4}{c}}" ///
		"\toprule") ///
 postfoot("\bottomrule" ///
 "\end{tabular}" ///
 "\end{threeparttable}" ///
 "\end{adjustbox}" ///
 "\end{table}")
estimates clear 

bysort q_non_white: eststo: estpost summarize non_white HS Public_Assistance /*
*/ Public_Transit Under_Eighteen Eighteen_to_Tw Fortyfive_to_Six Sixtyfive_up, listwise
esttab using "$tbl/fmt_quartiles_demo.tex", replace ///
cells(mean(label("Mean") fmt(3)) sd(label("SD") par fmt(3))) ///
 booktabs label collabels(none) nodepvar nostar gaps  ///
 prehead("\begin{table}[htbp]\centering" ///
		"\begin{adjustbox}{width=.5\textwidth, center}" ///
		"\begin{threeparttable}" ///
		"\caption{Summary Statistics: Demographic Characteristics}" ///
		"\begin{tabular}{l*{4}{c}}" ///
		"\toprule") ///
 postfoot("\bottomrule" ///
 "\end{tabular}" ///
 "\end{threeparttable}" ///
 "\end{adjustbox}" ///
 "\end{table}")
estimates clear
 
*Subsample of Sold Houses 
keep if saledesc == 129 | saledesc == 119
keep if sale_restrict ==1
keep if saleyear >= 2010

bysort q_non_white: eststo: estpost summarize fairmarkettotal saleprice ratoo  /* 
*/ finishedlivingarea lotarea stories condition /*
*/ totalrooms bedrooms fullbaths fireplaces aircon yearblt saleyear non_white HS Public_Assistance /*
*/ Public_Transit Under_Eighteen Eighteen_to_Tw Fortyfive_to_Six Sixtyfive_up, listwise
esttab using "$tbl/sp_quartiles_all.tex", replace ///
cells(mean(label("Mean") fmt(3)) sd(label("SD") par fmt(3))) ///
 booktabs label collabels(none) nodepvar nostar gaps  ///
 prehead("\begin{table}[htbp]\centering" ///
		"\begin{adjustbox}{width=.5\textwidth, center}" ///
		"\begin{threeparttable}" ///
		"\caption{Summary Statistics: Housing and Demographic Characteristics}" ///
		"\begin{tabular}{l*{4}{c}}" ///
		"\toprule") ///
 postfoot("\bottomrule" ///
 "\end{tabular}" ///
 "\end{threeparttable}" ///
 "\end{adjustbox}" ///
 "\end{table}")
estimates clear 

bysort q_non_white: eststo: estpost summarize fairmarkettotal saleprice  ratoo /* 
*/ finishedlivingarea lotarea stories condition  /*
*/ totalrooms fullbaths fireplaces aircon yearblt saleyear, listwise
esttab using "$tbl/sp_quartiles_house.tex", replace ///
cells(mean(label("Mean") fmt(3)) sd(label("SD") par fmt(3))) ///
 booktabs label collabels(none) nodepvar nostar gaps  ///
 prehead("\begin{table}[htbp]\centering" ///
		"\begin{adjustbox}{width=.5\textwidth, center}" ///
		"\begin{threeparttable}" ///
		"\caption{Summary Statistics: Housing Characteristics}" ///
		"\begin{tabular}{l*{4}{c}}" ///
		"\toprule") ///
 postfoot("\bottomrule" ///
 "\end{tabular}" ///
 "\end{threeparttable}" ///
 "\end{adjustbox}" ///
 "\end{table}")
estimates clear 

bysort q_non_white: eststo: estpost summarize non_white HS Public_Assistance /*
*/ Public_Transit Under_Eighteen Eighteen_to_Tw Fortyfive_to_Six Sixtyfive_up, listwise
esttab using "$tbl/sp_quartiles_demo.tex", replace ///
cells(mean(label("Mean") fmt(3)) sd(label("SD") par fmt(3))) ///
 booktabs label collabels(none) nodepvar nostar gaps  ///
 prehead("\begin{table}[htbp]\centering" ///
		"\begin{adjustbox}{width=.5\textwidth, center}" ///
		"\begin{threeparttable}" ///
		"\caption{Summary Statistics: Demographic Characteristics}" ///
		"\begin{tabular}{l*{4}{c}}" ///
		"\toprule") ///
 postfoot("\bottomrule" ///
 "\end{tabular}" ///
 "\end{threeparttable}" ///
 "\end{adjustbox}" ///
 "\end{table}")
estimates clear 
********************************************************************************
*REGRESSIONS 
********************************************************************************
use "$path/merged_data.dta", clear 

tab bgroup, gen(zz_bgroup)
tab ncode, gen(zz_ncode) 

global house nc2 nc3 nc4 nc5 nc6 nc7 nc8 stories totalrooms bedrooms fullbaths /*
*/ fireplaces bsmtgarage finishedlivingarea lotarea roof i.basement /*
*/ i.heatingcooling i.exteriorfinish i.yearblt i.saleyear
global acs HS Public_Assistance Public_Transit All_Other_T /* 
*/ Under_Eighteen Eighteen_to_Tw Fortyfive_to_Six Sixtyfive_up

global rbt robust cluster(municode)

*Comparing Block Group to Neighborhood FE
preserve
foreach x in fmt sp {
	if "`x'"=="sp"	{
	*run on only houses sold since 2010*
	keep if saledesc == 129 | saledesc == 119
	keep if sale_restrict ==1
	keep if saleyear >= 2010
	}

qui reg `x' $house , $rbt
eststo `x'_0
qui reg `x' $house zz_b*, $rbt
eststo `x'_1
qui reg `x'  $house zz_n*, $rbt
eststo `x'_2
}
esttab fmt_0 fmt_1 fmt_2 sp_0 sp_1 sp_2 using "$tbl/compare_bg_to_neigh.tex", drop(*) /* 
*/ nostar stats(r2_a N N_clust, fmt(3 0 0) labels("Adjusted R-Squared" "Observations" "Clusters"))  /*
	*/ booktabs  /*
	*/ indicate("Housing Characteristics = stories" "Block Group FE = zz_bgroup4"  "Neighborhood FE = zz_ncode4") /*
	*/ mtitles("Fair Mkt" "Fair Mkt" "Fair Mkt" "Sale" "Sale" "Sale") ///
	prehead("\begin{table}[htbp]\centering" ///
		"\begin{adjustbox}{width=.7\textwidth, center}" ///
		"\begin{threeparttable}" ///
		"\caption{Comparison of Block-Group and Neighborhood Fixed Effects}" ///
		"\begin{tabular}{l*{6}{c}}" ///
		"\toprule") ///
 postfoot("\bottomrule" ///
"\end{tabular}" ///
 "\end{threeparttable}" ///
 "\end{adjustbox}" ///
 "\end{table}") replace 
estimates clear 
restore 

*Using Demographics Instead of Block-Group
preserve
foreach x in fmt sp {
	if "`x'"=="sp"	{
	*run on only houses sold since 2010*
	keep if saledesc == 129 | saledesc == 119
	keep if sale_restrict==1
	keep if saleyear >= 2010
	global tle Sale Price
	}
	if  "`x'"=="fmt" {
	    global tle Fair Market Valuation
	}
	qui reg `x' $house , $rbt
	eststo `x'_0
	qui reg `x' $house zz_b*, $rbt
	eststo `x'_1
	qui reg `x' $house samplemean*, $rbt
	eststo `x'_2
	qui reg `x' $house samplemean* $acs, $rbt
	eststo `x'_3
	qui reg `x' $house samplemean* $acs non_white, $rbt
	eststo `x'_4
	
	esttab `x'_0 `x'_1 `x'_2 `x'_3 `x'_4 using "$tbl/`x'_results.tex", /*
*/	keep(non_white HS Public_Assistance Public_Transit  All_Other_Transport) /* 
*/ cells(b(star fmt(3)) se(par fmt(3))) star(* .1 ** .05 *** .01) /*
*/ stats(r2_a N N_clust, fmt(3 0 0) labels("Adjusted R-Squared" "Observations" "Clusters"))  /*
	*/ booktabs label collabels(none) gaps nomtitles /*
	*/ indicate("Housing Characteristics = stories" "Block Group FE = zz_bgroup4" ///
	"Average Parcel Characteristics = samplemean_*"  "ACS Demographics = Sixtyfive_up" /// 
	 ) /*
	*/ prehead("\begin{table}[htbp]\centering" ///
		"\begin{adjustbox}{width=.7\textwidth, center}" ///
		"\begin{threeparttable}" ///
		"\caption{Log $tle with Block-Group Demograhic Characteristics}" ///
		"\begin{tabular}{l*{5}{c}}" ///
		"\toprule") ///
 postfoot("\bottomrule" ///
"\multicolumn{6}{l}{\footnotesize \sym{*} \(p<.1\), \sym{**} \(p<.05\), \sym{***} \(p<.01\)}\\" ///
"\end{tabular}" ///
 "\end{threeparttable}" ///
 "\end{adjustbox}" ///
 "\end{table}") replace 
 estimates clear
}
restore 

*log RTO 
keep if saledesc == 129 | saledesc == 119
keep if sale_restrict ==1
keep if saleyear >= 2010
	
qui reg rto $house , $rbt
eststo rto_0
qui reg rto $house zz_b*, $rbt
eststo rto_1
qui reg rto $house samplemean_*, $rbt
eststo rto_2
qui reg rto $house samplemean_* $acs , $rbt
eststo rto_3
qui reg rto $house samplemean* $acs non_white , $rbt
eststo rto_4

esttab rto_0 rto_1 rto_2 rto_3 rto_4 using "$tbl/ratio.tex",  /*
*/ keep(non_white HS Public_Assistance Public_Transit  All_Other_Transport) /* 
*/ cells(b(star fmt(3)) se(par fmt(3))) star(* .1 ** .05 *** .01) /*
*/ booktabs label collabels(none) gaps nomtitles  /*
*/ stats(r2_a N N_clust, fmt(3 0 0) labels("Adjusted R-Squared" "Observations" "Clusters"))/*
	*/ indicate("Housing Characteristics = stories" "Block Group FE = zz_bgroup4" ///
	"Average Parcel Characteristics = samplemean_*" "ACS Demographics = Sixtyfive_up") ///
	prehead("\begin{table}[htbp]\centering" ///
		"\begin{adjustbox}{width=.5\textwidth, center}" ///
		"\begin{threeparttable}" ///
		"\caption{Log Ratio of Fair Market Valuation to Sale Price}" ///
		"\begin{tabular}{l*{5}{c}}" ///
		"\toprule") ///
 postfoot("\bottomrule" ///
"\multicolumn{6}{l}{\footnotesize \sym{*} \(p<.1\), \sym{**} \(p<.05\), \sym{***} \(p<.01\)}\\" ///
"\end{tabular}" ///
 "\end{threeparttable}" ///
 "\end{adjustbox}" ///
 "\end{table}") replace  
estimates clear 

*FAIR MKT on RHS
qui reg sp fmt $house , $rbt
eststo reg1
qui reg sp fmt $house zz_b*, $rbt
eststo reg2
qui reg sp fmt $house samplemean_*, $rbt
eststo reg3a
qui reg sp fmt $house samplemean_* $acs , $rbt
eststo reg4
qui reg sp fmt $house samplemean* $acs non_white , $rbt
eststo reg5

esttab reg1 reg2 reg3a reg4 reg5 using "$tbl/fmt_rhs.tex",  /*
*/ keep(non_white HS Public_Assistance Public_Transit  All_Other_Transport) /* 
*/ cells(b(star fmt(3)) se(par fmt(3))) star(* .1 ** .05 *** .01) /*
*/ booktabs label collabels(none) gaps nomtitles  /*
*/ stats(r2_a N N_clust, fmt(3 0 0) labels("Adjusted R-Squared" "Observations" "Clusters"))/*
	*/ indicate("Housing Characteristics = stories" "Block Group FE = zz_bgroup4" ///
	"Average Parcel Characteristics = samplemean_*" "ACS Demographics = Sixtyfive_up") ///
	prehead("\begin{table}[htbp]\centering" ///
		"\begin{adjustbox}{width=.5\textwidth, center}" ///
		"\begin{threeparttable}" ///
		"\caption{Regressing the Log Sale Price on the Log Fair Market Valuation}" ///
		"\begin{tabular}{l*{5}{c}}" ///
		"\toprule") ///
 postfoot("\bottomrule" ///
"\multicolumn{6}{l}{\footnotesize \sym{*} \(p<.1\), \sym{**} \(p<.05\), \sym{***} \(p<.01\)}\\" ///
"\end{tabular}" ///
 "\end{threeparttable}" ///
 "\end{adjustbox}" ///
 "\end{table}") replace  
estimates clear 

*******************************************************************************
*DATA VISUALIZATION
*******************************************************************************
tempfile m3 
use "$path/merged_data.dta", clear 
keep if saledesc == 129 | saledesc == 119
keep if sale_restrict ==1
keep if saleyear >= 2010

reg sp fmt i.ncode, noconstant robust cluster(municode) 
eststo reg1
esttab reg1 using "$vsl\ncode_coef.csv", replace drop(fmt) nostar label /*
*/ cells(b(fmt(3)))

preserve
import delimited "$vsl\ncode_coef.csv", encoding(ISO-8859-9) clear 
foreach x in v1 v2{
	replace `x'=subinstr(`x', "=", "",.) 
	replace `x' = subinstr(`x', char(34), "", .)
	replace `x'= subinstr(`x',`""""', "",.)
   }
drop if v1==""
drop if strpos(v1, "ser")

destring v2, replace 

ren v1 neighcode
ren v2 coef

sort neighcode
save `m3', replace
restore 

keep neighcode geo_id_blo
ren geo_id_blo GEOID10

sort neighcode 
merge m:1 neighcode using `m3'
drop _m

export delimited using "$vsl/ncode_coef.csv", replace


