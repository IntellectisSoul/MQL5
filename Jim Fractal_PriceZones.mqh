//+------------------------------------------------------------------+
//|                                           Jim Fractal_Zones Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"



   /*DOCUMENTATION : DeepSeek
   =======================================================================================================================
   This is a method arising out of completion of Jim FractalDataLookBack where gM15FractalHigh, gM15FractalLow, gDailyFractalHigh and gDailyFractalLow has been defined and drawn on Chart.
   This Function attempts to divide the M15High and M15Low into 10 segments and 9 Zones based on neutral Zone at middle line #5. It assumes 
   
   Zones are divided into 10 segments, similar to PriceIndex (1, 2, 3, 4, -1, -2, -3, -4...)
   
     1.April.2025 : newly created.
   =======================================================================================================================
*/
// PriceZones.mqh - NEW FILE
#ifndef PRICE_ZONES_MQH
#define PRICE_ZONES_MQH

class PriceZoneManager {
private:
    int m_currentRange;
    
public:
    void UpdateZones(double fractalHigh, double fractalLow) {
        if(fractalHigh <= fractalLow) return;
        
        double step = (fractalHigh - fractalLow)/10;
        
        // Create 9 segmented lines
        for(int i = -4; i <= 4; i++) {
            string name = "ZoneLine_"+IntegerToString(i);
            double price = fractalLow + (i+5)*step;
            
            ObjectCreate(0, name, OBJ_TREND, 0, TimeCurrent(), price, TimeCurrent()+PeriodSeconds(PERIOD_M15)*2, price);
            ObjectSetInteger(0, name, OBJPROP_COLOR, (i==0)?clrGold:clrSilver);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_RAY, false);
        }
    }
    
    int GetCurrentRange(double price, double high, double low) {
        if(price >= high) return 5;
        if(price <= low) return -5;
        return (int)MathFloor((price-low)/(high-low)*10)-4;
    }
};

#endif

/*
//+------------------------------------------------------------------+
//| Example Usage                                                    |
//+------------------------------------------------------------------+
void OnTick() {
    // Call this when your fractals update
    if(isNewBar(PERIOD_M15)) {
        CreateSegmentedLevels();
    }
    
    // Continuously monitor price range
    CheckPriceRangeAlerts();
    
    // Optional: Display current range on chart
    Comment("Current Price Range: ", GetCurrentPriceRange(),
            "\nM15 High: ", gM15FractalHigh,
            "\nM15 Low: ", gM15FractalLow);
}
*/