//+------------------------------------------------------------------+
//|                                  intrade_bar_console_bot_api.mqh |
//|                         Copyright 2019-2020, Yaroslav Barabanov. |
//|                                https://t.me/BinaryOptionsScience |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019-2020, Yaroslav Barabanov."
#property link      "https://t.me/BinaryOptionsScience"
#property strict

#include "named_pipe_client.mqh"
#include "hash.mqh"
#include "json.mqh"

class IntradeBarConsoleBotApi {
private:
   NamedPipeClient pipe;
   bool is_connected;
   bool is_broker_connected;
   bool is_broker_prev_connected;
   int tick;            // тики для подсчета времени отправки ping
   double balance;      // баланс
   double prev_balance; // предыдущий баланс
   
public:

   enum ENUM_BO_ORDER_TYPE {
   	BUY = 0,
   	SELL = 1,
   };
   
   enum ENUM_BO_TYPE {
   	CLASSICAL = 0,
   	SPRINT = 1,
   };

   IntradeBarConsoleBotApi() {
      pipe.set_buffer_size(2048);
      is_connected = false;
      is_broker_connected = false;
      is_broker_prev_connected = false;
      tick = 0;
      balance = 0;
      prev_balance = 0;
   }
   
   ~IntradeBarConsoleBotApi() {
      close();
   }
   
   bool connect(string api_pipe_name) {
      if(is_connected) return true;
      is_connected = pipe.open(api_pipe_name);
      return is_connected;
   }
   
   bool connected() {
      return is_connected;
   }
   
   bool open_deal(string symbol, int direction, datetime expiration, int type, double amount) {
      if(!is_connected) return false;
      if(direction != BUY && direction != SELL) return false;
      if(type != CLASSICAL && type != SPRINT) return false;
      string json_body;
      string str_direction = direction == BUY ? "BUY" : "SELL";
      json_body = StringConcatenate(json_body,"{\"contract\":{\"symbol\":\"",symbol,"\",\"direction\":\"",str_direction,"\",\"amount\":",amount,",");
      if(type == CLASSICAL) {
         if(expiration < 86400) expiration *= 60; // переводим время в секунды
         json_body = StringConcatenate(json_body,"\"date_expiry\":",(long)expiration);
      } else {
         expiration *= 60; // переводим время в секунды
         json_body = StringConcatenate(json_body,"\"duration\":",(long)expiration);
      }
      json_body = StringConcatenate(json_body,"}}");
      Print("json_body",json_body);
      if(pipe.write(json_body)) return true;
      close();
      return false;
   }
   
   bool open_deal(string symbol, string strategy_name, int direction, datetime expiration, int type, double amount) {
      if(!is_connected) return false;
      if(direction != BUY && direction != SELL) return false;
      if(type != CLASSICAL && type != SPRINT) return false;
      string json_body;
      string str_direction = direction == BUY ? "BUY" : "SELL";
      json_body = StringConcatenate(json_body,"{\"contract\":{\"symbol\":\"",symbol,"\",\"strategy_name\":\"",strategy_name,"\",\"direction\":\"",str_direction,"\",\"amount\":",amount,",");
      if(type == CLASSICAL) {
         if(expiration < 86400) expiration *= 60; // переводим время в секунды
         json_body = StringConcatenate(json_body,"\"date_expiry\":",(long)expiration);
      } else {
         expiration *= 60; // переводим время в секунды
         json_body = StringConcatenate(json_body,"\"duration\":",(long)expiration);
      }
      json_body = StringConcatenate(json_body,"}}");
      if(pipe.write(json_body)) return true;
      close();
      return false;
   }
   
   double get_balance() {
      return balance;
   }
   
   bool check_balance_change() {
      if(prev_balance != balance) {
         prev_balance = balance;
         return true;
      }
      return false;
   }
   
   bool check_broker_connection() {
      return is_broker_connected;
   } 
   
   bool check_broker_connection_change() {
      if(is_broker_prev_connected != is_broker_connected) {
         is_broker_prev_connected = is_broker_connected;
         return true;
      }
      return false;
   } 
   
   void update(int delay) {
      if(!is_connected) return;
      const int MAX_TICK = 10000;
      tick += delay;
      if(tick > MAX_TICK) {
         tick = 0;
         string json_body = "{\"ping\":1}";
         if(!pipe.write(json_body)) {
            close();
         }
      }
      if(pipe.get_bytes_read() > 0) {
         string body = pipe.read();
         //Print("body: ", body);
         
         /* парсим json сообщение */
         JSONParser *parser = new JSONParser();
         JSONValue *jv = parser.parse(body);
         if(jv == NULL) {
            Print("error:"+(string)parser.getErrorCode() + parser.getErrorMessage());
         } else {
            if(jv.isObject()) {
               JSONObject *jo = jv;
               double dtemp = 0;
               if(jo.getDouble("balance", dtemp)){
                  balance = dtemp;
                  //Print("balance: ", balance);
               }
               
               /* проверяем сообщение ping */
               int itemp = 0;
               if(jo.getInt("ping", itemp)){
                  //Print("ping: ",itemp);
                  string json_body = "{\"pong\":1}";
                  if(!pipe.write(json_body)) {
                     close();
                  }
               }
               
               /* проверяем состояние соединения */
               if(jo.getInt("connection", itemp)){
                  if(itemp == 1) is_broker_connected = true;
                  else is_broker_connected = false;
                  //Print("connection: ",itemp);
               }
            }
            delete jv;
         }
         delete parser;
      }
   }
   
   void close() {
      if(is_connected) pipe.close();
      is_connected = false;
      is_broker_connected = false;
      is_broker_prev_connected = false;
      tick = 0;
      balance = 0;
      prev_balance = 0;
   }
};

