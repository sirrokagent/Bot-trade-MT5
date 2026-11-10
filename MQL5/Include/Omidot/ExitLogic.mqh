#ifndef OMIDOT_EXITLOGIC_MQH
#define OMIDOT_EXITLOGIC_MQH

#include "Types.mqh"

bool ShouldEarlyExit(ENUM_TRADE_DIRECTION positionDir,
                      double macdMainPrev, double macdSignalPrev,
                      double macdMainCurr, double macdSignalCurr,
                      double rsiPrev, double rsiCurr,
                      double rsiExtremeLevel)
  {
   if(positionDir == DIR_NONE)
      return false;

   if(positionDir == DIR_BUY)
     {
      bool macdCrossedDown  = (macdMainPrev >= macdSignalPrev && macdMainCurr < macdSignalCurr);
      bool rsiReversingDown = (rsiPrev >= rsiExtremeLevel && rsiCurr < rsiExtremeLevel);
      return macdCrossedDown && rsiReversingDown;
     }

   double rsiLowExtreme = 100.0 - rsiExtremeLevel;
   bool   macdCrossedUp  = (macdMainPrev <= macdSignalPrev && macdMainCurr > macdSignalCurr);
   bool   rsiReversingUp = (rsiPrev <= rsiLowExtreme && rsiCurr > rsiLowExtreme);
   return macdCrossedUp && rsiReversingUp;
  }

bool ShouldPartialClose(double profitPoints,
                         double atrPoints,
                         double partialAtrMultiplier,
                         bool alreadyPartiallyClosed)
  {
   if(alreadyPartiallyClosed)
      return false;
   if(atrPoints <= 0.0)
      return false;
   return profitPoints >= atrPoints * partialAtrMultiplier;
  }

double ComputeBreakevenSL(ENUM_TRADE_DIRECTION positionDir,
                           double entryPrice,
                           double spreadPoints,
                           double point)
  {
   double spreadPrice = spreadPoints * point;
   if(positionDir == DIR_BUY)
      return entryPrice + spreadPrice;
   if(positionDir == DIR_SELL)
      return entryPrice - spreadPrice;
   return 0.0;
  }

double ComputeTrailingSL(ENUM_TRADE_DIRECTION positionDir,
                          double currentPrice,
                          double atrPrice,
                          double trailMultiplier,
                          double currentSL)
  {
   double distance = atrPrice * trailMultiplier;

   if(positionDir == DIR_BUY)
     {
      double candidate = currentPrice - distance;
      if(candidate > currentSL)
         return candidate;
      return currentSL;
     }

   if(positionDir == DIR_SELL)
     {
      double candidate = currentPrice + distance;
      if(currentSL <= 0.0 || candidate < currentSL)
         return candidate;
      return currentSL;
     }

   return currentSL;
  }

#endif
