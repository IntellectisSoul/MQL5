//+------------------------------------------------------------------+
//|                                            Jim SharedStructs.mqh |
//+------------------------------------------------------------------+
//global variables shared by all Include files and Main EA
// Include/SharedTypes.mqh
#ifndef SHAREDTYPES_MQH
#define SHAREDTYPES_MQH



// CustomConstants.mqh
#define TRADE_TRANSACTION_DEAL_ADD            1
#define TRADE_TRANSACTION_ORDER_ADD           2
#define TRADE_TRANSACTION_HISTORY_ADD         3
#define TRADE_TRANSACTION_ORDER_REJECT        4
#define TRADE_TRANSACTION_ORDER_CANCEL        5
#define TRADE_TRANSACTION_ORDER_EXPIRED       6
#define TRADE_TRANSACTION_REQUEST             7

#define TRADE_RETCODE_REQUOTE               10004
#define TRADE_RETCODE_REJECT                10006
#define TRADE_RETCODE_CANCEL                10007
#define TRADE_RETCODE_PLACED                10008
#define TRADE_RETCODE_DONE                  10009
#define TRADE_RETCODE_DONE_PARTIAL          10010
#define TRADE_RETCODE_ERROR                 10011
#define TRADE_RETCODE_TIMEOUT               10012
#define TRADE_RETCODE_INVALID               10013
#define TRADE_RETCODE_INVALID_VOLUME        10014
#define TRADE_RETCODE_INVALID_PRICE         10015
#define TRADE_RETCODE_PROCESSING            10016

//WriteLog to csv

int csvTradeLog_handle = INVALID_HANDLE;
string csvTradeLog_fileName = "";
ulong lastChangedTicket = 0;        // Tracks most recently changed ticket
bool isPositionUpdated = false;     // Flag for position changes
bool headersWritten = false;

// Position Tracking
 int count_sells=0;
 int count_buys=0;   //quite reliable in counting number of open Positions


string tradeSource ="";
//+------------------------------------------------------------------+
//| Defense Hedging                                                  |
//+------------------------------------------------------------------+
// --- State Flags for Hedging ---
bool isBuyHedgePending = false;  // Flag for BUY hedge attempts
bool isSellHedgePending = false; // Flag for SELL hedge attempts
ulong pendingBuyHedgeOrderTicket = 0; // Store ticket of pending BUY hedge order
ulong pendingSellHedgeOrderTicket = 0; // Store ticket of pending SELL hedge order


// Store the ticket of the position we are trying to hedge
ulong positionToHedgeTicket_Buy = 0;
ulong positionToHedgeTicket_Sell = 0;

// Defense System
bool lastHasPositions = false; // Tracks whether there were positions in the last tick
int lastProcessedPositionIndex = -1;
bool actionTakenThisTick = false;
datetime lastHedgeTime = 0;

// Cooldowns
bool skipTrade = false; // Cooldown for ANY new trade (entry/hedge) after a closure
bool skipDefense = false;

bool isTREND_Up = false;
bool isTREND_Down = false;

double stopLossPips = 50;
double takeProfitPips = 100;


//OnTradeTransaction()
string headerParams[];
string valueParams[];
ulong processedDeals[]; // Array to track processed deal tickets

//+------------------------------------------------------------------+
//| HedgeHistory structure                                           |
//+------------------------------------------------------------------+
struct HedgeHistory {
    ulong hedgeTicket;    // Ticket of the paired position
    datetime hedgeTime;   // Time of the hedging/unhedging event
    double closePrice;    // Closing price of the unhedged position
    double profitAtHedge; // Profit/loss at the time of unhedging
    int hedgeAction;      // 0 for hedge open, 1 for hedge close
};

int alertswitchPrevious = 0;
int Trigger_EntryDirection = 0;
int alertswitch =0;
string alertcomment = "";

//+------------------------------------------------------------------+
//| PositionDetails structure                                        |
//+------------------------------------------------------------------+
struct PositionDetails 
{
   // Core position information
   ulong     ticket;
   string    symbol;
   double    lotSize;
   long      positionType;       // POSITION_TYPE_BUY or POSITION_TYPE_SELL
   double    openPrice;
   datetime  openTime;
 
   // Close information
   double    closePrice;
   double    pnl;                // Profit & Loss
   double    swap;
   double    commission;
   datetime  closeTime;
   string    purpose;           // TRADE_PURPOSE_NEW_ENTRY/HEDGE/UNHEDGE
   
   // Hedging information
   bool      isHedged;
   ulong     hedgeTicket;
   double    hedgeLotSize;
   HedgeHistory hedgeHistory[];
   
   // Profit protection tracking
   double    highestProfit;
   double    protectedProfit;
   
   // Status flags
   bool      pendingClosure;
   bool      isClosed;
   datetime  lastLogTime;
   long      magicNumber;
   bool      needsLogging;

   string    alertcomment;
   int       alertswitch;
   int       alertswitchPrevious;
   int       Trigger_EntryDirection;

   // Constructor
   PositionDetails() {
      ticket = 0;
      symbol = "";
      lotSize = 0.0;
      positionType = -1;
      openPrice = 0.0;
      openTime = 0;
      closePrice = 0.0;
      pnl = 0.0;
      swap = 0.0;
      commission = 0.0;
      closeTime = 0;
      purpose = "";
      isHedged = false;
      hedgeTicket = 0;
      hedgeLotSize = 0.0;
      ArrayResize(hedgeHistory, 0);
      highestProfit = 0.0;
      protectedProfit = 0.0;
      pendingClosure = false;
      isClosed = false;
      lastLogTime = 0;
      magicNumber = 0;
      needsLogging = false;
      alertcomment = "";
      alertswitch = 0;
      alertswitchPrevious = 0;
      Trigger_EntryDirection = 0;
   }
};



//+------------------------------------------------------------------+
//| ClosedPosition structure                                              |
//+------------------------------------------------------------------+
// Structure to hold temporary data for closed positions before removal from PositionsArray[].
// Used to ensure logging captures correct attributes (e.g., alertcomment, alertswitch) for closed positions.

// Structure to hold temporary data for closed positions
struct ClosedPosition
{
   ulong ticket;                     // Position ticket number
   string symbol;                    // Symbol of the position (e.g., AUDNZD)
   datetime closeTime;               // Time the position was closed
   double closePrice;                // Price at which the position was closed
   double lotSize;                   // Lot size of the position
   double pnl;                       // Profit/loss of the position
   double swap;                      // Swap charges for the position
   double commission;                // Commission charged for the position
   string purpose;                   // Trade purpose (e.g., "Manual Closed Position")
   string alertcomment;              // Comment for the trade (e.g., "Manual")
   int alertswitch;                  // Alert switch value (e.g., 999 for buy, -999 for sell)
   int alertswitchPrevious;          // Previous alert switch value
   int Trigger_EntryDirection;       // Trigger entry direction (e.g., 999/-999 for manual)
};
ClosedPosition closedPositionData;        // Holds data for closed positions


//+------------------------------------------------------------------+
//| HedgePair structure                                              |
//+------------------------------------------------------------------+
struct HedgePair {
    ulong ticket1;
    ulong ticket2;
};

//+------------------------------------------------------------------+
//| HedgeMapping structure                                           |
//+------------------------------------------------------------------+
struct HedgeMapping {
    ulong orderTicket;
    ulong originalTicket;
};

//+------------------------------------------------------------------+
//| DefenseResult structure                                          |
//+------------------------------------------------------------------+

// DefenseResult structure for defense logic results
struct DefenseResult
{
   ulong ticket;                     // Position ticket
   double openPrice;                 // Open price of the position
   double currentPrice;              // Current market price
   double lotSize;                   // Lot size of the position
   int alertswitch;                  // Alert switch value
   string alertcomment;              // Alert comment
   int Trigger_EntryDirection;       // Trigger entry direction
   bool flag_DefensiveCutLoss;       // Defensive cut loss flag
   bool DefensePbarFractal;          // Defense fractal condition
   bool DefenseFrama;                // Defense Frama condition
   bool DefenseAccel;                // Defense acceleration condition
   bool DefensePnL;                  // Defense profit/loss condition
   bool DefenseTotalScoreBinary;     // Defense total score binary condition
   bool Defense_TrendAction;         // Defense trend action condition
   ulong deal;                       // Deal ticket
   int PriceIndex;                   // Price index value

};
DefenseResult defenseResult;              // Holds results from defense logic
//+------------------------------------------------------------------+
//| TradeCooldown structure                                          |
//+------------------------------------------------------------------+
struct TradeCooldown {
   string symbol;
   datetime lastTradeTime;
};

//+------------------------------------------------------------------+
//| HedgeCooldown structure                                          |
//+------------------------------------------------------------------+
struct HedgeCooldown {
   string symbol;
   datetime lastHedgeTime;
   bool allowEarlyExit;
   datetime lastUnhedgeTime;
};

//+------------------------------------------------------------------+
//| ClosedTrade structure                                            |
//+------------------------------------------------------------------+
struct ClosedTrade {
   ulong ticket;
   string symbol;
   double lotSize;
   double closePrice;
   double pnl;
   datetime closeTime;
};

//+------------------------------------------------------------------+
//| DefenseAction enum                                               |
//+------------------------------------------------------------------+
enum DefenseAction {
    DEFENSE_ACTION_HEDGE_ONLY,
    DEFENSE_ACTION_REVERSE_POSITIONS,
    DEFENSE_ACTION_CLOSE_ALL
};

//+------------------------------------------------------------------+
//| ProtectProfitResult structure                                    |
//+------------------------------------------------------------------+
struct ProtectProfitResult {
   bool success;
   string exitReason;
   double closePrice;
   double pnL;
};

//+------------------------------------------------------------------+
//| CloseResult structure                                            |
//+------------------------------------------------------------------+
struct CloseResult {
   bool success;
   double closePrice;
   double pnL;
   bool error;
};

//+------------------------------------------------------------------+
//| HedgeResult enum                                                 |
//+------------------------------------------------------------------+
enum HedgeResult {
   HEDGE_SUCCESS,
   HEDGE_FAILED_INSUFFICIENT_MARGIN,
   HEDGE_FAILED_OTHER
};

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
PositionDetails PositionsArray[];
int PositionsCount = 0;
PositionDetails updatedPos;           // Global temporary position object

PositionDetails PositionsArray_Simulated[];  //for simulated trades
int SimulatedPositionsCount = 0;

HedgeMapping hedgeMappings[];
int hedgeMapCount = 0;

ClosedTrade ClosedTrades[];
int ClosedTradesCount = 0;

TradeCooldown tradeCooldowns[];
HedgeCooldown hedgeCooldowns[];


#endif //  __JIM_SHAREDSTRUCTS_19JUNE_DEEPSEEK_MQH__  
