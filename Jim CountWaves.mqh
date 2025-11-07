//+------------------------------------------------------------------+
//|                                               Jim CountWaves.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"


#include "Jim Fractal.mqh"

// Global variables to track state
int waveCount = 0; // Tracks the number of waves counted
int prevlast_FractalType = 0; // Tracks the last fractal type processed (1 for uptrend, -1 for downtrend)
double lastfractal_High = 0.0; // Tracks the last fractal high
double lastfractal_Low = 0.0; // Tracks the last fractal low
double frozenSegmentSize = 0.0; // Stores the frozen segment size at the first fractal signal
bool flag_waveStarted = false; // Indicates whether a wave has started
bool flag_fractalIndex = false;



// Enhanced CountWaves function with additional arguments
int CountWaves(int local_FractalType, int currentFractalType, double PriceNormalized,
               
                bool useTrendControl,
               double segmentSize) {
    // Freeze segmentSize at the first fractal signal
    if (waveCount == 0 && !flag_waveStarted && local_FractalType !=0) {
        frozenSegmentSize = segmentSize;
    }

    // Check if the current fractal type is valid and alternating
    if (currentFractalType != prevlast_FractalType && currentFractalType != 0) {
        // Apply trend confirmation control if enabled
        if (useTrendControl) {
            if ((currentFractalType == 1) || (currentFractalType == -1 )) {
                // Reset wave count if trend confirmation fails
                waveCount = 0;
                flag_waveStarted = false;
                prevlast_FractalType = currentFractalType;
                return waveCount;
            }
        }

        // Calculate the price difference based on fractal highs and lows
        double priceDifference = MathAbs(lastfractal_High - lastfractal_Low);

        // Check if the price difference is "large" (10x frozen segment size)
        if (!flag_waveStarted && priceDifference >= 10 * frozenSegmentSize) {
            flag_waveStarted = true; // Start counting waves
            waveCount++; // Increment wave count
            Alert(_Symbol + "  Trend : 1st Wave completed" );
        } else if (flag_waveStarted) {
            // Alternate fractals are required for subsequent waves
            waveCount++;
        }

        // Reset wave count if it exceeds the maximum limit
        if (waveCount > 3) {
            waveCount = 0; // Reset wave count
            flag_waveStarted = false; // Reset wave state
            frozenSegmentSize = 0.0; // Reset frozen segment size
        }

        // Update the last fractal type and fractal prices
        prevlast_FractalType = currentFractalType;
        if (currentFractalType == 1) {
            lastfractal_Low = PriceNormalized; // Update last fractal low for uptrend
        } else if (currentFractalType == -1) {
            lastfractal_High = PriceNormalized; // Update last fractal high for downtrend
        }
    }

    // Monitor lastfractal_HighIndex and lastfractal_LowIndex
  
    if (!flag_fractalIndex && ((lastfractal_HighIndex <= 3 && currentFractalType ==-1)  || (lastfractal_LowIndex >= -3 && currentFractalType ==1) )) {
       if(currentFractalType ==1) {Alert(_Symbol + " : Reverse_fractalIndex_Up!");}
          else {Alert(_Symbol + " : Reverse_fractalIndex_Down!");}
        flag_fractalIndex = true;
    }
/*
    // Monitor PriceNormalized for warnings
    if (PriceNormalized > lastfractal_High || PriceNormalized < lastfractal_Low) {
        Alert("Warning: PriceNormalized has exceeded lastfractal_High or fallen below lastfractal_Low!");
    }
*/
    // Return the current wave count
    return waveCount;
}