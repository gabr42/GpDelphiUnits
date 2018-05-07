(*:Helper routines for Lischke's Virtual Treeview.
   @author Primoz Gabrijelcic
   @desc <pre>
   (c) 2017 Primoz Gabrijelcic
   Free for personal and commercial use. No rights reserved.

   Author            : Primoz Gabrijelcic
   Creation date     : 2002-09-18
   Last modification : 2017-03-20
   Version           : 1.07
</pre>*)(*
   History:
     1.07: 2017-03-20
       - Implemented VTGetNodeDataInt64 and VTSetNodeDataInt64.
     1.06: 2015-09-17
       - Added VTGetTopParent.
       - Added VTFilter.
     1.05: 2008-02-29
       - Added helpers to store/restore header layout: VTGetHeaderAsString,
         VTSetHeaderFromString.
     1.04a: 2007-05-17
       - Removed two warnings introduced in 1.04.
     1.04: 2007-02-20
       - Added capability to access more than just first 4 bytes of the node data to
         VT(Get|Set)NodeData[Int] procedures.
     1.03: 2005-11-22
       - Added method VTResort.
     1.02: 2005-10-07
       - Added function VTHighestVisibleColumn.
     1.01: 2005-09-30
       - Declared cxDateTime and GpTime editors.
     1.0a: 2005-03-25
       - Fixed accvio in VTGetNodeData.
     1.0: 2002-09-18
       - Created & released.
*)

unit GpVirtualTree;

interface

uses
  VirtualTrees;

type
  TFilterProc = reference to procedure (node: PVirtualNode; var isVisible: boolean);

procedure VTFilter(vt: TVirtualStringTree; filter: TFilterProc);
procedure VTFindAndSelect(vt: TVirtualStringTree; nodeText: string;
  columnIndex: integer = -1; forceSelect: boolean = true);
function  VTFindNode(vt: TVirtualStringTree; nodeText: string;
  columnIndex: integer = -1): PVirtualNode;
function  VTGetHeaderAsString(header: TVTHeader): string;
function  VTGetNodeData(vt: TBaseVirtualTree; node: PVirtualNode = nil; ptrOffset: integer
  = 0): pointer;
function  VTGetNodeDataInt(vt: TBaseVirtualTree; node: PVirtualNode = nil; ptrOffset:
  integer = 0): integer;
function  VTGetNodeDataInt64(vt: TBaseVirtualTree; node: PVirtualNode = nil): integer;
function  VTGetText(vt: TVirtualStringTree; node: PVirtualNode = nil;
  columnIndex: integer = -1): string;
function  VTGetTopParent(vt: TVirtualStringTree; node: PVirtualNode = nil): PVirtualNode;
function  VTHighestVisibleColumn(vt: TBaseVirtualTree): integer;
procedure VTResort(vt: TVirtualStringTree);
procedure VTSelectNode(vt: TBaseVirtualTree; node: PVirtualNode);
procedure VTSetCheck(vt: TBaseVirtualTree; node: PVirtualNode;
  checkif, uncheckif: boolean);
procedure VTSetHeaderFromString(header: TVTHeader; const value: string);
procedure VTSetNodeData(vt: TBaseVirtualTree; value: pointer; node: PVirtualNode = nil;
  ptrOffset: integer = 0);
procedure VTSetNodeDataInt(vt: TBaseVirtualTree; value: integer; node: PVirtualNode =
  nil; ptrOffset: integer = 0);
procedure VTSetNodeDataInt64(vt: TBaseVirtualTree; value: integer; node: PVirtualNode = nil);

implementation

uses
  Windows,
  SysUtils,
  Classes,
  OmniXMLUtils;

type
  TVirtualTreeFriend = class(TBaseVirtualTree) end;

{ globals }

procedure VTFilter(vt: TVirtualStringTree; filter: TFilterProc);
var
  isVisible: boolean;
  node     : PVirtualNode;
begin
  vt.BeginUpdate;
  try
    node := vt.GetFirst;
    while assigned(node) do begin
      filter(node, isVisible);
      vt.IsFiltered[node] := not isVisible;
      node := vt.GetNext(node);
    end;
  finally vt.EndUpdate; end;
end; { VTFilter }

{:Find the node with a specified caption, then focus and select it. Assumes that
  virtual treeview doesn't use columns. If node is not found, either unselects
  and unfocuses all nodes (if 'forceSelect' is False) or selects and focuses
  first node (if 'forceSelect' is True)
  @since   2002-09-18
}
procedure VTFindAndSelect(vt: TVirtualStringTree; nodeText: string;
  columnIndex: integer; forceSelect: boolean);
var
  node: PVirtualNode;
begin
  if (columnIndex < 0) and (vt.Header.Columns.Count > 0) then
    columnIndex := 0;
  node := VTFindNode(vt, nodeText, columnIndex);
  if (not assigned(node)) and forceSelect then
    node := vt.GetFirst;
  VTSelectNode(vt, node);
end; { VTFindAndSelect }

{:Find the node with a specified caption. Assumes that virtual treeview doesn't
  use columns.
  @since   2002-09-18
}        
function VTFindNode(vt: TVirtualStringTree; nodeText: string;
  columnIndex: integer): PVirtualNode;
begin
  if nodeText = '' then
    Result := nil
  else begin
    if (columnIndex < 0) and (vt.Header.Columns.Count > 0) then
      columnIndex := 0;
    Result := vt.GetFirst;
    while assigned(Result) do begin
      if AnsiSameText(vt.Text[Result,columnIndex], nodeText) then
        Exit;
      Result := vt.GetNext(Result);
    end; //while
  end;
end; { VTFindNode }

{:Return node data as a pointer. If 'node' parameter is not specified, return
  data for the focused node.
  @since   2002-09-18
}
function VTGetNodeData(vt: TBaseVirtualTree; node: PVirtualNode; ptrOffset: integer): pointer;
begin
  Result := nil;
  if not assigned(node) then
    node := vt.FocusedNode;
  if assigned(node) then
    Result := pointer(pointer(int64(vt.GetNodeData(node)) + ptrOffset * SizeOf(pointer))^);
end; { VTGetNodeData }

{:Returns node data as an integer. If 'node' parameter is not specified, returns
  data for the focused node.
  @since   2002-09-18
}
function VTGetNodeDataInt(vt: TBaseVirtualTree; node: PVirtualNode; ptrOffset: integer): integer;
begin
  Result := integer(VTGetNodeData(vt, node, ptrOffset));
end; { VTGetNodeDataInt }

{:Returns node data as an integer. If 'node' parameter is not specified, returns
  data for the focused node.
}
function VTGetNodeDataInt64(vt: TBaseVirtualTree; node: PVirtualNode): integer;
begin
  Result := 0;
  if not assigned(node) then
    node := vt.FocusedNode;
  if assigned(node) then
    Result := PInt64(vt.GetNodeData(node))^;
end; { VTGetNodeDataInt }

{:Returns caption of the specified node. If node is not specified, focus node is
  used.
  @since   2002-09-18
}
function VTGetText(vt: TVirtualStringTree; node: PVirtualNode;
  columnIndex: integer): string;
begin
  if not assigned(node) then
    node := vt.FocusedNode;
  if (columnIndex < 0) and (vt.Header.Columns.Count > 0) then
    columnIndex := 0;
  if assigned(node) then
    Result := vt.Text[node, columnIndex]
  else
    Result := '';
end; { VTGetText }

{:Returns index of rightmost visible column.
  @since   2005-10-07
}
function VTHighestVisibleColumn(vt: TBaseVirtualTree): integer;
var
  column        : TVirtualTreeColumn;
  highestVisible: cardinal;
  iHeaderCol    : integer;
begin
  Result := -1;
  highestVisible := 0;
  for iHeaderCol := 0 to TVirtualTreeFriend(vt).Header.Columns.Count-1 do begin
    column := TVirtualTreeFriend(vt).Header.Columns[iHeaderCol];
    if coVisible in Column.Options then
      if column.Position > highestVisible then begin
        highestVisible := column.Position;
        Result := iHeaderCol;
      end;
  end;
end; { HighestVisibleColumn }

{:Resorts the tree using the current settings.
  @since   2005-11-22
}
procedure VTResort(vt: TVirtualStringTree);
begin
  vt.SortTree(vt.Header.SortColumn, vt.Header.SortDirection);
end; { VTResort }

{:Selects and focuses specified node.
  @since   2002-09-18
}        
procedure VTSelectNode(vt: TBaseVirtualTree; node: PVirtualNode);
begin
  vt.ClearSelection;
  if assigned(node) then
    vt.Selected[node] := true;
  vt.FocusedNode := node;
end; { VTSelectNode }

{:Sets check state of the specified node.
  @since   2002-09-18
}        
procedure VTSetCheck(vt: TBaseVirtualTree; node: PVirtualNode;
  checkif, uncheckif: boolean);
begin
  if checkif then
    vt.CheckState[node] := csCheckedNormal
  else if uncheckif then
    vt.CheckState[node] := csUncheckedNormal
  else
    vt.CheckState[node] := csMixedNormal;
end; { VTSetCheck }

{:Set node data as a pointer. If 'node' parameter is not specified, set data
  for the focused node.
  @since   2002-09-18
}
procedure VTSetNodeData(vt: TBaseVirtualTree; value: pointer; node: PVirtualNode;
  ptrOffset: integer);
begin
  if not assigned(node) then
    node := vt.FocusedNode;
  pointer(pointer(int64(vt.GetNodeData(node)) + ptrOffset * SizeOf(pointer))^) := value;
end; { VTSetNodeData }

{:Set node data as an integer. If 'node' parameter is not specified, set data
  for the focused node.
  @since   2002-09-18
}
procedure VTSetNodeDataInt(vt: TBaseVirtualTree; value: integer; node: PVirtualNode;
  ptrOffset: integer);
begin
  VTSetNodeData(vt, pointer(value), node, ptrOffset);
end; { VTSetNodeDataInt }

procedure VTSetNodeDataInt64(vt: TBaseVirtualTree; value: integer; node: PVirtualNode);
begin
  if not assigned(node) then
    node := vt.FocusedNode;
  PInt64(vt.GetNodeData(node))^ := value;
end; { VTSetNodeDataInt64 }

function VTGetHeaderAsString(header: TVTHeader): string;
var
  strHeader: TStringStream;
begin
  strHeader := TStringStream.Create('');
  try
    header.SaveToStream(strHeader);
    Result := Base64Encode(strHeader.DataString);
  finally FreeAndNil(strHeader); end;
end; { VTGetHeaderAsString }

procedure VTSetHeaderFromString(header: TVTHeader; const value: string);
var
  strHeader: TStringStream;
begin
  strHeader := TStringStream.Create(Base64Decode(value));
  try
    strHeader.Position := 0;
    try
      header.LoadFromStream(strHeader);
    except
      header.RestoreColumns;
    end;
  finally FreeAndNil(strHeader); end;
end; { VTSetHeaderFromString }

function VTGetTopParent(vt: TVirtualStringTree; node: PVirtualNode = nil): PVirtualNode;
begin
  if not assigned(node) then
    node := vt.FocusedNode;
  if not assigned(node) then
    Exit(nil);

  while vt.NodeParent[node] <> nil do
    node := vt.NodeParent[node];
  Result := node;
end; { VTGetTopParent }

end.
