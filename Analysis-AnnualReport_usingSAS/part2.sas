libname stocks "C:\Users\srija\OneDrive\Desktop\New folder";

data MyCompany;
set stocks.AnnualReports;
format InfoAvailDate YYMMDD10.;
where  sector="Public Utilitie" and Industry="Power Generation";
FiscalYearDate=datepart(IndFinancialYearEnd);
FiscalYear=Year(FiscalYearDate);
InfoAvailDate=input(IndDatePrelimLoaded,YYMMDD10.);
run;

Proc SORT data = MyCompany NODUPKEY;
   BY SYMBOL IndFinancialYearEnd;
RUN;

*Calculating ROI;
Data Report2009;
   SET MyCompany (keep=FiscalYear EBIT BSTotalCurrentLiabilities BSLTDebt BSMinorIntLiab BSPrefStockEq BSCash BSNetFixedAss BSWC symbol InfoAvailDate BSSharesOutCommon);
   WHERE FiscalYear=2009;
   ReturnOnCapital=EBIT/(BSNetFixedAss+BSWC);
   RUN;

   proc rank data= Report2009 out=Report2009ROC descending;
   var ReturnOnCapital;
   ranks RankROC;
   run;

   *Determine Earnings Yield for cut-off year;
   data GetPrices;
   merge Report2009ROC (in=OnBase)
         stocks.pricesrevised (in=OnPrices rename=(tic=symbol) keep=tic date close adjclose)
		 ;
	by symbol;
	if OnBase and date=InfoAvailDate;
	run;

	proc freq data=GetPrices;
	tables symbol;
	title "GetPrices";
	run;
	title;
data GetPrices2;
   merge Report2009ROC (in=OnBase)
         stocks.pricesrevised (in=OnPrices rename=(tic=symbol) keep=tic date close adjclose)
		 ;
	by symbol;
	if OnBase and InfoAvailDate<=date<=InfoAvailDate+5;
	run;
	proc freq data=GetPrices2;
	tables symbol;
	title "GetPrices2";
	run;
	title;
	data GetPricesFirst;
	set GetPrices2;
	by symbol date;
	if first.symbol;
	run;

	data EarningsYield;
	set GetPricesFirst;
	MarketCap=close*BSSharesOutCommon;
	EarningsYield= EBIT/ (MarketCap+BSTotalCurrentLiabilities+BSLTDebt+BSMinorIntLiab+BSPrefStockEq-BSCash);
	run;
proc rank data=EarningsYield out=EYAndROCRank descending;
var EarningsYield;
ranks RankEY;
run;
proc plot data=EYAndROCRank;
plot RankEY*RankROC=' ' $symbol;
run;
quit;

data AvgRank;
set EYAndROCRank;
AvgRank=(RankEY+RankROC)/2;
run;
data MyCompaniesOneYearLater(keep=symbol FiscalYear InfoAvailDate);
set stocks.AnnualReports;
format InfoAvailDate YYMMDD10.;
where  sector="Public Utilitie" and Industry="Power Generation";
FiscalYearDate=datepart(IndFinancialYearEnd);
FiscalYear=Year(FiscalYearDate);
InfoAvailDate=input(IndDatePrelimLoaded,YYMMDD10.);
if FiscalYear = 2010;
run;


data OneyearLaterWithPrice;
merge MyCompaniesOneYearLater (in=OnCompanies)
      stocks.pricesrevised (in=OnPrices rename=(tic=symbol adjclose=LaterAdjClose) keep=tic date close adjclose)
	  ;
	  by symbol;
	  if InfoAvailDate-5<=date<=InfoAvailDate-1;
	  run;
	  data PriceBeforeNextReport;
	  set OneyearLaterWithPrice;
	  by symbol date;
	  if last.symbol;
	  run;
data EvalBeforeNextReport;
merge AvgRank (in=OnBase)
      PriceBeforeNextReport(in=OnNext)
	   ;
by symbol;
if OnBase;
return=(LaterAdjClose-AdjClose)/AdjClose;
run;

proc plot data=EvalBeforeNextReport;
plot return*AvgRank=' '$symbol;
run;
quit;

data MuchLaterPrice (keep=tic adjclose rename=(tic=symbol adjclose=adjclose2014));
set stocks.pricesrevised;
if date="02Jan2014"d;
run;

data LaterReturn;
merge EvalBeforeNextReport (in=OnBase)
      MuchLaterPrice (in=OnLater);
by symbol;
if OnBase;
return2014=(adjclose2014-AdjClose)/AdjClose;
run;

proc plot data=LaterReturn;
plot return2014*AvgRank=' ' $symbol;
run;
quit;

proc reg data=LaterReturn;
model return2014=AvgRank;
run;

proc reg data=LaterReturn;
model return=AvgRank;
run;
quit;
