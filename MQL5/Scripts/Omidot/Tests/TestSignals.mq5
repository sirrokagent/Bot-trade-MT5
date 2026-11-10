#include "../../../Include/Omidot/Signals.mqh"

int g_failCount = 0;

void AssertDir(string name, ENUM_TRADE_DIRECTION actual, ENUM_TRADE_DIRECTION expected)
  {
   if(actual != expected)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected %d, got %d", name, expected, actual);
     }
   else
      PrintFormat("PASS: %s", name);
  }

void OnStart()
  {
   g_failCount = 0;

   AssertDir("trend_cross_up_gives_buy",
             GetSignal_Trend(1.1000, 1.1020, 1.1010, 1.1015), DIR_BUY);

   AssertDir("trend_cross_down_gives_sell",
             GetSignal_Trend(1.1010, 1.0990, 1.1000, 1.1000), DIR_SELL);

   AssertDir("trend_no_cross_gives_none",
             GetSignal_Trend(1.1000, 1.1005, 1.0990, 1.0995), DIR_NONE);

   AssertDir("meanreversion_oversold_recovery_at_lower_band_gives_buy",
             GetSignal_MeanReversion(25.0, 35.0, 30.0, 70.0, 1.0950, 1.1040, 1.0960), DIR_BUY);

   AssertDir("meanreversion_overbought_recovery_at_upper_band_gives_sell",
             GetSignal_MeanReversion(75.0, 65.0, 30.0, 70.0, 1.1050, 1.1040, 1.0960), DIR_SELL);

   AssertDir("meanreversion_recovery_without_band_touch_gives_none",
             GetSignal_MeanReversion(25.0, 35.0, 30.0, 70.0, 1.1000, 1.1040, 1.0960), DIR_NONE);

   AssertDir("breakout_above_highest_high_gives_buy",
             GetSignal_Breakout(1.2050, 1.2000, 1.1950), DIR_BUY);

   AssertDir("breakout_below_lowest_low_gives_sell",
             GetSignal_Breakout(1.1900, 1.2000, 1.1950), DIR_SELL);

   AssertDir("breakout_inside_range_gives_none",
             GetSignal_Breakout(1.1980, 1.2000, 1.1950), DIR_NONE);

   if(g_failCount == 0)
      Print("ALL TESTS PASSED");
   else
      PrintFormat("%d TEST(S) FAILED", g_failCount);
  }
