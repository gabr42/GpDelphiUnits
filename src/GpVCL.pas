(*:VCL helper library.
   @author Primoz Gabrijelcic
   @desc <pre>
   (c) 2018 Primoz Gabrijelcic
   Free for personal and commercial use. No rights reserved.

   Author            : Primoz Gabrijelcic
   Creation date     : 2003-12-11
   Last modification : 2018-03-15
   Version           : 1.24
</pre>*)(*
   History:
     1.24: 2018-03-15
       - Implemented SaveCanvasToFile and TCanvasHelper.SaveToFile.
     1.23a: 2017-09-26
       - Fixed ChangeExtensionOnTypeChange when file name in dialog is empty.
     1.23: 2017-05-29
       - Added optional list parameter to DisableControls(array of TControl)
         and EnableControls(array of TControl) overloads.
     1.22: 2017-02-03
       - Implemented RemapPtToControl.
     1.21: 2016-12-07
       - Implemented ChangeExtensionOnTypeChange.
     1.20: 2016-12-01
       - Implemented GetFormTextFromResource.
     1.19: 2015-07-07
       - Control and component enumerators support recursive enumeration.
     1.18: 2015-05-07
       - Implemented AutoRestoreCursor.
     1.17: 2015-01-21
       - Implemented TComponentEnumeratorFactory<T> and EnumComponents helpers.
     1.16: 2014-12-15
       - Added EnableChildControls overload which can enable or disable controls.
       - Fixed accvio in EnableChildControls/DisableChildControls when a list parameter
         wasn't assigned.
     1.15: 2014-06-18
       - Implemented class helper for TWinControl supporting control enumeration.
     1.14: 2013-12-05
       - Better way to redraw a window in EnableRedraw (works with forms and MDI children).
     1.13: 2013-11-11
       - Added DisableRedraw and EnableRedraw.
     1.12: 2013-11-06
       - Added BrowseForFolder.
     1.11: 2013-05-23
       - Added action enumerators.
     1.10: 2011-04-20
       - Added bunch of EnableControls/DisableControls overloads.
       - Added bunch of overloaded ShowControls/HideControls functions.
     1.09a: 2008-02-06
       - Changed TControlEnumeratorFactory to a record. That way, no reference counting on
         the interface is required and code is shorter. Thanks to Fredrik Loftheim for
         the suggestion.
     1.09: 2008-01-23
       - Added TWinControl.Controls enumerator.
     1.08: 2007-10-26
       - Added methods ControlByClass and ControlsByClass.
     1.07: 2004-04-19
       - Added methods DisableChildControls, EnableChildControls, DisableControls,
         EnableControls.
     1.06: 2004-04-08
       - Added parameter SkipFirstN to ControlByTag and ComponentByTag.
     1.05: 2004-03-10
       - Added function CanAllocateHandle.
     1.04: 2004-03-09
       - Added support for .Lines property. 
     1.03: 2004-02-08
       - Added support for .Checked property.
     1.02: 2004-01-17
       - Added two overloaded methods ComponentByTag. 
     1.01: 2003-12-24
       - Added methods ContainsNonemptyControl and SameControlsAndProperties.  
     1.0: 2003-12-11
       - Released.
*)

unit GpVCL;

interface

uses
  Windows,
  Messages,
  Types,
  SysUtils,
  Classes,
  Graphics,
  Controls,
  StdCtrls,
  Contnrs,
  Dialogs,
  Forms,
  ActnList,
  GpStuff,
  GpAutoCreate;

{$IFDEF ConditionalExpressions}
  {$IF CompilerVersion >= 20} //D2009+
    {$DEFINE GpVCL_Anonymous}
  {$IFEND}
{$ENDIF}

type
  TControlEnumerator = record
  strict private
    ceClass        : TClass;
    ceIndex        : integer;
    ceParent       : TWinControl;
    ceRecursive    : boolean;
    ceControls     : TList; //of TControl
    ceControlsGuard: IGpAutoDestroyObject;
    procedure BuildControlList(parent: TWinControl);
  public
    constructor Create(parent: TWinControl; matchClass: TClass; recursive: boolean = false);
    function  GetCurrent: TControl;
    function  MoveNext: boolean;
    property Current: TControl read GetCurrent;
  end; { TControlEnumerator }

  TControlEnumeratorFactory = record
  strict private
    cefClass    : TClass;
    cefParent   : TWinControl;
    cefRecursive: boolean;
  public
    constructor Create(parent: TWinControl; matchClass: TClass; recursive: boolean = false);
    function  GetEnumerator: TControlEnumerator;
  end; { TControlEnumeratorFactory }

  TControlEnumeratorFactory<T:TControl> = record
  strict private
    FIndex        : integer;
    FParent       : TWinControl;
    FRecursive    : boolean;
    FControls     : TList; //of TControl
    FControlsGuard: IGpAutoDestroyObject;
    procedure BuildControlList(parent: TWinControl);
  public
    constructor Create(parent: TWinControl; recursive: boolean = false);
    function  GetCurrent: T;
    function  GetEnumerator: TControlEnumeratorFactory<T>;
    function  MoveNext: boolean;
    property Current: T read GetCurrent;
  end; { TControlEnumeratorFactory<T> }

  TComponentEnumeratorFactory<T:TComponent> = record
  strict private
    FIndex          : integer;
    FParent         : TWinControl;
    FRecursive      : boolean;
    FComponents     : TList; //of TComponent
    FComponentsGuard: IGpAutoDestroyObject;
    procedure BuildComponentList(parent: TWinControl);
  public
    constructor Create(parent: TWinControl; recursive: boolean = false);
    function  GetCurrent: T;
    function  GetEnumerator: TComponentEnumeratorFactory<T>;
    function  MoveNext: boolean;
    property Current: T read GetCurrent;
  end; { TControlEnumeratorFactory<T> }

  TScrollBar = class(StdCtrls.TScrollBar)
  strict protected
    function  GetWinPageSize: integer;
    procedure SetWinPageSize(const value: integer);
  public
    property WinPageSize: integer read GetWinPageSize write SetWinPageSize;
  end; { TScrollBar }

  TGpManagedFrame = class(TFrame)
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
  end; { TGpManagedFrame }

  TGpManagedForm = class(TForm)
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
  end; { TGpManagedForm }

function  ContainsNonemptyControl(controlParent: TWinControl;
  const requiredControlNamePrefix: string; const ignoreControls: string = ''): boolean;
procedure CopyControlsToProperties(sourceParent: TWinControl;
  targetObj: TPersistent; const removePrefixFromControls: string);
procedure CopyPropertiesToControls(sourceObj: TPersistent;
  targetParent: TWinControl; const prefixControlsWith: string);
function  SameControlsAndProperties(controlParent: TWinControl;
  compareObj: TPersistent; const removePrefixFromControls: string): boolean;

function  ControlByTag(parent: TWinControl; tag: integer;
  searchInSubcontrols: boolean = true): TControl; overload;
function  ControlByTag(parent: TWinControl; tag: integer; searchInSubcontrols: boolean;
  allowOnly: array of TControlClass): TControl; overload;
function  ControlByTag(parent: TWinControl; tag: integer; searchInSubcontrols: boolean;
  allowOnly: array of TControlClass; skipFirstN: integer): TControl; overload;

function  ControlByClass(parent: TWinControl; controlClass: TClass;
  controlIndex: integer = 1): TControl;

procedure ControlsByClass(parent: TWinControl; controlClass: TClass;
  controls: TObjectList);

function  ComponentByTag(parent: TComponent; tag: integer;
  searchInSubcomponents: boolean = true): TComponent; overload;
function  ComponentByTag(parent: TComponent; tag: integer; searchInSubcomponents: boolean;
  allowOnly: array of TComponentClass): TComponent; overload;
function  ComponentByTag(parent: TComponent; tag: integer; searchInSubcomponents: boolean;
  allowOnly: array of TComponentClass; skipFirstN: integer): TComponent; overload;

function  CanAllocateHandle(control: TWinControl): boolean;

procedure DisableChildControls(parent: TWinControl; disabledList: TList = nil);
procedure EnableChildControls(parent: TWinControl; enabledList: TList = nil); overload;
procedure EnableChildControls(parent: TWinControl; enable: boolean; enabledList: TList = nil); overload;
procedure DisableControls(controlList: TList); overload;
procedure EnableControls(controlList: TList); overload;
procedure EnableControls(controlList: TList; enable: boolean); overload;
procedure DisableControls(const controlList: array of TControl; disabledList: TList = nil); overload;
procedure EnableControls(const controlList: array of TControl; enabledList: TList = nil); overload;
procedure EnableControls(const controlList: array of TControl; enable: boolean; enabledList: TList = nil); overload;

procedure HideControls(controlList: TList); overload;
procedure ShowControls(controlList: TList); overload;
procedure ShowControls(controlList: TList; show: boolean); overload;
procedure HideControls(const controlList: array of TControl); overload;
procedure ShowControls(const controlList: array of TControl); overload;
procedure ShowControls(const controlList: array of TControl; show: boolean); overload;

procedure DisableRedraw(control: TWinControl); overload; inline;
procedure DisableRedraw(controls: array of TWinControl); overload;
procedure EnableRedraw(control: TWinControl; forceRepaint: boolean = true); overload;
procedure EnableRedraw(controls: array of TWinControl; forceRepaint: boolean = true); overload;

type
  IActionEnumerator = interface
    function  GetCurrent: TAction;
    function  MoveNext: boolean;
    property Current: TAction read GetCurrent;
  end; { IActionEnumerator }

  IActionEnumeratorFactory = interface
    function  GetEnumerator: IActionEnumerator;
  end; { IActionEnumeratorFactory }

function  EnumControls(parent: TWinControl; matchClass: TClass = nil; recursive: boolean = false): TControlEnumeratorFactory;
function  EnumActions(actionList: TActionList; filter: TPredicate<TAction> = nil): IActionEnumeratorFactory; overload;
function  EnumActions(actionList: TActionList; const category: string): IActionEnumeratorFactory; overload;

function BrowseForFolder(const ATitle: string; var SelectedFolder: string): boolean;

type
  TWinControlEnumerator = class helper for TWinControl
  public
    function  EnumComponents(recursive: boolean = false): TComponentEnumeratorFactory<TComponent>; overload;
    function  EnumComponents<T: TComponent>(recursive: boolean = false): TComponentEnumeratorFactory<T>; overload;
    function  EnumControls(recursive: boolean = false): TControlEnumeratorFactory<TControl>; overload;
    function  EnumControls<T:TControl>(recursive: boolean = false): TControlEnumeratorFactory<T>; overload;
  end; { TWinControlEnumerator }

{$IFDEF GpVCL_Anonymous}
function AutoRestoreCursor(newCursor: TCursor): IGpAutoExecute;
{$ENDIF GpVCL_Anonymous}

function GetFormTextFromResource(const formName: string): string; overload;
function GetFormTextFromResource(const formClass: TClass): string; overload;
function GetFormTextFromResource(const form: TCustomForm): string; overload;

procedure ChangeExtensionOnTypeChange(saveDialog: TFileSaveDialog);

function  RemapPtToControl(const pt: TPoint; sourceContext, targetContext: TControl): TPoint;

procedure SaveCanvasToFile(canvas: TCanvas; const fileName: string);

type
  TCanvasHelper = class helper for TCanvas
  public
    procedure SaveToFile(const fileName: string);
  end; { TCanvasHelper }

implementation

uses
  TypInfo,
  FileCtrl,
  ShlObj,
  Themes,
  ActiveX,
  GpProperty;

type
  TActionEnumerator = class(TInterfacedObject, IActionEnumerator)
  strict private
    FActionList: TActionList;
    FFilter    : TPredicate<TAction>;
    FIndex     : integer;
  public
    constructor Create(actionList: TActionList; filter: TPredicate<TAction>);
    function  GetCurrent: TAction;
    function  MoveNext: boolean;
    property Current: TAction read GetCurrent;
  end; { TActionEnumerator }

  TActionEnumeratorFactory = class(TInterfacedObject, IActionEnumeratorFactory)
  strict private
    FActionList: TActionList;
    FFilter    : TPredicate<TAction>;
  public
    constructor Create(actionList: TActionList; filter: TPredicate<TAction>);
    function GetEnumerator: IActionEnumerator;
  end; { TActionEnumeratorFactory }

function Unwrap(s: string; child: TControl): string;
begin
  (* Probably not a good idea to do this for all applications:
  if (not IsPublishedProp(child, 'WordWrap')) or (GetOrdProp(child, 'WordWrap') = 0) then
    Result := s
  else
    Result := TrimRight(StringReplace(s, #13#10, ' ', [rfReplaceAll]));
  *)
  Result := s;
end; { Unwrap }

{:Checks if any control (with name starting with 'requiredControlNamePrefix' and
  not included in the #13#10-delimited 'ignoreControls' list) contains non-empty
  .Text or .Lines property.
  @since   2003-12-24
}
function ContainsNonemptyControl(controlParent: TWinControl;
  const requiredControlNamePrefix: string;
  const ignoreControls: string = ''): boolean;
var
  child   : TControl;
  iControl: integer;
  ignored : TStringList;
  obj     : TObject;
begin
  Result := true;
  if ignoreControls = '' then
    ignored := nil
  else begin
    ignored := TStringList.Create;
    ignored.Text := ignoreControls;
  end;
  try
    for iControl := 0 to controlParent.ControlCount-1 do begin
      child := controlParent.Controls[iControl];
      if (requiredControlNamePrefix = '') or
         SameText(requiredControlNamePrefix, Copy(child.Name, 1, Length(requiredControlNamePrefix))) then
      if (not assigned(ignored)) or (ignored.IndexOf(child.Name) < 0) then
      if IsPublishedProp(child, 'Text') and (GetStrProp(child, 'Text') <> '') then
        Exit
      else if IsPublishedProp(child, 'Lines') then begin
        obj := TObject(cardinal(GetOrdProp(child, 'Lines')));
        if (obj is TStrings) and (Unwrap(TStrings(obj).Text, child) <> '') then
          Exit;
      end;
    end; //for iControl
  finally FreeAndNil(ignored); end;
  Result := false;
end; { ContainsNonemptyControl }

{:Copies data from .Text and .Checked properties to published object properties with the
  same name as the control names (after prefix is removed from the control name).
  @since   2003-12-11
}
procedure CopyControlsToProperties(sourceParent: TWinControl;
  targetObj: TPersistent; const removePrefixFromControls: string);
var
  child     : TControl;
  iProperty : integer;
  obj       : TObject;
  sourceProp: IGpProperty;
begin
  sourceProp := CreateGpProperty(targetObj);
  for iProperty := 0 to sourceProp.Count-1 do begin
    child := sourceParent.FindChildControl(removePrefixFromControls+sourceProp.Name[iProperty]);
    if assigned(child) then begin
      if IsPublishedProp(child, 'Text') then
        sourceProp.StringValue[iProperty] := GetStrProp(child, 'Text')
      else if IsPublishedProp(child, 'Checked') then
        sourceProp.BooleanValue[iProperty] := (GetOrdProp(child, 'Checked') <> 0)
      else if IsPublishedProp(child, 'Lines') then begin
        obj := TObject(cardinal(GetOrdProp(child, 'Lines')));
        if obj is TStrings then
          sourceProp.StringValue[iProperty] := Unwrap(TStrings(obj).Text, child);
      end;
    end;
  end; //for
end; { CopyControlsToProperties }

{:Copies data from published object properties to .Text and .Checked properties of
  controls with the same name as the object properties (after prefix is removed from the
  control name).
  @since   2003-12-11
}
procedure CopyPropertiesToControls(sourceObj: TPersistent;
  targetParent: TWinControl; const prefixControlsWith: string);
var
  child     : TControl;
  iProperty : integer;
  obj       : TObject;
  sourceProp: IGpProperty;
begin
  sourceProp := CreateGpProperty(sourceObj);
  for iProperty := 0 to sourceProp.Count-1 do begin
    child := targetParent.FindChildControl(prefixControlsWith+sourceProp.Name[iProperty]);
    if assigned(child) then begin
      if IsPublishedProp(child, 'Text') then
        SetStrProp(child, 'Text', sourceProp.StringValue[iProperty])
      else if IsPublishedProp(child, 'Checked') then
        SetOrdProp(child, 'Checked', Ord(sourceProp.BooleanValue[iProperty]))
      else if IsPublishedProp(child, 'Lines') then begin
        obj := TObject(cardinal(GetOrdProp(child, 'Lines')));
        if (obj is TStrings) then
          TStrings(obj).Text := sourceProp.StringValue[iProperty];
      end;
    end;
  end; //for
end; { CopyPropertiesToControls }

{:Checks if data in .Text and .Checked properties is the same as in published object
  properties with the same name as the control names (after prefix is removed
  from the control name).
  @since   2003-12-24
}
function SameControlsAndProperties(controlParent: TWinControl;
  compareObj: TPersistent; const removePrefixFromControls: string): boolean;
var
  child     : TControl;
  iProperty : integer;
  obj       : TObject;
  sourceProp: IGpProperty;
begin
  Result := false;
  sourceProp := CreateGpProperty(compareObj);
  for iProperty := 0 to sourceProp.Count-1 do begin
    child := controlParent.FindChildControl(removePrefixFromControls+sourceProp.Name[iProperty]);
    if assigned(child) then begin
      if IsPublishedProp(child, 'Text') and
         (sourceProp.StringValue[iProperty] <> GetStrProp(child, 'Text'))
      then
        Exit;
      if IsPublishedProp(child, 'Checked') and
         (sourceProp.BooleanValue[iProperty] <> (GetOrdProp(child, 'Checked') <> 0))
      then
        Exit;
      if IsPublishedProp(child, 'Lines') then begin
        obj := TObject(cardinal(GetOrdProp(child, 'Lines')));
        if (obj is TStrings) then
          if sourceProp.StringValue[iProperty] <> Unwrap(TStrings(obj).Text, child) then
            Exit;
      end;
    end;
  end; //for
  Result := true;
end; { SameControlsAndProperties }

function ControlByTag(parent: TWinControl; tag: integer; 
  searchInSubcontrols: boolean): TControl;
begin
  Result := ControlByTag(parent, tag, searchInSubcontrols, [nil]);
end; { ControlByTag }

function ControlByTag(parent: TWinControl; tag: integer; searchInSubcontrols: boolean;
  allowOnly: array of TControlClass): TControl; 
begin
  Result := ControlByTag(parent, tag, searchInSubcontrols, allowOnly, 0);
end; { ControlByTag }

function ControlByTag(parent: TWinControl; tag: integer; searchInSubcontrols: boolean;
  allowOnly: array of TControlClass; skipFirstN: integer): TControl;

  function IsAllowed(control: TControl): boolean;
  var
    iAllowed: integer;
  begin
    if (Length(allowOnly) = 0) or ((Length(allowOnly) = 1) and (allowOnly[Low(allowOnly)] = nil)) then
      Result := true
    else begin
      Result := true;
      for iAllowed := Low(allowOnly) to High(allowOnly) do
        if allowOnly[iAllowed] = control.ClassType then
          Exit;
      Result := false;
    end;
  end; { IsAllowed }

var
  iControl: integer;
  
begin { ControlByTag }
  Result := nil;
  for iControl := 0 to parent.ControlCount-1 do begin
    if (parent.Controls[iControl].Tag = tag) and IsAllowed(parent.Controls[iControl]) then
    begin
      if skipFirstN > 0 then
        Dec(skipFirstN)
      else begin
        Result := parent.Controls[iControl];
        break; //for iControl
      end;
    end;
  end; //for iControl
  if (not assigned(Result)) and searchInSubcontrols then begin
    for iControl := 0 to parent.ControlCount-1 do begin
      if parent.Controls[iControl] is TWinControl then
        Result := ControlByTag(parent.Controls[iControl] as TWinControl, tag, true,
                    allowOnly);
      if assigned(Result) then
        break; //for iControl
    end; //for iControl
  end;
end; { ControlByTag }

function ControlByClass(parent: TWinControl; controlClass: TClass;
  controlIndex: integer): TControl;
var
  iControl : integer;
  occurence: integer;
begin
  Result := nil;
  occurence := 0;
  for iControl := 0 to parent.ControlCount - 1 do begin
    if parent.Controls[iControl] is controlClass then begin
      Inc(occurence);
      if occurence = controlIndex then begin
        Result := parent.Controls[iControl];
        break; //for
      end;
    end;
  end;
end; { ControlByClass }

procedure ControlsByClass(parent: TWinControl; controlClass: TClass;
  controls: TObjectList);
var
  iControl: integer;
begin
  controls.OwnsObjects := false; //better safe than sorry
  controls.Clear;
  for iControl := 0 to parent.ControlCount - 1 do
    if parent.Controls[iControl] is controlClass then
      controls.Add(parent.Controls[iControl]);
end; { ControlsByClass }

function ComponentByTag(parent: TComponent; tag: integer;
  searchInSubcomponents: boolean): TComponent;
begin
  Result := ComponentByTag(parent, tag, searchInSubcomponents, [nil]);
end; { ComponentByTag }

function ComponentByTag(parent: TComponent; tag: integer; searchInSubcomponents: boolean;
  allowOnly: array of TComponentClass): TComponent; 
begin
  Result := ComponentByTag(parent, tag, searchInSubcomponents, allowOnly, 0);
end; { ComponentByTag }

function ComponentByTag(parent: TComponent; tag: integer; searchInSubcomponents: boolean;
  allowOnly: array of TComponentClass; skipFirstN: integer): TComponent;

  function IsAllowed(control: TComponent): boolean;
  var
    iAllowed: integer;
  begin
    if (Length(allowOnly) = 0) or ((Length(allowOnly) = 1) and
       (allowOnly[Low(allowOnly)] = nil))
    then
      Result := true
    else begin
      Result := true;
      for iAllowed := Low(allowOnly) to High(allowOnly) do
        if allowOnly[iAllowed] = control.ClassType then
          Exit;
      Result := false;
    end;
  end; { IsAllowed }

var
  iComponent: integer;

begin { ComponentByTag }
  Result := nil;
  for iComponent := 0 to parent.ComponentCount-1 do begin
    if (parent.Components[iComponent].Tag = tag) and
       IsAllowed(parent.Components[iComponent]) then
    begin
      if skipFirstN > 0 then
        Dec(skipFirstN)
      else begin
        Result := parent.Components[iComponent];
        break; //for iComponent
      end;
    end;
  end; //for iControl
  if (not assigned(Result)) and searchInSubcomponents then begin
    for iComponent := 0 to parent.ComponentCount-1 do begin
      Result := ComponentByTag(parent.Components[iComponent], tag, true, allowOnly);
      if assigned(Result) then
        break; //for iComponent
    end; //for iComponent
  end;
end; { ComponentByTag }

function CanAllocateHandle(control: TWinControl): boolean;
begin
  Result := false;
  repeat
    if control.HandleAllocated then begin
      Result := true;
      break; //repeat
    end;
    control := control.Parent;
  until control = nil;
end; { CanAllocateHandle }

procedure DisableChildControls(parent: TWinControl; disabledList: TList);
var
  iControl: integer;
begin
  for iControl := 0 to parent.ControlCount-1 do
    if parent.Controls[iControl].Enabled then begin
      parent.Controls[iControl].Enabled := false;
      if assigned(disabledList) then
        disabledList.Add(parent.Controls[iControl]);
    end;
end; { DisableChildControls }

procedure EnableChildControls(parent: TWinControl; enabledList: TList);
var
  iControl: integer;
begin
  for iControl := 0 to parent.ControlCount-1 do
    if not parent.Controls[iControl].Enabled then begin
      parent.Controls[iControl].Enabled := true;
      if assigned(enabledList) then
        enabledList.Add(parent.Controls[iControl]);
    end;
end; { EnableChildControls }

procedure DisableControls(controlList: TList);
var
  iControl: integer;
begin
  for iControl := 0 to controlList.Count-1  do
    TControl(controlList[iControl]).Enabled := false;
end; { DisableControls }

procedure EnableControls(controlList: TList);
var
  iControl: integer;
begin
  for iControl := 0 to controlList.Count-1  do
    TControl(controlList[iControl]).Enabled := true;
end; { EnableControls }

function EnumControls(parent: TWinControl; matchClass: TClass; recursive: boolean): TControlEnumeratorFactory;
begin
  Result := TControlEnumeratorFactory.Create(parent, matchClass, recursive);
end; { EnumControls }

procedure EnableControls(controlList: TList; enable: boolean); overload;
begin
  if enable then
    EnableControls(controlList)
  else
    DisableControls(controlList);
end; { EnableControls }

procedure DisableControls(const controlList: array of TControl; disabledList: TList);
var
  control: TControl;
begin
  for control in controlList do
    if control.Enabled then begin
      control.Enabled := false;
      if assigned(disabledList) then
        disabledList.Add(control);
    end;
end; { DisableControls }

procedure EnableControls(const controlList: array of TControl; enabledList: TList); overload;
var
  control: TControl;
begin
  for control in controlList do begin
    if not control.Enabled then begin
      control.Enabled := true;
      if assigned(enabledList) then
        enabledList.Add(control);
    end;
  end;
end; { EnableControls }

procedure EnableControls(const controlList: array of TControl; enable: boolean; enabledList: TList);
  overload;
begin
  if enable then
    EnableControls(controlList, enabledList)
  else
    DisableControls(controlList, enabledList);
end; { EnableControls }

procedure HideControls(controlList: TList); overload;
var
  iControl: integer;
begin
  for iControl := 0 to controlList.Count-1  do
    TControl(controlList[iControl]).Visible := true;
end; { HideControls }

procedure ShowControls(controlList: TList); overload;
var
  iControl: integer;
begin
  for iControl := 0 to controlList.Count-1  do
    TControl(controlList[iControl]).Visible := true;
end; { ShowControls }

procedure ShowControls(controlList: TList; show: boolean);
begin
  if show then
    ShowControls(controlList)
  else
    HideControls(controlList);
end; { ShowControls }

procedure HideControls(const controlList: array of TControl); overload;
var
  control: TControl;
begin
  for control in controlList do
    control.Visible := false;
end; { HideControls }

procedure ShowControls(const controlList: array of TControl); overload;
var
  control: TControl;
begin
  for control in controlList do
    control.Visible := true;
end; { ShowControls }

procedure ShowControls(const controlList: array of TControl; show: boolean);
begin
  if show then
    ShowControls(controlList)
  else
    HideControls(controlList);
end; { ShowControls }

function EnumActions(actionList: TActionList; filter: TPredicate<TAction>):
  IActionEnumeratorFactory; overload;
begin
  Result := TActionEnumeratorFactory.Create(actionList, filter);
end; { EnumActions }

function EnumActions(actionList: TActionList; const category: string): IActionEnumeratorFactory; overload;
begin
  Result := EnumActions(actionList,
    function (action: TAction): boolean
    begin
      Result := SameText(action.Category, category);
    end);
end; { EnumActions }

function BrowseForFolder(const ATitle: string; var SelectedFolder: string): boolean;
begin
  if Win32MajorVersion >= 6 then begin
    with TFileOpenDialog.Create(nil) do try
      Title := ATitle;
      Options := [fdoPickFolders, fdoPathMustExist, fdoForceFileSystem];
      OkButtonLabel := 'Select';
      DefaultFolder := SelectedFolder;
      FileName := SelectedFolder;
      Result := Execute;
      if Result then
        SelectedFolder := FileName;
    finally
      Free;
    end
  end
  else
    Result := SelectDirectory(ATitle, ExtractFileDrive(SelectedFolder), SelectedFolder, [sdNewUI, sdNewFolder]);
end; { BrowseForFolder }

procedure DisableRedraw(control: TWinControl);
begin
  SendMessage(control.Handle, WM_SETREDRAW, 0, 0);
end; { DisableRedraw }

procedure DisableRedraw(controls: array of TWinControl);
var
  control: TWinControl;
begin
  for control in controls do
    DisableRedraw(control);
end; { DisableRedraw }

procedure EnableRedraw(control: TWinControl; forceRepaint: boolean);
begin
  SendMessage(control.Handle, WM_SETREDRAW, -1, 0);
  if forceRepaint then
//    control.Repaint;
    RedrawWindow(control.Handle, nil, 0, RDW_ERASE or RDW_INVALIDATE or RDW_FRAME or RDW_ALLCHILDREN);
end; { EnableRedraw }

procedure EnableRedraw(controls: array of TWinControl; forceRepaint: boolean);
var
  control: TWinControl;
begin
  for control in controls do
    EnableRedraw(control, forceRepaint);
end; { EnableRedraw }

procedure EnableChildControls(parent: TWinControl; enable: boolean; enabledList: TList);
begin
  if enable then
    EnableChildControls(parent, enabledList)
  else
    DisableChildControls(parent, enabledList);
end; { EnableChildControls }

{$IFDEF GpVCL_Anonymous}
function AutoRestoreCursor(newCursor: TCursor): IGpAutoExecute;
var
  oldCursor: TCursor;
begin
  oldCursor := Screen.Cursor;
  Screen.Cursor := newCursor;
  Result := AutoExecute(
    procedure
    begin
      Screen.Cursor := oldCursor;
    end);
end; { AutoRestoreCursor }

{$ENDIF GpVCL_Anonymous}

function GetFormTextFromResource(const formName: string): string;
var
  rs: TResourceStream;
  ts: TStringStream;
begin
  Result := '';
  try
    rs := TResourceStream.Create(MainInstance, UpperCase(formName), RT_RCDATA);
    try
      ts := TStringStream.Create;
      try
        try
          ObjectBinaryToText(rs, ts);
          Result := ts.DataString;
        except
          on E: EReadError do ;
        end;
      finally FreeAndNil(ts); end;
    finally FreeAndNil(rs); end;
  except
    on E: EResNotFound do ;
  end;
end; { GetFormTextFromResource }

function GetFormTextFromResource(const formClass: TClass): string;
begin
  Result := GetFormTextFromResource(formClass.ClassName);
end; { GetFormTextFromResource }

function GetFormTextFromResource(const form: TCustomForm): string; overload;
begin
  Result := GetFormTextFromResource(form.ClassName);
end; { GetFormTextFromResource }

procedure ChangeExtensionOnTypeChange(saveDialog: TFileSaveDialog);
var
  dialog       : IFileDialog;
  dlgFileName  : LPCWSTR;
  dlgFolderName: string;
  newFileName  : string;
  sExt         : string;
  si           : IShellItem;
  sName        : string;
  sPath        : string;

  function GetItemName(Item: IShellItem; var ItemName: string): HResult;
  var
    pszItemName: LPCWSTR;
  begin
    Result := Item.GetDisplayName(SIGDN_FILESYSPATH, pszItemName);
    if Failed(Result) then
      Result := Item.GetDisplayName(SIGDN_NORMALDISPLAY, pszItemName);
    if Succeeded(Result) then
    try
      ItemName := pszItemName;
    finally
      CoTaskMemFree(pszItemName);
    end;
  end; { GetItemName }

begin
  dialog := saveDialog.Dialog;

  if not (Succeeded(dialog.GetFileName(dlgFileName)) and
          Succeeded(dialog.GetFolder(si)) and
          Succeeded(GetItemName(si, dlgFolderName)))
  then
    Exit;

  sPath := IncludeTrailingPathDelimiter(ExtractFilePath(dlgFileName));
  if sPath = '\' then
    sPath := '';
  if AnsiSameText(sPath, IncludeTrailingPathDelimiter(dlgFolderName)) then
    sPath := '';
  sName := ExtractFileName(dlgFileName);
  sExt := ExtractFileExt(sName);
  sName := Copy(sName, 1, Length(sName) - Length(sExt));
  if (Length(sName) > 0) and (sName[Length(sName)] = '.') then
    sName := Copy(sName, 1, Length(sName) - 1);
  sExt := ExtractFileExt(saveDialog.FileTypes[saveDialog.FileTypeIndex-1].FileMask);
  saveDialog.DefaultExtension := sExt;

  if sName <> '' then begin
    if sPath = '' then
      newFileName := sName + sExt
    else
      newFileName := sPath + sName + sExt;
    saveDialog.FileName := newFileName;
    dialog.SetFileName(PWideChar(newFileName));
    sName := saveDialog.FileName;
  end;
end; { ChangeExtensionOnTypeChange }

function RemapPtToControl(const pt: TPoint; sourceContext, targetContext: TControl): TPoint;
begin
  Result := targetContext.ScreenToClient(sourceContext.ClientToScreen(pt))
end; { RemapPtToControl }

procedure SaveCanvasToFile(canvas: TCanvas; const fileName: string);
var
  bmp: TBitmap;
begin
  bmp := TBitmap.Create;
  try
    bmp.SetSize(canvas.ClipRect.Right, canvas.ClipRect.Bottom);
    BitBlt(bmp.canvas.Handle, 0, 0, bmp.Width, bmp.Height, canvas.Handle, 0, 0, SRCCOPY);
    bmp.SaveToFile(fileName);
  finally
    bmp.Free;
  end;
end; { SaveCanvasToFile }

{ TControlEnumerator }

constructor TControlEnumerator.Create(parent: TWinControl; matchClass: TClass;
  recursive: boolean);
begin
  ceParent := parent;
  ceClass := matchClass;
  ceIndex := -1;
  ceRecursive := recursive;
  ceControls := TList.Create;
  ceControlsGuard := AutoDestroyObject(ceControls);
  BuildControlList(ceParent);
end; { TControlEnumerator.Create }

procedure TControlEnumerator.BuildControlList(parent: TWinControl);
var
  ctrl: TControl;
  i   : integer;
begin
  for i := 0 to parent.ControlCount - 1 do begin
    ctrl := parent.Controls[i];
    if (ceClass = nil) or (ctrl.InheritsFrom(ceClass)) then
      ceControls.Add(ctrl);
    if ceRecursive and (ctrl is TWinControl) then
      BuildControlList(TWinControl(ctrl));
  end;
end; { TControlEnumerator.BuildControlList }

function TControlEnumerator.GetCurrent: TControl;
begin
  Result := ceControls[ceIndex];
end; { TControlEnumerator.GetCurrent }

function TControlEnumerator.MoveNext: boolean;
begin
  Inc(ceIndex);
  Result := (ceIndex < ceControls.Count);
end; { TControlEnumerator.MoveNext }

{ TControlEnumeratorFactory }

constructor TControlEnumeratorFactory.Create(parent: TWinControl; matchClass: TClass;
  recursive: boolean);
begin
  cefParent := parent;
  cefClass := matchClass;
  cefRecursive := recursive;
end; { TControlEnumeratorFactory.Create }

function TControlEnumeratorFactory.GetEnumerator: TControlEnumerator;
begin
  Result := TControlEnumerator.Create(cefParent, cefClass, cefRecursive);
end; { TControlEnumeratorFactory.GetEnumerator }

{ TControlEnumeratorFactory<T> }

constructor TControlEnumeratorFactory<T>.Create(parent: TWinControl; recursive: boolean);
begin
  FParent := parent;
  FIndex := -1;
  FRecursive := recursive;
  FControls := TList.Create;
  FControlsGuard := AutoDestroyObject(FControls);
  BuildControlList(FParent);
end; { TControlEnumeratorFactory<T>.Create }

procedure TControlEnumeratorFactory<T>.BuildControlList(parent: TWinControl);
var
  ctrl: TControl;
  i   : integer;
begin
  for i := 0 to parent.ControlCount - 1 do begin
    ctrl := parent.Controls[i];
    if ctrl.InheritsFrom(T) then
      FControls.Add(ctrl);
    if FRecursive and (ctrl is TWinControl) then
      BuildControlList(TWinControl(ctrl));
  end; //while
end; { TControlEnumeratorFactory<T>.BuildControlList }

function TControlEnumeratorFactory<T>.GetCurrent: T;
begin
  Result := T(FControls[FIndex]);
end; { TControlEnumeratorFactory<T>.GetCurrent }

function TControlEnumeratorFactory<T>.GetEnumerator: TControlEnumeratorFactory<T>;
begin
  Result := Self;
end; { TControlEnumeratorFactory<T>.GetEnumerator }

function TControlEnumeratorFactory<T>.MoveNext: boolean;
begin
  Inc(FIndex);
  Result := (FIndex < FControls.Count);
end; { TControlEnumeratorFactory<T>.MoveNext }

{ TComponentEnumeratorFactory<T> }

constructor TComponentEnumeratorFactory<T>.Create(parent: TWinControl; recursive: boolean);
begin
  FParent := parent;
  FIndex := -1;
  FRecursive := recursive;
  FComponents := TList.Create;
  FComponentsGuard := AutoDestroyObject(FComponents);
  BuildComponentList(parent);
end; { TComponentEnumeratorFactory<T>.Create }

procedure TComponentEnumeratorFactory<T>.BuildComponentList(parent: TWinControl);
var
  comp: TComponent;
  i: integer;
begin
  for i := 0 to parent.ComponentCount - 1 do begin
    comp := parent.Components[i];
    if comp.InheritsFrom(T) then
      FComponents.Add(comp);
    if FRecursive and (comp is TWinControl) then
      BuildComponentList(TWinControl(comp));
  end; //while
end; { TComponentEnumeratorFactory }

function TComponentEnumeratorFactory<T>.GetCurrent: T;
begin
  Result := T(FComponents[FIndex]);
end; { TComponentEnumeratorFactory<T>.GetCurrent }

function TComponentEnumeratorFactory<T>.GetEnumerator: TComponentEnumeratorFactory<T>;
begin
  Result := Self;
end; { TComponentEnumeratorFactory<T>.GetEnumerator }

function TComponentEnumeratorFactory<T>.MoveNext: boolean;
begin
  Inc(FIndex);
  Result := (FIndex < FComponents.Count);
end; { TComponentEnumeratorFactory<T>.MoveNext }

{ TActionEnumerator }

constructor TActionEnumerator.Create(actionList: TActionList; filter: TPredicate<TAction>);
begin
  inherited Create;
  FActionList := actionList;
  FFilter := filter;
  FIndex := -1;
end; { TActionEnumerator.Create }

function TActionEnumerator.GetCurrent: TAction;
begin
  Result := TAction(FActionList.Actions[FIndex]);
end; { TActionEnumerator.GetCurrent }

function TActionEnumerator.MoveNext: boolean;
begin
  Result := false;
  while FIndex < (FActionList.ActionCount - 1) do begin
    Inc(FIndex);
    if (not assigned(FFilter)) or FFilter(FActionList.Actions[FIndex] as TAction) then
      Exit(true);
  end; //while
end; { TActionEnumerator.MoveNext }

{ TActionEnumeratorFactory }

constructor TActionEnumeratorFactory.Create(actionList: TActionList;
  filter: TPredicate<TAction>);
begin
  inherited Create;
  FActionList := actionList;
  FFilter := filter;
end; { TActionEnumeratorFactory.Create }

function TActionEnumeratorFactory.GetEnumerator: IActionEnumerator;
begin
  Result := TActionEnumerator.Create(FActionList, FFilter);
end; { TActionEnumeratorFactory.GetEnumerator }

{ TGpManagedFrame }

procedure TGpManagedFrame.AfterConstruction;
begin
  inherited;
  TGpManaged.CreateManagedChildren(Self);
end; { TGpManagedFrame.AfterConstruction }

procedure TGpManagedFrame.BeforeDestruction;
begin
  TGpManaged.DestroyManagedChildren(Self);
  inherited;
end; { TGpManagedFrame.BeforeDestruction }

{ TGpManagedForm }

procedure TGpManagedForm.AfterConstruction;
begin
  inherited;
  TGpManaged.CreateManagedChildren(Self);
end; { TGpManagedForm.AfterConstruction }

procedure TGpManagedForm.BeforeDestruction;
begin
  TGpManaged.DestroyManagedChildren(Self);
  inherited;
end; { TGpManagedForm.BeforeDestruction }

{ TWinControlEnumerator }

function TWinControlEnumerator.EnumComponents(recursive: boolean):
  TComponentEnumeratorFactory<TComponent>;
begin
  Result := TComponentEnumeratorFactory<TComponent>.Create(Self, recursive);
end; { TWinControlEnumerator.EnumComponents }

function TWinControlEnumerator.EnumComponents<T>(recursive: boolean):
  TComponentEnumeratorFactory<T>;
begin
  Result := TComponentEnumeratorFactory<T>.Create(Self, recursive);
end; { TWinControlEnumerator.EnumComponents }

function TWinControlEnumerator.EnumControls(recursive: boolean):
  TControlEnumeratorFactory<TControl>;
begin
  Result := TControlEnumeratorFactory<TControl>.Create(Self, recursive);
end; { TWinControlEnumerator.EnumControls }

function TWinControlEnumerator.EnumControls<T>(recursive: boolean):
  TControlEnumeratorFactory<T>;
begin
  Result := TControlEnumeratorFactory<T>.Create(Self, recursive);
end; { TWinControlEnumerator.EnumControls }

{ TScrollBar }

function TScrollBar.GetWinPageSize: integer;
var
  scrollInfo: TScrollInfo;
begin
  Result := 0;
  scrollInfo.cbSize := SizeOf(scrollInfo);
  scrollInfo.fMask := SIF_PAGE;
  if GetScrollInfo(Handle, SB_CTL, scrollInfo) then
    Result := scrollInfo.nPage;
end; { TScrollBar.GetWinPageSize }

procedure TScrollBar.SetWinPageSize(const value: integer);
var
  scrollInfo: TScrollInfo;
begin
  scrollInfo.cbSize := SizeOf(scrollInfo);
  scrollInfo.nPage := value;
  scrollInfo.fMask := SIF_PAGE;
  if sfHandleMessages in StyleServices.Flags then begin
    SetScrollInfo(Handle, SB_CTL, scrollInfo, false);
    RedrawWindow(Handle, nil, 0, RDW_INVALIDATE or RDW_UPDATENOW);
  end
  else
    SetScrollInfo(Handle, SB_CTL, scrollInfo, true);
end; { TScrollBar.SetWinPageSize }

{ TCanvasHelper }

procedure TCanvasHelper.SaveToFile(const fileName: string);
begin
  SaveCanvasToFile(Self, fileName);
end; { TCanvasHelper.SaveToFile }

end.
