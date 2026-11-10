#include "../../../Include/Omidot/RiskMath.mqh"

int g_failCount = 0;

void AssertNear(string testName, double actual, double expected, double tolerance)
  {
   if(MathAbs(actual - expected) > tolerance)
     {
      g_failCount++;
      PrintFormat("FAIL: %s -> expected %.5f, got %.5f", testName, expected, actual);
     }
   else
      PrintFormat("PASS: %s", testName);
  }

void OnStart()
  {
   g_failCount = 0;

   AssertNear("normal_no_rounding_needed",
               CalculateLotSize(10000.0, 1.0, 200.0, 1.0, 0.00001, 0.00001, 0.01, 0.01, 100.0),
               0.50, 0.0001);

   AssertNear("floors_down_to_lot_step",
               CalculateLotSize(10000.0, 1.0, 333.0, 1.0, 0.00001, 0.00001, 0.01, 0.01, 100.0),
               0.30, 0.0001);

   AssertNear("clamps_to_min_lot",
               CalculateLotSize(100.0, 1.0, 500.0, 1.0, 0.00001, 0.00001, 0.01, 0.01, 100.0),
               0.01, 0.0001);

   AssertNear("clamps_to_max_lot",
               CalculateLotSize(10000000.0, 5.0, 10.0, 1.0, 0.00001, 0.00001, 0.01, 0.01, 100.0),
               100.0, 0.0001);

   if(g_failCount == 0)
      Print("ALL TESTS PASSED");
   else
      PrintFormat("%d TEST(S) FAILED", g_failCount);
  }
