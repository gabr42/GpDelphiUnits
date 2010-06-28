(*:Version info accessors and modifiers, version storage and formatting.
   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2009, Primoz Gabrijelcic
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

   Author            : Primoz Gabrijelcic
   Creation date     : unknown
   Last modification : 2009-07-01
   Version           : 2.04
</pre>*)(*
   History:
     2.04: 2009-07-01
       - Extended IVersion interface with IsNotHigherThan, IsNotLowerThan and IsEqualTo.
     2.03: 2009-02-13
       - Updated for Delphi 2009.
     2.02: 2008-05-28
       - Added another CreateVersion overload.
       - Extended IVersion interface with IsHigherThan and IsLowerThan.
     2.01: 2007-03-13
       - Added overloaded CreateVersion function.
     2.0: 2002-10-07
       - Extended and completely redesigned.
*)

unit GpVersion;

{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  Windows,
  GpManagedClass,
  INIFiles;

const
  verFullDotted   = '%d.%d.%d.%d';     // 1.0.1.0 => 1.0.1.0
  verShort2to4    = '%d.%d%t.%d.%d';   // 1.0.1.0 => 1.0.1
  verShort2to3    = '%d.%d%t.%d';      // 1.0.1.0 => 1.0.1
  verTwoPlusAlpha = '%d.%.2d%a';       // 1.0.1.0 => 1.00a

  CDefaltLangCharset = '040904E4';

type
  {:Interface specifying access to internal version data.
  }
  IVersion = interface
    function  GetAsInt64(var fullVersion: int64): IVersion;
    function  GetAsResource(var resourceMS, resourceLS: DWORD): IVersion;
    function  GetAsWord(idx: integer; var versionPart: word): IVersion;
    function  GetAsWords(var version, subversion, revision, build: word): IVersion;
    function  GetInt64: int64;
    function  GetNextPart: word;
    function  GetResourceLS: DWORD;
    function  GetResourceMS: DWORD;
    function  GetWord(idx: integer): word;
    procedure InitIterator;
    function  IsEqualTo(version: IVersion): boolean;
    function  IsHigherThan(version: IVersion): boolean;
    function  IsLowerThan(version: IVersion): boolean;
    function  IsNotHigherThan(version: IVersion): boolean;
    function  IsNotLowerThan(version: IVersion): boolean;
    function  SetAsInt64(fullVersion: int64): IVersion;
    function  SetAsResource(resourceMS, resourceLS: DWORD): IVersion;
    function  SetAsWord(idx: integer; versionPart: word): IVersion;
    function  SetAsWords(version, subversion, revision, build: word): IVersion;
    procedure SetInt64(value: int64);
    procedure SetNextPart(versionPart: word);
    procedure SetResourceLS(value: DWORD);
    procedure SetResourceMS(value: DWORD);
    procedure SetWord(idx: integer; const Value: word);
    property AsInt64: int64 read GetInt64 write SetInt64;
    property AsResourceLS: DWORD read GetResourceLS write SetResourceLS;
    property AsResourceMS: DWORD read GetResourceMS write SetResourceMS;
    property AsWords[idx: integer]: word read GetWord write SetWord;
  end; { IVersion }

  {:Version descriptor.
    @since   2002-10-04
  }
  TVersion = class(TInterfacedObject, IVersion)
  private
    vIteratorPart: integer;
    vVersion     : array [0..3] of word;
  protected
    function  GetInt64: int64;
    function  GetResourceLS: DWORD;
    function  GetResourceMS: DWORD;
    function  GetWord(idx: integer): word;
    procedure SetInt64(value: int64);
    procedure SetResourceLS(value: DWORD);
    procedure SetResourceMS(value: DWORD);
    procedure SetWord(idx: integer; const Value: word);
  public
    constructor Create(fullVersion: int64); overload;
    constructor Create(resourceMS, resourceLS: DWORD); overload;
    constructor Create(version, subversion, revision, build: word); overload;
    function  GetAsInt64(var fullVersion: int64): IVersion;
    function  GetAsResource(var resourceMS, resourceLS: DWORD): IVersion;
    function  GetAsWord(idx: integer; var versionPart: word): IVersion;
    function  GetAsWords(var version, subversion, revision, build: word): IVersion;
    function  GetNextPart: word;
    procedure InitIterator;
    function  IsEqualTo(version: IVersion): boolean;
    function  IsHigherThan(version: IVersion): boolean;
    function  IsLowerThan(version: IVersion): boolean;
    function  IsNotHigherThan(version: IVersion): boolean;
    function  IsNotLowerThan(version: IVersion): boolean;
    function  SetAsInt64(fullVersion: int64): IVersion;
    function  SetAsResource(resourceMS, resourceLS: DWORD): IVersion;
    function  SetAsWord(idx: integer; versionPart: word): IVersion;
    function  SetAsWords(version, subversion, revision, build: word): IVersion;
    procedure SetNextPart(versionPart: word);
    property AsInt64: int64 read GetInt64 write SetInt64;
    property AsResourceLS: DWORD read GetResourceLS write SetResourceLS;
    property AsResourceMS: DWORD read GetResourceMS write SetResourceMS;
    property AsWords[idx: integer]: word read GetWord write SetWord;
  end; { TVersion }

  function CreateVersion: IVersion; overload;
  function CreateVersion(fullVersion: int64): IVersion; overload;
  function CreateVersion(version, subversion, revision, build: word): IVersion; overload;

type
  {:Interface specifyng TVersion<->string converter
    @since   2002-10-04
  }
  IVersionParser = interface
    function  StrToVer(version, formatString: string): IVersion;
    function  VerToStr(version: IVersion; formatString: string): string;
  end; { IVersionParser }

  {:Converts string into TVersion and back.
    @since   2002-10-04
  }
  TVersionParser = class(TGpManagedClass, IVersionParser)
  protected
    function  ExtractAlpha(var version: string): integer;
    function  ExtractAlphaUC(var version: string): integer;
    function  ExtractNumber(var version: string): integer;
    function  GetFirstPart(var formatString: string): string;
    function  VerToAlpha(ver: word): string;
  public
    function  StrToVer(version, formatString: string): IVersion;
    function  VerToStr(version: IVersion; formatString: string): string;
  end; { TVersionParser }

  function CreateParser: IVersionParser;

type
  {:Interface specifying access to the version info data.
  }
  IGpVersionInfo = interface
    function  GetComment: string;
    function  GetCompanyName: string;
    function  GetFormattedVersion(const formatString: string): string; 
    function  GetIsDebug: boolean;
    function  GetIsPrerelease: boolean;
    function  GetIsPrivateBuild: boolean; 
    function  GetIsSpecialBuild: boolean;
    function  GetProductName: string;
    function  GetVersion: IVersion; 
    function  HasVersionInfo: boolean;
    procedure SetComment(const comment: string);
    procedure SetCompanyName(const companyName: string);
    procedure SetFormattedVersion(const version, formatString: string); 
    procedure SetIsDebug(isDebug: boolean);
    procedure SetIsPrerelease(isPrerelease: boolean);
    procedure SetIsPrivateBuild(isPrivateBuild: boolean);
    procedure SetIsSpecialBuild(isSpecialBuild: boolean);
    procedure SetProductName(const productName: string);
    procedure SetVersion(version: IVersion);
    property Comment: string read GetComment write SetComment;
    property CompanyName: string read GetCompanyName write SetCompanyName;
    property IsDebug: boolean read GetIsDebug write SetIsDebug;
    property IsPrerelease: boolean read GetIsPrerelease write SetIsPrerelease;
    property IsPrivateBuild: boolean read GetIsPrivateBuild write SetIsPrivateBuild;
    property IsSpecialBuild: boolean read GetIsSpecialBuild write SetIsSpecialBuild;
    property ProductName: string read GetProductName write SetProductName;
    property Version: IVersion read GetVersion write SetVersion;
  end; { IGpVersionInfo }

  {:Abstract version info accessing class.
    @since   2002-10-07
  }        
  TGpAbstractVersionInfo = class(TInterfacedObject, IGpVersionInfo)
  protected
    function  GetComment: string; virtual; abstract;
    function  GetCompanyName: string; virtual; abstract;
    function  GetFormattedVersion(const formatString: string): string; virtual;
    function  GetIsDebug: boolean; virtual; abstract;
    function  GetIsPrerelease: boolean; virtual; abstract;
    function  GetIsPrivateBuild: boolean; virtual; abstract;
    function  GetIsSpecialBuild: boolean; virtual; abstract;
    function  GetProductName: string; virtual; abstract;
    function  GetVersion: IVersion; virtual; abstract;
    function  HasVersionInfo: boolean; virtual; abstract;
    procedure SetComment(const comment: string); virtual; abstract;
    procedure SetCompanyName(const companyName: string); virtual; abstract;
    procedure SetFormattedVersion(const version, formatString: string); virtual;
    procedure SetIsDebug(isDebug: boolean); virtual; abstract;
    procedure SetIsPrivateBuild(isPrivateBuild: boolean); virtual; abstract;
    procedure SetIsPrerelease(isPrerelease: boolean); virtual; abstract;
    procedure SetIsSpecialBuild(isSpecialBuild: boolean); virtual; abstract;
    procedure SetProductName(const productName: string); virtual; abstract;
    procedure SetVersion(version: IVersion); virtual; abstract;
  end; { TGpAbstractVersionInfo }

  {:Parent for the read-only version info classes.
    @since   2002-10-07
  }
  TGpReadonlyVersionInfo = class(TGpAbstractVersionInfo)
  protected
    procedure SetComment(const comment: string); override;
    procedure SetCompanyName(const companyName: string); override;
    procedure SetIsDebug(isDebug: boolean); override;
    procedure SetIsPrerelease(isPrerelease: boolean); override;
    procedure SetIsPrivateBuild(isPrivateBuild: boolean); override;
    procedure SetIsSpecialBuild(isSpecialBuild: boolean); override;
    procedure SetProductName(const productName: string); override;
    procedure SetVersion(version: IVersion); override;
    procedure SetFormattedVersion(const version, formatString: string); override;
  end; { TGpReadonlyVersionInfo }

  {:Read-only access to the version info resource in the executable.
  }
  TGpResourceVersionInfo = class(TGpReadonlyVersionInfo)
  private
    viVersionSize  : DWORD;
    viVersionInfo  : pointer;
    viFixedFileInfo: PVSFixedFileInfo;
    viFixedFileSize: UINT;
    viLangCharset  : string;
  protected
    function  GetComment: string; override;
    function  GetCompanyName: string; override;
    function  GetIsDebug: boolean; override;
    function  GetIsPrerelease: boolean; override;
    function  GetIsPrivateBuild: boolean; override;
    function  GetIsSpecialBuild: boolean; override;
    function  GetProductName: string; override;
    function  GetVersion: IVersion; override;
    function  QueryValue(key: string): string;
  public
    constructor Create(const fileName: string; lang_charset: string = CDefaltLangCharset);
    destructor  Destroy; override;
    function  GetFormattedVersion(const formatString: string): string; override;
    function  HasVersionInfo: boolean; override;
    property Comment: string read GetComment;
    property CompanyName: string read GetCompanyName;
    property IsDebug: boolean read GetIsDebug;
    property IsPrerelease: boolean read GetIsPrerelease;
    property IsPrivateBuild: boolean read GetIsPrivateBuild;
    property IsSpecialBuild: boolean read GetIsSpecialBuild;
    property ProductName: string read GetProductName;
    property Version: IVersion read GetVersion;
  end; { TGpResourceVersionInfo }

  //:Alias for old programs.
  TGpVersionInfo = TGpResourceVersionInfo;

  function CreateResourceVersionInfo(const fileName: string;
    lang_charset: string = CDefaltLangCharset): IGpVersionInfo;

type
  {:Access to the version info resource in the DOF file.
  }
  TGpDOFVersionInfo = class(TGpAbstractVersionInfo)
  private
    dviIni                 : TINIFile;
    dviProductVersionFormat: string;
    function  GetSetting(const section, key: string): string;
    procedure SetSetting(const section, key, value: string);
  protected
    function  GetComment: string; override;
    function  GetCompanyName: string; override;
    function  GetIsDebug: boolean; override;
    function  GetIsPrerelease: boolean; override;
    function  GetIsPrivateBuild: boolean; override;
    function  GetIsSpecialBuild: boolean; override;
    function  GetProductName: string; override;
    function  GetVersion: IVersion; override;
    procedure SetComment(const comment: string); override;
    procedure SetCompanyName(const companyName: string); override;
    procedure SetIsDebug(isDebug: boolean); override;
    procedure SetIsPrerelease(isPrerelease: boolean); override;
    procedure SetIsPrivateBuild(isPrivateBuild: boolean); override;
    procedure SetIsSpecialBuild(isSpecialBuild: boolean); override;
    procedure SetProductName(const productName: string); override;
    procedure SetVersion(version: IVersion); override;
  public
    constructor Create(fileName: string;
      const productVersionFormat: string = '');
    destructor  Destroy; override;
    function  HasVersionInfo: boolean; override;
    property Comment: string read GetComment write SetComment;
    property CompanyName: string read GetCompanyName write SetCompanyName;
    property IsDebug: boolean read GetIsDebug write SetIsDebug;
    property IsPrerelease: boolean read GetIsPrerelease write SetIsPrerelease;
    property IsPrivateBuild: boolean read GetIsPrivateBuild write SetIsPrivateBuild;
    property IsSpecialBuild: boolean read GetIsSpecialBuild write SetIsSpecialBuild;
    property ProductName: string read GetProductName write SetProductName;
    property Version: IVersion read GetVersion write SetVersion;
  end; { TGpDOFVersionInfo }

  function CreateDOFVersionInfo(const fileName: string;
    const productVersionFormat: string = ''): IGpVersionInfo;

  function CompanyName: string;
  function GetFormattedVersion(const formatString: string): string;
  function GetVersion: IVersion; 
  function GetVersionFor(const exeName, formatString: string): string;
  function HasVersionInfo: boolean;
  function IsDebug: boolean;
  function IsPrerelease: boolean;
  function IsPrivateBuild: boolean;
  function IsSpecialBuild: boolean;
  function ProductName: string;
  function StrToVer(version, formatString: string): IVersion;
  function VerToStr(version: IVersion; formatString: string): string;

implementation

uses
  SysUtils;

const
  CDOFBuild            = 'Build';
  CDOFComments         = 'Comments';
  CDOFCompanyName      = 'CompanyName';
  CDOFDebug            = 'Debug';
  CDOFFileVersion      = 'FileVersion';
  CDOFMajorVer         = 'MajorVer';
  CDOFMinorVer         = 'MinorVer';
  CDOFPreRelease       = 'PreRelease';
  CDOFPrivate          = 'Private';
  CDOFProductName      = 'ProductName';
  CDOFProductVersion   = 'ProductVersion';
  CDOFRelease          = 'Release';
  CDOFSpecial          = 'Special';
  CDOFVersionInfo      = 'Version Info';
  CDOFVersionInfoKeys  = 'Version Info Keys';
  CResourceComments    = 'Comments';
  CResourceCompanyName = 'CompanyName';
  CResourceProductName = 'ProductName';

function CreateVersion: IVersion;
begin
  Result := TVersion.Create;
end; { CreateVersion }

function CreateVersion(fullVersion: int64): IVersion;
begin
  Result := TVersion.Create(fullVersion);
end; { CreateVersion }

function CreateVersion(version, subversion, revision, build: word): IVersion;
begin
  Result := TVersion.Create(version, subversion, revision, build);
end; { CreateVersion }

function CreateParser: IVersionParser;
begin
  Result := TVersionParser.Create;
end; { CreateParser }

function CreateResourceVersionInfo(const fileName: string;
  lang_charset: string = CDefaltLangCharset): IGpVersionInfo;
begin
  Result := TGpResourceVersionInfo.Create(fileName, lang_charset);
end; { CreateResourceVersionInfo }

function CreateDOFVersionInfo(const fileName: string;
  const productVersionFormat: string): IGpVersionInfo;
begin
  Result := TGpDOFVersionInfo.Create(fileName, productVersionFormat);
end; { CreateDOFVersionInfo }

function CompanyName: string;
begin
  Result := CreateResourceVersionInfo(ParamStr(0)).GetCompanyName;
end; { CompanyName }

function GetFormattedVersion(const formatString: string): string;
begin
  Result := CreateResourceVersionInfo(ParamStr(0)).GetFormattedVersion(formatString);
end; { GetFormattedVersion }

function GetVersion: IVersion; 
begin
  Result := CreateResourceVersionInfo(ParamStr(0)).GetVersion;
end; { GetVersion }                                 

function GetVersionFor(const exeName, formatString: string): string;
begin
  Result := CreateResourceVersionInfo(exeName).GetFormattedVersion(formatString);
end; { GetVersionFor }

function IsDebug: boolean;
begin
  Result := CreateResourceVersionInfo(ParamStr(0)).IsDebug;
end; { IsDebug }

function IsPrerelease: boolean;
begin
  Result := CreateResourceVersionInfo(ParamStr(0)).IsPrerelease;
end; { IsPrerelease }

function IsSpecialBuild: boolean;
begin
  Result := CreateResourceVersionInfo(ParamStr(0)).IsSpecialBuild;
end; { IsSpecialBuild }

function IsPrivateBuild: boolean;
begin
  Result := CreateResourceVersionInfo(ParamStr(0)).IsPrivateBuild;
end; { IsPrivateBuild }

function HasVersionInfo: boolean;
begin
  Result := CreateResourceVersionInfo(ParamStr(0)).HasVersionInfo;
end; { HasVersionInfo }

function ProductName: string;
begin
  Result := CreateResourceVersionInfo(ParamStr(0)).ProductName;
end; { ProductName }

function StrToVer(version, formatString: string): IVersion;
begin
  Result := CreateParser.StrToVer(version, formatString);
end; { StrToVer }

function VerToStr(version: IVersion; formatString: string): string;
begin
  Result := CreateParser.VerToStr(version, formatString);
end; { VerToStr }

{ TVersion }

constructor TVersion.Create(fullVersion: int64);
begin
  AsInt64 := fullVersion;
end; { TVersion.Create }

constructor TVersion.Create(resourceMS, resourceLS: DWORD);
begin
  AsResourceMS := resourceMS;
  AsResourceLS := resourceLS;
end; { TVersion.Create }

constructor TVersion.Create(version, subversion, revision, build: word);
begin
  AsWords[0] := version;
  AsWords[1] := subversion;
  AsWords[2] := revision;
  AsWords[3] := build;
end; { TVersion.Create }

function TVersion.GetAsInt64(var fullVersion: int64): IVersion;
begin
  fullVersion := AsInt64;
  Result := Self;
end; { TVersion.GetAsInt64 }

function TVersion.GetAsResource(var resourceMS, resourceLS: DWORD): IVersion;
begin
  resourceMS := AsResourceMS;
  resourceLS := AsResourceLS;
  Result := Self;
end; { TVersion.GetAsResource }

function TVersion.GetAsWord(idx: integer; var versionPart: word): IVersion;
begin
  versionPart := AsWords[idx];
  Result := Self;
end; { TVersion.GetAsWord }

function TVersion.GetAsWords(var version, subversion, revision, build: word): IVersion;
begin
  version    := AsWords[0];
  subversion := AsWords[1];
  revision   := AsWords[2];
  build      := AsWords[3];
  Result := Self;
end; { TVersion.GetAsWords }

function TVersion.GetInt64: int64;
begin
  Result := vVersion[0];
  Result := (Result SHL 16) OR vVersion[1];
  Result := (Result SHL 16) OR vVersion[2];
  Result := (Result SHL 16) OR vVersion[3];
end; { TVersion.GetInt64 }

function TVersion.GetNextPart: word;
begin
  Result := AsWords[vIteratorPart];
  Inc(vIteratorPart);
end; { TVersion.GetNextPart }

function TVersion.GetResourceLS: DWORD;
begin
  Result := (vVersion[2] SHL 16) OR vVersion[3];
end; { TVersion.GetResourceLS }

function TVersion.GetResourceMS: DWORD;
begin
  Result := (vVersion[0] SHL 16) OR vVersion[1];
end; { TVersion.GetResourceMS }

function TVersion.GetWord(idx: integer): word;
begin
  if (idx < 0) or (idx > 3) then
    raise Exception.CreateFmt('Invalid index %d in TVersion.GetWord',[idx])
  else
    Result := vVersion[idx];
end; { TVersion.GetWord }

procedure TVersion.InitIterator;
begin
  vIteratorPart := 0;
end; { TVersion.InitIterator }

function TVersion.IsEqualTo(version: IVersion): boolean;
begin
  Result := (AsInt64 = version.AsInt64);
end; { TVersion.IsEqualTo }

function TVersion.IsHigherThan(version: IVersion): boolean;
var
  iWord: integer;
begin
  Result := false;
  for iWord := Low(vVersion) to High(vVersion) do
    if AsWords[iWord] > version.AsWords[iWord] then begin
      Result := true;
      break; //for
    end
    else if AsWords[iWord] < version.AsWords[iWord] then
      break; //for
end; { TVersion.IsHigherThan }

function TVersion.IsLowerThan(version: IVersion): boolean;
var
  iWord: integer;
begin
  Result := false;
  for iWord := Low(vVersion) to High(vVersion) do
    if AsWords[iWord] < version.AsWords[iWord] then begin
      Result := true;
      break; //for
    end
    else if AsWords[iWord] > version.AsWords[iWord] then
      break; //for
end; { TVersion.IsLowerThan }

function TVersion.IsNotHigherThan(version: IVersion): boolean;
begin
  Result := IsEqualTo(version) or IsLowerThan(version);
end; { TVersion.IsNotHigherThan }

function TVersion.IsNotLowerThan(version: IVersion): boolean;
begin
  Result := IsEqualTo(version) or IsHigherThan(version);
end; { TVersion.IsNotLowerThan }

function TVersion.SetAsInt64(fullVersion: int64): IVersion;
begin
  AsInt64 := fullVersion;
  Result := Self;
end; { TVersion.SetAsInt64 }

function TVersion.SetAsResource(resourceMS, resourceLS: DWORD): IVersion;
begin
  AsResourceMS := resourceMS;
  AsResourceLS := resourceLS;
  Result := Self;
end; { TVersion.SetAsResource }

function TVersion.SetAsWord(idx: integer; versionPart: word): IVersion;
begin
  AsWords[idx] := versionPart;
  Result := Self;
end; { TVersion.SetAsWord }

function TVersion.SetAsWords(version, subversion, revision, build: word): IVersion;
begin
  AsWords[0] := version;
  AsWords[1] := subversion;
  AsWords[2] := revision;
  AsWords[3] := build;
  Result := Self;
end; { TVersion.SetAsWords }

procedure TVersion.SetInt64(value: int64);
begin
  vVersion[3] := (value AND $FFFF); value := value SHR 16;
  vVersion[2] := (value AND $FFFF); value := value SHR 16;
  vVersion[1] := (value AND $FFFF); value := value SHR 16;
  vVersion[0] := (value AND $FFFF);
end; { TVersion.SetInt64 }

procedure TVersion.SetNextPart(versionPart: word);
begin
  AsWords[vIteratorPart] := versionPart;
  Inc(vIteratorPart);
end; { TVersion.SetNextPart }

procedure TVersion.SetResourceLS(value: DWORD);
begin
   vVersion[3] := (value AND $FFFF); value := value SHR 16;
   vVersion[2] := (value AND $FFFF);
end; { TVersion.SetResourceLS }

procedure TVersion.SetResourceMS(value: DWORD);
begin
  vVersion[1] := (value AND $FFFF); value := value SHR 16;
  vVersion[0] := (value AND $FFFF);
end; { TVersion.SetResourceMS }

procedure TVersion.SetWord(idx: integer; const value: word);
begin
  if (idx < 0) or (idx > 3) then
    raise Exception.CreateFmt('Invalid index %d in TVersion.GetWord',[idx])
  else
    vVersion[idx] := value;
end; { TVersion.SetWord }

{ TVersionParser }

{:Extract leading character from the version string.
  @since   2002-10-04
}
function TVersionParser.ExtractAlpha(var version: string): integer;
begin
  if (version <> '') and (ansichar(version[1]) in ['a'..'z']) then begin
    Result := Ord(version[1]) - Ord('a') + 1;
    Delete(version, 1, 1);
  end
  else
    Result := 0;
end; { TVersionParser.ExtractAlpha }

{:Extract leading upper-case character from the version string.
  @since   2002-10-04
}
function TVersionParser.ExtractAlphaUC(var version: string): integer;
begin
  if (version <> '') and (ansichar(version[1]) in ['A'..'Z']) then begin
    Result := Ord(version[1]) - Ord('A') + 1;
    Delete(version, 1, 1);
  end
  else
    Result := 0;
end; { TVersionParser.ExtractAlphaUC }

{:Extract leading integer from the version string.
  @since   2002-10-04
}
function TVersionParser.ExtractNumber(var version: string): integer;
var
  errorPos: integer;
begin
  Val(version, Result, errorPos);
  if errorPos = 0 then
    errorPos := Length(version)+1;
  Delete(version, 1, errorPos-1);
end; { TVersionParser.ExtractNumber }

{:Extract first part of the format string.
  @since   2002-10-04
}
function TVersionParser.GetFirstPart(var formatString: string): string;
var
  i: integer;
begin
  if formatString[1] <> '%' then
    Result := formatString[1]
  else begin
    i := 2;
    while (i < Length(formatString)) and
          (not (ansichar(UpCase(formatString[i])) in ['A','D','T'])) do
      Inc(i);
    Result := Copy(formatString,1,i);
  end;
  Delete(formatString, 1, Length(Result));
end; { TVersionParser.GetFirstPart }

{:Convert string to TVersion according to the format specifier.
  @since   2002-10-04
}
function TVersionParser.StrToVer(version, formatString: string): IVersion;
var
  ftype: char;
  part : string;
begin
  Result := CreateVersion;
  Result.InitIterator;
  while formatString <> '' do begin
    part := GetFirstPart(formatString);
    if part[1] <> '%' then
      Delete(version, 1, Length(part))
    else begin
      ftype := part[Length(part)];
      case ftype of
        'd','D': Result.SetNextPart(ExtractNumber(version));
        'a': Result.SetNextPart(ExtractAlpha(version));
        'A': Result.SetNextPart(ExtractAlphaUC(version));
        else // skip irrelevant specifier
      end; //case
    end; //if
  end; //while
end; { TVersionParser.StrToVer }

{:Convert one part of version number into string.
  @since   2002-10-04
}
function TVersionParser.VerToAlpha(ver: word): string;
begin
  if ver > 0 then begin
    if ver <= 26 then
      Result := Chr(Ord('a')+ver-1)
    else
      Result := '?';
  end
  else
    Result := '';
end; { TVersionParser.VerToAlpha }

{:Convert TVersion to string according to the format specifier.
  @since   2002-10-04
}
function TVersionParser.VerToStr(version: IVersion; formatString: string): string;
var
  ftype         : char;
  lastTruncPoint: integer;
  part          : string;
  truncating    : boolean;
  verpart       : word;

  procedure CheckTruncate;
  begin
    if truncating then
      if verpart > 0 then
        lastTruncPoint := Length(Result);
  end; { CheckTruncate }

begin
  Result := '';
  version.InitIterator;
  truncating := false;
  while formatString <> '' do begin
    part := GetFirstPart(formatString);
    if part[1] <> '%' then
      Result := Result + part
    else begin
      ftype := part[Length(part)];
      case ftype of
        'd','D':
          begin
            Result := Result + Format(part,[version.GetNextPart]);
            CheckTruncate;
          end; //'d','D'
        'a':
          begin
            Result := Result + VerToAlpha(version.GetNextPart);
            CheckTruncate;
          end; //'a'
        'A':
          begin
            Result := Result + UpperCase(VerToAlpha(version.GetNextPart));
            CheckTruncate;
          end; //'A'
        't','T':
          begin
            lastTruncPoint := Length(Result);
            truncating := true;
          end; //'t','T'
        else
          Result := Result + part;
      end; //case
    end; //if
  end; //while
  if truncating then
    Result := Copy(Result,1,lastTruncPoint);
end; { TVersionParser.VerToStr }

{ TGpAbstractVersionInfo }

function TGpAbstractVersionInfo.GetFormattedVersion(
  const formatString: string): string;
begin
  Result := VerToStr(GetVersion, formatString);
end; { TVersionParser.GetFormattedVersion }

procedure TGpAbstractVersionInfo.SetFormattedVersion(const version,
  formatString: string);
begin
  SetVersion(StrToVer(version, formatString));
end;{ TGpReadonlyVersionInfo }

procedure TGpReadonlyVersionInfo.SetComment(const comment: string);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetComment');
end; { TGpReadonlyVersionInfo.SetComment }

procedure TGpReadonlyVersionInfo.SetCompanyName(const companyName: string);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetCompanyName');
end; { TGpReadonlyVersionInfo.SetCompanyName }

procedure TGpReadonlyVersionInfo.SetFormattedVersion(const version,
  formatString: string);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetFormattedVersion');
end; { TGpReadonlyVersionInfo.SetFormattedVersion }

procedure TGpReadonlyVersionInfo.SetIsDebug(isDebug: boolean);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetIsDebug');
end; { TGpReadonlyVersionInfo.SetIsDebug }

procedure TGpReadonlyVersionInfo.SetIsPrerelease(isPrerelease: boolean);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetIsPrerelease');
end; { TGpReadonlyVersionInfo.SetIsPrerelease }

procedure TGpReadonlyVersionInfo.SetIsPrivateBuild(isPrivateBuild: boolean);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetIsPrivateBuild');
end; { TGpReadonlyVersionInfo.SetIsPrivateBuild }

procedure TGpReadonlyVersionInfo.SetIsSpecialBuild(
  isSpecialBuild: boolean);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetIsSpecialBuild');
end; { TGpReadonlyVersionInfo.SetIsSpecialBuild }

procedure TGpReadonlyVersionInfo.SetProductName(const productName: string);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetProductName');
end; { TGpReadonlyVersionInfo.SetProductName }

procedure TGpReadonlyVersionInfo.SetVersion(version: IVersion);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetVersion');
end; { TGpReadonlyVersionInfo.SetVersion }

{ TGpResourceVersionInfo }

constructor TGpResourceVersionInfo.Create(const fileName: string; lang_charset: string = CDefaltLangCharset);
var
  hnd: DWORD;
begin
  inherited Create;
  viLangCharset := lang_charset;
  viVersionSize := GetFileVersionInfoSize(PChar(fileName),hnd);
  if viVersionSize > 0 then begin
    GetMem(viVersionInfo,viVersionSize);
    Win32Check(GetFileVersionInfo(PChar(fileName),0,viVersionSize,viVersionInfo));
    Win32Check(VerQueryValue(viVersionInfo,'\',pointer(viFixedFileInfo),viFixedFileSize));
  end;
end; { TGpResourceVersionInfo.Create }

destructor TGpResourceVersionInfo.Destroy;
begin
  FreeMem(viVersionInfo);
  inherited Destroy;
end; { TGpResourceVersionInfo.Destroy }

function TGpResourceVersionInfo.GetComment: string;
begin
  Result := QueryValue(CResourceComments);
end; { TGpResourceVersionInfo.GetComment }

function TGpResourceVersionInfo.GetCompanyName: string;
begin
  Result := QueryValue(CResourceCompanyName);
end; { TGpResourceVersionInfo.GetCompanyName }

function TGpResourceVersionInfo.GetFormattedVersion(const formatString: string): string;
begin
  Result := '';
  if not HasVersionInfo then
    Exit;
  Result := CreateParser.VerToStr(GetVersion, formatString);
end; { TGpResourceVersionInfo.GetFormattedVersion }

function TGpResourceVersionInfo.GetIsDebug: boolean;
begin
  with viFixedFileInfo^ do
    Result := ((VS_FF_DEBUG AND dwFileFlagsMask) <> 0) and
              ((VS_FF_DEBUG AND dwFileFlags) <> 0);
end; { TGpResourceVersionInfo.GetIsDebug }

function TGpResourceVersionInfo.GetIsPrerelease: boolean;
begin
  with viFixedFileInfo^ do
    Result := ((VS_FF_PRERELEASE AND dwFileFlagsMask) <> 0) and
              ((VS_FF_PRERELEASE AND dwFileFlags) <> 0);
end; { TGpResourceVersionInfo.GetIsPrerelease }

function TGpResourceVersionInfo.GetIsPrivateBuild: boolean;
begin
  with viFixedFileInfo^ do
    Result := ((VS_FF_PRIVATEBUILD AND dwFileFlagsMask) <> 0) and
              ((VS_FF_PRIVATEBUILD AND dwFileFlags) <> 0);
end; { TGpResourceVersionInfo.GetIsPrivateBuild }

function TGpResourceVersionInfo.GetIsSpecialBuild: boolean;
begin
  with viFixedFileInfo^ do
    Result := ((VS_FF_SPECIALBUILD AND dwFileFlagsMask) <> 0) and
              ((VS_FF_SPECIALBUILD AND dwFileFlags) <> 0);
end; { TGpResourceVersionInfo.GetIsSpecialBuild }

function TGpResourceVersionInfo.GetProductName: string;
begin
  Result := QueryValue(CResourceProductName);
end; { TGpResourceVersionInfo.GetProductName }

function TGpResourceVersionInfo.GetVersion: IVersion;
begin
  Result := CreateVersion;
  if HasVersionInfo then
    Result.SetAsResource(viFixedFileInfo^.dwFileVersionMS, viFixedFileInfo^.dwFileVersionLS);
end; { TGpResourceVersionInfo.GetVersion }

function TGpResourceVersionInfo.HasVersionInfo: boolean;
begin
  Result := (viVersionSize > 0);
end; { TGpResourceVersionInfo.HasVersionInfo }

function TGpResourceVersionInfo.QueryValue(key: string): string;
var
  p   : PChar;
  clen: DWORD;
begin
  if VerQueryValue(viVersionInfo,PChar('\StringFileInfo\'+viLangCharset+'\'+key),pointer(p),clen) then
    Result := p
  else
    Result := '';
end; { TGpResourceVersionInfo.QueryValue }

{ TGpDOFVersionInfo }

constructor TGpDOFVersionInfo.Create(fileName: string; const productVersionFormat: string);
begin
  inherited Create;
  if ExtractFilePath(fileName) = '' then
    fileName := '.\'+fileName;
  dviIni := TINIFile.Create(fileName);
  dviProductVersionFormat := productVersionFormat;
end; { TGpDOFVersionInfo.Create }

destructor TGpDOFVersionInfo.Destroy;
begin
  FreeAndNil(dviIni);
  inherited Destroy;
end; { TGpDOFVersionInfo.Destroy }

function TGpDOFVersionInfo.GetComment: string;
begin
  Result := GetSetting(CDOFVersionInfoKeys, CDOFComments);
end; { TGpDOFVersionInfo.GetComment }

function TGpDOFVersionInfo.GetCompanyName: string;
begin
  Result := GetSetting(CDOFVersionInfoKeys, CDOFCompanyName);
end; { TGpDOFVersionInfo.GetCompanyName }

function TGpDOFVersionInfo.GetIsDebug: boolean;
begin
  Result := (GetSetting(CDOFVersionInfo, CDOFDebug) = '1');
end; { TGpDOFVersionInfo.GetIsDebug }

function TGpDOFVersionInfo.GetIsPrerelease: boolean;
begin
  Result := (GetSetting(CDOFVersionInfo, CDOFPreRelease) = '1');
end; { TGpDOFVersionInfo.GetIsPrerelease }

function TGpDOFVersionInfo.GetIsPrivateBuild: boolean;
begin
  Result := (GetSetting(CDOFVersionInfo, CDOFPrivate) = '1');
end; { TGpDOFVersionInfo.GetIsPrivateBuild }

function TGpDOFVersionInfo.GetIsSpecialBuild: boolean;
begin
  Result := (GetSetting(CDOFVersionInfo, CDOFSpecial) = '1');
end; { TGpDOFVersionInfo.GetIsSpecialBuild }

function TGpDOFVersionInfo.GetProductName: string;
begin
  Result := GetSetting(CDOFVersionInfoKeys, CDOFProductName);
end; { TGpDOFVersionInfo.GetProductName }

function TGpDOFVersionInfo.GetSetting(const section, key: string): string;
begin
  Result := dviIni.ReadString(section, key, '');
end; { TGpDOFVersionInfo.GetSetting }

function TGpDOFVersionInfo.GetVersion: IVersion;
var
  productVersion: IVersion;
  versionInfo   : IVersion;
begin
  Result := StrToVer(GetSetting(CDOFVersionInfoKeys, CDOFFileVersion), verFullDotted);
  versionInfo := CreateVersion.SetAsWords(
    StrToInt(GetSetting(CDOFVersionInfo, CDOFMajorVer)),
    StrToInt(GetSetting(CDOFVersionInfo, CDOFMinorVer)),
    StrToInt(GetSetting(CDOFVersionInfo, CDOFRelease)),
    StrToInt(GetSetting(CDOFVersionInfo, CDOFBuild))
  );
  if versionInfo.AsInt64 > Result.AsInt64 then
    Result := versionInfo;
  if dviProductVersionFormat <> '' then begin
    productVersion := StrToVer(GetSetting(CDOFVersionInfoKeys, CDOFProductVersion), dviProductVersionFormat);
    if productVersion.AsInt64 > Result.AsInt64 then
      Result := productVersion;
  end;
end; { TGpDOFVersionInfo.GetVersion }

function TGpDOFVersionInfo.HasVersionInfo: boolean;
begin
  Result :=
    dviIni.SectionExists(CDOFVersionInfo) and
    dviIni.SectionExists(CDOFVersionInfoKeys);
end; { TGpDOFVersionInfo.HasVersionInfo }

procedure TGpDOFVersionInfo.SetComment(const comment: string);
begin
  SetSetting(CDOFVersionInfoKeys, CDOFComments, comment);
end; { TGpDOFVersionInfo.SetComment }

procedure TGpDOFVersionInfo.SetCompanyName(const companyName: string);
begin
  SetSetting(CDOFVersionInfoKeys, CDOFCompanyName, companyName);
end; { TGpDOFVersionInfo.SetCompanyName }

procedure TGpDOFVersionInfo.SetIsDebug(isDebug: boolean);
begin
  SetSetting(CDOFVersionInfo, CDOFDebug, IntToStr(Ord(isDebug)));
end; { TGpDOFVersionInfo.SetIsDebug }

procedure TGpDOFVersionInfo.SetIsPrerelease(isPrerelease: boolean);
begin
  SetSetting(CDOFVersionInfo, CDOFPreRelease, IntToStr(Ord(isPrerelease)));
end; { TGpDOFVersionInfo.SetIsPrerelease }

procedure TGpDOFVersionInfo.SetIsPrivateBuild(isPrivateBuild: boolean);
begin
  SetSetting(CDOFVersionInfo, CDOFPrivate, IntToStr(Ord(isPrivateBuild)));
end; { TGpDOFVersionInfo.SetIsPrivateBuild }

procedure TGpDOFVersionInfo.SetIsSpecialBuild(isSpecialBuild: boolean);
begin
  SetSetting(CDOFVersionInfo, CDOFSpecial, IntToStr(Ord(isSpecialBuild)));
end; { TGpDOFVersionInfo.SetIsSpecialBuild }

procedure TGpDOFVersionInfo.SetProductName(const productName: string);
begin
  SetSetting(CDOFVersionInfoKeys, CDOFProductName, productName);
end; { TGpDOFVersionInfo.SetProductName }

procedure TGpDOFVersionInfo.SetSetting(const section, key, value: string);
begin
  dviIni.WriteString(section, key, value);
end; { TGpDOFVersionInfo.SetSetting }

procedure TGpDOFVersionInfo.SetVersion(version: IVersion);
begin
  SetSetting(CDOFVersionInfoKeys, CDOFFileVersion, VerToStr(version, verFullDotted));
  SetSetting(CDOFVersionInfo, CDOFMajorVer, IntToStr(version.AsWords[0]));
  SetSetting(CDOFVersionInfo, CDOFMinorVer, IntToStr(version.AsWords[1]));
  SetSetting(CDOFVersionInfo, CDOFRelease,  IntToStr(version.AsWords[2]));
  SetSetting(CDOFVersionInfo, CDOFBuild,    IntToStr(version.AsWords[3]));
  if dviProductVersionFormat <> '' then
    SetSetting(CDOFVersionInfoKeys, CDOFProductVersion, VerToStr(version, dviProductVersionFormat));
end; { TGpDOFVersionInfo.SetVersion }

end.
