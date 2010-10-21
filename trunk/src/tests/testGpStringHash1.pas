unit testGpStringHash1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,
  GpForm,
  GpStringHash;

type
  TfrmTestGpStringHash = class(TGpForm)
    lbLog: TListBox;
    btnTestStringHash: TButton;
    btnTestStringTable: TButton;
    btnTestDictionary: TButton;
    procedure btnTestDictionaryClick(Sender: TObject);
    procedure btnTestStringHashClick(Sender: TObject);
    procedure btnTestStringTableClick(Sender: TObject);
  private
  strict protected
  protected
    procedure RunStringObjectTest(canGrow: boolean);
    procedure RunStringTest(canGrow: boolean);
  public
  end;

var
  frmTestGpStringHash: TfrmTestGpStringHash;

implementation

uses
  GpLists;

{$R *.dfm}

procedure TfrmTestGpStringHash.btnTestDictionaryClick(Sender: TObject);
var
  hash    : TGpStringDictionary;
  hashItem: integer;
  index   : cardinal;
  kv      : TGpStringDictionaryKV;
  value   : int64;
begin
  hash := TGpStringDictionary.Create(6);
  try
    for hashItem := 1 to 10 do
      hash.Add(IntToStr(hashItem), hashItem);
    for hashItem := 1 to 10 do begin
      value := hash.ValueOf(IntToStr(hashItem));
      if value <> hashItem then
        Log('*** Expected %d, retrieved %d', [hashItem, value])
      else
        Log('[%d] = %d', [hashItem, value]);
    end;
    for hashItem := 1 to 10 do begin
      if not hash.Find(IntToStr(hashItem), index, value) then
        Log('*** Didn''t find %d', [hashItem])
      else if hashItem <> value then
        Log('*** Expected %d, retrieved %d', [hashItem, value])
      else
        Log('[%d] = %d, %d', [hashItem, index, value]);
    end;
    if hash.Find('1X', index, value) then
      Log('*** Did find 1X');
    Log('Has(1X) = %d', [Ord(hash.HasKey('1X'))]); //1X maps into same slot as '2'
    for kv in hash do
      if StrToInt(kv.Key) <> kv.Value then
        Log('*** %d <> %s', [kv.Value, kv.Key])
      else
        Log('%s:%d:%d', [kv.Key, kv.Index, kv.Value]);
  finally FreeAndNil(hash); end;
end;

procedure TfrmTestGpStringHash.btnTestStringHashClick(Sender: TObject);
begin
  RunStringTest(true);
  RunStringTest(false);
  RunStringObjectTest(false);
  RunStringObjectTest(true);
end;

procedure TfrmTestGpStringHash.btnTestStringTableClick(Sender: TObject);
var
  ia   : integer;
  ib   : integer;
  ic   : integer;
  key  : string;
  kv   : TGpStringTableKV;
  st   : TGpStringTable;
  value: int64;
begin
  st := TGpStringTable.Create(16);
  try
    ia := st.Add('aaaa', 111);   //should not trigger growth
    Log('[aaaa] = %d', [ia]);
    ib := st.Add('bbbbb', 222);  //should trigger growth
    Log('[bbbbb] = %d', [ib]);
    ic := st.Add('cccccc', 333); //should not trigger growth
    Log('[cccccc] = %d', [ic]);
    st.Get(ia, key, value);
    Log('[%d] = %s:%d', [ia, key, value]);
    st.Get(ib, key, value);
    Log('[%d] = %s:%d', [ib, key, value]);
    st.Get(ic, key, value);
    Log('[%d] = %s:%d', [ic, key, value]);
    for kv in st do
      Log('%s:%d', [kv.Key, kv.Value]);
  finally FreeAndNil(st); end;
end;

procedure TfrmTestGpStringHash.RunStringObjectTest(canGrow: boolean);
var
  hash    : TGpStringObjectHash;
  hashItem: integer;
  val11   : TGpInt64;
begin
  hash := TGpStringObjectHash.Create(10, true, canGrow);
  try
    for hashItem := 1 to 10 do
      hash.Add(IntToStr(hashItem), TGpInt64.Create(hashItem));
    try
      val11 := TGpInt64.Create(11);
      hash.Add('11', val11);
    except
      if canGrow then
        Log('*** Exception in Grow mode!')
      else
        FreeAndNil(val11);
    end;
    for hashItem := 1 to 11 do try
      if TGpInt64(hash.ValueOf(IntToStr(hashItem))).Value <> hashItem then
        Log('*** Expected %d, retrieved %d', [hashItem, TGpInt64(hash.ValueOf(IntToStr(hashItem))).Value]);
    except
      if canGrow then
        Log('*** Exception in Grow mode!')
      else if hashItem <> 11 then
        Log('*** Exception on item %d', [hashItem]);
    end;
  finally FreeAndNil(hash); end;
end;

procedure TfrmTestGpStringHash.RunStringTest(canGrow: boolean);
var
  hash    : TGpStringHash;
  hashItem: integer;
begin
  hash := TGpStringHash.Create(10, canGrow);
  try
    for hashItem := 1 to 10 do
      hash.Add(IntToStr(hashItem), hashItem);
    try
      hash.Add('11', 11);
    except
      if canGrow then
        Log('*** Exception in Grow mode!');
    end;
    for hashItem := 1 to 11 do try
      if hash.ValueOf(IntToStr(hashItem)) <> hashItem then
        Log('*** Expected %d, retrieved %d', [hashItem, hash.ValueOf(IntToStr(hashItem))]);
    except
      if canGrow then
        Log('*** Exception in Grow mode!')
      else if hashItem <> 11 then
        Log('*** Exception on item %d', [hashItem]);
    end;
  finally FreeAndNil(hash); end;
end;

end.
