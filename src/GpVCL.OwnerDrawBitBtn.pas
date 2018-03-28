unit GpVCL.OwnerDrawBitBtn;

interface

uses
  Winapi.Messages, Winapi.Windows,
  System.Classes,
  Vcl.Themes, Vcl.Graphics, Vcl.Controls, Vcl.Buttons;

type
  TOwnerDrawBitBtn = class(Vcl.Buttons.TBitBtn)
  public type
    TOwnerDrawEvent = reference to procedure (button: TOwnerDrawBitBtn; canvas: TCanvas;
      drawRect: TRect; buttonState: TThemedButton);
  strict private
    FCanvas        : TCanvas;
    FDetails       : TThemedElementDetails;
    FIsFocused     : boolean;
    FMouseInControl: boolean;
    FOnOwnerDraw   : TOwnerDrawEvent;
    FState         : TButtonState;
  strict protected
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure CNDrawItem(var Message: TWMDrawItem); message CN_DRAWITEM;
    procedure DoDrawText(DC: HDC; const text: string;
      var textRect: TRect; textFlags: Cardinal);
    procedure DrawItem(const DrawItemStruct: TDrawItemStruct);
  protected
    procedure SetButtonStyle(ADefault: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
    procedure DrawText(const value: string; textBounds: TRect;
  textFlags: longint);
    property OnOwnerDraw: TOwnerDrawEvent read FOnOwnerDraw write FOnOwnerDraw;
  end;

  TBitBtn = class(TOwnerDrawBitBtn)
  end;

implementation

uses
  System.Types, System.SysUtils;

{ TOwnerDrawBitBtn }

procedure TOwnerDrawBitBtn.CMMouseEnter(var Message: TMessage);
begin
  FMouseInControl := true;
  inherited;
end;

procedure TOwnerDrawBitBtn.CMMouseLeave(var Message: TMessage);
begin
  FMouseInControl := false;
  inherited;
end;

procedure TOwnerDrawBitBtn.CNDrawItem(var Message: TWMDrawItem);
begin
  if assigned(OnOwnerDraw) then
    DrawItem(Message.DrawItemStruct^)
  else
    inherited;
end;

constructor TOwnerDrawBitBtn.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCanvas := TCanvas.Create;
end;

destructor TOwnerDrawBitBtn.Destroy;
begin
  FreeAndNil(FCanvas);
  inherited;
end;

procedure TOwnerDrawBitBtn.DrawItem(const DrawItemStruct: TDrawItemStruct);
var
  buttonState: TThemedButton;
  flags      : longint;
  isDown     : boolean;
  isDefault  : boolean;
  rect       : TRect;
  styleSvc   : TCustomStyleServices;
begin
  FCanvas.Handle := DrawItemStruct.hDC;
  rect := ClientRect;

  with DrawItemStruct do begin
    FCanvas.Handle := hDC;
    FCanvas.Font := Self.Font;
    isDown := itemState and ODS_SELECTED <> 0;
    isDefault := itemState and ODS_FOCUS <> 0;

    if not Enabled then
      FState := bsDisabled
    else if isDown then
      FState := bsDown
    else
      FState := bsUp;
  end;

  if not Enabled then
    buttonState := tbPushButtonDisabled
  else if IsDown then
    buttonState := tbPushButtonPressed
  else if FMouseInControl then
    buttonState := tbPushButtonHot
  else if FIsFocused or isDefault then
    buttonState := tbPushButtonDefaulted
  else
    buttonState := tbPushButtonNormal;

  if ThemeControl(Self) then begin
    styleSvc := StyleServices;

    FDetails := styleSvc.GetElementDetails(buttonState);
    // Parent background.
    if not (csGlassPaint in ControlState) then
      styleSvc.DrawParentBackground(Handle, DrawItemStruct.hDC, FDetails, True)
    else
      FillRect(DrawItemStruct.hDC, rect, GetStockObject(BLACK_BRUSH));
    // buttonState shape.
    styleSvc.DrawElement(DrawItemStruct.hDC, FDetails, DrawItemStruct.rcItem);
    styleSvc.GetElementContentRect(FCanvas.Handle, FDetails, DrawItemStruct.rcItem, rect);

    if assigned(OnOwnerDraw) then
      OnOwnerDraw(Self, FCanvas, ClientRect, buttonState);

    if FIsFocused and isDefault and styleSvc.IsSystemStyle then begin
      FCanvas.Pen.Color := clWindowFrame;
      FCanvas.Brush.Color := clBtnFace;
      DrawFocusRect(FCanvas.Handle, rect);
    end;
  end
  else begin
    rect := ClientRect;

    flags := DFCS_BUTTONPUSH or DFCS_ADJUSTRECT;
    if IsDown then
      flags := flags or DFCS_PUSHED;
    if DrawItemStruct.itemState and ODS_DISABLED <> 0 then
      flags := flags or DFCS_INACTIVE;

    { DrawFrameControl doesn't allow for drawing a button as the
        default buttonState, so it must be done here. }
    if FIsFocused or isDefault then begin
      FCanvas.Pen.Color := clWindowFrame;
      FCanvas.Pen.Width := 1;
      FCanvas.Brush.Style := bsClear;
      FCanvas.Rectangle(rect.Left, rect.Top, rect.Right, rect.Bottom);

      { DrawFrameControl must draw within this border }
      InflateRect(rect, -1, -1);
    end;

    { DrawFrameControl does not draw a pressed buttonState correctly }
    if isDown then begin
      FCanvas.Pen.Color := clBtnShadow;
      FCanvas.Pen.Width := 1;
      FCanvas.Brush.Color := clBtnFace;
      FCanvas.Rectangle(rect.Left, rect.Top, rect.Right, rect.Bottom);
      InflateRect(rect, -1, -1);
    end
    else
      DrawFrameControl(DrawItemStruct.hDC, rect, DFC_BUTTON, flags);

    if FIsFocused then begin
      rect := ClientRect;
      InflateRect(rect, -1, -1);
    end;

    FCanvas.Font := Self.Font;
    if isDown then
      OffsetRect(rect, 1, 1);

    if assigned(FOnOwnerDraw) then
      OnOwnerDraw(Self, FCanvas, rect, buttonState);

    if FIsFocused and isDefault then begin
      rect := ClientRect;
      InflateRect(rect, -4, -4);
      FCanvas.Pen.Color := clWindowFrame;
      FCanvas.Brush.Color := clBtnFace;
      DrawFocusRect(FCanvas.Handle, rect);
    end;
  end;

  FCanvas.Handle := 0;
end;

procedure TOwnerDrawBitBtn.DoDrawText(DC: HDC; const Text: string;
  var textRect: TRect; textFlags: Cardinal);
var
  textColor  : TColor;
  textFormats: TTextFormat;
begin
  if ThemeControl(Self) then begin
    if (FState = bsDisabled) or (not StyleServices.IsSystemStyle and (seFont in StyleElements)) then
    begin
      if not StyleServices.GetElementColor(FDetails, ecTextColor, textColor) or (textColor = clNone) then
        textColor := FCanvas.Font.Color;
    end
    else
      textColor := FCanvas.Font.Color;

    textFormats := TTextFormatFlags(textFlags);
    if csGlassPaint in ControlState then
      Include(textFormats, tfComposited);
    StyleServices.DrawText(DC, FDetails, text, textRect, textFormats, textColor);
  end
  else
    Winapi.Windows.DrawText(DC, text, Length(text), textRect, textFlags);
end;

procedure TOwnerDrawBitBtn.DrawText(const value: string; textBounds: TRect;
  textFlags: longint);
const
  wordBreakFlag: array[Boolean] of longint = (0, DT_WORDBREAK);
var
  flags: Longint;
begin
  if ThemeControl(Self) then begin
    Brush.Style := bsClear;
    DoDrawText(FCanvas.Handle, Caption, textBounds, textFlags OR
      DrawTextBiDiModeFlags(0) OR wordBreakFlag[WordWrap]);
  end
  else begin
    flags := DrawTextBiDiModeFlags(0) or wordBreakFlag[WordWrap];
    Brush.Style := bsClear;
    if (FState = bsDisabled) then begin
      OffsetRect(textBounds, 1, 1);
      Font.Color := clBtnHighlight;
      DoDrawText(FCanvas.Handle, Caption, textBounds, textFlags OR flags);
      OffsetRect(textBounds, -1, -1);
      Font.Color := clBtnShadow;
      DoDrawText(FCanvas.Handle, Caption, textBounds, textFlags OR flags);
    end
    else
      DoDrawText(FCanvas.Handle, Caption, textBounds, textFlags OR flags);
  end;
end;

procedure TOwnerDrawBitBtn.SetButtonStyle(ADefault: Boolean);
begin
  inherited SetButtonStyle(ADefault);
  FIsFocused := ADefault;
end;

end.
