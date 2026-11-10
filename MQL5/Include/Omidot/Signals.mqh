#ifndef OMIDOT_SIGNALS_MQH
#define OMIDOT_SIGNALS_MQH

#include "Types.mqh"

ENUM_TRADE_DIRECTION GetSignal_Trend(double fastMaPrev,
                                      double fastMaCurr,
                                      double slowMaPrev,
                                      double slowMaCurr)
  {
   bool crossedUp   = (fastMaPrev <= slowMaPrev && fastMaCurr > slowMaCurr);
   bool crossedDown = (fastMaPrev >= slowMaPrev && fastMaCurr < slowMaCurr);

   if(crossedUp)
      return DIR_BUY;
   if(crossedDown)
      return DIR_SELL;
   return DIR_NONE;
  }

ENUM_TRADE_DIRECTION GetSignal_MeanReversion(double rsiPrev,
                                              double rsiCurr,
                                              double rsiOversold,
                                              double rsiOverbought,
                                              double close,
                                              double bbUpper,
                                              double bbLower)
  {
   bool rsiRecoveringUp   = (rsiPrev <= rsiOversold && rsiCurr > rsiOversold);
   bool touchedLowerBand  = (close <= bbLower);
   if(rsiRecoveringUp && touchedLowerBand)
      return DIR_BUY;

   bool rsiRecoveringDown = (rsiPrev >= rsiOverbought && rsiCurr < rsiOverbought);
   bool touchedUpperBand  = (close >= bbUpper);
   if(rsiRecoveringDown && touchedUpperBand)
      return DIR_SELL;

   return DIR_NONE;
  }

ENUM_TRADE_DIRECTION GetSignal_Breakout(double close,
                                         double highestHighExcludingCurrent,
                                         double lowestLowExcludingCurrent)
  {
   if(close > highestHighExcludingCurrent)
      return DIR_BUY;
   if(close < lowestLowExcludingCurrent)
      return DIR_SELL;
   return DIR_NONE;
  }

#endif
