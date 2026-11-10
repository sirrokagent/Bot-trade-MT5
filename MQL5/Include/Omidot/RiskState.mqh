#ifndef OMIDOT_RISKSTATE_MQH
#define OMIDOT_RISKSTATE_MQH

double CalcDailyLossPercent(double dayStartEquity, double currentEquity)
  {
   if(dayStartEquity <= 0.0)
      return 0.0;

   double loss = dayStartEquity - currentEquity;
   if(loss <= 0.0)
      return 0.0;

   return (loss / dayStartEquity) * 100.0;
  }

bool IsDailyDrawdownLocked(double dayStartEquity, double currentEquity, double maxDrawdownPercent)
  {
   if(dayStartEquity <= 0.0)
      return false;

   double lossPercent = CalcDailyLossPercent(dayStartEquity, currentEquity);
   return lossPercent >= maxDrawdownPercent;
  }

bool IsNewServerDay(datetime previousStamp, datetime currentStamp)
  {
   if(previousStamp == 0)
      return true;

   MqlDateTime prevStruct, currStruct;
   TimeToStruct(previousStamp, prevStruct);
   TimeToStruct(currentStamp, currStruct);

   return (prevStruct.year != currStruct.year ||
           prevStruct.mon  != currStruct.mon  ||
           prevStruct.day  != currStruct.day);
  }

#endif
