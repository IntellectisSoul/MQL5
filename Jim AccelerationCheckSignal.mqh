 //------------------------------------------------------------------+
//|                                             Jim Acceleration.mq5 |
//|                                         Copyright Jim S, Lim 2024|
//|                                                    version :  1  |
//+------------------------------------------------------------------+
/*
   DOCUMENTATION : This is an object-oriented program wth 3 Methods
   Outputs : 
      A. Relationship with itself : 
      1. 
      
  
  
  -------------------
  31.Oct.2024 : 
   
   */
   
   double NoOfSegment_Array[2] = {0,0}; //for PushElement_toArray()
//=========================================================================================+        
//Function : Acceleration : returns the NoOfSegments
//=========================================================================================+   
double Acceleration(string Accesymbol, ENUM_TIMEFRAMES AccePeriod, double pPriceNormalized, double pPricedelta, double segmentSize, 
                  double pCurrentOpen, char &TailScore, double pLowTail, double pHighTail)export
  {
   double NoOfSegments=0;
   double iLow  = iLow(Accesymbol, AccePeriod,  0);   //calculate CurrentBar High/ Low
   double iHigh  = iHigh(Accesymbol, AccePeriod,  0);
  

//calculate no. of ladders or length of the segment. if more than 8 ladders, addScalp.
   if(pPricedelta >0)
     {NoOfSegments = ((pPriceNormalized - iLow)/segmentSize) ;}
   else
      if(pPricedelta <0)
        {NoOfSegments = ((pPriceNormalized - iHigh)/segmentSize) ;}
        

   
  // double pLowTail = pPriceNormalized - iLow;
  // double pHighTail = iHigh- pPriceNormalized;
   
   //double TotalBarHt = (iHigh - iLow)/segmentSize;
   //double BarMid = (iHigh - iLow)/2; 
   //BarMidPrice = iLow + BarMid;
   
   //Check long Tail
     double minPercentageMove = 0.07;
   if ( pLowTail > pHighTail && pPriceNormalized > pCurrentOpen && pPricedelta >=minPercentageMove) { TailScore =1;}
   else if (pHighTail > pLowTail  && pPriceNormalized < pCurrentOpen && pPricedelta <=-minPercentageMove) { TailScore =-1;}
   else TailScore =0;

   NoOfSegments=NormalizeDouble(NoOfSegments,_Digits);
    
      
      // PrintFormat(_Symbol + "  Price: %f, Low: %f, High: %f, PDelta: %f, SegmentSize: %f, NoOfSegments: %f", pCurrentPrice, iLow, iHigh, pPricedelta, segmentSize, NoOfSegments);

   
  /* //Check framaproc both at open and close of bar : 
   double PbarframaCross;
   if (pframaproc)
  */ 
   return (NoOfSegments);   //is the no. of segmentSize's.'
  }
/*
to add function to check for whipsaw : basically check for Pbars whose iHigh is above FramaCurrent & whose iLows is below.
Avoid entering until the Pbar is not anymore in this whipsaw situation or until after 8 consecutive bars of this type is over.
above is true of a problem only for M15.

How to measure and identify RANGE-PINGPONG scenario  :
1. Average of Frama
2. how many times Bar whipsawed across pFramaproc.  WaveNeg and WavePos can also paint a picture of RANGE situations when knowing where the current price is in relation to them.


*/