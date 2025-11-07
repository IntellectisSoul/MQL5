//JS-Lim

//28.Oct.   : VIX comments updated and to be used.
//+----------------------------------------------------------------------------------------------------+
//| ATR : Measure of Volatility. Strength of Continuation. Mean Reversion.
//|     
//+----------------------------------------------------------------------------------------------------+
      
   
   int ATRCheckSignal(string symbol, double &ATRCurrent, string &pATRStrength, 
   double PriceNormalized, double &ATRPriceRatio, double &ATRdelta)export  
   //the "&" above allows variable to be an additional "return" or exported to be received by the caller of the function. 
     {
      //create a price array
      double MyPriceArray[];
      //double PriceNormalized = ((CurrentPrice+askPrice)/2);
      //define the ATR
      int ATRDefine = iATR(symbol,PERIOD_M15, 5);
      //sort the array
      ArraySetAsSeries(MyPriceArray, true);
      //retreive into memory buffer
      CopyBuffer(ATRDefine, 0,0,2, MyPriceArray);
      //get value of current candle
      ATRCurrent = NormalizeDouble(MyPriceArray[0], _Digits);
         //attempt to normalize across all instruments
      ATRPriceRatio = PriceNormalized / ATRCurrent; 
      
      double ATRPrevious = NormalizeDouble(MyPriceArray[1], _Digits);
         

     ATRdelta = NormalizeDouble(((ATRCurrent - ATRPrevious)/PriceNormalized)*100, 3);
     
     if (_Symbol == "US_TECH100")  
                  {   
                 // ATRdelta *=1;
                  //ATRPriceRatio /=10;
                  }
     else if (_Symbol == "USDSGD" || _Symbol == "USDCAD")  
                  {   
                  ATRdelta /=1000;
                  ATRPriceRatio /=100;
                  }
     else if (_Symbol == "GBPUSD")  
                  {   
                  ATRdelta /=1000;
                  ATRPriceRatio /=100;
                  }
                  
      else if (_Symbol == "DOLLAR_INDX")  
                  {   
                  ATRdelta /=10;
                  ATRPriceRatio /=100;
                  }
      else if (_Symbol == "GOLD")  
                  { 
                   ATRdelta *=10;
                  }
      else if (_Symbol == "CrudeOIL")  
                  { 
                   ATRPriceRatio *=10;
                  }

   //Check ATRScore
   int ATRScore;
   if (ATRCurrent<ATRPrevious) ATRScore =-1;
   else if (ATRCurrent>ATRPrevious) ATRScore =1;
   else ATRScore =0;
   
   //Find the max. and min. range values
   //https://www.mql5.com/en/forum/108481
/*
  //=================================================================================================================
   //Check for ATR_turn. ATRScorePrevious-aware. where ATRturn_Trend means to continue along direction of Frama trend.
   //this supersedes the need to check ATRScore per se as this is already taken into account overall within ATR_turn.
   //    : this is used for Risk Mgt./ TP, addScalp and reversal plays.
   //=================================================================================================================  
 
 
     if ((ATRScore ==1 || ATRScore ==-1 ) && ( ATRCurrent >11 || ATRCurrent <50 )) ATR_turn = "ATRturn_Trend";  //no action. continue with current Position.
        else if (ATRScore ==-1 && ATRCurrent >50) ATR_turn = "ATRturn_RevSHORT";  //TP or reverse (Rick Mgt)
         else if (ATRScore ==1 && ATRCurrent <10) ATR_turn = "ATRturn_RevLONG";  //TP or reverse (Rick Mgt)
         else (ATR_turn = "ATR_unKnown");
  */        
//+-----------------------------------------------------------------+
//| ATRStrength only specifically for USTech
//+-----------------------------------------------------------------+
    //Initial ENTRY and EXIT to be confirmed by both ATRScore + ATRPriceDir and RVIDir + RVIStrength and BBConvDivergence
    //Subsequent MEAN REVERSION, CONTINUATION or PINGPONG: confirmed by midBB + FRAMA 

  //new simplified version
  if(ATRCurrent <= 3.99 && ATRCurrent >= 68)  pATRStrength =  "VIX REVERSAL";   
     //else if(ATRCurrent >= 52)                 pATRStrength =  "WEAKENING VIX-TREND";      
     else if(ATRCurrent >= 36)                 pATRStrength =  "VIX-TRENDING";            
     else if(ATRCurrent >= 20)                 pATRStrength =  "START VIX-TREND";     
     else if(ATRCurrent >= 4)                 pATRStrength =  "VIX NEUTRAL";

   return(ATRScore);
   }
   
//+-----------------------------------------------------------------+
//| ConvertATRToUSD : to dynamically calculate the earlyTrailingStop
//+-----------------------------------------------------------------+ 
   
   // Helper function to convert ATR to USD
double ConvertATRToUSD(string symbol, double atr, double lotSize) {
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize == 0) {
      Print("Error: Tick size is zero for ", symbol);
      return atr; // Fallback
   }
   double points = atr / tickSize; // Convert ATR to points
   double usdValue = points * tickValue * lotSize; // USD value
   return usdValue;
   }
//+------------------------------------------------------------------+

/* //+-----------------------------------------------------------------+
//| ATRStrength only specifically for DXY
//+-----------------------------------------------------------------+
    //Initial ENTRY and EXIT to be confirmed by both ATRScore + ATRPriceDir and RVIDir + RVIStrength and BBConvDivergence
    //Subsequent MEAN REVERSION, CONTINUATION or PINGPONG: confirmed by midBB + FRAMA 

  //new simplified version
  if(ATRCurrent <= 0.115 && ATRCurrent >= 0.093)  pATRStrength =  "VIX REVERSAL";   
     else if(ATRCurrent >= 0.070)                 pATRStrength =  "WEAKENING VIX-TREND";      
     else if(ATRCurrent >= 0.050)                 pATRStrength =  "VIX-TRENDING";            
     else if(ATRCurrent >= 0.024)                 pATRStrength =  "START VIX-TREND";     

     else if(ATRCurrent >= 0.010)                 pATRStrength =  "VIX NEUTRAL";
   */
