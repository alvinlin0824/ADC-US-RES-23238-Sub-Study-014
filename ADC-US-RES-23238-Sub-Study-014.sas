/*Upload Data*/
/*filename dir pipe "dir /b/l/s  ""\\oneabbott.com\dept\ADC\Technical_OPS\Clinical_Affairs\CDM_23238\004\UUU\004UUUFIN_L2\*.csv""";*/
/*filename dir pipe "dir /b/l/s  ""\\oneabbott.com\dept\ADC\Technical_OPS\Clinical_Affairs\CDM_23238\004\UUU\004UUUFIN_L2\ApolADC0080000000_L2L_231020_110659\*.csv""";*/
/*filename dir pipe "dir /b/s  ""C:\Project\ADC-US-RES-23238-Sub-Study-014\Output_2024-04-23-15-56\outputs\*.csv""";*/
/*filename dir1 pipe "dir /b/s  ""\\oneabbott.com\dept\ADC\Technical_OPS\Clinical_Affairs\CDM_23238\014\AUU\*freestyle.csv""";*/
libname out "\\oneabbott.com\dept\ADC\Technical_OPS\Clinical_Affairs\Clinical Study Files\Sensor Systems\ADC-US-RES-23238_InHouse Sensor\Statistics\Programs\Outputs\SE014\AL";
/*data list;*/
/*	infile dir truncover;*/
/*	input path $256.;*/
/*    if find(path,"ADC","i") then do; */
/*		/*	Extract Subject ID*/*/
/*		subject = substr(path,find(path,"L3_ADC","i")+6,4);*/
/*		/*	Extract Condition ID*/*/
/*		condition_id = upcase(substr(path,find(path,"L3_ADC","i")+11,3));*/
/*	end;*/
/*run;*/

/*data list1;*/
/*	infile dir1 truncover;*/
/*	input path $256.;*/
/*    if find(path,"ADC","i") then do; */
/*		/*	Extract Subject ID*/*/
/*		subject = substr(path,prxmatch("/(ApolADC|Apol014)/i",Path)+7,4);*/
/*		/*	Extract Condition ID*/*/
/*		condition_id = substr(path,prxmatch("/Apol/i",Path)+18,3);*/
/*	end;*/
/*run;*/
/**/
/*data events_list anaplus_list freestyle_list;*/
/*	set list list1;*/
/*	if find(path,"events.csv","i") and ^find(path,"Archive","i") then output events_list;*/
/*    if find(path,"anaPlus.csv","i") and ^find(path,"Archive","i") and ^find(path,"LifeCountTimeStamp","i") then output anaplus_list;*/
/*	if find(path,"freestyle.csv","i") and find(path,"Apol","i") and ^find(path,"Archive","i") then output freestyle_list;*/
/*run;*/

/*Loop events.csv Data*/
/*data events;*/
/*	set events_list;*/
/*	infile dummy filevar = path length = reclen end = done missover dlm='2C'x dsd firstobs=4;*/
/*	do while(not done);*/
/*	    filename = substr(path,find(path,"L3_ADC","i"),35);*/
/*		input uid: $char256. date: yymmdd10. time:time8. type: $char56. col_4: $char3. col_5: $char11. col_6: $char4. col_7: best8. col_8: $char9. */
/* snr: $char11.;*/
/*        format date date9. time time8.;*/
/*		drop uid col_4-col_8;*/
/*        output;*/
/*	end;*/
/*run;*/

/*Multiple Sensor Start*/
/*data events_start;*/
/*	set events (where = (type ="SENSOR_STARTED (58)"));*/
/*run;*/

/*Loop anaplus.csv Data*/
/*data anaplus;*/
/*	set anaplus_list;*/
/*	infile dummy filevar = path length = reclen end = done missover dlm='2C'x dsd firstobs=4;*/
/*	do while(not done);*/
/*	    filename = substr(path,find(path,"L3_ADC","i"),35);*/
/*		input uid: $char16. date: yymmdd10. time: time8. type: $char56. gl: best8. st: best8. tr: best1. nonact: best1.;*/
/*        format date date9. time time8.;*/
/*		drop uid st--nonact;*/
/*        output;*/
/*	end;*/
/*run;*/

/*stack*/
/*data auu;*/
/*set events_start anaplus;*/
/*format dtm datetime16.;*/
/*dtm = dhms(date,0,0,time);*/
/*run;*/

/*Sort by dtm*/
/*proc sort data = auu; */
/*by subject condition_id dtm;*/
/*run;*/

/*Fill the sensor serial number*/
/*data out.auu;*/
/*set auu;*/
/*/*Pseudo snr column*/*/
/*retain _snr snr_start;*/
/*if ^missing(snr) then do; */
/*_snr = snr;*/
/*snr_start = dtm; */
/*end;*/
/*else do; */
/*snr = _snr; */
/*end;*/
/*drop _snr date time filename;*/
/*format snr_start datetime16.;*/
/*run;*/

/*Loop freestyle.csv Data*/
/*data bg;*/
/*	set freestyle_list;*/
/*	infile dummy filevar = path length = reclen end = done missover dlm='2C'x dsd firstobs=4;*/
/*	do while(not done);*/
/*		input uid: $char16. date: yymmdd10. time: time8. bg: best8. st: best1.;*/
/*        format date date9. time time8.;*/
/*		drop uid condition_id;*/
/*        output;*/
/*	end;*/
/*run;*/

/*Remove Duplicated uploads*/
/*proc sort data = bg NODUP out = out.bg;*/
/*where st = 0;*/
/*by _all_;*/
/*run;

data auu;
set out.auu;
run;

data curr_auu;
set auu(where = (gl between 40 and 400 and type = "906"));
et = (dtm - snr_start)/3600;
run;

data bg;
set out.bg(where = (bg between 20 and 500));
format fs_dtm datetime16.;
fs_dtm = dhms(date,0,0,time);
drop date time;
run;

/*Pair BG and Sensor Data*/
proc sql;
 create table curr_paired_bg as
 select a.*, b.*
 from curr_auu a, bg b
 where a.subject=b.subject and a.dtm-300<=b.fs_dtm<=a.dtm+300
 group by b.subject, fs_dtm
 order by b.subject, fs_dtm;
quit;

data curr_paired_bg1;
 set curr_paired_bg;
 abstimediff=abs(dtm-fs_dtm);
run;

proc sort data=curr_paired_bg1; by subject condition_id snr fs_dtm abstimediff bg descending dtm; run;

data curr_paired_bg2;
 set curr_paired_bg1;
 by subject condition_id snr fs_dtm abstimediff bg descending dtm;
 if first.fs_dtm; *Choose pair that is closest in time when BG paired with multiple GM;
run;

proc sort data = curr_paired_bg2; by subject condition_id snr dtm abstimediff fs_dtm; run;

data curr_paired;
 set curr_paired_bg2;
 by subject condition_id snr dtm abstimediff fs_dtm;
 if first.dtm; *Choose pair that is closest in time when GM paired with multiple BG;
 s_immediate = gl/bg;
 drop abstimediff;
run;

/*Get median based on eTime between 11 hours and 121 hours*/
proc means data = curr_paired median noprint nway;
class subject condition_id snr;
where et between 11 and 121;
var s_immediate;
output out = esa_median(drop = _TYPE_ _FREQ_) median = s_median N = n;
run;

proc sort data = esa_median; by subject condition_id snr; run;
proc sort data = curr_paired; by subject condition_id snr; run;

/*Left Join esa with esa_median to get interpolate data*/
data esa_snorm;
merge curr_paired(in = x) esa_median(in = y);
by subject condition_id snr;
if x;
s_norm = s_immediate/s_median;
/*Filter first 8 hours */
if 1 <= et <= 9;
/*Remove missing values for s_norm*/
if s_norm ^= .;
run;

/*Trapezoidal numerical integration*/
data esa_area;
set esa_snorm;
by subject condition_id snr;
lag_et = lag(et);
lag_s_norm = lag(s_norm);
if first.snr then do; 
lag_et = 0;
lag_s_norm = 0;
end;
/*Calculate the trapzoid area*/
if first.snr then area = 0;
else area + (et - lag_et) * (s_norm + lag_s_norm - 2) / 2;
if last.snr;
/*Only sum up the area when s_normlnterp < 1*/
where s_norm < 1;
keep subject condition_id snr n s_median area;
run;

proc sort data = auu NODUPKEY out = auu_nodup(keep=subject condition_id snr); by subject condition_id snr; run; 
proc sort data = esa_median; by subject condition_id snr;run;

/*Left Join to get complete data*/
data esa_index;
retain subject condition_id snr s_median n area Category;
format Category $10.;
merge auu_nodup(in = x) esa_median(in = y) esa_area(in = z);
by subject condition_id snr;
if x;
/*Assign ESA Classification*/
if area = . then Category = "5.NaN";
else if  -1 < area <= 0 then Category = "4.None";
else if -2 < area <= -1 then Category = "3.Minor";
else if -3 < area <= -2 then Category = "2.Moderate";
else if area <= -3 then Category = "1.Severe";
/*Extract Lot*/
Lot = substr(condition_id,3,1);
run;

proc format;
value $category
	  "1.Severe" = "Severe"
      "2.Moderate" = "Moderate"
      "3.Minor" = "Minor"
	  "4.None" = "None"
	  "5.NaN" = "NaN";
run;

proc sort data = esa_index out = esa_index1(where = (Category ^= "5.NaN")) ; by Lot area;
run;

data index count(keep = Lot RowNo rename = (RowNo = Count));
set esa_index1;
by Lot;
if first.Lot then RowNo = 1;
else RowNo + 1;
output index;
if last.lot then output count;
run;

data esa_plot;
merge index(in=x) count(in = y);
by Lot;
if x ;
percent_of_sensor = RowNo/Count;
run;

options papersize=a3 orientation=portrait;
ods rtf file="C:\Project\ADC-US-RES-23238-Sub-Study-014\ADC-US-RES-23238-Sub-Study-014-%trim(%sysfunc(today(),yymmddn8.)).rtf" startpage=no;

proc freq data = esa_index;
tables Lot*Category/nocum NOCOL nopercent;
format Category $category.;
run;

proc sgplot data = esa_plot noautolegend cycleattrs;
styleattrs datacontrastcolors=(magenta green blue orange);
	series x = percent_of_sensor y = area / group = Lot groupdisplay=overlay markers markerattrs=(size=5 symbol=dot);
    yaxis label="ESA Area 8hrs" reverse  values = (-5 to 0 by 0.5);
	xaxis label="% of Sensors" ;
	keylegend / title="Lot" ;
run;

proc print data = esa_index(drop = Lot) noobs label;
label subject = "Subject"
      condition_id = "Condition ID"
	  snr = "Sensor Serial Number"
	  s_median = "Median Sensitivity";
format Category $category.;
run;

ODS RTF CLOSE;