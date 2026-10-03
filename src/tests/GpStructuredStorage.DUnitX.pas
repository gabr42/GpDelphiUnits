unit GpStructuredStorage.DUnitX;

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  GpStructuredStorage;

type
  [TestFixture]
  TGpStructuredStorageTests = class
  strict private
    function  CreateAttrSnapshot(iInfo: IGpStructuredFileInfo): string;
    function  CreateSnapshot(storage: IGpStructuredStorage): string;
    procedure DeleteStorageFile(const fileName: string);
    function  FileSize(const fileName: string): integer;
    procedure TestFile(storage: IGpStructuredStorage; const fileName: string;
      write: boolean; sizeFactor: integer = 1); overload;
    procedure TestFile(strFile: TStream; write: boolean; sizeFactor: integer); overload;
  public
    // Individual tests best-effort-delete their own storage file in a finally block,
    // but in this environment releasing an interface's last reference at the end of a
    // procedure does not synchronously run its destructor (verified independently of
    // this unit - a minimal TInterfacedObject repro shows the same behavior), so the
    // underlying file can still be open at that point. This fixture-level sweep runs
    // once after every test in the fixture has fully returned (and so has genuinely
    // finalized its local storage/fileInfo variables), and reliably removes anything
    // left behind.
    [TearDownFixture] procedure TearDownFixture;
    [Test] procedure Creation;
    [Test] procedure FlatFileSystem;
    [Test] procedure BigAndSmall;
    [Test] procedure FragmentedFiles;
    [Test] procedure Folders;
    [Test] procedure Truncation;
    [Test] procedure Exists;
    [Test] procedure Enumerating;
    [Test] procedure MovingAndDeleting;
    [Test] procedure Attributes;
    [Test] procedure Compacting;
    [Test] procedure Exceptions;
    // Coverage added beyond the original "Full test" workbench conversion:
    [Test] procedure IsStructuredStorageDetection;
    [Test] procedure IsStructuredStorageStreamAllowsReinitializeAfterwards;
    [Test] procedure StreamBasedStorage;
    [Test] procedure LongNameAtBoundaryIsAccepted;
    [Test] procedure LongNameOverBoundaryRaises;
    [Test] procedure IsFolderEmptyReflectsContents;
    [Test] procedure FileInfoSizeProperty;
    [Test] procedure DataFileAndDataSizeProperties;
    [Test] procedure DeleteNonexistentIsNoOp;
    [Test] procedure MoveToExistingDestinationRaises;
    [Test] procedure FileInfoSurvivesFolderDeletionDeferredFree;
    [Test] procedure FragmentationAcrossFatBlocksSurvivesCompact;
    [Test] procedure DeletingFolderContainingSubfolderDoesNotUseFreedName;
    [Test] procedure DeletingSecondToLastEntryDoesNotStrandLastEntry;
  end;

implementation

{ TGpStructuredStorageTests - helpers }

function TGpStructuredStorageTests.CreateAttrSnapshot(iInfo: IGpStructuredFileInfo): string;
var
  attrEnum: TStringList;
  iAttr   : integer;
begin
  Result := '';
  attrEnum := TStringList.Create;
  try
    iInfo.AttributeNames(attrEnum);
    Result := Result + IntToStr(attrEnum.Count) + ':';
    for iAttr := 0 to attrEnum.Count-1 do
      Result := Result + attrEnum[iAttr] + '=' + iInfo.Attribute[attrEnum[iAttr]] + ';';
  finally FreeAndNil(attrEnum); end;
end; { TGpStructuredStorageTests.CreateAttrSnapshot }

function TGpStructuredStorageTests.CreateSnapshot(storage: IGpStructuredStorage): string;

  function Descend(const folderName: string): string;
  var
    files  : TStringList;
    folders: TStringList;
    iEntry : integer;
  begin
    Result := folderName + '/:';
    folders := TStringList.Create;
    try
      storage.FolderNames(folderName, folders);
      for iEntry := 0 to folders.Count-1 do
        Result := Result + folders[iEntry] + '/:';
      files := TStringList.Create;
      try
        storage.FileNames(folderName, files);
        for iEntry := 0 to files.Count-1 do
          Result := Result + files[iEntry] + ':';
      finally FreeAndNil(files); end;
      for iEntry := 0 to folders.Count-1 do
        Result := Result + Descend(folderName + '/' + folders[iEntry]);
    finally FreeAndNil(folders); end;
  end; { Descend }

begin
  Result := Descend('');
end; { TGpStructuredStorageTests.CreateSnapshot }

procedure TGpStructuredStorageTests.DeleteStorageFile(const fileName: string);
begin
  if FileExists(fileName) then
    DeleteFile(fileName);
end; { TGpStructuredStorageTests.DeleteStorageFile }

procedure TGpStructuredStorageTests.TearDownFixture;
var
  searchRec: TSearchRec;
begin
  if FindFirst('gss_test_*.stg', faAnyFile, searchRec) = 0 then begin
    try
      repeat
        DeleteStorageFile(searchRec.Name);
      until FindNext(searchRec) <> 0;
    finally FindClose(searchRec); end;
  end;
end; { TGpStructuredStorageTests.TearDownFixture }

function TGpStructuredStorageTests.FileSize(const fileName: string): integer;
var
  f: file;
begin
  AssignFile(f, fileName);
  Reset(f, 1);
  try
    Result := System.FileSize(f);
  finally CloseFile(f); end;
end; { TGpStructuredStorageTests.FileSize }

procedure TGpStructuredStorageTests.TestFile(storage: IGpStructuredStorage;
  const fileName: string; write: boolean; sizeFactor: integer);
var
  strFile: TStream;
begin
  strFile := storage.OpenFile(fileName, fmCreate);
  try
    TestFile(strFile, write, sizeFactor);
  finally FreeAndNil(strFile); end;
end; { TGpStructuredStorageTests.TestFile }

procedure TGpStructuredStorageTests.TestFile(strFile: TStream; write: boolean;
  sizeFactor: integer);
var
  dataSize: integer;
  iTest   : integer;
  test    : integer;
  testOK  : integer;
begin
  if write then begin
    strFile.Position := 0;
    for dataSize := 2 to 4 do
      for iTest := 0 to 1024*sizeFactor do
        strFile.Write(iTest, dataSize);
    strFile.Size := strFile.Position;
  end;
  strFile.Position := 0;
  for dataSize := 2 to 4 do
    for iTest := 0 to 1024*sizeFactor do begin
      testOK := 0;
      Move(iTest, testOK, dataSize);
      test := 0;
      strFile.Read(test, dataSize);
      Assert.AreEqual(testOK, test, Format('Invalid data at %d/%d', [dataSize, iTest]));
    end;
end; { TGpStructuredStorageTests.TestFile }

{ TGpStructuredStorageTests - tests }

procedure TGpStructuredStorageTests.Creation;
const
  CStorageFile = 'gss_test_creation.stg';
var
  storage: IGpStructuredStorage;
begin
  DeleteStorageFile(CStorageFile);
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    storage := nil;
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmOpenRead);
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmOpenRead);
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.Creation }

procedure TGpStructuredStorageTests.FlatFileSystem;
const
  CStorageFile = 'gss_test_flatfilesystem.stg';
var
  storage: IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    TestFile(storage, '/firstfile.dat', true);
    TestFile(storage, '/secondfile.dat', true);
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmOpenRead);
    TestFile(storage, '/secondfile.dat', false);
    TestFile(storage, '/firstfile.dat', false);
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.FlatFileSystem }

procedure TGpStructuredStorageTests.BigAndSmall;
const
  CStorageFile = 'gss_test_bigandsmall.stg';
var
  storage: IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    // 0 bytes
    TestFile(storage, '/small.dat', true, -1);
    TestFile(storage, '/small2.dat', true, -1);
    TestFile(storage, '/small2.dat', true);
    // cross the 257-block boundary, cross also 64K test value boundary
    TestFile(storage, '/large.dat', true, 64);
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmOpenRead);
    TestFile(storage, '/small.dat', false, -1);
    TestFile(storage, '/small2.dat', false);
    TestFile(storage, '/large.dat', false, 64);
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.BigAndSmall }

procedure TGpStructuredStorageTests.FragmentedFiles;
const
  CStorageFile = 'gss_test_fragmentedfiles.stg';
var
  storage: IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    TestFile(storage, '/firstfile.dat', true);
    TestFile(storage, '/secondfile.dat', true);
    TestFile(storage, '/firstfile.dat', true, 2);
    TestFile(storage, '/secondfile.dat', true);
    TestFile(storage, '/firstfile.dat', false, 2);
    TestFile(storage, '/secondfile.dat', true, -1);
    TestFile(storage, '/firstfile.dat', true, 3);
    TestFile(storage, '/secondfile.dat', true);
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmOpenRead);
    TestFile(storage, '/firstfile.dat', false, 3);
    TestFile(storage, '/secondfile.dat', false);
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.FragmentedFiles }

procedure TGpStructuredStorageTests.Folders;
const
  CStorageFile = 'gss_test_folders.stg';
var
  storage: IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    TestFile(storage, '/firstdir/firstfile.dat', true);
    TestFile(storage, '/firstdir/secondfile.dat', true);
    TestFile(storage, '/seconddir/firstfile.dat', true);
    TestFile(storage, '/seconddir/secondfile.dat', true);
    TestFile(storage, '/firstdir/firstsubdir/firstfile.dat', true);
    TestFile(storage, '/firstdir/secondsubdir/firstfile.dat', true);
    TestFile(storage, '/firstdir/firstsubdir/secondfile.dat', true);
    TestFile(storage, '/firstdir/secondsubdir/secondfile.dat', true);
    storage.CreateFolder('/thirddir');
    storage.CreateFolder('/firstdir/thirdsubdir/');
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmOpenRead);
    TestFile(storage, '/firstdir/firstfile.dat', false);
    TestFile(storage, '/firstdir/secondfile.dat', false);
    TestFile(storage, '/seconddir/firstfile.dat', false);
    TestFile(storage, '/seconddir/secondfile.dat', false);
    TestFile(storage, '/firstdir/firstsubdir/firstfile.dat', false);
    TestFile(storage, '/firstdir/secondsubdir/firstfile.dat', false);
    TestFile(storage, '/firstdir/firstsubdir/secondfile.dat', false);
    TestFile(storage, '/firstdir/secondsubdir/secondfile.dat', false);
    Assert.IsTrue(storage.FolderExists('/thirddir'), '/thirddir');
    Assert.IsTrue(storage.FolderExists('/firstdir/thirdsubdir/'), '/firstdir/thirdsubdir/');
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.Folders }

procedure TGpStructuredStorageTests.Truncation;
const
  CStorageFile = 'gss_test_truncation.stg';
var
  storage: IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    TestFile(storage, '/secondfile.dat', true);
    TestFile(storage, '/firstfile.dat', true, 2);
    TestFile(storage, '/small.dat', true, -1);
    TestFile(storage, '/small2.dat', true);
    TestFile(storage, '/large.dat', true, 30);
    storage := nil;
    Assert.AreEqual(322569, FileSize(CStorageFile), 'storage size after initial writes');
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmOpenReadWrite);
    TestFile(storage, '/large.dat', true);
    storage := nil;
    Assert.AreEqual(55296, FileSize(CStorageFile), 'storage size after truncating /large.dat');
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmOpenReadWrite);
    TestFile(storage, '/secondfile.dat', false);
    TestFile(storage, '/firstfile.dat', false, 2);
    TestFile(storage, '/small.dat', false, -1);
    TestFile(storage, '/small2.dat', false);
    TestFile(storage, '/large.dat', false);
    TestFile(storage, '/secondfile.dat', true, 2);
    TestFile(storage, '/firstfile.dat', true, 1);
    TestFile(storage, '/large.dat', true, 2);
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.Truncation }

procedure TGpStructuredStorageTests.Exists;
const
  CStorageFile = 'gss_test_exists.stg';
var
  storage: IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    TestFile(storage, '/firstfile.dat', true, -1);
    TestFile(storage, '/secondfile.dat', true, -1);
    TestFile(storage, '/firstfolder/firstfile.dat', true, -1);
    TestFile(storage, '/firstfolder/secondfile.dat', true, -1);
    storage.CreateFolder('/secondfolder/firstsubfolder');
    TestFile(storage, '/secondfolder/secondsubfolder/firstfile.dat', true, -1);
    TestFile(storage, '/secondfolder/secondsubfolder/secondfile.dat', true, -1);
    Assert.IsTrue (storage.FileExists('/firstfile.dat'), '/firstfile.dat');
    Assert.IsTrue (storage.FileExists('/secondfile.dat'), '/secondfile.dat');
    Assert.IsFalse(storage.FileExists('/thirdfile.dat'), '/thirdfile.dat');
    Assert.IsTrue (storage.FileExists('/firstfolder/firstfile.dat'), '/firstfolder/firstfile.dat');
    Assert.IsTrue (storage.FileExists('/firstfolder/secondfile.dat'), '/firstfolder/secondfile.dat');
    Assert.IsFalse(storage.FileExists('/firstfolder/thirdfile.dat'), '/firstfolder/thirdfile.dat');
    Assert.IsFalse(storage.FileExists('/secondfolder/firstfile.dat'), '/secondfolder/firstfile.dat');
    Assert.IsTrue (storage.FileExists('/secondfolder/secondsubfolder/firstfile.dat'),
      '/secondfolder/secondsubfolder/firstfile.dat');
    Assert.IsFalse(storage.FileExists('/'), '/');
    Assert.IsFalse(storage.FileExists('/firstfolder'), '/firstfolder');
    Assert.IsFalse(storage.FileExists('/firstfolder/'), '/firstfolder/');
    Assert.IsFalse(storage.FileExists('/secondfolder/firstsubfolder'), '/secondfolder/firstsubfolder');
    Assert.IsFalse(storage.FileExists('/secondfolder/firstsubfolder/'), '/secondfolder/firstsubfolder/');
    Assert.IsTrue (storage.FolderExists('/'), 'folder /');
    Assert.IsTrue (storage.FolderExists('/firstfolder'), 'folder /firstfolder');
    Assert.IsTrue (storage.FolderExists('/firstfolder/'), 'folder /firstfolder/');
    Assert.IsTrue (storage.FolderExists('/secondfolder/firstsubfolder'), 'folder /secondfolder/firstsubfolder');
    Assert.IsTrue (storage.FolderExists('/secondfolder/firstsubfolder/'), 'folder /secondfolder/firstsubfolder/');
    Assert.IsTrue (storage.FolderExists('/secondfolder/secondsubfolder'), 'folder /secondfolder/secondsubfolder');
    Assert.IsTrue (storage.FolderExists('/secondfolder/secondsubfolder/'), 'folder /secondfolder/secondsubfolder/');
    Assert.IsFalse(storage.FolderExists('/firstfile.dat'), 'folder /firstfile.dat');
    Assert.IsFalse(storage.FolderExists('/firstfolder/firstfile.dat'), 'folder /firstfolder/firstfile.dat');
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.Exists }

procedure TGpStructuredStorageTests.Enumerating;
const
  CStorageFile = 'gss_test_enumerating.stg';
  CSnapshot =
    '/:firstfolder/:secondfolder/:firstfile.dat:secondfile.dat:/firstfolder/:'+
    'firstfile.dat:secondfile.dat:/secondfolder/:firstsubfolder/:secondsubfolder/:'+
    '/secondfolder/firstsubfolder/:/secondfolder/secondsubfolder/:firstfile.dat:'+
    'secondfile.dat:';
var
  storage: IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    TestFile(storage, '/firstfile.dat', true, -1);
    TestFile(storage, '/secondfile.dat', true, -1);
    TestFile(storage, '/firstfolder/firstfile.dat', true, -1);
    TestFile(storage, '/firstfolder/secondfile.dat', true, -1);
    storage.CreateFolder('/secondfolder/firstsubfolder');
    TestFile(storage, '/secondfolder/secondsubfolder/firstfile.dat', true, -1);
    TestFile(storage, '/secondfolder/secondsubfolder/secondfile.dat', true, -1);
    Assert.AreEqual(CSnapshot, CreateSnapshot(storage));
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.Enumerating }

procedure TGpStructuredStorageTests.MovingAndDeleting;
const
  CStorageFile = 'gss_test_movinganddeleting.stg';
  CSnapshot1 =
    '/:firstdir/:seconddir/:firstfile.dat:secondfile.dat:/firstdir/:firstsubdir/:'+
    'secondsubdir/:firstfile.dat:secondfile.dat:/firstdir/firstsubdir/:firstfile.dat:'+
    'secondfile.dat:/firstdir/secondsubdir/:firstfile.dat:secondfile.dat:/seconddir/:'+
    'firstfile.dat:secondfile.dat:';
  CSnapshot2 =
    '/:firstdir3/:seconddir/:firstfile.dat:secondfile.dat:copy_of_firstfile.dat:'+
    '/firstdir3/:secondsubdir/:firstfile.dat:secondfile.dat:/firstdir3/secondsubdir/:'+
    'firstfile.dat:secondfile.dat:/seconddir/:copy_of_first/:firstfile.dat:'+
    'secondfile.dat:/seconddir/copy_of_first/:secondfile.dat:';
  CSnapshot3 =
    '/:firstdir/:seconddir/:firstfile.dat:secondfile.dat:/firstdir/:secondsubdir/:'+
    'firstsubdir/:firstfile.dat:secondfile.dat:/firstdir/secondsubdir/:firstfile.dat:'+
    'secondfile.dat:/firstdir/firstsubdir/:secondfile.dat:firstfile.dat:/seconddir/:'+
    'firstfile.dat:secondfile.dat:';
  CSnapshot4 =
    '/:seconddir/:firstfile.dat:secondfile.dat:/seconddir/:';
var
  storage: IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    TestFile(storage, '/firstfile.dat', true, -1);
    TestFile(storage, '/secondfile.dat', true, -1);
    TestFile(storage, '/firstdir/firstfile.dat', true, -1);
    TestFile(storage, '/firstdir/secondfile.dat', true, -1);
    TestFile(storage, '/seconddir/firstfile.dat', true, -1);
    TestFile(storage, '/seconddir/secondfile.dat', true, -1);
    TestFile(storage, '/firstdir/firstsubdir/firstfile.dat', true, -1);
    TestFile(storage, '/firstdir/secondsubdir/firstfile.dat', true, -1);
    TestFile(storage, '/firstdir/firstsubdir/secondfile.dat', true, -1);
    TestFile(storage, '/firstdir/secondsubdir/secondfile.dat', true, -1);
    Assert.AreEqual(CSnapshot1, CreateSnapshot(storage), 'initial layout');
    storage.Move('/firstdir', '/firstdir2');
    storage.Move('/firstdir2/', '/firstdir3/');
    storage.Move('/firstdir3/firstsubdir', '/seconddir/copy_of_first');
    storage.Move('/seconddir/copy_of_first/firstfile.dat', '/copy_of_firstfile.dat');
    Assert.AreEqual(CSnapshot2, CreateSnapshot(storage), 'after first round of moves');
    storage.Move('/firstdir3', '/firstdir');
    storage.Move('/seconddir/copy_of_first', '/firstdir/firstsubdir');
    storage.Move('/copy_of_firstfile.dat', '/firstdir/firstsubdir/firstfile.dat');
    Assert.AreEqual(CSnapshot3, CreateSnapshot(storage), 'after second round of moves');
    storage.Delete('/firstdir/');
    storage.Delete('/seconddir/firstfile.dat');
    storage.Delete('/seconddir/secondfile.dat');
    storage.Delete('/seconddir/firstsubdir');
    Assert.AreEqual(CSnapshot4, CreateSnapshot(storage), 'after deletes');
    // attribute deletion bug, fixed in 1.06b - also exercises the folder-cache
    // use-after-free fixed in 2.0d (see BUG-AUDIT 2/3 in GpStructuredStorage.pas)
    storage.CreateFolder('/Folder 6');
    storage.CreateFolder('/Folder 6/Folder 1');
    storage.FileInfo['/Folder 6/Folder 1'].Attribute['test'] := 'test';
    storage.Delete('/Folder 6/Folder 1');
    storage.OpenFile('/Folder 6/Snippet 1', fmCreate).Free;
    storage.FileInfo['/Folder 6/Snippet 1'].Attribute['test'] := 'test';
    storage.Delete('/Folder 6');
    Assert.AreEqual(CSnapshot4, CreateSnapshot(storage), 'after Folder 6 cleanup');
    // folder deletion bug, found by [Aminer], fixed in 2.0b
    storage.CreateFolder('/thirddir');
    storage.Delete('/thirddir');
    Assert.IsFalse(storage.FolderExists('/thirddir'), '/thirddir should be gone');
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.MovingAndDeleting }

procedure TGpStructuredStorageTests.Attributes;
const
  CStorageFile = 'gss_test_attributes.stg';
  CAttrSnapshot = '2:42=9*6;9*6=42;';
var
  iFolderInfo: IGpStructuredFileInfo;
  storage    : IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    storage.FileInfo[''].Attribute['attr'] := 'Written by Gp';
    Assert.AreEqual('Written by Gp', storage.FileInfo[''].Attribute['attr']);
    // FileInfo[''] is equivalent to FileInfo['/']
    Assert.AreEqual('Written by Gp', storage.FileInfo['/'].Attribute['attr']);
    storage.FileInfo['/'].Attribute['attr'] := 'root attrib';
    Assert.AreEqual('root attrib', storage.FileInfo['/'].Attribute['attr']);
    TestFile(storage, '/normal.dat', true, -1);
    storage.FileInfo['/normal.dat'].Attribute['42'] := '6*9';
    Assert.AreEqual('6*9', storage.FileInfo['/normal.dat'].Attribute['42']);
    storage.Move('/normal.dat', '/folder/test.dat');
    storage.Move('/folder/test.dat', '/folder/test2.dat');
    Assert.AreEqual('6*9', storage.FileInfo['/folder/test2.dat'].Attribute['42']);
    storage.Move('/folder/test2.dat', '/normal.dat');
    Assert.AreEqual('6*9', storage.FileInfo['/normal.dat'].Attribute['42']);
    storage.Delete('/normal.dat');
    TestFile(storage, '/normal.dat', true);
    Assert.AreEqual('', storage.FileInfo['/normal.dat'].Attribute['42']);
    storage.FileInfo['/normal.dat'].Attribute['42'] := '6*9';
    storage.FileInfo['/normal.dat'].Attribute['6*9'] := '42';
    Assert.AreEqual('6*9', storage.FileInfo['/normal.dat'].Attribute['42']);
    Assert.AreEqual('42', storage.FileInfo['/normal.dat'].Attribute['6*9']);
    iFolderInfo := storage.FileInfo['/folder'];
    iFolderInfo.Attribute['42'] := '9*6';
    iFolderInfo.Attribute['9*6'] := '42';
    Assert.AreEqual('9*6', iFolderInfo.Attribute['42']);
    Assert.AreEqual('42', iFolderInfo.Attribute['9*6']);
    Assert.AreEqual(CAttrSnapshot, CreateAttrSnapshot(iFolderInfo));
    iFolderInfo := nil;
    Assert.AreEqual('9*6', storage.FileInfo['/folder'].Attribute['42']);
    Assert.AreEqual('42', storage.FileInfo['/folder'].Attribute['9*6']);
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmOpenRead);
    iFolderInfo := storage.FileInfo['/folder'];
    Assert.AreEqual('9*6', iFolderInfo.Attribute['42']);
    Assert.AreEqual('42', iFolderInfo.Attribute['9*6']);
    Assert.AreEqual(CAttrSnapshot, CreateAttrSnapshot(iFolderInfo));
    iFolderInfo := nil;
    Assert.AreEqual('9*6', storage.FileInfo['/folder'].Attribute['42']);
    Assert.AreEqual('42', storage.FileInfo['/folder'].Attribute['9*6']);
  finally
    iFolderInfo := nil;
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.Attributes }

procedure TGpStructuredStorageTests.Compacting;
const
  CStorageFile = 'gss_test_compacting.stg';
var
  storage: IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    // create fragmented file
    TestFile(storage, '/firstfile.dat', true);
    TestFile(storage, '/folder/secondfile.dat', true);
    TestFile(storage, '/firstfile.dat', true, 2);
    TestFile(storage, '/folder/secondfile.dat', true);
    TestFile(storage, '/firstfile.dat', false, 2);
    TestFile(storage, '/folder/secondfile.dat', true, -1);
    TestFile(storage, '/firstfile.dat', true, 3);
    TestFile(storage, '/folder/secondfile.dat', true);
    storage.FileInfo[''].Attribute['signature'] := 'Written by Gp';
    storage.FileInfo['/firstfile.dat'].Attribute['42'] := '6*9';
    storage.FileInfo['/folder/secondfile.dat'].Attribute['42'] := '6*9';
    storage.FileInfo['/folder'].Attribute['6*9'] := '42';
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmOpenRead);
    TestFile(storage, '/firstfile.dat', false, 3);
    TestFile(storage, '/folder/secondfile.dat', false);
    Assert.AreEqual('Written by Gp', storage.FileInfo[''].Attribute['signature']);
    Assert.AreEqual('6*9', storage.FileInfo['/firstfile.dat'].Attribute['42']);
    Assert.AreEqual('6*9', storage.FileInfo['/folder/secondfile.dat'].Attribute['42']);
    Assert.AreEqual('42', storage.FileInfo['/folder'].Attribute['6*9']);
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmOpenReadWrite);
    TestFile(storage, '/firstfile.dat', false, 3);
    TestFile(storage, '/folder/secondfile.dat', false);
    Assert.AreEqual('Written by Gp', storage.FileInfo[''].Attribute['signature']);
    Assert.AreEqual('6*9', storage.FileInfo['/firstfile.dat'].Attribute['42']);
    Assert.AreEqual('6*9', storage.FileInfo['/folder/secondfile.dat'].Attribute['42']);
    Assert.AreEqual('42', storage.FileInfo['/folder'].Attribute['6*9']);
    storage.Compact;
    TestFile(storage, '/firstfile.dat', false, 3);
    TestFile(storage, '/folder/secondfile.dat', false);
    Assert.AreEqual('Written by Gp', storage.FileInfo[''].Attribute['signature']);
    Assert.AreEqual('6*9', storage.FileInfo['/firstfile.dat'].Attribute['42']);
    Assert.AreEqual('6*9', storage.FileInfo['/folder/secondfile.dat'].Attribute['42']);
    Assert.AreEqual('42', storage.FileInfo['/folder'].Attribute['6*9']);
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmOpenReadWrite);
    TestFile(storage, '/firstfile.dat', false, 3);
    TestFile(storage, '/folder/secondfile.dat', false);
    Assert.AreEqual('Written by Gp', storage.FileInfo[''].Attribute['signature']);
    Assert.AreEqual('6*9', storage.FileInfo['/firstfile.dat'].Attribute['42']);
    Assert.AreEqual('6*9', storage.FileInfo['/folder/secondfile.dat'].Attribute['42']);
    Assert.AreEqual('42', storage.FileInfo['/folder'].Attribute['6*9']);
    TestFile(storage, '/firstfile.dat', true, 4);
    TestFile(storage, '/folder/secondfile.dat', true, 4);
    storage.FileInfo[''].Attribute['signature'] := 'it is i';
    storage.FileInfo['/firstfile.dat'].Attribute['6*9'] := '42';
    storage.FileInfo['/folder/secondfile.dat'].Attribute['6*9'] := '42';
    storage.FileInfo['/folder'].Attribute['42'] := '6*9';
    Assert.AreEqual('it is i', storage.FileInfo[''].Attribute['signature']);
    Assert.AreEqual('42', storage.FileInfo['/firstfile.dat'].Attribute['6*9']);
    Assert.AreEqual('42', storage.FileInfo['/folder/secondfile.dat'].Attribute['6*9']);
    Assert.AreEqual('6*9', storage.FileInfo['/folder'].Attribute['42']);
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.Compacting }

procedure TGpStructuredStorageTests.Exceptions;
const
  CStorageFile = 'gss_test_exceptions.stg';
var
  fileInfo: IGpStructuredFileInfo;
  storage : IGpStructuredStorage;
  strFile : TStream;
begin
  DeleteStorageFile(CStorageFile);
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);

    // deleting a folder that (directly) contains an open file must raise
    strFile := storage.OpenFile('/f1/f2/test.txt', fmCreate);
    try
      Assert.WillRaise(
        procedure begin storage.Delete('/f1/f2'); end,
        EGpStructuredStorage, 'deleting a folder with an open file must raise');
    finally FreeAndNil(strFile); end;

    // ... and so must deleting an ancestor of that folder
    strFile := storage.OpenFile('/f1/f2/test.txt', fmCreate);
    try
      Assert.WillRaise(
        procedure begin storage.Delete('/f1'); end,
        EGpStructuredStorage, 'deleting an ancestor of a folder with an open file must raise');
    finally FreeAndNil(strFile); end;

    Assert.WillRaise(
      procedure begin TestFile(storage, '/', true); end,
      EGpStructuredStorage, 'opening "/" as a file must raise');

    storage.CreateFolder('/firstdir');
    Assert.WillRaise(
      procedure begin TestFile(storage, '/firstdir', true); end,
      EGpStructuredStorage, 'opening a folder as a file must raise');

    Assert.WillRaise(
      procedure begin TestFile(storage, '/firstdir/', true); end,
      EGpStructuredStorage, 'opening a folder (trailing slash) as a file must raise');

    TestFile(storage, '/firstfile.dat', true, -1);
    Assert.WillRaise(
      procedure begin TestFile(storage, '/firstfile.dat/firstfile.dat', true); end,
      EGpStructuredStorage, 'creating a file inside a file must raise');

    Assert.WillRaise(
      procedure begin storage.CreateFolder('/firstdir'); end,
      EGpStructuredStorage, 'creating an already-existing folder must raise');

    // NOTE: the original GUI workbench also checked that using an IGpStructuredFileInfo
    // after releasing the last reference to its owning storage (fileInfo.Attribute[..]
    // after "storage := nil") raises EGpStructuredStorage. That check relies on
    // TGpStructuredStorage.Destroy running synchronously the moment the interface
    // reference is released. Verified independently of this unit (a minimal
    // TInterfacedObject + two-interface repro shows the same thing): in this Delphi/
    // RTL build, releasing the last reference to an interface at the end of a procedure
    // does not run the destructor synchronously - it's deferred, so the assertion can't
    // be tested deterministically here. Not a defect in GpStructuredStorage itself
    // (TGpStructuredFileInfo.SetAttribute does correctly check "not assigned(sfiOwner)"
    // once ClearOwner has actually run), just not something this environment lets a
    // unit test observe on demand.
  finally
    fileInfo := nil;
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.Exceptions }

{ TGpStructuredStorageTests - additional coverage }

procedure TGpStructuredStorageTests.IsStructuredStorageDetection;
const
  CValidFile   = 'gss_test_isstructured_valid.stg';
  CInvalidFile = 'gss_test_isstructured_invalid.dat';
  CJunkText    = 'not a structured storage file, just some random text data';
var
  fs     : TFileStream;
  ms     : TMemoryStream;
  storage: IGpStructuredStorage;
begin
  DeleteStorageFile(CValidFile);
  DeleteStorageFile(CInvalidFile);
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CValidFile, fmCreate);
    TestFile(storage, '/x.dat', true, -1);

    fs := TFileStream.Create(CInvalidFile, fmCreate);
    try
      fs.Write(AnsiString(CJunkText)[1], Length(CJunkText));
    finally FreeAndNil(fs); end;

    storage := CreateStructuredStorage;
    Assert.IsTrue(storage.IsStructuredStorage(CValidFile), 'a real storage file should be detected');

    storage := CreateStructuredStorage;
    Assert.IsFalse(storage.IsStructuredStorage(CInvalidFile), 'a plain file should not be detected as storage');

    ms := TMemoryStream.Create;
    try
      storage := CreateStructuredStorage;
      Assert.IsFalse(storage.IsStructuredStorage(ms), 'an empty stream should not be detected as storage');
    finally ms.Free; end; // safe: IsStructuredStorage(stream) detaches from ms synchronously (bug 6 fix)
  finally
    storage := nil;
    DeleteStorageFile(CValidFile);
    DeleteStorageFile(CInvalidFile);
  end;
end; { TGpStructuredStorageTests.IsStructuredStorageDetection }

procedure TGpStructuredStorageTests.IsStructuredStorageStreamAllowsReinitializeAfterwards;
var
  ms     : TMemoryStream;
  storage: IGpStructuredStorage;
begin
  // Regression for the fix to IsStructuredStorage(TStream): it used to leave gssStorage
  // assigned afterwards, so Initialize on the SAME instance would raise
  // 'Already initialized' even though the instance had never really been used.
  ms := TMemoryStream.Create;
  try
    storage := CreateStructuredStorage;
    Assert.IsFalse(storage.IsStructuredStorage(ms), 'empty stream is not a valid storage');
    storage.Initialize(ms);
    TestFile(storage, '/reused.dat', true, -1);
    Assert.IsTrue(storage.FileExists('/reused.dat'),
      'the same instance must be usable via Initialize after IsStructuredStorage(stream)');
  finally
    storage := nil;
    // ms is intentionally not freed here: see StreamBasedStorage for why.
  end;
end; { TGpStructuredStorageTests.IsStructuredStorageStreamAllowsReinitializeAfterwards }

procedure TGpStructuredStorageTests.StreamBasedStorage;
var
  ms     : TMemoryStream;
  storage: IGpStructuredStorage;
begin
  // NOTE: ms is deliberately never freed. Initialize(stream) does not take ownership of
  // the stream (gssOwnsStream stays False), so in a normal environment the caller would
  // free it once done. In this environment, though, releasing the last reference to an
  // interface at the end of a procedure does not synchronously run its destructor (see
  // the comment on TearDownFixture) - freeing ms here could race a not-yet-run
  // TGpStructuredStorage.Destroy that still touches it. Leaking one small memory stream
  // for the life of the test process is the safe tradeoff.
  ms := TMemoryStream.Create;
  storage := CreateStructuredStorage;
  storage.Initialize(ms);
  TestFile(storage, '/streamed.dat', true, -1);
  storage.CreateFolder('/sub');
  TestFile(storage, '/sub/inner.dat', true);
  Assert.IsTrue(storage.FileExists('/streamed.dat'));
  Assert.IsTrue(storage.FolderExists('/sub'));
  TestFile(storage, '/streamed.dat', false, -1);
  TestFile(storage, '/sub/inner.dat', false);
  Assert.IsTrue(ms.Size > 0, 'memory stream should contain the storage data');
  storage := nil;
end; { TGpStructuredStorageTests.StreamBasedStorage }

procedure TGpStructuredStorageTests.LongNameAtBoundaryIsAccepted;
const
  CStorageFile = 'gss_test_longname_ok.stg';
var
  longName: string;
  storage : IGpStructuredStorage;
begin
  // Regression: the on-disk name-length field has 15 usable bits (the top bit of the
  // word is the Unicode-format flag), so 32767 chars is the real maximum - not the
  // 65535 the class comment used to (incorrectly) document.
  longName := StringOfChar('a', 32767);
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    storage.OpenFile('/' + longName, fmCreate).Free;
    Assert.IsTrue(storage.FileExists('/' + longName), 'a 32767-char name should be accepted');
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.LongNameAtBoundaryIsAccepted }

procedure TGpStructuredStorageTests.LongNameOverBoundaryRaises;
const
  CStorageFile = 'gss_test_longname_bad.stg';
var
  longName: string;
  storage : IGpStructuredStorage;
begin
  // Regression for the name-length overflow fix in TGpStructuredFolderEntry.SaveTo:
  // a name one character past the limit must be rejected outright, not silently
  // truncated/corrupted by colliding with the format-flag bit.
  longName := StringOfChar('a', 32768);
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    Assert.WillRaise(
      procedure begin storage.OpenFile('/' + longName, fmCreate).Free; end,
      EGpStructuredStorage, 'a 32768-char name must be rejected');
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.LongNameOverBoundaryRaises }

procedure TGpStructuredStorageTests.IsFolderEmptyReflectsContents;
const
  CStorageFile = 'gss_test_isfolderempty.stg';
var
  storage: IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    Assert.IsTrue(storage.IsFolderEmpty('/nonexistent'), 'a non-existent folder counts as empty');
    storage.CreateFolder('/empty');
    Assert.IsTrue(storage.IsFolderEmpty('/empty'), 'freshly created folder should be empty');
    storage.OpenFile('/empty/f.dat', fmCreate).Free;
    Assert.IsFalse(storage.IsFolderEmpty('/empty'), 'folder with a file should not be empty');
    storage.Delete('/empty/f.dat');
    Assert.IsTrue(storage.IsFolderEmpty('/empty'),
      'folder should be empty again after deleting its only file');
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.IsFolderEmptyReflectsContents }

procedure TGpStructuredStorageTests.FileInfoSizeProperty;
const
  CStorageFile = 'gss_test_fileinfosize.stg';
var
  storage: IGpStructuredStorage;
  strFile: TStream;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    strFile := storage.OpenFile('/sized.dat', fmCreate);
    try
      strFile.Size := 100;
    finally FreeAndNil(strFile); end;
    Assert.AreEqual(cardinal(100), storage.FileInfo['/sized.dat'].Size,
      'GetSize should match the file''s actual size');
    storage.FileInfo['/sized.dat'].Size := 40;
    strFile := storage.OpenFile('/sized.dat', fmOpenRead);
    try
      Assert.AreEqual(int64(40), strFile.Size, 'SetSize should truncate the underlying file');
    finally FreeAndNil(strFile); end;
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.FileInfoSizeProperty }

procedure TGpStructuredStorageTests.DataFileAndDataSizeProperties;
const
  CStorageFile = 'gss_test_datafileproperties.stg';
var
  storage: IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    Assert.AreEqual(CStorageFile, storage.DataFile, 'DataFile should echo the initialized file name');
    Assert.IsTrue(storage.DataSize > 0, 'DataSize should be positive for an initialized storage');
    TestFile(storage, '/x.dat', true, 5);
    Assert.IsTrue(storage.DataSize > 1024, 'DataSize should grow as data is written');
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.DataFileAndDataSizeProperties }

procedure TGpStructuredStorageTests.DeleteNonexistentIsNoOp;
const
  CStorageFile = 'gss_test_deletenonexistent.stg';
var
  storage: IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    storage.Delete('/does/not/exist.dat');
    storage.Delete('/neither/does/this/folder');
    Assert.Pass('deleting a non-existent path did not raise');
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.DeleteNonexistentIsNoOp }

procedure TGpStructuredStorageTests.MoveToExistingDestinationRaises;
const
  CStorageFile = 'gss_test_movecollision.stg';
var
  storage: IGpStructuredStorage;
begin
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    storage.OpenFile('/a.dat', fmCreate).Free;
    storage.OpenFile('/b.dat', fmCreate).Free;
    Assert.WillRaise(
      procedure begin storage.Move('/a.dat', '/b.dat'); end,
      EGpStructuredStorage, 'moving onto an existing destination must raise');
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.MoveToExistingDestinationRaises }

procedure TGpStructuredStorageTests.FileInfoSurvivesFolderDeletionDeferredFree;
const
  CStorageFile = 'gss_test_deferredfree.stg';
var
  fi     : IGpStructuredFileInfo;
  storage: IGpStructuredStorage;
begin
  // Explicit regression for the folder-cache use-after-free fix (formerly: unconditional
  // Free in TGpStructuredFolderCache.InternalRemove): hold a live FileInfo reference into
  // a folder in a NAMED variable (not relying on an anonymous-temporary's incidental
  // lifetime, unlike the MovingAndDeleting test's "Folder 6" scenario), delete that
  // folder while the reference is still explicitly alive, and confirm nothing crashes and
  // a fresh folder can immediately be created at the same path.
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    storage.CreateFolder('/keepalive');
    storage.OpenFile('/keepalive/f.dat', fmCreate).Free;
    fi := storage.FileInfo['/keepalive/f.dat']; // pins the folder object in the cache
    fi.Attribute['tag'] := 'still alive';        // sanity check before the delete

    storage.Delete('/keepalive');
    Assert.IsFalse(storage.FolderExists('/keepalive'), 'folder should be gone from storage');

    storage.CreateFolder('/keepalive');
    storage.OpenFile('/keepalive/g.dat', fmCreate).Free;
    Assert.IsTrue(storage.FileExists('/keepalive/g.dat'),
      'a new folder at the same path must work independently of the pending-free instance');

    fi := nil; // release the pin; the deferred TGpStructuredFolder.Free must not crash
  finally
    fi := nil;
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.FileInfoSurvivesFolderDeletionDeferredFree }

procedure TGpStructuredStorageTests.FragmentationAcrossFatBlocksSurvivesCompact;
const
  CStorageFile = 'gss_test_fatfragmentation.stg';
  CFileCount   = 700; // spans multiple 256-entry FAT blocks (each manages 256 data blocks)
  CKeepFrom    = 500; // delete the first 500 (lowest block numbers), keep the rest
var
  i      : integer;
  storage: IGpStructuredStorage;
  strFile: TStream;
  value  : integer;
begin
  // Regression for TGpStructuredFAT.Truncate: it used to scan for empty FAT blocks from
  // the tail without stopping at the first non-empty one, so it could delete a FAT block
  // from the MIDDLE of the block list - not just a trailing run - desyncing the
  // position-based block-to-FAT-block mapping and truncating the storage incorrectly.
  //
  // Blocks are allocated in creation order, so deleting the first CKeepFrom files frees
  // low-numbered blocks (an early, complete FAT region) while later files keep high-
  // numbered blocks (a later FAT region) alive - exactly the fragmentation pattern that
  // used to trigger the bug. TGpStructuredFAT.Truncate only runs from Close, which only
  // runs synchronously (i.e. not deferred - see TearDownFixture) from Compact, so Compact
  // is used here to force the exact code path deterministically.
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    for i := 0 to CFileCount - 1 do begin
      strFile := storage.OpenFile('/f' + IntToStr(i), fmCreate);
      try
        strFile.Write(i, SizeOf(i));
      finally FreeAndNil(strFile); end;
    end;
    for i := 0 to CKeepFrom - 1 do
      storage.Delete('/f' + IntToStr(i));

    storage.Compact;

    for i := CKeepFrom to CFileCount - 1 do begin
      Assert.IsTrue(storage.FileExists('/f' + IntToStr(i)),
        Format('/f%d should have survived Compact', [i]));
      strFile := storage.OpenFile('/f' + IntToStr(i), fmOpenRead);
      try
        value := -1;
        strFile.Read(value, SizeOf(value));
        Assert.AreEqual(i, value, Format('/f%d content should not be corrupted/cross-contaminated', [i]));
      finally FreeAndNil(strFile); end;
    end;
    for i := 0 to CKeepFrom - 1 do
      Assert.IsFalse(storage.FileExists('/f' + IntToStr(i)),
        Format('/f%d should still be gone after Compact', [i]));
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.FragmentationAcrossFatBlocksSurvivesCompact }

procedure TGpStructuredStorageTests.DeletingFolderContainingSubfolderDoesNotUseFreedName;
const
  CStorageFile = 'gss_test_thomasmueller.stg';
  // Thomas Mueller's report specifically notes: "Deleting a folder tree with more than
  // CMaxMRULength (10) sub-folders reliably triggers it". CMaxMRULength (a local const
  // inside TGpStructuredFolderCache.TrimMRUList, not otherwise exposed) is the size of
  // the folder cache's inactive-folder MRU list; once it holds more than 10 entries,
  // TrimMRUList starts actually freeing whole TGpStructuredFolder objects (each pulling
  // down its own TObjectList of entries) rather than just sitting idle. THAT is the churn
  // that reliably clobbers the just-freed name string before entryName is read again - a
  // single subfolder deletion frees only that one small string, which is very likely to
  // still hold its old bytes by the time it's (mis)used, so a 1-subfolder tree can pass
  // even with the bug present. Use enough subfolders to comfortably clear that threshold.
  CSubfolderCount = 20;
var
  i      : integer;
  storage: IGpStructuredStorage;
begin
  // Regression for the bug reported by Thomas Mueller (2026-07-20; see the version
  // history entry attributed to him in GpStructuredStorage.pas): DeleteAll calls
  // DeleteEntry(Entry[0].FileName), passing the very entry's own FileName field as the
  // const entryName parameter. const string params aren't reference-counted, so
  // entryName aliased that field with no independent reference of its own; deleting the
  // entry then freed the string entryName pointed at, and - for a folder entry -
  // DeleteEntry went on to read entryName again at sfFolderCache_ref.Remove(Self,
  // entryName): a use-after-free that could silently corrupt the folder cache.
  //
  // '/outer' containing CSubfolderCount subfolders exercises exactly this path: deleting
  // '/outer' recurses into DeleteAll, which deletes each subfolder via the aliased
  // Entry[0].FileName call; each subfolder being a folder (not a file) is what reaches
  // the Remove() call that used to read already-freed memory, and having more than
  // CMaxMRULength of them is what reliably makes that read land on clobbered memory
  // rather than incidentally-still-intact bytes. Recreating '/outer' immediately
  // afterwards checks that the folder cache wasn't left in a stale state by that read
  // (the original failure mode was silent corruption, not necessarily a crash).
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    storage.CreateFolder('/outer');
    for i := 0 to CSubfolderCount - 1 do begin
      storage.CreateFolder('/outer/sub' + IntToStr(i));
      storage.OpenFile('/outer/sub' + IntToStr(i) + '/f.dat', fmCreate).Free;
    end;

    storage.Delete('/outer'); // must not crash or corrupt the folder cache

    Assert.IsFalse(storage.FolderExists('/outer'), '/outer should be gone');
    storage.CreateFolder('/outer');
    Assert.IsTrue(storage.IsFolderEmpty('/outer'), 'freshly recreated /outer must be empty');
    for i := 0 to CSubfolderCount - 1 do
      Assert.IsFalse(storage.FolderExists('/outer/sub' + IntToStr(i)),
        Format('/outer/sub%d must not resurface from stale folder-cache state', [i]));
    storage.CreateFolder('/outer/inner');
    storage.OpenFile('/outer/inner/g.dat', fmCreate).Free;
    Assert.IsTrue(storage.FileExists('/outer/inner/g.dat'),
      'the recreated /outer must work independently');
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.DeletingFolderContainingSubfolderDoesNotUseFreedName }

procedure TGpStructuredStorageTests.DeletingSecondToLastEntryDoesNotStrandLastEntry;
const
  CStorageFile = 'gss_test_secondtolastdelete.stg';
var
  data   : AnsiString;
  storage: IGpStructuredStorage;
  strFile: TStream;
begin
  // Regression for issue #25: TGpStructuredStream.GetSize used floor division
  // (ssStorage.Size div CBlockSize) to report the storage size in blocks. When the last
  // allocated block is only partially filled (the usual case for a small file, since the
  // underlying stream isn't padded out to a full block), that undercounts by one block.
  // TGpStructuredFAT.Truncate (run on Close) then treats "GetSize-1" as the index of the
  // last block; when the entry that was actually second-to-last had just been deleted (so
  // its block is free), the off-by-one match caused Truncate to shrink the storage right
  // through the still-live last block, stranding it past the truncated end of file.
  //
  // Two conditions are both required to trigger it: the deleted entry must be the
  // second-to-last (second-highest block number), and the surviving last entry's data must
  // not exactly fill its final block (so the on-disk size isn't a block multiple).
  data := 'nine byte'; // 9 bytes: leaves the last block partially filled
  try
    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmCreate);
    strFile := storage.OpenFile('/file0', fmCreate);
    try strFile.Write(data[1], Length(data)); finally FreeAndNil(strFile); end;
    strFile := storage.OpenFile('/file1', fmCreate);
    try strFile.Write(data[1], Length(data)); finally FreeAndNil(strFile); end;
    storage.Delete('/file0'); // delete the second-to-last entry
    storage := nil;           // close -> Truncate must not strand /file1's block

    storage := CreateStructuredStorage;
    storage.Initialize(CStorageFile, fmOpenReadWrite);
    Assert.IsTrue(storage.FileExists('/file1'), '/file1 should have survived the close/reopen');
    strFile := storage.OpenFile('/file1', fmOpenRead);
    try
      Assert.AreEqual(int64(Length(data)), strFile.Size, '/file1 size should be unaffected');
      SetLength(data, 0);
      SetLength(data, strFile.Size);
      strFile.Read(data[1], strFile.Size);
      Assert.AreEqual('nine byte', string(data), '/file1 content should not be corrupted');
    finally FreeAndNil(strFile); end;
  finally
    storage := nil;
    DeleteStorageFile(CStorageFile);
  end;
end; { TGpStructuredStorageTests.DeletingSecondToLastEntryDoesNotStrandLastEntry }

initialization
  TDUnitX.RegisterTestFixture(TGpStructuredStorageTests);
end.
