//#define DEBUG
#property strict
#ifndef TRADE_MONITORING_MQH
#define TRADE_MONITORING_MQH

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "Jim_TradeUtils.mqh"
#include "Jim ProtectProfit_Hedge.mqh"
#include "Jim SharedStructs.mqh"

#include "Jim LogSymbolInfo.mqh" //convert Print statements and logs all actions for each instruments separately.
//#include "FileLogger.mqh"

#define TRADE_COOLDOWN_SECONDS 300
#define HEDGE_COOLDOWN_SECONDS 300



extern int MagicNumber;
ulong pendingHedgeTickets[];
//+------------------------------------------------------------------+
//| Jim TradeMonitoring.mqh                                          |
//| Copyright 2025, Jim S.Lim                                        |
//+------------------------------------------------------------------+

/*
Purpose: Provides structures and functions for tracking open positions, managing hedge states, and executing hedges in an MQL5 Expert Advisor. Used by MainEA.mq5, Jim ProtectProfit_Hedge.mq5, and Jim_Trade_Defense.mq5.

Key Functions:
   UpdatePositionTracking(): Refreshes PositionsArray, removes closed positions, and clears orphaned hedge references.
   GetPositionDetails(): Updates PositionsArray and aggregates position data (lot size, buys, sells) for a symbol.
   
   CalculateHedgingStatus(): Pairs BUY and SELL positions by volume for hedging.
   AreAllPositionsHedged(): Checks if all positions for a symbol are hedged.
   UpdateTradeHedgedState(): Updates isHedged and hedgeTicket for a position.
   CleanClosedPositions(): Removes closed positions and unhedges paired positions.
  
   GetHedgeHistory(): Retrieves hedge history for a ticket.
   CheckPositionMetrics(): Validates position metrics with retries.
   
   
   Summary of Function Categories and Dependencies

    Main Functions (Core functionality, called directly by the EA):
        GetPositionDetails(): Updates PositionsArray and aggregates position data.
        UpdatePositionTracking(): Orchestrates position tracking updates.
        CheckPositionMetrics(): Monitors position metrics; used in ProtectProfit()
        
        
    Helper Functions (Support main functions, called internally):
        UpdateTradeHedgedState(): Updates hedging status.
        CalculateHedgingStatus(): Pairs positions for hedging.
        CleanClosedPositions(): Removes closed positions and unhedges paired positions; used in GetPositionDetails(.
       
        GetHedgeHistory(): Retrieves hedging history.
        IsPositionInArray(): Validates position presence in the array.
        AreAllPositionsHedged(): Checks if all positions are hedged.
        
    Dependency Graph:
        UpdatePositionTracking() → CleanClosedPositions(), GetPositionDetails(), CalculateHedgingStatus()
        GetPositionDetails() → CleanClosedPositions()
        CalculateHedgingStatus() → UpdateTradeHedgedState()
       
        CleanClosedPositions() → (indirectly affects UpdateTradeHedgedState() via CalculateHedgingStatus())
        
        


Change Log:
   20.June.2025  :updated UpdatePositionsTracking() to be integrated into OnTradeTransaction().removed CleanClosedPositions()
   2.June.2025 : revsions from Grok
   9.May.2025 : revised CleanClosedPositions() & CloseSpecificPosition()
   25.April.2025 : moved CloseSpecificPosition from TradeUtils
   21.April.2025 :  [Current Date]: Deprecated initialProfitThreshold, unified to use dynamic threshold parameter.
   18.April: Enhanced CleanClosedPositions() and UpdatePositionTracking() to clear orphaned hedge references, preventing stale isHedged states. Updated HedgePosition() to enforce 5-minute cooldown.
   16.April: Added hedgeHistory to PositionDetails for tracking past hedge tickets to support reversal decisions.
   15.April: Added UpdateTradeHedgedState() and consolidated tracking into PositionsArray.
   10.April: Adjusted position tracking for robustness.
   08.April: Created to replace CheckAllPositions.mq5, shared by Jim ProtectProfit_Hedge.mq5 and Jim_Trade_Defense.mq5.
*/
// Assume these are accessible (defined in .mq5, declared extern in SharedStructs.mqh or here)
//extern string logSubFolder;
// Declare LogSymbolToFile if its definition is elsewhere and not included
// void LogSymbolToFile(string message, string subfolder);


/*
Updates the PositionsArray with current open positions for a given symbol, aggregating data such as total lot size, position type, open price, and counts of buy/sell positions.
It also removes duplicates and ensures the array reflects the current state of open positions.
Category: Main Function

This is a core function that populates and updates the PositionsArray, which is central to position tracking in your EA system. 
It’s called frequently to ensure the EA has the latest position data.



=====================
Position Tracking System
├── UpdatePositionTracking() - Full position scan/refresh
├── UpdateHedgeStatus() - Specific hedge relationship updates
└── AddNewPositionToTracking() - Add single position

Hedge Management
└── HandleHedgeOperation() - Consolidated hedge function
   ├── Uses BuyMarketTrade/SellMarketTrade
   └── Calls UpdateHedgeStatus
   
   
   Main EA (OnTick)
├── GetPositionDetails(symbol, posDetails, count_buys, count_sells)
│   └── Purpose: Queries position state and counts for defense decisions
├── defenseManager.CheckDefensesForTicket(defenseParams, ticket)
│   └── Returns DefenseResult for triggering cases
├── HandleHedgeOperation(positionTicket) [Case 5/6]
│   ├── IsPositionHedged(positionTicket)
│   ├── IsSymbolInHedgeCooldown(symbol)
│   ├── StoreHedgeMapping(orderTicket, originalTicket)
│   ├── BuyMarketTrade/SellMarketTrade()
│   └── Triggers OnTradeTransaction() for updates
├── HandleTrendReversalCase(ticket, position, PriceIndex) [Case 7]
│   ├── FindHedgePairs(symbol, pairs[], pairCount)
│   ├── CloseSpecificPosition(ticket)
│   │   └── Updates PositionArray[i].pendingClosure/isHedged
│   └── Write_PnL_Data() (via OnTradeTransaction)
├── HandleCutLossCase(ticket, position, PriceIndex) [Case 3]
│   ├── CloseSpecificPosition(ticket)
│   └── Write_PnL_Data() (via OnTradeTransaction)

OnTradeTransaction()
├── GetPositionDetails(symbol, posDetails, count_buys, count_sells)
├── CheckForReversalOpportunity(pos.ticket)
├── UpdatePositionTracking(symbol, newPos)
│   ├── CleanClosedPositions(symbol)
│   ├── VerifyAllHedgeRelationships(symbol)
│   ├── GetPositionDetails()
│   └── UpdateTradeHedgedState(ticket, isHedged, newHedgeTicket)
├── AddHedgePosition(originalTicket, positionTicket, lotSize, symbol)
│   └── UpdateTradeHedgedState()
├── RemoveHedgePosition(position, hedgeTicket, symbol, closePrice, qty, mode)
│   ├── UpdateTradeHedgedState()
│   └── RemovePositionFromTracking(ticket)
├── RemovePositionFromTracking(ticket)
│   └── Updates PositionArray[]/isHedged
├── GetOriginalTicketForHedge(orderTicket)
├── UpdateHedgeCooldown(symbol)
└──_PnL_Data(openPrice, closePrice, alertComment, alertSwitch, PriceIndex, ...)

DefenseManager.mqh
├── CheckDefensesForTicket(defenseParams, ticket)
├── CloseSpecificPosition(ticket)
├── HandleHedgeOperation(positionTicket)
├── HandleTrendReversalCase(ticket, position, PriceIndex)
├── HandleCutLossCase(ticket, position, PriceIndex)
*/
//+------------------------------------------------------------------+
//|                      TradeMonitor.mqh                            |
//+------------------------------------------------------------------+



// Global variables



// Position tracking : defined in SharedStrcts.mqh
/*PositionDetails PositionsArray[];
int PositionsCount = 0;
int count_buys = 0;
int count_sells = 0;
*/
// Hedge tracking
/*
HedgeMapping hedgeMappings[];
int hedgeMapCount = 0;
HedgeCooldown hedgeCooldowns[];
ulong pendingBuyHedgeOrderTicket = 0;
ulong pendingSellHedgeOrderTicket = 0;
*/

//+------------------------------------------------------------------+
//| Initialization functions                                         |
//+------------------------------------------------------------------+


void InitializeCSVHeaders()
{
    ArrayResize(headerParams, 140);
    int index = 0;
    headerParams[index++] = "TimeServer";
    headerParams[index++] = "Symbol";
    headerParams[index++] = "Ticket";
    // ... continue with all your headers ...
    headerParams[138] = "TradePurpose";
}

//+------------------------------------------------------------------+
//| Core position monitoring functions                               |
//+------------------------------------------------------------------+
//used inside OnInit()
void ValidatePositions()
{
    static datetime lastCheck = 0;
    if(TimeCurrent() - lastCheck < 1) return; // Throttle checks
    lastCheck = TimeCurrent();
    
    int total = PositionsTotal();
    for(int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            // Only process positions for our symbol
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            
            // Determine if this is an EA or manual trade
            long magic = PositionGetInteger(POSITION_MAGIC);
            bool isEATrade = (magic == MagicNumber);
            
            // Check if we need to log this position
            if(ShouldLogPosition(ticket))
            {
                // Determine trade purpose
                TradePurpose purpose = TRADE_PURPOSE_NEW_ENTRY;
                HedgePair pair;
                if(FindHedgePairByTicket(ticket, pair))
                    purpose = TRADE_PURPOSE_HEDGE;
                
                // Log the position
                WritePositionToFile(ticket, purpose);
                MarkPositionAsLogged(ticket);
            }
        }
    }
}


//+------------------------------------------------------------------+
//| HandleNewPosition                                            |
//+------------------------------------------------------------------+

void HandleNewPosition(ulong ticket, string symbol, bool isEATrade)
{
    PositionDetails newPos;
    if(PositionSelectByTicket(ticket))
    {
        newPos.ticket = ticket;
        newPos.symbol = symbol;
        newPos.lotSize = PositionGetDouble(POSITION_VOLUME);
        newPos.positionType = PositionGetInteger(POSITION_TYPE);
        newPos.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        newPos.openTime = (datetime)PositionGetInteger(POSITION_TIME);
        newPos.pnl = PositionGetDouble(POSITION_PROFIT);
        newPos.swap = PositionGetDouble(POSITION_SWAP);
        newPos.commission = GetCommissionFromHistory(ticket);
        
        // Set trade purpose based on comment or other criteria
        newPos.purpose = (PositionGetInteger(POSITION_MAGIC) == 0) ? 
                         TRADE_PURPOSE_NEW_ENTRY : TRADE_PURPOSE_HEDGE;

        AddPositionToArray(newPos);
        
        LogSymbolToFile(StringFormat("New position: %I64u %s %.2f lots @ %.5f", 
                      ticket, symbol, newPos.lotSize, newPos.openPrice));
       
    }
}


//+------------------------------------------------------------------+
//| HandleClosedPosition : used in case                                          |
//+------------------------------------------------------------------+

void HandleClosedPosition(ulong ticket, string symbol, bool isEATrade)

{
    CloseSpecificPosition(ticket); // Uses the function we previously defined
    
    // Update global counters
    for(int i = 0; i < PositionsCount; i++)
    {
        if(PositionsArray[i].ticket == ticket)
        {
            if(PositionsArray[i].positionType == POSITION_TYPE_BUY) 
                count_buys--;
            else 
                count_sells--;
            break;
        }
    }
    
    LogSymbolToFile(StringFormat("Closed position: %I64u %s", ticket, symbol));
   
}


//+------------------------------------------------------------------+
//| HandlePartialClose                                            |
//+------------------------------------------------------------------+
void HandlePartialClose(ulong ticket, string symbol, bool isEATrade)
{
    int posIndex = -1;
    for(int i = 0; i < PositionsCount; i++)
    {
        if(PositionsArray[i].ticket == ticket)
        {
            posIndex = i;
            break;
        }
    }
    
    if(posIndex >= 0 && PositionSelectByTicket(ticket))
    {
        PositionsArray[posIndex].lotSize = PositionGetDouble(POSITION_VOLUME);
        PositionsArray[posIndex].pnl = PositionGetDouble(POSITION_PROFIT);
        LogSymbolToFile(StringFormat("Updated partial close: %I64u %s %.2f lots", 
                      ticket, symbol, PositionsArray[posIndex].lotSize));
      
    }
}




//+------------------------------------------------------------------+
//| Position management functions                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| GetPositionDetails                                               |
//+------------------------------------------------------------------+
//Grok 4.June.2025
//6.June.2025 : updated to prevent cross-contamination of symbols across instruments.
      //Notes: Filters positions by symbol using NormalizeSymbol(), ensuring PositionsArray[] contains only the current symbol’s positions.
      //Preservation of existing position data in existingPositions[]; Two-pass processing: First to collect matching positions, second to identify hedged pairs.

bool GetPositionDetails(string symbol, PositionDetails &posDetails)
{
    string msg; // Temporary variable to store log messages

    // Validate the input symbol: Ensure it's not empty and has a valid bid price.
    // If invalid, log the error and return false to indicate failure.
    if(symbol == "" || !SymbolInfoDouble(symbol, SYMBOL_BID))
    {
        msg = "[" + symbol + "] Invalid symbol"; 
        LogSymbolToFile(msg); 
        return false;
    }

    // Initialize the output parameter (posDetails) to zero memory to avoid garbage data.
    ZeroMemory(posDetails);
    // Reset global counters for buy and sell positions to track new totals.
    count_buys = 0;
    count_sells = 0;
    // Initialize a counter for total positions found (used for return value).
    int totalPositions = 0;

    // Create a temporary array to preserve existing position data before rebuilding.
    // This ensures non-hedging info (e.g., highestProfit) is not lost.
    PositionDetails existingPositions[];
    ArrayResize(existingPositions, PositionsCount); 
    msg = "[" + symbol + "] Preserving " + IntegerToString(PositionsCount) + " existing positions before rebuild";
    LogSymbolToFile(msg); 
    for(int i = 0; i < PositionsCount; i++)
    {
        existingPositions[i] = PositionsArray[i]; // Simplified copy using struct assignment; 21June
      /*19June2025
        // Copy all fields from PositionsArray to existingPositions to retain state.
        existingPositions[i].ticket = PositionsArray[i].ticket;
        existingPositions[i].symbol = PositionsArray[i].symbol;
        existingPositions[i].lotSize = PositionsArray[i].lotSize;
        existingPositions[i].positionType = PositionsArray[i].positionType;
        existingPositions[i].openPrice = PositionsArray[i].openPrice;
        existingPositions[i].currentProfit = PositionsArray[i].currentProfit;
        existingPositions[i].swap = PositionsArray[i].swap;
        
        existingPositions[i].isHedged = PositionsArray[i].isHedged;
        existingPositions[i].hedgeTicket = PositionsArray[i].hedgeTicket;
        existingPositions[i].hedgeLotSize = PositionsArray[i].hedgeLotSize;
        ArrayCopy(existingPositions[i].hedgeHistory, PositionsArray[i].hedgeHistory); // Deep copy hedge history
        existingPositions[i].highestProfit = PositionsArray[i].highestProfit;
        existingPositions[i].protectedProfit = PositionsArray[i].protectedProfit;
        existingPositions[i].pendingClosure = PositionsArray[i].pendingClosure;
        existingPositions[i].pendingHedgeOrder = PositionsArray[i].pendingHedgeOrder;
        existingPositions[i].pendingReversal = PositionsArray[i].pendingReversal;
        */
    }

    // Reset PositionsArray to an empty state to prepare for a full rebuild.
    ArrayResize(PositionsArray, 0);
    PositionsCount = 0;

    // Get the total number of positions in the terminal and log it.
    int terminalPositions = PositionsTotal();
    msg = "[" + symbol + "] Terminal positions: " + IntegerToString(terminalPositions);
    LogSymbolToFile(msg);

    // First pass: Iterate through all terminal positions to collect those matching the symbol.
    string normalizedSymbol = NormalizeSymbol(symbol); 
   // Loop through all terminal positions, starting from the last one (reverse order)
         
      for(int i = terminalPositions - 1; i >= 0; i--)
      {
          // Get the ticket number of the position at index `i`
          ulong ticket = PositionGetTicket(i); 
          
          // Attempt to select the position by its ticket number
          if(!PositionSelectByTicket(ticket))
          {
              // If selection fails, log an error message and skip to the next position
              msg = "[" + symbol + "] Failed to select ticket " + IntegerToString(ticket);
              LogSymbolToFile(msg);
              continue; // Skip this iteration and move to the next position
          }
      
          // Retrieve the symbol of the selected position
          string posSymbol = PositionGetString(POSITION_SYMBOL); 
          
          // Normalize the position's symbol and compare it with the current symbol
          if(NormalizeSymbol(posSymbol) != normalizedSymbol)
          {
              // If there is a symbol mismatch, check if the position is simulated (magic number = 7)
              long magic = PositionGetInteger(POSITION_MAGIC);
              if(magic == 7) // Simulated trades are flagged as invalid
              {
                  // Log and alert about the critical symbol mismatch for simulated positions
                  msg = "[" + symbol + "] Critical symbol mismatch: Simulated position " + IntegerToString(ticket) + 
                        " (Magic=" + IntegerToString(magic) + ") on " + posSymbol;
                  LogSymbolToFile(msg);
                  Alert(msg); // Display an alert to notify the user
              }
              
              // Skip all mismatched positions (regardless of magic number) to ensure symbol-specific operation
              continue; // Move to the next position
          }
      
          // Resize the PositionsArray to accommodate the new position
          ArrayResize(PositionsArray, PositionsCount + 1); 
          
          // Populate the new position's details in the PositionsArray
          PositionsArray[PositionsCount].ticket = ticket; // Store the ticket number
          PositionsArray[PositionsCount].symbol = posSymbol; // Store the symbol
          PositionsArray[PositionsCount].lotSize = PositionGetDouble(POSITION_VOLUME); // Store the lot size
          PositionsArray[PositionsCount].positionType = PositionGetInteger(POSITION_TYPE); // Store the position type (BUY/SELL)
          PositionsArray[PositionsCount].openPrice = PositionGetDouble(POSITION_PRICE_OPEN); // Store the open price
          PositionsArray[PositionsCount].openTime = (datetime)PositionGetInteger(POSITION_TIME);
       
        PositionsArray[PositionsCount].pnl = PositionGetDouble(POSITION_PROFIT);
        PositionsArray[PositionsCount].swap = PositionGetDouble(POSITION_SWAP);
          
          // Initialize additional properties for the position
          PositionsArray[PositionsCount].isHedged = false; // Default: not hedged
          PositionsArray[PositionsCount].hedgeTicket = 0; // Default: no hedge ticket
          PositionsArray[PositionsCount].hedgeLotSize = 0.0; // Default: no hedge lot size
          ArrayResize(PositionsArray[PositionsCount].hedgeHistory, 0); // Clear any existing hedge history
          PositionsArray[PositionsCount].highestProfit = 0.0; // Default: no highest profit recorded
          PositionsArray[PositionsCount].protectedProfit = 0.0; // Default: no protected profit
          PositionsArray[PositionsCount].pendingClosure = false; // Default: not pending closure
          
      
          // Check if the current position exists in the `existingPositions` array
          for(int j = 0; j < ArraySize(existingPositions); j++)
          {
              // If the ticket matches, copy the highest profit and protected profit values
              if(existingPositions[j].ticket == ticket)
              {
                  PositionsArray[PositionsCount].highestProfit = existingPositions[j].highestProfit;
                  PositionsArray[PositionsCount].protectedProfit = existingPositions[j].protectedProfit;
                  break; // Exit the loop once the matching ticket is found
              }
          }
      
          // Increment the total count of processed positions
          totalPositions++; 
          
          // Count the number of BUY and SELL positions
          if(PositionsArray[PositionsCount].positionType == POSITION_TYPE_BUY)
              count_buys++;
          else if(PositionsArray[PositionsCount].positionType == POSITION_TYPE_SELL)
              count_sells++;
      
          // If `posDetails` is empty, assign the current position as the default position
          if(posDetails.ticket == 0)
              posDetails = PositionsArray[PositionsCount];
      
          // Add a flag to track whether the log message has already been written
          bool isLogged = false; // Initially set to false
      
          // Generate the log message for the current position
          msg = "[" + symbol + "] Collected ticket " + IntegerToString(ticket) + ": Type=" + 
                (PositionsArray[PositionsCount].positionType == POSITION_TYPE_BUY ? "BUY" : "SELL") + 
                ", Lots=" + DoubleToString(PositionsArray[PositionsCount].lotSize, 2);
      
          // Log the message only if it hasn't been logged yet
          if(!isLogged)
          {
              LogSymbolToFile(msg); // Write the message to the log file
              isLogged = true; // Mark the message as logged to prevent duplicates
          }
      
          // Increment the position count for the next iteration
          PositionsCount++; 
      }

    // Second pass: Identify hedged pairs (opposite directions with matching lots).
    bool pairedTickets[];
    ArrayResize(pairedTickets, PositionsCount); 
    ArrayInitialize(pairedTickets, false); 

    for(int i = 0; i < PositionsCount; i++)
    {
        if(pairedTickets[i]) continue; 

        for(int j = 0; j < PositionsCount; j++)
        {
            if(i == j || pairedTickets[j]) continue; 

            if(((PositionsArray[i].positionType == POSITION_TYPE_BUY && PositionsArray[j].positionType == POSITION_TYPE_SELL) ||
                (PositionsArray[i].positionType == POSITION_TYPE_SELL && PositionsArray[j].positionType == POSITION_TYPE_BUY)) &&
               MathAbs(PositionsArray[i].lotSize - PositionsArray[j].lotSize) < 0.0001)
            {
                 // Set hedge information
                PositionsArray[i].isHedged = true;
                PositionsArray[i].hedgeTicket = PositionsArray[j].ticket;
                PositionsArray[i].hedgeLotSize = PositionsArray[j].lotSize;
                PositionsArray[j].isHedged = true;
                PositionsArray[j].hedgeTicket = PositionsArray[i].ticket;
                PositionsArray[j].hedgeLotSize = PositionsArray[i].lotSize;

                // Add hedge history
                HedgeHistory newHistory;
                newHistory.hedgeTicket = PositionsArray[j].ticket;
                newHistory.hedgeTime = TimeCurrent();
                newHistory.closePrice = 0.0;
                newHistory.profitAtHedge = 0.0;
                newHistory.hedgeAction = 0;

                int newSize = ArraySize(PositionsArray[i].hedgeHistory) + 1;
                ArrayResize(PositionsArray[i].hedgeHistory, newSize);
                PositionsArray[i].hedgeHistory[newSize-1] = newHistory;

                newSize = ArraySize(PositionsArray[j].hedgeHistory) + 1;
                ArrayResize(PositionsArray[j].hedgeHistory, newSize);
                PositionsArray[j].hedgeHistory[newSize-1] = newHistory;

                pairedTickets[i] = true;
                pairedTickets[j] = true;

                msg = "[" + symbol + "] Position " + IntegerToString(PositionsArray[i].ticket) + 
                      " (Type=" + (PositionsArray[i].positionType == POSITION_TYPE_BUY ? "BUY" : "SELL") + 
                      ", Lots=" + DoubleToString(PositionsArray[i].lotSize, 2) + 
                      ") is hedged by " + IntegerToString(PositionsArray[j].ticket) + 
                      " (Type=" + (PositionsArray[j].positionType == POSITION_TYPE_BUY ? "BUY" : "SELL") + 
                      ", Lots=" + DoubleToString(PositionsArray[j].lotSize, 2) + ")";
                LogSymbolToFile(msg); 
                break;
            }
        }
    }

    // Log the final state of all positions in PositionsArray.
    for(int i = 0; i < PositionsCount; i++)
    {
        msg = "[" + symbol + "] Added ticket " + IntegerToString(PositionsArray[i].ticket) + ": Type=" + 
              (PositionsArray[i].positionType == POSITION_TYPE_BUY ? "BUY" : "SELL") + 
              ", Lots=" + DoubleToString(PositionsArray[i].lotSize, 2) + 
              ", Hedged=" + (PositionsArray[i].isHedged ? "Yes (" + IntegerToString(PositionsArray[i].hedgeTicket) + ")" : "No");
        LogSymbolToFile(msg); 
    }

    msg = "[" + symbol + "] PositionsCount=" + IntegerToString(PositionsCount) + 
          ", Buys=" + IntegerToString(count_buys) + 
          ", Sells=" + IntegerToString(count_sells);
    LogSymbolToFile(msg); 

    return totalPositions > 0;
}

/*bool GetPositionDetails(string symbol, PositionDetails &posDetails) 
{
   msg; // Reusable string for formatting log messages
   
   if(symbol == "" || !SymbolInfoDouble(symbol, SYMBOL_BID)) {
      // Alert is fine for critical errors, or log it too
      Alert("Error: Invalid or non-existent symbol: ", symbol);
      msg = StringFormat("Error: Invalid or non-existent symbol: %s", symbol);
       LogSymbolToFile(msg);
      return false;
   }


   int totalPositions = 0;
   const int MAX_RETRIES = 3;
   for(int attempt = 0; attempt < MAX_RETRIES; attempt++) {
      totalPositions = PositionsTotal();
      if(totalPositions > 0 || attempt == MAX_RETRIES - 1) break;
      // Log retry attempt
      msg = StringFormat("%s No positions found on attempt %d. Retrying after delay...", symbol, attempt + 1);
       LogSymbolToFile(msg);
      Sleep(500);
   }

   if(totalPositions == 0) {
      ArrayResize(PositionsArray, 0);
      PositionsCount = 0;
      // Log no positions found
      msg = StringFormat("%s No open positions found.", symbol);
       LogSymbolToFile(msg);
      CleanClosedPositions(symbol); // This function also needs conversion below
      return true;
   }

   // --- Existing logic for processing positions ---
        
      // Process all positions
      PositionDetails tempArray[];
      ArrayResize(tempArray, totalPositions);
      ulong processedTickets[];
      ArrayResize(processedTickets, totalPositions);
      int tempCount = 0;
      bool symbolPositionFound = false;
      
      for(int i = 0; i < totalPositions; i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(!PositionSelectByTicket(ticket)) continue;
      
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      double lotSize = PositionGetDouble(POSITION_VOLUME);
      long positionType = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentProfit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);
      double commission = PositionGetDouble(POSITION_COMMISSION);
      
      // Skip invalid positions
      if(posSymbol == "" || lotSize <= 0 || 
      (positionType != POSITION_TYPE_BUY && positionType != POSITION_TYPE_SELL)) {
      continue;
      }

      // Check for duplicates
      bool isDuplicate = false;
      for(int j = 0; j < tempCount; j++) {
         if(processedTickets[j] == ticket) {
            isDuplicate = true;
            break;
         }
      }
      if(isDuplicate) continue;

      processedTickets[tempCount] = ticket;

      bool isHedged = false;
      ulong hedgeTicket = 0;
      ulong hedgeHistory[];
      double highestProfit = currentProfit; // Default to current if not found
      double protectedProfit = 0.0; // Default if not found
      bool pendingClosure = false; // Default if not found

      for(int j = 0; j < PositionsCount; j++) { // Loop through OLD PositionsArray
         if(PositionsArray[j].ticket == ticket) {
            // Found existing data for this ticket, preserve its state
            isHedged = PositionsArray[j].isHedged;
            hedgeTicket = PositionsArray[j].hedgeTicket;
            ArrayCopy(hedgeHistory, PositionsArray[j].hedgeHistory); // Copy history
            highestProfit = PositionsArray[j].highestProfit;
            protectedProfit = PositionsArray[j].protectedProfit;
            pendingClosure = PositionsArray[j].pendingClosure;
            break;
         }
      }

      tempArray[tempCount].ticket = ticket;
       tempArray[tempCount].symbol = posSymbol;
       tempArray[tempCount].lotSize = lotSize;
       tempArray[tempCount].positionType = positionType;
       tempArray[tempCount].openPrice = openPrice;
       tempArray[tempCount].currentProfit = currentProfit; // Store potentially stale profit
       tempArray[tempCount].swap = swap;                 // Store potentially stale swap
       tempArray[tempCount].commission = commission;      // Store potentially stale commission
       tempArray[tempCount].isHedged = isHedged;
       tempArray[tempCount].hedgeTicket = hedgeTicket;
       ArrayCopy(tempArray[tempCount].hedgeHistory, hedgeHistory); // Copy history to temp array entry
       tempArray[tempCount].highestProfit = highestProfit;
       tempArray[tempCount].protectedProfit = protectedProfit;
       tempArray[tempCount].pendingClosure = pendingClosure;
       tempCount++;

         
         // Update output parameters for our symbol
         if(posSymbol == symbol) {
            symbolPositionFound = true;
            if(posDetails.ticket == 0) { // First position found
                posDetails = tempArray[tempCount-1];
            } else {
                // For multiple positions, calculate weighted average
                double totalLotSize = posDetails.lotSize + lotSize;
                posDetails.openPrice = (posDetails.openPrice * posDetails.lotSize + openPrice * lotSize) / totalLotSize;
                posDetails.lotSize = totalLotSize;
            }
         
         if(positionType == POSITION_TYPE_BUY) count_buys++;
         else count_sells++;
         }
         }
         
         // Update global positions array
         ArrayResize(PositionsArray, tempCount);
         for(int i = 0; i < tempCount; i++) {
         PositionsArray[i] = tempArray[i];
         }
         PositionsCount = tempCount;
         
         CleanClosedPositions(symbol);
            // Log summary
                      
   msg = StringFormat("%s GetPositionDetails: PositionsCount=%d, buys=%d, sells=%d, total lot size=%.2f",
                  symbol, PositionsCount, count_buys, count_sells, posDetails.lotSize);                   
    LogSymbolToFile(msg);

         return symbolPositionFound;
}
*/

//+------------------------------------------------------------------+
//| CheckPositionMetrics     : used in ProtectProfit()               |
//+------------------------------------------------------------------+
/*
 designed to retrieve and log  metrics (profit, swap, commission) for a specific position/ticket, with retries to handle temporary data issues.

Category: Main Function
    This function is part of the core monitoring loop, ensuring position metrics are valid and can trigger actions if needed.
Dependencies:
    Uses MQL5 functions like PositionSelectByTicket(), PositionGetDouble(), etc.
Called By:
   ProtectProfit()
    Main EA’s Defense logic (to monitor all tracked positions).


*/


void CheckPositionMetrics(ulong ticket, string symbol, bool logMetrics = false)
{
    if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == symbol)
    {
        double profit = PositionGetDouble(POSITION_PROFIT);
        double swap = PositionGetDouble(POSITION_SWAP);
        double commission = 0.0;
      
            if (HistorySelectByPosition(ticket))
            {
                for (int j = 0; j < HistoryDealsTotal(); j++)
                {
                    ulong histDealTicket = HistoryDealGetTicket(j);
                  if (HistoryDealGetInteger(histDealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
                     {
                         commission += HistoryDealGetDouble(histDealTicket, DEAL_COMMISSION);
                     }
                }
            }
        
         for (int i = 0; i < PositionsCount; i++)
        {
            if (PositionsArray[i].ticket == ticket)
            {
                PositionsArray[i].pnl = profit;
                PositionsArray[i].swap = swap;
                PositionsArray[i].commission = commission;
                
                if (logMetrics)
                {
                    string msg = symbol + " Metrics for ticket " + IntegerToString(ticket) +
                                 ": P&L=" + DoubleToString(profit, 2) +
                                 ", Swap=" + DoubleToString(swap, 2) +
                                 ", Commission=" + DoubleToString(commission, 2);
                    Alert(msg);
                    LogSymbolToFile(msg);
                }
                break;
            }
        }
    }
}





//+------------------------------------------------------------------+
//| CloseSpecificPosition                                            |
//| Closes a specific position with dynamic deviation                |
//used by case 5 & 6
//+------------------------------------------------------------------+

CloseResult CloseSpecificPosition(ulong ticket)
{
    string msg;
    CloseResult result;
    result.success = false;
    result.closePrice = 0.0;
    result.pnL = 0.0;
    CTrade localTradeUtil;

    // Check if position exists in tracking array
    int arrayIndex = -1;
    for(int i = 0; i < PositionsCount; i++) {
        if(PositionsArray[i].ticket == ticket) {
            arrayIndex = i;
            break;
        }
    }
    
    if(arrayIndex == -1) {
        msg = StringFormat("Position %I64u not found in tracking array.", ticket);
        LogSymbolToFile(msg);
        return result;
    }
    
   string symbol = PositionsArray[arrayIndex].symbol;
   
    // Check if position exists in terminal
    if(!PositionSelectByTicket(ticket)) {
        msg = StringFormat("Position %I64u not found in terminal.", ticket);
        LogSymbolToFile(msg);
        //PositionsArray[arrayIndex].pendingClosure = true;  //must centralize update in OnTradeTransactions() instead.
        return result;
    }

    // Get position details
    double currentPnL = PositionGetDouble(POSITION_PROFIT);
  /*  long positionType = PositionGetInteger(POSITION_TYPE);
    double lotSize = PositionGetDouble(POSITION_VOLUME);
   
    ulong magic = PositionGetInteger(POSITION_MAGIC);
   */
    // Configure CTrade
    localTradeUtil.SetExpertMagicNumber(PositionGetInteger(POSITION_MAGIC));
    localTradeUtil.SetDeviationInPoints((ulong)MathRound(GetDynamicDeviation(symbol)));
    localTradeUtil.SetTypeFillingBySymbol(symbol);

    // Attempt closure
    int retries = 3;
    for(int attempt = 0; attempt < retries; attempt++) {
        msg = StringFormat("%s Attempt %d to close position %I64u", symbol, attempt+1, ticket);
        LogSymbolToFile(msg);

        if(localTradeUtil.PositionClose(ticket)) {
            result.success = true;
            result.closePrice = localTradeUtil.ResultPrice();
            result.pnL = currentPnL;
            
           /* 10.June.2025
           // Handle hedge partner if exists //do not handle here, let this update be handled centrally inside OnTradeTransactions()
            if(PositionsArray[arrayIndex].isHedged) {
                ulong partnerTicket = PositionsArray[arrayIndex].hedgeTicket;
                for(int i = 0; i < PositionsCount; i++) {
                    if(PositionsArray[i].ticket == partnerTicket) {
                        msg = StringFormat("%s Unhedging partner position %I64u", symbol, partnerTicket);
                        LogSymbolToFile(msg);
                        PositionsArray[i].isHedged = false;
                        PositionsArray[i].hedgeTicket = 0;
                        break;
                    }
                }
            }
            
            PositionsArray[arrayIndex].pendingClosure = true;
            */
            break;
        } else {
            msg = StringFormat("%s Close attempt failed. Error: %d", symbol, GetLastError());
            LogSymbolToFile(msg);
            Sleep(500);
        }
    }

    return result;
}



//+------------------------------------------------------------------+
//| Hedge management functions                                       |
//+------------------------------------------------------------------+


//+---------------------------------------+
//| HandleHedgeOperation                  |
//+---------------------------------------+
//Grok 2.June.2025
void HandleHedgeOperation(ulong positionTicket, string context = "Defense")
{
    // Validate ticket first to get symbol and volume
    if(positionTicket == 0)
    {
        LogSymbolToFile("Hedge failed: Invalid ticket (0)");
        return;
    }
    if(!PositionSelectByTicket(positionTicket))
    {
        LogSymbolToFile(StringFormat("%s Hedge failed: Position %I64u not found", 
                      _Symbol, positionTicket));
        return;
    }

    // Get position details
    string symbol = PositionGetString(POSITION_SYMBOL);
    long positionType = PositionGetInteger(POSITION_TYPE);
    double positionVolume = PositionGetDouble(POSITION_VOLUME);

    // Now perform checks with valid symbol and volume
    // Check trading permissions
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        LogSymbolToFile(StringFormat("%s Trading not allowed by terminal", _Symbol));
        return;
    }
    
    if(SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_FULL)
    {
        LogSymbolToFile(StringFormat("%s Trading not allowed for symbol", symbol));
        return;
    }
    
    // Check margin requirements
    double marginRequired;
    if(!OrderCalcMargin(ORDER_TYPE_SELL, symbol, positionVolume, 
       SymbolInfoDouble(symbol, SYMBOL_ASK), marginRequired))
    {
        LogSymbolToFile(StringFormat("%s Failed to calculate margin for hedge", symbol));
        return;
    }
    
    if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < marginRequired)
    {
        LogSymbolToFile(StringFormat("%s Insufficient margin for hedge. Required: %.2f, Available: %.2f",
                      symbol, marginRequired, AccountInfoDouble(ACCOUNT_MARGIN_FREE)));
        return;
    }

    // Rest of original function...
    // [Keep all remaining code unchanged]
}

/*
void HandleHedgeOperation(ulong positionTicket, string context = "Defense")
{
    // === 1. Input Validation ===
    if(positionTicket == 0) {
        LogSymbolToFile("Hedge failed: Invalid ticket (0)");
        return;
    }
    
    if(!PositionSelectByTicket(positionTicket)) {
        LogSymbolToFile(StringFormat("%s Hedge failed: Position %I64u not found", 
                      _Symbol, positionTicket));
        return;
    }
    
    // === 2. Get Position Details ===
    string symbol = PositionGetString(POSITION_SYMBOL);
    long positionType = PositionGetInteger(POSITION_TYPE);
    double positionVolume = PositionGetDouble(POSITION_VOLUME);
    
    // === 3. Check Cooldown ===
    datetime currentTime = TimeCurrent();
    bool skipHedge = false;
    for(int i = 0; i < ArraySize(hedgeCooldowns); i++) {
        if(hedgeCooldowns[i].symbol == symbol && currentTime - hedgeCooldowns[i].lastHedgeTime < 300) { // 5-minute cooldown
            skipHedge = true;
            LogSymbolToFile(StringFormat("%s Hedge throttled - too soon since last hedge", symbol));
            break;
        }
    }
    if(skipHedge) return;
    
    // === 4. Check if Already Hedged ===
    if(IsPositionHedged(positionTicket)) {
        LogSymbolToFile(StringFormat("%s Position %I64u already hedged", symbol, positionTicket));
        return;
    }
    
    // === 5. Prepare Hedge Position ===
    PositionDetails hedgePos;
    hedgePos.symbol = symbol;
    hedgePos.lotSize = positionVolume;
    hedgePos.positionType = (positionType == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
    
    // === 6. Execute Hedge Trade ===
    ulong newTicket = (positionType == POSITION_TYPE_BUY) ?
        SellMarketTrade(symbol, hedgePos, 0, MagicNumber, TRADE_PURPOSE_HEDGE) :
        BuyMarketTrade(symbol, hedgePos, MagicNumber, TRADE_PURPOSE_HEDGE);
    
    // === 7. Update Global Tracking ===
    if(newTicket > 0) {
        // Use modular function to handle all tracking updates
        AddHedgePosition(positionTicket, newTicket, positionVolume, symbol);
        
        // Update cooldown and log success
        lastHedgeTime = TimeCurrent();
        UpdateHedgeCooldown(symbol);
        
        LogSymbolToFile(StringFormat("%s Successfully hedged position %I64u with %I64u (%s)", 
                      symbol, positionTicket, newTicket, context));
        Alert(StringFormat("%s Hedged position %I64u with %I64u (%s)", 
              symbol, positionTicket, newTicket, context));
    } else {
        LogSymbolToFile(StringFormat("%s Failed to place hedge for position %I64u", 
                      symbol, positionTicket));
        Alert(StringFormat("%s Failed to hedge position %I64u", 
              symbol, positionTicket));
    }
}
*/

//+------------------------------------------------------------------+
//| HandleTrendReversalCase                                          |
//+------------------------------------------------------------------+
// Handles trend reversal case (7) by closing original position
//Grok : 2.June.2025
void HandleTrendReversalCase(ulong ticket, PositionDetails &position, int PriceIndex)
{
    string symbol = position.symbol;
    string msg;

    // Find all hedge pairs for the symbol
    HedgePair pairs[];
    int pairCount;
    FindHedgePairs(symbol, pairs, pairCount);

    // Handle case with no hedge pairs
    if(pairCount == 0)
    {
        msg = StringFormat("%s No hedge pairs found for symbol", symbol);
        LogSymbolToFile(msg);
        //Alert(msg);
        return;
    }

    // Process each hedge pair
    for(int i = 0; i < pairCount; i++)
    {
        ulong ticket1 = pairs[i].ticket1;
        ulong ticket2 = pairs[i].ticket2;

        // Determine position types
        long type1 = 0, type2 = 0;
        if(PositionSelectByTicket(ticket1))
        {
            type1 = PositionGetInteger(POSITION_TYPE);
        }
        else
        {
            msg = StringFormat("%s Position %I64u not found", symbol, ticket1);
            LogSymbolToFile(msg);
            //Alert(msg);
            continue;
        }
        if(PositionSelectByTicket(ticket2))
        {
            type2 = PositionGetInteger(POSITION_TYPE);
        }
        else
        {
            msg = StringFormat("%s Position %I64u not found", symbol, ticket2);
            LogSymbolToFile(msg);
            //Alert(msg);
            continue;
        }

        // Identify unfavorable position
        ulong ticketToClose = 0;
        ulong ticketToKeep = 0;
        if(isTREND_Up)
        {
            if(type1 == POSITION_TYPE_SELL)
            {
                ticketToClose = ticket1;
                ticketToKeep = ticket2;
            }
            else if(type2 == POSITION_TYPE_SELL)
            {
                ticketToClose = ticket2;
                ticketToKeep = ticket1;
            }
        }
        else if(isTREND_Down)
        {
            if(type1 == POSITION_TYPE_BUY)
            {
                ticketToClose = ticket1;
                ticketToKeep = ticket2;
            }
            else if(type2 == POSITION_TYPE_BUY)
            {
                ticketToClose = ticket2;
                ticketToKeep = ticket1;
            }
        }

        // Close unfavorable position
        if(ticketToClose != 0)
        {
            CloseResult closeResult = CloseSpecificPosition(ticketToClose);
            if(closeResult.success)
            {
                msg = StringFormat("%s Closed unfavorable position %I64u (PnL: %.2f) due to trend reversal",
                                   symbol, ticketToClose, closeResult.pnL);
                LogSymbolToFile(msg);
                Alert(msg);
                // Updates handled by OnTradeTransaction
            }
            else
            {
                msg = StringFormat("%s Failed to close unfavorable position %I64u", symbol, ticketToClose);
                LogSymbolToFile(msg);
                //Alert(msg);
            }
        }
    }
}




//+------------------------------------------------------------------+
//| StoreHedgeMapping                                          |
//+------------------------------------------------------------------+
void StoreHedgeMapping(ulong orderTicket, ulong originalTicket)
{
    ArrayResize(hedgeMappings, hedgeMapCount + 1);
    hedgeMappings[hedgeMapCount].orderTicket = orderTicket;
    hedgeMappings[hedgeMapCount].originalTicket = originalTicket;
    hedgeMapCount++;
}



//+------------------------------------------------------------------+
//| GetOriginalTicketForHedge                                          |
//+------------------------------------------------------------------+
ulong GetOriginalTicketForHedge(ulong orderTicket)
{
    for(int i = 0; i < hedgeMapCount; i++)
    {
        if(hedgeMappings[i].orderTicket == orderTicket)
        {
            ulong originalTicket = hedgeMappings[i].originalTicket;
            for(int j = i; j < hedgeMapCount - 1; j++)
                hedgeMappings[j] = hedgeMappings[j + 1];
            hedgeMapCount--;
            ArrayResize(hedgeMappings, hedgeMapCount);
            return originalTicket;
        }
    }
    return 0;
}




//======= CASE HANDLER FUNCTIONS =======//

//+---------------------------------------------------------------+
//| IsPositionHedged : Helper function for HandleHedgeOperation   |
//+---------------------------------------------------------------+
// Returns true if the specified position is marked as hedged
bool IsPositionHedged(ulong positionTicket)
{
    for(int i = 0; i < PositionsCount; i++) {
        if(PositionsArray[i].ticket == positionTicket) {
            return PositionsArray[i].isHedged;
        }
    }
    return false;
}
 

//+------------------------------------------------------------------+
//| FindHedgePairs                                                  |
//+------------------------------------------------------------------+
//Grok

void FindHedgePairs(string symbol, HedgePair &pairs[], int &pairCount)
{
    pairCount = 0;
    ArrayResize(pairs, PositionsCount / 2); // Max possible pairs
    bool processed[];
    ArrayResize(processed, PositionsCount);
    ArrayFill(processed, 0, PositionsCount, false);

    for(int i = 0; i < PositionsCount; i++) {
        if(processed[i] || PositionsArray[i].symbol != symbol || !PositionsArray[i].isHedged) {
            continue;
        }
        ulong ticket1 = PositionsArray[i].ticket;
        ulong ticket2 = PositionsArray[i].hedgeTicket;
        double lotSize1 = PositionsArray[i].lotSize;
        if(ticket2 == 0) continue;

        int partnerIndex = -1;
        for(int j = 0; j < PositionsCount; j++) {
            if(PositionsArray[j].ticket == ticket2 && 
               PositionsArray[j].hedgeTicket == ticket1 && 
               PositionsArray[j].lotSize == lotSize1) { // Ensure same lot size
                partnerIndex = j;
                break;
            }
        }

        if(partnerIndex != -1 && !processed[partnerIndex]) {
            pairs[pairCount].ticket1 = ticket1;
            pairs[pairCount].ticket2 = ticket2;
            pairCount++;
            processed[i] = true;
            processed[partnerIndex] = true;
        }
    }
    ArrayResize(pairs, pairCount);
}

//Helper function : 
bool FindHedgePairByTicket(ulong ticket, HedgePair &pair)
{
    HedgePair pairs[];
    int pairCount;
    FindHedgePairs(_Symbol, pairs, pairCount);
    
    for(int i = 0; i < pairCount; i++)
    {
        if(pairs[i].ticket1 == ticket || pairs[i].ticket2 == ticket)
        {
            pair = pairs[i];
            return true;
        }
    }
    return false;
}



//+------------------------------------------------------------------+
//| Trade transaction handlers                                       |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| ProcessOrderEvents                                            |
//+------------------------------------------------------------------+

void ProcessOrderEvents(const MqlTradeTransaction &trans, const MqlTradeResult &result, bool isEATrade)
{
    if(trans.type == TRADE_TRANSACTION_ORDER_ADD)
    {
        if(trans.order == pendingBuyHedgeOrderTicket)
        {
            isBuyHedgePending = false;
            LogSymbolToFile("BUY hedge order placed: " + IntegerToString(trans.order));
        }
        else if(trans.order == pendingSellHedgeOrderTicket)
        {
            isSellHedgePending = false;
            LogSymbolToFile("SELL hedge order placed: " + IntegerToString(trans.order));
        }
    }
    else if(trans.type == TRADE_TRANSACTION_ORDER_DELETE)
    {
        if(trans.order == pendingBuyHedgeOrderTicket)
        {
            pendingBuyHedgeOrderTicket = 0;
            isBuyHedgePending = false;
        }
        else if(trans.order == pendingSellHedgeOrderTicket)
        {
            pendingSellHedgeOrderTicket = 0;
            isSellHedgePending = false;
        }
    }
}

//+------------------------------------------------------------------+
//| Position update functions                                        |
//+------------------------------------------------------------------+

bool AddPositionToArray(const PositionDetails &pos)
{
    if(ArrayResize(PositionsArray, PositionsCount+1) == PositionsCount+1)
    {
        PositionsArray[PositionsCount] = pos;
        PositionsCount++;
        return true;
    }
    return false;
}



//+------------------------------------------------------------------+
//| UpdateTradeHedgedState - Essential for maintaining position state |
//+------------------------------------------------------------------+
//handles just hedge logic; called during hedge operations (like in CalculateHedgingStatus())
// Use this when you ONLY need to update hedge status (lightweight)
bool UpdateTradeHedgedState(ulong ticket, bool isHedged, ulong hedgeTicket = 0)
{
    for(int i = 0; i < PositionsCount; i++)
    {
        if(PositionsArray[i].ticket == ticket)
        {
            PositionsArray[i].isHedged = isHedged;
            if(hedgeTicket != 0)
                PositionsArray[i].hedgeTicket = hedgeTicket;
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| UpdatePositionDetails - Essential for maintaining position state |
//+------------------------------------------------------------------+
//handles general position synchronization;  is called for general position maintenance
// Use this for FULL position refresh from MT5 (more comprehensive)
void UpdatePositionDetails(PositionDetails &pos, bool isNewPosition=true)
{
    if(PositionSelectByTicket(pos.ticket))
    {
    
         // Add hedge validation check here
        if(pos.isHedged && !PositionSelectByTicket(pos.hedgeTicket)) {
            pos.isHedged = false;  // Auto-cleanup if hedge partner disappeared
           LogSymbolToFile("Auto-cleaned missing hedge for ticket: " + IntegerToString(pos.ticket));
        }
        // Core position info (always updated)
        pos.ticket = PositionGetInteger(POSITION_TICKET);
        pos.symbol = PositionGetString(POSITION_SYMBOL);
        pos.lotSize = PositionGetDouble(POSITION_VOLUME);
        pos.positionType = PositionGetInteger(POSITION_TYPE);
        pos.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        pos.openTime = (datetime)PositionGetInteger(POSITION_TIME);
    
        // Dynamic values (existing positions only)
        if(!isNewPosition)
        {
            pos.pnl = PositionGetDouble(POSITION_PROFIT);
            pos.swap = PositionGetDouble(POSITION_SWAP);
            
            // Comprehensive commission calculation
            pos.commission = 0.0;
            if(HistorySelectByPosition(pos.ticket))
            {
                int deals = HistoryDealsTotal();
                for(int i = 0; i < deals; i++)
                {
                    ulong dealTicket = HistoryDealGetTicket(i);
                    if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
                    {
                        pos.commission += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                        LogSymbolToFile(StringFormat("Commission added: %.2f for ticket %I64u",
                                      HistoryDealGetDouble(dealTicket, DEAL_COMMISSION), pos.ticket));
                    }
                }
            }
            
            // Track highest profit achieved
            if(pos.pnl > pos.highestProfit)
            {
                LogSymbolToFile(StringFormat("New high profit: %.2f (was %.2f) for ticket %I64u",
                              pos.pnl, pos.highestProfit, pos.ticket));
                pos.highestProfit = pos.pnl;
            }
        }
    }
    else
    {
        LogSymbolToFile("UpdatePositionDetails failed - couldn't select ticket: " + IntegerToString(pos.ticket));
    }
}



//+------------------------------------------------------------------+
//| UpdatePositionTracking  - Revised to use struct                                            |
//+------------------------------------------------------------------+
/*
Orchestrates the position tracking process by clearing orphaned hedge references, cleaning closed positions, updating the PositionsArray with current positions, and recalculating hedging status.
Category: Main Function

    This is a core function that ensures the EA’s position tracking is up-to-date, called frequently to maintain accurate position data.

Dependencies:
    Calls CleanClosedPositions() to remove closed positions.
    Calls GetPositionDetails() to update the PositionsArray.
    Calls CalculateHedgingStatus() to update hedging status.
    
Purpose: Orchestrates complete position synchronization and hedge status maintenance.
Behavior:
    Clears orphaned hedge references (hedge partners no longer exist).
    Calls:
        CleanClosedPositions
        GetPositionDetails
        CalculateHedgingStatus
    Logs a summary of buy/sell counts.
*/

/*

void UpdatePositionTracking(const MqlTradeTransaction &trans, const MqlTradeResult &result, string &msg)
{
    // Initialize counters for buy and sell positions
    int tempBuys = 0;
    int tempSells = 0;

    // Process the transaction based on its type
    switch (trans.type)
    {
        case TRADE_TRANSACTION_DEAL_ADD:
            // Handle new deal addition (e.g., position opening)
            if (trans.deal > 0 && HistoryDealSelect(trans.deal))
            {
                ulong ticket = trans.position;
                if (ticket > 0)
                {
                    string symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
                    string normalizedSymbol = NormalizeSymbol(symbol);
                    string normalizedChartSymbol = NormalizeSymbol(_Symbol);
                    // Skip simulated trades (MagicNumber == 7) if symbol mismatches
                    if (normalizedSymbol != normalizedChartSymbol)
                    {
                        long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
                        if (magic == 7)
                        {
                            msg = "[" + symbol + "] Skipping simulated trade: Ticket=" + IntegerToString(ticket) + 
                                  ", Magic=" + IntegerToString(magic);
                            LogSymbolToFile(msg);
                            return;
                        }
                    }

                    // Add new position to PositionsArray[]
                    int newSize = PositionsCount + 1;
                    ArrayResize(PositionsArray, newSize);
                    int newIndex = newSize - 1;
                    PositionsArray[newIndex].ticket = ticket;
                    PositionsArray[newIndex].symbol = symbol;
                    PositionsArray[newIndex].lotSize = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
                    PositionsArray[newIndex].positionType = (HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_BUY) ? 
                                                            POSITION_TYPE_BUY : POSITION_TYPE_SELL;
                    PositionsArray[newIndex].openPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
                    PositionsArray[newIndex].isHedged = false;
                    PositionsArray[newIndex].hedgeTicket = 0;
                    PositionsArray[newIndex].hedgeLotSize = 0.0;
                    ArrayResize(PositionsArray[newIndex].hedgeHistory, 0);
                    PositionsArray[newIndex].highestProfit = 0.0;
                    PositionsArray[newIndex].protectedProfit = 0.0;
                    PositionsArray[newIndex].pendingClosure = false;
                    PositionsArray[newIndex].pendingHedgeOrder = 0;
                    PositionsArray[newIndex].pendingReversal = false;
                    PositionsCount = newSize;

                    // Increment counters based on position type
                    if (PositionsArray[newIndex].positionType == POSITION_TYPE_BUY) tempBuys++;
                    else tempSells++;

                    msg = "[" + symbol + "] Added position: Ticket=" + IntegerToString(ticket) + 
                          ", Type=" + (PositionsArray[newIndex].positionType == POSITION_TYPE_BUY ? "BUY" : "SELL") + 
                          ", Lots=" + DoubleToString(PositionsArray[newIndex].lotSize, 2);
                    LogSymbolToFile(msg);
                }
            }
            break;

        case TRADE_TRANSACTION_POSITION:
            // Handle position updates or closures
            if (trans.position > 0)
            {
                if (!PositionSelectByTicket(trans.position))
                {
                    // Position has been closed, remove from PositionsArray[]
                    for (int i = PositionsCount - 1; i >= 0; i--)
                    {
                        if (PositionsArray[i].ticket == trans.position)
                        {
                            if (PositionsArray[i].isHedged && PositionsArray[i].hedgeTicket != 0)
                            {
                                // Unlink the hedge pair
                                for (int j = 0; j < PositionsCount; j++)
                                {
                                    if (PositionsArray[j].ticket == PositionsArray[i].hedgeTicket)
                                    {
                                        PositionsArray[j].isHedged = false;
                                        PositionsArray[j].hedgeTicket = 0;
                                        msg = "[" + PositionsArray[i].symbol + "] Unhedged partner " + 
                                              IntegerToString(PositionsArray[j].ticket) + 
                                              " after " + IntegerToString(trans.position) + " closed";
                                        LogSymbolToFile(msg);
                                        break;
                                    }
                                }
                            }
                            // Shift and resize array to remove the closed position
                            for (int j = i; j < PositionsCount - 1; j++)
                                PositionsArray[j] = PositionsArray[j + 1];
                            ArrayResize(PositionsArray, --PositionsCount);
                            msg = "[" + PositionsArray[i].symbol + "] Removed closed position: Ticket=" + 
                                  IntegerToString(trans.position);
                            LogSymbolToFile(msg);
                            break;
                        }
                    }
                }
                else
                {
                    // Update existing position metrics
                    for (int i = 0; i < PositionsCount; i++)
                    {
                        if (PositionsArray[i].ticket == trans.position)
                        {
                            PositionsArray[i].currentProfit = PositionGetDouble(POSITION_PROFIT);
                            PositionsArray[i].swap = PositionGetDouble(POSITION_SWAP);
                            PositionsArray[i].highestProfit = MathMax(PositionsArray[i].highestProfit, 
                                                                  PositionGetDouble(POSITION_PROFIT));
                            break;
                        }
                    }
                }
            }
            break;
    }

    // Recalculate global counters based on current PositionsArray[]
    for (int i = 0; i < PositionsCount; i++)
    {
        if (PositionsArray[i].symbol == _Symbol)
        {
            if (PositionsArray[i].positionType == POSITION_TYPE_BUY) tempBuys++;
            else tempSells++;
        }
    }
    count_buys = tempBuys;
    count_sells = tempSells;

    // Log the updated tracking state
    msg = "[" + _Symbol + "] Position tracking updated: Buys=" + IntegerToString(count_buys) + 
          ", Sells=" + IntegerToString(count_sells);
    LogSymbolToFile(msg);
}

/* 20June_v1 working version 
void UpdatePositionTracking(string symbol, PositionDetails &posDetails) 
{
       // temp counts 
     string msg;
    int tempBuys = 0;
    int tempSells = 0;
   
    
 // Phase 1: Clean orphaned references for the current symbol
    for(int i = PositionsCount - 1; i >= 0; i--)
    {
        if(PositionsArray[i].symbol != symbol) continue; // Skip non-matching symbols

        if(PositionsArray[i].positionType == POSITION_TYPE_BUY)
            tempBuys++;
        else
            tempSells++;

        if(PositionsArray[i].hedgeTicket != 0 && !PositionSelectByTicket(PositionsArray[i].hedgeTicket))
        {
            RemovePositionFromTracking(PositionsArray[i].ticket);
            msg = StringFormat("%s Cleared orphaned hedge reference for ticket %I64u",
                               symbol, PositionsArray[i].ticket);
            LogSymbolToFile(msg);
            PositionsArray[i].isHedged = false;
            PositionsArray[i].hedgeTicket = 0;
        }
    }

    // Phase 2-3: Clean and verify (unchanged)
 
    VerifyAllHedgeRelationships(symbol);
  
    // Phase 4: Update position metrics
    
    if(!GetPositionDetails(symbol, posDetails)) {
        ZeroMemory(posDetails);
    }

    // ONLY update globals AFTER all processing
    count_buys = tempBuys;
    count_sells = tempSells;
    
    // Final logging
    msg = StringFormat("%s Position tracking updated: Buys=%d, Sells=%d, LotSize=%.2f",
                      symbol, count_buys, count_sells, posDetails.lotSize);
    LogSymbolToFile(msg);
}
 */           
     


      //+------------------------------------------------------------------+
      //| VerifyAllHedgeRelationships - New Helper Function                |
      //+------------------------------------------------------------------+
      
      void VerifyAllHedgeRelationships(string symbol)
      {
          for(int i = 0; i < PositionsCount; i++) {
              if(PositionsArray[i].symbol != symbol) continue;
              
              if(PositionsArray[i].isHedged && PositionsArray[i].hedgeTicket != 0) {
                  bool mutualRelationshipFound = false;
                  
                  // Check if partner exists and references back
                  for(int j = 0; j < PositionsCount; j++) {
                      if(PositionsArray[j].ticket == PositionsArray[i].hedgeTicket) {
                          if(PositionsArray[j].hedgeTicket == PositionsArray[i].ticket) {
                              mutualRelationshipFound = true;
                              
                              // Additional verification
                              if(PositionsArray[j].symbol != symbol || 
                                 PositionsArray[j].positionType == PositionsArray[i].positionType) {
                                  LogSymbolToFile(StringFormat("%s Invalid hedge pair %I64u<->%I64u - same type or symbol mismatch",
                                            symbol,
                                            PositionsArray[i].ticket,
                                            PositionsArray[j].ticket));
                                  mutualRelationshipFound = false;
                              }
                          }
                          break;
                      }
                  }
                  
                  if(!mutualRelationshipFound) {
                      LogSymbolToFile(StringFormat("%s Clearing invalid hedge for %I64u (partner %I64u)",
                                symbol,
                                PositionsArray[i].ticket,
                                PositionsArray[i].hedgeTicket));
                      PositionsArray[i].isHedged = false;
                      PositionsArray[i].hedgeTicket = 0;
                  }
              }
          }
      }


//+------------------------------------------------------------------+
//| Utility functions                                                |
//+------------------------------------------------------------------+


    
 string NormalizeSymbol(string sym)
{
    if(sym == "") return sym;
    string result = sym;
    StringToUpper(result);
    int dotPos = StringFind(result, ".");
    if(dotPos != -1) result = StringSubstr(result, 0, dotPos);
    return result;
}


//+------------------------------------------------------------------+
//| GetCommissionFromHistory: More robust commission calculation     |
//+------------------------------------------------------------------+
double GetCommissionFromHistory(ulong ticket)
{
    double commission = 0;
    
    if(HistorySelectByPosition(ticket))
    {
        int deals = HistoryDealsTotal();
        for(int i = 0; i < deals; i++)
        {
            ulong dealTicket = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
            {
                commission += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            }
        }
    }
    return NormalizeDouble(commission, 2);
}


//+------------------------------------------------------------------+
//| GetTicketFromPositionsArray : 
//+------------------------------------------------------------------+
//If you already have the position object, you can directly use its ticket field: ulong ticket = position.ticket;
//For new or closed positions:ulong ticket = trans.position;
ulong GetTicketFromPositionsArray(string symbol, ulong ticket)
{
    for (int i = 0; i < PositionsCount; i++)
    {
        if (PositionsArray[i].symbol == symbol && PositionsArray[i].ticket == ticket)
        {
            return PositionsArray[i].ticket;
        }
    }
    return 0; // Return 0 if no matching ticket is found
}




//5.May.2025 : Qwen new functions
//+------------------------------------------------------------------+
//| IsSymbolInHedgeCooldown                                        |
//+------------------------------------------------------------------+
// Function to check if a symbol is in hedge cooldown
bool IsSymbolInHedgeCooldown(string symbol) {
    datetime currentTime = TimeCurrent();
    for(int i = 0; i < ArraySize(hedgeCooldowns); i++) {
        if(hedgeCooldowns[i].symbol == symbol && 
           currentTime - hedgeCooldowns[i].lastHedgeTime < 300) {
            return true;
        }
    }
    return false;
}



//+------------------------------------------------------------------+
//| UpdateHedgeCooldown                                        |
//+------------------------------------------------------------------+

// Function to update hedge cooldown for a symbol
void UpdateHedgeCooldown(string symbol) {
    bool found = false;
    for(int i = 0; i < ArraySize(hedgeCooldowns); i++) {
        if(hedgeCooldowns[i].symbol == symbol) {
            hedgeCooldowns[i].lastHedgeTime = TimeCurrent();
            found = true;
            break;
        }
    }
    if(!found) {
        int size = ArraySize(hedgeCooldowns);
        ArrayResize(hedgeCooldowns, size + 1);
        hedgeCooldowns[size].symbol = symbol;
        hedgeCooldowns[size].lastHedgeTime = TimeCurrent();
    }
}




//+------------------------------------------------------------------+
//| RemovePositionFromTracking :
//+------------------------------------------------------------------+
void RemovePositionFromTracking(ulong ticket) 
   {
    for(int i = 0; i < PositionsCount; i++) {
        if(PositionsArray[i].ticket == ticket) {
            // Handle hedge partner if exists
            if(PositionsArray[i].isHedged && PositionsArray[i].hedgeTicket != 0) {
                for(int j = 0; j < PositionsCount; j++) {
                    if(PositionsArray[j].ticket == PositionsArray[i].hedgeTicket) {
                        PositionsArray[j].isHedged = false;
                        PositionsArray[j].hedgeTicket = 0;
                        break;
                    }
                }
            }
            
            // Shift remaining elements
            for(int j = i; j < PositionsCount-1; j++) {
                PositionsArray[j] = PositionsArray[j+1];
            }
            PositionsCount--;
            ArrayResize(PositionsArray, PositionsCount);
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| CalculateHedgingStatus  (Safety Net - Optional Logging)                                            |
//+------------------------------------------------------------------+
/*
Purpose: Auto-pairs matching BUY and SELL positions for a symbol based on volume.
Behavior:
    Categorizes and filters current positions by BUY/SELL.
    Computes unhedged volumes.
    If mismatch: unhedges all positions for that symbol.
    Else: attempts to hedge unhedged positions by exact volume match.
    Logs pairings and unpairings.
 */
   // This function also acts as a safety net. Logging might be less critical here
   // unless debugging specific pairing issues potentially caused by it.
   // Add logging if needed, following the StringFormat pattern.
   // ... (Existing logic) ...

   // Example log point if unhedging occurs here:
void CalculateHedgingStatus(string symbol) {
   struct PositionInfo {
      ulong ticket;
      double volume;
      bool isHedged;
      ulong hedgeTicket;
   };

   PositionInfo buyPositions[];
   PositionInfo sellPositions[];
   int buyCount = 0;
   int sellCount = 0;

   ArrayResize(buyPositions, PositionsCount);
   ArrayResize(sellPositions, PositionsCount);

   for(int i = 0; i < PositionsCount; i++) {
      if(PositionsArray[i].symbol != symbol || !PositionSelectByTicket(PositionsArray[i].ticket)) continue;

      double volume = PositionsArray[i].lotSize;
      if(PositionsArray[i].positionType == POSITION_TYPE_BUY) {
         buyPositions[buyCount].ticket = PositionsArray[i].ticket;
         buyPositions[buyCount].volume = volume;
         buyPositions[buyCount].isHedged = PositionsArray[i].isHedged;
         buyPositions[buyCount].hedgeTicket = PositionsArray[i].hedgeTicket;
         buyCount++;
      } else if(PositionsArray[i].positionType == POSITION_TYPE_SELL) {
         sellPositions[sellCount].ticket = PositionsArray[i].ticket;
         sellPositions[sellCount].volume = volume;
         sellPositions[sellCount].isHedged = PositionsArray[i].isHedged;
         sellPositions[sellCount].hedgeTicket = PositionsArray[i].hedgeTicket;
         sellCount++;
      }
   }

   ArrayResize(buyPositions, buyCount);
   ArrayResize(sellPositions, sellCount);

   double totalBuyVolume = 0;
   double totalSellVolume = 0;
   for(int i = 0; i < buyCount; i++) {
      if(!buyPositions[i].isHedged) totalBuyVolume += buyPositions[i].volume;
   }
   for(int i = 0; i < sellCount; i++) {
      if(!sellPositions[i].isHedged) totalSellVolume += sellPositions[i].volume;
   }

   double hedgedVolume = MathMin(totalBuyVolume, totalSellVolume);
   if(hedgedVolume <= 0) {
      for(int i = 0; i < PositionsCount; i++) {
       if(PositionsArray[i].symbol == symbol && PositionsArray[i].isHedged) {
          // Log before updating state
            string msg = StringFormat("%s CalculateHedgingStatus: Unhedging ticket %I64u as counterpart volume mismatch.",
                                      symbol, PositionsArray[i].ticket);
            LogSymbolToFile(msg);
            UpdateTradeHedgedState(PositionsArray[i].ticket, false, 0);
         }
      }
      return;
   }

   for(int i = 0; i < buyCount; i++) {
      if(buyPositions[i].isHedged) continue;
      for(int j = 0; j < sellCount; j++) {
         if(sellPositions[j].isHedged) continue;
         if(buyPositions[i].volume == sellPositions[j].volume) {
          // Log before updating state
            string msg = StringFormat("%s CalculateHedgingStatus: Auto-pairing ticket %I64u (BUY) with %I64u (SELL) based on volume match.",
                                      symbol, buyPositions[i].ticket, sellPositions[j].ticket);
            LogSymbolToFile(msg);
            buyPositions[i].isHedged = true;
            buyPositions[i].hedgeTicket = sellPositions[j].ticket;
            sellPositions[j].isHedged = true;
            sellPositions[j].hedgeTicket = buyPositions[i].ticket;
            UpdateTradeHedgedState(buyPositions[i].ticket, true, sellPositions[j].ticket);
            UpdateTradeHedgedState(sellPositions[j].ticket, true, buyPositions[i].ticket);
            break;
         }
      }
   }
}



bool ShouldLogPosition(ulong ticket)
{
    for(int i = 0; i < PositionsCount; i++)
    {
        if(PositionsArray[i].ticket == ticket)
        {
            // Only log if not already logged recently
            return (PositionsArray[i].lastLogTime == 0 || 
                   TimeCurrent() - PositionsArray[i].lastLogTime > 60);
        }
    }
    return true; // New position
}

//+------------------------------------------------------------------+
//| GetLastChangedTicket - Returns the most recently modified ticket |
//+------------------------------------------------------------------+
ulong GetLastChangedTicket()
{
    static ulong lastChangedTicket = 0;
    static datetime lastChangeTime = 0;
    
    // Check positions for recent changes
    for(int i = 0; i < PositionsCount; i++)
    {
        if(PositionSelectByTicket(PositionsArray[i].ticket))
        {
            datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME_UPDATE);
            if(positionTime > lastChangeTime)
            {
                lastChangeTime = positionTime;
                lastChangedTicket = PositionsArray[i].ticket;
            }
        }
    }
    
    // Also check history for recently closed positions
    if(HistorySelect(0, TimeCurrent()))
    {
        int total = HistoryDealsTotal();
        for(int i = 0; i < total; i++)
        {
            ulong dealTicket = HistoryDealGetTicket(i);
            datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
            if(dealTime > lastChangeTime)
            {
                lastChangeTime = dealTime;
                lastChangedTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            }
        }
    }
    
    return lastChangedTicket;
}

//+------------------------------------------------------------------+
//| Position logging functions                                       |
//+------------------------------------------------------------------+
// Global variables for file management
bool headersWritten = false;
datetime lastPositionCheck = 0;

//+------------------------------------------------------------------+
//| Unified Position Logging Controller                              |
//+------------------------------------------------------------------+

void ManagePositionLogging(ulong changedTicket = 0)
{
    static datetime lastLogTime = 0;
    
    // Throttle logging to once per second
    if(TimeCurrent() - lastLogTime < 1) return;
    lastLogTime = TimeCurrent();

    // Case 1: Specific position changed
    if(changedTicket > 0)
    {
        // For active positions
        if(PositionSelectByTicket(changedTicket))
        {
            string positionSymbol = PositionGetString(POSITION_SYMBOL);
            if(positionSymbol != _Symbol)
            {
                LogSymbolToFile(StringFormat("Skipping foreign symbol position %I64u (%s)", 
                              changedTicket, positionSymbol));
                return;
            }

            // Determine trade purpose
            TradePurpose purpose = TRADE_PURPOSE_NEW_ENTRY;
            long positionMagic = PositionGetInteger(POSITION_MAGIC);
            if(positionMagic != MagicNumber) purpose = TRADE_PURPOSE_MANUAL;
            
            HedgePair pair;
            if(FindHedgePairByTicket(changedTicket, pair))
                purpose = (positionMagic == MagicNumber) ? TRADE_PURPOSE_HEDGE : TRADE_PURPOSE_MANUAL_HEDGE;
            
            WritePositionToFile(changedTicket, purpose);
        }
        // For closed positions
        else
        {
            // Get magic number from deal history
            if(HistorySelectByPosition(changedTicket))
            {
                int deals = HistoryDealsTotal();
                if(deals > 0)
                {
                    ulong dealTicket = HistoryDealGetTicket(0);
                    string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
                    
                    if(dealSymbol != _Symbol)
                    {
                        LogSymbolToFile(StringFormat("Skipping foreign symbol closed position %I64u (%s)", 
                                      changedTicket, dealSymbol));
                        return;
                    }

                    long positionMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
                    TradePurpose purpose = TRADE_PURPOSE_NEW_ENTRY;
                    if(positionMagic != MagicNumber) purpose = TRADE_PURPOSE_MANUAL;
                    
                    HedgePair pair;
                    if(FindHedgePairByTicket(changedTicket, pair))
                        purpose = (positionMagic == MagicNumber) ? TRADE_PURPOSE_HEDGE : TRADE_PURPOSE_MANUAL_HEDGE;
                    
                    WriteClosedPositionToFile(changedTicket, purpose);
                }
            }
        }
        return;
    }

    // Case 2: Full refresh fallback
    LogSymbolToFile("Performing full position log refresh");
    int total = PositionsTotal();
    for(int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            string positionSymbol = PositionGetString(POSITION_SYMBOL);
            if(positionSymbol != _Symbol) continue;

            // Determine trade purpose
            TradePurpose purpose = TRADE_PURPOSE_NEW_ENTRY;
            long positionMagic = PositionGetInteger(POSITION_MAGIC);
            if(positionMagic != MagicNumber)
                purpose = TRADE_PURPOSE_MANUAL;
            
            HedgePair pair;
            if(FindHedgePairByTicket(ticket, pair))
                purpose = (positionMagic == MagicNumber) ? TRADE_PURPOSE_HEDGE : TRADE_PURPOSE_MANUAL_HEDGE;
            
            WritePositionToFile(ticket, purpose);
        }
    }
}
//+------------------------------------------------------------------+
//| WriteClosedPositionToFile |
//+------------------------------------------------------------------+
// Implement WriteClosedPositionToFile
void WriteClosedPositionToFile(ulong ticket, TradePurpose purpose)
{
    if(!HistoryDealSelect(ticket)) return;
    
    // Initialize array
    ArrayResize(valueParams, ArraySize(headerParams));
    for(int i = 0; i < ArraySize(valueParams); i++)
        valueParams[i] = "0";
    
    // Populate data
    valueParams[0] = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
    valueParams[1] = HistoryDealGetString(ticket, DEAL_SYMBOL);
    valueParams[2] = IntegerToString(ticket);
    valueParams[7] = IntegerToString(HistoryDealGetInteger(ticket, DEAL_MAGIC));
    valueParams[8] = DoubleToString(HistoryDealGetDouble(ticket, DEAL_PRICE), _Digits);
    valueParams[9] = "0"; // Current price (closed positions)
    valueParams[10] = DoubleToString(HistoryDealGetDouble(ticket, DEAL_PRICE), _Digits);
    valueParams[11] = DoubleToString(HistoryDealGetDouble(ticket, DEAL_VOLUME), 2);
    valueParams[12] = DoubleToString(HistoryDealGetDouble(ticket, DEAL_PROFIT), 2);
    valueParams[138] = IntegerToString(purpose);
    
    WriteFile_EntryData(valueParams, ticket);
}
//+------------------------------------------------------------------+
//| Enhanced CheckClosedPositionsLogging (renamed to avoid conflict) |
//+------------------------------------------------------------------+
void CheckClosedPositionsLogging()
{
    datetime start = TimeCurrent() - 60; // Check last minute
    if(!HistorySelect(start, TimeCurrent())) return;
    
    int totalDeals = HistoryDealsTotal();
    for(int i = 0; i < totalDeals; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT &&
           HistoryDealGetString(dealTicket, DEAL_SYMBOL) == _Symbol)
        {
            ulong posTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            
            if(ShouldLogClosedPosition(posTicket))
            {
                TradePurpose purpose = TRADE_PURPOSE_NEW_ENTRY;
                HedgePair pair;
                if(FindHedgePairByTicket(posTicket, pair))
                    purpose = TRADE_PURPOSE_UNHEDGE;
                
                WriteClosedPositionToFile(dealTicket, purpose);
                MarkClosedPositionAsLogged(posTicket);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Unified Position Logger                                          |
//+------------------------------------------------------------------+
void LogPosition(ulong ticket)
{
    // Determine trade purpose
    TradePurpose purpose = TRADE_PURPOSE_NEW_ENTRY;
    if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
        purpose = TRADE_PURPOSE_MANUAL;
    
    // Check if this is a hedge
    HedgePair pair;
    if(FindHedgePairByTicket(ticket, pair))
        purpose = (purpose == TRADE_PURPOSE_NEW_ENTRY) ? TRADE_PURPOSE_HEDGE : TRADE_PURPOSE_MANUAL_HEDGE;
    
    // Prepare and write position data
    WritePositionToFile(ticket, purpose);
}

//+------------------------------------------------------------------+
//| Enhanced WritePositionToFile                                     |
//+------------------------------------------------------------------+

void WritePositionToFile(ulong ticket, TradePurpose purpose)
{
    // Safety checks
    if(!PositionSelectByTicket(ticket)) 
    {
        LogSymbolToFile(StringFormat("%s Position %I64u not found for logging", _Symbol, ticket));
        return;
    }
    
    // Get the position's actual symbol
    string positionSymbol = PositionGetString(POSITION_SYMBOL);
    
     int requiredSize = 139; // Matches your headerParams size (0-138)
    // Initialize array
      
    // Initialize all values
    for(int i = 0; i < requiredSize; i++)
        valueParams[i] = "0";
    
    // Populate core position data - matching your exact CSV structure
    valueParams[0] = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES); // TimeServer
    valueParams[1] = _Symbol;                                            // Symbol
    valueParams[2] = IntegerToString(ticket);                            // Ticket
    valueParams[7] = IntegerToString(PositionGetInteger(POSITION_MAGIC)); // MagicNo
    valueParams[8] = DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits); // askPrice
    valueParams[9] = DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT), _Digits); // CurrentPrice
    valueParams[10] = DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), _Digits); // OpenPrice
    valueParams[11] = "0"; // ClosePrice (will be filled for closed positions)
    valueParams[12] = DoubleToString(PositionGetDouble(POSITION_VOLUME), 2); // LotSize
    valueParams[13] = DoubleToString(PositionGetDouble(POSITION_PROFIT), 2); // P&L
    valueParams[138] = IntegerToString(purpose); // TradePurpose (last field)
    
    // Note: Fields 3-6 and 14-137 are initialized to "0" but not populated here
    // as they appear to be strategy-specific indicators that would be set elsewhere
    
    // Write to file
    if(!WriteFile_EntryData(valueParams, ticket))
    {
        LogSymbolToFile(StringFormat("%s Failed to write position %I64u to file", _Symbol, ticket));
    }
}

//+------------------------------------------------------------------+
//| Optimized WriteFile_EntryData                                    |
//+------------------------------------------------------------------+
bool WriteFile_EntryData(string &data[], ulong ticket)
{
    // Static variables for error tracking
    static int lastError = 0;
    static datetime lastRetry = 0;
    
    // Attempt to open file
    csvTradeLog_handle = FileOpen(csvTradeLog_fileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, '\t');
    
    if(csvTradeLog_handle == INVALID_HANDLE)
    {
        int error = GetLastError();
        // Only log if error changed or it's been over 60 seconds
        if(error != lastError || TimeCurrent() - lastRetry > 60)
        {
            string errorMsg;
            switch(error)
            {
                case 5001: errorMsg = "File already in use"; break;
                case 5002: errorMsg = "File not found"; break;
                case 5003: errorMsg = "No file access rights"; break;
                case 5004: errorMsg = "Disk full"; break;
                default: errorMsg = "Unknown error " + IntegerToString(error);
            }
            LogSymbolToFile(StringFormat("File error %d: %s", error, errorMsg));
            lastError = error;
            lastRetry = TimeCurrent();
        }
        return false;
    }
    
    // Write headers if needed
    if(!headersWritten)
    {
        string header = "";
        for(int i = 0; i < ArraySize(headerParams); i++)
        {
            header += headerParams[i];
            if(i < ArraySize(headerParams) - 1) header += "\t";
        }
        FileWrite(csvTradeLog_handle, header);
        
        // Write P&L summation row
        string sumRow = "";
        for(int i = 0; i < ArraySize(headerParams); i++)
        {
            sumRow += (i == 12) ? "=SUM(M3:M1048576)" : "";
            if(i < ArraySize(headerParams) - 1) sumRow += "\t";
        }
        FileWrite(csvTradeLog_handle, sumRow);
        
        headersWritten = true;
    }

    // Write data row
    FileSeek(csvTradeLog_handle, 0, SEEK_END);
    string row = "";
    for(int i = 0; i < ArraySize(data); i++)
    {
        row += (data[i] == "") ? "0" : data[i];
        if(i < ArraySize(data) - 1) row += "\t";
    }
    
    bool success = (FileWrite(csvTradeLog_handle, row) > 0);
    FileClose(csvTradeLog_handle);
    
    if(!success)
    {
        LogSymbolToFile(StringFormat("%s Failed to write data for ticket %I64u", _Symbol, ticket));
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Position tracking helpers                                        |
//+------------------------------------------------------------------+


bool ShouldLogClosedPosition(ulong ticket)
{
    // Check if we've already logged this closure
    for(int i = 0; i < PositionsCount; i++)
    {
        if(PositionsArray[i].ticket == ticket && PositionsArray[i].isClosed)
            return false;
    }
    return true;
}

void MarkPositionAsLogged(ulong ticket)
{
    for(int i = 0; i < PositionsCount; i++)
    {
        if(PositionsArray[i].ticket == ticket)
        {
            PositionsArray[i].lastLogTime = TimeCurrent();
            break;
        }
    }
}

void MarkClosedPositionAsLogged(ulong ticket)
{
    for(int i = 0; i < PositionsCount; i++)
    {
        if(PositionsArray[i].ticket == ticket)
        {
            PositionsArray[i].isClosed = true;
            break;
        }
    }
}

#endif 
