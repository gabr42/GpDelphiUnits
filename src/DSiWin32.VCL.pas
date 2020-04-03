(*:Parts of DSiWin32 that are bound to VCL namespace.
   @desc <pre>
   Free for personal and commercial use. No rights reserved.

   Maintainer        : gabr
   Contributors      : aoven,
   Creation date     : 2020-04-03
   Last modification : 2020-04-03
   Version           : 1.0
</pre>*)(*
   History:
     1.0: 2020-04-03
       - Moved here code from DSiWin32.
*)

unit DSiWin32.VCL;

{$IFDEF ConditionalExpressions}
  {$IF CompilerVersion >= 23}{$DEFINE DSiScopedUnitNames}{$IFEND}
{$ENDIF}

interface

uses
  {$IFDEF DSiScopedUnitNames}Vcl.Graphics{$ELSE}Graphics{$ENDIF},
  DSiWin32;

type
  TDSiRegistry = class(DSiWin32.TDSiRegistry)
  public
    function  ReadFont(const name: string; font: TFont): boolean;
    procedure WriteFont(const name: string; font: TFont);
  end; { TDSiRegistry }

function  DSiInitFontToSystemDefault(aFont: TFont; aElement: TDSiUIElement): boolean;

implementation

uses
  {$IFDEF DSiScopedUnitNames}System.UITypes,{$ENDIF}
  {$IFDEF DSiScopedUnitNames}Winapi.Windows{$ELSE}Windows{$ENDIF},
  {$IFDEF DSiScopedUnitNames}System.SysUtils{$ELSE}SysUtils{$ENDIF};

{ TDSiRegistry }

{:Reads TFont from the registry.
  @author  gabr
  @since   2002-11-25
}
function TDSiRegistry.ReadFont(const name: string; font: TFont): boolean;
var
  istyle: integer;
  fstyle: TFontStyles;
begin
  Result := false;
  if GetDataSize(name) > 0 then begin
    font.Charset := ReadInteger(name+'_charset', font.Charset);
    font.Color   := ReadInteger(name+'_color', font.Color);
    font.Height  := ReadInteger(name+'_height', font.Height);
    font.Name    := ReadString(name, font.Name);
    font.Pitch   := TFontPitch(ReadInteger(name+'_pitch', Ord(font.Pitch)));
    font.Size    := ReadInteger(name+'_size', font.Size);
    fstyle := font.Style;
    istyle := 0;
    Move(fstyle, istyle, SizeOf(TFontStyles));
    istyle := ReadInteger(name+'_style', istyle);
    Move(istyle, fstyle, SizeOf(TFontStyles));
    font.Style := fstyle;
    Result := true;
  end;
end; { TDSiRegistry.ReadFont }

{:Writes TFont into the registry.
  @author  gabr
  @since   2002-11-25
}
procedure TDSiRegistry.WriteFont(const name: string; font: TFont);
var
  istyle: integer;
  fstyle: TFontStyles;
begin
  WriteInteger(name+'_charset', font.Charset);
  WriteInteger(name+'_color', font.Color);
  WriteInteger(name+'_height', font.Height);
  WriteString(name, font.Name);
  WriteInteger(name+'_pitch', Ord(font.Pitch));
  WriteInteger(name+'_size', font.Size);
  fstyle := font.Style;
  istyle := 0;
  Move(fstyle, istyle, SizeOf(TFontStyles));
  WriteInteger(name+'_style', istyle);
end; { TDSiRegistry.WriteFont }

{ exported }

{:Initializes font to the metrics of a specific GUI element.
  @author  aoven
  @since   2007-11-13
}
function DSiInitFontToSystemDefault(aFont: TFont; aElement: TDSiUIElement): boolean;
var
  NCM: TNonClientMetrics;
  PLF: PLogFont;
begin
  Result := false;
  NCM.cbSize := {$IFDEF Unicode}
    {$IF CompilerVersion = 20} //D2009
      SizeOf(TNonClientMetrics)
    {$ELSE}
      TNonClientMetrics.SizeOf
    {$IFEND}
  {$ELSE}
    SizeOf(TNonClientMetrics)
  {$ENDIF};
  if SystemParametersInfo(SPI_GETNONCLIENTMETRICS, 0, @NCM, 0) then begin
    case aElement of
      ueMenu:          PLF := @NCM.lfMenuFont;
      ueMessage:       PLF := @NCM.lfMessageFont;
      ueWindowCaption: PLF := @NCM.lfCaptionFont;
      ueStatus:        PLF := @NCM.lfStatusFont;
      else raise Exception.Create('Unexpected GUI element');
    end;
    aFont.Handle := CreateFontIndirect(PLF^);
    Result := true;
  end;
end; { DSiInitFontToSystemDefault }

end.
