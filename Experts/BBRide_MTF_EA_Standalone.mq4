//+------------------------------------------------------------------+
//|                                              BBRide_MTF_EA.mq4    |
//|  EA MT4 - "D dang du day BB" + H1 hoi MA10/BB giua + M5 2 day tang|
//|                                                                   |
//|  CHIEU BUY:                                                       |
//|   1. MN1 & W1 xu huong TANG, chua cham khang cu                   |
//|   2. D1 du day dai TREN BB                                        |
//|   3. H1 hoi XUONG MA10 / BB giua ma khong gay xu huong            |
//|   4. M5/M1 tich luy, tao 2 DAY TANG DAN                           |
//|   5. Pha LEN neckline -> BUY, SL duoi day 2                       |
//|                                                                   |
//|  CHIEU SELL (doi xung):                                           |
//|   1. MN1 & W1 xu huong GIAM, chua cham ho tro                     |
//|   2. D1 du day dai DUOI BB                                        |
//|   3. H1 hoi LEN MA10 / BB giua ma khong gay xu huong              |
//|   4. M5/M1 tich luy, tao 2 DINH GIAM DAN                          |
//|   5. Pha XUONG neckline -> SELL, SL tren dinh 2                   |
//|                                                                   |
//|  KY LUAT VON (bat buoc, khong the tat bang tay khi dang chay):    |
//|   - Lot = (Balance x Risk%) / (SL pips x gia tri 1 pip cua 1 lot) |
//|   - Dung trade khi lo qua % gioi han trong ngay                   |
//|   - Dung trade sau N lenh thua lien tiep                          |
//|   - KHONG tang lot de go, KHONG noi rong SL, KHONG binh quan gia  |
//|   - Chi vao lenh khi RR thuc te >= RR toi thieu                   |
//+------------------------------------------------------------------+
#property copyright "BBRide MTF"
#property link      ""
#property version   "1.30"
#property strict

//=== BAN STANDALONE: copy thang vao MQL4/Experts/ va compile.  ===
//=== Khong can tao thu muc Include/BBRide.                    ===

//+------------------------------------------------------------------+
//|  PHAN LOGIC LOI (nhung san - KHONG can file Include)              |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                  BBRideCore.mqh   |
//|  Thu vien logic dung chung cho EA va Indicator - HAI CHIEU        |
//|                                                                   |
//|  CHIEU MUA (BUY):                                                 |
//|   1) MN1 + W1 xu huong TANG, GIA CHUA CHAM KHANG CU               |
//|   2) D1 "du day" dai TREN BB (dong cua bam dai tren nhieu phien)  |
//|   3) H1 hoi XUONG MA10 hoac BB giua ma khong gay xu huong         |
//|   4) M5/M1 tich luy tao 2 DAY TANG DAN                            |
//|   5) Pha LEN neckline (dinh giua 2 day) -> BUY                    |
//|                                                                   |
//|  CHIEU BAN (SELL) - doi xung hoan toan:                           |
//|   1) MN1 + W1 xu huong GIAM, GIA CHUA CHAM HO TRO                 |
//|   2) D1 "du day" dai DUOI BB (dong cua bam dai duoi nhieu phien)  |
//|   3) H1 hoi LEN MA10 hoac BB giua ma khong gay xu huong           |
//|   4) M5/M1 tich luy tao 2 DINH GIAM DAN                           |
//|   5) Pha XUONG neckline (day giua 2 dinh) -> SELL                 |
//+------------------------------------------------------------------+


#define BBRIDE_NO_LEVEL     9999.0   // khong tim thay khang cu / ho tro
#define BBRIDE_BUY          1
#define BBRIDE_SELL        -1

//--- Che do giao dich
#define BBRIDE_MODE_BOTH    0
#define BBRIDE_MODE_BUY     1
#define BBRIDE_MODE_SELL    2

//+------------------------------------------------------------------+
//| Bo tham so cau hinh                                              |
//+------------------------------------------------------------------+
struct BBRideSettings
  {
   //--- Che do
   int               tradeMode;         // 0=ca hai chieu, 1=chi BUY, 2=chi SELL
   //--- Tang 1: xu huong khung lon (MN1 / W1)
   bool              useMonthly;
   int               mnFast;
   int               mnSlow;
   bool              useWeekly;
   int               wFast;
   int               wSlow;
   ENUM_MA_METHOD    maMethod;
   //--- Khang cu / ho tro
   int               resLookback;
   int               resFractalDepth;
   double            minRoomATR;
   //--- Tang 2: D1 du day BB
   int               bbPeriod;
   double            bbDev;
   int               dRideLookback;
   int               dMinRideBars;
   double            dRideThreshold;    // BUY: %B >= nguong | SELL: %B <= 1-nguong
   bool              dRequireExpansion;
   //--- Tang 3: H1 pullback
   int               h1MaPeriod;
   bool              h1UseBBMid;
   double            h1TouchATR;
   int               h1PullbackBars;
   double            h1MinExtensionATR;
   int               h1TrendMa;
   //--- Tang 4-5: khung vao lenh
   int               entryTF;
   int               entryLookback;
   int               swingDepth;
   double            minHigherLowATR;   // BUY: day2 cao hon day1 | SELL: dinh2 thap hon dinh1
   double            maxHigherLowATR;
   bool              requireContraction;
   bool              requireNeckBreak;
   //--- Quan tri rui ro
   double            slBufferATR;
   double            rr;
   bool              tpAtResistance;    // cat TP tai khang cu (BUY) / ho tro (SELL)
  };

//+------------------------------------------------------------------+
//| Ket qua kiem tra tin hieu                                        |
//+------------------------------------------------------------------+
struct BBRideSignal
  {
   bool              valid;
   int               direction;      // BBRIDE_BUY (+1) hoac BBRIDE_SELL (-1)
   double            entry;
   double            sl;
   double            tp;
   double            piv1;           // diem xoay thu nhat (day/dinh cu)
   double            piv2;           // diem xoay thu hai (day cao hon / dinh thap hon)
   double            neckline;
   datetime          signalBar;
   //--- chan doan tung tang
   bool              okMonthly;
   bool              okWeekly;
   bool              okRoom;
   bool              okDailyRide;
   bool              okH1Pullback;
   bool              okDoubleBottom;
   bool              okTrigger;
   double            roomATR;
   double            dailyPB;
   int               dailyRideCount;
   double            h1Zone;
   string            note;
  };

//+------------------------------------------------------------------+
//| Gan tham so mac dinh                                             |
//+------------------------------------------------------------------+
void BBRideDefaults(BBRideSettings &s)
  {
   s.tradeMode         = BBRIDE_MODE_BOTH;
   s.useMonthly        = true;
   s.mnFast            = 5;
   s.mnSlow            = 10;
   s.useWeekly         = true;
   s.wFast             = 10;
   s.wSlow             = 20;
   s.maMethod          = MODE_EMA;
   s.resLookback       = 60;
   s.resFractalDepth   = 2;
   s.minRoomATR        = 1.5;
   s.bbPeriod          = 20;
   s.bbDev             = 2.0;
   s.dRideLookback     = 10;
   s.dMinRideBars      = 4;
   s.dRideThreshold    = 0.80;
   s.dRequireExpansion = true;
   s.h1MaPeriod        = 10;
   s.h1UseBBMid        = true;
   s.h1TouchATR        = 0.35;
   s.h1PullbackBars    = 6;
   s.h1MinExtensionATR = 1.0;
   s.h1TrendMa         = 50;
   s.entryTF           = PERIOD_M5;
   s.entryLookback     = 80;
   s.swingDepth        = 2;
   s.minHigherLowATR   = 0.0;
   s.maxHigherLowATR   = 4.0;
   s.requireContraction= true;
   s.requireNeckBreak  = true;
   s.slBufferATR       = 0.5;
   s.rr                = 2.0;
   s.tpAtResistance    = true;
  }

//+------------------------------------------------------------------+
//| Tien ich                                                         |
//+------------------------------------------------------------------+
bool BBRideHasBars(const string sym,const int tf,const int need)
  {
   return(iBars(sym,tf)>=need);
  }
//+------------------------------------------------------------------+
string BBRideDirName(const int dir)
  {
   return(dir==BBRIDE_BUY?"BUY":"SELL");
  }
//+------------------------------------------------------------------+
//| %B cua Bollinger: (Close - Lower) / (Upper - Lower)              |
//+------------------------------------------------------------------+
double BBRidePercentB(const string sym,const int tf,const int period,const double dev,const int shift)
  {
   double up =iBands(sym,tf,period,dev,0,PRICE_CLOSE,MODE_UPPER,shift);
   double lo =iBands(sym,tf,period,dev,0,PRICE_CLOSE,MODE_LOWER,shift);
   double cl =iClose(sym,tf,shift);
   double w  =up-lo;
   if(w<=0.0) return(0.5);
   return((cl-lo)/w);
  }

//+------------------------------------------------------------------+
//| TANG 1: xu huong khung lon theo chieu dir                        |
//|  BUY : MA nhanh > MA cham, MA nhanh doc len, gia > MA cham       |
//|  SELL: MA nhanh < MA cham, MA nhanh doc xuong, gia < MA cham     |
//+------------------------------------------------------------------+
bool BBRideTrendOK(const string sym,const int tf,const int fast,const int slow,
                   const ENUM_MA_METHOD method,const int dir)
  {
   if(!BBRideHasBars(sym,tf,slow+5)) return(false);

   double maF1=iMA(sym,tf,fast,0,method,PRICE_CLOSE,1);
   double maF3=iMA(sym,tf,fast,0,method,PRICE_CLOSE,3);
   double maS1=iMA(sym,tf,slow,0,method,PRICE_CLOSE,1);
   double maS3=iMA(sym,tf,slow,0,method,PRICE_CLOSE,3);
   double close1=iClose(sym,tf,1);

   if(dir==BBRIDE_BUY)
     {
      if(maF1<=maS1)   return(false);
      if(maF1<=maF3)   return(false);
      if(maS1<maS3)    return(false);
      if(close1<=maS1) return(false);
      return(true);
     }
   //--- SELL
   if(maF1>=maS1)   return(false);
   if(maF1>=maF3)   return(false);
   if(maS1>maS3)    return(false);
   if(close1>=maS1) return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//| Fractal dinh / day                                               |
//+------------------------------------------------------------------+
bool BBRideIsSwingHigh(const string sym,const int tf,const int shift,const int depth)
  {
   double h=iHigh(sym,tf,shift);
   for(int k=1;k<=depth;k++)
     {
      if(iHigh(sym,tf,shift-k)>h) return(false);
      if(iHigh(sym,tf,shift+k)>h) return(false);
     }
   return(true);
  }
//+------------------------------------------------------------------+
bool BBRideIsSwingLow(const string sym,const int tf,const int shift,const int depth)
  {
   double l=iLow(sym,tf,shift);
   for(int k=1;k<=depth;k++)
     {
      if(iLow(sym,tf,shift-k)<l) return(false);
      if(iLow(sym,tf,shift+k)<l) return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| TANG 1b: can gan nhat theo huong di chuyen                       |
//|  BUY : khang cu (dinh fractal gan nhat PHIA TREN gia)            |
//|  SELL: ho tro   (day  fractal gan nhat PHIA DUOI gia)            |
//|  Tra ve 0 neu khong con can nao chan duong                       |
//+------------------------------------------------------------------+
double BBRideNearestLevel(const string sym,const int tf,const int lookback,
                          const int depth,const double price,const int dir)
  {
   if(!BBRideHasBars(sym,tf,lookback+depth+2)) return(0.0);

   double best=0.0;
   for(int i=depth+1;i<=lookback;i++)
     {
      if(dir==BBRIDE_BUY)
        {
         if(!BBRideIsSwingHigh(sym,tf,i,depth)) continue;
         double h=iHigh(sym,tf,i);
         if(h<=price) continue;
         if(best==0.0 || h<best) best=h;         // dinh THAP NHAT nam tren gia
        }
      else
        {
         if(!BBRideIsSwingLow(sym,tf,i,depth)) continue;
         double l=iLow(sym,tf,i);
         if(l>=price) continue;
         if(best==0.0 || l>best) best=l;         // day CAO NHAT nam duoi gia
        }
     }
   return(best);
  }

//+------------------------------------------------------------------+
//| Khoang trong toi can gan nhat, tinh theo ATR khung do            |
//+------------------------------------------------------------------+
double BBRideRoomATR(const string sym,const int tf,const BBRideSettings &s,
                     const int dir,double &levelOut)
  {
   double price=iClose(sym,tf,0);
   double atr  =iATR(sym,tf,14,1);
   levelOut=BBRideNearestLevel(sym,tf,s.resLookback,s.resFractalDepth,price,dir);

   if(atr<=0.0)      return(0.0);
   if(levelOut<=0.0) return(BBRIDE_NO_LEVEL);    // duong di trong hoan toan
   return(dir==BBRIDE_BUY ? (levelOut-price)/atr : (price-levelOut)/atr);
  }

//+------------------------------------------------------------------+
//| TANG 2: D1 dang "du day" theo chieu dir                          |
//|  BUY : %B >= nguong (bam dai TREN)                               |
//|  SELL: %B <= 1 - nguong (bam dai DUOI)                           |
//+------------------------------------------------------------------+
bool BBRideDailyRiding(const string sym,const BBRideSettings &s,const int dir,
                       int &rideCount,double &pbLast)
  {
   rideCount=0;
   pbLast=0.0;
   int need=s.bbPeriod+s.dRideLookback+5;
   if(!BBRideHasBars(sym,PERIOD_D1,need)) return(false);

   double loThreshold=1.0-s.dRideThreshold;

   for(int i=1;i<=s.dRideLookback;i++)
     {
      double pb=BBRidePercentB(sym,PERIOD_D1,s.bbPeriod,s.bbDev,i);
      if(i==1) pbLast=pb;
      if(dir==BBRIDE_BUY) { if(pb>=s.dRideThreshold) rideCount++; }
      else                { if(pb<=loThreshold)      rideCount++; }
     }
   if(rideCount<s.dMinRideBars) return(false);

   //--- BB giua phai doc dung chieu
   double midNow =iBands(sym,PERIOD_D1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_MAIN,1);
   double midPast=iBands(sym,PERIOD_D1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_MAIN,s.dRideLookback);
   double close1 =iClose(sym,PERIOD_D1,1);

   if(dir==BBRIDE_BUY)
     {
      if(midNow<=midPast) return(false);
      if(close1<=midNow)  return(false);
     }
   else
     {
      if(midNow>=midPast) return(false);
      if(close1>=midNow)  return(false);
     }

   //--- BB mo rong (chung cho ca hai chieu)
   if(s.dRequireExpansion)
     {
      double wNow =iBands(sym,PERIOD_D1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_UPPER,1)
                  -iBands(sym,PERIOD_D1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_LOWER,1);
      double wPast=iBands(sym,PERIOD_D1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_UPPER,s.dRideLookback)
                  -iBands(sym,PERIOD_D1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_LOWER,s.dRideLookback);
      if(wNow<wPast) return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| TANG 3: H1 hoi ve MA10 / BB giua ma KHONG gay xu huong           |
//|  BUY : gia hoi XUONG vung, khong dong cua sau DUOI vung          |
//|  SELL: gia hoi LEN  vung, khong dong cua sau TREN vung           |
//+------------------------------------------------------------------+
bool BBRideH1Pullback(const string sym,const BBRideSettings &s,const int dir,double &zoneOut)
  {
   zoneOut=0.0;
   int need=MathMax(s.h1TrendMa,s.bbPeriod)+s.h1PullbackBars+30;
   if(!BBRideHasBars(sym,PERIOD_H1,need)) return(false);

   double atr=iATR(sym,PERIOD_H1,14,1);
   if(atr<=0.0) return(false);

   double ma10 =iMA(sym,PERIOD_H1,s.h1MaPeriod,0,s.maMethod,PRICE_CLOSE,0);
   double bbMid=iBands(sym,PERIOD_H1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_MAIN,0);
   double bbMidPast=iBands(sym,PERIOD_H1,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_MAIN,s.h1PullbackBars+3);
   double trendMa=iMA(sym,PERIOD_H1,s.h1TrendMa,0,s.maMethod,PRICE_CLOSE,0);
   double close1 =iClose(sym,PERIOD_H1,1);

   //--- xu huong H1 phai con dung chieu
   if(dir==BBRIDE_BUY)
     {
      if(bbMid<=bbMidPast) return(false);
      if(close1<trendMa)   return(false);
     }
   else
     {
      if(bbMid>=bbMidPast) return(false);
      if(close1>trendMa)   return(false);
     }

   double tol  =s.h1TouchATR*atr;
   double price=iClose(sym,PERIOD_H1,0);

   //--- chon vung hoi gan gia nhat
   double zone=ma10;
   if(s.h1UseBBMid && MathAbs(price-bbMid)<MathAbs(price-ma10)) zone=bbMid;
   zoneOut=zone;

   if(dir==BBRIDE_BUY)
     {
      //--- 1) truoc do gia phai gian LEN khoi vung
      double maxHigh=0.0;
      for(int i=1;i<=s.h1PullbackBars+12;i++)
        {
         double h=iHigh(sym,PERIOD_H1,i);
         if(h>maxHigh) maxHigh=h;
        }
      if((maxHigh-zone)<s.h1MinExtensionATR*atr) return(false);

      //--- 2) co cu cham vung tu tren xuong
      bool touched=false;
      for(int j=0;j<=s.h1PullbackBars;j++)
         if(iLow(sym,PERIOD_H1,j)<=zone+tol) { touched=true; break; }
      if(!touched) return(false);

      //--- 3) chua gay: khong nen nao dong cua sau DUOI vung
      for(int k=1;k<=s.h1PullbackBars;k++)
         if(iClose(sym,PERIOD_H1,k)<zone-tol) return(false);
      return(true);
     }

   //--- SELL: doi xung
   double minLow=0.0;
   for(int i2=1;i2<=s.h1PullbackBars+12;i2++)
     {
      double l=iLow(sym,PERIOD_H1,i2);
      if(minLow==0.0 || l<minLow) minLow=l;
     }
   if((zone-minLow)<s.h1MinExtensionATR*atr) return(false);

   bool touched2=false;
   for(int j2=0;j2<=s.h1PullbackBars;j2++)
      if(iHigh(sym,PERIOD_H1,j2)>=zone-tol) { touched2=true; break; }
   if(!touched2) return(false);

   for(int k2=1;k2<=s.h1PullbackBars;k2++)
      if(iClose(sym,PERIOD_H1,k2)>zone+tol) return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//| TANG 4+5: M5/M1 - mo hinh 2 diem xoay + pha neckline             |
//|  BUY : 2 DAY TANG DAN, neckline = dinh giua, pha LEN             |
//|  SELL: 2 DINH GIAM DAN, neckline = day giua, pha XUONG           |
//+------------------------------------------------------------------+
bool BBRideSwingPattern(const string sym,const BBRideSettings &s,const int dir,const double h1Zone,
                        double &piv1,double &piv2,double &neckline,
                        datetime &sigBar,string &why)
  {
   piv1=0; piv2=0; neckline=0; sigBar=0; why="";
   int tf=s.entryTF;
   if(!BBRideHasBars(sym,tf,s.entryLookback+s.swingDepth+10))
     { why="Thieu du lieu khung vao lenh"; return(false); }

   double atr=iATR(sym,tf,14,1);
   if(atr<=0.0) { why="ATR khung vao lenh = 0"; return(false); }

   //--- quet 2 diem xoay gan nhat (day cho BUY, dinh cho SELL)
   int idx1=-1,idx2=-1;
   for(int i=s.swingDepth+1;i<=s.entryLookback;i++)
     {
      bool isPivot=(dir==BBRIDE_BUY ? BBRideIsSwingLow(sym,tf,i,s.swingDepth)
                                    : BBRideIsSwingHigh(sym,tf,i,s.swingDepth));
      if(!isPivot) continue;
      if(idx2<0) { idx2=i; continue; }
      if(idx1<0)
        {
         if(i-idx2<s.swingDepth+2) continue;
         idx1=i;
         break;
        }
     }
   if(idx1<0 || idx2<0)
     { why=(dir==BBRIDE_BUY?"Chua du 2 day swing":"Chua du 2 dinh swing"); return(false); }

   piv2=(dir==BBRIDE_BUY ? iLow(sym,tf,idx2) : iHigh(sym,tf,idx2));
   piv1=(dir==BBRIDE_BUY ? iLow(sym,tf,idx1) : iHigh(sym,tf,idx1));

   //--- BUY: day sau CAO HON | SELL: dinh sau THAP HON
   double diff=(dir==BBRIDE_BUY ? piv2-piv1 : piv1-piv2);
   if(diff<=0.0)
     { why=(dir==BBRIDE_BUY?"Day 2 khong cao hon day 1":"Dinh 2 khong thap hon dinh 1"); return(false); }
   if(diff<s.minHigherLowATR*atr) { why="Chenh lech 2 diem xoay khong dang ke"; return(false); }
   if(diff>s.maxHigherLowATR*atr) { why="Hai diem xoay qua xa nhau - khong phai tich luy"; return(false); }

   //--- diem xoay thu 2 phai nam trong vung hoi H1
   double zoneTol=MathMax(s.h1TouchATR*iATR(sym,PERIOD_H1,14,1),3.0*atr);
   if(h1Zone>0.0 && MathAbs(piv2-h1Zone)>zoneTol)
     { why="Diem xoay 2 khong nam tai vung hoi H1"; return(false); }

   //--- neckline: BUY = dinh cao nhat giua 2 day | SELL = day thap nhat giua 2 dinh
   for(int j=idx2;j<=idx1;j++)
     {
      if(dir==BBRIDE_BUY)
        {
         double h=iHigh(sym,tf,j);
         if(h>neckline) neckline=h;
        }
      else
        {
         double l=iLow(sym,tf,j);
         if(neckline==0.0 || l<neckline) neckline=l;
        }
     }

   //--- tich luy: bien do doan giua 2 diem xoay phai co lai
   if(s.requireContraction)
     {
      double rNow=0.0; int cNow=0;
      for(int a=idx2;a<=idx1;a++) { rNow+=(iHigh(sym,tf,a)-iLow(sym,tf,a)); cNow++; }
      double rPre=0.0; int cPre=0;
      for(int b=idx1+1;b<=MathMin(idx1+(idx1-idx2)+1,s.entryLookback);b++)
        { rPre+=(iHigh(sym,tf,b)-iLow(sym,tf,b)); cPre++; }
      if(cNow>0 && cPre>0)
        {
         double avgNow=rNow/cNow, avgPre=rPre/cPre;
         if(avgNow>avgPre*1.20) { why="Bien do chua co lai (chua tich luy)"; return(false); }
        }
     }

   //--- trigger: pha neckline dung chieu, bang nen vua dong
   if(s.requireNeckBreak)
     {
      int    digits=(int)MarketInfo(sym,MODE_DIGITS);
      double cl1=iClose(sym,tf,1);
      double cl2=iClose(sym,tf,2);
      if(dir==BBRIDE_BUY)
        {
         if(cl1<=neckline) { why="Chua pha LEN neckline "+DoubleToString(neckline,digits); return(false); }
         if(cl2>neckline)  { why="Da pha neckline tu truoc - bo qua"; return(false); }
        }
      else
        {
         if(cl1>=neckline) { why="Chua pha XUONG neckline "+DoubleToString(neckline,digits); return(false); }
         if(cl2<neckline)  { why="Da pha neckline tu truoc - bo qua"; return(false); }
        }
     }

   sigBar=iTime(sym,tf,1);
   why="OK";
   return(true);
  }

//+------------------------------------------------------------------+
//| Danh gia mot chieu cu the                                        |
//+------------------------------------------------------------------+
void BBRideEvaluateDir(const string sym,const BBRideSettings &s,const int dir,BBRideSignal &sig)
  {
   sig.valid=false; sig.direction=dir;
   sig.entry=0; sig.sl=0; sig.tp=0;
   sig.piv1=0; sig.piv2=0; sig.neckline=0; sig.signalBar=0;
   sig.okMonthly=false; sig.okWeekly=false; sig.okRoom=false;
   sig.okDailyRide=false; sig.okH1Pullback=false; sig.okDoubleBottom=false; sig.okTrigger=false;
   sig.roomATR=0; sig.dailyPB=0; sig.dailyRideCount=0; sig.h1Zone=0; sig.note="";

   string dirName=BBRideDirName(dir);

   //--- TANG 1: khung lon
   sig.okMonthly = (!s.useMonthly) || BBRideTrendOK(sym,PERIOD_MN1,s.mnFast,s.mnSlow,s.maMethod,dir);
   sig.okWeekly  = (!s.useWeekly)  || BBRideTrendOK(sym,PERIOD_W1, s.wFast, s.wSlow, s.maMethod,dir);
   if(!sig.okMonthly) { sig.note=dirName+": MN1 chua xac nhan xu huong"; return; }
   if(!sig.okWeekly)  { sig.note=dirName+": W1 chua xac nhan xu huong";  return; }

   //--- TANG 1b: con du khong gian toi can gan nhat
   double level=0.0;
   sig.roomATR=BBRideRoomATR(sym,PERIOD_W1,s,dir,level);
   sig.okRoom=(sig.roomATR>=s.minRoomATR);
   if(!sig.okRoom)
     {
      sig.note=dirName+": gia da sat "+(dir==BBRIDE_BUY?"khang cu":"ho tro")+
               " W1 ("+DoubleToString(sig.roomATR,2)+" ATR)";
      return;
     }

   //--- TANG 2: D1 du day BB
   sig.okDailyRide=BBRideDailyRiding(sym,s,dir,sig.dailyRideCount,sig.dailyPB);
   if(!sig.okDailyRide)
     {
      sig.note=dirName+": D1 chua du day BB ("+IntegerToString(sig.dailyRideCount)+"/"+
               IntegerToString(s.dMinRideBars)+" phien)";
      return;
     }

   //--- TANG 3: H1 hoi ve vung trend thuan
   sig.okH1Pullback=BBRideH1Pullback(sym,s,dir,sig.h1Zone);
   if(!sig.okH1Pullback)
     { sig.note=dirName+": H1 chua hoi ve MA"+IntegerToString(s.h1MaPeriod)+"/BB giua"; return; }

   //--- TANG 4+5: mo hinh 2 diem xoay + pha neckline
   string why="";
   sig.okDoubleBottom=BBRideSwingPattern(sym,s,dir,sig.h1Zone,sig.piv1,sig.piv2,sig.neckline,sig.signalBar,why);
   if(!sig.okDoubleBottom) { sig.note=dirName+": "+why; return; }
   sig.okTrigger=true;

   //--- Tinh entry / SL / TP
   int    digits=(int)MarketInfo(sym,MODE_DIGITS);
   double atrEntry=iATR(sym,s.entryTF,14,1);

   if(dir==BBRIDE_BUY)
     {
      sig.entry=MarketInfo(sym,MODE_ASK);
      sig.sl   =NormalizeDouble(sig.piv2-s.slBufferATR*atrEntry,digits);
      double risk=sig.entry-sig.sl;
      if(risk<=0.0) { sig.note="SL khong hop le"; sig.okTrigger=false; return; }

      sig.tp=NormalizeDouble(sig.entry+s.rr*risk,digits);
      if(s.tpAtResistance && level>0.0 && level<sig.tp)
         sig.tp=NormalizeDouble(level-0.2*atrEntry,digits);     // chot truoc khang cu
      if(sig.tp<=sig.entry) { sig.note=dirName+": TP bi khang cu chan - bo qua setup"; return; }
     }
   else
     {
      sig.entry=MarketInfo(sym,MODE_BID);
      sig.sl   =NormalizeDouble(sig.piv2+s.slBufferATR*atrEntry,digits);
      double risk=sig.sl-sig.entry;
      if(risk<=0.0) { sig.note="SL khong hop le"; sig.okTrigger=false; return; }

      sig.tp=NormalizeDouble(sig.entry-s.rr*risk,digits);
      if(s.tpAtResistance && level>0.0 && level>sig.tp)
         sig.tp=NormalizeDouble(level+0.2*atrEntry,digits);     // chot truoc ho tro
      if(sig.tp>=sig.entry) { sig.note=dirName+": TP bi ho tro chan - bo qua setup"; return; }
     }

   sig.valid=true;
   sig.note="DU DIEU KIEN VAO LENH "+dirName;
  }

//+------------------------------------------------------------------+
//| Diem so tien do cua mot tin hieu (dung de chon chieu hien thi)   |
//+------------------------------------------------------------------+
int BBRideScore(const BBRideSignal &sig)
  {
   int n=0;
   if(sig.okMonthly)      n++;
   if(sig.okWeekly)       n++;
   if(sig.okRoom)         n++;
   if(sig.okDailyRide)    n++;
   if(sig.okH1Pullback)   n++;
   if(sig.okDoubleBottom) n++;
   if(sig.valid)          n++;
   return(n);
  }

//+------------------------------------------------------------------+
//| HAM TONG: danh gia theo che do (ca hai chieu / chi mot chieu)    |
//+------------------------------------------------------------------+
void BBRideEvaluate(const string sym,const BBRideSettings &s,BBRideSignal &sig)
  {
   BBRideSignal sigBuy, sigSell;
   bool triedBuy=false, triedSell=false;

   if(s.tradeMode!=BBRIDE_MODE_SELL)
     {
      BBRideEvaluateDir(sym,s,BBRIDE_BUY,sigBuy);
      triedBuy=true;
      if(sigBuy.valid) { sig=sigBuy; return; }
     }
   if(s.tradeMode!=BBRIDE_MODE_BUY)
     {
      BBRideEvaluateDir(sym,s,BBRIDE_SELL,sigSell);
      triedSell=true;
      if(sigSell.valid) { sig=sigSell; return; }
     }

   //--- khong chieu nao du dieu kien: hien thi chieu di duoc xa hon
   if(triedBuy && triedSell)
      sig=(BBRideScore(sigSell)>BBRideScore(sigBuy) ? sigSell : sigBuy);
   else if(triedBuy)  sig=sigBuy;
   else               sig=sigSell;
  }

//+------------------------------------------------------------------+
//| Chuoi mo ta trang thai tung tang (dashboard)                     |
//+------------------------------------------------------------------+
string BBRideTick(const bool b)
  {
   return(b?"[OK]  ":"[--]  ");
  }
//+------------------------------------------------------------------+
string BBRideModeName(const int mode)
  {
   if(mode==BBRIDE_MODE_BUY)  return("CHI BUY");
   if(mode==BBRIDE_MODE_SELL) return("CHI SELL");
   return("CA HAI CHIEU");
  }
//+------------------------------------------------------------------+
string BBRideStatusText(const string sym,const BBRideSettings &s,const BBRideSignal &sig)
  {
   int    d  =(int)MarketInfo(sym,MODE_DIGITS);
   int    dir=sig.direction;
   bool   isBuy=(dir==BBRIDE_BUY);
   string dirName=BBRideDirName(dir);

   string t="";
   t+="=== BB RIDE MTF - "+sym+" | Che do: "+BBRideModeName(s.tradeMode)+" ===\n";
   t+="Dang xet chieu: "+dirName+(isBuy?"  (D du day dai TREN BB)":"  (D du day dai DUOI BB)")+"\n";
   t+=BBRideTick(sig.okMonthly)     +"1. MN1 xu huong "+(isBuy?"tang":"giam")+"\n";
   t+=BBRideTick(sig.okWeekly)      +"2. W1 xu huong "+(isBuy?"tang":"giam")+"\n";
   t+=BBRideTick(sig.okRoom)        +"3. Con khong gian toi "+(isBuy?"khang cu":"ho tro")+": "+
                                     DoubleToString(sig.roomATR,2)+" ATR\n";
   t+=BBRideTick(sig.okDailyRide)   +"4. D1 du day BB: "+IntegerToString(sig.dailyRideCount)+
                                     " phien, %B="+DoubleToString(sig.dailyPB,2)+"\n";
   t+=BBRideTick(sig.okH1Pullback)  +"5. H1 hoi ve vung "+DoubleToString(sig.h1Zone,d)+"\n";
   t+=BBRideTick(sig.okDoubleBottom)+"6. "+(isBuy?"2 day tang dan":"2 dinh giam dan")+
                                     " (M"+IntegerToString(s.entryTF)+")\n";
   if(sig.piv1>0)
      t+="        "+(isBuy?"day1=":"dinh1=")+DoubleToString(sig.piv1,d)+
         "  "+(isBuy?"day2=":"dinh2=")+DoubleToString(sig.piv2,d)+
         "  neck="+DoubleToString(sig.neckline,d)+"\n";
   t+=BBRideTick(sig.valid)         +"7. TRIGGER\n";
   if(sig.valid)
      t+="        "+dirName+" "+DoubleToString(sig.entry,d)+"  SL "+DoubleToString(sig.sl,d)+
         "  TP "+DoubleToString(sig.tp,d)+"\n";
   t+="Trang thai: "+sig.note+"\n";
   return(t);
  }

//+------------------------------------------------------------------+

//--- ================= CHE DO GIAO DICH ============================
input string  __g0__            = "===== CHE DO GIAO DICH =====";
input int     InpTradeMode      = 0;       // 0 = ca hai chieu | 1 = chi BUY | 2 = chi SELL

//--- ================= THAM SO KHUNG LON (MN1 / W1) =================
input string  __g1__            = "===== KHUNG LON (MN1 / W1) =====";
input bool    InpUseMonthly     = true;    // Bat loc xu huong MN1
input int     InpMnFast         = 5;       // MN1: MA nhanh
input int     InpMnSlow         = 10;      // MN1: MA cham
input bool    InpUseWeekly      = true;    // Bat loc xu huong W1
input int     InpWFast          = 10;      // W1: MA nhanh
input int     InpWSlow          = 20;      // W1: MA cham
input ENUM_MA_METHOD InpMaMethod= MODE_EMA;// Phuong phap MA
input int     InpResLookback    = 60;      // So nen W1 quet khang cu
input int     InpResDepth       = 2;       // Do sau fractal xac dinh dinh
input double  InpMinRoomATR     = 1.5;     // Khoang trong toi thieu toi khang cu (xATR W1)

//--- ================= THAM SO D1 - DU DAY BB =======================
input string  __g2__            = "===== D1 DU DAY BB =====";
input int     InpBBPeriod       = 20;      // Chu ky Bollinger
input double  InpBBDev          = 2.0;     // Do lech chuan BB
input int     InpDRideLookback  = 10;      // So phien D1 danh gia
input int     InpDMinRideBars   = 4;       // So phien toi thieu bam dai tren
input double  InpDRideThreshold = 0.80;    // %B toi thieu de tinh "bam dai" (0-1)
input bool    InpDReqExpansion  = true;    // Yeu cau BB dang mo rong

//--- ================= THAM SO H1 - PULLBACK =======================
input string  __g3__            = "===== H1 HOI VE TREND THUAN =====";
input int     InpH1MaPeriod     = 10;      // MA10 tren H1
input bool    InpH1UseBBMid     = true;    // Chap nhan cham BB giua H1
input double  InpH1TouchATR     = 0.35;    // Dung sai cham vung (xATR H1)
input int     InpH1PullbackBars = 6;       // So nen H1 gan nhat tim cu cham
input double  InpH1MinExtATR    = 1.0;     // Song tang truoc do toi thieu (xATR H1)
input int     InpH1TrendMa      = 50;      // MA loc xu huong H1

//--- ================= THAM SO KHUNG VAO LENH ======================
input string  __g4__            = "===== KHUNG VAO LENH (M5/M1) =====";
input ENUM_TIMEFRAMES InpEntryTF= PERIOD_M5; // Khung tim 2 day
input int     InpEntryLookback  = 80;      // So nen quet 2 day
input int     InpSwingDepth     = 2;       // Do sau fractal cho day
input double  InpMinHigherLow   = 0.0;     // Day 2 cao hon day 1 toi thieu (xATR)
input double  InpMaxHigherLow   = 4.0;     // Day 2 cao hon day 1 toi da (xATR)
input bool    InpReqContraction = true;    // Yeu cau bien do co lai (tich luy)
input bool    InpReqNeckBreak   = true;    // Yeu cau pha neckline

//--- ================= KHOI LUONG & RISK/REWARD ====================
input string  __g5__            = "===== KHOI LUONG & RISK/REWARD =====";
input double  InpRiskPercent    = 1.0;     // % rui ro moi lenh (0 = dung lot co dinh)
input double  InpFixedLots      = 0.01;    // Lot co dinh khi RiskPercent = 0
input double  InpMaxLotCap      = 0.0;     // Tran khoi luong tuyet doi (0 = khong chan)
input double  InpSLBufferATR    = 0.5;     // Dem SL duoi day 2 (xATR khung vao lenh)
input double  InpRR             = 2.0;     // RR muc tieu cho TP
input double  InpMinRR          = 1.5;     // RR THUC TE toi thieu moi duoc vao lenh
input bool    InpTPAtResistance = true;    // Cat TP truoc khang cu W1

//--- ================= DANH SACH CAP DUOC PHEP =====================
input string  __g5b__           = "===== CHI DANH CAC CAP NAY =====";
input bool    InpUseWhitelist   = true;    // Chi cho phep chay tren danh sach duoi
input string  InpSymbolWhitelist= "GBPUSD,GBPAUD,GBPJPY,AUDUSD,EURUSD,EURAUD,EURJPY"; // Cach nhau dau phay

//--- ================= GIOI HAN THUA LO (KY LUAT) ==================
input string  __g6__            = "===== GIOI HAN THUA LO =====";
input double  InpMaxDailyLossPct= 2.0;     // Dung trade khi lo vuot % nay trong ngay (0 = tat)
input bool    InpCountFloating  = true;    // Tinh ca lo dang treo vao han muc ngay
input int     InpMaxConsecLoss  = 3;       // Dung trade sau N lenh thua lien tiep (0 = tat)
input int     InpMaxTradesPerDay= 3;       // So lenh toi da moi ngay (0 = khong gioi han)
input bool    InpAllowAveraging = false;   // Cho phep mo them lenh cung chieu (KHUYEN NGHI: false)
input bool    InpRiskScopeAll   = true;    // TRUE = tinh tran lo/chuoi thua TOAN TAI KHOAN (chay nhieu cap)
input int     InpMaxTradesTotal  = 3;      // Toi da lenh mo dong thoi TOAN TAI KHOAN (0 = tat)
input int     InpMaxSameCurrency = 2;      // Toi da lenh mo cung dong tien co so, vd GBPxxx (0 = tat)
input int     InpMaxTrades      = 1;       // So lenh mo dong thoi toi da

//--- ================= SAN PHAM BIEN DONG MANH =====================
input string  __g7__            = "===== XAUUSD / BTC / CRYPTO =====";
input bool    InpHighVolAuto    = true;    // Tu dong nhan dien va giam risk cho san pham bien dong manh
input double  InpHighVolFactor  = 0.5;     // He so nhan vao Risk% cho san pham do (0.5 = giam mot nua)
input string  InpHighVolKeys    = "XAU,GOLD,XAG,SILVER,BTC,XBT,ETH,CRYPTO"; // Tu khoa nhan dien (cach nhau dau phay)

//--- ================= THUC THI LENH ===============================
input string  __g8__            = "===== THUC THI LENH =====";
input double  InpMaxSpreadPips  = 3.0;     // Spread toi da cho phep (pip)
input int     InpSlippage       = 3;       // Slippage (point)
input int     InpMagic          = 20260910;// Magic number

//--- ================= QUAN LY LENH DANG MO ========================
input string  __g9__            = "===== QUAN LY LENH DANG MO =====";
input bool    InpBreakEvenAt1R  = true;    // Dua SL ve hoa von khi lai 1R
input bool    InpTrailBBMidH1   = true;    // Trailing theo BB giua H1
input bool    InpCloseOnH1Break = false;   // Dong lenh khi H1 dong duoi BB giua

//--- ================= HIEN THI / CANH BAO =========================
input string  __g10__           = "===== HIEN THI / CANH BAO =====";
input bool    InpDryRun         = false;   // TRUE = chi canh bao, khong vao lenh
input bool    InpShowPanel      = true;    // Hien bang trang thai tren chart
input bool    InpAlertPopup     = true;    // Popup khi co tin hieu
input bool    InpAlertPush      = false;   // Push notification

//--- Bien toan cuc
BBRideSettings g_set;
BBRideSignal   g_sig;
datetime       g_lastEntryBar = 0;   // nen da vao lenh (tranh trung tin hieu)
datetime       g_lastCalcBar  = 0;   // nen da tinh toan gan nhat
datetime       g_haltAlertDay = 0;   // da canh bao dung trade cho ngay nao
string         g_blockReason  = "";  // ly do dang bi chan vao lenh

//+------------------------------------------------------------------+
int OnInit()
  {
   BBRideDefaults(g_set);

   g_set.useMonthly        = InpUseMonthly;
   g_set.mnFast            = InpMnFast;
   g_set.mnSlow            = InpMnSlow;
   g_set.useWeekly         = InpUseWeekly;
   g_set.wFast             = InpWFast;
   g_set.wSlow             = InpWSlow;
   g_set.maMethod          = InpMaMethod;
   g_set.resLookback       = InpResLookback;
   g_set.resFractalDepth   = InpResDepth;
   g_set.minRoomATR        = InpMinRoomATR;

   g_set.bbPeriod          = InpBBPeriod;
   g_set.bbDev             = InpBBDev;
   g_set.dRideLookback     = InpDRideLookback;
   g_set.dMinRideBars      = InpDMinRideBars;
   g_set.dRideThreshold    = InpDRideThreshold;
   g_set.dRequireExpansion = InpDReqExpansion;

   g_set.h1MaPeriod        = InpH1MaPeriod;
   g_set.h1UseBBMid        = InpH1UseBBMid;
   g_set.h1TouchATR        = InpH1TouchATR;
   g_set.h1PullbackBars    = InpH1PullbackBars;
   g_set.h1MinExtensionATR = InpH1MinExtATR;
   g_set.h1TrendMa         = InpH1TrendMa;

   g_set.entryTF           = (int)InpEntryTF;
   g_set.entryLookback     = InpEntryLookback;
   g_set.swingDepth        = InpSwingDepth;
   g_set.minHigherLowATR   = InpMinHigherLow;
   g_set.maxHigherLowATR   = InpMaxHigherLow;
   g_set.requireContraction= InpReqContraction;
   g_set.requireNeckBreak  = InpReqNeckBreak;

   g_set.slBufferATR       = InpSLBufferATR;
   g_set.rr                = InpRR;
   g_set.tpAtResistance    = InpTPAtResistance;
   g_set.tradeMode         = InpTradeMode;

   //--- kiem tra tham so
   if(InpDMinRideBars>InpDRideLookback)
     {
      Print("Loi tham so: InpDMinRideBars phai <= InpDRideLookback");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpTradeMode<0 || InpTradeMode>2)
     {
      Print("Loi tham so: InpTradeMode chi nhan 0 (ca hai), 1 (chi BUY) hoac 2 (chi SELL)");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpMinRR<1.0)
     {
      Print("Loi tham so: InpMinRR < 1.0 - he thong nay khong chap nhan RR duoi 1:1");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpRR<InpMinRR)
      Print("Canh bao: InpRR (",DoubleToString(InpRR,2),") thap hon InpMinRR (",
            DoubleToString(InpMinRR,2),") - hau het setup se bi loai");
   if(!SymbolAllowed())
     {
      Print("TU CHOI CHAY: ",Symbol()," khong nam trong danh sach cap duoc phep [",
            InpSymbolWhitelist,"]. Go EA khoi chart nay.");
      Comment("BBRide MTF: ",Symbol()," KHONG nam trong danh sach cap duoc phep.\n",
              "Danh sach: ",InpSymbolWhitelist);
      return(INIT_FAILED);
     }
   if(InpEntryTF!=PERIOD_M1 && InpEntryTF!=PERIOD_M5 && InpEntryTF!=PERIOD_M15)
      Print("Canh bao: khung vao lenh khuyen nghi M1/M5 (dang dung ",(int)InpEntryTF," phut)");
   if(InpRiskPercent<=0.0 && IsHighVolSymbol())
      Print("CANH BAO: ",Symbol()," la san pham bien dong manh - dung LOT CO DINH rat rui ro. ",
            "Nen dat InpRiskPercent > 0 de lot tu dong co giai theo do rong SL.");

   PrintFormat("BBRide MTF EA v1.30 | %s | %s | EntryTF=M%d | Risk=%.2f%% (hieu luc %.2f%%) | RR>=%.2f | Tran lo ngay=%.2f%% (%s)",
               Symbol(),BBRideModeName(InpTradeMode),(int)InpEntryTF,InpRiskPercent,EffectiveRiskPercent(),
               InpMinRR,InpMaxDailyLossPct,(InpRiskScopeAll?"toan tai khoan":"rieng symbol"));
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
  }
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- quan ly lenh dang mo chay moi tick
   ManageOpenTrades();

   //--- chi danh gia tin hieu khi co nen moi tren khung vao lenh
   datetime curBar=iTime(Symbol(),(int)InpEntryTF,0);
   if(curBar==g_lastCalcBar) return;
   g_lastCalcBar=curBar;

   BBRideEvaluate(Symbol(),g_set,g_sig);

   //--- kiem tra hang rao ky luat (luon chay de hien thi tren panel)
   g_blockReason="";
   bool allowed=TradingAllowed(g_blockReason);

   if(InpShowPanel) Comment(BuildPanel());

   if(!g_sig.valid) return;
   if(g_sig.signalBar==g_lastEntryBar) return;      // tin hieu da xu ly

   NotifySignal();

   if(InpDryRun) { g_lastEntryBar=g_sig.signalBar; return; }

   if(!allowed)
     {
      Print("BO QUA TIN HIEU - ",g_blockReason);
      g_lastEntryBar=g_sig.signalBar;               // khong xu ly lai tin hieu nay
      return;
     }
   if(!SpreadOK())
     {
      Print("Bo qua tin hieu: spread qua rong (",DoubleToString(CurrentSpreadPips(),1)," pip)");
      return;
     }

   if(OpenTrade()) g_lastEntryBar=g_sig.signalBar;
  }

//+==================================================================+
//|                    KHOI QUAN TRI RUI RO                          |
//+==================================================================+

//+------------------------------------------------------------------+
//| Gia tri mot pip theo so digits cua broker                        |
//+------------------------------------------------------------------+
double PipSize()
  {
   int    d =(int)MarketInfo(Symbol(),MODE_DIGITS);
   double pt=MarketInfo(Symbol(),MODE_POINT);
   if(d==3 || d==5) return(pt*10.0);   // broker 5 so le: 1 pip = 10 point
   return(pt);
  }
//+------------------------------------------------------------------+
//| GIA TRI 1 PIP CUA 1 LOT (tinh bang tien tai khoan)               |
//| = TickValue x (PipSize / TickSize)                               |
//+------------------------------------------------------------------+
double PipValuePerLot()
  {
   double tickValue=MarketInfo(Symbol(),MODE_TICKVALUE);
   double tickSize =MarketInfo(Symbol(),MODE_TICKSIZE);
   if(tickSize<=0.0 || tickValue<=0.0) return(0.0);
   return(tickValue*(PipSize()/tickSize));
  }
//+------------------------------------------------------------------+
//| Symbol hien tai co nam trong danh sach duoc phep khong?          |
//| So khop kieu "chua chuoi" nen chap nhan hau to cua broker:       |
//| EURUSD.m, EURUSDpro, EURUSD_i ... deu khop "EURUSD"              |
//+------------------------------------------------------------------+
bool SymbolAllowed()
  {
   if(!InpUseWhitelist) return(true);

   string sym=Symbol();
   StringToUpper(sym);
   string list=InpSymbolWhitelist;
   StringToUpper(list);

   string parts[];
   int n=StringSplit(list,StringGetCharacter(",",0),parts);
   for(int i=0;i<n;i++)
     {
      string k=parts[i];
      StringTrimLeft(k); StringTrimRight(k);
      if(StringLen(k)==0) continue;
      if(StringFind(sym,k)>=0) return(true);
     }
   return(false);
  }
//+------------------------------------------------------------------+
//| Lenh dang xet co thuoc pham vi tinh rui ro khong?                |
//| InpRiskScopeAll = true  -> gop moi symbol co cung Magic          |
//| InpRiskScopeAll = false -> chi symbol cua chart nay              |
//+------------------------------------------------------------------+
bool InRiskScope()
  {
   if(OrderMagicNumber()!=InpMagic) return(false);
   if(!InpRiskScopeAll && OrderSymbol()!=Symbol()) return(false);
   return(true);
  }
//+------------------------------------------------------------------+
//| Nhan dien san pham bien dong manh (XAU, BTC, ...)                |
//+------------------------------------------------------------------+
bool IsHighVolSymbol()
  {
   if(!InpHighVolAuto) return(false);

   string sym=Symbol();
   StringToUpper(sym);
   string keys=InpHighVolKeys;
   StringToUpper(keys);

   string parts[];
   int n=StringSplit(keys,StringGetCharacter(",",0),parts);
   for(int i=0;i<n;i++)
     {
      string k=parts[i];
      StringTrimLeft(k); StringTrimRight(k);
      if(StringLen(k)==0) continue;
      if(StringFind(sym,k)>=0) return(true);
     }
   return(false);
  }
//+------------------------------------------------------------------+
//| Risk% hieu luc: giam cho san pham bien dong manh                 |
//| (XAUUSD/BTC khong duoc dung cung mot muc rui ro nhu forex)       |
//+------------------------------------------------------------------+
double EffectiveRiskPercent()
  {
   double r=InpRiskPercent;
   if(r>0.0 && IsHighVolSymbol()) r*=InpHighVolFactor;
   return(r);
  }
//+------------------------------------------------------------------+
//| CONG THUC TINH LOT                                               |
//|   Tien rui ro = Balance x Risk%                                  |
//|   Lot = Tien rui ro / (SL pips x Gia tri 1 pip cua 1 lot)        |
//+------------------------------------------------------------------+
double CalcLots(const double entry,const double sl,string &detail)
  {
   detail="";
   if(InpRiskPercent<=0.0)
     {
      detail=StringConcatenate("Lot co dinh ",DoubleToString(InpFixedLots,2));
      return(NormalizeLots(InpFixedLots));
     }

   double riskPct  =EffectiveRiskPercent();
   double riskMoney=AccountBalance()*riskPct/100.0;          // Tien rui ro
   double pip      =PipSize();
   double slPips   =(pip>0.0 ? MathAbs(entry-sl)/pip : 0.0); // SL tinh bang pip
   double pipValue =PipValuePerLot();                        // Gia tri 1 pip cua 1 lot

   if(slPips<=0.0 || pipValue<=0.0)
     {
      Print("Khong tinh duoc lot theo rui ro (slPips=",DoubleToString(slPips,1),
            ", pipValue=",DoubleToString(pipValue,2),") - dung lot co dinh");
      detail="Fallback lot co dinh";
      return(NormalizeLots(InpFixedLots));
     }

   double lots=riskMoney/(slPips*pipValue);

   detail=StringConcatenate("Risk ",DoubleToString(riskPct,2),"% = ",
                            DoubleToString(riskMoney,2)," | SL ",DoubleToString(slPips,1),
                            " pip | 1 pip/lot = ",DoubleToString(pipValue,2),
                            " | lot = ",DoubleToString(lots,2));
   return(NormalizeLots(lots));
  }
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
  {
   double minLot =MarketInfo(Symbol(),MODE_MINLOT);
   double maxLot =MarketInfo(Symbol(),MODE_MAXLOT);
   double lotStep=MarketInfo(Symbol(),MODE_LOTSTEP);
   if(lotStep<=0.0) lotStep=0.01;

   lots=MathFloor(lots/lotStep)*lotStep;                 // lam tron XUONG - khong bao gio vuot risk
   if(InpMaxLotCap>0.0 && lots>InpMaxLotCap) lots=InpMaxLotCap;
   if(lots>maxLot) lots=maxLot;
   if(lots<minLot) lots=0.0;                             // khong du von cho lot toi thieu -> bo lenh
   return(NormalizeDouble(lots,2));
  }
//+------------------------------------------------------------------+
//| Moc dau ngay theo gio server                                     |
//+------------------------------------------------------------------+
datetime DayStart()
  {
   return(StringToTime(TimeToString(TimeCurrent(),TIME_DATE)));
  }
//+------------------------------------------------------------------+
//| Lai/lo da dong trong ngay + so lenh da vao trong ngay            |
//+------------------------------------------------------------------+
void DailyClosedStats(double &realized,int &tradesToday)
  {
   realized=0.0; tradesToday=0;
   datetime ds=DayStart();

   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(!InRiskScope()) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      if(OrderCloseTime()<ds) continue;
      realized+=OrderProfit()+OrderSwap()+OrderCommission();
      tradesToday++;
     }
   //--- lenh mo trong ngay nhung chua dong cung tinh vao so lenh
   for(int j=OrdersTotal()-1;j>=0;j--)
     {
      if(!OrderSelect(j,SELECT_BY_POS,MODE_TRADES)) continue;
      if(!InRiskScope()) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      if(OrderOpenTime()>=ds) tradesToday++;
     }
  }
//+------------------------------------------------------------------+
//| Lai/lo dang treo cua cac lenh EA                                 |
//+------------------------------------------------------------------+
double FloatingPL()
  {
   double pl=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(!InRiskScope()) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      pl+=OrderProfit()+OrderSwap()+OrderCommission();
     }
   return(pl);
  }
//+------------------------------------------------------------------+
//| Dem so lenh THUA LIEN TIEP gan nhat                              |
//+------------------------------------------------------------------+
int ConsecutiveLosses()
  {
   //--- cache: chi quet lai khi so lenh trong lich su thay doi
   static int cachedHistory=-1;
   static int cachedValue=0;
   int histTotal=OrdersHistoryTotal();
   if(histTotal==cachedHistory) return(cachedValue);
   //--- lich su thay doi -> quet lai

   int      cnt=0;
   datetime cutoff=TimeCurrent()+86400;      // moc tren de bat dau quet lui

   for(int n=0;n<20;n++)                     // toi da 20 lenh gan nhat
     {
      datetime bestTime=0;
      double   bestPL=0.0;
      bool     found=false;

      for(int i=OrdersHistoryTotal()-1;i>=0;i--)
        {
         if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
         if(!InRiskScope()) continue;
         if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
         datetime ct=OrderCloseTime();
         if(ct<=0 || ct>=cutoff) continue;
         if(ct>bestTime)
           {
            bestTime=ct;
            bestPL  =OrderProfit()+OrderSwap()+OrderCommission();
            found   =true;
           }
        }
      if(!found) break;
      if(bestPL<0.0) cnt++; else break;      // gap lenh khong thua -> dut chuoi
      cutoff=bestTime;
     }
   cachedHistory=histTotal;
   cachedValue=cnt;
   return(cnt);
  }
//+------------------------------------------------------------------+
//| % lo trong ngay so voi balance dau ngay                          |
//| (so duong = dang lo, so am = dang lai)                           |
//+------------------------------------------------------------------+
double DailyLossPercent(double &realized,double &floating,int &tradesToday)
  {
   DailyClosedStats(realized,tradesToday);
   floating=FloatingPL();

   double dayStartBalance=AccountBalance()-realized;   // balance truoc khi vao ngay giao dich
   if(dayStartBalance<=0.0) return(0.0);

   double total=realized+(InpCountFloating?floating:0.0);
   return(-total/dayStartBalance*100.0);
  }
//+------------------------------------------------------------------+
//| HANG RAO KY LUAT: co duoc phep vao lenh moi khong?               |
//+------------------------------------------------------------------+
bool TradingAllowed(string &reason)
  {
   reason="";

   //--- 0) cap giao dich phai nam trong danh sach cho phep
   if(!SymbolAllowed())
     { reason=Symbol()+" khong nam trong danh sach cap duoc phep"; return(false); }

   //--- 1) khong binh quan gia / khong mo them lenh cung chieu
   int openCnt=CountMyTrades();
   if(!InpAllowAveraging && openCnt>0)
     { reason="Da co lenh dang mo - khong binh quan gia"; return(false); }
   if(openCnt>=InpMaxTrades)
     { reason="Da dat so lenh mo toi da tren "+Symbol()+" ("+IntegerToString(InpMaxTrades)+")"; return(false); }

   //--- 1b) tran lenh mo toan tai khoan
   if(InpMaxTradesTotal>0)
     {
      int gCnt=CountOpenTradesGlobal();
      if(gCnt>=InpMaxTradesTotal)
        { reason="Da co "+IntegerToString(gCnt)+" lenh mo toan tai khoan (tran "+
                 IntegerToString(InpMaxTradesTotal)+")"; return(false); }
     }

   //--- 1c) chan cuoc cong don cung mot dong tien (GBPUSD+GBPAUD+GBPJPY = 3 lan long GBP)
   if(InpMaxSameCurrency>0)
     {
      int sCnt=CountOpenSameBase(g_sig.direction);
      if(sCnt>=InpMaxSameCurrency)
        { reason="Da co "+IntegerToString(sCnt)+" lenh dang "+
                 (g_sig.direction==BBRIDE_BUY?"long ":"short ")+BaseCurrency(Symbol())+
                 " (tran "+IntegerToString(InpMaxSameCurrency)+") - tranh cuoc cong don"; return(false); }
     }

   //--- 2) so lenh trong ngay
   double realized=0.0; int tradesToday=0;
   DailyClosedStats(realized,tradesToday);
   if(InpMaxTradesPerDay>0 && tradesToday>=InpMaxTradesPerDay)
     { reason="Da du "+IntegerToString(tradesToday)+" lenh trong ngay"; return(false); }

   //--- 3) tran lo trong ngay
   if(InpMaxDailyLossPct>0.0)
     {
      double rz=0.0,fl=0.0; int tdCnt=0;
      double lossPct=DailyLossPercent(rz,fl,tdCnt);
      if(lossPct>=InpMaxDailyLossPct)
        {
         reason="DUNG TRADE: lo "+DoubleToString(lossPct,2)+"% >= tran "+
                DoubleToString(InpMaxDailyLossPct,2)+"% trong ngay";
         AlertHaltOnce(reason);
         return(false);
        }
     }

   //--- 4) chuoi thua lien tiep
   if(InpMaxConsecLoss>0)
     {
      int cl=ConsecutiveLosses();
      if(cl>=InpMaxConsecLoss)
        {
         reason="DUNG TRADE: "+IntegerToString(cl)+" lenh thua lien tiep (tran "+
                IntegerToString(InpMaxConsecLoss)+") - nghi, review lai setup";
         AlertHaltOnce(reason);
         return(false);
        }
     }
   return(true);
  }
//+------------------------------------------------------------------+
//| Canh bao dung trade - moi ngay chi bao mot lan                   |
//+------------------------------------------------------------------+
void AlertHaltOnce(const string reason)
  {
   datetime ds=DayStart();
   if(g_haltAlertDay==ds) return;
   g_haltAlertDay=ds;
   Print(reason);
   if(InpAlertPopup) Alert(Symbol()," - ",reason);
   if(InpAlertPush)  SendNotification(Symbol()+" - "+reason);
  }
//+------------------------------------------------------------------+
double CurrentSpreadPips()
  {
   double sp =(MarketInfo(Symbol(),MODE_ASK)-MarketInfo(Symbol(),MODE_BID));
   double pip=PipSize();
   if(pip<=0.0) return(0.0);
   return(sp/pip);
  }
//+------------------------------------------------------------------+
bool SpreadOK()
  {
   if(InpMaxSpreadPips<=0.0) return(true);
   return(CurrentSpreadPips()<=InpMaxSpreadPips);
  }
//+------------------------------------------------------------------+
int CountMyTrades()
  {
   int n=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagic) continue;
      if(OrderType()==OP_BUY || OrderType()==OP_SELL) n++;
     }
   return(n);
  }

//+==================================================================+
//|                       KHOI THUC THI LENH                         |
//+==================================================================+

//+------------------------------------------------------------------+
//| Dem lenh mo tren TOAN TAI KHOAN (cung Magic, moi symbol)         |
//+------------------------------------------------------------------+
int CountOpenTradesGlobal()
  {
   int n=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=InpMagic) continue;
      if(OrderType()==OP_BUY || OrderType()==OP_SELL) n++;
     }
   return(n);
  }
//+------------------------------------------------------------------+
//| Dong tien co so cua symbol (3 ky tu dau), vd EURJPY -> EUR       |
//| Luu y: broker dat TIEN TO (mEURUSD) se cho ket qua sai           |
//+------------------------------------------------------------------+
string BaseCurrency(const string sym)
  {
   string s2=sym;
   StringToUpper(s2);
   if(StringLen(s2)<3) return(s2);
   return(StringSubstr(s2,0,3));
  }
//+------------------------------------------------------------------+
//| Dem lenh mo dang cuoc cung mot dong tien co so                   |
//| (GBPUSD + GBPAUD + GBPJPY deu la long GBP -> rui ro cong don)    |
//+------------------------------------------------------------------+
int CountOpenSameBase(const int dir)
  {
   string base=BaseCurrency(Symbol());
   int wanted=(dir==BBRIDE_BUY ? OP_BUY : OP_SELL);
   int n=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=InpMagic) continue;
      if(OrderType()!=wanted) continue;                  // chi cong don khi CUNG CHIEU
      if(BaseCurrency(OrderSymbol())==base) n++;
     }
   return(n);
  }
//+------------------------------------------------------------------+
//| Bao dam SL/TP ton trong STOPLEVEL cua broker                     |
//+------------------------------------------------------------------+
bool ValidateStops(const int dir,const double price,double &sl,double &tp)
  {
   int    digits =(int)MarketInfo(Symbol(),MODE_DIGITS);
   double point  =MarketInfo(Symbol(),MODE_POINT);
   double minDist=MarketInfo(Symbol(),MODE_STOPLEVEL)*point;
   if(minDist<=0.0) minDist=2*point;

   if(dir==BBRIDE_BUY)
     {
      if(price-sl<minDist) sl=NormalizeDouble(price-minDist,digits);
      if(tp-price<minDist) return(false);            // TP qua gan -> bo setup
     }
   else
     {
      if(sl-price<minDist) sl=NormalizeDouble(price+minDist,digits);
      if(price-tp<minDist) return(false);
     }
   sl=NormalizeDouble(sl,digits);
   tp=NormalizeDouble(tp,digits);
   return(true);
  }
//+------------------------------------------------------------------+
//| Mo lenh BUY theo tin hieu                                        |
//+------------------------------------------------------------------+
bool OpenTrade()
  {
   int    dir    =g_sig.direction;
   int    opType =(dir==BBRIDE_BUY ? OP_BUY : OP_SELL);
   color  clrOrd =(dir==BBRIDE_BUY ? clrDodgerBlue : clrOrangeRed);
   string dirName=BBRideDirName(dir);
   double sl=g_sig.sl, tp=g_sig.tp;

   for(int attempt=0;attempt<3;attempt++)
     {
      RefreshRates();
      double price=(dir==BBRIDE_BUY ? MarketInfo(Symbol(),MODE_ASK) : MarketInfo(Symbol(),MODE_BID));
      double slTry=sl, tpTry=tp;
      if(!ValidateStops(dir,price,slTry,tpTry))
        {
         Print("Bo qua: TP khong dat khoang cach toi thieu cua broker");
         return(false);
        }

      //--- RR THUC TE tai gia khop, sau khi TP da bi can chan cat bot
      double riskDist=(dir==BBRIDE_BUY ? price-slTry : slTry-price);
      if(riskDist<=0.0) { Print("Bo qua: SL khong hop le"); return(false); }
      double rrEff=(dir==BBRIDE_BUY ? (tpTry-price) : (price-tpTry))/riskDist;
      if(rrEff<InpMinRR)
        {
         PrintFormat("Bo qua setup %s: RR thuc te %.2f < RR toi thieu %.2f",dirName,rrEff,InpMinRR);
         return(false);
        }

      string lotDetail="";
      double lots=CalcLots(price,slTry,lotDetail);
      if(lots<=0.0)
        {
         Print("Bo qua: khoi luong tinh ra = 0 (von khong du cho lot toi thieu voi SL nay). ",lotDetail);
         return(false);
        }

      int ticket=OrderSend(Symbol(),opType,lots,price,InpSlippage,slTry,tpTry,
                           "BBRide MTF "+dirName,InpMagic,0,clrOrd);
      if(ticket>0)
        {
         PrintFormat("MO %s #%d lots=%.2f entry=%s SL=%s TP=%s RR=%.2f | %s",
                     dirName,ticket,lots,
                     DoubleToString(price,Digits),DoubleToString(slTry,Digits),
                     DoubleToString(tpTry,Digits),rrEff,lotDetail);
         return(true);
        }

      int err=GetLastError();
      PrintFormat("OrderSend that bai (lan %d), loi %d",attempt+1,err);
      if(err==ERR_INVALID_STOPS || err==ERR_NOT_ENOUGH_MONEY || err==ERR_TRADE_DISABLED) break;
      Sleep(500);
     }
   return(false);
  }
//+------------------------------------------------------------------+
//| Quan ly lenh dang mo                                             |
//| NGUYEN TAC: SL CHI DUOC DI CHUYEN THEO HUONG CO LOI.             |
//| Khong bao gio noi rong SL vi lenh dang am.                       |
//+------------------------------------------------------------------+
void ManageOpenTrades()
  {
   int    digits =(int)MarketInfo(Symbol(),MODE_DIGITS);
   double point  =MarketInfo(Symbol(),MODE_POINT);
   double minDist=MarketInfo(Symbol(),MODE_STOPLEVEL)*point;
   double bid    =MarketInfo(Symbol(),MODE_BID);
   double ask    =MarketInfo(Symbol(),MODE_ASK);
   double bbMidH1=iBands(Symbol(),PERIOD_H1,InpBBPeriod,InpBBDev,0,PRICE_CLOSE,MODE_MAIN,0);
   double closeH1=iClose(Symbol(),PERIOD_H1,1);

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagic) continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL) continue;

      double open =OrderOpenPrice();
      double sl   =OrderStopLoss();
      bool   isBuy=(type==OP_BUY);

      //--- thoat khi H1 dong cua gay trend thuan
      if(InpCloseOnH1Break)
        {
         bool broken=(isBuy ? closeH1<bbMidH1 : closeH1>bbMidH1);
         if(broken)
           {
            double px=(isBuy?bid:ask);
            if(OrderClose(OrderTicket(),OrderLots(),px,InpSlippage,clrOrangeRed))
               Print("Dong lenh #",OrderTicket()," do H1 dong ",(isBuy?"duoi":"tren")," BB giua");
            continue;
           }
        }

      if(isBuy)
        {
         double newSl=sl;
         //--- hoa von khi lai 1R
         if(InpBreakEvenAt1R && sl<open)
           {
            double r=open-sl;
            if(r>0.0 && bid-open>=r) newSl=MathMax(newSl,open);
           }
         //--- trailing theo BB giua H1 (chi keo LEN)
         if(InpTrailBBMidH1 && bbMidH1>0.0 && bbMidH1>newSl && bbMidH1<bid-minDist)
            newSl=bbMidH1;
         //--- CHAN CUNG: SL khong bao gio lui ve sau
         if(newSl<sl) newSl=sl;

         newSl=NormalizeDouble(newSl,digits);
         if(newSl>sl+point && bid-newSl>minDist)
            if(!OrderModify(OrderTicket(),open,newSl,OrderTakeProfit(),0,clrGreen))
               Print("OrderModify that bai #",OrderTicket()," loi ",GetLastError());
        }
      else
        {
         //--- SL = 0 nghia la chua co SL: dung moc rat xa de logic keo xuong hoat dong
         double newSl=(sl>0.0 ? sl : ask+10000*point);
         //--- hoa von khi lai 1R
         if(InpBreakEvenAt1R && sl>open)
           {
            double r=sl-open;
            if(r>0.0 && open-ask>=r) newSl=MathMin(newSl,open);
           }
         //--- trailing theo BB giua H1 (chi keo XUONG)
         if(InpTrailBBMidH1 && bbMidH1>0.0 && bbMidH1<newSl && bbMidH1>ask+minDist)
            newSl=bbMidH1;
         //--- CHAN CUNG: SL khong bao gio noi rong len tren
         if(sl>0.0 && newSl>sl) newSl=sl;

         newSl=NormalizeDouble(newSl,digits);
         if((sl<=0.0 || newSl<sl-point) && newSl-ask>minDist)
            if(!OrderModify(OrderTicket(),open,newSl,OrderTakeProfit(),0,clrGreen))
               Print("OrderModify that bai #",OrderTicket()," loi ",GetLastError());
        }
     }
  }
//+------------------------------------------------------------------+
void NotifySignal()
  {
   double rr=0.0;
   double riskDist=(g_sig.direction==BBRIDE_BUY ? g_sig.entry-g_sig.sl : g_sig.sl-g_sig.entry);
   if(riskDist>0.0)
      rr=(g_sig.direction==BBRIDE_BUY ? g_sig.tp-g_sig.entry : g_sig.entry-g_sig.tp)/riskDist;

   string msg=StringConcatenate("BBRide ",BBRideDirName(g_sig.direction)," ",Symbol(),
                                " | Entry ",DoubleToString(g_sig.entry,Digits),
                                " | SL ",DoubleToString(g_sig.sl,Digits),
                                " | TP ",DoubleToString(g_sig.tp,Digits),
                                " | RR ",DoubleToString(rr,2));
   Print(msg);
   if(InpAlertPopup) Alert(msg);
   if(InpAlertPush)  SendNotification(msg);
  }
//+------------------------------------------------------------------+
//| Bang trang thai tren chart                                       |
//+------------------------------------------------------------------+
string BuildPanel()
  {
   string t=BBRideStatusText(Symbol(),g_set,g_sig);

   double realized=0.0,floating=0.0;
   int    tradesToday=0;
   double lossPct=DailyLossPercent(realized,floating,tradesToday);
   int    consec=ConsecutiveLosses();

   t+="---------------- QUAN TRI RUI RO ----------------\n";
   t+="Risk/lenh: "+DoubleToString(EffectiveRiskPercent(),2)+"%";
   if(IsHighVolSymbol()) t+=" (da giam x"+DoubleToString(InpHighVolFactor,2)+" - san pham bien dong manh)";
   t+="\n";
   t+="P/L ngay: "+DoubleToString(realized,2)+" da dong / "+DoubleToString(floating,2)+" dang treo  =>  ";
   t+=(lossPct>0.0? "lo "+DoubleToString(lossPct,2)+"%" : "lai "+DoubleToString(-lossPct,2)+"%");
   t+="  (tran "+DoubleToString(InpMaxDailyLossPct,2)+"%)\n";
   t+="Pham vi tinh rui ro: "+(InpRiskScopeAll?"TOAN TAI KHOAN (moi cap cung Magic)":"RIENG "+Symbol())+"\n";
   t+="Lenh hom nay: "+IntegerToString(tradesToday);
   if(InpMaxTradesPerDay>0) t+="/"+IntegerToString(InpMaxTradesPerDay);
   t+="  |  Thua lien tiep: "+IntegerToString(consec)+"/"+IntegerToString(InpMaxConsecLoss)+"\n";
   t+="Spread: "+DoubleToString(CurrentSpreadPips(),1)+" pip  |  Lenh mo: "+
      IntegerToString(CountMyTrades())+"/"+IntegerToString(InpMaxTrades)+" (cap nay)";
   t+="  |  Toan TK: "+IntegerToString(CountOpenTradesGlobal());
   if(InpMaxTradesTotal>0) t+="/"+IntegerToString(InpMaxTradesTotal);
   t+="  |  "+(g_sig.direction==BBRIDE_BUY?"Long ":"Short ")+BaseCurrency(Symbol())+": "+
      IntegerToString(CountOpenSameBase(g_sig.direction));
   if(InpMaxSameCurrency>0) t+="/"+IntegerToString(InpMaxSameCurrency);
   t+="\n";
   if(StringLen(g_blockReason)>0) t+=">>> CHAN VAO LENH: "+g_blockReason+"\n";
   t+=(InpDryRun?"CHE DO: CHI CANH BAO (DryRun)":"CHE DO: VAO LENH THAT")+"\n";
   t+="Cap nhat: "+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
   return(t);
  }
//+------------------------------------------------------------------+
