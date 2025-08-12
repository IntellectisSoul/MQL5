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

//+------------------------------------------------------------------+
//| Generate a pseudo-ticket for simulated trades                     |
//+------------------------------------------------------------------+
string GeneratePseudoTicket()
{
   static int counter = 0; // Ensure uniqueness
   int random = MathRand();
   int ticketNum = (int)(TimeCurrent() % 1000000 + random + counter++) % 1000000; // 6-digit number
   string ticket = StringFormat("S%06d", ticketNum); // Prefix with "S", ensure 7 characters
   return ticket;
}
//+------------------------------------------------------------------+
//| Write simulated position to file                                  |
//+------------------------------------------------------------------+
void WriteSimulatedPositionToFile(string symbol, string ticket, string purpose, string alertComment, 
                                  int alertSwitch, int alertSwitchPrev, int triggerEntryDirection, 
                                  double openPrice, double closePrice, double lotSize)
{
   if(csvTradeLog_fileName == "")
   {
      csvTradeLog_fileName = "PositionLog_" + symbol + ".csv";
      csvTradeLog_handle = FileOpen(csvTradeLog_fileName, FILE_WRITE|FILE_CSV|FILE_COMMON, "\t");
      if(csvTradeLog_handle == INVALID_HANDLE)
      {
         LogSymbolToFile("WriteSimulatedPositionToFile: Failed to open file " + csvTradeLog_fileName + 
                         ", error=" + IntegerToString(GetLastError()));
         return;
      }
      
      if(!headersWritten)
      {
         string headerLine = "";
         for(int i = 0; i < ArraySize(headerParams); i++)
         {
            headerLine += headerParams[i];
            if(i < ArraySize(headerParams) - 1) headerLine += "\t";
         }
         FileWrite(csvTradeLog_handle, headerLine);
         headersWritten = true;
         LogSymbolToFile("WriteSimulatedPositionToFile: Wrote headers to " + csvTradeLog_fileName);
      }
      FileClose(csvTradeLog_handle);
   }

   // Update trade-specific fields in valueParams
   ArrayResize(valueParams, 141); // Ensure size matches headerParams
   valueParams[0] = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES); // TimeServer
   valueParams[1] = symbol;                                             // Symbol
   valueParams[2] = ticket;                                             // Ticket (Sxxxxxx)
   valueParams[3] = alertComment == "" ? "None" : alertComment;         // alertcomment
   valueParams[4] = IntegerToString(alertSwitch);                       // alertswitch
   valueParams[5] = IntegerToString(alertSwitchPrev);                   // alertswitchPrev
   valueParams[6] = IntegerToString(triggerEntryDirection);             // Trigger_Entry
   valueParams[7] = "7";                                                // MagicNo (simulated)
   valueParams[8] = DoubleToString(openPrice, _Digits);                 // askPrice
   valueParams[9] = DoubleToString(openPrice, _Digits);                 // CurrentPrice (use openPrice for open positions)
   valueParams[10] = DoubleToString(openPrice, _Digits);                // OpenPrice
   valueParams[11] = "0";                                               // ClosedPrice (empty for open positions)
   valueParams[12] = DoubleToString(lotSize, 2);                        // LotSize
   valueParams[13] = "0.00";                                            // swap
   valueParams[14] = "0.00";                                            // commission
   valueParams[15] = "0.00";                                            // P&L
   valueParams[16] = (purpose == "" || purpose == "Closed Position") ? GetPurposeFromTriggerEntryDirection(triggerEntryDirection) : purpose; // TradePurpose
   // Fields 17-140 are assumed to be already populated with global indicator values
   for(int i = 17; i < ArraySize(valueParams); i++)
   {
      if(valueParams[i] == "" || StringLen(valueParams[i]) == 0)
      {
         valueParams[i] = "0"; // Default for numeric or boolean fields
         if(StringFind(headerParams[i], "Time") >= 0)
            valueParams[i] = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES); // For TimeLocal
         else if(StringFind(headerParams[i], "Identifier") >= 0 || 
                 StringFind(headerParams[i], "Type") >= 0 || 
                 StringFind(headerParams[i], "Stoch_Xover") >= 0 || 
                 StringFind(headerParams[i], "DeM_trendShiftResult") >= 0)
            valueParams[i] = "None"; // For string fields
      }
   }
   if(!WriteFile_EntryData(valueParams, StringToInteger(StringSubstr(ticket, 1)), csvTradeLog_handle)) // Convert Sxxxxx to integer
  
   {
      LogSymbolToFile("WriteSimulatedPositionToFile: Failed to write simulated position: " + ticket);
   }
   else
   {
      LogSymbolToFile("WriteSimulatedPositionToFile: Successfully wrote simulated position: " + ticket + 
                      ", purpose=" + valueParams[16] + ", alertcomment=" + alertComment + 
                      ", alertswitch=" + IntegerToString(alertSwitch) + 
                      ", Trigger_EntryDirection=" + IntegerToString(triggerEntryDirection));
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
   if(csvTradeLog_fileName == "")
   {
      csvTradeLog_fileName = "PositionLog_" + symbol + ".csv";
      csvTradeLog_handle = FileOpen(csvTradeLog_fileName, FILE_WRITE|FILE_CSV|FILE_COMMON, "\t");
      if(csvTradeLog_handle == INVALID_HANDLE)
      {
         LogSymbolToFile("WriteSimulatedClosedPositionToFile: Failed to open file " + 
                         csvTradeLog_fileName + ", error=" + IntegerToString(GetLastError()));
         return;
      }
      
      if(!headersWritten)
      {
         string headerLine = "";
         for(int i = 0; i < ArraySize(headerParams); i++)
         {
            headerLine += headerParams[i];
            if(i < ArraySize(headerParams) - 1) headerLine += "\t";
         }
         FileWrite(csvTradeLog_handle, headerLine);
         headersWritten = true;
         LogSymbolToFile("WriteSimulatedClosedPositionToFile: Wrote headers to " + csvTradeLog_fileName);
      }
      FileClose(csvTradeLog_handle);
   }

   // Update trade-specific fields in valueParams
   ArrayResize(valueParams, 141); // Ensure size matches headerParams
   valueParams[0] = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES); // TimeServer
   valueParams[1] = symbol;                                             // Symbol
   valueParams[2] = ticket;                                             // Ticket (Sxxxxxx or existing position ticket)
   valueParams[3] = alertComment == "" ? "None" : alertComment;         // alertcomment
   valueParams[4] = IntegerToString(alertSwitch);                       // alertswitch
   valueParams[5] = IntegerToString(alertSwitchPrev);                   // alertswitchPrev
   valueParams[6] = IntegerToString(triggerEntryDirection);             // Trigger_Entry
   valueParams[7] = "7";                                                // MagicNo (simulated)
   valueParams[8] = "0.0";                                              // askPrice
   valueParams[9] = "0.0";                                              // CurrentPrice
   valueParams[10] = DoubleToString(openPrice, _Digits);                // OpenPrice
   valueParams[11] = DoubleToString(closePrice, _Digits);               // ClosePrice
   valueParams[12] = DoubleToString(lotSize, 2);                        // LotSize
   valueParams[13] = "0.00";                                            // swap
   valueParams[14] = "0.00";                                            // commission
   // Calculate P&L using existing CalculatePnL function
   int positionType = (closePrice > openPrice) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL; // Simulate direction
   double pl = CalculatePnL(openPrice, closePrice, lotSize, positionType, 0.00, 0.00); // Swap and commission set to 0
   valueParams[15] = DoubleToString(pl, 2);                             // P&L
   valueParams[16] = (purpose == "" || purpose == "Closed Position") ? GetPurposeFromTriggerEntryDirection(triggerEntryDirection) : purpose; // TradePurpose
   // Fields 17-140 are assumed to be already populated with global indicator values
   for(int i = 17; i < ArraySize(valueParams); i++)
   {
      if(valueParams[i] == "" || StringLen(valueParams[i]) == 0)
      {
         valueParams[i] = "0"; // Default for numeric or boolean fields
         if(StringFind(headerParams[i], "Time") >= 0)
            valueParams[i] = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES); // For TimeLocal
         else if(StringFind(headerParams[i], "Identifier") >= 0 || 
                 StringFind(headerParams[i], "Type") >= 0 || 
                 StringFind(headerParams[i], "Stoch_Xover") >= 0 || 
                 StringFind(headerParams[i], "DeM_trendShiftResult") >= 0)
            valueParams[i] = "None"; // For string fields
      }
   }

    if(!WriteFile_EntryData(valueParams, StringToInteger(StringSubstr(ticket, 1)), csvTradeLog_handle)) // Convert Sxxxxx to integer
   {
      LogSymbolToFile("WriteSimulatedClosedPositionToFile: Failed to write simulated closed position: " + ticket);
   }
   else
   {
      LogSymbolToFile("WriteSimulatedClosedPositionToFile: Successfully wrote simulated closed position: " + ticket + 
                      ", purpose=" + valueParams[16] + ", alertcomment=" + alertComment + 
                      ", alertswitch=" + IntegerToString(alertSwitch) + 
                      ", Trigger_EntryDirection=" + IntegerToString(triggerEntryDirection) + 
                      ", P&L=" + DoubleToString(pl, 2));
   }
}