libname stocks "C:\Users\srija\OneDrive\Desktop\New folder";
proc contents data=stocks.annualreports varnum;
run;
proc freq data=stocks.annualreports;
table IndFinancialYearEnd;
run;
data work.annualreports;
set stocks.annualreports;
FiscalYearDate=datepart(IndFinancialYearEnd);
FiscalYear=Year(FiscalYearDate);
run;
proc freq data=work.annualreports;
table FiscalYear;
run;
data work.No2014;
set work.annualreports;
if FiscalYearDate<"01Jan2014"d;
run;
proc freq data=work.No2014;
tables FiscalYear;
run;
proc freq data=No2014;
tables sector*industry/list missing missprint;
run;
data MyCompanies;
set work.no2014; 
if sector="Public Utilitie" and Industry="Power Generation";
run;
proc freq data=Mycompanies order=freq;
title "Number of annual reports recorded by Name";
tables name;
run;
title;
proc sort nodupkey data=MyCompanies;
by name fiscalyear;
run;

data MyCompanies;
set MyCompanies;
NameCompressed=compress(name, " .()-,");
run;
proc freq data=MyCompanies order=freq;
tables Symbol*NameCompressed/list out=CompanuCounts;
run;
proc sort data=CompanuCounts;
by descending Count Symbol;
run;
data fourCompaniez;
set Companucounts(obs=4);
run;
/*dirt in data scana corporation*/

data WithBinaries;
set mycompanies;
if namecompressed ="AlleteInc" then AlleteInc=1;
                              else AlleteInc=0;
if namecompressed ="AlliantEnergyCorporation" then AlliantEnergyCorporation=1;
                              else AlliantEnergyCorporation=0;
if namecompressed ="AvistaCorporation" then AvistaCorporation=1;
                              else AvistaCorporation=0;
if namecompressed ="DukeEnergyCorporation" then DukeEnergyCorporation=1;
                              else DukeEnergyCorporation=0;
run;
proc freq data=withbinaries order=freq;
tables name*AlleteInc*AlliantEnergyCorporation*AvistaCorporation*DukeEnergyCorporation/  list nopercent nocum missing missprint;
run;

data ForAnova;
set withbinaries;
if AlleteInc=1 or AlliantEnergyCorporation=1 or AvistaCorporation=1 or DukeEnergyCorporation=1;
run;
data Convertmetric;
set Foranova;
NetPMtoInd=input(NetProfitMarginToIndustry,8.);
run;
proc means data=Convertmetric ;
class symbol;
var NetPMtoInd;
run;
proc anova data=Convertmetric;
class symbol;
model NetPMtoInd=symbol;
means symbol/snk;
run;
quit;


/*My project*/
proc sort nodupkey data=MyCompanies;
by symbol;
run;

data work.OptionsFile;
set stocks.OptionsFile (rename=(underlying=symbol));
if "01Apr2014"d<=expdate<="31Jan2016"d;
run;

proc sort data = OptionsFile;
by symbol expdate strike;
run;
data MyOptions;
merge MyCompanies(in=OnCompanies keep=symbol)
      work.OptionsFile(in=OnOptions)
	  ;
by symbol;
if OnCompanies and OnOptions;
run;

proc freq data=MyOptions;
table symbol;
run;

proc means data=MyOptions;
class Symbol type;
var strike;
run;
proc summary data=Myoptions nway;
class symbol type;
var strike;
output out=OptionStrikes mean=;
run;

/*Dividend yield*/
data work.prices;
set stocks.pricesrevised;
year=year(date);
run;

proc means data=work.prices n nmiss min;
class year;
var date;
run;

proc means data=work.prices nway;
class year;
var date;
output out= FirstTradingDayPerYear min=;
run;
proc print data=FirstTradingDayPerYear;
run;
data MyFirstTradingDay;
set stocks.pricesrevised;
if date="03Jan2012"d;
run;
proc sort data= MyFirstTradingDay;
by tic;
run;
data MyPriceFirstTradingDay;
merge MyCompanies(in=OnCompanies keep=symbol)
      MyFirstTradingDay (in=OnPrices rename=(tic=symbol))
	  ;
by symbol;
if OnCompanies and OnPrices;
run;

data work.DivFile;
set stocks.DivFile;
Where Date ge "03Jan2012"d;
rename tic=symbol;
run;

data MyDividends;
merge MyPriceFirstTradingDay (in=OnPrice)
      DivFile                 (in=OnDiv)
	  ;
by    symbol;
if   OnPrice and OnDiv;
run;

proc summary data=MyDividends nway;
class symbol adjclose;
var DivAmount;
output out=Divsum sum=;
run;

data DivCalc;
format DivYield percent8.1;
set Divsum;
DivYield=DivAmount/AdjClose;
run;

*Determine the min and max split amounts;;
data work.splits(drop=date rename=(splitdate=date));
set stocks.splits;
SplitDate=input(date,YYMMDD10.);
format SplitDate YYMMDD10.;
rename tic=symbol;
run;
data MySplits;
merge MyCompanies(in=OnCompanies keep=symbol)
      Splits(in=OnSplits )
	  ;
by symbol;
if OnCompanies and OnSplits and date ge "02Jan1990"d;
   run;
proc means data=Mysplits max min;
class symbol;
var split;
run;
proc summary data=MySplits nway;
class symbol;
var split;
output out=SplitMinMax(drop=_type_) min=SplitMin max=SplitMax;
run;

data OnePerSymbolStart;
merge MyCompanies(in=OnBase keep=symbol)
      SplitMinMax(in=OnSplits)
	  DivCalc(in=OnDiv)
	  ;
by symbol;
if OnBase;
run;
option nolabel;
proc freq data=MyOptions;
table symbol /out=OptionsCount (drop=Percent rename=(count=OptionsCount));
run;
options label;
proc transpose data= OptionStrikes (drop=_type_ _freq_)
               out=OptionsTransposed Prefix=StrikePrice_;
		by symbol;id type;var strike;
run;

options nolabel;
data OnePerSymbolRound2;
merge MyCompanies (in=OnBase keep=symbol)
      SplitMinMax (in=OnSplits drop= rename=(_freq_=SplitCount))
	  Divcalc     (in=OnDiv drop=_type_ _freq_ adjclose)
	  OptionsCount(in=OnOptions)
	  Optionstransposed (in=OptionsPrices drop=_NAME_)
	  ;
by symbol;
if OnBase;
run;
options label;

data OnePerSymbolNoBlanks;
set OnePerSymbolRound2;
format StrikePrice_C StrikePrice_p 8.2;
array numbervars _numeric_;
do over numbervars;
   if numbervars=. then numbervars=0;
end;
run;
data OnePerSymbolNoBlanks;
set OnePerSymbolRound2;
format StrikePrice_C StrikePrice_p 8.2;
array BlankToZero SplitCount DivYield DivAmount OptionsCount;
do over BlankToZero;
   if BlankToZero=. then BlankToZero=0;
end;
run;


