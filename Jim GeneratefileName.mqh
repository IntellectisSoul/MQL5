
#include "Jim LogSymbolInfo.mqh"
//+-------------------------------------------------------------------+
//|                                          Jim GeneratefileName.mq5 |
//|                   This is an include file for Jim DataLogTimer.mq5|
//|                                                     Copyright 2024|
//+-------------------------------------------------------------------+

//#ifndef __fileNameGENERATOR_MQH__  // If not defined
//#define __fileNameGENERATOR_MQH__  // Define it
//#include <Tools/stdlib.mqh>
//#include <Tools/DateTime.mqh>

//this generates a filename for Main 'Jim DataLogTimer.mq5' by dynamically adds the date.
   /* DOCUMENTATION : 
   12.Dec.2024 : allows 1 argument to change filename prefix according to its purpose. If no argument is passed, it defaults to empty.
   */
string GeneratefileName(string descript = "", string symbol = "")
{
    // Debug: Log current time to verify date using LogSymbolToFile
    LogSymbolToFile("Current Time in GeneratefileName: " + TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));

    // Use local time for filename date
    datetime now = TimeLocal(); // Switch to local time (Singapore, UTC+8)

    // Create a structure to store date-time components
    MqlDateTime timeStruct;
    TimeToStruct(now, timeStruct);

    // Extract parts of the date
    int day = timeStruct.day;          // Day of the month
    int month = timeStruct.mon;        // Month number (1-12)
    int year = timeStruct.year;        // Year (e.g., 2024)
    int weekday = timeStruct.day_of_week; // 0 = Sun, 1 = Mon, ..., 6 = Sat

    // Convert month number to abbreviation
    string monthName[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
    string monthAbbr = monthName[month - 1];

    // Determine the week number within the month (1-4)
    int weekNumber = (day - 1) / 7 + 1;

    // Convert weekday number to abbreviation (Mon to Fri)
    string weekdayName[] = {"Sun", "Mon", "Tues", "Wed", "Thurs", "Fri", "Sat"};
    string weekdayAbbr = weekdayName[weekday];

    // Construct the date string in dd_MM_yyyy format
    string dateStr = StringFormat("%02d-%02d-%d", day, month, year);

    // Use provided symbol, fallback to _Symbol if empty
    string usedSymbol = (StringLen(symbol) > 0) ? symbol : _Symbol;

    // Construct the final fileName
    string local_fileName = StringFormat("%s_%s_%s_%s_Week%d_%s.csv", 
                                descript, usedSymbol, dateStr, monthAbbr, weekNumber, weekdayAbbr);
    return local_fileName;
}
/*
// Example usage:
void OnStart()
{
   Print(Generatelocal_fileName());
}
*/