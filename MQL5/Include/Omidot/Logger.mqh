#ifndef OMIDOT_LOGGER_MQH
#define OMIDOT_LOGGER_MQH

string FormatLogLine(string timestampText, string category, string message)
  {
   return timestampText + "," + category + "," + message;
  }

void LogEvent(string fileName, string timestampText, string category, string message)
  {
   int handle = FileOpen(fileName, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return;

   FileSeek(handle, 0, SEEK_END);
   FileWriteString(handle, FormatLogLine(timestampText, category, message) + "\r\n");
   FileClose(handle);
  }

#endif
