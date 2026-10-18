//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version   "2.00"

//+------------------------------------------------------------------+
//| Diagnostic Logging and Notification Handler                      |
//+------------------------------------------------------------------+
class CLogger
{
private:
   string            m_eaName;
   bool              m_enableTerminalLog;
   bool              m_enableAlertPopup;
   bool              m_enablePushNotify;

public:
                     CLogger();
                    ~CLogger() {}

   void              Init(const string eaName,
                          const bool terminalLog = true,
                          const bool alertPopup = false,
                          const bool pushNotify = false);

   void              Info(const string message);
   void              Warn(const string message);
   void              Error(const string message);
   void              Signal(const string symbol, const string action, const double price, const double sl, const double tp, const string rationale);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLogger::CLogger() :
   m_eaName("MT5_EA"),
   m_enableTerminalLog(true),
   m_enableAlertPopup(false),
   m_enablePushNotify(false)
{
}

//+------------------------------------------------------------------+
//| Initialize Logger Settings                                       |
//+------------------------------------------------------------------+
void CLogger::Init(const string eaName,
                   const bool terminalLog,
                   const bool alertPopup,
                   const bool pushNotify)
{
   m_eaName            = eaName;
   m_enableTerminalLog = terminalLog;
   m_enableAlertPopup  = alertPopup;
   m_enablePushNotify  = pushNotify;
}

//+------------------------------------------------------------------+
//| Log Informational Message                                        |
//+------------------------------------------------------------------+
void CLogger::Info(const string message)
{
   if(m_enableTerminalLog)
      PrintFormat("[%s][INFO][%s] %s", m_eaName, TimeToString(TimeCurrent(), TIME_SECONDS), message);
}

//+------------------------------------------------------------------+
//| Log Warning Message                                              |
//+------------------------------------------------------------------+
void CLogger::Warn(const string message)
{
   if(m_enableTerminalLog)
      PrintFormat("[%s][WARN][%s] %s", m_eaName, TimeToString(TimeCurrent(), TIME_SECONDS), message);
      
   if(m_enableAlertPopup)
      Alert(StringFormat("[%s][WARN] %s", m_eaName, message));
}

//+------------------------------------------------------------------+
//| Log Error Message                                                |
//+------------------------------------------------------------------+
void CLogger::Error(const string message)
{
   PrintFormat("[%s][ERROR][%s] %s", m_eaName, TimeToString(TimeCurrent(), TIME_SECONDS), message);
   
   if(m_enableAlertPopup)
      Alert(StringFormat("[%s][ERROR] %s", m_eaName, message));
}

//+------------------------------------------------------------------+
//| Dispatch Strategy Signal Event                                   |
//+------------------------------------------------------------------+
void CLogger::Signal(const string symbol, const string action, const double price, const double sl, const double tp, const string rationale)
{
   string formatted = StringFormat("[%s] SIGNAL on %s: %s @ %.5f | SL: %.5f | TP: %.5f | Rationale: %s",
                                   m_eaName, symbol, action, price, sl, tp, rationale);
                                   
   Print(formatted);
   
   if(m_enableAlertPopup)
      Alert(formatted);
      
   if(m_enablePushNotify)
      SendNotification(formatted);
}
