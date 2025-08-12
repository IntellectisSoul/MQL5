//+------------------------------------------------------------------+
//|                                          Jim BBgap-Universal.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#include "Jim ATRCheckSignal.mqh"

class UniversalBBgap {
private:
    int lookbackPeriod;
    double bbgapArray[];
    int arraySize;  // Add this to track array size
    
public:
    // Constructor to initialize
    UniversalBBgap() {
        arraySize = 0;
        lookbackPeriod = 20; // or whatever period you want
        ArrayResize(bbgapArray, lookbackPeriod);
    }
    
    // Function to add value to array
    void AddToArray(double value) {
        // Shift array elements
        for(int i = lookbackPeriod - 1; i > 0; i--) {
            bbgapArray[i] = bbgapArray[i-1];
        }
        bbgapArray[0] = value;
        
        if(arraySize < lookbackPeriod) arraySize++;
    }
    
    // Calculate average
    double ArrayAverage() {
        double sum = 0;
        for(int i = 0; i < arraySize; i++) {
            sum += bbgapArray[i];
        }
        return (arraySize > 0) ? sum/arraySize : 0;
    }
    
    // Calculate standard deviation
    double ArrayStdDev() {
        if(arraySize <= 1) return 0;
        
        double avg = ArrayAverage();
        double sum = 0;
        
        for(int i = 0; i < arraySize; i++) {
            sum += MathPow(bbgapArray[i] - avg, 2);
        }
        
        return MathSqrt(sum / (arraySize - 1));
    }
    
    struct BBgapMetrics {
        double normalizedBBgap;
        double zScore;
        string volatilityRegime;
        double atrScaledGap;
        
          // Default constructor
        BBgapMetrics() {
            normalizedBBgap = 0.0;
            zScore = 0.0;
            volatilityRegime = "";
            atrScaledGap = 0.0;
        }
        
        // Copy constructor
        BBgapMetrics(const BBgapMetrics& other) {
            normalizedBBgap = other.normalizedBBgap;
            zScore = other.zScore;
            volatilityRegime = other.volatilityRegime;
            atrScaledGap = other.atrScaledGap;
        }
        
        // Assignment operator
        void operator=(const BBgapMetrics& other) {
            normalizedBBgap = other.normalizedBBgap;
            zScore = other.zScore;
            volatilityRegime = other.volatilityRegime;
            atrScaledGap = other.atrScaledGap;
        }
    };
    
    BBgapMetrics Calculate(string symbol, double topBB, double botBB, double midBB) {
        BBgapMetrics metrics;
        
        // Get ATR values using your existing function
        double ATRCurrent;
        string ATRStrength;
        double ATRPriceRatio;
        double ATRdelta;
        double priceNormalized = midBB;
        
        // Call your existing ATR function
        int atrSignal = ATRCheckSignal(symbol, ATRCurrent, ATRStrength, 
                                     priceNormalized, ATRPriceRatio, ATRdelta);
        
        // Calculate raw BBgap
        double rawBBgap = ((topBB - botBB) / midBB) * 100;
        
        // Normalize BBgap using ATR
        metrics.atrScaledGap = (rawBBgap / ATRCurrent);
        
        // Store normalized value
        AddToArray(metrics.atrScaledGap);
        
        // Calculate Z-score normalization
        double bbgapMA = ArrayAverage();
        double bbgapStdDev = ArrayStdDev();
        metrics.zScore = (bbgapStdDev != 0) ? (metrics.atrScaledGap - bbgapMA) / bbgapStdDev : 0;
        
        // Determine volatility regime
        metrics.volatilityRegime = DetermineVolatilityRegime(metrics.zScore, ATRStrength);
        
        return metrics;
    }
    
private:
    string DetermineVolatilityRegime(double zScore, string atrStrength) {
        if(atrStrength == "VIX REVERSAL" && zScore > 2) 
            return "Extreme Volatility";
        else if(atrStrength == "VIX-TRENDING" && zScore > 1) 
            return "High Volatility";
        else if(atrStrength == "VIX NEUTRAL" && MathAbs(zScore) <= 1) 
            return "Normal Volatility";
        else if(atrStrength == "START VIX-TREND" && zScore < -1) 
            return "Building Pressure";
        else 
            return "Mixed Signals";
    }
};

/*
This approach:
   Uses your existing ATR function
   Combines ATR and BBgap for better normalization
   Creates a universal scaling that works across instruments
   Provides clear trading signals
   Adapts position sizing and risk management
   Considers both volatility and price action
   Key advantages:
   Works with any instrument
   Adapts to market conditions
   Provides consistent signals
   Includes risk management
   Uses your existing ATR implementation
   Remember to:
   Test thoroughly with different instruments
   Monitor performance across different market conditions
   Adjust thresholds based on your risk tolerance
   Use proper position sizing
   Always implement proper risk management
   
   //--------------
   
   Implementation Example:
void OnTick() {
    // Get BB values
    double topBB = iBands(Symbol(), Period(), 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
    double botBB = iBands(Symbol(), Period(), 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
    double midBB = iBands(Symbol(), Period(), 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    UniversalBBgap bbgapCalculator;
    UniversalBBgap::BBgapMetrics metrics = bbgapCalculator.Calculate(Symbol(), topBB, botBB, midBB);
    
    // Trading logic based on normalized metrics
    if(metrics.zScore < -2 && metrics.volatilityRegime == "Building Pressure") {
        // Potential breakout setup
        double positionSize = NormalizePositionSize(metrics.atrScaledGap);
        // Place your order here
    }
}

double NormalizePositionSize(double atrScaledGap) {
    double baseSize = 1.0;
    return baseSize * (1 / (1 + MathAbs(atrScaledGap)));
}
Trading Signals Framework:
struct TradingSignals {
    bool isBreakoutSetup;
    bool isTrendingSetup;
    bool isReversal;
    double suggstedPositionSize;
    double suggestedStopLoss;
};

TradingSignals AnalyzeMarketConditions(UniversalBBgap::BBgapMetrics metrics) {
    TradingSignals signals;
    
    // Breakout setup
    signals.isBreakoutSetup = (metrics.zScore < -2 && 
                              metrics.volatilityRegime == "Building Pressure");
    
    // Trending setup
    signals.isTrendingSetup = (metrics.zScore > 1 && 
                              metrics.volatilityRegime == "High Volatility");
    
    // Reversal setup
    signals.isReversal = (metrics.zScore > 2 && 
                         metrics.volatilityRegime == "Extreme Volatility");
    
    // Position sizing
    signals.suggstedPositionSize = NormalizePositionSize(metrics.atrScaledGap);
    
    // Stop loss calculation
    signals.suggestedStopLoss = CalculateAdaptiveStopLoss(metrics);
    
    return signals;
}
Risk Management Integration:
double CalculateAdaptiveStopLoss(UniversalBBgap::BBgapMetrics metrics) {
    double baseStopLoss = 2.0 * metrics.atrScaledGap;
    
    // Adjust based on volatility regime
    if(metrics.volatilityRegime == "Extreme Volatility")
        return baseStopLoss * 1.5;
    else if(metrics.volatilityRegime == "Building Pressure")
        return baseStopLoss * 0.75;
    else
        return baseStopLoss;
}