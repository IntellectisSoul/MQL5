//+------------------------------------------------------------------+
//|                                              Jim DXY_Signals.mqh |
//|                                             Copyright 2025, StJo |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#ifndef JIM_DXY_SIGNALS_MQH
#define JIM_DXY_SIGNALS_MQH
/*+------------------------------------------------------------------+
TRENDS : 
Frama_PricePos
FramaScore
FractalType


REVERSALS :  find a way to indicate exhaustion for TRENDS
isReverse_BBgap_VolDown : seems accurate.

isReverse_BB2deltaR_Down : looks ok and always followed by isReverse_TotalScoreBinaryDown
isReverse_TotalScoreBinaryDown : 



+------------------------------------------------------------------+
*/
/*
double DXY_FramaCurrentPrice=0;
double DXY_Framadelta=0;
 static double DXY_PreviousPrice;
 double DXY_FramaPrevious2Price;
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
//A. Obtain Current Price of Instrument
//+XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX+
  MqlTick DXY_SPrice; //create object  DXY_SPrice type with MqlTick structure
   SymbolInfoTick(DXY,  DXY_SPrice);
   gaskPrice = NormalizeDouble(SPrice.ask, _Digits);
   DXY_CurrentPrice = NormalizeDouble(DXY_SPrice.bid, _Digits);
   DXY_PriceNormalized = NormalizeDouble(((DXY_CurrentPrice + DXY_askPrice)/2),_Digits);

  int DXY_FramaScore = FramaCheckSignal(DXY, PERIOD_M15, DXY_PriceNormalized, DXY_FramaCurrentPrice,
                                     DXY_FramaPreviousPrice, DXY_FramaPrevious2Price, DXY_Framadelta,
                                     DXY_Frama_PricePos, DXY_PbarOpen, DXY_PbarClose, DXY_PbarCross, DXY_P2barOpen, DXY_P2barClose, DXY_P2barCross,
                                     DXY_midBB, DXY_topBB1, DXY_FramaIndex, DXY_FramaAngle);
                                     
                                     
   */      
   
   //+------------------------------------------------------------------+
//| Jim_DXY_Signals.mqh                                              |
//+------------------------------------------------------------------+
#property copyright "StJo"
#property strict


#include "Jim_DeltaToAngle.mqh"
#include "Jim BBCheckSignal.mqh"  // Include the file containing BBCheckSignal, getFrama_Index, getPrice_Index, BB_Trend_Proc, and CheckDir
#include "Jim FRAMACheckSignal.mqh" // to use getFrama_Index()
#include "Jim Fractal.mqh"
#include "Jim LogSymbolInfo.mqh"
//+------------------------------------------------------------------+
//| DXY Global Variables                                             |
//+------------------------------------------------------------------+
// FrAMA variables
double DXY_FramaArray[];
int DXY_Frama_handle = INVALID_HANDLE;
double DXY_FramaCurrentPrice = 0;
double DXY_FramaPreviousPrice = 0;
double DXY_FramaPrevious2Price = 0;
double DXY_Framadelta = 0;
int DXY_Frama_PricePos = 0;
double DXY_FramaAngle = 0;
int DXY_FramaIndex = 0;
int DXY_FramaScore = 0;
double DXY_PbarOpen = 0, DXY_PbarClose = 0, DXY_P2barOpen = 0, DXY_P2barClose = 0;
char DXY_PbarCross = 0, DXY_P2barCross = 0;

// BB variables
double DXY_midBBArray[], DXY_topBB1Array[], DXY_botBB1Array[], DXY_topBB2Array[], DXY_botBB2Array[];
int DXY_handle_iBands_StdDev1_M15 = INVALID_HANDLE;
int DXY_handle_iBands_StdDev2_M15 = INVALID_HANDLE;
double DXY_midBB = 0, DXY_midBBPrevious = 0, DXY_topBB1 = 0, DXY_topBB1Top = 0, DXY_topBB1Bot = 0;
double DXY_botBB1 = 0, DXY_botBB1Top = 0, DXY_botBB1Bot = 0, DXY_topBB2 = 0, DXY_botBB2 = 0;
double DXY_topBB2previous = 0, DXY_botBB2previous = 0;
double DXY_midBBdelta = 0, DXY_topBB2delta = 0, DXY_botBB2delta = 0;
double DXY_BBgap = 0, DXY_BBgap_PriceRatio = 0, DXY_segmentSize = 0;
double DXY_BBgap_Volatility_delta = 0, DXY_topBB2Angle = 0, DXY_botBB2Angle = 0;
double DXY_Scalp_StdDev_top = 0, DXY_Scalp_StdDev_bot = 0, DXY_Scalp_StdDev_top2 = 0, DXY_Scalp_StdDev_bot2 = 0;
double DXY_BBgap_Expansion = 0, DXY_midBB_Angle = 0;
int DXY_PriceIndex = 0, DXY_barCount = 0, DXY_topBB1Dir = 0, DXY_botBB1Dir = 0;
char DXY_midBBTREND = 0;

// Fractal variables
double DXY_fractalHigh_delta = 0;
double DXY_fractalLow_delta = 0;
double DXY_lastFractal_High[2]; // Array to store fractal high history
double DXY_lastFractal_Low[2];  // Array to store fractal low history
int DXY_fractalType = 0;


// Price variables
double DXY_CurrentPrice = 0;
double DXY_askPrice = 0;
double DXY_PriceNormalized = 0;

//+------------------------------------------------------------------+
//| DXY_BBCheckSignal                                                |
//+------------------------------------------------------------------+
int DXY_BBCheckSignal(string symbol, ENUM_TIMEFRAMES period) {
   // Initialize Bollinger Bands handles if not already done
   if (DXY_handle_iBands_StdDev1_M15 == INVALID_HANDLE) {
      DXY_handle_iBands_StdDev1_M15 = iBands(symbol, period, 11, 0, 1.05, PRICE_CLOSE);
      if (DXY_handle_iBands_StdDev1_M15 < 0) {
           LogSymbolToFile("DXY: Failed to create iBands StdDev 1.05: " + IntegerToString(GetLastError()));
         return -1;
      }
   }
   if (DXY_handle_iBands_StdDev2_M15 == INVALID_HANDLE) {
      DXY_handle_iBands_StdDev2_M15 = iBands(symbol, period, 11, 0, 2.1, PRICE_CLOSE);
      if (DXY_handle_iBands_StdDev2_M15 < 0) {
          LogSymbolToFile("DXY: Failed to create iBands StdDev 2.1: " + IntegerToString(GetLastError()));
         return -1;
      }
   }

   // Copy Bollinger Bands data
   if (CopyBuffer(DXY_handle_iBands_StdDev1_M15, 0, 0, 12, DXY_midBBArray) <= 0) {
     LogSymbolToFile("DXY: Failed to copy midBB buffer: " + IntegerToString(GetLastError()));
      return -1;
   }
   ArraySetAsSeries(DXY_midBBArray, true);
   DXY_midBB = DXY_midBBArray[0];
   DXY_midBBPrevious = DXY_midBBArray[1];
   double midBBPrevious4th = DXY_midBBArray[4];
   DXY_midBBdelta = NormalizeDouble(((DXY_midBB - DXY_midBBPrevious) / DXY_midBBPrevious) * 10000, 3);
   DXY_midBB_Angle = DeltaToAngle(DXY_midBBdelta);

   // Determine BB trend
   if (DXY_midBBPrevious < midBBPrevious4th && DXY_midBB <= DXY_midBBPrevious) DXY_midBBTREND = -1;
   else if (DXY_midBBPrevious > midBBPrevious4th && DXY_midBB >= DXY_midBBPrevious) DXY_midBBTREND = 1;
   else DXY_midBBTREND = 0;

   // Top BB (StdDev 1.05 and 2.1)
   if (CopyBuffer(DXY_handle_iBands_StdDev1_M15, 1, 0, 2, DXY_topBB1Array) <= 0 ||
       CopyBuffer(DXY_handle_iBands_StdDev2_M15, 1, 0, 2, DXY_topBB2Array) <= 0) {
      LogSymbolToFile("DXY: Failed to copy top BB buffers: " + IntegerToString(GetLastError()));
      return -1;
   }
   ArraySetAsSeries(DXY_topBB1Array, true);
   ArraySetAsSeries(DXY_topBB2Array, true);
   DXY_topBB1 = NormalizeDouble(DXY_topBB1Array[0], _Digits);
   double topBB1previous = NormalizeDouble(DXY_topBB1Array[1], _Digits);
   DXY_topBB2 = NormalizeDouble(DXY_topBB2Array[0], _Digits);
   DXY_topBB2previous = NormalizeDouble(DXY_topBB2Array[1], _Digits);
   DXY_topBB2delta = NormalizeDouble((DXY_topBB2 - DXY_topBB2previous) / DXY_topBB2previous * 10000, 2);
   DXY_topBB2Angle = DeltaToAngle(DXY_topBB2delta);
   DXY_topBB1Dir = CheckDir(DXY_topBB1, topBB1previous);

   // Bottom BB (StdDev 1.05 and 2.1)
   if (CopyBuffer(DXY_handle_iBands_StdDev1_M15, 2, 0, 2, DXY_botBB1Array) <= 0 ||
       CopyBuffer(DXY_handle_iBands_StdDev2_M15, 2, 0, 2, DXY_botBB2Array) <= 0) {
      LogSymbolToFile("DXY: Failed to copy bottom BB buffers: " + IntegerToString(GetLastError()));
      return -1;
   }
   ArraySetAsSeries(DXY_botBB1Array, true);
   ArraySetAsSeries(DXY_botBB2Array, true);
   DXY_botBB1 = NormalizeDouble(DXY_botBB1Array[0], _Digits);
   double botBB1previous = NormalizeDouble(DXY_botBB1Array[1], _Digits);
   DXY_botBB2 = NormalizeDouble(DXY_botBB2Array[0], _Digits);
   DXY_botBB2previous = NormalizeDouble(DXY_botBB2Array[1], _Digits);
   DXY_botBB2delta = NormalizeDouble((DXY_botBB2 - DXY_botBB2previous) / DXY_botBB2previous * 10000, 2);
   DXY_botBB2Angle = DeltaToAngle(DXY_botBB2delta);
   DXY_botBB1Dir = CheckDir(DXY_botBB1, botBB1previous);

   // Segment size and Price Index
   DXY_segmentSize = NormalizeDouble((DXY_topBB2 - DXY_botBB2) / 8, _Digits);
   const double MIN_SEGMENT_SIZE = 0.00001;
   DXY_segmentSize = MathMax(DXY_segmentSize, MIN_SEGMENT_SIZE);
   DXY_PriceIndex = getPrice_Index(DXY_PriceNormalized, DXY_midBB, DXY_topBB1);

   // BB gap and volatility
   double BBgap_orig = DXY_topBB2 - DXY_botBB2;
   DXY_BBgap = NormalizeDouble((BBgap_orig / DXY_midBB) * 100, 3);
   double DXY_BBgap_PriceRatioPr = (DXY_topBB2previous - DXY_botBB2previous) / DXY_PriceNormalized;
   double DXY_BBgap_PriceRatioCr = (DXY_topBB2 - DXY_botBB2) / DXY_PriceNormalized;
   DXY_BBgap_Expansion = NormalizeDouble(DXY_BBgap_PriceRatioCr / DXY_BBgap_PriceRatioPr, 5);
   DXY_BBgap_PriceRatio = NormalizeDouble((DXY_BBgap / DXY_PriceNormalized) * 1000, 2);
   DXY_BBgap_Volatility_delta = NormalizeDouble(((DXY_BBgap_PriceRatioCr - DXY_BBgap_PriceRatioPr) / (DXY_BBgap_PriceRatioPr + 1e-10)) * 100, _Digits);

   // Additional BB calculations
   DXY_topBB1Top = NormalizeDouble(DXY_topBB1 + (DXY_segmentSize * 1.25), _Digits);
   DXY_topBB1Bot = NormalizeDouble(DXY_topBB1 - (DXY_segmentSize * 1.25), _Digits);
   DXY_botBB1Top = NormalizeDouble(DXY_botBB1 + (DXY_segmentSize * 1.25), _Digits);
   DXY_botBB1Bot = NormalizeDouble(DXY_botBB1 - (DXY_segmentSize * 1.25), _Digits);

   // BB Proclivity
   int BB_Proc = BB_Trend_Proc(DXY_BBgap_Expansion, DXY_topBB2Angle, DXY_midBB_Angle, DXY_botBB2Angle, DXY_BBgap, DXY_midBBTREND);
   return BB_Proc;
}


//+------------------------------------------------------------------+
//| DXY_FractalCheckSignal                                           |
//+------------------------------------------------------------------+
int DXY_FractalCheckSignal(string symbol, ENUM_TIMEFRAMES period) {
   DXY_fractalType = FractalCheckSignal(symbol, period, DXY_CurrentPrice, DXY_fractalHigh_delta, DXY_fractalLow_delta, DXY_lastFractal_High, DXY_lastFractal_Low);
   return DXY_fractalType;
}



//+------------------------------------------------------------------+
//| DXY_FramaCheckSignal                                             |
//+------------------------------------------------------------------+
int DXY_FramaCheckSignal(string symbol, ENUM_TIMEFRAMES period) {
   // Initialize FrAMA handle
   DXY_Frama_handle = iFrAMA(symbol, period, 11, 0, PRICE_CLOSE);
   ArraySetAsSeries(DXY_FramaArray, true);
   ArrayResize(DXY_FramaArray, 12);

   if (CopyBuffer(DXY_Frama_handle, 0, 0, 12, DXY_FramaArray) <= 0) {
       LogSymbolToFile("DXY: Error copying FRAMA buffer: " + IntegerToString(GetLastError()));
      return 0;
   }

   DXY_FramaCurrentPrice = NormalizeDouble(DXY_FramaArray[0], _Digits);
   DXY_FramaPreviousPrice = DXY_FramaArray[1];
   DXY_FramaPrevious2Price = DXY_FramaArray[2];
   DXY_Framadelta = NormalizeDouble(((DXY_FramaCurrentPrice - DXY_FramaPreviousPrice) / DXY_FramaPreviousPrice) * 10000, 3);
   DXY_FramaAngle = DeltaToAngle(DXY_Framadelta);
   DXY_FramaIndex = getFrama_Index(DXY_FramaCurrentPrice, DXY_midBB, DXY_topBB1);

   if (DXY_PriceNormalized < 0.00005) DXY_PriceNormalized = 0;
   if (DXY_PriceNormalized > DXY_FramaCurrentPrice) DXY_Frama_PricePos = 1;
   else if (DXY_PriceNormalized == DXY_FramaCurrentPrice) DXY_Frama_PricePos = 0;
   else DXY_Frama_PricePos = -1;

   // BarCross logic
   if (DXY_PbarOpen < DXY_FramaPreviousPrice && DXY_PbarClose > DXY_FramaPreviousPrice) DXY_PbarCross = 0;
   else if (DXY_PbarOpen > DXY_FramaPreviousPrice && DXY_PbarClose < DXY_FramaPreviousPrice) DXY_PbarCross = 0;
   else if (DXY_PbarClose > DXY_PbarOpen && DXY_PbarOpen > DXY_FramaPreviousPrice) DXY_PbarCross = 1;
   else if (DXY_PbarClose < DXY_PbarOpen && DXY_PbarOpen < DXY_FramaPreviousPrice) DXY_PbarCross = -1;
   else if (DXY_PbarClose > DXY_PbarOpen && DXY_PbarClose < DXY_FramaPreviousPrice) DXY_PbarCross = 2;
   else if (DXY_PbarClose < DXY_PbarOpen && DXY_PbarClose > DXY_FramaPreviousPrice) DXY_PbarCross = -2;
   else DXY_PbarCross = 0;

   if (DXY_P2barOpen < DXY_FramaPrevious2Price && DXY_P2barClose > DXY_FramaPrevious2Price) DXY_P2barCross = 0;
   else if (DXY_P2barOpen > DXY_FramaPrevious2Price && DXY_P2barClose < DXY_FramaPrevious2Price) DXY_P2barCross = 0;
   else if (DXY_P2barClose > DXY_P2barOpen && DXY_P2barOpen > DXY_FramaPrevious2Price) DXY_P2barCross = 1;
   else if (DXY_P2barClose < DXY_P2barOpen && DXY_P2barOpen < DXY_FramaPrevious2Price) DXY_P2barCross = -1;
   else if (DXY_P2barClose > DXY_P2barOpen && DXY_P2barClose < DXY_FramaPrevious2Price) DXY_P2barCross = 2;
   else if (DXY_P2barClose < DXY_P2barOpen && DXY_P2barClose > DXY_FramaPrevious2Price) DXY_P2barCross = -2;
   else DXY_P2barCross = 0;

   // FramaScore logic
   if (DXY_Framadelta > 0.007 && (DXY_Frama_PricePos == 1 || DXY_PbarCross >= 1 || DXY_P2barCross >= 1) && DXY_FramaIndex < 4) {
      DXY_FramaScore = 1;
   } else if (DXY_Framadelta < -0.007 && (DXY_Frama_PricePos == -1 || DXY_PbarCross <= -1 || DXY_P2barCross <= -1) && DXY_FramaIndex > -4) {
      DXY_FramaScore = -1;
   } else if (DXY_Framadelta < 0.007 && DXY_Framadelta > -0.007) {
      DXY_FramaScore = 0;
   } else {
      DXY_FramaScore = 0;
   }

   return DXY_FramaScore;
}

//+------------------------------------------------------------------+
//| DXY_UpdateSignals : this is required in order to "run" DXY checks |
//+------------------------------------------------------------------+
bool DXY_CheckSignal() {
   // Get DXY price
   MqlTick DXY_SPrice;
   if (!SymbolInfoTick("DXY", DXY_SPrice)) {
      LogSymbolToFile("DXY: Failed to get price data: " + IntegerToString(GetLastError()));
      return false;
   }
   DXY_askPrice = NormalizeDouble(DXY_SPrice.ask, _Digits);
   DXY_CurrentPrice = NormalizeDouble(DXY_SPrice.bid, _Digits);
   DXY_PriceNormalized = NormalizeDouble((DXY_askPrice + DXY_CurrentPrice) / 2, _Digits);

   // Get bar data for Pbar and P2bar
   double close[], open[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   if (CopyClose("DXY", PERIOD_M15, 0, 3, close) <= 0 || CopyOpen("DXY", PERIOD_M15, 0, 3, open) <= 0) {
      LogSymbolToFile("DXY: Failed to copy bar data: " + IntegerToString(GetLastError()));
      return false;
   }
   DXY_PbarOpen = open[1];
   DXY_PbarClose = close[1];
   DXY_P2barOpen = open[2];
   DXY_P2barClose = close[2];

   // Calculate BB signals
   int BB_Proc = DXY_BBCheckSignal("DXY", PERIOD_M15);
   if (BB_Proc == -1) return false;

   // Calculate FrAMA signals
   DXY_FramaScore = DXY_FramaCheckSignal("DXY", PERIOD_M15);

   // Calculate Fractal signals
   DXY_fractalType = DXY_FractalCheckSignal("DXY", PERIOD_M15);

   return true;
}
     

//+------------------------------------------------------------------+
//| DXY_BuySignal                                                    |
//+------------------------------------------------------------------+
bool DXY_DownSignal() {
   return (DXY_FramaScore == -1 && DXY_Frama_PricePos == -1 && 
           DXY_midBBTREND == -1 && DXY_fractalType == -1);
}

//+------------------------------------------------------------------+
//| DXY_SellSignal                                                   |
//+------------------------------------------------------------------+
bool DXY_UpSignal() {
   return (DXY_FramaScore == 1 && DXY_Frama_PricePos == 1 && 
           DXY_midBBTREND == 1 && DXY_fractalType == 1);
}
         
         
#endif               