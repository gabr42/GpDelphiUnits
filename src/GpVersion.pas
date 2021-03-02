(*:Version info accessors and modifiers, version storage and formatting.
   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2020, Primoz Gabrijelcic
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
   Last modification : 2021-01-04
   Version           : 2.14
</pre>*)(*
   History:
     2.14: 2021-01-04
       - Prepend '.\' to pathless file name to prevent problems on Windows 10.
     2.13: 2017-05-31
       - Code doesn't create VersionInfo and VersionInfoKeys anymore as that breaks
         Berlin compatibility.
       - Information from various PropertyGroup/VerInfo_Keys values is merged together.
     2.12a: 2016-12-05
       - Better logic for reading information from a .dproj.
     2.12: 2016-10-17
       - SetVersion modifies all configurations in a .dproj file.
     2.11: 2016-08-29
       - DPROJ understands Seattle format.
     2.10: 2013-02-11
       - DPROJ understands XE2 format.
     2.09a: 2012-11-08
       - DPROJ version info writer converts &apos; back into '.
     2.09: 2012-03-08
       - TGpDPROJVersionInfo.Destroy opens .dproj file with retry logic. Somehow .dproj
         is sometimes "being used by another process" on the build server.
     2.08: 2011-01-24
       - Implemented Locale and Codepage properties.
     2.07: 2010-11-12
       - Implemented TGpDPROJVersionInfo.SetVersionInfoKey.
     2.06: 2010-11-06
       - Implemented TGpDPROJVersionInfo.GetVersionInfoKey.
     2.05: 2010-11-04
       - Added DPROJ version reader/writer.
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
  Classes,
  GpManagedClass,
  INIFiles,
  OmniXML,
  OmniXMLUtils;

const
  verFullDotted   = '%d.%d.%d.%d';     // 1.0.1.0 => 1.0.1.0
  verShort2to4    = '%d.%d%t.%d.%d';   // 1.0.1.0 => 1.0.1
  verShort2to3    = '%d.%d%t.%d';      // 1.0.1.0 => 1.0.1
  verShort2       = '%d.%.2d';         // 1.0.1.0 => 1.0
  verTwoPlusAlpha = '%d.%.2d%a';       // 1.0.1.0 => 1.00a
  verFABBuild     = 'FABBUILD';        // works in GetFormattedVersion and VerToStr

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
    function  GetCodePage: word;
    function  GetComment: string;
    function  GetCompanyName: string;
    function  GetFormattedVersion(const formatString: string): string;
    function  GetIsDebug: boolean;
    function  GetIsPrerelease: boolean;
    function  GetIsPrivateBuild: boolean;
    function  GetIsSpecialBuild: boolean;
    function  GetLocale: word;
    function  GetProductName: string;
    function  GetVersion: IVersion;
    function  GetVersionInfoKey(const keyName: string): string;
    function  HasVersionInfo: boolean;
    procedure SetCodePage(value: word);
    procedure SetComment(const comment: string);
    procedure SetCompanyName(const companyName: string);
    procedure SetFormattedVersion(const version, formatString: string);
    procedure SetIsDebug(isDebug: boolean);
    procedure SetIsPrerelease(isPrerelease: boolean);
    procedure SetIsPrivateBuild(isPrivateBuild: boolean);
    procedure SetIsSpecialBuild(isSpecialBuild: boolean);
    procedure SetLocale(value: word);
    procedure SetProductName(const productName: string);
    procedure SetVersion(version: IVersion);
    procedure SetVersionInfoKey(const keyName, value: string);
    property CodePage: word read GetCodePage write SetCodePage;
    property Comment: string read GetComment write SetComment;
    property CompanyName: string read GetCompanyName write SetCompanyName;
    property IsDebug: boolean read GetIsDebug write SetIsDebug;
    property IsPrerelease: boolean read GetIsPrerelease write SetIsPrerelease;
    property IsPrivateBuild: boolean read GetIsPrivateBuild write SetIsPrivateBuild;
    property IsSpecialBuild: boolean read GetIsSpecialBuild write SetIsSpecialBuild;
    property Locale: word read GetLocale write SetLocale;
    property ProductName: string read GetProductName write SetProductName;
    property Version: IVersion read GetVersion write SetVersion;
  end; { IGpVersionInfo }

  IGpDprojInfo = interface ['{7FFF0D4F-9C18-4D7D-9A95-ED25A66AC98B}']
    function GetManifestName: string;
  end; { IGpDprojInfo }

  {:Abstract version info accessing class.
    @since   2002-10-07
  }
  TGpAbstractVersionInfo = class(TInterfacedObject, IGpVersionInfo)
  protected
    function  GetCodePage: word; virtual; abstract;
    function  GetComment: string; virtual; abstract;
    function  GetCompanyName: string; virtual; abstract;
    function  GetFormattedVersion(const formatString: string): string; virtual;
    function  GetIsDebug: boolean; virtual; abstract;
    function  GetIsPrerelease: boolean; virtual; abstract;
    function  GetIsPrivateBuild: boolean; virtual; abstract;
    function  GetIsSpecialBuild: boolean; virtual; abstract;
    function  GetLocale: word; virtual; abstract;
    function  GetProductName: string; virtual; abstract;
    function  GetVersion: IVersion; virtual; abstract;
    function  GetVersionInfoKey(const keyName: string): string; virtual; abstract;
    function  HasVersionInfo: boolean; virtual; abstract;
    procedure SetCodePage(value: word); virtual; abstract;
    procedure SetComment(const comment: string); virtual; abstract;
    procedure SetCompanyName(const companyName: string); virtual; abstract;
    procedure SetFormattedVersion(const version, formatString: string); virtual;
    procedure SetIsDebug(isDebug: boolean); virtual; abstract;
    procedure SetIsPrivateBuild(isPrivateBuild: boolean); virtual; abstract;
    procedure SetIsPrerelease(isPrerelease: boolean); virtual; abstract;
    procedure SetIsSpecialBuild(isSpecialBuild: boolean); virtual; abstract;
    procedure SetLocale(value: word); virtual; abstract;
    procedure SetProductName(const productName: string); virtual; abstract;
    procedure SetVersion(version: IVersion); virtual; abstract;
    procedure SetVersionInfoKey(const keyName, value: string); virtual; abstract;
  end; { TGpAbstractVersionInfo }

  {:Parent for the read-only version info classes.
    @since   2002-10-07
  }
  TGpReadonlyVersionInfo = class(TGpAbstractVersionInfo)
  protected
    procedure SetCodePage(value: word); override;
    procedure SetComment(const comment: string); override;
    procedure SetCompanyName(const companyName: string); override;
    procedure SetIsDebug(isDebug: boolean); override;
    procedure SetIsPrerelease(isPrerelease: boolean); override;
    procedure SetIsPrivateBuild(isPrivateBuild: boolean); override;
    procedure SetIsSpecialBuild(isSpecialBuild: boolean); override;
    procedure SetLocale(value: word); override;
    procedure SetProductName(const productName: string); override;
    procedure SetVersion(version: IVersion); override;
    procedure SetFormattedVersion(const version, formatString: string); override;
    procedure SetVersionInfoKey(const keyName, value: string); override;
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
    function  GetCodePage: word; override;
    function  GetComment: string; override;
    function  GetCompanyName: string; override;
    function  GetIsDebug: boolean; override;
    function  GetIsPrerelease: boolean; override;
    function  GetIsPrivateBuild: boolean; override;
    function  GetIsSpecialBuild: boolean; override;
    function  GetLocale: word; override;
    function  GetProductName: string; override;
    function  GetVersion: IVersion; override;
    function  GetVersionInfoKey(const keyName: string): string; override;
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
    function  GetCodePage: word; override;
    function  GetComment: string; override;
    function  GetCompanyName: string; override;
    function  GetIsDebug: boolean; override;
    function  GetIsPrerelease: boolean; override;
    function  GetIsPrivateBuild: boolean; override;
    function  GetIsSpecialBuild: boolean; override;
    function  GetLocale: word; override;
    function  GetProductName: string; override;
    function  GetVersion: IVersion; override;
    function  GetVersionInfoKey(const keyName: string): string; override;
    procedure SetCodePage(value: word); override;
    procedure SetComment(const comment: string); override;
    procedure SetCompanyName(const companyName: string); override;
    procedure SetIsDebug(isDebug: boolean); override;
    procedure SetIsPrerelease(isPrerelease: boolean); override;
    procedure SetIsPrivateBuild(isPrivateBuild: boolean); override;
    procedure SetIsSpecialBuild(isSpecialBuild: boolean); override;
    procedure SetLocale(value: word); override;
    procedure SetProductName(const productName: string); override;
    procedure SetVersion(version: IVersion); override;
    procedure SetVersionInfoKey(const keyName, value: string); override;
  public
    constructor Create(fileName: string; const productVersionFormat: string = '');
    destructor  Destroy; override;
    function  HasVersionInfo: boolean; override;
    property CodePage: word read GetCodePage write SetCodePage;
    property Comment: string read GetComment write SetComment;
    property CompanyName: string read GetCompanyName write SetCompanyName;
    property IsDebug: boolean read GetIsDebug write SetIsDebug;
    property IsPrerelease: boolean read GetIsPrerelease write SetIsPrerelease;
    property IsPrivateBuild: boolean read GetIsPrivateBuild write SetIsPrivateBuild;
    property IsSpecialBuild: boolean read GetIsSpecialBuild write SetIsSpecialBuild;
    property Locale: word read GetLocale write SetLocale;
    property ProductName: string read GetProductName write SetProductName;
    property Version: IVersion read GetVersion write SetVersion;
  end; { TGpDOFVersionInfo }

  function CreateDOFVersionInfo(const fileName: string;
    const productVersionFormat: string = ''): IGpVersionInfo;

type
  {:Access to the version info resource in the DPROJ file.
  }
  TGpDPROJVersionInfo = class(TGpAbstractVersionInfo, IGpDprojInfo)
  private
    dviDproj               : IXMLDocument;
    dviFileName            : string;
    dviManifest            : IXMLNode; //PropertyGroup/Manifest_File
    dviModified            : boolean;
    dviProductVersionFormat: string;
    dviPVIK                : IXMLNode; // PropertyGroup[Platform]/VerInfo_Keys
    dviPVIKList            : TStringList;
    dviVI                  : IXMLNode; // Personality/VersionInfo
    dviVIK                 : IXMLNode; // Personality/VersionInfoKeys
    dviVIL                 : IXMLNode; // PropertyGroup[Platform]/VerInfo_Locale
  protected
    function  CollectVerInfoKeys: string;
    function  GetCodePage: word; override;
    function  GetComment: string; override;
    function  GetCompanyName: string; override;
    function  GetIsDebug: boolean; override;
    function  GetIsPrerelease: boolean; override;
    function  GetIsPrivateBuild: boolean; override;
    function  GetIsSpecialBuild: boolean; override;
    function  GetLocale: word; override;
    function  GetManifestName: string;
    function  GetProductName: string; override;
    function  GetVersion: IVersion; override;
    procedure SetAllNodes(const path: string; value: string);
    procedure SetCodePage(value: word); override;
    procedure SetComment(const comment: string); override;
    procedure SetCompanyName(const companyName: string); override;
    procedure SetIsDebug(isDebug: boolean); override;
    procedure SetIsPrerelease(isPrerelease: boolean); override;
    procedure SetIsPrivateBuild(isPrivateBuild: boolean); override;
    procedure SetIsSpecialBuild(isSpecialBuild: boolean); override;
    procedure SetLocale(value: word); override;
    procedure SetProductName(const productName: string); override;
    procedure SetVersion(version: IVersion); override;
  public
    constructor Create(fileName: string; const productVersionFormat: string = '');
    destructor  Destroy; override;
    function  GetVersionInfoKey(const keyName: string): string; override;
    function  HasVersionInfo: boolean; override;
    procedure SetVersionInfoKey(const keyName, value: string); override;
    property CodePage: word read GetCodePage write SetCodePage;
    property Comment: string read GetComment write SetComment;
    property CompanyName: string read GetCompanyName write SetCompanyName;
    property IsDebug: boolean read GetIsDebug write SetIsDebug;
    property IsPrerelease: boolean read GetIsPrerelease write SetIsPrerelease;
    property IsPrivateBuild: boolean read GetIsPrivateBuild write SetIsPrivateBuild;
    property IsSpecialBuild: boolean read GetIsSpecialBuild write SetIsSpecialBuild;
    property Locale: word read GetLocale write SetLocale;
    property ManifestName: string read GetManifestName;
    property ProductName: string read GetProductName write SetProductName;
    property Version: IVersion read GetVersion write SetVersion;
  end; { TGpDPROJVersionInfo }

  function CreateDPROJVersionInfo(const fileName: string;
    const productVersionFormat: string): IGpVersionInfo;

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
  SysUtils,
  {$IFDEF Unicode}
  AnsiStrings,
  {$ENDIF}
  GpStreams,
  GpHugeF;

const
  CDOFBuild            = 'Build';
  CDOFCodePage         = 'CodePage';
  CDOFComments         = 'Comments';
  CDOFCompanyName      = 'CompanyName';
  CDOFDebug            = 'Debug';
  CDOFFileVersion      = 'FileVersion';
  CDOFLocale           = 'Locale';
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

function CreateDPROJVersionInfo(const fileName: string;
  const productVersionFormat: string): IGpVersionInfo;
begin
  Result := TGpDPROJVersionInfo.Create(fileName, productVersionFormat);
end; { CreateDPROJVersionInfo }

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

  if formatString = verFABBuild then
    formatString := verShort2to3;

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

  if formatString = verFABBuild then
    if (version.GetAsWord (2, verpart) <> nil) and (verpart = 0) then
      formatString := verTwoPlusAlpha
    else formatString := verShort2to3;

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

procedure TGpReadonlyVersionInfo.SetCodePage(value: word);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetCodePage');
end; { TGpReadonlyVersionInfo.SetCodePage }

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

procedure TGpReadonlyVersionInfo.SetLocale(value: word);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetLocale');
end; { TGpReadonlyVersionInfo.SetLocale }

procedure TGpReadonlyVersionInfo.SetProductName(const productName: string);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetProductName');
end; { TGpReadonlyVersionInfo.SetProductName }

procedure TGpReadonlyVersionInfo.SetVersion(version: IVersion);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetVersion');
end; { TGpReadonlyVersionInfo.SetVersion }

procedure TGpReadonlyVersionInfo.SetVersionInfoKey(const keyName, value: string);
begin
  raise EAbstractError.Create('TGpReadonlyVersionInfo.SetVersionInfoKey');
end; { TGpReadonlyVersionInfo.SetVersionInfoKey }

{ TGpResourceVersionInfo }

constructor TGpResourceVersionInfo.Create(const fileName: string; lang_charset: string = CDefaltLangCharset);
var
  hnd: DWORD;
  fn: string;
begin
  inherited Create;
  viLangCharset := lang_charset;
  fn := fileName;
  if ExtractFilePath(fn) = '' then
    fn := '.\' + fn;
  viVersionSize := GetFileVersionInfoSize(PChar(fn),hnd);
  if viVersionSize > 0 then begin
    GetMem(viVersionInfo,viVersionSize);
    Win32Check(GetFileVersionInfo(PChar(fn),0,viVersionSize,viVersionInfo));
    Win32Check(VerQueryValue(viVersionInfo,'\',pointer(viFixedFileInfo),viFixedFileSize));
  end;
end; { TGpResourceVersionInfo.Create }

destructor TGpResourceVersionInfo.Destroy;
begin
  FreeMem(viVersionInfo);
  inherited Destroy;
end; { TGpResourceVersionInfo.Destroy }

function TGpResourceVersionInfo.GetCodePage: word;
begin
  Result := StrToInt(viLangCharset) SHR 16; // untested
end; { TGpResourceVersionInfo.GetCodePage }

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

function TGpResourceVersionInfo.GetLocale: word;
begin
  Result := StrToInt(viLangCharset) AND $FFFF; // untested
end; { TGpResourceVersionInfo.GetLocale }

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

function TGpResourceVersionInfo.GetVersionInfoKey(const keyName: string): string;
begin
  Result := QueryValue(keyName); // untested
end; { TGpResourceVersionInfo.GetVersionInfoKey }

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

function TGpDOFVersionInfo.GetCodePage: word;
begin
  Result := StrToInt(GetSetting(CDOFVersionInfoKeys, CDOFCodePage));
end; { TGpDOFVersionInfo.GetCodePage }

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

function TGpDOFVersionInfo.GetLocale: word;
begin
  Result := StrToInt(GetSetting(CDOFVersionInfoKeys, CDOFLocale));
end; { TGpDOFVersionInfo.GetLocale }

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

function TGpDOFVersionInfo.GetVersionInfoKey(const keyName: string): string;
begin
  Result := GetSetting(CDOFVersionInfoKeys, keyName);
end; { TGpDOFVersionInfo.GetVersionInfoKey }

function TGpDOFVersionInfo.HasVersionInfo: boolean;
begin
  Result :=
    dviIni.SectionExists(CDOFVersionInfo) and
    dviIni.SectionExists(CDOFVersionInfoKeys);
end; { TGpDOFVersionInfo.HasVersionInfo }

procedure TGpDOFVersionInfo.SetCodePage(value: word);
begin
  SetSetting(CDOFVersionInfo, CDOFCodePage, IntToStr(value));
end; { TGpDOFVersionInfo.SetCodePage }

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

procedure TGpDOFVersionInfo.SetLocale(value: word);
begin
  SetSetting(CDOFVersionInfo, CDOFLocale, IntToStr(value));
end; { TGpDOFVersionInfo.SetLocale }

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

procedure TGpDOFVersionInfo.SetVersionInfoKey(const keyName, value: string);
begin
  SetSetting(CDOFVersionInfoKeys, keyName, value);
end; { TGpDOFVersionInfo.SetVersionInfoKey }

{ TGpDPROJVersionInfo }

constructor TGpDPROJVersionInfo.Create(fileName: string; const productVersionFormat: string);
begin
  inherited Create;
  dviFileName := fileName;
  dviProductVersionFormat := productVersionFormat;
  dviDproj := CreateXMLDoc;
  dviDproj.PreserveWhiteSpace := false;
  Assert(XMLLoadFromFile(dviDproj, fileName));
  dviVI := dviDproj.SelectSingleNode('//*/Delphi.Personality/VersionInfo');
  dviVIK := dviDproj.SelectSingleNode('//*/Delphi.Personality/VersionInfoKeys');
  dviPVIK := dviDproj.SelectSingleNode('//*/PropertyGroup[@Condition="''$(Base)''!=''''"]/VerInfo_Keys');
  if not assigned(dviPVIK) then
    dviPVIK := dviDproj.SelectSingleNode('//*/PropertyGroup[@Condition="''$(Base_Win32)''!=''''"]/VerInfo_Keys');
  if (not assigned(dviPVIK)) or (not HasVersionInfo) then begin
    dviPVIK := dviDproj.SelectSingleNode('//*/PropertyGroup/VerInfo_IncludeVerInfo');
    if assigned(dviPVIK) then
      dviPVIK := dviPVIK.ParentNode.SelectSingleNode('VerInfo_Keys');
  end;
  if assigned(dviPVIK) then
    dviVIL := dviPVIK.SelectSingleNode('../VerInfo_Locale');
  dviManifest := dviDproj.SelectSingleNode('//*/PropertyGroup[@Condition="''$(Cfg_1_Win32)''!=''''"]/Manifest_File');
  if not assigned(dviManifest) then
    dviManifest := dviDproj.SelectSingleNode('//*/PropertyGroup/Manifest_File');
  dviPVIKList := TStringList.Create;
  dviPVIKList.Delimiter := ';';
  dviPVIKList.StrictDelimiter := true;
  dviPVIKList.DelimitedText := CollectVerInfoKeys;
end; { TGpDPROJVersionInfo.Create }

destructor TGpDPROJVersionInfo.Destroy;
var
  strDProj: TGpHugeFileStream;
begin
  if dviModified then begin
    strDProj := TGpHugeFileStream.Create(dviFileName, accWrite, [hfoBuffered, hfoCanCreate],
      CAutoShareMode, 5000, 200);
    try
      strDProj.WriteAnsiStr(StringReplace(XMLSaveToAnsiString(dviDproj, ofIndent),
        AnsiString('&apos;'), AnsiString(''''), [rfReplaceAll]));
    finally FreeAndNil(strDProj) end;
  end;
  FreeAndNil(dviPVIKList);
  inherited;
end; { TGpDPROJVersionInfo.Destroy }

function TGpDPROJVersionInfo.CollectVerInfoKeys: string;
var
  i       : integer;
  keyDict : TStringList;
  keyValue: string;
  name    : string;
  node    : IXMLNode;
  nodeDict: TStringList;
  value   : string;
begin
  keyDict := TStringList.Create;
  try
    for node in XMLEnumNodes(dviDproj, '//*/PropertyGroup/VerInfo_Keys') do begin
      nodeDict := TStringList.Create;
      try
        nodeDict.Delimiter := ';';
        nodeDict.StrictDelimiter := true;
        nodeDict.DelimitedText := GetNodeText(node);
        for i := 0 to nodeDict.Count - 1 do begin
          name := nodeDict.Names[i];
          value := nodeDict.ValueFromIndex[i];
          if value = '' then
            value := #127; //TStringList.Values doesn't like empty strings
          keyValue := keyDict.Values[name];
          if ((keyValue = '') or (keyValue = #127)) and (not value.Contains('$(')) then
            keyDict.Values[name] := value;
        end;
      finally FreeAndNil(nodeDict); end;
    end;
    for i := 1 to 5 do
      keyDict.Values['Key'+IntToStr(i)] := '';
    keyDict.Delimiter := ';';
    Result := StringReplace(keyDict.DelimitedText, #127, '', [rfReplaceAll]);
  finally FreeAndNil(keyDict); end;
end; { TGpDPROJVersionInfo.CollectVerInfoKeys }

function TGpDPROJVersionInfo.GetCodePage: word;
begin
  Result := StrToIntDef(GetNodeText(dviVI.SelectSingleNode('VersionInfo[@Name="CodePage"]')), $0409);
end; { TGpDPROJVersionInfo.GetCodePage }

function TGpDPROJVersionInfo.GetComment: string;
begin
  Result := GetVersionInfoKey('Comments');
end; { TGpDPROJVersionInfo.GetComment }

function TGpDPROJVersionInfo.GetCompanyName: string;
begin
  Result := GetVersionInfoKey('CompanyName');
end; { TGpDPROJVersionInfo.GetCompanyName }

function TGpDPROJVersionInfo.GetIsDebug: boolean;
begin
  Result := XMLStrToBoolDef(LowerCase(GetNodeText(dviVI.SelectSingleNode('VersionInfo[@Name="Debug"]'))), false);
end; { TGpDPROJVersionInfo.GetIsDebug }

function TGpDPROJVersionInfo.GetIsPrerelease: boolean;
begin
  Result := XMLStrToBoolDef(LowerCase(GetNodeText(dviVI.SelectSingleNode('VersionInfo[@Name="PreRelease"]'))), false);
end; { TGpDPROJVersionInfo.GetIsPrerelease }

function TGpDPROJVersionInfo.GetIsPrivateBuild: boolean;
begin
  Result := XMLStrToBoolDef(LowerCase(GetNodeText(dviVI.SelectSingleNode('VersionInfo[@Name="Private"]'))), false);
end; { TGpDPROJVersionInfo.GetIsPrivateBuild }

function TGpDPROJVersionInfo.GetIsSpecialBuild: boolean;
begin
  Result := XMLStrToBoolDef(LowerCase(GetNodeText(dviVI.SelectSingleNode('VersionInfo[@Name="Special"]'))), false);
end; { TGpDPROJVersionInfo.GetIsSpecialBuild }

function TGpDPROJVersionInfo.GetLocale: word;
begin
  if assigned(dviVIL) then
    Result := StrToInt(GetNodeText(dviVIL))
  else
    Result := StrToInt(GetNodeText(dviVI.SelectSingleNode('VersionInfo[@Name="Locale"]')));
end; { TGpDPROJVersionInfo.GetLocale }

function TGpDPROJVersionInfo.GetManifestName: string;
begin
  Result := GetNodeText(dviManifest);
end; { TGpDPROJVersionInfo.GetManifestName }

function TGpDPROJVersionInfo.GetProductName: string;
begin
  Result := GetVersionInfoKey('ProductName');
end; { TGpDPROJVersionInfo.GetProductName }

function TGpDPROJVersionInfo.GetVersion: IVersion;
var
  productVersion: IVersion;
  verInfoVersion: IVersion;
  versionInfo   : IVersion;
begin
  Result := StrToVer(dviPVIKList.Values['FileVersion'], verFullDotted);
  if assigned(dviVIK) then begin
    verInfoVersion := StrToVer(
      GetNodeText(dviVIK.SelectSingleNode('VersionInfoKeys[@Name="FileVersion"]')),
      verFullDotted);
    if verInfoVersion.AsInt64 > Result.AsInt64 then
      Result := verInfoVersion;
  end;
  if assigned(dviVI) then begin
    versionInfo := CreateVersion.SetAsWords(
      XMLStrToInt(GetNodeText(dviVI.SelectSingleNode('VersionInfo[@Name="MajorVer"]'))),
      XMLStrToInt(GetNodeText(dviVI.SelectSingleNode('VersionInfo[@Name="MinorVer"]'))),
      XMLStrToInt(GetNodeText(dviVI.SelectSingleNode('VersionInfo[@Name="Release"]'))),
      XMLStrToInt(GetNodeText(dviVI.SelectSingleNode('VersionInfo[@Name="Build"]')))
    );
    if versionInfo.AsInt64 > Result.AsInt64 then
      Result := versionInfo;
  end;
  if dviProductVersionFormat <> '' then begin
    productVersion := StrToVer(dviPVIKList.Values['PlatformVersion'], dviProductVersionFormat);
    if productVersion.AsInt64 > Result.AsInt64 then
      Result := productVersion;
    if assigned(dviVIK) then begin
      productVersion := StrToVer(
        GetNodeText(dviVIK.SelectSingleNode('VersionInfoKeys[@Name="ProductVersion"]')),
        dviProductVersionFormat);
      if productVersion.AsInt64 > Result.AsInt64 then
        Result := productVersion;
    end;
  end;
end; { TGpDPROJVersionInfo.GetVersion }

function TGpDPROJVersionInfo.GetVersionInfoKey(const keyName: string): string;
begin
  Result := dviPVIKList.Values[keyName];
  if (Result = '') and assigned(dviVIK) then
    Result := GetNodeText(dviVIK.SelectSingleNode(Format('VersionInfoKeys[@Name="%s"]', [keyName])));
end; { TGpDPROJVersionInfo.GetVersionInfoKey }

function TGpDPROJVersionInfo.HasVersionInfo: boolean;
var
  sVerInfo: string;
  verInfo : IXMLNode;
begin
  Result := false;
  sVerInfo := '';
  if assigned(dviPVIK) then begin
    verInfo := dviPVIK.SelectSingleNode('../VerInfo_IncludeVerInfo');
    if assigned(verInfo) then
      sVerInfo := GetNodeText(verInfo);
  end;
  if (sVerInfo = '') and assigned(dviVI) then
    sVerInfo := GetNodeText(dviVI.SelectSingleNode('VersionInfo[@Name="IncludeVerInfo"]'));
  if sVerInfo <> '' then
    Result := XMLStrToBool(LowerCase(sVerInfo));
end; { TGpDPROJVersionInfo.HasVersionInfo }

procedure TGpDPROJVersionInfo.SetAllNodes(const path: string; value: string);
var
  node: IXMLNode;
begin
  for node in XMLEnumNodes(dviDProj, path) do
    SetTextChild(node, value);
end; { TGpDPROJVersionInfo.SetAllNodes }

procedure TGpDPROJVersionInfo.SetCodePage(value: word);
begin
  SetTextChild(dviVI.SelectSingleNode('VersionInfo[@Name="CodePage"]'), IntToStr(value));
  dviModified := true;
end; { TGpDPROJVersionInfo.SetCodePage }

procedure TGpDPROJVersionInfo.SetComment(const comment: string);
begin
  SetVersionInfoKey('Comments', comment);
  dviModified := true;
end; { TGpDPROJVersionInfo.SetComment }

procedure TGpDPROJVersionInfo.SetCompanyName(const companyName: string);
begin
  SetVersionInfoKey('CompanyName', companyName);
  dviModified := true;
end; { TGpDPROJVersionInfo.SetCompanyName }

procedure TGpDPROJVersionInfo.SetIsDebug(isDebug: boolean);
begin
  SetTextChild(dviVI.SelectSingleNode('VersionInfo[@Name="Debug"]'), XMLBoolToStr(isDebug, true));
  dviModified := true;
end; { TGpDPROJVersionInfo.SetIsDebug }

procedure TGpDPROJVersionInfo.SetIsPrerelease(isPrerelease: boolean);
begin
  SetTextChild(dviVI.SelectSingleNode('VersionInfo[@Name="PreRelease"]'), XMLBoolToStr(isPrerelease, true));
  dviModified := true;
end; { TGpDPROJVersionInfo.SetIsPrerelease }

procedure TGpDPROJVersionInfo.SetIsPrivateBuild(isPrivateBuild: boolean);
begin
  SetTextChild(dviVI.SelectSingleNode('VersionInfo[@Name="Private"]'), XMLBoolToStr(isPrivateBuild, true));
  dviModified := true;
end; { TGpDPROJVersionInfo.SetIsPrivateBuild }

procedure TGpDPROJVersionInfo.SetIsSpecialBuild(isSpecialBuild: boolean);
begin
  SetTextChild(dviVI.SelectSingleNode('VersionInfo[@Name="Special"]'), XMLBoolToStr(isSpecialBuild, true));
  dviModified := true;
end; { TGpDPROJVersionInfo.SetIsSpecialBuild }

procedure TGpDPROJVersionInfo.SetLocale(value: word);
begin
  if assigned(dviVIL) then
    SetTextChild(dviVIL, IntToStr(value))
  else
    SetTextChild(dviVI.SelectSingleNode('VersionInfo[@Name="Locale"]'), IntToStr(value));
  dviModified := true;
end; { TGpDPROJVersionInfo.SetLocale }

procedure TGpDPROJVersionInfo.SetProductName(const productName: string);
begin
  SetVersionInfoKey('ProductName', productName);
end; { TGpDPROJVersionInfo.SetProductName }

procedure TGpDPROJVersionInfo.SetVersion(version: IVersion);
begin
  if assigned(dviPVIK) then begin
    dviPVIKList.Values['FileVersion'] := VerToStr(version, verFullDotted);
    if dviProductVersionFormat <> '' then
      dviPVIKList.Values['ProductVersion'] := VerToStr(version, dviProductVersionFormat);
    SetAllNodes('//*/PropertyGroup/VerInfo_Keys', dviPVIKList.DelimitedText);
    SetAllNodes('//*/PropertyGroup/VerInfo_IncludeVerInfo', 'true');
  end;
  if assigned(dviVIK) then
    SetTextChild(dviVIK.SelectSingleNode('VersionInfoKeys[@Name="FileVersion"]'), VerToStr(version, verFullDotted));
  if assigned(dviVI) then begin
    SetTextChild(dviVI.SelectSingleNode('VersionInfo[@Name="MajorVer"]'), IntToStr(version.AsWords[0]));
    SetTextChild(dviVI.SelectSingleNode('VersionInfo[@Name="MinorVer"]'), IntToStr(version.AsWords[1]));
    SetTextChild(dviVI.SelectSingleNode('VersionInfo[@Name="Release"]'), IntToStr(version.AsWords[2]));
    SetTextChild(dviVI.SelectSingleNode('VersionInfo[@Name="Build"]'), IntToStr(version.AsWords[3]));
  end;
  if (dviProductVersionFormat <> '') and assigned(dviVIK) then
    SetTextChild(dviVIK.SelectSingleNode('VersionInfoKeys[@Name="ProductVersion"]'),
      VerToStr(version, dviProductVersionFormat));
  dviModified := true;
end; { TGpDPROJVersionInfo.SetVersion }

procedure TGpDPROJVersionInfo.SetVersionInfoKey(const keyName, value: string);
var
  verInfoNode: IXMLNode;
begin
  if assigned(dviPVIK) then begin
    dviPVIKList.Values[keyName] := value;
    for verInfoNode in XMLEnumNodes(dviDproj, '//*/PropertyGroup/VerInfo_IncludeVerInfo["true"]/../VerInfo_Keys') do
      SetTextChild(dviPVIK, dviPVIKList.DelimitedText);
  end;
  SetTextChild(dviVIK.SelectSingleNode(Format('VersionInfoKeys[@Name="%s"]', [keyName])), value);
  dviModified := true;
end; { TGpDPROJVersionInfo.SetVersionInfoKey }

end.

