#ifndef OMIDOT_FILTERS_MQH
#define OMIDOT_FILTERS_MQH

#include "Types.mqh"

struct FilterToggles
  {
   bool useEMA200;
   bool useADX;
   bool useATR;
   bool useH4Confirmation;
   bool useRSIExtreme;
   bool useMACD;
  };

struct FilterInputs
  {
   double               price;
   double               ema200;
   double               adxValue;
   double               adxThreshold;
   double               atrValue;
   double               atrAverage;
   double               atrMinMultiplier;
   ENUM_TRADE_DIRECTION h4TrendDirection;
   double               rsiValue;
   double               rsiExtremeLevel;
   double               macdMain;
   double               macdSignal;
  };

bool PassesFilters(ENUM_TRADE_DIRECTION signalDir,
                    ENUM_TRADING_MODE mode,
                    const FilterInputs &f,
                    const FilterToggles &t)
  {
   if(signalDir == DIR_NONE)
      return false;

   if(t.useEMA200)
     {
      if(signalDir == DIR_BUY && f.price <= f.ema200)
         return false;
      if(signalDir == DIR_SELL && f.price >= f.ema200)
         return false;
     }

   if(t.useATR)
     {
      if(f.atrAverage > 0.0 && f.atrValue < f.atrAverage * f.atrMinMultiplier)
         return false;
     }

   if(t.useH4Confirmation)
     {
      if(f.h4TrendDirection != DIR_NONE && f.h4TrendDirection != signalDir)
         return false;
     }

   if(mode != MODE_MEAN_REVERSION)
     {
      if(t.useADX && f.adxValue < f.adxThreshold)
         return false;

      if(t.useRSIExtreme)
        {
         if(signalDir == DIR_BUY && f.rsiValue >= f.rsiExtremeLevel)
            return false;
         if(signalDir == DIR_SELL && f.rsiValue <= (100.0 - f.rsiExtremeLevel))
            return false;
        }

      if(t.useMACD)
        {
         if(signalDir == DIR_BUY && f.macdMain <= f.macdSignal)
            return false;
         if(signalDir == DIR_SELL && f.macdMain >= f.macdSignal)
            return false;
        }
     }

   return true;
  }

#endif
