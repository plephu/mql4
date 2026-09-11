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
#property strict

#ifndef __BBRIDE_CORE_MQH__
#define __BBRIDE_CORE_MQH__

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
   //--- Bo khung thoi gian (thay doi duoc -> mot bo logic dung cho nhieu kich ban)
   int               tfTrend1;          // khung xu huong lon nhat   (MN1 / W1)
   int               tfTrend2;          // khung xu huong thu hai + quet khang cu/ho tro (W1 / D1)
   int               tfRide;            // khung "du day BB"         (D1 / H1)
   int               tfPullback;        // khung hoi ve MA10/BB giua (H1 / M15)
   //--- Tang 1: xu huong khung lon (MN1 / W1)
   bool              useMonthly;        // bat loc tfTrend1
   int               mnFast;
   int               mnSlow;
   bool              useWeekly;         // bat loc tfTrend2
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
   int               pbMaPeriod;
   bool              pbUseBBMid;
   double            pbTouchATR;
   int               pbBars;
   double            pbMinExtATR;
   int               pbTrendMa;
   //--- Tang 4-5: khung vao lenh
   int               entryTF;
   int               entryLookback;
   int               swingDepth;
   double            minHigherLowATR;   // BUY: day2 cao hon day1 | SELL: dinh2 thap hon dinh1
   double            maxHigherLowATR;
   bool              requireContraction;
   bool              requireNeckBreak;
   bool              requireTrendBreak; // yeu cau pha duong trend cua nhip hoi
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
   double            trendLine;      // gia tri duong trend nhip hoi tai nen trigger
   datetime          tlTime1;        // diem neo 1 cua duong trend (cu hon)
   double            tlPrice1;
   datetime          tlTime2;        // diem neo 2 (moi hon)
   double            tlPrice2;
   datetime          signalBar;
   //--- chan doan tung tang
   bool              okMonthly;
   bool              okWeekly;
   bool              okRoom;
   bool              okDailyRide;
   bool              okPullback;
   bool              okDoubleBottom;
   bool              okTrendBreak;
   bool              okTrigger;
   double            roomATR;
   double            dailyPB;
   int               dailyRideCount;
   double            pbZone;
   string            note;
  };

//+------------------------------------------------------------------+
//| Gan tham so mac dinh                                             |
//+------------------------------------------------------------------+
void BBRideDefaults(BBRideSettings &s)
  {
   s.tradeMode         = BBRIDE_MODE_BOTH;
   s.tfTrend1          = PERIOD_MN1;
   s.tfTrend2          = PERIOD_W1;
   s.tfRide            = PERIOD_D1;
   s.tfPullback        = PERIOD_H1;
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
   s.pbMaPeriod        = 10;
   s.pbUseBBMid        = true;
   s.pbTouchATR        = 0.35;
   s.pbBars    = 6;
   s.pbMinExtATR = 1.0;
   s.pbTrendMa         = 50;
   s.entryTF           = PERIOD_M5;
   s.entryLookback     = 80;
   s.swingDepth        = 2;
   s.minHigherLowATR   = 0.0;
   s.maxHigherLowATR   = 4.0;
   s.requireContraction= true;
   s.requireNeckBreak  = true;
   s.requireTrendBreak = true;
   s.slBufferATR       = 0.5;
   s.rr                = 2.0;
   s.tpAtResistance    = true;
  }

//+------------------------------------------------------------------+
//| KICH BAN DUNG SAN (preset)                                       |
//|  0 - SWING   : MN1+W1 xu huong -> D1 du day BB -> H1 hoi -> M5   |
//|  1 - INTRADAY: W1+D1  xu huong -> H4 du day BB -> M15 hoi -> M5  |
//|  2 - CUSTOM  : giu nguyen khung dang cau hinh                    |
//|                                                                   |
//| Ca hai kich ban chay CUNG MOT bo logic, chi khac bo khung thoi   |
//| gian. Cung mot cach doc thi truong, ap o hai cap do khac nhau.    |
//+------------------------------------------------------------------+
#define BBRIDE_PRESET_SWING     0
#define BBRIDE_PRESET_INTRADAY  1
#define BBRIDE_PRESET_CUSTOM    2

void BBRideApplyPreset(BBRideSettings &s,const int preset)
  {
   if(preset==BBRIDE_PRESET_SWING)
     {
      s.tfTrend1  = PERIOD_MN1;
      s.tfTrend2  = PERIOD_W1;
      s.tfRide    = PERIOD_D1;
      s.tfPullback= PERIOD_H1;
      s.entryTF   = PERIOD_M5;
     }
   else if(preset==BBRIDE_PRESET_INTRADAY)
     {
      s.tfTrend1  = PERIOD_W1;
      s.tfTrend2  = PERIOD_D1;
      s.tfRide    = PERIOD_H4;
      s.tfPullback= PERIOD_M15;
      s.entryTF   = PERIOD_M5;
     }
   //--- CUSTOM: khong dong vao gi ca
  }

//+------------------------------------------------------------------+
//| Ten khung thoi gian de hien thi                                  |
//+------------------------------------------------------------------+
string BBRideTFName(const int tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return("M1");
      case PERIOD_M5:  return("M5");
      case PERIOD_M15: return("M15");
      case PERIOD_M30: return("M30");
      case PERIOD_H1:  return("H1");
      case PERIOD_H4:  return("H4");
      case PERIOD_D1:  return("D1");
      case PERIOD_W1:  return("W1");
      case PERIOD_MN1: return("MN1");
     }
   return("M"+IntegerToString(tf));
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
//| TANG 2: khung tfRide dang "du day" theo chieu dir                 |
//|  BUY : %B >= nguong (bam dai TREN)                               |
//|  SELL: %B <= 1 - nguong (bam dai DUOI)                           |
//+------------------------------------------------------------------+
bool BBRideDailyRiding(const string sym,const BBRideSettings &s,const int dir,
                       int &rideCount,double &pbLast)
  {
   rideCount=0;
   pbLast=0.0;
   int need=s.bbPeriod+s.dRideLookback+5;
   if(!BBRideHasBars(sym,s.tfRide,need)) return(false);

   double loThreshold=1.0-s.dRideThreshold;

   for(int i=1;i<=s.dRideLookback;i++)
     {
      double pb=BBRidePercentB(sym,s.tfRide,s.bbPeriod,s.bbDev,i);
      if(i==1) pbLast=pb;
      if(dir==BBRIDE_BUY) { if(pb>=s.dRideThreshold) rideCount++; }
      else                { if(pb<=loThreshold)      rideCount++; }
     }
   if(rideCount<s.dMinRideBars) return(false);

   //--- BB giua phai doc dung chieu
   double midNow =iBands(sym,s.tfRide,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_MAIN,1);
   double midPast=iBands(sym,s.tfRide,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_MAIN,s.dRideLookback);
   double close1 =iClose(sym,s.tfRide,1);

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
      double wNow =iBands(sym,s.tfRide,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_UPPER,1)
                  -iBands(sym,s.tfRide,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_LOWER,1);
      double wPast=iBands(sym,s.tfRide,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_UPPER,s.dRideLookback)
                  -iBands(sym,s.tfRide,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_LOWER,s.dRideLookback);
      if(wNow<wPast) return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| TANG 3: khung tfPullback hoi ve MA10 / BB giua, KHONG gay trend   |
//|  BUY : gia hoi XUONG vung, khong dong cua sau DUOI vung          |
//|  SELL: gia hoi LEN  vung, khong dong cua sau TREN vung           |
//+------------------------------------------------------------------+
bool BBRidePullbackZone(const string sym,const BBRideSettings &s,const int dir,double &zoneOut)
  {
   zoneOut=0.0;
   int need=MathMax(s.pbTrendMa,s.bbPeriod)+s.pbBars+30;
   if(!BBRideHasBars(sym,s.tfPullback,need)) return(false);

   double atr=iATR(sym,s.tfPullback,14,1);
   if(atr<=0.0) return(false);

   double ma10 =iMA(sym,s.tfPullback,s.pbMaPeriod,0,s.maMethod,PRICE_CLOSE,0);
   double bbMid=iBands(sym,s.tfPullback,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_MAIN,0);
   double bbMidPast=iBands(sym,s.tfPullback,s.bbPeriod,s.bbDev,0,PRICE_CLOSE,MODE_MAIN,s.pbBars+3);
   double trendMa=iMA(sym,s.tfPullback,s.pbTrendMa,0,s.maMethod,PRICE_CLOSE,0);
   double close1 =iClose(sym,s.tfPullback,1);

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

   double tol  =s.pbTouchATR*atr;
   double price=iClose(sym,s.tfPullback,0);

   //--- chon vung hoi gan gia nhat
   double zone=ma10;
   if(s.pbUseBBMid && MathAbs(price-bbMid)<MathAbs(price-ma10)) zone=bbMid;
   zoneOut=zone;

   if(dir==BBRIDE_BUY)
     {
      //--- 1) truoc do gia phai gian LEN khoi vung
      double maxHigh=0.0;
      for(int i=1;i<=s.pbBars+12;i++)
        {
         double h=iHigh(sym,s.tfPullback,i);
         if(h>maxHigh) maxHigh=h;
        }
      if((maxHigh-zone)<s.pbMinExtATR*atr) return(false);

      //--- 2) co cu cham vung tu tren xuong
      bool touched=false;
      for(int j=0;j<=s.pbBars;j++)
         if(iLow(sym,s.tfPullback,j)<=zone+tol) { touched=true; break; }
      if(!touched) return(false);

      //--- 3) chua gay: khong nen nao dong cua sau DUOI vung
      for(int k=1;k<=s.pbBars;k++)
         if(iClose(sym,s.tfPullback,k)<zone-tol) return(false);
      return(true);
     }

   //--- SELL: doi xung
   double minLow=0.0;
   for(int i2=1;i2<=s.pbBars+12;i2++)
     {
      double l=iLow(sym,s.tfPullback,i2);
      if(minLow==0.0 || l<minLow) minLow=l;
     }
   if((zone-minLow)<s.pbMinExtATR*atr) return(false);

   bool touched2=false;
   for(int j2=0;j2<=s.pbBars;j2++)
      if(iHigh(sym,s.tfPullback,j2)>=zone-tol) { touched2=true; break; }
   if(!touched2) return(false);

   for(int k2=1;k2<=s.pbBars;k2++)
      if(iClose(sym,s.tfPullback,k2)>zone+tol) return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//| DUONG TREND CUA NHIP HOI (tren khung vao lenh)                   |
//|  BUY : noi 2 DINH gan nhat -> duong trend GIAM cua nhip dieu chinh|
//|        vao lenh khi gia dong cua VUOT LEN tren duong nay          |
//|  SELL: noi 2 DAY gan nhat -> duong trend TANG cua nhip hoi        |
//|        vao lenh khi gia dong cua XUYEN XUONG duoi duong nay       |
//|                                                                   |
//|  Duong trend bat tin hieu SOM va chinh xac hon neckline ngang:    |
//|  neckline chi gay khi gia vuot dinh cu, con duong trend gay ngay  |
//|  khi nhip dieu chinh mat da.                                      |
//+------------------------------------------------------------------+
bool BBRideTrendLineBreak(const string sym,const BBRideSettings &s,const int dir,
                          double &lineAtSignal,datetime &t1,double &p1,
                          datetime &t2,double &p2,string &why)
  {
   lineAtSignal=0; t1=0; p1=0; t2=0; p2=0; why="";
   int tf=s.entryTF;

   //--- tim 2 diem xoay NGUOC chieu gan nhat (dinh cho BUY, day cho SELL)
   int sA=-1,sB=-1;                       // sB = moi hon (shift nho hon)
   for(int i=s.swingDepth+1;i<=s.entryLookback;i++)
     {
      bool isCounter=(dir==BBRIDE_BUY ? BBRideIsSwingHigh(sym,tf,i,s.swingDepth)
                                      : BBRideIsSwingLow(sym,tf,i,s.swingDepth));
      if(!isCounter) continue;
      if(sB<0) { sB=i; continue; }
      if(sA<0)
        {
         if(i-sB<s.swingDepth+2) continue;
         sA=i;
         break;
        }
     }
   if(sA<0 || sB<0)
     { why=(dir==BBRIDE_BUY?"Chua du 2 dinh de dung duong trend":"Chua du 2 day de dung duong trend"); return(false); }

   double vA=(dir==BBRIDE_BUY ? iHigh(sym,tf,sA) : iLow(sym,tf,sA));   // cu hon
   double vB=(dir==BBRIDE_BUY ? iHigh(sym,tf,sB) : iLow(sym,tf,sB));   // moi hon

   //--- duong trend phai doc NGUOC chieu vao lenh (nhip hoi dang yeu dan)
   if(dir==BBRIDE_BUY && vB>=vA) { why="Duong trend khong giam - nhip hoi chua yeu"; return(false); }
   if(dir==BBRIDE_SELL && vB<=vA){ why="Duong trend khong tang - nhip hoi chua yeu"; return(false); }

   int bars=sA-sB;
   if(bars<=0) { why="Hai diem neo duong trend khong hop le"; return(false); }

   //--- do doc tren moi nen, tinh theo chieu thoi gian tien ve hien tai
   double slope=(vB-vA)/bars;

   //--- chieu duong trend tai nen vua dong (shift 1) va nen truoc do (shift 2)
   double lineAt1=vB+slope*(sB-1);
   double lineAt2=vB+slope*(sB-2);

   double cl1=iClose(sym,tf,1);
   double cl2=iClose(sym,tf,2);
   int    digits=(int)MarketInfo(sym,MODE_DIGITS);

   if(dir==BBRIDE_BUY)
     {
      if(cl1<=lineAt1) { why="Chua VUOT LEN duong trend "+DoubleToString(lineAt1,digits); return(false); }
      if(cl2>lineAt2)  { why="Da vuot duong trend tu truoc - bo qua"; return(false); }
     }
   else
     {
      if(cl1>=lineAt1) { why="Chua XUYEN XUONG duong trend "+DoubleToString(lineAt1,digits); return(false); }
      if(cl2<lineAt2)  { why="Da xuyen duong trend tu truoc - bo qua"; return(false); }
     }

   lineAtSignal=lineAt1;
   t1=iTime(sym,tf,sA); p1=vA;
   t2=iTime(sym,tf,sB); p2=vB;
   why="OK";
   return(true);
  }

//+------------------------------------------------------------------+
//| TANG 4+5: M5/M1 - mo hinh 2 diem xoay + pha neckline             |
//|  BUY : 2 DAY TANG DAN, neckline = dinh giua, pha LEN             |
//|  SELL: 2 DINH GIAM DAN, neckline = day giua, pha XUONG           |
//+------------------------------------------------------------------+
bool BBRideSwingPattern(const string sym,const BBRideSettings &s,const int dir,const double pbZone,
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
   double zoneTol=MathMax(s.pbTouchATR*iATR(sym,s.tfPullback,14,1),3.0*atr);
   if(pbZone>0.0 && MathAbs(piv2-pbZone)>zoneTol)
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
   sig.trendLine=0; sig.tlTime1=0; sig.tlPrice1=0; sig.tlTime2=0; sig.tlPrice2=0;
   sig.okMonthly=false; sig.okWeekly=false; sig.okRoom=false;
   sig.okDailyRide=false; sig.okPullback=false; sig.okDoubleBottom=false;
   sig.okTrendBreak=false; sig.okTrigger=false;
   sig.roomATR=0; sig.dailyPB=0; sig.dailyRideCount=0; sig.pbZone=0; sig.note="";

   string dirName=BBRideDirName(dir);

   //--- TANG 1: khung lon
   sig.okMonthly = (!s.useMonthly) || BBRideTrendOK(sym,s.tfTrend1,s.mnFast,s.mnSlow,s.maMethod,dir);
   sig.okWeekly  = (!s.useWeekly)  || BBRideTrendOK(sym,s.tfTrend2,s.wFast, s.wSlow, s.maMethod,dir);
   if(!sig.okMonthly) { sig.note=dirName+": "+BBRideTFName(s.tfTrend1)+" chua xac nhan xu huong"; return; }
   if(!sig.okWeekly)  { sig.note=dirName+": "+BBRideTFName(s.tfTrend2)+" chua xac nhan xu huong";  return; }

   //--- TANG 1b: con du khong gian toi can gan nhat
   double level=0.0;
   sig.roomATR=BBRideRoomATR(sym,s.tfTrend2,s,dir,level);
   sig.okRoom=(sig.roomATR>=s.minRoomATR);
   if(!sig.okRoom)
     {
      sig.note=dirName+": gia da sat "+(dir==BBRIDE_BUY?"khang cu":"ho tro")+
               " "+BBRideTFName(s.tfTrend2)+" ("+DoubleToString(sig.roomATR,2)+" ATR)";
      return;
     }

   //--- TANG 2: D1 du day BB
   sig.okDailyRide=BBRideDailyRiding(sym,s,dir,sig.dailyRideCount,sig.dailyPB);
   if(!sig.okDailyRide)
     {
      sig.note=dirName+": "+BBRideTFName(s.tfRide)+" chua du day BB ("+
               IntegerToString(sig.dailyRideCount)+"/"+IntegerToString(s.dMinRideBars)+" nen)";
      return;
     }

   //--- TANG 3: H1 hoi ve vung trend thuan
   sig.okPullback=BBRidePullbackZone(sym,s,dir,sig.pbZone);
   if(!sig.okPullback)
     { sig.note=dirName+": "+BBRideTFName(s.tfPullback)+" chua hoi ve MA"+IntegerToString(s.pbMaPeriod)+"/BB giua"; return; }

   //--- TANG 4+5: mo hinh 2 diem xoay + pha neckline
   string why="";
   sig.okDoubleBottom=BBRideSwingPattern(sym,s,dir,sig.pbZone,sig.piv1,sig.piv2,sig.neckline,sig.signalBar,why);
   if(!sig.okDoubleBottom) { sig.note=dirName+": "+why; return; }

   //--- TANG 5b: vuot duong trend cua nhip hoi
   if(s.requireTrendBreak)
     {
      string whyTl="";
      sig.okTrendBreak=BBRideTrendLineBreak(sym,s,dir,sig.trendLine,
                                            sig.tlTime1,sig.tlPrice1,sig.tlTime2,sig.tlPrice2,whyTl);
      if(!sig.okTrendBreak) { sig.note=dirName+": "+whyTl; return; }
     }
   else
      sig.okTrendBreak=true;

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
   if(sig.okPullback)   n++;
   if(sig.okDoubleBottom) n++;
   if(sig.okTrendBreak)   n++;
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
   string tfChain=BBRideTFName(s.tfTrend1)+"+"+BBRideTFName(s.tfTrend2)+" > "+
                  BBRideTFName(s.tfRide)+" > "+BBRideTFName(s.tfPullback)+" > "+
                  BBRideTFName(s.entryTF);
   t+="=== BB RIDE MTF - "+sym+" | "+BBRideModeName(s.tradeMode)+" ===\n";
   t+="Bo khung: "+tfChain+"\n";
   t+="Dang xet chieu: "+dirName+"  ("+BBRideTFName(s.tfRide)+" du day dai "+
      (isBuy?"TREN":"DUOI")+" BB)\n";
   t+=BBRideTick(sig.okMonthly)     +"1. "+BBRideTFName(s.tfTrend1)+" xu huong "+(isBuy?"tang":"giam")+"\n";
   t+=BBRideTick(sig.okWeekly)      +"2. "+BBRideTFName(s.tfTrend2)+" xu huong "+(isBuy?"tang":"giam")+"\n";
   t+=BBRideTick(sig.okRoom)        +"3. Con khong gian toi "+(isBuy?"khang cu ":"ho tro ")+
                                     BBRideTFName(s.tfTrend2)+": "+DoubleToString(sig.roomATR,2)+" ATR\n";
   t+=BBRideTick(sig.okDailyRide)   +"4. "+BBRideTFName(s.tfRide)+" du day BB: "+
                                     IntegerToString(sig.dailyRideCount)+" nen, %B="+
                                     DoubleToString(sig.dailyPB,2)+"\n";
   t+=BBRideTick(sig.okPullback)    +"5. "+BBRideTFName(s.tfPullback)+" hoi ve vung "+
                                     DoubleToString(sig.pbZone,d)+"\n";
   t+=BBRideTick(sig.okDoubleBottom)+"6. "+(isBuy?"2 day tang dan":"2 dinh giam dan")+
                                     " ("+BBRideTFName(s.entryTF)+")\n";
   if(sig.piv1>0)
      t+="        "+(isBuy?"day1=":"dinh1=")+DoubleToString(sig.piv1,d)+
         "  "+(isBuy?"day2=":"dinh2=")+DoubleToString(sig.piv2,d)+
         "  neck="+DoubleToString(sig.neckline,d)+"\n";
   t+=BBRideTick(sig.okTrendBreak)  +"7. "+(isBuy?"Vuot LEN":"Xuyen XUONG")+" duong trend nhip hoi";
   if(sig.trendLine>0) t+=": "+DoubleToString(sig.trendLine,d);
   t+="\n";
   t+=BBRideTick(sig.valid)         +"8. TRIGGER\n";
   if(sig.valid)
      t+="        "+dirName+" "+DoubleToString(sig.entry,d)+"  SL "+DoubleToString(sig.sl,d)+
         "  TP "+DoubleToString(sig.tp,d)+"\n";
   t+="Trang thai: "+sig.note+"\n";
   return(t);
  }

#endif // __BBRIDE_CORE_MQH__
//+------------------------------------------------------------------+
