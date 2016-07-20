//+------------------------------------------------------------------+
//|                                                    MySQL-001.mq4 |
//|                                   Copyright 2014, Eugene Lugovoy |
//|                                        http://www.fxcodexlab.com |
//| Test connections to MySQL. Reaching limit (DEMO)                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Eugene Lugovoy"
#property link      "http://www.fxcodexlab.com"
#property version   "1.00"
#property strict
#include <MQLMySQL.mqh>
#include <Arrays\ArrayString.mqh>
string INI;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+

int DB; // database identifiers
int user_id,Cursor = -10,Rows;
string platname;
string Query,account_number = IntegerToString(AccountNumber());

void init()
{
   
    string Host, User, Password, Database, Socket; // database credentials
    int Port,ClientFlag;
    Print (MySqlVersion());
   
    // reading database credentials from INI file
    Host = "wecapital.gotoftp11.com";
    User = "wecapital";
    Password = "wewant2016";
    Database = "wecapital";
    Port     = 3306;
    Socket   = 0;
    ClientFlag = 0;  
    Print ("Host: ",Host, ", User: ", User, ", Database: ",Database);
    Print ("Connecting...");
    
    DB = MySqlConnect(Host, User, Password, Database, Port, Socket, ClientFlag);
    
    if (DB == -1) { 
      Print ("Connection failed! Error: "+MySqlErrorDescription);
      return ;
    } else { 
      Print ("Connected! DBID#",DB);
    }
    Query = "SELECT user_id,platname FROM `oc_account` where acc_no = '"+ account_number +"' order by id desc limit 1";
    Cursor = MySqlCursorOpen(DB, Query);
    if (Cursor >= 0) 
    {
      Rows = MySqlCursorFetchRow(Cursor);
      if(Rows > 0)
      {
         user_id = MySqlGetFieldAsInt(Cursor, 0);
         platname = MySqlGetFieldAsString(Cursor, 1);
      }
      
    }
}



int htsTotal;
void start()
{  
   CArrayString *arr=new CArrayString; 
   CArrayString *arrAmount=new CArrayString; 
   
   if(DB == -1 && user_id == 0)
   {
      Print("not user "); return;
   }
   int i,time0,id,index;
   int historyTotal = OrdersHistoryTotal();
   string c_day;
   string c_res[];
   string strplit[2];
   double withdraw,deposit;
   string sep=","; 
   ushort u_sep = StringGetCharacter(sep,0);
   
   if(htsTotal < historyTotal)
   {  
      string r_content;
      double amount = 0,amount0 = 0;
      for(int cpt = 0;cpt<OrdersHistoryTotal();cpt++)
      {
         if(OrderSelect(cpt,SELECT_BY_POS,MODE_HISTORY))
         {
            if(OrderOpenTime() > 0)
            {
               time0 = OrderOpenTime();
            }
            
            if(OrderType() == OP_SELL || OrderType() == OP_BUY )
            {
               amount += OrderProfit() + OrderCommission() + OrderSwap();
               amount0 = OrderProfit() + OrderCommission() + OrderSwap();
               time0 = OrderCloseTime();
               c_day = TimeToString(time0,TIME_DATE);
               c_day = StringSubstr(c_day, 0, 4)+"-"+StringSubstr(c_day,5,2)+"-"+StringSubstr(c_day, 8, 2);
               Cursor = -10;
               
               //index = array_search(arr , c_day);
               index = -1;
               for(i=0;i<arr.Total();i++) 
               {
                  if( StringSubstr(arr[i],0,10) == c_day )
                  {
                     index = i;
                  }
               }
               
               if(index > -1)
               {
                  StringSplit(arr[index],u_sep,strplit);
                  arr.Update(index,strplit[0] + "," + DoubleToStr(StrToDouble(strplit[1]) + amount0,2));
                  //Print(arr[index]);
               }else{
                  arr.Add(c_day + "," + DoubleToStr(amount0,2));
                  //i++;
               }
               
               
               //continue;
            }
            
            if(OrderType() == 6 && OrderProfit() <0)
            {
               withdraw += OrderProfit();
            }
            
            if(OrderType() == 6 && OrderProfit() >=0)
            {
               deposit += OrderProfit();
            }
            
            htsTotal ++ ;
            //Sleep(100);
         }
      }
      arr.Sort();
      //ArraySort(arr);
      Print("Data inited");
      amount = 0;
      int arrTime;
      for(int i=0;i<arr.Total();i++)
      {
         StringSplit(arr[i],u_sep,strplit);
         amount += StrToDouble(strplit[1]);
         Query = "SELECT id,time FROM `oc_account_log` where acc_no = '"+ account_number +"' and time = '"+ strplit[0] +"' order by time desc";
         Cursor = MySqlCursorOpen(DB, Query);
         Rows = MySqlCursorFetchRow(Cursor);
         if (Rows > 0) 
         {
            id = MySqlGetFieldAsInt(Cursor, 0);
            c_day = StringSubstr(strplit[0], 0, 4)+"."+StringSubstr(strplit[0],5,2)+"."+StringSubstr(strplit[0], 8, 2);
            arrTime = StrToTime(c_day);
            if(arrTime + 3600*24*3 > TimeCurrent() || true)
            {
               Query = "UPDATE `oc_account_log` SET amount = '"+amount+"' where id = "+id;
               if (MySqlExecute(DB, Query))
               {
                  Print ("UPDATE: ", Query);
               }
            }
            
         }else{
            Query = "INSERT INTO `oc_account_log` (user_id,platname,acc_no,time,amount) VALUES ("+ user_id +",\'"+platname+"\',"+account_number+",'"+strplit[0]+"',"+amount+");";
            if (MySqlExecute(DB, Query))
            {
               Print ("INSERT: ", Query);
            }
         }
         MySqlCursorClose(Cursor);
      } 
      

      withdraw = MathAbs(withdraw);
      Query = "UPDATE `oc_account` SET amount = '"+deposit+"', withdraw = '"+withdraw+"' where  acc_no = '"+account_number+"'";
      if (MySqlExecute(DB, Query))
      {
         //Print ("Succeeded: ", Query);
      }
   }
   delete arr;
   delete arrAmount;
   
 
}

void deinit()
{

   MySqlDisconnect(DB);
   Print ("All connections closed. Script done!");
}