//+------------------------------------------------------------------+
//|                                            OmidotEquityCurve.mq5 |
//+------------------------------------------------------------------+
#property copyright "Omidot"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "Equity"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLime
#property indicator_width1  2

#property indicator_label2  "Balance"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrYellow
#property indicator_width2  1

double g_equityBuffer[];
double g_balanceBuffer[];

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, g_equityBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, g_balanceBuffer, INDICATOR_DATA);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME, "Omidot Equity Curve");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total <= 0)
      return(0);

   if(prev_calculated == 0)
     {
      for(int i = 0; i < rates_total; i++)
        {
         g_equityBuffer[i]  = EMPTY_VALUE;
         g_balanceBuffer[i] = EMPTY_VALUE;
        }
     }

   int lastIndex = rates_total - 1;
   g_equityBuffer[lastIndex]  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_balanceBuffer[lastIndex] = AccountInfoDouble(ACCOUNT_BALANCE);

   return(rates_total);
  }
//+------------------------------------------------------------------+
