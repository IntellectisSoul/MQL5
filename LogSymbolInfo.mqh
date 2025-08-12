 switch(Trigger_EntryDirection)

     {
      case 1: //Naked BUY
         if(skipTrade)
            break;
         if(false) //temporarily switch this off and never execute
            //if(count_buys >3 || (alertswitch == alertswitchPrevious))
           {
            break;  //controls max. volumne
           }
         //LONG : enter new position
         else
            if((alertswitch != alertswitchPrevious)
               && !isReverse_FramaDown && !isReverse_FractStochDown && Stoch5Xover!="stoch_XDown" && !isReverse_FramaDown)
              {
              MagicNumber = 7; //simulated trades
               Alert(_Symbol, ": ", alertcomment,  " Trigger_EntryD=", Trigger_EntryDirection, " : ", pOpenPrice, " : ", alertswitch);
               Print(alertcomment,  " Trigger_EntryD=", Trigger_EntryDirection, " : ", pOpenPrice, " : ", alertswitch);

               //for LONG



               /*
                   // =========== Open a TRADE ============
                     double lotSize = Position_LotSize; // Use the lot size from GetPositionDetails, or define a fixed value
                     if(lotSize <= 0) {
                        lotSize = GetMinimumLotSize(_Symbol); // Fallback to minimum lot size if Position_LotSize is invalid
                     }

                     // Open the buy position
                    ulong newBuyTicket = BuyMarketTrade(_Symbol, lotSize, alertswitch, 0, MagicNumber); // pairedTicket = 0 since this is a naked position
                     if(newBuyTicket > 0) {
                        // Add the new buy position to trackedPositions as unhedged
                        int newSize = ArraySize(trackedPositions) + 1;
                        ArrayResize(trackedPositions, newSize);
                               int newSize = PositionsCount + 1;
                              ArrayResize(PositionsArray, newSize);
                              int newIndex = newSize - 1;
                              PositionsArray[newIndex].ticket = newBuyTicket;
                              PositionsArray[newIndex].symbol = _Symbol;
                              PositionsArray[newIndex].lotSize = lotSize;
                              PositionsArray[newIndex].positionType = POSITION_TYPE_BUY;
                              PositionsArray[newIndex].openPrice = pOpenPrice;
                              PositionsArray[newIndex].isHedged = false;
                              PositionsArray[newIndex].hedgeTicket = 0;
                              PositionsArray[newIndex].highestProfit = 0.0;
                              PositionsArray[newIndex].protectedProfit = 0.0;
                              PositionsArray[newIndex].initialProfitThreshold = 25.0;
                              PositionsArray[newIndex].pendingClosure = false;
                              PositionsCount = newSize;
               */
               // Visual and logging actions
               BuyArrowChartCreate(alertswitch, ClosePrice); // Draw only on success
               
               if(alertswitchPrevious < 0)
                 {
                  
                   // } //remove this temporary comment when going live.
                  alertswitchPrevious = alertswitch;
                  // Set cooldown to prevent rapid re-triggering of Defense
                  cooldownSize = ArraySize(tradeCooldowns) + 1;
                  ArrayResize(tradeCooldowns, cooldownSize);
                  tradeCooldowns[cooldownSize - 1].symbol = _Symbol;
                  tradeCooldowns[cooldownSize - 1].lastTradeTime = TimeCurrent();
                 }
               else
                 {
                  Print(_Symbol, " Case 1: Buy order failed for Trigger_EntryD=", Trigger_EntryDirection, "  alertswitch=", alertswitch);
                 }
              }
         break;



      //XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      case 2: //Naked SELL
         //Alert(_Symbol + "   Trigger_EntryDirection=" + (string)Trigger_EntryDirection);
         if(skipTrade)
            break;
         //Control maximum entry volume
         if(false) //temporarily switch this off and never execute
            // if(count_sells >3 || (alertswitch == alertswitchPrevious))
           {
            break;
           }

         //SHORT :enter new position
         else
            if((alertswitch != alertswitchPrevious) && !isReverse_FramaUp
               && !isReverse_FractStochUp && Stoch5Xover !="stoch_XUp" && !isReverse_FramaUp)
              {
               MagicNumber = 7; //simulated trades
               Alert(_Symbol, ": ", alertcomment,  " Trigger_EntryD=", Trigger_EntryDirection, " : ", PriceIndex," : ", pOpenPrice, " : ", alertswitch);
               Print(alertcomment,  " Trigger_EntryD=", Trigger_EntryDirection, " : ", PriceIndex," : ", pOpenPrice, " : ", alertswitch);


              
               
               // Visual and logging actions
               SellArrowChartCreate(alertswitch, ClosePrice);
               
               if(alertswitchPrevious > 0)
                 {
                  
                  //  }
                  alertswitchPrevious = alertswitch;

                  // Set cooldown to prevent rapid re-triggering of Defense
                  int cooldownSize = ArraySize(tradeCooldowns) + 1;
                  ArrayResize(tradeCooldowns, cooldownSize);
                  tradeCooldowns[cooldownSize - 1].symbol = _Symbol;
                  tradeCooldowns[cooldownSize - 1].lastTradeTime = TimeCurrent();
                 }
               else
                 {
                  Print(_Symbol, " Case 2: Sell order failed for Trigger_EntryD=", Trigger_EntryDirection, "  alertswitch=", alertswitch);
                 }
              }
         break;
      /*ShortWritePnL(OpenPrice, alertcomment, alertswitch, shortPion,count_buys,
      alertswitchPrevious, Proclivity );*/

/*
      case 3: //Defense CutLoss

         alertswitchPrevious = alertswitch;
         if(PositionType != -1)
           {
            //LogSymbolToFile(_Symbol, "  alertcomment. Calling CloseAllExistingPositions. PositionType=", PositionType);
            LogSymbolToFile(StringFormat(_Symbol, "  %s  alertcomment. Calling CloseAllExistingPositions. PositionType=%d", PositionType));


            CloseAllExistingPositions(_Symbol);  //not no position.
            //CleanClosedPositions(_Symbol);  // Remove closed positions and unhedge paired positions
           }

         Alert(_Symbol + "   Defense :" +  "   alertcomment=" + alertcomment + "  alertsw=" + IntegerToString(alertswitch) + " Trig_EntryD=" + (string)Trigger_EntryDirection + " x-x-x");
         Print(_Symbol + "   Defense :" +  "   alertcomment=" + alertcomment + "  alertsw=" + IntegerToString(alertswitch) + " Trig_EntryD=" + (string)Trigger_EntryDirection + " x-x-x");


         if(alertswitch >0)
           {
            ClosePrice =gCurrentPrice;  //if BUY
           }
         else
           {
            ClosePrice =gaskPrice;
           }

      


         DefenseTPArrowChartCreate(alertswitch, ClosePrice);

         //Writes 2 rows : the trade and also the PnL calculation below
         WriteFile_EntryData(valueParams, gfhandle,  ClosePrice, alertswitch);
         Write_PnL_Data(ClosePrice, alertcomment, alertswitch, 
                        PriceIndex, Trigger_EntryDirection, Position_LotSize, OpenPrice);


         break;
*/
    case 4://TP for alertswitch 87 and -88
{
    alertswitchPrevious = alertswitch;
    string logMessage = StringFormat("%s: TP triggered alertswitch=%d, PositionType=%d", 
                                    _Symbol, alertswitch, PositionType);
    LogSymbolToFile(logMessage);
    Alert(logMessage);

    if(PositionType != -1)
    {
        int orderType = (alertswitch == 87) ? POSITION_TYPE_BUY :
                       (alertswitch == -88) ? POSITION_TYPE_SELL : -1;

        if(orderType != -1)
        {
            int closedCount = 0;
            for(int i = PositionsCount-1; i >= 0; i--) // Reverse iteration for safe removal
            {
                if(PositionsArray[i].positionType == orderType && 
                   PositionsArray[i].symbol == _Symbol)
                {
                    logMessage = StringFormat("%s Closing ticket %I64u (Type=%d Lot=%.2f)",
                                             _Symbol, PositionsArray[i].ticket, 
                                             PositionsArray[i].positionType,
                                             PositionsArray[i].lotSize);
                    LogSymbolToFile(logMessage);
                    
                    CloseResult result = CloseSpecificPosition(PositionsArray[i].ticket);
                    if(result.success)
                    {
                        closedCount++;
                        logMessage = StringFormat("%s Closed successfully, P&L=%.2f",
                                                _Symbol, result.pnL);
                    }
                    else
                    {
                        logMessage = StringFormat("%s Failed to close", _Symbol);
                    }
                    LogSymbolToFile(logMessage);
                }
            }
            logMessage = StringFormat("%s Total %s positions closed: %d",
                                     _Symbol, 
                                     (orderType == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
                                     closedCount);
            LogSymbolToFile(logMessage);
        }
    }
    
    DefenseTPArrowChartCreate(alertswitch, ClosePrice);
    break;