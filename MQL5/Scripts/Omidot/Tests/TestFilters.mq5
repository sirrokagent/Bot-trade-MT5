#include "../../../Include/Omidot/Filters.mqh"

int g_failCount = 0;

void AssertTrue(string name, bool actual)
  {
   if(!actual)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected true, got false", name);
     }
   else
      PrintFormat("PASS: %s", name);
  }

void AssertFalse(string name, bool actual)
  {
   if(actual)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected false, got true", name);
     }
   else
      PrintFormat("PASS: %s", name);
  }

FilterToggles AllOn()
  {
   FilterToggles t;
   t.useEMA200 = true;
   t.useADX = true;
   t.useATR = true;
   t.useH4Confirmation = true;
   t.useRSIExtreme = true;
   t.useMACD = true;
   return t;
  }

FilterInputs BaseBuyPassing()
  {
   FilterInputs f;
   f.price = 1.2000;
   f.ema200 = 1.1950;
   f.adxValue = 25.0;
   f.adxThreshold = 20.0;
   f.atrValue = 0.0015;
   f.atrAverage = 0.0010;
   f.atrMinMultiplier = 0.5;
   f.h4TrendDirection = DIR_BUY;
   f.rsiValue = 55.0;
   f.rsiExtremeLevel = 70.0;
   f.macdMain = 0.0020;
   f.macdSignal = 0.0010;
   return f;
  }

void OnStart()
  {
   g_failCount = 0;
   FilterToggles t = AllOn();

   FilterInputs passing = BaseBuyPassing();
   AssertTrue("buy_passes_all_filters", PassesFilters(DIR_BUY, MODE_TREND, passing, t));

   FilterInputs blockedByEma = BaseBuyPassing();
   blockedByEma.price = 1.1900;
   AssertFalse("buy_blocked_by_ema200", PassesFilters(DIR_BUY, MODE_TREND, blockedByEma, t));

   FilterInputs blockedByAdx = BaseBuyPassing();
   blockedByAdx.adxValue = 10.0;
   AssertFalse("buy_blocked_by_adx", PassesFilters(DIR_BUY, MODE_TREND, blockedByAdx, t));

   FilterInputs blockedByRsi = BaseBuyPassing();
   blockedByRsi.rsiValue = 75.0;
   AssertFalse("buy_blocked_by_rsi_extreme", PassesFilters(DIR_BUY, MODE_TREND, blockedByRsi, t));

   FilterInputs blockedByMacd = BaseBuyPassing();
   blockedByMacd.macdMain = 0.0005;
   AssertFalse("buy_blocked_by_macd", PassesFilters(DIR_BUY, MODE_TREND, blockedByMacd, t));

   FilterInputs meanReversionLowAdx = BaseBuyPassing();
   meanReversionLowAdx.adxValue = 5.0;
   AssertTrue("mean_reversion_skips_adx_filter", PassesFilters(DIR_BUY, MODE_MEAN_REVERSION, meanReversionLowAdx, t));

   if(g_failCount == 0)
      Print("ALL TESTS PASSED");
   else
      PrintFormat("%d TEST(S) FAILED", g_failCount);
  }
