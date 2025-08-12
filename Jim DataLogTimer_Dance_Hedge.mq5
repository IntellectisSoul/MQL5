//+-------------------------------------------------------------------+
//|                                     Jim DataLogTimer_Dance_v3.mq5 |
//|                                       Copyright 2025, Jim S.Lim   |
//+-------------------------------------------------------------------+
// The resulting CSV Data file requires post-processing. I use Power Automate Desktop flow 'Jim MQL5 PostProcess SplitCSV'

//v82.4 : Fully Working! DO NOT OVERWRITE OR DELETE!
//SETUP of CHART & INDICATORS : BB(11), RVI(10); DeMark(13), Frama(11), ATR(10)

/*------------------------------------------------------------------------------------------------------+
   change log
   18.June.2025 : update to isTREND_Up / Down
   30.May.2025 : refined isTREND_Up/Down; included isReverse_BB2deltaR_Up and isReverse_TotalScoreBinaryUp 
   8.May.2025 : fixing .mqh dependencies...
   29.April.2025 : updated PriceChangeAnalyze_Timediff for detectShift_Reverse() calculation related to BBgap_Volatility; updated isReverse_DeMUp/DeMDown, isTrend_DeMUp;  Dem_ShiftResult
   5.April.2025 : Fine-tuned FractStoch by adding lastfractal5Type.
   28.March.2025 : adjusted CalculateBarCount() to consider bar Price Open as well. both must be either above or below Framaline
   26.March.2025 : fixed DeMProc.
   24.March.2025 : added Include Jim isREVERSE.mq5
   23.March.2025 : isRevese_Frama updated with shiftReverse
   20.March.2025 : isREVERSE added.
   18.March.2025 : fixed some compile warnings and order precedences.
   17.March.2025 : removed DeM5Angle_shiftCrossReverse and consolidated into DeM_shiftReverse
   11.March.2025 : misc. updates; added lastFractalType to all Execs
   26.Feb.2025 : updated isReverse_PriceIndexUp
   25.Feb.2025 : added DeM_shiftTrend to isReverse_DeMdelta
   24.Feb.2025 : adjustments to isReverse_DeMUp; new isaddScalp_FractDeMUp, added to addScalp; added DeM5Angle_shiftCrossReverse.
   18.Feb.2025 : adusted addScalp, BBAngle_shiftCrossReverse, 
   14.Feb.2025 : misc
   13.Feb.2025 : followed adjustments from Dancev3.1
   11.Feb. : added Fractal to Pbar
   7.Feb. : adjusted isReverse_BBUp; isRange_BB and isTrend_BB, isTrend_Frama, isRange_Frama was named incorrectly during FileWrite.
   17.Jan.2025 : added midBB, midBB5. renamed isBBTrending to isTrend_BB, as well as to isBBRanging to isRange_BB; seems  gTailScore can be removed substituted with finalTailScore
   8.Jan.2025 : added HighLowTailDiff
   31.Dec.2024 : writing to CSV correctly now without need for post-processing.
   27.Dec.2024 : adjusted according to DAnce_v1; global variable cannot be reduced
   19.Dec.2024 : adjustments to PriceChangeAnalze...fixed barCount
   18.Dec.2024 : introduced isReverse_FramaUp,  isReverse_FramaDown, isReverse_BBUp and isReverse_BBDown.

   14.Dec.2024 : added RANGE and TREND Open Trades; removed the BuyMarket(), SellMarket() temporarily to enable actual trading Logs.
   13.Dec.2024 : GetPositionDetails() can now update gLotSize; Deleted all alert Functions from old EA without reviewing what they are doing. To review them again later
               : Created a new include class file for 'Jim Trade_Defense.mq5 with 5 Defense functions (MathGPT)
   12.Dec.2024 : partial cleanup of global variables into local to save memory.
   29.Nov.2024 : added gbarPricedelta and ATRCurrent adjusted to be universal %.
   27.Nov.2024 : misc. fix on variables (static declaration removed at global level) and initialization to 0.
   22.Nov.2024 : incorporated include file Jim Count_continuousBars.mq5 in OnInit() to countBars at initialization;
   11.Nov.2024 : updated barCount variable to local_barCount in countBarsBasedOnFrama(). previously was counting incorrectly.
   6.Nov.2024 : added FramaAngle
   30.Oct.2024 : this uses arrays instead of passing many and changeable arguments into the function. it is easier and more efficient for code maintenance. however it writes the entire row into a single cell.
            : this requires post-processing with Power Automate.
            : converted all char types to int to reduce errors.
            : added FramaPriceIndex
            : added Continous TREND barCount every 15 min. 
   23.Oct.2024 : Added Stochastic
   18.Oct.2024 : renamed 'Framadelta' to Framadelta to reflect more accurately. 

 
*/
#include "Jim AccelerationCheckSignal.mqh"
#include "Jim ATRCheckSignal.mqh"
#include "Jim barCount.mqh"
#include "Jim BBCheckSignal.mqh"
#include "Jim BBgap-Universal.mqh"
//#include "Jim_DeltaToAngle.mqh" //calculate angle in degrees from delta change.
#include "Jim DeMCheckSignal.mqh"
#include "Jim Dynamic_Date.mqh" //this dynamically generates the filename with today's date'
#include "Jim Fractal.mqh"
#include "Jim FractalDataLookBack.mqh"
#include "Jim FRAMACheckSignal.mqh"
#include "Jim PriceChangeAnalyze_Timediff_v2.mqh" //
#include "Jim isREVERSE.mqh"
#include "Jim RVI_CheckSignal.mqh"
#include "Jim Stochastics.mqh"
#include "Jim TotalScore.mqh"
//#include "Jim SharedStructs.mqh"

//#include "Jim Trade_Defense.mqh"
//#include "Jim TradeMonitor_MathGPT.mqh"
#include "\Mql5Book\Price.mqh"


//0000000000000000000000000000000000000000000000000000000
//#include "Jim DXYCheckSignal1.mq5"
//initialize Objects
   CBars CPrice;  //create object CPrice type with CBars class
   UniversalBBgap bbgapCalculator;
   SimplePriceAnalyzer Simple_analyzer;//create instance object analyzer type with PriceAnalyzer class
   FractalAnalyzer *fractalAnalyzer;
 //===============================
 //Define global variables
int handle_iBands_StdDev1_M5;
int handle_iBands_StdDev2_M5;
int handle_iBands_StdDev1_M15;
int handle_iBands_StdDev2_M15;
 
string gsymbol = _Symbol;
 datetime lastArrayUpdate = 0;     // Stores the last time we updated the array (used in DeMdelta_Array)
 
string fileName = "";
int gfhandle =0;

double gaskPrice =0;
double gCurrentPrice =0;
double gPriceNormalized =0;


int gfractal5Type =0;
int gfractalType =0;
double glastFractal5_HighLow_Price =0; //used in Fractal

// BB Indicator Handles
int handle_iBands_StdDev1 = INVALID_HANDLE;
int handle_iBands_StdDev2 = INVALID_HANDLE;

int gBB5_Proc =0;
int gBB_Proc =0;
double gtopBB1 =0;
double gbotBB1 =0;


double gtopBB2 =0;

double gbotBB2 =0;
double gBBgap5 =0;
double gBBgap =0;
double gmidBBdelta =0;
//double gBBgapToPrice;
double gBBgapPriceRatio =0;
double gtopBB2Angle =0;
double gbotBB2Angle =0;

double gmidBBframadelta_Vector =0;

 //double gFraRVILineadelta_TimeDiff =0;

double gmidBBframadelta_V_TimeDiff =0;
/*
 double gBBgapPriceRatio_TimeDiff;
 double gBBgapRldr_unitPr_TimeDiff;
 double gBBgapRldr_Pr_TimeDiff;
 double gBBgap_Volatility_Adjustment_TimeDiff;
//double gFradelta_BBgap_Expansion;
 double gBBgap_PriceRatio_TimeDiff;
 double gtopBB2delta_TimeDiff;
*/
double gDeMCurrentPrice =0;
int gDeM5Score =0;
int gDeMScore =0;
double gDeM5delta =0;
double gDeMdelta =0;
string gDeM5Proc ="";
string gDeMProc ="";
//string gDXYDeMProc="";
double DeM5Angle =0;
double DeMAngle =0;

double gDeM5CurrentPrice =0;

double gFraRVILine_Adelta =0;
 
double gFraDeMdelta =0; 

double gFramaCurrentPrice =0;
 double gFrama5delta =0;

int gFramaScore =0;

double  gFramadelta =0;
double gBBFrdeltaRatio =0;
 double gBBFrdeltaRatio_TimeDiff =0;

double gATRCurrent =0;
int gATRScore =0;

double gRVILine_Adelta =0;
int gRVIScore =0;

/*
string gDXYBBConvDivergence;
double gDXY_midBB;
double gDXY_midBBdelta;
double gDXY_topBB1Top;
double gDXY_topBB1Bot;
double gDXY_botBB1Top;
double gDXY_botBB1Bot;
double gDXY_topBB2previous;
double gDXY_botBB2previous;
*/
/*
int gDXYFramaScore;
int gDXYDeMScore;
int gDXYRVIScore;
int gDXYATRScore;
double gDXYDeMCurrentPrice;

string gDXYATRStrength;
*/
string gProclivity ="";
//double gDXYFramaCurrentPrice =0;

//int gDXYFrama_PricePos =0;

//double gDXY_DeMCurrentPrice =0;   


double gBBgap_PriceRatio =0;
double gNoOfSegments =0;
double gBBgap5_Expansion =0;
double gBBgap_Expansion =0;



 char shortPosition =0;
 char longPosition =0;
double gTotalScore =0;
double TotalScoreBinary =0;
bool isTotalScoreBinary_Up =false;
bool isTotalScoreBinary_Down =false;

double gBBgap5_Volatility_delta =0;
double gBBgap_Volatility_delta =0;



char gmidBBTREND =0;
string gBBConvDivergence_Prev="";

double gATRPriceRatio =0;
double gATRdelta =0;

double gPricedelta =0;
double gtopBB2delta =0;
double gbotBB2delta =0;

double gBB2deltaR =0;
//double gBB2deltaR_TimeDiff =0;

double gP2bar5Close =0;

double gPbarHeight =0;
double gPbarEntryHigh =0;
double gPbarEntryLow =0;

//double gFraDeMdelta_TimeDiff =0;
//double gFraRVILine_Adelta_TimeDiff =0;

double gFradelta_gBBgap_Expansion =0;


 char gTailScore =0;

   string gRVIproc=""; string gRVI5proc="";
   double gRVILine5_Adelta =0; 
   
   double gRVI5Line_A =0;
   double gRVILine_A =0;
   char gcount_WaveUp =0;
   char gcount_WaveDown =0;
   double gWaveH =0;
   double gWaveL =0;
   
double gmidBB =0;  
double midBB5 =0;


double gsegmentSize =0; //this replaced ladderUnitP
int gPrice5Index =0; //this is originating from BBChecksignal
int gPriceIndex =0; //this is originating from BBChecksignal

// Declare and initialize the Stochastics object globally
Stochastics stoch5; //5-min Period
Stochastics stoch;  // Declare stoch as object class of Stochastics globally so it can be used as an instance. then initialize inside OnInit()
   double gStoch_level =0.0; 
     int gStoch5Score =0; 
   int gStochScore =0; 
   string gStoch5Xover = "";
   string gStochXover = ""; //crossover signal
   bool AlertTriggered =false;  // Prevent multiple alerts for the same signal for stoch crossing.

int Frama5Index =0;
int FramaIndex =0;  

  //Reversals
   bool isReverse_BB2deltaR_Up =false;
   bool isReverse_TotalScoreBinaryUp =false;
   bool isReverse_BB2deltaR_Down =false;
   bool isReverse_TotalScoreBinaryDown =false;

 char gPbarCross =0;
    char gPbar5Cross =0;
    char gP2bar5Cross =0;
    char gP2barCross =0;
    
   double gP2barMid =0;
   double gPbarHigh =0;
   double gPbarLow =0; 
   double gPbarMid =0;

string valueParams[] ;
string headerParams[];

int barCount=0;


double BBTopBot_Frama_delta_Vector =0;


   //comparing FramaAngle to its previous bars. 
   double gFrama5Angle =0;
   double gFramaAngle =0;
   double gFrama5Angle_Long =0;  
   
//Fractal
   static int lastFractalType = 0;  // To store the last known fractal type
   static int lastFractal5Type = 0;  // To store the last known fractal type

   
 // Check if a new bar has been formed
          //bool StochAlertTriggered =false;  // Prevent multiple alerts for the same signal for stoch crossing. Reset the variable on a new bar Print("New bar detected. AlertTriggered reset to false."); }
         // bool FractalAlertTriggered =false; 
         
//double BBgap_Volatility_Adjustment =0;   

   double analyzed_TailScore=0;
   int finalTailScore=0;      
   int gFrama_PricePos=0;
   
   int previousFramaPricePos=0;
   //bool flag_barCount=false;
   
   double midBB5_Angle=0;
   double midBB_Angle=0;
   

   double BBgapMetrics=0;
   
   double gbarPricedelta=0;


   double glastFractal5_High[]; //used in Fractal
   double glastFractal5_Low[];
   double glastFractal_High[]; //used in Fractal
   double glastFractal_Low[];
   
   int lastfractal_HighIndex = 0;
   int lastfractal_LowIndex = 0;
   double fractalHigh5_delta = 0.0;
   double fractalLow5_delta = 0.0;
   double fractalHigh_delta = 0.0;
   double fractalLow_delta = 0.0;
   


   double shift = 0.0; 


bool isRANGE=false;
bool isRange_BB =false;
bool isRange_Frama =false;
bool isTrend_Frama =false;
bool isReverse_BBUp =false;
bool isReverse_BBDown =false;


bool isReverse_FramaUp =false;
bool isReverse_FramaDown =false;

bool isaddScalp_FractDeMUp = false;
bool isaddScalp_FractDeMDown = false;   
bool isAddScalp_Up =false;
bool isAddScalp_Down =false;

bool isTrend_BBUp =false;
bool isTrend_BBDown =false;
bool isTrend_FramaUp =false;
bool isTrend_FramaDown =false;
bool isTrend_TailUp =false;
bool isTrend_TailDown =false;
bool isTrend_DeMUp =false;
bool isTrend_DeMDown =false;

bool isTREND_Up =false;
bool isTREND_Down =false;



double Frama5Angle_shiftTrend =0;
double FramaAngle_shiftTrend =0;
double BB5Angle_shiftTrend =0;
double BBAngle_shiftTrend =0;
double BBFrama_shiftTrend =0;

double BBAngle_shiftReverse =0;
double BB5Angle_shiftCrossReverse =0;
double BBAngle_shiftCrossReverse =0;

double FramaAngle_shiftReverse =0;
double FramaAngle_shiftCrossReverse =0;
double Frama5Angle_shiftCrossReverse =0;

double DeM_trendShiftResult =0;

   bool isREVERSE_Up =false;
   bool isREVERSE_Down =false;
   int upTriggerIdentifier =0;
   int downTriggerIdentifier =0;
   bool isReverse_PriceIndexUp =false;
   bool isReverse_PriceIndexDown =false;
   bool flag_lastPriceIndex =false;
   int lastPriceIndex =0; //used in isPriceReverse
   int lastPrice5Index =0;
   
   bool isReverse_FractStochUp =false;
   bool isReverse_FractStochDown =false;
   
   bool isReverse_DeMUp =false;
   bool isReverse_DeMDown =false;
   bool isReverse_BBFrdeltaRatio =false;
   bool isReverse_TailUp =false;
   bool isReverse_TailDown =false;
   
   double HighLowTailDiff=0;
   
   double HighTail=0;
   double LowTail=0;
   
//+-----------------------------------+
//Extract Datas
//+-----------------------------------+

/*+------------------------------------------------------------------+
Old code to generate filename : incomplete. this goes inside OnInit()
 datetime date = __DATE__;
//create a structure
   MqlDateTime d;
   TimeToStruct(date, d);

   int Year = d.year;
   int Month = d.mon;
   int Day = d.day;
   int DayOfWeek = d.day_of_week;

   string _date = (string)Year+ "-" + (string)Month +  "-" + (string)Day+  "-" +(string) DayOfWeek;

   fileName = "Data " + _Symbol + "-" + _date+ "Sept Week1.csv";                                                              |
+------------------------------------------------------------------+
*/
int OnInit()
  {
  string fileDescript = "Data";
    // Call the function from the included library
   fileName = GeneratefileName(fileDescript); //calls library Jim Dynamic_Date.mq5
   //Print("Generated Filename: ", fileName);
   //printf(fileName);
      
      
 
    //--- Create BBCheckSignal Indicator Handles ---
      handle_iBands_StdDev1_M5 = iBands(_Symbol, PERIOD_M5, 11, 0, 1.05, PRICE_CLOSE);
      handle_iBands_StdDev2_M5 = iBands(_Symbol, PERIOD_M5, 11, 0, 2.1, PRICE_CLOSE);
      handle_iBands_StdDev1_M15 = iBands(_Symbol, PERIOD_M15, 11, 0, 1.05, PRICE_CLOSE);
      handle_iBands_StdDev2_M15 = iBands(_Symbol, PERIOD_M15, 11, 0, 2.1, PRICE_CLOSE);
      



//--- triggers the OnTimer() with a 30 second period
   EventSetTimer(30);


//===========================================================================+
   //Initial Fractal array : lookback to retrieve previous Up and Down Fractals
   //===========================================================================+
     ArrayInitialize(glastFractal5_High, EMPTY_VALUE);
      ArrayInitialize(glastFractal5_Low, EMPTY_VALUE);
      ArrayInitialize(glastFractal_High, EMPTY_VALUE);
      ArrayInitialize(glastFractal_Low, EMPTY_VALUE);
      
      ArraySetAsSeries(glastFractal5_High, true);
      ArraySetAsSeries(glastFractal5_Low, true);
      ArraySetAsSeries(glastFractal_High, true);
      ArraySetAsSeries(glastFractal_Low, true);
   
    // Instantiate FractalAnalyzer object
    fractalAnalyzer = new FractalAnalyzer(_Symbol, PERIOD_M5);
  
   // fractalAnalyzer = new FractalAnalyzer(_Symbol, PERIOD_CURRENT);
    // Check pointer validity and initialize
    if (fractalAnalyzer != NULL) {
        fractalAnalyzer.InitializeFractals(); // Correctly call the InitializeFractals method
    } else {
        Print("Failed to initialize FractalAnalyzer.");
        return INIT_FAILED;
    }

   // Populate initial fractal arrays
   fractalAnalyzer.GetHighFractals(glastFractal5_High);
   fractalAnalyzer.GetLowFractals(glastFractal5_Low);
   
        fractalAnalyzer = new FractalAnalyzer(_Symbol, PERIOD_M15);
           if (fractalAnalyzer != NULL) {
        fractalAnalyzer.InitializeFractals(); // Correctly call the InitializeFractals method
    } else {
        Print("Failed to initialize FractalAnalyzer.");
        return INIT_FAILED;
    }
    
    // Populate initial fractal arrays
    fractalAnalyzer.GetHighFractals(glastFractal_High);
   fractalAnalyzer.GetLowFractals(glastFractal_Low);
   
   //free up memory since this object is run only once in OnInit().  
   delete fractalAnalyzer;

//---
   //==============================================+
   //Initial BarCount :
   //==============================================+
    // Define necessary variables
   int Frama_handle;
    int barsToCopy = 12;

   
// Set up FrAMA handle and retrieve the last 12 bars of FrAMA and closing prices
double framaArray[12];
Frama_handle = iFrAMA(_Symbol, PERIOD_M15, 11, 0, PRICE_CLOSE);

// Check if FrAMA handle is valid
if (Frama_handle == INVALID_HANDLE) {
    Print(_Symbol, " Error initializing FrAMA handle: ", GetLastError());
    return INIT_FAILED;
}

// Copy FrAMA values into framaArray (most recent data at index 0)
if (CopyBuffer(Frama_handle, 0, 0, barsToCopy, framaArray) <= 0) {
    Print(_Symbol, " Error copying FRAMA buffer: ", GetLastError());
    return INIT_FAILED;
}

// Main: Calculate the count of bars meeting criteria using CalculateBarCount
barCount = CalculateBarCount(_Symbol, PERIOD_M15, framaArray);

 
     //end of Initial barCount==============================
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  
     if(fractalAnalyzer != NULL) {
        delete fractalAnalyzer;
        fractalAnalyzer = NULL;
    }
          // Loop through all objects on the current chart
          int total_objects = ObjectsTotal(0); // 0 for the current chart
          for (int i = total_objects - 1; i >= 0; i--)
          {
              // Get the name of the object
              string object_name = ObjectName(0, i);
              
              // Check if the object name starts with specific patterns
              if (StringFind(object_name, "ENTRYLONG") == 0 ||
                  StringFind(object_name, "entryLONGalertswitch") == 0 ||
                  StringFind(object_name, "ENTRYSHORT") == 0 ||
                  StringFind(object_name, "entrySHORTalertswitch") == 0 ||
                  StringFind(object_name, "TriggerCase") == 0)
              {
                  // Delete the object
                  ObjectDelete(0, object_name);
              }
          }
//--- destroy the timer after completing the work
   EventKillTimer();

  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   int alertswitch =0;
 
 string alertcomment="";
  static char alertswitchPrevious=0;
  static char countPrevious=0;
  

double gCurrentOpen =0;


   // char DXYP2barCross;
//end OnTimer
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
//A. Obtain Current Price of Instrument
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+

   MqlTick SPrice; //create object SPrice type with MqlTick structure
   SymbolInfoTick(_Symbol, SPrice);
   gaskPrice = SPrice.ask;
   gCurrentPrice = SPrice.bid;
   gPriceNormalized = ((gCurrentPrice+gaskPrice)/2);
   static double PreviousPrice=0;
//char PriceDir = CheckDir (gCurrentPrice, PreviousPrice);

  
//printf("PriceDir : " + (string)PriceDir);

//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-+
//B.: BB Function. SD 1.1 & SD2.0, 11 bars.
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-+

char gbotBBDir2 =0;
//Std 1.05
double top5BB2Angle =0;
double bot5BB2Angle =0;
char midBB5TREND =0;

double midBB5Previous =0;    
double top5BB1 =0;
double top5BB1Top =0;
double top5BB1Bot =0;

double bot5BB1 =0;
double bot5BB1Top =0;
double bot5BB1Bot =0;
double top5BB2 =0;
double bot5BB2 =0;
double top5BB2previous =0;
double bot5BB2previous =0;
double midBB5delta =0;

double top5BB2delta =0;
double bot5BB2delta =0;

double BBgap5PriceRatio =0;

double gScalp_StdDev_top =0;
double gScalp_StdDev_bot =0;
double gScalp_StdDev_top2 =0;
double gScalp_StdDev_bot2 =0;

      int top5BB1Dir=0; //used in Defense
      int bot5BB1Dir=0;
      int topBB1Dir=0;
      int botBB1Dir=0;

 gBB2deltaR = gtopBB2delta /gbotBB2delta;
   double BB2deltaR_array[2]= {0,0};

      
double segment5Size =0; //this replaced ladderUnitP


     gBB5_Proc = BBCheckSignal(_Symbol, PERIOD_M5, handle_iBands_StdDev1_M5, handle_iBands_StdDev2_M5, midBB5, midBB5Previous, top5BB1, top5BB1Top, top5BB1Bot,  
       bot5BB1, bot5BB1Top, bot5BB1Bot, top5BB2,  bot5BB2, top5BB2previous, bot5BB2previous, midBB5delta,  top5BB2delta,  bot5BB2delta, gBBgap5,
       BBgap5PriceRatio, segment5Size, gBBgap5_Volatility_delta, top5BB2Angle, bot5BB2Angle, 
       gPriceNormalized, gaskPrice, gCurrentPrice, midBB5TREND, gScalp_StdDev_top, gScalp_StdDev_bot, gScalp_StdDev_top2, 
       gScalp_StdDev_bot2, gBBgap5_Expansion, gPrice5Index, midBB5_Angle, barCount,  top5BB1Dir, bot5BB1Dir);
       
    int BB5_Reverse = BB_Reverse(gBB5_Proc, gPrice5Index); //this function is calculated at the MAIN EA.
 

 double topBB1Top =0; double topBB1Bot =0;
double gtopBB2previous =0;
double gbotBB2previous =0;


double botBB1Top =0; 
double botBB1Bot =0;
double midBBPrevious =0;

char gtopBBDir2 =0;

    
   gBB_Proc = BBCheckSignal(_Symbol, PERIOD_M15, handle_iBands_StdDev1_M15, handle_iBands_StdDev2_M15, gmidBB, midBBPrevious, gtopBB1, topBB1Top, topBB1Bot,  
       gbotBB1, botBB1Top, botBB1Bot, gtopBB2,  gbotBB2, gtopBB2previous, gbotBB2previous, gmidBBdelta,  gtopBB2delta,  gbotBB2delta, gBBgap,
       gBBgapPriceRatio, gsegmentSize, gBBgap_Volatility_delta, gtopBB2Angle, gbotBB2Angle, 
       gPriceNormalized, gaskPrice, gCurrentPrice, gmidBBTREND, gScalp_StdDev_top, gScalp_StdDev_bot, gScalp_StdDev_top2, 
       gScalp_StdDev_bot2, gBBgap_Expansion, gPriceIndex, midBB_Angle, barCount, topBB1Dir, botBB1Dir);
       
     int BB_Reverse = BB_Reverse(gBB_Proc, gPriceIndex); //this function is calculated at the MAIN EA.
         
 gBB2deltaR = gtopBB2delta / gbotBB2delta;
 
 
    //store lastPriceIndex in order to use in isPriceReverse()
         if (flag_lastPriceIndex == false && (MathAbs(gPriceIndex >=4) || MathAbs(gPrice5Index <=5) ))
            {
            lastPriceIndex = gPriceIndex; 
            lastPrice5Index = gPriceIndex;
            flag_lastPriceIndex= true; 
            }
 /*
   gBBgap = gtopBB2 - gbotBB2;
   gBBgapToPrice = NormalizeDouble(gCurrentPrice/(gBBgap *100)  ,3);
         //double BBgapToPrice = BBgap / gCurrentPrice;
   gBBgapRatio = gBBgapToPrice;

   gBBgapRldr_unitPr =  gBBgapRatio/gBBgap_Expansion;
 
   double DXY_midBB;
   double DXY_midBBPrevious;
   double DXY_topBB1;
   double DXY_botBB1;


//Std. Dev. 2.0
   double DXY_topBB2;
   double DXY_botBB2;
  // double DXY_middelta;

   double DXY_BBgap;
   double DXY_BBgapPriceRatio;
   double DXY_ladderPrevious;
   double DXY_ladderCurrent;
   double DXY_BBgap_Volatility_delta;
   double DXY_BBgapRldr_unitPr;


   double DXY_topBB2Angle;
   double DXY_botBB2Angle;
   double DXY_BBgap_Volatility_Adjustment;

   double DXY_Scalp_StdDev_top;
   double  DXY_Scalp_StdDev_bot;
   double DXY_Scalp_StdDev_top2;
   double  DXY_Scalp_StdDev_bot2;

   char DXY_midBBTREND;
   double DXY_topBB2delta;
   double DXY_botBB2delta;


   gDXYBBConvDivergence = BBCheckSignal("XAUUSD", PERIOD_M15, DXY_midBB, DXY_midBBPrevious, DXY_topBB1, gDXY_topBB1Top, gDXY_topBB1Bot, 
   DXY_botBB1, gDXY_botBB1Top, gDXY_botBB1Bot,DXY_topBB2, DXY_botBB2, gDXY_topBB2previous, gDXY_botBB2previous,  gDXY_midBBdelta,  DXY_topBB2delta,  DXY_botBB2delta, 
   gcountPrevious,  DXY_BBgap, DXY_BBgapPriceRatio, DXY_ladderPrevious, DXY_ladderCurrent, DXY_BBgap_Volatility_delta, DXY_BBgapRldr_unitPr, 
   DXY_topBB2Angle,  DXY_botBB2Angle, DXY_BBgap_Volatility_Adjustment, gPriceNormalized, gaskPrice, gCurrentPrice, DXY_midBBTREND,
   DXY_Scalp_StdDev_top,DXY_Scalp_StdDev_bot, DXY_Scalp_StdDev_top2, DXY_Scalp_StdDev_bot2, gBBConvDivergence_Prev, gBBgap_Expansion);
*/

//to normalize values with the 4 "0s" digits value of USTech, DAX, and China. (Fx has no 0s)


   /*//+--------------------------------------------------------------------------------------+
   //Ladder : is snapshot BBgap. can be developed
   //+--------------------------------------------------------------------------------------+
   //for purpose of feeding value into Acceleration Fn.
   gladderUnitP=(gtopBBprevious - gbotBBprevious)/16 ; //using previous prevents from moving-target because it is fixed.
   //gladderUnitP = NormalizeDouble(gladderUnitP, _Digits);

   gladderCurrent = (gtopBB2 - gbotBB2)/16;

   gBBgap_Volatility_delta = NormalizeDouble((gladderCurrent - gladderUnitP),_Digits);
   */            
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
//C. Bar Prices
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+

gCurrentOpen  = iOpen(NULL, 0,  0);
double giLow  = iLow(NULL, 0,  0);   //calculate CurrentBar High/ Low
double giHigh  = iHigh(NULL, 0,  0);

 gPricedelta  = NormalizeDouble(((gPriceNormalized - PreviousPrice)/PreviousPrice)*10000, _Digits);
 gbarPricedelta  = NormalizeDouble(((gPriceNormalized - gCurrentOpen)/gCurrentOpen)*10000, _Digits); //price direction; this is used in analyzed_TailScore 
  
    HighTail = (giHigh - MathMax(gCurrentOpen, gPriceNormalized))/gsegmentSize;;
    LowTail = (MathMin(gCurrentOpen, gPriceNormalized) - giLow)/gsegmentSize;
    
    HighLowTailDiff = LowTail - HighTail ; //if (+) means UP?
    HighLowTailDiff = NormalizeDouble(HighLowTailDiff, 2);
    
    
   double HighLowTailDiff_Array[2] = {0,0};
   HighLowTailDiff = LowTail - HighTail ; //if (+) means UP, (-) means Down
   HighLowTailDiff = NormalizeDouble(HighLowTailDiff, 2);
    
    
    finalTailScore = Simple_analyzer.calculateTailScore(
    gbarPricedelta,
    gCurrentPrice,
    gCurrentOpen,
    HighTail,
    LowTail,
    gPricedelta// pass the delta here where it's needed
    );

   
    
 
 //DXY gPricedelta
   //  gDXYPricedelta = NormalizeDouble(CheckDXYPriceDir ( gDXYPriceNormalized, gDXYPbarHigh, gDXYPbarLow),_Digits);       //1-Min. chart
     
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
// Previous Bars  (use MqlTick to compare against previous bar)              |
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+

double gP2bar5Open =0;

   CPrice.Update(_Symbol, PERIOD_M5);
   double Pbar5Close = CPrice.bar[1].close;
   double Pbar5High = CPrice.bar[1].high;
   double Pbar5Low = CPrice.bar[1].low;
   double Pbar5Mid = (Pbar5High+Pbar5Low)/2;
   double Pbar5Open = CPrice.bar[1].open;

   CPrice.Update(_Symbol, PERIOD_M15);
   double PbarClose = CPrice.bar[1].close;
    gPbarHigh = CPrice.bar[1].high;
    gPbarLow = CPrice.bar[1].low;
    gPbarMid = (gPbarHigh+gPbarLow)/2;
   
   double PbarOpen = CPrice.bar[1].open;
   
     gPbarHeight = NormalizeDouble(((gPbarHigh - gPbarLow) / gsegmentSize), 2); //in order to universalize the value.
     gPbarEntryLow = NormalizeDouble(((gPbarLow + (gPbarHeight/3)*gsegmentSize)),2);
     gPbarEntryHigh = NormalizeDouble(((gPbarHigh- (gPbarHeight/3)*gsegmentSize)),2);
   
    // P2bar : 2nd Previous Bar
     double gP2barClose = CPrice.bar[2].close;
      double gP2barHigh = CPrice.bar[2].high;
     double gP2barLow = CPrice.bar[2].low;
     gP2barMid = (gP2barHigh+gP2barLow)/2;
     double  gP2barOpen = CPrice.bar[2].open;
     
        
       
     CPrice.Update("XAUUSD", PERIOD_M15);
     double DXYPbarOpen = CPrice.bar[1].open;
     double DXYPbarClose = CPrice.bar[1].close;
     
     CPrice.Update("XAUUSD", PERIOD_H1);
     double DXYH1PbarOpen = CPrice.bar[1].open;
     double DXYH1PbarClose = CPrice.bar[1].close;
//double PbarMid = (gPbarHigh+gPbarLow)/2;
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
// D. Waves High and Low + Magnet Level                               |
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
         
         //put into an array the PbarLow and start accumulating highs until countPrevious becomes <0. as long as this is true,
         //EA should not take an opposite (SELL) trading position against countP  (BUY) direction and seek to enter at magnet level!
        
         double PBarHnLarray[2] = {gPbarLow, gPbarHigh};     //loads the static array with values. PbarLow should be CurrentBarLow
                                                          //using this as approximate substitute. Later, use datetime to access.
         //use function to load, calculate array
         
         double MagnetLevel = FnMagnet (gaskPrice, gCurrentPrice, PBarHnLarray, gWaveH, gWaveL, countPrevious, alertswitchPrevious);
    

  
   
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
//E. : ATR (10) EXIT + to calculate SL or TP
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+

   string ATRStrength;
   gATRScore = ATRCheckSignal(_Symbol, gATRCurrent, ATRStrength, gPriceNormalized, gATRPriceRatio, gATRdelta);
       //make universal
       gATRCurrent = NormalizeDouble((gATRCurrent / gPriceNormalized)*10000,2);

//string RVIDir = CheckRVIScore (gRVILine_Adelta, RVILineb);
//double RVITotal = RVILinea-RVILineb;

  /* double DXYATRCurrent1;

   double DXY_ATRdelta;
   double DXY_ATRPriceRatio;
   gDXYATRScore = ATRCheckSignal("XAUUSD", DXYATRCurrent1, gDXYATRStrength,
                                 gPriceNormalized, DXY_ATRPriceRatio, DXY_ATRdelta);
  */
 

//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
//F. : BBgapMetrics : from Jim BBgap-Universal.mq5
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
       UniversalBBgap::BBgapMetrics metrics = bbgapCalculator.Calculate(Symbol(), gtopBB2, gbotBB2, gmidBB);

         //obtain BBgap
           BBgapMetrics = metrics.atrScaledGap;
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
//G: FRAMA (11) Function
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

//double FramaCurrentPrice;
//double Framadelta;
   double Frama5CurrentPrice =0;
    double Frama5PreviousPrice =0;
    double Frama5Previous2Price =0;
    int gFrama5_PricePos =0;


   double Frama5Angle =0;     
   double Frama5Angle_Long =0;  

   
   int Frama5Score = FramaCheckSignal(_Symbol, PERIOD_M5, gPriceNormalized, Frama5CurrentPrice, 
               Frama5PreviousPrice, Frama5Previous2Price, gFrama5delta, gFrama5_PricePos, 
               Pbar5Open, Pbar5Close, gPbar5Cross,  gP2bar5Open, gP2bar5Close, gP2bar5Cross, 
               midBB5, top5BB1, Frama5Index, gFrama5Angle);
      
            
            double Fra5delta_BBgap_Expansion = NormalizeDouble((gFrama5delta * gBBgap_Expansion),3);
   
   double FramaPreviousPrice =0;
   double FramaPrevious2Price =0;


               
   gFramaScore = FramaCheckSignal(_Symbol, PERIOD_M15, gPriceNormalized, gFramaCurrentPrice, 
                 FramaPreviousPrice, FramaPrevious2Price, gFramadelta, gFrama_PricePos,
                 PbarOpen, PbarClose, gPbarCross,  gP2barOpen, gP2barClose, gP2barCross, 
                 gmidBB, gtopBB1, FramaIndex, gFramaAngle);
                 
  gBBFrdeltaRatio = gmidBBdelta / gFramadelta;
   gmidBBframadelta_Vector = gFramadelta + gmidBBdelta ;
   gFradelta_gBBgap_Expansion = NormalizeDouble((gFramadelta * gBBgap_Expansion),3);
   BBTopBot_Frama_delta_Vector = gFramadelta + gmidBBdelta + gtopBB2delta + gbotBB2delta;
   
   
   
      
     

//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-+
//H.: Fractal Function : to run check once every 5-min bar
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-+
  // Call FractalCheckSignal() on new bars only; Check if a fractal has been detected


  gfractal5Type = FractalCheckSignal(_Symbol, PERIOD_M5, gCurrentPrice, fractalHigh5_delta, fractalLow5_delta, glastFractal5_High, glastFractal5_Low);
        //note we are feeding a 15min midBB and gtopBB1 using the 5-min to sense for fractal. hence there is no need for lastfractal5_High and Low.
         lastFractal5Type = gfractal5Type;
         
    if (gfractal5Type == -1  || gfractal5Type == 1)
      { 
         lastfractal_LowIndex = getPrice_Index( glastFractal5_Low[0], gmidBB, gtopBB1); //this value is only true at the point it was; getPrice_Index is inside BBCheckSignal
         lastfractal_HighIndex = getPrice_Index( glastFractal5_High[0], gmidBB, gtopBB1);
          
       }  
   
       
  gfractalType = FractalCheckSignal(_Symbol, PERIOD_M15, gCurrentPrice, fractalHigh_delta, fractalLow_delta, glastFractal_High, glastFractal_Low);
    //lastfractal_LowIndex = getPrice_Index( glastFractal_Low[0], gmidBB, gtopBB1); //this value is only true at the point it was; getPrice_Index is inside BBCheckSignal
   // lastfractal_HighIndex = getPrice_Index( glastFractal_High[0], gmidBB, gtopBB1);
   lastFractalType = gfractalType;
   //equate to Global variable 
    //reset lastFractalType to 0 when it exceeds; this is important because it is used to signal TREND vs. RANGE
     //reset lastFractalType to 0 when it exceeds; this is important because it is used to signal TREND vs. RANGE
   if((gPriceNormalized >= glastFractal_High[0]) || (gPriceNormalized <= glastFractal_Low[0])) {lastFractalType =0;}
   
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
//I.: DeMark(8) Function
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


//gDeMCurrentPrice = NormalizeDouble(gDeMCurrentPrice, _Digits);
 
   gDeM5Score = DeMCheckSignal(_Symbol, PERIOD_M5, gDeM5CurrentPrice, gDeM5delta, DeM5Angle); 
   
  // double DeMCurrentPrice;
  
   gDeMScore = DeMCheckSignal(_Symbol, PERIOD_M15, gDeMCurrentPrice, gDeMdelta,  DeMAngle);
          
          
   //combine this with detectshift_2 if >20
   if(gDeMCurrentPrice >= 0.75 && gDeM5Score ==-1 && gDeMScore ==-1)
      gDeMProc = "DeMSHORT";
   else
      if(gDeMCurrentPrice <= 0.25 && gDeM5Score ==1 && gDeMScore ==1)
         gDeMProc = "DeMLONG";
      else
         gDeMProc = "DeM_NEUTRAL";          

//DXY of DeMScore
//gDXYDeMScore = DeMCheckSignal("XAUUSD", PERIOD_M15, gDXY_DeMCurrentPrice, gDXY_DeMdelta, gDXYDeMProc);

//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-+
//J.: RVI(8) Function
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-+
   gRVIScore = CheckRVIScore(_Symbol, PERIOD_M5,  gRVI5Line_A, gRVILine5_Adelta, gRVI5proc);
   gRVIScore = CheckRVIScore(_Symbol, PERIOD_M15, gRVILine_A,   gRVILine_Adelta, gRVIproc);
   /*
   char DXYRVIScore = CheckRVIScore ("XAUUSD", gRVILine_Adelta);
   */
/*
//DXY of RVIScore
   double DXYRVILine_A;
   string DXYgRVIproc;
   double DXY_gRVILineadelta;
   gDXYRVIScore = CheckRVIScore("XAUUSD", PERIOD_M15, DXYRVILine_A, DXY_gRVILineadelta, DXYgRVIproc);
   */
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX---+
//K. : Stochastics  :
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX---+
 {
   //Get Stochastic Value
   gStoch_level = stoch.Get_StochasticLevel();
    //Alert("Stoch cross Up");
   //Print(_Symbol + "  Stoch: ", gStoch_level);
   
   //Get Stochastic Score
   gStoch5Score = stoch5.Get_TrendDirection();
   gStochScore = stoch.Get_TrendDirection();
  // Print(_Symbol + "  Stoch: ", StochScore);
  
  //Signal for Crossover Up or Down
    gStoch5Xover = stoch5.Get_CrossoverSignal();
    gStochXover = stoch.Get_CrossoverSignal();
  }



//DXY PriceDir
// char DXYPriceDir = CheckDXYPriceDir ("XAUUSD");       //1-Min. chart


//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
// L. Acceleration                                                  |
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
gNoOfSegments= Acceleration (_Symbol, PERIOD_M15, gPriceNormalized, gPricedelta, gsegmentSize, gCurrentOpen, gTailScore, LowTail, HighTail);
  gNoOfSegments  = NormalizeDouble( gNoOfSegments, _Digits);
PreviousPrice = gCurrentPrice;

//double PreviousOpen = gCurrentOpen; //seems unused.
//printf("Acceleration : " + NoOfSegments);
 
//XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
// M. : TotalScoreBinary
//  
//XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
 TotalScoreBinary = GetTotalScore_Pattern(gFramaScore, gRVIScore, gStochScore, gDeMScore, gTotalScore );

      //double ladder = (topBB2-midBB)/8;
       isTotalScoreBinary_Up = TotalScoreBinary >= 96;
       isTotalScoreBinary_Down = TotalScoreBinary <=74;
     
//double ladder = (topBB2-midBB)/8;
double TotalScoreBinary_Array[2]= {0,0};
       
//XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
// N. : Populate Arrays after every 30 seconds : for use in CONDITIONS
 //function located inside DeMCheckSignal
//XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+ 
   
    // Update the 30-second array if 30 seconds have elapsed
   if(TimeCurrent() - lastArrayUpdate >= 30)
   {
      //DeMark
      PushElement_toArray(gDeMdelta, DeMdelta_Array); //populate DeMdelta_Array[]
      PushElement_toArray(DeM5Angle, DeMAngle5_Array); //populate DeMdelta_Array[]
      PushElement_toArray(DeMAngle, DeMAngle_Array); //populate DeMdelta_Array[]
      //BB
      PushElement_toArray(midBB5_Angle, midBBArray5_Angle); //populate midBBArray5_Angle[]
      PushElement_toArray(midBB_Angle, midBBArray_Angle); //populate midBBArray_Angle[]
      //Frama
      PushElement_toArray(gFrama5Angle, FramaArray5_Angle);  //populate FramaArray_AngleLong[]
      PushElement_toArray(gFramaAngle, FramaArray_Angle);  //populate FramaArray_AngleLong[]
      //FramaLong
      //PushElement_toArray(gFramaAngle_Long, FramaArray_AngleLong);  //populate FramaArray_AngleLong[]
      lastArrayUpdate = TimeCurrent();
     //Print("Updated DeMdelta_Array: current=", DeMdelta_Array[0], " previous=", DeMdelta_Array[1]);
     
     PushElement_toArray(HighLowTailDiff, HighLowTailDiff_Array);
     
      //BB : to detect Reversal
      PushElement_toArray(gBBgap_Volatility_delta, BBgap_Volatility_delta_array);
      PushElement_toArray(gBB2deltaR, BB2deltaR_array);

      //TotalScoreBinary : to detect Reversal
      PushElement_toArray(TotalScoreBinary, TotalScoreBinary_Array);
   }
//XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
// N. RANGE PPONG  Conditions : check PriceIndex > 5 / -5
//          : can be between BB or between fractal peak highs/ lows
//          : BB, FramaAngle, fractalType, PriceIndex, lastfractal_Index (high/low)
//XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
            /* Strategy : 
                  1. Reverse when PriceIndex >5 (+ / -)
            */
      
            
            int Anglethreshold_Low = 6;
            int Anglethreshold_High =12;
            
            
            //Calculate and compare BB Angles         
            isRange_BB = (gBBgap_Expansion < 0.95  && (gBB_Proc ==0
                  || ( (MathAbs(gtopBB2Angle) - MathAbs(gbotBB2Angle) <= 15) && MathAbs(midBB_Angle) < Anglethreshold_Low  && MathAbs(midBB5_Angle) < Anglethreshold_Low ))
                  );
            
            isRange_Frama = (MathAbs(gFrama5Angle) < Anglethreshold_High && MathAbs(gFramaAngle) < Anglethreshold_High );
                        //!isTrend_FramaUp && !isTrend_FramaDown
            
         //XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
         //RANGE :  Main
         //XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
            isRANGE = (isRange_BB || isRange_Frama)  || (lastFractalType ==0 && !(isTREND_Up) && !(isTREND_Down) && !(isREVERSE_Up) && !(isREVERSE_Down)) ; 
//XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
//TREND :  TREND CONDITIONS : detect some threshold of spike or reversal in BB and Frama angles
//XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
      // For circular buffer, you may want to derive positions adaptively:
      int lb1 = 1; // lb refers to lookback. This represents the previous
      int lb2 = 4; // This is the position 4 steps before the latest one i specified.
     
      int anglethreshold_Trend = 4; //specifies the trigger angle difference between the last 2 bar angles.
      int anglethreshold_Reverse =30; //specifies the trigger angle difference between the immediate previous bar angle and the 4th previous bar's angle.
      double ratioThreshold = 3; //specifies the ratio 
      
      int angle_threshold_Cross = 15; //detects end of Trend  / pullback
     
      
       double HighLowTailDiff_shiftReverse = Simple_analyzer.detectShift_Reverse(HighLowTailDiff_Array[0],  HighLowTailDiff_Array[lb1], 0, ratioThreshold);
       
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
      //TREND BB :  long-term U-Turn shifts across 5 bars in the past; -----
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
      //Tracks short-term changes or typical pullback (isaddScalp) if BB5Angle_shiftTrend is not congruent with BBAngle_shiftTrend. 
       BB5Angle_shiftTrend = Simple_analyzer.detectShift_Trend( midBBArray5_Angle[0], midBBArray5_Angle[lb1], anglethreshold_Trend); //specifies the trigger angle difference between the last 2 bar angles.); 
       BBAngle_shiftTrend = Simple_analyzer.detectShift_Trend( midBBArray_Angle[0],  midBBArray_Angle[lb1], anglethreshold_Trend);
      //Slow is to avoid false reversal
      // BB5Angle_shiftSlow = Simple_analyzer.detectShift_Trend( midBBArray5_Angle[0], midBBArray5_Angle[lb2], anglethreshold_Reverse);
     //  BBAngle_shiftSlow = Simple_analyzer.detectShift_Trend( midBBArray_Angle[0],  midBBArray_Angle[lb2], anglethreshold_Reverse);
      //Cross compare M5 vs.M15 : detects end of Trend or Pullback
     
      BBAngle_shiftReverse = Simple_analyzer.detectShift_Reverse( midBBArray_Angle[0],  midBBArray_Angle[lb1], anglethreshold_Reverse); 
      BB5Angle_shiftCrossReverse = Simple_analyzer.detectShift_Reverse( midBBArray5_Angle[0],  midBBArray_Angle[0], anglethreshold_Reverse); 
    
     //midBB & Frama Angles : compare
   
          
      //isTrend_BB : uses a combination of BB_Proc and detecting sudden shifts in the midBB_Angle.
      isTrend_BBUp = ( !(BBAngle_shiftReverse <0) && !(BB5Angle_shiftCrossReverse <0) && gFrama_PricePos >=1 
                       && ( ((BB5Angle_shiftTrend >0 || BBAngle_shiftTrend >0) || (BB5Angle_shiftTrend > BBAngle_shiftTrend)  ) // removed  && (BB5Angle_shiftSlow >0 || BB5Angle_shiftSlow >0 )
                           || gBB_Proc ==1)); //neutral on direction              
                     
      isTrend_BBDown = (!(BBAngle_shiftReverse >0) && !(BB5Angle_shiftCrossReverse >0) && gFrama_PricePos <=-1
                         && ( ((BB5Angle_shiftTrend <0 || BBAngle_shiftTrend <0) || (BB5Angle_shiftTrend < BBAngle_shiftTrend) ) //removed && (BB5Angle_shiftSlow <0 || BB5Angle_shiftSlow <0 )
                           || gBB_Proc ==-1));
                       
     
      
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+    
      //TREND FRAMA 5-min : compare to detect Reversal or startTrend
      //Note : i am not sure how effective or whether FramaArray5_AngleLong has any use at all. to double check. otherwise, can delete as it might be confusing.
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
    //5-min
    //( (Simple_analyzer.detectShift_Trend( FramaArray5_AngleLong[0],  FramaArray5_AngleLong[lb1], anglethreshold_Trend)
       Frama5Angle_shiftTrend =  //based on angle of bar 1 to bar 4.  Excel Data 
                          Simple_analyzer.detectShift_Trend( FramaArray5_Angle[0],  FramaArray5_Angle[lb1], anglethreshold_Trend, ratioThreshold);//latest bar index 0 compared with immediate previous bar lb1.
                         
     // Simple_analyzer.updatePrice(gFramaAngle);  // populates the angles into the array. Assuming updatePrice method exists and `FramaAngle` is the latest data 
      FramaAngle_shiftTrend = Simple_analyzer.detectShift_Trend( FramaArray_Angle[0], FramaArray_Angle[lb1], anglethreshold_Trend); //latest bar index 0 compared with immediate previous bar lb1.
     
     FramaAngle_shiftReverse = Simple_analyzer.detectShift_Reverse( FramaArray_Angle[0],  FramaArray_Angle[lb1], anglethreshold_Reverse); 
     Frama5Angle_shiftCrossReverse = Simple_analyzer.detectShift_Reverse( FramaArray5_Angle[0],  FramaArray_Angle[0], anglethreshold_Reverse);   //Cross compare M5 vs.M15 : detects end of Trend or Pullback
     
      
       //midBB & Frama 
      BBFrama_shiftTrend= Simple_analyzer.detectShift_Trend( midBBArray_Angle[0], FramaArray_Angle[0], anglethreshold_Trend); 
      // Assuming Simple_analyzer is an instance of SimplePriceAnalyzer
      //int startIndex = 0; // Keep track of the start index if needed
      //int size = Simple_analyzer.GetSize();
      
      // Jim PriceChangeAnalyze_Timediff1.mq5 : FramaArray_Angle: FramaAngle_shiftSlow Detect slow and long-term U-Turn angle shifts across bar angles in the past; 
      // in this case, comparing the angle in index 1 against the angle in index 3, 
      //Frama5Angle_shiftSlow = Simple_analyzer.detectShift_Trend(int(FramaArray5_Angle[0]), int(FramaArray5_Angle[lb2]), anglethreshold_Reverse);
      //FramaAngle_shiftSlow = Simple_analyzer.detectShift_Trend(int(FramaArray_Angle[0]), int(FramaArray_Angle[lb2]), anglethreshold_Reverse);
      
           

//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
//Frama
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+

   isTrend_FramaUp = previousFramaPricePos ==1 && gFrama_PricePos ==1 && (gFramaAngle >=Anglethreshold_Low || gBB_Proc ==1) 
                     && gBBgap_Expansion > 1.02
                     //Negations
                     && !(gStochScore <0) && !(Frama5Score <0) && !(lastFractalType ==-1)
                     && !(FramaAngle_shiftTrend > 0)  
                     && !(Frama5Angle_shiftTrend > FramaAngle_shiftTrend) 
                     && !(Frama5Angle > Anglethreshold_Low && gFramaAngle > Anglethreshold_High); 
                     
   isTrend_FramaDown = previousFramaPricePos ==-1 && gFrama_PricePos ==-1 && (gFramaAngle <=-Anglethreshold_Low  || gBB_Proc ==-1)
                     && gBBgap_Expansion > 1.02
                     //Negations:
                     && !(gStochScore >0) && !(Frama5Score >0) && !(lastFractalType ==1)
                     && !(FramaAngle_shiftTrend < 0) 
                     && !(Frama5Angle_shiftTrend < FramaAngle_shiftTrend) 
                     && !(Frama5Angle < Anglethreshold_Low && gFramaAngle < Anglethreshold_High);                 

    
    
        
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
//TrendCond3 : isTrend_Tail : use of High and Low Tails for additional supporting fine-grain control
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
    isTrend_TailUp = gFrama_PricePos ==1 && ((lastFractalType ==1  || lastfractal_LowIndex <=-4) && (LowTail ==0 && gbarPricedelta >0.5));
   
    isTrend_TailDown = gFrama_PricePos ==-1 && ((lastFractalType ==-1 || lastfractal_HighIndex >=4) && (HighTail ==0 && gbarPricedelta <-0.5));
     
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
// TrendCond4 : isTrend_DeMUp :              |
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
    
      DeM_trendShiftResult = 0.0; // Initialize result variable to zero
      
      // Define the DeMthreshold dynamically based on angle_threshold_Cross
      double DeMthreshold = angle_threshold_Cross + 5;
      
      // Check 1: Delta Array Trend Shift
      // Corrected Argument Order: (previous, current, threshold) -> (Array[lb1], Array[0], threshold)
      DeM_trendShiftResult = Simple_analyzer.detectShift_Trend(DeMdelta_Array[0], DeMdelta_Array[lb1], (int)DeMthreshold); // Cast threshold to int if needed by function signature
      
      // Check 2: Angle Array Trend Shift (only if Check 1 returned 0.0)
      if (DeM_trendShiftResult == 0.0) {
          // Corrected Argument Order: (previous, current, threshold) -> (Array[lb1], Array[0], threshold)
          DeM_trendShiftResult = Simple_analyzer.detectShift_Trend(DeMAngle_Array[0], DeMAngle_Array[lb1], (int)DeMthreshold); // Cast threshold to int if needed
      }
      
      // Alerting logic based on the first detected trend shift
      // Note: This alert only triggers if DeM_trendShiftResult is POSITIVE.
      // Review the function's return logic to confirm if this covers all desired "trend shift" scenarios.
      // See explanation below for what a positive result means according to the function code.
     isTrend_DeMUp =(DeM_trendShiftResult > 0);
     isTrend_DeMDown =  (DeM_trendShiftResult < 0);

      
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
      // TREND  : TREND CONDOLIDATED CONDITIONS         |
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+    
      //BBgap, PriceIndex.
       isTREND_Up = gFrama_PricePos ==1 && (gFramaScore==1  || lastFractalType ==1)
               && gfractalType !=-1  && !isTrend_BBDown && gStochScore !=-1  && FramaIndex !=4 && !isTrend_BBDown && !isReverse_BB2deltaR_Down && !isReverse_TotalScoreBinaryDown 
                     && gRVIproc != "RVI_TrendDown" && gRVIproc != "RVI_startTrendDown" && gRVIproc != "RVI_ReverseDown" &&  gBB_Proc !=0  //negation
               && (
               (isTrend_BBUp || isTrend_FramaUp ) 
               || (isTrend_BBUp && FramaIndex <=-1) 
               || ((gRVIproc =="RVI_startTrendUp" || gRVIproc =="RVI_TrendUp")  && isTrend_BBUp)
               );
              
                    
       isTREND_Down = gFrama_PricePos ==-1 && (gFramaScore==-1 || lastFractalType ==-1)
               && gfractalType !=1  && !isTrend_BBUp  && gStochScore !=1  && FramaIndex !=-4 && !isReverse_BB2deltaR_Up && !isReverse_TotalScoreBinaryUp 
                     && gRVIproc != "RVI_TrendUp" && gRVIproc != "RVI_startTrendUp" && gRVIproc != "RVI_ReverseUp" && gBB_Proc !=0
               && (
               (isTrend_BBDown || isTrend_FramaDown ) 
               || (isTrend_BBDown && FramaIndex >=1) 
               || ((gRVIproc =="RVI_startTrendDown" || gRVIproc =="RVI_TrendDown")  && isTrend_BBDown)
              );
                       
       
     
  
    
 
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
//RevCon : REVERSE CONDITION to TP when Ranging.
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
  
     //isPriceReverse :  
     isReverse_PriceIndexUp = lastPriceIndex <=-4 && isRANGE &&( gDeMScore ==1 || isTotalScoreBinary_Up || gATRScore ==-1 || gStoch_level >=90)  //removed RVILine_Adelta <=0
         && (lastPrice5Index ==-5 || Frama5Index <=-3 || FramaIndex <=-3  || gNoOfSegments <= -0.35 );
         
     isReverse_PriceIndexDown = lastPriceIndex >=4 &&  isRANGE &&(gDeMScore ==-1 || isTotalScoreBinary_Down || gATRScore ==-1  || gStoch_level <=10) 
         && (lastPrice5Index ==5 || Frama5Index >=3 || FramaIndex >=3 || gNoOfSegments >= 0.35);
     
     
     
      

   //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
   // RevCon1 : isReverse_Frama : CONDITION   :  detect sudden shift in Angle of Frama           |
   //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+    
      // shift==-1 is specified inside detechShift() as indicating no significant shift
       //5-min
               
           
        if ((gRVIproc !="RVI_startTrendDown" && (gRVIproc !="RVI_TrendDown" || gBBgap5_Expansion <0.95) && lastFractalType !=-1 && FramaIndex <=2) //removed  !((fractal5Type * fractalType) < 0) 
            && Frama5Angle_shiftCrossReverse >0
            && (
               (Frama5Angle > anglethreshold_Trend && (FramaAngle_shiftReverse >0 || Frama5Angle_shiftCrossReverse > 0))
               || (FramaIndex <=-1 && gFramaScore !=-1 && Frama5Score ==11 && Frama5Index <=-3 && gPbar5Cross==0) //M5
               || (Frama5Angle_shiftTrend >0)
               )
           )
                
            {
                isReverse_FramaUp =true; // Set the flag to true only once per period
            }

      if ((gRVIproc !="RVI_startTrendUp" && (gRVIproc !="RVI_TrendUp" || gBBgap5_Expansion <0.95)  && lastFractalType !=1 && FramaIndex >=-2) //removed !((fractal5Type * fractalType) < 0) 
             && Frama5Angle_shiftCrossReverse <0 
             && (
                   (Frama5Angle < -anglethreshold_Trend && (FramaAngle_shiftReverse <0 || Frama5Angle_shiftCrossReverse < 0))
                  || (FramaIndex >=1 && gFramaScore !=1  && Frama5Score ==-1 && Frama5Index >=3 && gPbar5Cross==0)
                  || (Frama5Angle_shiftTrend <0)
                )
         ) 
            {
                isReverse_FramaDown =true; // Set the flag to true only once per period
            }

       
          //use FramaArray[]
           double lb1_Frama_value = FramaArray_Angle[lb1];
         //  double lb2_Frama_value = FramaArray_Angle[lb2];

      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
      // RevCon2 : isReverse_BB : CONDITION   : detect sudden shift in Angle of BB.               |
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+    
       
       // double BBshift  = Simple_analyzer.detectShift(midBB_Angle, lb1, lb2, anglethreshold);  //from Jim PriceChangeAnalyze_Timediff.mq5

         //BUY
         // double BBshift  = Simple_analyzer.detectShift(midBB_Angle, lb1, lb2, anglethreshold);  //from Jim PriceChangeAnalyze_Timediff.mq5
          isReverse_BBUp = ((gPriceIndex <=-3 && gbotBB2Angle >=0) && ( BBAngle_shiftReverse >0 || BB5Angle_shiftCrossReverse >0 || BBFrama_shiftTrend >0));
   
         //Sell
        isReverse_BBDown =((gPriceIndex >=3 && gtopBB2Angle <=0) && (BBAngle_shiftReverse <0 || BB5Angle_shiftCrossReverse <0 || BBFrama_shiftTrend <0));
 
          //use FramaArray[]
           double lb1_BB_value = midBBArray_Angle[lb1];
           //double lb2_BB_value = midBBArray_Angle[lb2];
         
      
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
      // RevCon3 :  REVERSE isReverse_FractStochUp : CONDITION                         |
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+    

          isReverse_FractStochUp = (lastFractalType ==1 && lastFractal5Type ==1 && ((gPriceNormalized > gPbarMid) || FramaIndex <=-1)) 
                         && ((gStoch5Score ==1 || gStoch5Xover == "stoch_XUp") && (gStochScore ==1 ||  gStochXover =="stoch_XUp"));
          
          isReverse_FractStochDown = (lastFractalType ==-1 && lastFractal5Type ==-1 &&  ((gPriceNormalized < gPbarMid)  || FramaIndex >=1)) 
                        && ((gStoch5Xover == "stoch_XDown" || gStoch5Score ==-1) && (gStochScore ==-1 || gStochXover =="stoch_XDown"));
            
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+   
      // RevCon4 : REVERSE isReverse_DeMUp isReverse_DeMdelta : CONDITION                      |
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+ 
     
  
      double moveToZeroResult = 0.0; // Initialize to zero (no move detected yet)
      double magnitudeThreshold = anglethreshold_Reverse;
      
      // Check 1: M5 Angle move TO zero
      // Calls detectMoveToZero_Reverse(currentValue, previousValue, magnitudeThreshold)
      moveToZeroResult = Simple_analyzer.detectMoveToZero_Reverse(DeMAngle5_Array[0], DeMAngle5_Array[lb1], magnitudeThreshold);
      
      // Check 2: M15 Angle move TO zero (only if Check 1 returned 0.0)
      if (moveToZeroResult == 0.0) {
          // Calls detectMoveToZero_Reverse(currentValue, previousValue, magnitudeThreshold)
          moveToZeroResult = Simple_analyzer.detectMoveToZero_Reverse(DeMAngle_Array[0], DeMAngle_Array[lb1], magnitudeThreshold);
      }
      
      // Check 3: Delta move TO zero (only if Check 1 and Check 2 returned 0.0)
      if (moveToZeroResult == 0.0) {
          // Calls detectMoveToZero_Reverse(currentValue, previousValue, magnitudeThreshold)
          // Corrected: Added the magnitudeThreshold argument
          moveToZeroResult = Simple_analyzer.detectMoveToZero_Reverse(DeMdelta_Array[0], DeMdelta_Array[lb1], 5);
      }
      
      // Determine direction based on the final result stored in moveToZeroResult
      // Corrected: Used moveToZeroResult
     isReverse_DeMUp = moveToZeroResult > 0;   // Positive result means UP (neg -> zero)
     isReverse_DeMDown = moveToZeroResult < 0; // Negative result means DOWN (pos -> zero)
      

    
 
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
      // RevCon5 :  REVERSE isReverse_BBFrdeltaRatio : CONDITION                      |
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+ 
       isReverse_BBFrdeltaRatio =  gBBFrdeltaRatio <-2.5;
       
   //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
   // RevCon6 :  REVERSE isReverse_BBFrdeltaRatio && isReverse_DeMUp : CONDITION                      |
   //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
   bool isReverse_DeMdelta_BBFrdeltaRatioUp = (isReverse_BBFrdeltaRatio && isReverse_DeMUp);
   bool isReverse_DeMdelta_BBFrdeltaRatioDown = (isReverse_BBFrdeltaRatio && isReverse_DeMDown);



    bool isReverse_HighLowTailDiff_Up =  HighLowTailDiff_shiftReverse >0; //used in isReverse_
    bool isReverse_HighLowTailDiff_Down = HighLowTailDiff_shiftReverse <0; 
           
           
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
// RevCon7 :  isReverse_Tail : use of Tail fine-grain signals as additional support to REVERSE  
//          : can also be used as Defense           |
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
  double BarHeight = giHigh - giLow ;
  double LowTail_BarRatio = LowTail / BarHeight;   double HighTail_BarRatio = HighTail / BarHeight;  
  static bool LowTail_BarRatio_On =  LowTail_BarRatio >=0.25;
  static bool HighTail_BarRatio_On = HighTail_BarRatio >=0.25;      
                      
                      
   //must have a big-picture controller.                         
   isReverse_TailUp = ((LowTail_BarRatio_On || (LowTail ==0 && HighTail ==0)) &&  gFrama_PricePos ==-1  
               && (gCurrentPrice > gPbarHigh || gNoOfSegments>0.5 || lastfractal_LowIndex <=-3 ||  lastFractalType ==1 || isReverse_HighLowTailDiff_Up ) //2nd bar
               );           //this is 2nd bar counting from last.
  
  
   isReverse_TailDown = ((HighTail_BarRatio_On || (HighTail ==0 && LowTail ==0)) && gFrama_PricePos ==1 
            && (gCurrentPrice < gPbarLow || gNoOfSegments <-0.5 || lastfractal_LowIndex >=3 || lastFractalType ==-1 || isReverse_HighLowTailDiff_Down )
            );   
            
 
  

//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
// RevCon9 : BBgap_Volatility_Reverse   | based on USDJPY DataLog 19.March.2025 !
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
//detects reversal : USDJPY : from 4 to -4.
   double BBgap_Volatility_Reverse = Simple_analyzer.detectShift_Reverse(BBgap_Volatility_delta_array[0],  BBgap_Volatility_delta_array[lb1], 1, 0.1, 1, 1);
   bool isReverse_BBgap_VolUp = BBgap_Volatility_Reverse >0;
   if(isReverse_BBgap_VolUp)
     {
    
      
     }

   bool isReverse_BBgap_VolDown = BBgap_Volatility_Reverse <0;
   if(isReverse_BBgap_VolDown)
     {
      
     
     }


//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
// RevCon10 : isReverse_BB2deltaR_Down   | based on USDJPY DataLog 19.March.2025 !
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
//This uses detectshift_Trend but from DataLog, this detects a reversal when ratioThreshold >3 :  dont put too much weight on this as yet..not sure if true everytime !
   double BB2deltaR_Trend = Simple_analyzer.detectShift_Trend(BB2deltaR_array[0],  BB2deltaR_array[lb1], 0, 3);
   isReverse_BB2deltaR_Up = BB2deltaR_Trend >0;
   if(isReverse_BB2deltaR_Up)
     {
      
     
     }

   isReverse_BB2deltaR_Down = BB2deltaR_Trend <0;
   if(isReverse_BB2deltaR_Down)
     {
     
      
     }


//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
// RevCon11 : TotalScoreBinary_Reverse : TotalScoreBinary_Reverse :
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
//we use detectShift_Trend because there are no (+)/(-)
   double TotalScoreBinary_Reverse = Simple_analyzer.detectShift_Trend(TotalScoreBinary_Array[0],  TotalScoreBinary_Array[lb1], 0, 2);

   isReverse_TotalScoreBinaryUp = TotalScoreBinary_Reverse >0;
   if(isReverse_TotalScoreBinaryUp)
     {
    
      
     }

   isReverse_TotalScoreBinaryDown = TotalScoreBinary_Reverse <0;
   if(isReverse_TotalScoreBinaryDown)
     {
   
     
     }

//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
// RevCon12 : Misc : isReverse_FramaPeaked_Up && Frama5Angle : Peak Detection : portends Reversal !
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
//Use this only in conjunction with Frama5Angle: when Framadelta goes up and Frama5Angle reverses
   double Framadelta_Trend = Simple_analyzer.detectShift_Trend(FramaArray5_Angle[0],  FramaArray5_Angle[lb1], 0, 2);

   bool isReverse_FramaPeaked_Up = Framadelta_Trend <0 && Frama5Angle_shiftTrend >0;  //direction is opposite, dictated by Frama5Angle, counter-intuitively!
   if(isReverse_FramaPeaked_Up)
     {
   
     
     }

   bool isReverse_FramaPeaked_Down = Framadelta_Trend >0 && Frama5Angle_shiftTrend <0;  //direction is opposite, dictated by Frama5Angle, counter-intuitively!;
   if(isReverse_FramaPeaked_Down)
     {
      
      
     }
          

            
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+
      // RevMAIN :    CONDITION                                                                 |
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX--+      
 

   isREVERSE_Up =   isReverse_FractStochUp && (isReverse_FramaUp || isReverse_DeMUp || isReverse_BBUp || gRVIproc == "RVI_ReverseUp" || isReverse_TailUp );
         if(isREVERSE_Up)
              {
                upTriggerIdentifier = CalculateUpTriggerIdentifier(isReverse_FractStochUp, isReverse_FramaUp, isReverse_DeMUp, isReverse_BBUp, gRVIproc);    
              } else {upTriggerIdentifier =0;}

   isREVERSE_Down =  isReverse_FractStochDown && (isReverse_FramaDown || isReverse_DeMDown || isReverse_BBDown || gRVIproc == "RVI_ReverseDown" || isReverse_TailDown);
        if(isREVERSE_Down)
           {
           downTriggerIdentifier = CalculateDownTriggerIdentifier(isReverse_FractStochDown, isReverse_FramaDown, isReverse_DeMDown, isReverse_BBDown, gRVIproc);
           }else {downTriggerIdentifier =0;}
           
           
 
//XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
//P. addScalp CONDITIONS
//XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+

      double topScalpPrice = NormalizeDouble(gtopBB1 + (gsegmentSize*.5),_Digits); //negative sign reduces its level for testing.
      double botScalpPrice = NormalizeDouble(gbotBB1 - (gsegmentSize*.5),_Digits);
      double addScalpFramaTop = NormalizeDouble(gFramaCurrentPrice +  (gsegmentSize*1.25), _Digits);//a little above FramaCurrent
      double addScalpFramaBot = NormalizeDouble(gFramaCurrentPrice -  (gsegmentSize*1.25), _Digits);// a little below FramaCurrent
      
      //BB_PullBack : detects temporary pullback but main TREND still intact; to use for addScalp. To reset after 5 min.
      static bool isaddScalp_BBUp = BBAngle_shiftCrossReverse <0 && midBB_Angle >Anglethreshold_High;
      static bool isaddScalp_BBDown = BBAngle_shiftCrossReverse >0 && midBB_Angle <-Anglethreshold_High;      
      
       //Fract5Type and DeM
      isaddScalp_FractDeMUp = midBB_Angle > Anglethreshold_High && gfractal5Type ==1 && gDeM5Score ==1 && gDeMScore ==1;
      isaddScalp_FractDeMDown = midBB_Angle < -Anglethreshold_High && gfractal5Type ==-1 && gDeM5Score ==-1 && gDeMScore ==-1;
      
      
    //BUY
    isAddScalp_Up =  ((isaddScalp_FractDeMUp || isaddScalp_BBUp) && isTREND_Up)
            && ( (barCount <=7 && isReverse_PriceIndexDown) || isReverse_BBDown  ||  isReverse_DeMDown ||  isReverse_DeMDown || (gDeM5Score ==-1 && gDeMScore ==1 ) 
                  || gRVIproc == "RVI_ReverseDown" || lastfractal_LowIndex >=-4) 
            && ((gStochScore ==1 || gRVIproc == "RVI_startTrendUp" ) && (gStoch_level <95 || gStoch5Xover != "stoch_XDown"))
            && FramaIndex <4 && gFrama_PricePos ==1 //Price is high than Frama
            && ((gPriceIndex <=3 || gCurrentPrice <= topScalpPrice) && MathAbs(gNoOfSegments) <=0.5);
         
          
       //SELL   
      isAddScalp_Down = ((isaddScalp_FractDeMDown || isaddScalp_BBDown) && isTREND_Down) 
            && ( (barCount <=7 && isReverse_PriceIndexUp) || isReverse_BBUp ||  isReverse_DeMUp || (gDeM5Score ==1 && gDeMScore ==-1)  
                  || gRVIproc == "RVI_ReverseUp" ||  lastfractal_HighIndex <=4)
            && ((gStochScore ==-1 || gRVIproc == "RVI_startTrendDown" )  && (gStoch_level <95 || gStoch5Xover != "stoch_XUp"))  
            && FramaIndex >-4 && gFrama_PricePos ==-1 //Price is lower than Frama
            && (( gPriceIndex >=-3 || gCurrentPrice >= botScalpPrice ) && MathAbs(gNoOfSegments) <=0.5);
           
    

    
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX---+
//R.: Frama Ratios : seem to represent vissicitudes!
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX---+
double FraATRdelta =0;
  
   FraATRdelta = NormalizeDouble(gFramadelta * gATRdelta, 3);
   gFraRVILine_Adelta = NormalizeDouble(gFramadelta + gRVILine_Adelta, 3);
   
   gFraDeMdelta = NormalizeDouble(gFramadelta + gDeMdelta, 3);
  
   //gFraRVector = gFraRVILine_Adelta + gFraDeMdelta;  
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
// S.: Calculate newBar                                                      |
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
   if (isNewBar(PERIOD_M5)) {
       // Print("Number of bars with unchanged Frama_PricePos: ", barCount);
     
          }

   if (isNewBar(PERIOD_M15)) {
     // Count the number of bars based on gFrama_PricePos
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-+
      //Resets barCount to 0 when bar crosses Framaline
      //+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-+
          countBarsBasedOnFrama(gPbarCross);  //PbarCross is defined above.
  
    } 
    
   if (isNewBar(PERIOD_M30)) {
       flag_lastPriceIndex =false;
      LowTail_BarRatio_On =false; //reset the boolean 
      HighTail_BarRatio_On =false;
       }
       
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-+
//T. : TRADE INFOS : 
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-+
         
         




//OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO+      
//COUNT WAVES Cases : should addScalp or ENTER at REVERSALS (Case 5 & 6)
//OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO+    
      if 
            (
            alertswitchPrevious !=-88    
            && (gaskPrice >= topScalpPrice || gCurrentPrice >= gtopBB2)
            && gcount_WaveUp <=2 
            && countPrevious <=0        //required because used in Cases scenarios; to prevent from counting non-stop
                                        //& to ensure only 1 Big wave is counted.
            ) 
            {
               gcount_WaveUp +=1;

               countPrevious = gcount_WaveUp;
           
               
            if (gcount_WaveUp >=5)
               {
                 // Alert( "POS 3rd wave reached. Back to 0");      //restart    
                  gcount_WaveUp =0;
               }
        
              // Alert ("default Check value : " + (string)Check);
      }//end of if
         //===================================================================+     
         //COUNTN 
         //===================================================================+
           else if 
               ( 
               (gCurrentPrice <= botScalpPrice || gaskPrice <= gbotBB2)
               && (gcount_WaveDown >=-2) && countPrevious <=0
               )
               {
                  gcount_WaveDown -=1;
                  countPrevious = gcount_WaveDown;  
                 //works well but switched off to test if ok to remove.
            

                 if (gcount_WaveDown ==-5) 
                  {
                  //Alert( "POS 3rd wave reached. Back to 0");     
                  gcount_WaveUp =0;
                  }
               
            }//end of if
 



  } //end of OnTick())

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
static double Rldr_diffarray[2] = {0};
static double midBBframaarray[2]  = {0};
static double BBgapPriceRarray[2] = {0};
static double Rldr_unitPrarray[2] = {0};
   //static double topBB2delarray[2];
  // static double botBB2delarray[2];
  // static double gBBgap_Volatility_deltaarray[2];
static double gBB2deltaR_array[2] = {0};
static double FraRVILine_Aarray[2] = {0};
static double FraDeMarray[2] = {0};

   static double BBFramaRarray[2] = {0};

   /*  
  gBBgap_Volatility_Adjustment_TimeDiff = Timediff( Rldr_diffarray); //using Momentum7
  gBBgap_Volatility_AdjustmentReverseAlert = Momentum7 (gBBgap_Volatility_Adjustment_TimeDiff, gRldr_diffarray7, gBBgap_Volatility_AdjustmentcountPos, gBBgap_Volatility_AdjustmentcountNeg, gmidBBdelta); 
  
   gBBgapPriceRatio_TimeDiff  = Timediff(gBBgapPriceRatio, BBgapPriceRarray);  //using special function CompareBBgapPriceR
   gBBgapPriceRatioReverseAlert =CompareBBgapPriceR (gBBgapPriceRatio_TimeDiff, gBBgapPriceRatio, gBBgapPriceRatioarray7, 
                                 gBBgapPriceRatiocountPos, gBBgapPriceRatiocountNeg); 
   
      
  //DXY   
  gDXY_BBgap_Volatility_Adjustment_TimeDiff  = Timediff(gDXY_BBgap_Volatility_Adjustment, gDXY_BBgap_Volatility_Adjustmentarray);     
  gDXY_BBgap_Volatility_AdjustmentReverseAlert =Momentum7 (gDXY_BBgap_Volatility_Adjustment_TimeDiff, gDXY_BBgap_Volatility_Adjustment, gDXY_BBgap_Volatility_Adjustmentarray7, gDXY_BBgap_Volatility_AdjustmentcountPos, gDXY_BBgap_Volatility_AdjustmentcountNeg, gDXY_midBBdelta); 
    
    
    
   //not yet using Momemtum7

   gBBFrdeltaRatio_TimeDiff  = Timediff(gBBFrdeltaRatio, BBFramaRarray);
   gBBgapRldr_unitPr_TimeDiff  = Timediff(gBBgapRldr_unitPr, Rldr_unitPrarray);
   gmidBBframadelta_V_TimeDiff  = Timediff(gmidBBframadelta_Vector, midBBframaarray);
   gBBgapPriceRatio_TimeDiff  = Timediff(gBBgapPriceRatio, BBgapPriceRarray);
      
   gFraRVILine_Adelta_TimeDiff = Timediff(gFraRVILine_Adelta, FraRVILine_Aarray);
   gFraDeMdelta_TimeDiff = Timediff(gFraDeMdelta, FraDeMarray);
   
     gBB2deltaR_TimeDiff = Timediff(gBB2deltaR, gBB2deltaRarray); 
   */   



//Create Arrays


ArrayResize(headerParams, 152);
//headers array parameter defined globally.
int index = 0;
// Assuming headerParams is a string array and index is declared and initialized
headerParams[index++] = "TimeServer";                     // 1
headerParams[index++] = "Symbol";                         // 2
headerParams[index++] = "askPrice";                       // 3
headerParams[index++] = "Price";                          // 4 // Current Price
headerParams[index++] = "barCount";                       // 5 // Continuous Trend bar count where FramaPricePos did not change
headerParams[index++] = "isRANGE";                        // 6
headerParams[index++] = "isRange_BB";                     // 7
headerParams[index++] = "isRange_Frama";                  // 8
headerParams[index++] = "isTREND_Up";                     // 9
headerParams[index++] = "isTREND_Down";                   // 10
headerParams[index++] = "isTrend_TailUp";                 // 11
headerParams[index++] = "isTrend_TailDown";               // 12
headerParams[index++] = "isTrend_BBUp";                   // 13
headerParams[index++] = "isTrend_FramaUp";                // 14
headerParams[index++] = "isTrend_BBDown";                 // 15
headerParams[index++] = "isTrend_FramaDown";              // 16
headerParams[index++] = "isTrend_DeMUp";                  // 17
headerParams[index++] = "isTrend_DeMDown";                // 18
headerParams[index++] = "isREVERSE_Up";                   // 19
headerParams[index++] = "isREVERSE_Down";                 // 20
headerParams[index++] = "upTriggerIdentifier";            // 21
headerParams[index++] = "downTriggerIdentifier";          // 22
headerParams[index++] = "isReverse_TotalScoreBinaryUp";
headerParams[index++] = "isReverse_TotalScoreBinaryDown";
headerParams[index++] = "isReverse_BB2deltaR_Up";
headerParams[index++] = "isReverse_BB2deltaR_Down";
headerParams[index++] = "isReverse_TailUp";               // 23
headerParams[index++] = "isReverse_TailDown";             // 24
headerParams[index++] = "isReverse_FractStochUp";         // 25
headerParams[index++] = "isReverse_FractStochDown";       // 26
headerParams[index++] = "isReverse_DeMUp";                // 27
headerParams[index++] = "isReverse_DeMDown";              // 28
headerParams[index++] = "isReverse_BBUp";                 // 29
headerParams[index++] = "isReverse_FramaUp";              // 30
headerParams[index++] = "isReverse_BBDown";               // 31
headerParams[index++] = "isReverse_FramaDown";            // 32
headerParams[index++] = "isReverse_PriceIndexUp";         // 33
headerParams[index++] = "isReverse_PriceIndexDown";       // 34
headerParams[index++] = "isaddScalp_FractDeMUp";          // 35
headerParams[index++] = "isaddScalp_FractDeMDown";        // 36
headerParams[index++] = "isAddScalp_Up";                  // 37
headerParams[index++] = "isAddScalp_Down";                // 38
headerParams[index++] = "Frama5Index";                    // 39
headerParams[index++] = "FramaIndex";                     // 40
headerParams[index++] = "Price5Index";                    // 41
headerParams[index++] = "PriceIndex";                     // 42
headerParams[index++] = "TotalScore";                     // 43
headerParams[index++] = "TotalScoreBinary";               // 44
headerParams[index++] = "isTotalScoreBinary_Up";          // 45
headerParams[index++] = "isTotalScoreBinary_Down";        // 46
headerParams[index++] = "BBTopBot_Frama_delta_Vector";    // 47
headerParams[index++] = "NoOfSegments";                   // 48
headerParams[index++] = "Pricedelta";                     // 49
headerParams[index++] = "HighTail";                       // 50
headerParams[index++] = "LowTail";                        // 51
headerParams[index++] = "HighLowTailDiff";                // 52
headerParams[index++] = "TailScore";                      // 53
headerParams[index++] = "finalTailScore";                 // 54
headerParams[index++] = "FramaCurent";                    // 55
headerParams[index++] = "FramaScore";                     // 56
headerParams[index++] = "Frama_PricePos";                 // 57
headerParams[index++] = "Frama5delta";                    // 58
headerParams[index++] = "Framadelta";                     // 59
headerParams[index++] = "Frama5Angle";                    // 60
headerParams[index++] = "FramaAngle";                     // 61
headerParams[index++] = "Pbar5Cross";                     // 62
headerParams[index++] = "PbarCross";                      // 63
headerParams[index++] = "P2barCross";                     // 64
headerParams[index++] = "Stoch5Score";                    // 65
headerParams[index++] = "StochScore";                     // 66
headerParams[index++] = "Stoch_level";                    // 67
headerParams[index++] = "Stoch5Xover";                    // 68
headerParams[index++] = "StochXover";                     // 69
headerParams[index++] = "BB5_Proc";                       // 70
headerParams[index++] = "BB_Proc";                        // 71
headerParams[index++] = "midBBTREND";                     // 72
headerParams[index++] = "midBB5";                         // 73
headerParams[index++] = "midBB";                          // 74
headerParams[index++] = "midBB5_Angle";                   // 75
headerParams[index++] = "midBB_Angle";                    // 76
headerParams[index++] = "topBB2Angle";                    // 77
headerParams[index++] = "botBB2Angle";                    // 78
headerParams[index++] = "BB5Angle_shiftTrend";            // 79
headerParams[index++] = "BBAngle_shiftTrend";             // 80
headerParams[index++] = "BB5Angle_shiftCrossReverse";     // 81
headerParams[index++] = "BBAngle_shiftCrossReverse";      // 82
headerParams[index++] = "Frama5Angle_shiftTrend";         // 83
headerParams[index++] = "FramaAngle_shiftTrend";          // 84
headerParams[index++] = "FramaAngle_shiftReverse";        // 85
headerParams[index++] = "Frama5Angle_shiftCrossReverse";  // 86
headerParams[index++] = "BBFrama_shiftTrend";             // 87
headerParams[index++] = "gBBgap5_Volatility_delta";       // 88
headerParams[index++] = "BBgap_Volatility_delta";         // 89
headerParams[index++] = "BBgap5";                         // 90
headerParams[index++] = "BBgapMetrics";                   // 91
headerParams[index++] = "BBgap";                          // 92
headerParams[index++] = "BBgap5_Expansion";               // 93
headerParams[index++] = "BBgap_Expansion";                // 94
headerParams[index++] = "BBgap_PriceRatio";               // 95
headerParams[index++] = "segmentSize";                    // 96
headerParams[index++] = "BB2deltaR";                      // 97
headerParams[index++] = "topBB2";                         // 98
headerParams[index++] = "botBB2";                         // 99
headerParams[index++] = "topBB1";                         // 100
headerParams[index++] = "botBB1";                         // 101
headerParams[index++] = "topBB2delta";                    // 102
headerParams[index++] = "botBB2delta";                    // 103
headerParams[index++] = "gRVIproc";                       // 104
headerParams[index++] = "RVILine_Adelta";                 // 105
headerParams[index++] = "RVIScore";                       // 106
headerParams[index++] = "Fractal5Type";                   // 107
headerParams[index++] = "FractalType";                    // 108
headerParams[index++] = "lastFractal_Low[1]";             // 109
headerParams[index++] = "lastFractal_Low[0]";             // 110
headerParams[index++] = "lastFractal_High[1]";            // 111
headerParams[index++] = "lastFractal_High[0]";            // 112
headerParams[index++] = "lastfractal_HighIndex";          // 113
headerParams[index++] = "lastfractal_LowIndex";           // 114
headerParams[index++] = "fractalHigh5_delta";             // 115
headerParams[index++] = "fractalLow5_delta";              // 116
headerParams[index++] = "fractalHigh_delta";              // 117
headerParams[index++] = "fractalLow_delta";               // 118
headerParams[index++] = "DeM5Proc";                       // 119
headerParams[index++] = "DeMProc";                        // 120
headerParams[index++] = "DeM5Score";                      // 121
headerParams[index++] = "DeMScore";                       // 122
headerParams[index++] = "DeMdelta";                       // 123
headerParams[index++] = "DeM5Angle";                      // 124
headerParams[index++] = "DeMAngle";                       // 125
headerParams[index++] = "DeMCurrentPrice";                // 126
headerParams[index++] = "DeM_trendShiftResult";           // 127
headerParams[index++] = "midBBdelta";                     // 128
headerParams[index++] = "FraDeMdelta";                    // 129
headerParams[index++] = "WaveHigh";                       // 130
headerParams[index++] = "WaveLow";                        // 131
headerParams[index++] = "WavePos";                        // 132
headerParams[index++] = "WaveNeg";                        // 133
headerParams[index++] = "barPricedelta";                  // 134
headerParams[index++] = "ATRScore";                       // 135
headerParams[index++] = "ATRCurrent";                     // 136
headerParams[index++] = "ATRPriceRatio";                  // 137
headerParams[index++] = "ATRdelta";                       // 138
headerParams[index++] = "midBBframadelta_Vector";         // 139
headerParams[index++] = "midBBframadelta_V_TimeDiff";     // 140
headerParams[index++] = "BBFrdeltaRatio";                 // 141
headerParams[index++] = "BBFrdeltaRatio_TimeDiff";        // 142
headerParams[index++] = "FraRVILine_Adelta";              // 143
headerParams[index++] = "gFradelta_gBBgap_Expansion";     // 144
headerParams[index++] = "P2barMid";                       // 145
headerParams[index++] = "gPbarHigh";                      // 146
headerParams[index++] = "gPbarLow";                       // 147
headerParams[index++] = "TimeLocal";                      // 148





//values array parameter
ArrayResize(valueParams, 152);
index = 0;
// Assuming valueParams is a string array and index is declared and initialized
valueParams[index++] = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);    // 1
valueParams[index++] = gsymbol;                                                 // 2
valueParams[index++] = DoubleToString(gaskPrice);                               // 3
valueParams[index++] = DoubleToString(gCurrentPrice);                           // 4
valueParams[index++] = IntegerToString(barCount);                               // 5
valueParams[index++] = isRANGE ? "1" : "0";                                     // 6
valueParams[index++] = isRange_BB ? "1" : "0";                                  // 7
valueParams[index++] = isRange_Frama ? "1" : "0";                               // 8
valueParams[index++] = isTREND_Up ? "1" : "0";                                  // 9
valueParams[index++] = isTREND_Down ? "1" : "0";                                // 10
valueParams[index++] = isTrend_TailUp ? "1" : "0";                              // 11
valueParams[index++] = isTrend_TailDown ? "1" : "0";                            // 12
valueParams[index++] = isTrend_BBUp ? "1" : "0";                                // 13
valueParams[index++] = isTrend_FramaUp ? "1" : "0";                             // 14
valueParams[index++] = isTrend_BBDown ? "1" : "0";                              // 15
valueParams[index++] = isTrend_FramaDown ? "1" : "0";                           // 16
valueParams[index++] = isTrend_DeMUp  ? "1" : "0";                              // 17
valueParams[index++] = isTrend_DeMDown  ? "1" : "0";                            // 18
valueParams[index++] = isREVERSE_Up ? "1" : "0";                                // 19
valueParams[index++] = isREVERSE_Down ? "1" : "0";                              // 20
valueParams[index++] = IntegerToString(upTriggerIdentifier);                    // 21
valueParams[index++] = IntegerToString(downTriggerIdentifier);                  // 22
valueParams[index++] = isReverse_TotalScoreBinaryUp ? "1" : "0";
valueParams[index++] = isReverse_TotalScoreBinaryDown ? "1" : "0";
valueParams[index++] = isReverse_BB2deltaR_Up ? "1" : "0";
valueParams[index++] = isReverse_BB2deltaR_Down ? "1" : "0";
valueParams[index++] = isReverse_TailUp ? "1" : "0";                            // 23
valueParams[index++] = isReverse_TailDown ? "1" : "0";                          // 24
valueParams[index++] = isReverse_FractStochUp ? "1" : "0";                      // 25
valueParams[index++] = isReverse_FractStochDown ? "1" : "0";                    // 26
valueParams[index++] = isReverse_DeMUp ? "1" : "0";                             // 27
valueParams[index++] = isReverse_DeMDown ? "1" : "0";                           // 28
valueParams[index++] = isReverse_BBUp ? "1" : "0";                              // 29
valueParams[index++] = isReverse_FramaUp ? "1" : "0";                           // 30
valueParams[index++] = isReverse_BBDown ? "1" : "0";                            // 31
valueParams[index++] = isReverse_FramaDown ? "1" : "0";                         // 32
valueParams[index++] = isReverse_PriceIndexUp ? "1" : "0";                      // 33
valueParams[index++] = isReverse_PriceIndexDown ? "1" : "0";                    // 34
valueParams[index++] = isaddScalp_FractDeMUp ? "1" : "0";                       // 35
valueParams[index++] = isaddScalp_FractDeMDown ? "1" : "0";                     // 36
valueParams[index++] = isAddScalp_Up ? "1" : "0";                               // 37
valueParams[index++] = isAddScalp_Down ? "1" : "0";                             // 38
valueParams[index++] = DoubleToString(Frama5Index);                             // 39
valueParams[index++] = IntegerToString(FramaIndex);                             // 40
valueParams[index++] = IntegerToString(gPrice5Index);                           // 41
valueParams[index++] = IntegerToString(gPriceIndex);                            // 42
valueParams[index++] = DoubleToString(gTotalScore);                             // 43
valueParams[index++] = DoubleToString(TotalScoreBinary);                        // 44
valueParams[index++] = isTotalScoreBinary_Up ? "1" : "0";                       // 45
valueParams[index++] = isTotalScoreBinary_Down ? "1" : "0";                     // 46
valueParams[index++] = DoubleToString(BBTopBot_Frama_delta_Vector);             // 47
valueParams[index++] = DoubleToString(NormalizeDouble(gNoOfSegments, 2));       // 48
valueParams[index++] = DoubleToString(gPricedelta);                             // 49
valueParams[index++] = DoubleToString(HighTail);                                // 50
valueParams[index++] = DoubleToString(LowTail);                                 // 51
valueParams[index++] = DoubleToString(HighLowTailDiff);                         // 52
valueParams[index++] = IntegerToString(gTailScore);                             // 53
valueParams[index++] = IntegerToString(finalTailScore);                         // 54
valueParams[index++] = DoubleToString(gFramaCurrentPrice);                      // 55
valueParams[index++] = IntegerToString(gFramaScore);                            // 56
valueParams[index++] = IntegerToString(gFrama_PricePos);                        // 57
valueParams[index++] = DoubleToString(gFrama5delta);                            // 58
valueParams[index++] = DoubleToString(gFramadelta);                             // 59
valueParams[index++] = DoubleToString(gFrama5Angle);                            // 60
valueParams[index++] = DoubleToString(gFramaAngle);                             // 61
valueParams[index++] = DoubleToString(gPbar5Cross);                             // 62
valueParams[index++] = DoubleToString(gPbarCross);                              // 63
valueParams[index++] = DoubleToString(gP2barCross);                             // 64
valueParams[index++] = IntegerToString(gStoch5Score);                           // 65
valueParams[index++] = IntegerToString(gStochScore);                            // 66
valueParams[index++] = DoubleToString(gStoch_level);                            // 67
valueParams[index++] = gStoch5Xover;                                            // 68
valueParams[index++] = gStochXover;                                             // 69
valueParams[index++] = IntegerToString(gBB5_Proc);                              // 70
valueParams[index++] = IntegerToString(gBB_Proc);                               // 71
valueParams[index++] = (string)gmidBBTREND;                                     // 72
valueParams[index++] = DoubleToString(midBB5);                                  // 73
valueParams[index++] = DoubleToString(gmidBB);                                  // 74
valueParams[index++] = DoubleToString(midBB5_Angle);                            // 75
valueParams[index++] = DoubleToString(midBB_Angle);                             // 76
valueParams[index++] = DoubleToString(gtopBB2Angle);                            // 77
valueParams[index++] = DoubleToString(gbotBB2Angle);                            // 78
valueParams[index++] = DoubleToString(BB5Angle_shiftTrend);                     // 79
valueParams[index++] = DoubleToString(BBAngle_shiftTrend);                      // 80
valueParams[index++] = DoubleToString(BB5Angle_shiftCrossReverse);              // 81
valueParams[index++] = DoubleToString(BBAngle_shiftCrossReverse);               // 82
valueParams[index++] = DoubleToString(Frama5Angle_shiftTrend);                  // 83
valueParams[index++] = DoubleToString(FramaAngle_shiftTrend);                   // 84
valueParams[index++] = DoubleToString(FramaAngle_shiftReverse);                 // 85
valueParams[index++] = DoubleToString(Frama5Angle_shiftCrossReverse);           // 86
valueParams[index++] = DoubleToString(BBFrama_shiftTrend);                      // 87
valueParams[index++] = DoubleToString(gBBgap5_Volatility_delta);                // 88
valueParams[index++] = DoubleToString(gBBgap_Volatility_delta);                 // 89
valueParams[index++] = DoubleToString(gBBgap5);                                 // 90
valueParams[index++] = DoubleToString(BBgapMetrics);                            // 91
valueParams[index++] = DoubleToString(gBBgap);                                  // 92
valueParams[index++] = DoubleToString(gBBgap5_Expansion);                       // 93
valueParams[index++] = DoubleToString(gBBgap_Expansion);                        // 94
valueParams[index++] = DoubleToString(gBBgapPriceRatio);                        // 95
valueParams[index++] = DoubleToString(gsegmentSize);                            // 96
valueParams[index++] = DoubleToString(gBB2deltaR);                              // 97
valueParams[index++] = DoubleToString(gtopBB2);                                 // 98
valueParams[index++] = DoubleToString(gbotBB2);                                 // 99
valueParams[index++] = DoubleToString(gtopBB1);                                 // 100
valueParams[index++] = DoubleToString(gbotBB1);                                 // 101
valueParams[index++] = DoubleToString(gtopBB2delta);                            // 102
valueParams[index++] = DoubleToString(gbotBB2delta);                            // 103
valueParams[index++] = gRVIproc;                                                // 104
valueParams[index++] = DoubleToString(gRVILine_Adelta);                         // 105
valueParams[index++] = IntegerToString(gRVIScore);                              // 106
valueParams[index++] = IntegerToString(gfractal5Type);                          // 107
valueParams[index++] = IntegerToString(gfractalType);                           // 108
valueParams[index++] = DoubleToString(glastFractal_Low[1]);                     // 109
valueParams[index++] = DoubleToString(glastFractal_Low[0]);                     // 110
valueParams[index++] = DoubleToString(glastFractal_High[1]);                    // 111
valueParams[index++] = DoubleToString(glastFractal_High[0]);                    // 112
valueParams[index++] = IntegerToString(lastfractal_HighIndex);                  // 113
valueParams[index++] = IntegerToString(lastfractal_LowIndex);                   // 114
valueParams[index++] = DoubleToString(fractalHigh5_delta);                      // 115
valueParams[index++] = DoubleToString(fractalLow5_delta);                       // 116
valueParams[index++] = DoubleToString(fractalHigh_delta);                       // 117
valueParams[index++] = DoubleToString(fractalLow_delta);                        // 118
valueParams[index++] = gDeM5Proc;                                               // 119
valueParams[index++] = gDeMProc;                                                // 120
valueParams[index++] = IntegerToString(gDeM5Score);                             // 121
valueParams[index++] = IntegerToString(gDeMScore);                              // 122
valueParams[index++] = DoubleToString(gDeMdelta);                               // 123
valueParams[index++] = DoubleToString(DeM5Angle);                               // 124
valueParams[index++] = DoubleToString(DeMAngle);                                // 125
valueParams[index++] = DoubleToString(gDeMCurrentPrice);                        // 126
valueParams[index++] = DoubleToString(DeM_trendShiftResult);                    // 127
valueParams[index++] = DoubleToString(gmidBBdelta);                             // 128
valueParams[index++] = DoubleToString(gFraDeMdelta);                            // 129
valueParams[index++] = DoubleToString(gWaveH);                                  // 130
valueParams[index++] = DoubleToString(gWaveL);                                  // 131
valueParams[index++] = DoubleToString(gcount_WaveUp);                           // 132
valueParams[index++] = DoubleToString(gcount_WaveDown);                         // 133
valueParams[index++] = DoubleToString(gbarPricedelta);                          // 134
valueParams[index++] = IntegerToString(gATRScore);                              // 135
valueParams[index++] = DoubleToString(gATRCurrent);                             // 136
valueParams[index++] = DoubleToString(gATRPriceRatio);                          // 137
valueParams[index++] = DoubleToString(gATRdelta);                               // 138
valueParams[index++] = DoubleToString(gmidBBframadelta_Vector);                 // 139
valueParams[index++] = DoubleToString(gmidBBframadelta_V_TimeDiff);             // 140
valueParams[index++] = DoubleToString(gBBFrdeltaRatio);                         // 141
valueParams[index++] = DoubleToString(gBBFrdeltaRatio_TimeDiff);                // 142
valueParams[index++] = DoubleToString(gFraRVILine_Adelta);                      // 143
valueParams[index++] = DoubleToString(gFradelta_gBBgap_Expansion);              // 144
valueParams[index++] = DoubleToString(gP2barMid);                               // 145
valueParams[index++] = DoubleToString(gPbarHigh);                               // 146
valueParams[index++] = DoubleToString(gPbarLow);                                // 147
valueParams[index++] = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES);     // 148


// Call the function to write actual data
   FnWriteFile(gfhandle);

  }//end of OnTimer


//+-----------------------------------+
// Write To Excel Function
//+-----------------------------------+
#property strict
//+-----------------------------------+
// Declare INVALID_DOUBLE_VALUE Constant
//+-----------------------------------+
const double INVALID_DOUBLE_VALUE = -1.0;

//+-----------------------------------+
// Write to File Function
//+-----------------------------------+


void FnWriteFile( int fhandle)           
    {         

    // Step 3: Check if file exists. If it does, then proceed to write the values since the headers already exist, it can be skipped. 
   
    if(FileIsExist(fileName, 1))
     {
      //check if file exist within the local directory.
      fhandle=FileOpen(fileName,FILE_READ|FILE_WRITE|FILE_CSV, "\t");
    
          if (fhandle == INVALID_HANDLE) 
            { Print("Error: Failed to open the file: ", fileName);
              return;
            }
            FileSeek(fhandle, 0, SEEK_END);

          // Concatenate value elements
          string valueRow = "";
          for (int i = 0; i < ArraySize(valueParams); i++) 
            {
              valueRow += valueParams[i];
              if (i < ArraySize(valueParams) - 1) valueRow += "\t"; // Add comma except for the last element
            }      
    // Write value row to file
     FileWrite(fhandle, valueRow);
            
     FileFlush(fhandle);
     FileClose(fhandle);

   }
    //if file does not exist, create it and add Headers
   else  
     {
         //Check if file exists and is properly opened
         fhandle=FileOpen(fileName,FILE_READ|FILE_WRITE|FILE_CSV, "\t");  
               if(fhandle==INVALID_HANDLE)
                 {
                  Alert(fileName);
                  Alert(_Symbol+"   Error opening file");
                  return;
                 }
               FileSeek(fhandle, 0, SEEK_END);
      
         // Concatenate header elements
          string headerRow = "";
          for (int i = 0; i < ArraySize(headerParams); i++) 
            {
              headerRow += headerParams[i];
              if (i < ArraySize(headerParams) - 1) headerRow += "\t"; // Add comma except for the last element
            }
          // Write header row to file
          FileWrite(fhandle, headerRow);         
          
         
         // Concatenate value elements
         string valueRow = "";
         for (int i = 0; i < ArraySize(valueParams); i++) {
           valueRow += valueParams[i];
           if (i < ArraySize(valueParams) - 1) valueRow += "\t"; // Add comma except for the last element
    }
    
          // Write value row to file
          FileWrite(fhandle, valueRow);     
               FileFlush(fhandle);//in order not to have a need to close the file. since WritePnL is coming next to write to the same excel file.
               FileClose(fhandle);
           }
   
   }



//=================================================================================================================================+        
//Function :Compare7  : Check for 7 continuous (+) or (-) 5-sec. Time increment values in order to decide reversal or continuation
//=================================================================================================================================+   

string Momentum7(double item, double reference, double &array7[], char &countPos, char &countNeg, double midBBdelta)
   {  //for array7
   ArrayResize(array7, 7);
   ArraySetAsSeries(array7, true);
   
   static char count; string reverseAlert;
   
   
   //populate array once only
   if (count <7) {array7[count] = item; count+=1;} 
   
   //reset loop
   else if (count ==7) 
   { countPos=0; countNeg =0;
     //count (+) & (-)
     for(char i=0; i<7; i++) 
         {
         if (array7[i] >0) {countPos+=1;} 
         else if (array7[i] <0) countNeg +=1;
         }      
      //reference following Trend
      if ( (countPos ==7 || array7[6] >0  ) && countPos > countNeg && (reference >0 && midBBdelta >0) ) {reverseAlert = "TREND LONG";} 
      else if ( (countNeg ==7 || array7[6] <0  ) && countNeg > countPos && (reference >0 && midBBdelta >0) ) {reverseAlert = "REVERSE SHORT";} 
      
      else if ((countPos ==7 || array7[6] >0  ) && countPos > countNeg && (reference >0  && midBBdelta <0)  ) {reverseAlert = "TREND SHORT";} 
      else if ((countNeg ==7 || array7[6] <0  ) && countNeg >countPos  && (reference >0  && midBBdelta <0)  ) {reverseAlert = "REVERSE LONG";}                   
      
      //reference not following Trend
      else if ( (countNeg == 7 || array7[6] <0  ) && countNeg > countPos && (reference <0 && midBBdelta >0) ) {reverseAlert = "REVERSE SHORT";}
      else if ( (countNeg == 7 || array7[6] <0  ) && countNeg > countPos && (reference <0 && midBBdelta <0) ) {reverseAlert = "REVERSE LONG";}  
      
      //for Reversals ! seems to work like magic.
      else if ((countPos ==7 || array7[6] >0  ) && countPos >countNeg  && (reference <0  && midBBdelta >0)  ) {reverseAlert = "TREND_LONG";} 
      else if ((countPos ==7 || array7[6] >0  ) && countPos > countNeg && (reference <0  && midBBdelta <0)  ) {reverseAlert = "TREND_SHORT";} 
     
      else {reverseAlert = "AMBIVALENT";}
   
     //re-arrange array and remove the earliest value to allow for a new one.
    for(char i=1; i<7; i++) 
         {array7[i-1] = array7[i];}
     array7[6] = item;     
   }
   return( reverseAlert);
   }


//==============================
string CompareBBgapPriceR(double item, double reference, double &array7[], char &countPos, char &countNeg)
   {  //for array7
             ArrayResize(array7, 7);
            ArraySetAsSeries(array7, true);
           
            static char count; string reverseAlert;
            
            
            //populate array once only
            if (count <7) {array7[count] = item; count+=1;} 
            
            //reset loop
            else if (count ==7)                //when 'if''was 'while' seems positive pnl
               { countPos=0; countNeg =0;
                 //count (+) & (-)
                 for(char i=0; i<7; i++) 
                     {
                     if (array7[i] >0) {countPos+=1;} 
                     else if (array7[i] <0) countNeg +=1;
                      }      
                  if ((countPos ==7 || array7[6] >0) && countPos > countNeg   ) {reverseAlert = "LONG";} 
                  else if ((countNeg == 7|| array7[6] <0) && countNeg > countPos ) {reverseAlert = "SHORT";} 
                  else {reverseAlert = "AMBIVALENT";}
            
                 //re-arrange array and remove the earliest value to allow for a new one.
                for(char i=1; i<7; i++) 
                     {array7[i-1] = array7[i];}
                 array7[6] = item;     
               }
             return( reverseAlert);
         }
         
         
        
//+------------------------------------------------------------------+
//| FramaDeMmidBB relationship                                            |
//+------------------------------------------------------------------+

bool FramaDeMmidBB_Long (double Framadelta, double FramaCurrentPrice, double midBB, double midBBdelta, string DeMProc)
{ bool x=0;
   if (midBBdelta >4 && Framadelta >6.5
         && (DeMProc == "DeMSHORT" || DeMProc == "DeM_NEUTRAL"|| DeMProc == "DeMLONG")) {x=1;} //strong magnitude
   else if (midBBdelta >0.7 && (Framadelta >0.7 || gBBFrdeltaRatio >1.25 ) 
         && FramaCurrentPrice < midBB 
         && (DeMProc == "DeMSHORT" || DeMProc == "DeM_NEUTRAL"|| DeMProc == "DeMLONG")
       ) {x=1;} //strong magnitude
   else if ((Framadelta <4 && FramaCurrentPrice > midBB) && DeMProc == "DeMSHORT"){x=0;}
   return x;
   }

bool FramaDeMmidBB_Short (double Framadelta, double FramaCurrentPrice, double midBB, double midBBdelta, string DeMProc)
{
  bool x=0;
   if (midBBdelta <-4 && Framadelta <-6.5 
         && (DeMProc == "DeMLONG" || DeMProc == "DeM_NEUTRAL" || DeMProc == "DeMSHORT")) {x=1;} //strong magnitude
   else if (midBBdelta <-0.7 && (Framadelta <-0.7 || gBBFrdeltaRatio >1.25) 
            && FramaCurrentPrice > midBB 
            && (DeMProc == "DeMLONG" || DeMProc == "DeM_NEUTRAL" || DeMProc == "DeMSHORT")
            ) {x=1;} //potential strong magnitude
  else if ((Framadelta >-4 && FramaCurrentPrice < midBB) && DeMProc == "DeMLONG"){x=0;}
   return x;
   }
   
//+------------------------------------------------------------------+
//| FramaRVImidBB relationship                                            |
//+------------------------------------------------------------------+
bool FramaRVImidBB_Long (double midBBdelta, double midBB, double Framadelta, double RVILine_A, 
               double FramaCurrentPrice, string RVIproc,int RVIScore )
 {bool x=0;
   //RVIScore is not important as direction is already dictated by strong magnitude of both mid & Framadelta
   if ( midBBdelta >5.5 && Framadelta >6.5 && RVILine_A <0.35 )     {x=1;}
   //RVIScore needs to be controlled when Frama magnitude is not strong
   else if (FramaCurrentPrice < midBB && midBBdelta >0.7 && Framadelta >0.7 && RVILine_A <0.35       
            && (RVIproc == "RVI_ReverseUp" || RVIproc == "RVI_startTrendUp" || RVIproc == "RVI_TrendUp"))  {x=1;}  
   else if ( midBBdelta >5.5 && Framadelta >4.5 && FramaCurrentPrice < midBB && RVILine_A >0.35) {x=1;}
   
   //lowFrama
   else if ( (midBBdelta >1 && Framadelta >0.3 && FramaCurrentPrice < midBB && RVILine_A <0.35) 
            && (RVIproc == "RVI_startTrendDown" || RVIproc == "RVI_startTrendDown") ){x=1;}
   //false
   else if ( midBBdelta >5.5 && Framadelta >4.5 && FramaCurrentPrice > midBB && RVILine_A >0.35) {x=0;}
   return x;
   }
  
  
  bool FramaRVImidBB_Short (double midBBdelta, double midBB, double Framadelta, double RVILine_A, 
               double FramaCurrentPrice, string RVIproc,int RVIScore )
 {bool x=0;
  //RVIScore is not important as direction is already dictated by strong magnitude of both mid & Framadelta
   if ( midBBdelta <-5.5 && Framadelta <-6.5 && RVILine_A >-0.35 )     {x=1;}
   //RVIScore needs to be controlled
   else if (FramaCurrentPrice > midBB && midBBdelta <-0.7 && Framadelta <-0.7 && RVILine_A >-0.35       
            && (RVIproc == "RVI_ReverseUp" || RVIproc == "RVI_startTrendUp" || RVIproc == "RVI_TrendUp"))  {x=1;}  
   else if ( midBBdelta <-5.5 && Framadelta <-4.5 && FramaCurrentPrice > midBB && RVILine_A <-0.35) {x=1;}
   
   //lowFrama
   else if ( (midBBdelta <-1 && Framadelta <-0.3 && FramaCurrentPrice > midBB && RVILine_A >-0.35) 
            && (RVIproc == "RVI_startTrendDown" || RVIproc == "RVI_startTrendDown") ){x=1;}
   //false         
   else if ( midBBdelta <-5.5 && Framadelta <-4.5 && FramaCurrentPrice < midBB && RVILine_A <-0.35) {x=0;}           
   return x;
   }
    
    
    
//=========================================================================================+        
//Function : Wave High & Low Array Calculation  : Calculate Wave High/ Low + Magnet level
//=========================================================================================+     
      //try to use iLowest/ iHighest to calculate Bars and only when it is needed, to conserve CPU.
  double FnMagnet (double paskPrice, double pCurrentPrice, double &pPBarHnLarray[], double &pWaveH, double &pWaveL, 
  char pcountPrevious, char palertswitchPrevious) 
   {  
      double MagnetLevel=0;
      static char countPrevious2;
      if ( palertswitchPrevious == 87 || palertswitchPrevious == -88 )  
         {countPrevious2 = pcountPrevious;}
        
      
      //revert to zero when Wave is over
      if ( pcountPrevious != countPrevious2 )  { pPBarHnLarray[0] = 0; pPBarHnLarray[1] = 0;}
         else 
         {
         //wave Low  
         if (pCurrentPrice < pPBarHnLarray[0]) 
            {
            //pPBarHnLarray[0] = pCurrentPrice;
            //pWaveL =  pPBarHnLarray[0];
            pWaveL = pCurrentPrice;
            countPrevious2 = pcountPrevious;
            }
         //wave High  
         else if (paskPrice > pPBarHnLarray[1]) 
            {
            //pPBarHnLarray[1] = paskPrice;
            //pWaveH = pPBarHnLarray[1] ;
            pWaveH = paskPrice;
            countPrevious2 = pcountPrevious;
            }
        
         //calculate
         MagnetLevel = (pWaveH + pWaveL)/2 ;
         }
         
    return (NormalizeDouble(MagnetLevel, _Digits)); 
   }    
   
   
//+------------------------------------------------------------------+
//| Returns true if a new bar has appeared for a symbol/period pair
//| This function will only check if a new bar has been formed.  |
//+------------------------------------------------------------------+
// Define a struct to hold the period and last bar time
struct PeriodBarTime {
    ENUM_TIMEFRAMES period;
    datetime last_time;
};
// Array to store the last bar time for each period
PeriodBarTime periodsBarTimes[];
bool isNewBar(ENUM_TIMEFRAMES period) {
    // Get the current bar's opening time
    datetime lastbar_time = (datetime)SeriesInfoInteger(Symbol(), period, SERIES_LASTBAR_DATE);

    // Search for the period in the array
    for (int i = 0; i < ArraySize(periodsBarTimes); i++) {
        if (periodsBarTimes[i].period == period) {
            // If a new bar is detected, update the last time and return true
            if (periodsBarTimes[i].last_time != lastbar_time) {
                periodsBarTimes[i].last_time = lastbar_time; // Update last time for this period
                return true;
            }
            return false; // No new bar
        }
    }

    // If period not found in array, add it with the current time
    PeriodBarTime newEntry;
    newEntry.period = period;
    newEntry.last_time = lastbar_time;
    ArrayResize(periodsBarTimes, ArraySize(periodsBarTimes) + 1);
    periodsBarTimes[ArraySize(periodsBarTimes) - 1] = newEntry;

    return false; // No new bar on first call
}

/*
bool isNewBar(ENUM_TIMEFRAMES period) {
    static datetime last_time = 0;  // Store the time of the last bar

    // Get the current bar's opening time
    datetime lastbar_time = (datetime)SeriesInfoInteger(Symbol(), period, SERIES_LASTBAR_DATE);

    // If first call, store the time and return false
    if (last_time == 0) {
    
        last_time = lastbar_time;
        return false;
    }

    // If a new bar is detected, update the last time and return true
    if (last_time != lastbar_time) {
        last_time = lastbar_time;
        return true;
    }

    // If we passed to this line, then the bar is not new; return false
    return false;
}

*/

//+------------------------------------------------------------------------------------------+
//| Function : countBarsBasedOnFrama:                                
//| This function will count the number of bars as long as Frama_PricePos has not changed.  
//+------------------------------------------------------------------------------------------+

void countBarsBasedOnFrama(char PbarCross)
  {

// Reset bar count if the Frama_PricePos changes
   if(previousFramaPricePos != gFrama_PricePos || PbarCross ==0)
     {
      // Reset barCount when gFrama_PricePos changes
      barCount = 0;
      previousFramaPricePos = gFrama_PricePos;
     }
   else
     {
      // Increment bar count if gFrama_PricePos has not changed
      barCount++;
     }
  }    