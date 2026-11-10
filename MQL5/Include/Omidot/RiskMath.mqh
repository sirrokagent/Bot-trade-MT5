#ifndef OMIDOT_RISKMATH_MQH
#define OMIDOT_RISKMATH_MQH

double CalculateLotSize(double balance,
                         double riskPercent,
                         double slDistancePoints,
                         double tickValue,
                         double tickSize,
                         double point,
                         double lotStep,
                         double minLot,
                         double maxLot)
  {
   if(slDistancePoints <= 0.0 || tickValue <= 0.0 || tickSize <= 0.0 || lotStep <= 0.0)
      return 0.0;

   double riskAmount    = balance * (riskPercent / 100.0);
   double valuePerPoint = tickValue * (point / tickSize);
   double rawLot         = riskAmount / (slDistancePoints * valuePerPoint);

   double steppedLot = MathFloor(rawLot / lotStep + 0.00000001) * lotStep;

   if(steppedLot < minLot)
      steppedLot = minLot;
   if(steppedLot > maxLot)
      steppedLot = maxLot;

   return steppedLot;
  }

#endif
