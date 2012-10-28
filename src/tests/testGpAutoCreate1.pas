unit testGpAutoCreate1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  System.Contnrs,
  GpAutoCreate;

type
  TLevel3 = class(TGpManaged)
  protected
    [GpManaged]
    FList1: TObjectList;
    [GpManaged(false)]
    FList2: TObjectList;
  end;

  TLevel2 = class(TGpManaged)
  strict protected
    [GpManaged]
    FLevel3: TLevel3;
  end;

  TLevel1 = class(TGpManaged)
  strict private
    [GpManaged]
    FLevel2a: TLevel2;
    FLevel2b: TLevel2; //unmanaged
  public
    [GpAutoCreate.GpManaged]
    FLevel2c: TLevel2;
  end;

  TfrmTestGpAutoCreate = class(TForm)
    ListBox1: TListBox;
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FLevel1: TLevel1;
    procedure DumpMembers(obj: TObject);
  public
  end;

var
  frmTestGpAutoCreate: TfrmTestGpAutoCreate;

implementation

uses
  System.Rtti;

{$R *.dfm}

procedure TfrmTestGpAutoCreate.DumpMembers(obj: TObject);

  procedure DumpFields(obj: TObject; const t: TRttiType; const prefix: string);
  var
    child: TObject;
    f    : TRttiField;
  begin
    for f in t.GetFields do begin
      child := f.GetValue(obj).AsObject;
      ListBox1.Items.Add(Format('%s%s: %s = %p', [prefix, F.Name, f.FieldType.Name, pointer(child)]));
      if assigned(child) then
        if child.InheritsFrom(TGpManaged) then
          DumpFields(child, f.FieldType, prefix + '  ')
        else if child.InheritsFrom(TObjectList) then
          Listbox1.Items.Add(Format('%s  OwnsObjects = %d', [prefix, Ord(TObjectList(child).OwnsObjects)]));
    end;
  end;

var
  ctx: TRttiContext;
  t  : TRttiType;
begin
  ctx := TRttiContext.Create;
  t := ctx.GetType(obj.ClassType);
  DumpFields(obj, t, '');
end;

procedure TfrmTestGpAutoCreate.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FLevel1);
end;

procedure TfrmTestGpAutoCreate.FormCreate(Sender: TObject);
begin
  FLevel1 := TLevel1.Create;
  DumpMembers(FLevel1);
end;

end.
