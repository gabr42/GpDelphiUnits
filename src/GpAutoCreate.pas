///<summary>Parent class that automatically creates/destroys fields in derived classes
///   that are marked with the [GpManaged] attribute.
///</summary>
///<author>Primoz Gabrijelcic</author>
///<remarks><para>
///   (c) 2013 Primoz Gabrijelcic
///   Free for personal and commercial use. No rights reserved.
///
///   Author            : Primoz Gabrijelcic
///   Creation date     : 2012-10-28
///   Last modification : 2014-01-06
///   Version           : 1.04a
///</para><para>
///   History:
///     1.04a: 2014-01-07
///       - TGpManaged is derived from TGpInterfacedPersistent.
///     1.04: 2014-01-03
///       - TGpManaged is derived from TInterfacedPersistent.
///     1.03: 2013-06-06
///       - Implemented GpManagedDestroy attribute which handles only the destruction of
///         the associated object.
///     1.02: 2013-04-04
///       - TGpManaged is derived from TInterfacedObject.
///     1.01: 2012-10-29
///       - Refactored creation/destruction code into class procedures that can be used
///         from any class as suggested by [Stefan Glienke].
///       - Simplified Boolean-testing code as suggested by [Stefan Glienke].
///     1.0: 2012-10-28
///       - Released.
///</para></remarks>

unit GpAutoCreate;

interface

uses
  System.Rtti,
  System.Classes,
  Vcl.Forms,
  GpStuff;

type
  GpManagedAttribute = class(TCustomAttribute)
  public type
    TConstructorType = (ctNoParam, ctParBoolean, ctParInteger);
  strict private
    FBoolParam      : boolean;
    FIntParam       : integer;
    FConstructorType: TConstructorType;
  public
    class function IsManaged(const obj: TRttiNamedObject): boolean; static;
    class function GetAttr(const obj: TRttiNamedObject; var ma: GpManagedAttribute): boolean; static;
    constructor Create; overload;
    constructor Create(boolParam: boolean); overload;
    constructor Create(intParam: integer); overload;
    property BoolParam: boolean read FBoolParam;
    property ConstructorType: TConstructorType read FConstructorType;
    property IntParam: integer read FIntParam;
  end; { GpManagedAttribute }

  GpManagedDestroyAttribute = class(TCustomAttribute)
  public
    class function IsManaged(const obj: TRttiNamedObject): boolean; static;
    class function GetAttr(const obj: TRttiNamedObject; var ma: GpManagedDestroyAttribute): boolean; static;
  end; { GpManagedDestroyAttribute }

  TGpManaged = class(TGpInterfacedPersistent)
  public
    constructor Create;
    destructor  Destroy; override;
    class procedure CreateManagedChildren(parent: TObject); static;
    class procedure DestroyManagedChildren(parent: TObject); static;
  end; { TGpManaged }

  TGpManagedForm = class(TForm)
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
  end; { TGpManagedForm }

implementation

uses
  System.SysUtils,
  TypInfo;

{ GpManagedAttribute }

constructor GpManagedAttribute.Create;
begin
  inherited Create;
  FConstructorType := ctNoParam;
end; { GpManagedAttribute.Create }

constructor GpManagedAttribute.Create(boolParam: boolean);
begin
  inherited Create;
  FConstructorType := ctParBoolean;
  FBoolParam := boolParam;
end; { GpManagedAttribute.Create }

constructor GpManagedAttribute.Create(intParam: integer);
begin
  inherited Create;
  FConstructorType := ctParInteger;
  FIntParam := intParam;
end; { GpManagedAttribute.Create }

class function GpManagedAttribute.GetAttr(const obj: TRttiNamedObject;
  var ma: GpManagedAttribute): boolean;
var
  a: TCustomAttribute;
begin
  Result := false;
  ma := nil;
  for a in obj.GetAttributes do
    if SameText(a.ClassName, 'GpManagedAttribute') then begin
      ma := GpManagedAttribute(a);
      Exit(true);
    end;
end; { GpManagedAttribute.GetAttr }

class function GpManagedAttribute.IsManaged(const obj: TRttiNamedObject): boolean;
var
  ma: GpManagedAttribute;
begin
  Result := GetAttr(obj, ma);
end; { GpManagedAttribute.IsManaged }

{ GpManagedDestroyAttribute }

class function GpManagedDestroyAttribute.GetAttr(const obj: TRttiNamedObject;
  var ma: GpManagedDestroyAttribute): boolean;
var
  a: TCustomAttribute;
begin
  Result := false;
  ma := nil;
  for a in obj.GetAttributes do
    if SameText(a.ClassName, 'GpManagedDestroyAttribute') then begin
      ma := GpManagedDestroyAttribute(a);
      Exit(true);
    end;
end; { GpManagedDestroyAttribute.GetAttr }

class function GpManagedDestroyAttribute.IsManaged(const obj: TRttiNamedObject): boolean;
var
  ma: GpManagedDestroyAttribute;
begin
  Result := GetAttr(obj, ma);
end; { GpManagedDestroyAttribute.IsManaged }

{ TGpManaged }

constructor TGpManaged.Create;
begin
  inherited Create;
  CreateManagedChildren(Self);
end; { TGpManaged.Create }

destructor TGpManaged.Destroy;
begin
  DestroyManagedChildren(Self);
  inherited;
end; { TGpManaged.Destroy }

class procedure TGpManaged.CreateManagedChildren(parent: TObject);
var
  ctor  : TRttiMethod;
  ctx   : TRttiContext;
  f     : TRttiField;
  ma    : GpManagedAttribute;
  params: TArray<TRttiParameter>;
  t     : TRttiType;
begin
  ctx := TRttiContext.Create;
  t := ctx.GetType(parent.ClassType);
  for f in t.GetFields do begin
    if not GpManagedAttribute.GetAttr(f, ma) then
      continue; //for f
    for ctor in f.FieldType.GetMethods('Create') do begin
      if ctor.IsConstructor then begin
        params := ctor.GetParameters;
        if (ma.ConstructorType = GpManagedAttribute.TConstructorType.ctNoParam) and
           (Length(params) = 0) then
        begin
          f.SetValue(parent, ctor.Invoke(f.FieldType.AsInstance.MetaclassType, []));
          break; //for ctor
        end
        else if (ma.ConstructorType = GpManagedAttribute.TConstructorType.ctParBoolean) and
                (Length(params) = 1) and
                (params[0].ParamType.Handle = TypeInfo(Boolean)) then
        begin
          f.SetValue(parent, ctor.Invoke(f.FieldType.AsInstance.MetaclassType, [ma.BoolParam]));
          break; //for ctor
        end
        else if (ma.ConstructorType = GpManagedAttribute.TConstructorType.ctParInteger) and
                (Length(params) = 1) and
                (params[0].ParamType.Handle = TypeInfo(Integer)) then
        begin
          f.SetValue(parent, ctor.Invoke(f.FieldType.AsInstance.MetaclassType, [ma.IntParam]));
          break; //for ctor
        end;
      end;
    end; //for ctor
  end; //for f
end; { TGpManaged.CreateManagedChildren }

class procedure TGpManaged.DestroyManagedChildren(parent: TObject);
var
  ctx : TRttiContext;
  dtor: TRttiMethod;
  f   : TRttiField;
  t   : TRttiType;
begin
  ctx := TRttiContext.Create;
  t := ctx.GetType(parent.ClassType);
  for f in t.GetFields do begin
    if not (GpManagedAttribute.IsManaged(f) or GpManagedDestroyAttribute.IsManaged(f)) then
      continue; //for f
    for dtor in f.FieldType.GetMethods('Destroy') do begin
      if dtor.IsDestructor then begin
        if not f.GetValue(parent).IsEmpty then begin
          dtor.Invoke(f.GetValue(parent), []);
          f.SetValue(parent, nil);
        end;
        break; //for dtor
      end;
    end; //for dtor
  end; //for f
end; { TGpManaged.DestroyManagedChildren }

{ TGpManagedForm }

constructor TGpManagedForm.Create(AOwner: TComponent);
begin
  inherited;
  TGpManaged.CreateManagedChildren(Self);
end; { TGpManagedForm.Create }

destructor TGpManagedForm.Destroy;
begin
  TGpManaged.DestroyManagedChildren(Self);
  inherited;
end; { TGpManagedForm.Destroy }

end.
