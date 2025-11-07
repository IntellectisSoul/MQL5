//+------------------------------------------------------------------+
//|                                     Jim SimulatedTradeCSVLog.mqh |
//|                                         Copyright 2025, StJo     |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property strict


#include "Jim SharedStructs.mqh"
#include "Jim LogSymbolInfo.mqh" 
#include "Jim TradeMonitor.mqh" // To access PositionDetails


// External dependencies (assumed to be defined in the main script)
extern string csvTradeLog_fileName;
extern int csvTradeLog_handle;
extern bool headersWritten;
extern string headerParams[];
extern string valueParams[];


/* XXXXXX-
   2.Sept.2025 : works well. but in order to reduce redundancy, has been depracated because ManagePositionLogging() inside Trade Monitor.mqh has already incorporated relevant simulated checks.
   14.Aug.2025 :Fixed writing of SiMULATED to csv.
   
   */
//+------------------------------------------------------------------+
//| Generate a pseudo-ticket for simulated trades                     |
//+------------------------------------------------------------------+

ulong GeneratePseudoTicket()
{
    static int counter = 0; // Ensure uniqueness
    int random = MathRand();
    int ticketNum = (int)(TimeCurrent() % 1000000 + random + counter++) % 1000000; // 6-digit number
    return (ulong)ticketNum; // Returns a numeric ulong
}
//+------------------------------------------------------------------+
//| Write simulated position to file                                  |
//+------------------------------------------------------------------+
void WriteSimulatedPositionToFile(string symbol, string ticket, string purpose, string alertComment, 
                                 int alertSwitch, int alertSwitchPrev, int triggerEntryDirection, 
                                 double openPrice, double closePrice, double lotSize)
{
    // Prepare all data before opening file
    ArrayResize(valueParams, ArraySize(headerParams));
    
    // Populate all data fields
    valueParams[0] = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
    valueParams[1] = symbol;
    valueParams[2] = ticket;
    valueParams[3] = (alertComment == "") ? "None" : alertComment;
    valueParams[4] = IntegerToString(alertSwitch);
    valueParams[5] = IntegerToString(alertSwitchPrev);
    valueParams[6] = IntegerToString(triggerEntryDirection);
    valueParams[7] = "7"; // MagicNo for simulated trades
    valueParams[8] = DoubleToString(openPrice, _Digits);
    valueParams[9] = DoubleToString(openPrice, _Digits);
    valueParams[10] = DoubleToString(openPrice, _Digits);
    valueParams[11] = "0";
    valueParams[12] = DoubleToString(lotSize, 2);
    valueParams[13] = "0.00";
    valueParams[14] = "0.00";
    valueParams[15] = "0.00";
    valueParams[16] = (purpose == "" || purpose == "Closed Position") ? 
                     GetPurposeFromTriggerEntryDirection(triggerEntryDirection) : purpose;
    
    // Fill remaining fields with defaults
    for(int i = 17; i < ArraySize(valueParams); i++)
    {
        if(valueParams[i] == "" || StringLen(valueParams[i]) == 0)
        {
            if(StringFind(headerParams[i], "Time") >= 0)
                valueParams[i] = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
            else if(StringFind(headerParams[i], "Identifier") >= 0 || 
                    StringFind(headerParams[i], "Type") >= 0 || 
                    StringFind(headerParams[i], "Stoch_Xover") >= 0 || 
                    StringFind(headerParams[i], "DeM_trendShiftResult") >= 0)
                valueParams[i] = "None";
            else
                valueParams[i] = "0";
        }
    }

    // Build the complete data line
    string dataLine = "";
    for(int i = 0; i < ArraySize(valueParams); i++)
    {
        dataLine += valueParams[i];
        if(i < ArraySize(valueParams) - 1) dataLine += "\t";
    }

    // Atomic file operation
    int handle = FileOpen(csvTradeLog_fileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, "\t");
    if(handle != INVALID_HANDLE)
    {
        // Move to end (in case someone else wrote to the file)
        FileSeek(handle, 0, SEEK_END);
        
        // Check if we need headers (first write)
        if(FileTell(handle) == 0)
        {
            string headerLine = "";
            for(int i = 0; i < ArraySize(headerParams); i++)
            {
                headerLine += headerParams[i];
                if(i < ArraySize(headerParams) - 1) headerLine += "\t";
            }
            FileWrite(handle, headerLine);
        }
        
        // Write the data
        if(FileWrite(handle, dataLine) > 0)
        {
            FileFlush(handle); // Force write to disk
            LogSymbolToFile("Successfully wrote position: " + ticket);
        }
        else
        {
            LogSymbolToFile("Write failed for ticket: " + ticket + ", error: " + IntegerToString(GetLastError()));
        }
        
        FileClose(handle);
    }
    else
    {
        LogSymbolToFile("Failed to open file: " + csvTradeLog_fileName + ", error: " + IntegerToString(GetLastError()));
    }
}

//+------------------------------------------------------------------+
//| Write simulated closed position to file                           |
//+------------------------------------------------------------------+
void WriteSimulatedClosedPositionToFile(string symbol, string ticket, string purpose, 
                                       string alertComment, int alertSwitch, 
                                       int alertSwitchPrev, int triggerEntryDirection, 
                                       double openPrice, double closePrice, double lotSize)
{
    // Prepare all data before opening file
    ArrayResize(valueParams, ArraySize(headerParams));
    
    // Calculate P&L
    int positionType = (closePrice > openPrice) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    double pl = CalculatePnL(openPrice, closePrice, lotSize, positionType, 0.00, 0.00);

    // Populate all data fields
    valueParams[0] = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
    valueParams[1] = symbol;
    valueParams[2] = ticket;
    valueParams[3] = (alertComment == "") ? "None" : alertComment;
    valueParams[4] = IntegerToString(alertSwitch);
    valueParams[5] = IntegerToString(alertSwitchPrev);
    valueParams[6] = IntegerToString(triggerEntryDirection);
    valueParams[7] = "7"; // MagicNo for simulated trades
    valueParams[8] = "0.0";
    valueParams[9] = "0.0";
    valueParams[10] = DoubleToString(openPrice, _Digits);
    valueParams[11] = DoubleToString(closePrice, _Digits);
    valueParams[12] = DoubleToString(lotSize, 2);
    valueParams[13] = "0.00";
    valueParams[14] = "0.00";
    valueParams[15] = DoubleToString(pl, 2);
    valueParams[16] = (purpose == "" || purpose == "Closed Position") ? 
                     GetPurposeFromTriggerEntryDirection(triggerEntryDirection) : purpose;
    
    // Fill remaining fields with defaults
    for(int i = 17; i < ArraySize(valueParams); i++)
    {
        if(valueParams[i] == "" || StringLen(valueParams[i]) == 0)
        {
            if(StringFind(headerParams[i], "Time") >= 0)
                valueParams[i] = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
            else if(StringFind(headerParams[i], "Identifier") >= 0 || 
                    StringFind(headerParams[i], "Type") >= 0 || 
                    StringFind(headerParams[i], "Stoch_Xover") >= 0 || 
                    StringFind(headerParams[i], "DeM_trendShiftResult") >= 0)
                valueParams[i] = "None";
            else
                valueParams[i] = "0";
        }
    }

    // Build the complete data line
    string dataLine = "";
    for(int i = 0; i < ArraySize(valueParams); i++)
    {
        dataLine += valueParams[i];
        if(i < ArraySize(valueParams) - 1) dataLine += "\t";
    }

    // Atomic file operation
    int handle = FileOpen(csvTradeLog_fileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, "\t");
    if(handle != INVALID_HANDLE)
    {
        // Move to end (in case someone else wrote to the file)
        FileSeek(handle, 0, SEEK_END);
        
        // Write the data
        if(FileWrite(handle, dataLine) > 0)
        {
            FileFlush(handle); // Force write to disk
            LogSymbolToFile("Successfully wrote closed position: " + ticket + ", P&L: " + DoubleToString(pl, 2));
        }
        else
        {
            LogSymbolToFile("Write failed for closed position: " + ticket + ", error: " + IntegerToString(GetLastError()));
        }
        
        FileClose(handle);
    }
    else
    {
        LogSymbolToFile("Failed to open file for closed position: " + csvTradeLog_fileName + ", error: " + IntegerToString(GetLastError()));
    }
}


