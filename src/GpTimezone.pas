{:      Primoz Gabrijelcic's Time Zone Routines v1.21b<p>

        Date/Time Routines to enhance your 32-bit Delphi Programming. <p>

        (c) 2008 Primoz Gabrijelcic<p>

        =================================================== <p>
        These routines are used by ESB Consultancy and Primoz Gabrijelcic
        within the development of their Customised Application. <p>
        Primoz Gabrijelcic retains full copyright. <p>
        mailto:gabr@17slon.com
        http://gp.17slon.com/gp/

        We do ask that if this code helps you in you development
        that you send as an email mailto:info@esbconsult.com.au or even
        a local postcard. It would also be nice if you gave us a
        mention in your About Box, Help File or Documentation. <p>

        ESB Consultancy Home Page: http://www.esbconsult.com.au <p>

        Mail Address: PO Box 2259, Boulder, WA 6432 AUSTRALIA <p>

        See TestUTC for the Demo Program. (Note form may encounter minor
        errors when opened with older versions of Delphi, simply ignore
        them and all should be fine.)

<pre>
This software is distributed under the BSD license.

Copyright (c) 2008, Primoz Gabrijelcic
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
- Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
- The name of the Primoz Gabrijelcic may not be used to endorse or promote
  products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
</pre>
        History:
        <pre>
        1.22: 2008-02-27
          - Implemented DateLT, DateLE, DateGT, DateGE.
        1.21b: 2004-11-05
          - Modified UTCTo[TZ]LocalTime/[TZ]LocalTimeToUTC functions to automatically
            execute FixDT on the result.
        1.21a: 2001-09-09
          - Removed conditional (Delphi 2) 'type longint = integer;' and
            replaced all longints with integers.
        1.21: 2000-09-06
          - Delphi 2 is missing SystemTimeToDateTime function so I conditionally
            added it to this unit. Also conditionally added (for Delphi 2 only)
            'type longint = integer;' and disabled PutTZToRegistry.
        1.2: 2000-10-18
          - String constant moved to resourcestring (D3 and newer) / const
            (D2) section.
          - Evaluation of "absolute date" format in
            GetTZDaylightSavingInfoForYear and DSTDate2Date has changed. Those
            two functions will return error (first 'false' and second '0') if
            they are called with "absolute date" format time zone info and a
            year which is not equal to the year in time zone info.
        1.1b: 2000-05-26
          - Fixed another memory leak (a small one) in
            TGpRegistryTimeZones.Clear.
        1.1a: 2000-05-18
          - Fixed memory leak in TGpRegistryTimeZones.Clear (thanks to Adrian
            Gallero who found it)
        1.1: 2000-02-11
          - New class TGpRegistryTimeZones that allows read/write access to
            timezone information in registry.
          - GetTZCount and GetTZ are deprecated. Please use
            TGpRegistryTimeZones.
          - New function TimeZoneRegKey.
        1.0.2: 2000-01-12
          - Modified FixDT to return input parameter if it does not represent a
            valid date.
        1.0.1: 1999-10-22
          - Function GetTZ was not working with Delphi 3. Fixed.
          - Fixed rounding problems in UTCToSwatch and SwatchToUTC.
          - Added function FixDT.
        1.0: 1999-10-18
          - First official release.
        </pre>
}

unit GpTimezone;

interface

uses
  Windows,
  Classes;

const
  MINUTESPERDAY = 1440;

type
  TSwatchBeat = 0..999;

{$IFDEF VER90} //Delphi 2 incorrectly defines integer as unsigned.
  integer = longint;
{$ENDIF VER90}

  TGpRegistryTimeZones = class;

  {: Encapsulates information about one timezone as stored in registry.
     Modifying class properties may fail if write access to the registry
     (HKEY_LOCAL_MACHINE + TimeZoneRegKey) is not allowed. In that property
     Modified will return false but no exception will occur. }
  TGpRegistryTimeZone = class
  private
    rtzDisplayName: string;
    rtzEnglishName: string;
    rtzModified   : boolean;
    rtzOwner      : TGpRegistryTimeZones;
    rtzRegistryKey: string;
    rtzTimeZone   : TTimeZoneInformation;
    function  GetWriteAccess: boolean;
    procedure SetDisplayName(const Value: string);
    procedure SetEnglishName(const Value: string);
    procedure SetTimeZone(const Value: TTimeZoneInformation);
    procedure SetWriteAccess(const Value: boolean);
  protected
    procedure SetOwner(AOwner: TGpRegistryTimeZones);
    property RegistryKey: string read rtzRegistryKey write rtzRegistryKey;
  public
    property DisplayName: string read rtzDisplayName write SetDisplayName;
    property EnglishName: string read rtzEnglishName write SetEnglishName;
    property Modified: boolean read rtzModified;
    property TimeZone: TTimeZoneInformation read rtzTimeZone write SetTimeZone;
    property WriteAccess: boolean read GetWriteAccess write SetWriteAccess;
  end; { TGpRegistryTimeZone }

  {: Encapsulates TimeZone information stored in registry. Allows read/write
     access, addition and deletion of timezones. Use with care.
     In fact, all modifications will trigger exception unless you set
     'WriteAccess := true'. I just want to prevent you from accidentally
     deleting half of your timezone settings (ouch!). }
  TGpRegistryTimeZones = class
  private
    rtzList      : TList;
    rtzFullAccess: boolean;
    function  GetItem(idx: integer): TGpRegistryTimeZone;
    procedure Clear;
  protected
    procedure CheckForWriteAccess;
    function  Update(rtz: TGpRegistryTimeZone): boolean;
  public
    constructor Create;
    destructor  Destroy; override;
    function  Add(regTimeZone: TGpRegistryTimeZone): boolean;
    function  Count: integer;
    function  Delete(regTimeZone: TGpRegistryTimeZone): boolean;
    procedure Reload;
    property  Items[idx: integer]: TGpRegistryTimeZone read GetItem; default;
    property  WriteAccess: boolean read rtzFullAccess write rtzFullAccess;
  end; { TGpRegistryTimeZones }

  {: Date comparison functions that treat dates with less than 1/10 ms of difference as
     equal.
  }
  function DateEQ(date1, date2: TDateTime): boolean;
  function DateLT(date1, date2: TDateTime): boolean;
  function DateLE(date1, date2: TDateTime): boolean;
  function DateGT(date1, date2: TDateTime): boolean;
  function DateGE(date1, date2: TDateTime): boolean;

  {: Corrects date part so it will represent exact (as possible) millisecond,
     not maybe small part before or after that. Useful when you want to use
     Trunc/Int and Frac functions to get date or time part from TDateTime
     variable.<br>
     Example: FixDT(36463.99999999999) will return 36464.<br>
     See function UTCToSwatch for another example.
  }
  function FixDT(date: TDateTime): TDateTime;

  {: Converts 'day of month' syntax to normal date. Set year and month to
     required values, set weekInMonth to required week (1-4, or 5 for last),
     set dayInWeek to required day of week (1 (Sunday) to 7 (Saturday) - Delphi
     style).<br>
     Example: To get last Sunday in Dec 1999 call DayOfMonth2Date(1999,12,5,0).}
  function DayOfMonth2Date(year,month,weekInMonth,dayInWeek: word): TDateTime;

  {: Converts TIME_ZONE_INFORMATION date to normal date. Time zone information
     can be returned in two formats by Windows API call GetTimeZoneInformation.
     Absolute format specifies an exact date and time when standard/DS time
     begins. In this form, the wYear, wMonth, wDay, wHour, wMinute , wSecond,
     and wMilliseconds members of the TSystemTime structure are used to specify
     an exact date. Year is left intact, if you want to change it, call
     ESBDates.AdjustDateYear (warning: this will clear the time part).
     Day-in-month format is specified by setting the wYear member to zero,
     setting the wDayOfWeek member to an appropriate weekday (0 to 6,
     0 = Sunday), and using a wDay value in the range 1 through 5 to select the
     correct day in the month. Year parameter is used to specify year for this
     date.
     Returns 0 if 'dstDate' is invalid or if it specifies "absolute date" for a
     year not equal to 'year' parameter. }
  function DSTDate2Date(dstDate: TSystemTime; year: word): TDateTime;

  {: Returns daylight saving information for a specified time zone and year.
     Sets DaylightDate and StandardDate year to specified year if date is
     specified in day-in-month format (see above).<br>
     DaylightDate and StandardDate are returned in local time. To convert them
     to UTC use DaylightDate+StandardBias/MINUTESPERDAY and
     StandardDate+DaylightBias/MINUTESPERDAY.<br>
     Returns false if 'TZ' is invalid or if it specifies "absolute date" for a
     year not equal to 'year' parameter. }
  function GetTZDaylightSavingInfoForYear (
    TZ: TTimeZoneInformation; year: word;
    var DaylightDate, StandardDate: TDateTime;
    var DaylightBias, StandardBias: integer): boolean;

  {: Returns daylight saving information for a specified time zone and current
     year. See GetTZDaylightSavingInfoForYear for more information. }
  function GetTZDaylightSavingInfo (TZ: TTimeZoneInformation;
    var DaylightDate, StandardDate: TDateTime;
    var DaylightBias, StandardBias: integer): boolean;

  {: Returns daylight saving information for current time zone and specified
     year. See GetTZDaylightSavingInfoForYear for more information. }
  function GetDaylightSavingInfoForYear (year: word;
    var DaylightDate, StandardDate: TDateTime;
    var DaylightBias, StandardBias: integer): boolean;

  {: Returns daylight saving information for current time zone and year. See
     GetTZDaylightSavingInfoForYear for more information. }
  function GetDaylightSavingInfo (var DaylightDate, StandardDate: TDateTime;
    var DaylightBias, StandardBias: integer): boolean;

  {: Converts local time to UTC according to a given timezone rules. Takes into
     account daylight saving time as it was active at that time. This is not
     very safe as DST rules are always changing.<br>
     Special processing is done for the times during the standard/daylight time
     switch.
     If the specified local time lies in the non-existing area (when clock is
     moved forward), function returns 0.
     If the specified local time lies in the ambigious area (when clock is moved
     backward), function takes into account value of preferDST parameter. If it
     is set to true, time is converted as if it belongs to the daylight time. If
     it is set to false, time is converted as if it belong to the standard time.
  }
  function TZLocalTimeToUTC(TZ: TTimeZoneInformation; loctime: TDateTime;
    preferDST: boolean): TDateTime;

  {: Converts local time to UTC according to a given timezone rules. Takes into
     account daylight saving time as it was active at that time. This is not
     very safe as DST rules are always changing.<br>
     In Windows NT/2000 (but not in 95/98) you can use API function
     SystemTimeToTzSpecificLocalTime instead. }
  function UTCToTZLocalTime(TZ: TTimeZoneInformation; utctime: TDateTime): TDateTime;

  {: Converts local time to UTC according to a current time zone. See
     TzLocalTimeToUTC for more information. }
  function LocalTimeToUTC(loctime: TDateTime; preferDST: boolean): TDateTime;

  {: Converts UTC time to local time according to a current time zone. See
     UTCToTZLocalTime for more information. }
  function UTCToLocalTime(utctime: TDateTime): TDateTime;

  {: Returns number of all defined time zones.
     @Deprecated Replaced with TGpRegistryTimeZones. }
  function GetTZCount: integer;

  {: Returns data for idx-th (0..GetTZCount-1) time zone in TZ parameter.
     Returns false if time zone does not exist.
     @Deprecated Replaced with TGpRegistryTimeZones. }
  function GetTZ(idx: integer; var EnglishName, displayName: string; var TZ: TTimeZoneInformation): boolean;

  {: Returns current bias (in minutes) for a given time zone. }
  function GetTZBias(TZ: TTimeZoneInformation): integer;

  {: Returns current bias (in minutes) and UTC datetime for a given timezone. }
  procedure GetTZNowUTCAndBias(TZ: TTimeZoneInformation; var nowUTC: TDateTime; var nowBias: integer);

  {: Returns current bias (in minutes) and UTC datetime. }
  procedure GetNowUTCAndBias(var nowUTC: TDateTime; var nowBias: integer);

  {: Returns current UTC date and time. }
  function NowUTC: TDateTime;

  {: Returns current UTC time. }
  function TimeUTC: TDateTime;

  {: Returns current UTC date. }
  function DateUTC: TDateTime;
  
  {: Compares two TSystemTime records. Returns -1 if st1 < st2, 1 is st1 > st2,
     and 0 if st1 = st2. }
  function CompareSysTime(st1, st2: TSystemTime): integer;

  {: Compares two TTimeZoneInformation records. }
  function IsEqualTZ(tz1, tz2: TTimeZoneInformation): boolean;

  {: Converts UTC time to Swatch Internet Time. Date part is returned as
     'internetDate' and beats part is returned as function result. } 
  function UTCToSwatch(utctime: TDateTime; var internetDate: TDateTime): TSwatchBeat;

  {: Converts Swatch Internet Time to UTC time. }
  function SwatchToUTC(internetDate: TDateTime; internetBeats: TSwatchBeat): TDateTime;

  {: Returns base key (relative to HKEY_LOCAL_MACHINE) for timezone settings. }
  function TimeZoneRegKey: string;

implementation

uses
  SysUtils,
  Registry,
  ESBDates;

var
  G_RegistryTZ: TGpRegistryTimeZones; // used in GetTZCount, GetTZ

{$UNDEF NeedBetterRegistry}       //There is no OpenKeyReadonly in Delphi 2 and 3.
{$UNDEF NoResourcestring}         //There is no resourcestring in Delphi 2.
{$UNDEF NeedSystemTimeToDateTime} //There is no SystemTimeToDateTime in Delphi 2.
{$IFDEF VER90}
  {$DEFINE NeedBetterRegistry}
  {$DEFINE NoResourcestring}
  {$DEFINE NeedSystemTimeToDateTime}
{$ENDIF}
{$IFDEF VER100}
  {$DEFINE NeedBetterRegistry}
{$ENDIF VER100}

{$IFDEF NoResourcestring}
const
{$ELSE}
resourcestring
{$ENDIF}
  sTGpRegistryTimeZonesWriteAccessNot = 'TGpRegistryTimeZones: WriteAccess not set.';

type
  TBetterRegistry = class(TRegistry)
  {$IFDEF NeedBetterRegistry}
    function OpenKeyReadOnly(const Key: string): Boolean;
  {$ENDIF NeedBetterRegistry}
  end;

{ TBetterRegistry }

{$IFDEF NeedBetterRegistry}
  function IsRelative(const Value: string): boolean;
  begin
    Result := not ((Value <> '') and (Value[1] = '\'));
  end;

  function TBetterRegistry.OpenKeyReadOnly(const Key: string): boolean;
  var
    TempKey : HKey;
    S       : string;
    Relative: boolean;
  begin
    S := Key;
    Relative := IsRelative(S);
    if not Relative then
      Delete(S, 1, 1);
    TempKey := 0;
    Result := RegOpenKeyEx(GetBaseKey(Relative), PChar(S), 0,
        KEY_READ, TempKey) = ERROR_SUCCESS;
    if Result then begin
      if (CurrentKey <> 0) and Relative then
        S := CurrentPath + '\' + S;
      ChangeKey(TempKey, S);
    end;
  end; { TBetterRegistry.OpenKeyReadOnly }
{$ENDIF NeedBetterRegistry}

{ /TBetterRegistry }

{$IFDEF NeedSystemTimeToDateTime}
function SystemTimeToDateTime(const SystemTime: TSystemTime): TDateTime;
begin
  with SystemTime do
  begin
    Result := EncodeDate(wYear, wMonth, wDay);
    if Result >= 0 then
      Result := Result + EncodeTime(wHour, wMinute, wSecond, wMilliSeconds)
    else
      Result := Result - EncodeTime(wHour, wMinute, wSecond, wMilliSeconds);
  end;
end;
{$ENDIF NeedSystemTimeToDateTime}

  function DateEQ(date1, date2: TDateTime): boolean;
  begin
    Result := (Abs(date1-date2) < 1/(10*MSecsPerDay));
  end; { DateEQ }

  function DateLT(date1, date2: TDateTime): boolean;
  begin
    Result := (date1 + 1/(10*MSecsPerDay)) < date2;
  end; { DateLT }

  function DateLE(date1, date2: TDateTime): boolean;
  begin
    Result := DateLT(date1, date2) or DateEQ(date1, date2);
  end; { DateLE }

  function DateGT(date1, date2: TDateTime): boolean;
  begin
    Result := (date1 - 1/(10*MSecsPerDay)) > date2;
  end; { DateGT }

  function DateGE(date1, date2: TDateTime): boolean;
  begin
    Result := DateGT(date1, date2) or DateEQ(date1, date2);
  end; { DateGE }

  function FixDT(date: TDateTime): TDateTime;
  var
    ye,mo,da,ho,mi,se,ms: word;
  begin
    try
      DecodeDate(date,ye,mo,da);
      DecodeTime(date,ho,mi,se,ms);
      Result := EncodeDate(ye,mo,da)+EncodeTime(ho,mi,se,ms);
    except
      on E: EConvertError do Result := date;
      else raise;
    end; 
  end; { FixDT }

  function DayOfMonth2Date(year,month,weekInMonth,dayInWeek: word): TDateTime;
  var
    days: integer;
    day : integer;
  begin
    if (weekInMonth >= 1) and (weekInMonth <= 4) then begin
      day := DayOfWeek(EncodeDate(year,month,1));      // get first day in month
      day := 1 + dayInWeek-day;                  // get first dayInWeek in month
      if day <= 0 then
        Inc(day,7);
      day := day + 7*(weekInMonth-1);   // get weekInMonth-th dayInWeek in month
      Result := EncodeDate(year,month,day);
    end
    else if weekInMonth = 5 then begin // last week, calculate from end of month
      days := DaysInMonth(EncodeDate(year,month,1));
      day  := DayOfWeek(EncodeDate(year,month,days));   // get last day in month
      day  := days + (dayInWeek-day);
      if day > days then
        Dec(day,7);                               // get last dayInWeek in month
      Result := EncodeDate(year,month,day);
    end
    else
      Result := 0;
  end; { DayOfMonth2Date }

  function DSTDate2Date(dstDate: TSystemTime; year: word): TDateTime;
  begin
    if dstDate.wMonth = 0 then
      Result := 0                                // invalid month => no DST info
    else if dstDate.wYear = 0 then begin                // day-of-month notation
      Result :=
        DayOfMonth2Date(year,dstDate.wMonth,dstDate.wDay,dstDate.wDayOfWeek+1{convert to Delphi Style}) +
        EncodeTime(dstDate.wHour,dstDate.wMinute,dstDate.wSecond,dstDate.wMilliseconds);
    end
    else if dstDate.wYear = year then // absolute format - valid only for specified year
      Result := SystemTimeToDateTime(dstDate)
    else
      Result := 0;
  end; { DSTDate2Date }

  function GetTZDaylightSavingInfoForYear(
    TZ: TTimeZoneInformation; year: word;
    var DaylightDate, StandardDate: TDateTime;
    var DaylightBias, StandardBias: integer): boolean;
  begin
    Result := false;
    if (TZ.DaylightDate.wMonth <> 0) and
       (TZ.StandardDate.wMonth <> 0) then
    begin
      DaylightDate := DSTDate2Date(TZ.DaylightDate,year);
      StandardDate := DSTDate2Date(TZ.StandardDate,year);
      DaylightBias := TZ.Bias+TZ.DaylightBias;
      StandardBias := TZ.Bias+TZ.StandardBias;
      Result := (DaylightDate <> 0) and (StandardDate <> 0);
    end;
  end; { GetTZDaylightSavingInfoForYear }

  function GetTZDaylightSavingInfo(TZ: TTimeZoneInformation;
    var DaylightDate, StandardDate: TDateTime;
    var DaylightBias, StandardBias: integer): boolean;
  begin
    Result := GetTZDaylightSavingInfoForYear(TZ,ThisYear,DaylightDate,StandardDate,DaylightBias,StandardBias);
  end; { GetTZDaylightSavingInfo }

  function GetDaylightSavingInfoForYear(year: word;
    var DaylightDate, StandardDate: TDateTime;
    var DaylightBias, StandardBias: integer): boolean;
  var
    TZ: TTimeZoneInformation;
  begin
    GetTimeZoneInformation (TZ);
    Result := GetTZDaylightSavingInfoForYear(TZ,year,DaylightDate,StandardDate,StandardBias,DaylightBias);
  end; { GetDaylightSavingInfoForYear }

  function GetDaylightSavingInfo(var DaylightDate, StandardDate: TDateTime;
    var DaylightBias, StandardBias: integer): boolean;
  var
    TZ: TTimeZoneInformation;
  begin
    GetTimeZoneInformation (TZ);
    Result := GetTZDaylightSavingInfo(TZ,DaylightDate,StandardDate,StandardBias,DaylightBias);
  end; { GetDaylightSavingInfo }

  function TZLocalTimeToUTC(TZ: TTimeZoneInformation; loctime: TDateTime;
    preferDST: boolean): TDateTime;

    function Convert(startDate, endDate, startOverl, endOverl: TDateTime;
      startInval, endInval: TDateTime; inBias, outBias, overlBias: integer): TDateTime;
    begin
      if ((locTime > startOverl) or DateEQ(locTime,startOverl)) and (locTime < endOverl) then
        Result := loctime + overlBias/MINUTESPERDAY
      else if ((locTime > startInval) or DateEQ(locTime,startInval)) and (locTime < endInval) then
        Result := 0
      else if ((locTime > startDate) or DateEQ(locTime,startDate)) and (locTime < endDate) then
        Result := loctime + inBias/MINUTESPERDAY
      else
        Result := loctime + outBias/MINUTESPERDAY;
    end; { Convert }

  var
    dltBias : real;
    overBias: integer;
    stdBias : integer;
    dayBias : integer;
    stdDate : TDateTime;
    dayDate : TDateTime;
  begin { TZLocalTimeToUTC }
    if GetTZDaylightSavingInfoForYear(TZ, Date2Year(loctime), dayDate, stdDate, dayBias, stdBias) then begin
      if preferDST then
        overBias := dayBias
      else
        overBias := stdBias;
      dltBias := (stdBias-dayBias)/MINUTESPERDAY;
      if dayDate < stdDate then begin // northern hemisphere
        if dayBias < stdBias then // overlap at stdDate
          Result := Convert(dayDate, stdDate, stdDate-dltBias, stdDate,
            dayDate, dayDate+dltBias, dayBias, stdBias, overBias)
        else // overlap at dayDate - that actually never happens
          Result := Convert(dayDate, stdDate, dayDate+dltBias, dayDate,
            stdDate, stdDate-dltBias, dayBias, stdBias, overBias);
      end
      else begin // southern hemisphere
        if dayBias < stdBias then // overlap at stdDate
          Result := Convert(stdDate, dayDate, stdDate-dltBias, stdDate,
            dayDate, dayDate+dltBias, stdBias, dayBias, overBias)
        else // overlap at dayDate - that actually never happens
          Result := Convert(stdDate, dayDate, dayDate+dltBias, dayDate,
            stdDate, stdDate-dltBias, stdBias, dayBias, overBias);
      end;
    end
    else
      Result := loctime + TZ.bias/MINUTESPERDAY; // TZ does not use DST
    Result := FixDT(Result);
  end; { TZLocalTimeToUTC }

  function UTCToTZLocalTime(TZ: TTimeZoneInformation; utctime: TDateTime): TDateTime;

    function Convert(startDate, endDate: TDateTime; inBias, outBias: integer): TDateTime;
    begin
      if ((utctime > startDate) or DateEQ(utctime,startDate)) and (utctime < endDate) then
        Result := utctime - inBias/MINUTESPERDAY
      else
        Result := utctime - outBias/MINUTESPERDAY;
    end; { Convert }

  var
    stdUTC : TDateTime;
    dayUTC : TDateTime;
    stdBias: integer;
    dayBias: integer;
    stdDate: TDateTime;
    dayDate: TDateTime;
    
  begin { UTCToTZLocalTime }
    if GetTZDaylightSavingInfoForYear(TZ, Date2Year(utctime), dayDate, stdDate, dayBias, stdBias) then begin
      dayUTC := dayDate + stdBias/MINUTESPERDAY;
      stdUTC := stdDate + dayBias/MINUTESPERDAY;
      if dayUTC < stdUTC then
        Result := Convert(dayUTC,stdUTC,dayBias,stdBias)  // northern hem.
      else
        Result := Convert(stdUTC,dayUTC,stdBias,dayBias); // southern hem.
    end
    else
      Result := utctime - TZ.bias/MINUTESPERDAY; // TZ does not use DST
    Result := FixDT(Result);
  end; { UTCToTZLocalTime }

  function LocalTimeToUTC(loctime: TDateTime; preferDST: boolean): TDateTime;
  var
    TZ: TTimeZoneInformation;
  begin
    GetTimeZoneInformation (TZ);
    Result := TZLocalTimeToUTC(TZ,loctime,preferDST);
  end; { LocalTimeToUTC }

  function UTCToLocalTime(utctime: TDateTime): TDateTime;
  var
    TZ: TTimeZoneInformation;
  begin
    GetTimeZoneInformation (TZ);
    Result := UTCToTZLocalTime(TZ,utctime);
  end; { UTCToLocalTime }

  function CompareSysTime(st1, st2: TSystemTime): integer;
  begin
    if st1.wYear < st2.wYear then
      Result := -1
    else if st1.wYear > st2.wYear then
      Result := 1
    else if st1.wMonth < st2.wMonth then
      Result := -1
    else if st1.wMonth > st2.wMonth then
      Result := 1
    else if st1.wDayOfWeek < st2.wDayOfWeek then
      Result := -1
    else if st1.wDayOfWeek > st2.wDayOfWeek then
      Result := 1
    else if st1.wDay < st2.wDay then
      Result := -1
    else if st1.wDay > st2.wDay then
      Result := 1
    else if st1.wHour < st2.wHour then
      Result := -1
    else if st1.wHour > st2.wHour then
      Result := 1
    else if st1.wMinute < st2.wMinute then
      Result := -1
    else if st1.wMinute > st2.wMinute then
      Result := 1
    else if st1.wSecond < st2.wSecond then
      Result := -1
    else if st1.wSecond > st2.wSecond then
      Result := 1
    else if st1.wMilliseconds < st2.wMilliseconds then
      Result := -1
    else if st1.wMilliseconds > st2.wMilliseconds then
      Result := 1
    else
      Result := 0;
  end; { CompareSysTime }
  
  function IsEqualTZ(tz1, tz2: TTimeZoneInformation): boolean;
  begin
    Result :=
      (tz1.Bias         = tz2.Bias)         and
      (tz1.StandardBias = tz2.StandardBias) and
      (tz1.DaylightBias = tz2.DaylightBias) and
      (CompareSysTime(tz1.StandardDate,tz2.StandardDate) = 0) and
      (CompareSysTime(tz1.DaylightDate,tz2.DaylightDate) = 0) and
      (WideCharToString(tz1.StandardName) = WideCharToString(tz2.StandardName)) and
      (WideCharToString(tz1.DaylightName) = WideCharToString(tz2.DaylightName));
  end; { IsEqualTZ }

  // Following two functions are converting Swatch Internet Time to UTC. Swatch
  // time is equal to GMT+1 (without DST) except that time portion is specified
  // as integer in the range of 0..999.

  function UTCToSwatch(utctime: TDateTime; var internetDate: TDateTime): TSwatchBeat;
  begin
    utctime := FixDT(utctime+60/MINUTESPERDAY);
    internetDate := Trunc(utctime);
    Result := Round(Frac(utctime)*(High(TSwatchBeat)+1));
  end; { UTCToSwatch }

  function SwatchToUTC(internetDate: TDateTime; internetBeats: TSwatchBeat): TDateTime;
  begin
    Result := FixDT(Trunc(FixDT(internetDate))+(internetBeats/(High(TSwatchBeat)+1))-60/MINUTESPERDAY);
  end; { SwatchToUTC }

  function GetTZCount: integer;
  begin
    Result := G_RegistryTZ.Count;
  end; { GetTZCount }

  function GetTZ(idx: integer; var EnglishName, displayName: string; var TZ: TTimeZoneInformation): boolean;
  var
    rtz: TGpRegistryTimeZone;
  begin
    if (idx >= 0) and (idx < GetTZCount) then begin
      rtz := G_RegistryTZ[idx];
      EnglishName := rtz.EnglishName;
      DisplayName := rtz.DisplayName;
      TZ := rtz.TimeZone;
      Result := true;
    end
    else
      Result := false;
  end; { GetTZ }
  
  function GetTZBias(TZ: TTimeZoneInformation): integer;
  var
    nowUTC: TDateTime;
  begin
    GetTZNowUTCAndBias(TZ,nowUTC,Result);
  end; { GetTZBias }

  procedure GetTZNowUTCAndBias(TZ: TTimeZoneInformation; var nowUTC: TDateTime; var nowBias: integer);
  var
    biasStart: integer;
    sysnow   : TSystemTime;
    tznow    : TDateTime;
  begin
    repeat
      biasStart := GetLocalTZBias;
      GetSystemTime(sysnow);
      nowUTC  := SystemTimeToDateTime(sysnow);
      tznow   := UTCToTZLocalTime(TZ,nowUTC);
      nowBias := Round((nowUTC-tznow)*MINUTESPERDAY);
    until biasStart = GetLocalTZBias; // recalc if local bias changed in the middle of calculation
  end; { GetTZNowUTCAndBias }

  procedure GetNowUTCAndBias(var nowUTC: TDateTime; var nowBias: integer);
  var
    TZ: TTimeZoneInformation;
  begin
    GetTimeZoneInformation (TZ);
    GetTZNowUTCAndBias(TZ, nowUTC, nowBias);
  end; { TBetterRegistry.GetNowUTCAndBias }

  function NowUTC: TDateTime;
  var
    sysnow: TSystemTime;
  begin
    GetSystemTime(sysnow);
    Result := SystemTimeToDateTime(sysnow);
  end; { NowUTC }

  function TimeUTC: TDateTime;
  begin
    Result := Frac(NowUTC);
  end; { TimeUTC }

  function DateUTC: TDateTime;
  begin
    Result := Int(NowUTC);
  end; { DateUTC }

  function TimeZoneRegKey: string;
  begin
    if Win32Platform = VER_PLATFORM_WIN32_NT then
      Result := '\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones'
    else
      Result := '\SOFTWARE\Microsoft\Windows\CurrentVersion\Time Zones';
  end; { TimeZoneRegKey }

{ private }

  type
    TRegTZI = packed record
      Bias: integer;
      StandardBias: integer;
      DaylightBias: integer;
      StandardDate: TSystemTime;
      DaylightDate: TSystemTime;
    end;

  function GetTZFromRegistry(reg: TBetterRegistry; var displayName: string; var TZ: TTimeZoneInformation): boolean;
  var
    regTZI: TRegTZI;
  begin
    Result := false;
    if assigned(reg) then begin
      with reg do begin
        if GetDataSize('TZI') = SizeOf(regTZI) then begin // data in correct format - hope, hope
          displayName := ReadString('Display');
          StringToWideChar(ReadString('Std'),@TZ.StandardName,SizeOf(TZ.StandardName) div SizeOf(WideChar));
          StringToWideChar(ReadString('Dlt'),@TZ.DaylightName,SizeOf(TZ.DaylightName) div SizeOf(WideChar));
          ReadBinaryData('TZI',regTZI,SizeOf(regTZI));
          TZ.Bias := regTZI.Bias;
          TZ.StandardBias := regTZI.StandardBias;
          TZ.DaylightBias := regTZI.DaylightBias;
          TZ.StandardDate := regTZI.StandardDate;
          TZ.DaylightDate := regTZI.DaylightDate;
          Result := true;
        end;
      end; //with
    end;
  end; { GetTZFromRegistry }

  function PutTZToRegistry(reg: TBetterRegistry; displayName: string; TZ: TTimeZoneInformation): boolean;
  var
    regTZI: TRegTZI;
  begin
    {$IFDEF VER90} //Can't convert TZ.xxxName into string in Delphi 2.
      Halt;
    {$ELSE}
      Result := false;
      if assigned(reg) then begin
        with reg do begin
          WriteString('Display',displayName);
          WriteString('Std',TZ.StandardName);
          WriteString('Dlt',TZ.DaylightName);
          regTZI.Bias := TZ.Bias;
          regTZI.StandardBias := TZ.StandardBias;
          regTZI.DaylightBias := TZ.DaylightBias;
          regTZI.StandardDate := TZ.StandardDate;
          regTZI.DaylightDate := TZ.DaylightDate;
          WriteBinaryData('TZI',regTZI,SizeOf(regTZI));
          Result := true;
        end; //with
      end;
    {$ENDIF}
  end; { PutTZToRegistry }

{ TGpRegistryTimeZones }

  function TGpRegistryTimeZones.Add(regTimeZone: TGpRegistryTimeZone): boolean;
  var
    reg: TBetterRegistry;
  begin
    CheckForWriteAccess;
    Result := false;
    reg := TBetterRegistry.Create;
    with reg do try
      RootKey := HKEY_LOCAL_MACHINE;
      regTimeZone.RegistryKey := regTimeZone.EnglishName;
      if OpenKey(TimeZoneRegKey+'\'+regTimeZone.RegistryKey,true) then begin
        PutTZToRegistry(reg,regTimeZone.DisplayName,regTimeZone.TimeZone);
        CloseKey;
        Result := true;
      end;
    finally reg.Free; end; //with
  end; { TGpRegistryTimeZones.Add }

  procedure TGpRegistryTimeZones.CheckForWriteAccess;
  begin
    if not WriteAccess then
      raise Exception.Create(sTGpRegistryTimeZonesWriteAccessNot);
  end; { TGpRegistryTimeZones.CheckForWriteAccess }

  procedure TGpRegistryTimeZones.Clear;
  var
    i: integer;
  begin
    for i := 0 to rtzList.Count-1 do begin
      TGpRegistryTimeZone(rtzList[i]).Free;
      rtzList[i] := nil;
    end; //for
    rtzList.Clear;
  end; { TGpRegistryTimeZones.Clear }

  function TGpRegistryTimeZones.Count: integer;
  begin
    Result := rtzList.Count;
  end; { TGpRegistryTimeZones.Count }

  constructor TGpRegistryTimeZones.Create;
  begin
    rtzList := TList.Create;
    Reload;
  end; { TGpRegistryTimeZones.Create }

  function TGpRegistryTimeZones.Delete(
    regTimeZone: TGpRegistryTimeZone): boolean;
  begin
    CheckForWriteAccess;
    with TBetterRegistry.Create do try
      RootKey := HKEY_LOCAL_MACHINE;
      Result := DeleteKey(TimeZoneRegKey+'\'+regTimeZone.RegistryKey);
    finally {self.}Free; end; //with
  end; { TGpRegistryTimeZones.Delete }
  
  destructor TGpRegistryTimeZones.Destroy;
  begin
    Clear;
    rtzList.Free;
    inherited Destroy;
  end; { TGpRegistryTimeZones.Destroy }

  function TGpRegistryTimeZones.GetItem(idx: integer): TGpRegistryTimeZone;
  begin
    Result := rtzList[idx];
  end; { TGpRegistryTimeZones.GetItem }

  procedure TGpRegistryTimeZones.Reload;
  var
    TZ  : TTimeZoneInformation;
    i   : integer;
    reg : TBetterRegistry;
    rtz : TGpRegistryTimeZone;
    disp: string;
    keys: TStringList;
  begin
    Clear;
    reg := TBetterRegistry.Create;
    with reg do try
      RootKey := HKEY_LOCAL_MACHINE;
      if OpenKeyReadOnly(TimeZoneRegKey) then begin
        keys := TStringList.Create;
        try
          GetKeyNames(keys);
          for i := 0 to keys.Count-1 do begin
            if OpenKeyReadOnly(TimeZoneRegKey+'\'+keys[i]) then begin
              if GetTzFromRegistry(reg,disp,TZ) then begin
                rtz := TGpRegistryTimeZone.Create;
                rtz.TimeZone := TZ;
                rtz.EnglishName := keys[i];
                rtz.DisplayName := disp;
                rtz.RegistryKey := keys[i];
                rtzList.Add(rtz);
                rtz.SetOwner(self);
              end;
              CloseKey;
            end;
          end; //for
        finally keys.Free; end;
      end;
    finally reg.Free; end; //with
  end; { TGpRegistryTimeZones.Reload }

  function TGpRegistryTimeZones.Update(rtz: TGpRegistryTimeZone): boolean;
  var
    reg: TBetterRegistry;
  begin
    CheckForWriteAccess;
    reg := TBetterRegistry.Create;
    with reg do try
      RootKey := HKEY_LOCAL_MACHINE;
      if AnsiCompareText(rtz.RegistryKey,rtz.EnglishName) <> 0 then begin
        MoveKey(TimeZoneRegKey+'\'+rtz.RegistryKey,
          TimeZoneRegKey+'\'+rtz.EnglishName,true);
        rtz.RegistryKey := rtz.EnglishName;
      end;
      Result := Add(rtz);
    finally {self.}Free; end; //with
  end; { TGpRegistryTimeZones.Update }

{ TGpRegistryTimeZone }

  function TGpRegistryTimeZone.GetWriteAccess: boolean;
  begin
    if assigned(rtzOwner) then
      Result := rtzOwner.WriteAccess
    else
      Result := true;
  end; { TGpRegistryTimeZone. }

  procedure TGpRegistryTimeZone.SetDisplayName(const Value: string);
  begin
    rtzModified := true;
    if Value <> rtzDisplayName then begin
      rtzDisplayName := Value;
      if assigned(rtzOwner) then
        if not rtzOwner.Update(self) then
          rtzModified := false;
    end;
  end; { TGpRegistryTimeZone.SetDisplayName }

  procedure TGpRegistryTimeZone.SetEnglishName(const Value: string);
  begin
    rtzModified := true;
    if Value <> rtzEnglishName then begin
      rtzEnglishName := Value;
      if assigned(rtzOwner) then
        if not rtzOwner.Update(self) then
          rtzModified := false;
    end;
  end; { TGpRegistryTimeZone.SetEnglishName }

  procedure TGpRegistryTimeZone.SetOwner(AOwner: TGpRegistryTimeZones);
  begin
    rtzOwner := AOwner;
  end; { TGpRegistryTimeZone.SetOwner }

  procedure TGpRegistryTimeZone.SetTimeZone(
    const Value: TTimeZoneInformation);
  begin
    rtzModified := true;
    if not IsEqualTZ(Value,rtzTimeZone) then begin
      rtzTimeZone := Value;
      if assigned(rtzOwner) then
        if not rtzOwner.Update(self) then
          rtzModified := false;
    end;
  end; { TGpRegistryTimeZone.SetTimeZone }
  
  procedure TGpRegistryTimeZone.SetWriteAccess(const Value: boolean);
  begin
    if assigned(rtzOwner) then
      rtzOwner.WriteAccess := Value;
  end; { TGpRegistryTimeZone.SetWriteAccess }

initialization
  G_RegistryTZ := TGpRegistryTimeZones.Create;
finalization
  G_RegistryTZ.Free;
  G_RegistryTZ := nil;
end.

