(*:Structured storage (compound file; file system inside a file) implementation.
   Inspired by the Compound File implementation written by Julian M Bucknall
   (http://www.boyet.com/).
   Not threadsafe.
   @author Primoz Gabrijelcic
   @desc <pre>

This software is distributed under the BSD license.

Copyright (c) 2011, Primoz Gabrijelcic
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
   Creation date     : 2003-11-10
   Last modification : 2011-01-01
   Version           : 2.0c
</pre>*)(*
   History:
     2.0c: 2011-01-01
       - Uses GpStreams instead of GpMemStr.
     2.0b: 2010-05-16
       - Bug fixed: When the folder was deleted, it was not removed from the folder cache.
         Because of that, subsequent FolderExists call succeeded instead of failed, which
         could cause all sorts of weird problems.
     2.0a: 2009-09-01
       - [Erik Berry] Definition of fmCreate in Delphi 2010 has changed and code had to 
         be adjusted.
     2.0: 2008-05-31
       - Added Unicode support to the underlying storage. File and folder names are stored
         in UTF-16, as are attribute names and values. API is still based on Delphi's
         'string' type - meaning that values are converted to Unicode and back on the fly
         using the current locale.
       - Existing structured storage files will be upgraded automatically if they are not
         open for readonly access. Applications, compiled with GpStructuredStorage 1.x
         will not be able to read new/upgraded files. Version is incremented to 2.0.0.0
         when 1.x file is opened unless it is opened in readonly mode. Newly created
         storages have version 2.0.0.0.
     1.12a: 2006-12-06
       - Fixed potential accvio in TGpStructuredStorage destructor.
     1.12: 2006-11-23
       - Big speed optimizations in directory access.
     1.11: 2006-10-20
       - Added test to raise exception if programmer tries to delete a folder containing
         open files.
     1.10c: 2006-09-17
       - FileInfo['/'] was not working. Fixed.
         (FileInfo['/'] is equivalent to FileInfo[''].)
       - Backslashes in parameter were not converted to slashes in FileInfo. Fixed.
     1.10b: 2006-07-20
       - Memory leak fixed: Internal objects representing folders were never freed. 
     1.10a: 2006-01-30
       - Fixed TGpStructuredStorage.Delete to not unnecessary auto-create parent folders.
       - Fixed TGpStructuredStorage.IsFolderEmpty to work when unexistent path is passed
         as a parameter.
     1.10: 2006-01-29
       - Added method IGpStructuredStorage.IsFolderEmpty.
     1.09: 2006-01-20
       - Major speedup in Folder flushing.
     1.08a: 2005-05-02
       - Fixed crash in Compact (signature of GetTempFileName was invalid).
     1.08: 2004-12-16
       - Added two overloaded versions of the IsStructuredStorage function to the
         interface.
     1.07: 2004-12-15
       - Added DataSize property to the interface.
     1.06c: 2004-03-11
       - DeleteAll assertion changed to hard exception.
     1.06b: 2004-03-10
       - Fixed bug in the Delete method - when a folder was deleted, folder attribute file
         was left in the storage.
       - Added assertion to the DeleteAll method.
     1.06a: 2004-03-09
       - [Erik Berry] Bug fixed in the DeleteAll method which could cause AV.
       - [Erik Berry] Bug fixed in the destructor (triggered if the Initialize failed).
     1.06: 2004-03-02
       - DeleteFile method renamed to Delete.
       - Added methods FileExists, FolderExists, CreateFolder, Move, Compact.
       - Supports notation FileInfo[''].Attribute (access to storage-global attributes).
       - Supports notation FileInfo['folder'].Attribute (access to folder attributes).
       - OpenFile now checks that the file name is not empty.
       - More aggresive storage truncation on close.
       - FileNames was returning names of internal attribute files. Fixed.
       - Internal attribute files were not preserved when storage file was closed and
         reopened. Fixed.
       - File system version changed to 1.0.2.0 because of header reorganization and
         global attribute file.
     1.05: 2004-02-22
       - Attribute name and value changed from WideString to string.
       - Added method IGpStructuredFileInfo.AttributeNames.
       - File system version changed to 1.0.1.0 (because the attribute type change makes
         1.05 filesystem incompatible with older versions).
     1.04: 2004-02-18
       - Attributes implemented (via the FileInfo[] property).
     1.03: 2004-02-17
       - Changed FileNames and FolderNames to accept TStrings parameter which is then
         filled with the data.
       - Changed Initialize to raise EGpStructuredStorage on error instead of returning
         boolean.
     1.02: 2004-02-16
       - Few 257 constants replaced with (CFATEntriesPerBlock+1).
       - As much of the file as possible (unused parts) is truncated on Destroy.
       - Free list is reordered in ascending order on Destroy.
     1.01: 2004-02-16
       - Added DeleteFile.
*)

unit GpStructuredStorage;

interface

uses
  Windows,
  SysUtils,
  Classes,
  GpLists;

const
  //:Structured storage path delimiter.
  CFolderDelim = '/';

type
  {:Structured storage exception class.
    @since   2004-01-08
  }
  EGpStructuredStorage = class(Exception);

  {:Information on one file in the structured storage.
    @since   2004-02-18
  }
  IGpStructuredFileInfo = interface ['{A79D2354-99D3-4D7B-841F-8A929971AE89}']
  //accessors
    function  GetAttribute(const attributeName: string): string;
    function  GetSize: cardinal;
    procedure SetAttribute(const attributeName: string; const value: string);
    procedure SetSize(value: cardinal);
  //public
    //:Fills the list with all defined attribute names.
    procedure AttributeNames({out} attributes: TStrings);
    //:File attributes.
    property Attribute[const attributeName: string]: string read GetAttribute write
      SetAttribute;
    //:File size.
    property Size: cardinal read GetSize write SetSize;
  end; { IGpStructuredFileInfo }

  {:Main structured storage interface. Note that directories are automatically vivified
    and destroyed.
    @since   2004-01-06
  }
  IGpStructuredStorage = interface ['{7166B79A-8DDB-4842-8BA9-C5F9A64B0E1B}']
  //accessors
    function  GetDataFile: string;
    function  GetDataSize: integer;
    function  GetFileInfo(const fileName: string): IGpStructuredFileInfo;
  //public
    //:Checks if a data file contains structured storage.
    function  IsStructuredStorage(const storageDataFile: string): boolean; overload;
    //:Checks if a stream contains structured storage.
    function  IsStructuredStorage(storageDataStream: TStream): boolean; overload;
    //:Initializes file-based structured storage. Just a wrapper around the other Initialize.
    procedure Initialize(const storageDataFile: string; mode: word); overload;
    //:Initializes stream-based structured storage.
    procedure Initialize(storageDataStream: TStream); overload;
    (*:Opens/creates a file. 'FileName' parameter must contain full path. Folders are
       created automatically. 'Mode' parameter is the same as in the TFileStream.Create.
       fmCreate: Creates/overwrites a file.
       fmOpenRead, fmOpenWrite, fmOpenReadWrite: Opens existing file in read-write mode.
       Read-only mode is not supported (but is automatically enforced if underlying
       storage is open read-only.
       @param   fileName Absolute path of the file to be created/open. Must start with a
                         folder delimiter (\ or /) and can contain any ascii character
                         except #0, \ and /. In Unicode Delphis, all Unicode characters
                         except mentioned three are allowed.
       @returns Nil if file does not exist and mode is not fmCreate; an object
                representing the file otherwise. Caller is responsible for destroying this
                object. *)
    function  OpenFile(const fileName: string; mode: word): TStream;
    (*:Creates new folder. 'FolderName' parameter must contain full path. All intermediate
       are created automatically.*)
    procedure CreateFolder(const folderName: string);
    //:Moves a file or folder.
    procedure Move(const objectName, newName: string);
    //:Deletes a file or folder. When deleting folder, all subfolders and files are automatically deleted.
    procedure Delete(const objectName: string);
    //:Checks whether the specified file exists.
    function  FileExists(const fileName: string): boolean;
    //:Checks whether the specified folder exists.
    function  FolderExists(const folderName: string): boolean;
    //:Returns list of files in folder 'folderName'.
    procedure FileNames(const folderName: string; {out} files: TStrings);
    //:Returns list of folders in folder 'folderName'.
    procedure FolderNames(const folderName: string; {out} folders: TStrings);
    //:Fast way to check if folder is empty.
    function  IsFolderEmpty(const folderName: string): boolean;
    //:Compacts the structured storage (by copying it to a temporary file and then back).
    procedure Compact;
    //:Returns name of the underlying data file or '' if storage is stream-based.
    property DataFile: string read GetDataFile;
    //:Returns size of the underlying data file.
    property DataSize: integer read GetDataSize;
    //:Returns file information interface.
    property FileInfo[const fileName: string]: IGpStructuredFileInfo read GetFileInfo;
  end; { IGpStructuredStorage }

  IGpDebugStructuredStorage = interface ['{8F6AA5E9-24DF-4312-A779-19DD78C5CB96}']
    procedure Dump(const fileName: string);
  end; { IGpDebugStructuredStorage }

{:Creates an instance of a structured storage.
  @since   2004-12-16
}
function CreateStructuredStorage: IGpStructuredStorage;

implementation
                 
uses
  Contnrs,
  Math,
  SyncObjs,
  GpStreams;

const
  CLowestSupported: cardinal = $01000200; // 1.0.2.0
  CVersion:         cardinal = $02000000; // 2.0.0.0

  CBlockSize          = 1024 {bytes};
  CFATEntriesPerBlock = CBlockSize div 4;

  CSignature: AnsiString   = 'GpStructuredStorage file'#13#10#26#0;

  //Numerical attribute representation. When changing, modify methods NumToAttributes and AttributesToNum.
  CAttrIsFolder        = $00000001;
  CAttrIsAttributeFile = $00000002;

(*
  Structured storage internals:
  [header:HEADER:1024]
  [fat entry:FATENTRY:1024]
  256 x [block:FOLDER/FILE:1024]
  [fat entry:FATENTRY:1024]
  256 x [block:FOLDER/FILE:1024]
  ...
  [fat entry:FATENTRY:1024]
  <=256 x [block:FOLDER/FILE:1024]

  HEADER:
  [signature:32]                     // AnsiChar
  [unused:964]
  [storage attribute file:4]
  [storage attribute file size:4]
  [first FAT block:4]
  [first unused block:4]
  [root folder:4]
  [root folder size:4]
  [version:4]                        // storage system version

  FATENTRY:
  256*[next block:4]                 // next-pointers for this block; 0 = unused

  FOLDER:                            // split over several blocks; FOLDER is a FILE
  [FILE_INFO]
  [FILE_INFO]
  [...]
  [FILE_INFO]
  [0:2]

  FILE_INFO:
  [file name length:2]               // highest bit is used to separate Ansi file name (0)
                                     // from Unicode UTF-16 (1)
  [file name:1..32767]               // UTF-16
  [file attributes:ATTRIBUTES:4]
  [file length:4]                    // 4 GB per file
  [first file block:4]

  ATTRIBUTES:
  $0001 = attrIsFolder
  $0002 = attrIsAttributeFile

  FILE:
  [byte blob]
*)

type
  {$IFDEF Unicode}
  TUnicodeString = string;
  {$ELSE}
  TUnicodeString = WideString;
  {$ENDIF Unicode}

  {:Stream wrapper, used for all accesses to structured storage.
    @since   2004-01-06
  }
  TGpStructuredStream = class
  private
    ssStorage: TStream;
  protected
    function  GetOffset: integer;
    function  GetPosition: integer;
    function  GetSize: integer;
    procedure SetOffset(const value: integer);
    procedure SetPosition(const value: integer);
    procedure SetSize(const value: integer);
  public
    constructor Create(storage: TStream);
    function  ReadBuffer(var buffer; numBytes: integer): integer; overload;
    function  ReadStream(stream: TStream; numBytes: integer): integer; overload;
    procedure Truncate(atBlock: integer);
    procedure WriteBuffer(const buffer; numBytes: integer); overload;
    procedure WriteStream(stream: TStream; numBytes: integer = 0); overload;
    property Offset: integer read GetOffset write SetOffset;
    property Position: integer read GetPosition write SetPosition;
    property Size: integer read GetSize write SetSize;
  end; { TGpStructuredStream }

  {:Header in the structured storage data file.
    @since   2003-11-24
  }
  TGpStructuredHeader = class
  private
    shPointers: array [-6..0] of cardinal;
    shStorage : TGpStructuredStream;
  protected
    function  GetCardinal(index: integer): cardinal;
    procedure SetCardinal(index: integer; const value: cardinal);
  public
    constructor Create(storage: TGpStructuredStream);
    function  CreateHeader: boolean;
    function  LoadHeader: boolean;
    property FirstEmptyBlock: cardinal index -3 read GetCardinal write SetCardinal;
    property FirstFATBlock: cardinal index -4 read GetCardinal write SetCardinal;
    property FirstRootFolderBlock: cardinal index -2 read GetCardinal write SetCardinal;
    property RootFolderSize: cardinal index -1 read GetCardinal write SetCardinal;
    //following properties are ordered by the offset from the end of block 0
    property StorageAttributeFile: cardinal index -6 read GetCardinal write SetCardinal;
    property StorageAttributeFileSize: cardinal index -5 read GetCardinal write SetCardinal;
    property Version: cardinal index 0 read GetCardinal write SetCardinal;
  end; { TGpStructuredHeader }

  TGpStructuredFolder = class;
  TGpStructuredFAT = class;
  TGpStructuredStorage = class;

  {:Internal file attributes
    @enum    sfAttrIsFolder        Entry represents a folder.
    @enum    sfAttrIsAttributeFile Entry represents a hidden attribute file.
    @since   2004-02-14
  }
  TGpStructuredFileAttribute = (sfAttrIsFolder, sfAttrIsAttributeFile);
  TGpStructuredFileAttributes = set of TGpStructuredFileAttribute;

  {:Low-level file object. Manages FAT chain and provides TStream-compatible
    access.
  }
  TGpStructuredFile = class(TStream)
  private
    sfAttributes        : TGpStructuredFileAttributes;
    sfCurrentBlock      : cardinal;
    sfCurrentBlockOffset: cardinal;
    sfCurrentPos        : integer;
    sfFileSize          : integer;
    sfFirstBlock        : cardinal;
    sfFolder            : TGpStructuredFolder;
    sfName              : string;
    sfOnSizeChanged     : TNotifyEvent;
    sfOwner             : TGpStructuredStorage;
  protected
    function  FAT: TGpStructuredFAT;
    procedure NotifySizeChange;
    procedure ResolvePosition;
    procedure SetParent(newParentFolder: TGpStructuredFolder);
    procedure SetSize(newSize: longint); override;
    function  Storage: TGpStructuredStream;
    property  Owner: TGpStructuredStorage read sfOwner;
  public
    constructor Create(owner: TGpStructuredStorage; folder: TGpStructuredFolder;
      fileName: string; firstBlock, fileSize: cardinal;
      attributes: TGpStructuredFileAttributes);
    destructor  Destroy; override;
    function FullPath: string;
    //TStream interface
    function Read(var buffer; count: longint): longint; override;
    function Write(const buffer; count: longint): longint; override;
    function Seek(offset: longint; origin: Word): longint; override;
    property Attributes: TGpStructuredFileAttributes read sfAttributes;
    property FileName: string read sfName write sfName;
    property Folder: TGpStructuredFolder read sfFolder;
    property OnSizeChanged: TNotifyEvent read sfOnSizeChanged write sfOnSizeChanged;
  end; { TGpStructuredFile }

  {:One folder entry.
    @since   2003-11-24
  }
  TGpStructuredFolderEntry = class
  private
    sfeAttributes   : TGpStructuredFileAttributes;
    sfeFileName     : string;
    sfeFirstFatEntry: cardinal;
    sfeLength       : cardinal;
  protected
    class function AttributesToNum(attr: TGpStructuredFileAttributes): cardinal;
    class function NumToAttributes(attr: cardinal): TGpStructuredFileAttributes;
  public
    constructor Create(const entryName: string; attributes: TGpStructuredFileAttributes;
      length, firstFatEntry: cardinal); overload;
    function  LoadFrom(stream: TStream): boolean;
    procedure SaveTo(stream: TStream);
    property Attributes: TGpStructuredFileAttributes read sfeAttributes;
    property FileLength: cardinal read sfeLength write sfeLength;
    property FileName: string read sfeFileName write sfeFileName;
    property FirstFatEntry: cardinal read sfeFirstFatEntry;
  end; { TGpStructuredFolderEntry }

  {:Interface to file properties.
    @since   2004-02-18
  }
  TGpStructuredFileInfo = class(TInterfacedObject, IGpStructuredFileInfo)
  private
    sfiFileName: string;
    sfiFolder  : TGpStructuredFolder;
    sfiOwner   : TGpStructuredStorage;
  protected
    procedure AccessFile(var strFile: TGpStructuredFile);
    function  GetAttribute(const attributeName: string): string;
    function  GetSize: cardinal;
    procedure ListAttributes(attrStream: TStream; {out} attributes: TStrings);
    function  RetrieveAttribute(attrStream: TStream;
      const attributeName: string): string;
    procedure SetAttribute(const attributeName: string; const value: string);
    procedure SetSize(value: cardinal);
    procedure UpdateAttribute(attrStream: TStream; const attributeName,
      attributeValue: string);
  public
    constructor Create(owner: TGpStructuredStorage; folder: TGpStructuredFolder;
      const fileName: string);
    destructor  Destroy; override;
    procedure ClearOwner;
    //:Fills the list with all defined attribute names.
    procedure AttributeNames({out} attributes: TStrings);
    //:File attributes.
    property Attribute[const attributeName: string]: string read GetAttribute write
      SetAttribute;
    //:File size.
    property Size: cardinal read GetSize write SetSize;
  end; { TGpStructuredFileInfo }

  TGpStructuredFolderProxy = class;
  TGpStructuredFolderCache = class;

  {:A folder inside the structured storage. Actually a file with a known
    internal structure.
    @since   2003-11-10
  }
  TGpStructuredFolder = class(TGpStructuredFile)
  private
    sfAccessCount    : integer;
    sfEntries        : TObjectList {of TGpStructuredFolderEntry};
    sfFolderCache_ref: TGpStructuredFolderCache;
    sfNumOpenFiles   : integer;
    sfProxy          : TGpStructuredFolderProxy;
  protected
    function  AccessEntry(const entryName: string; mode: word;
      attributes: TGpStructuredFileAttributes; raiseException: boolean = true): integer;
    function  CountEntries: integer;
    function  CreateEntry(const entryName: string;
      attributes: TGpStructuredFileAttributes; length, firstFatEntry: cardinal): integer;
    procedure FileClosed(strFile: TGpStructuredFile);
    procedure FileSizeChanged(sender: TObject);
    procedure Flush;
    function  GetEntry(idxEntry: integer): TGpStructuredFolderEntry;
    function  LocateObject(const entryName: string): integer;
    function  LocateEntry(const entryName: string;
      attributes: TGpStructuredFileAttributes): integer;
    procedure ReadEntries;
    property Entry[idxEntry: integer]: TGpStructuredFolderEntry read GetEntry;
    property NumOpenFiles: integer read sfNumOpenFiles;
    property Proxy: TGpStructuredFolderProxy read sfProxy write sfProxy;
  public
    constructor Create(owner: TGpStructuredStorage; parentFolder: TGpStructuredFolder;
      folderCache: TGpStructuredFolderCache; const folderName: string; firstBlock,
      folderSize: cardinal);
    destructor  Destroy; override;
    procedure Access;
    procedure AttachEntry(entry: TGpStructuredFolderEntry);
    procedure DeleteAll;
    function  DeleteEntry(const entryName: string): boolean;
    function  DetachEntry(const entryName: string): TGpStructuredFolderEntry;
    function  FileExists(const fileName: string): boolean;
    procedure FileNames({out} files: TStrings);
    function  FolderExists(const folderName: string): boolean;
    procedure FolderNames({out} folders: TStrings);
    procedure Initialize(folderSize: cardinal);
    function  IsEmpty: boolean;
    procedure MoveFrom(srcFolder: TGpStructuredFolder; const sourceName, newName: string);
    function  ObjectExists(const objectName: string): boolean;
    function  OpenAttributeFile(const fileName: string; mode: word): TGpStructuredFile;
    function  OpenFile(const fileName: string; mode: word): TGpStructuredFile;
    function  OpenFolder(const folderName: string; mode: word): TGpStructuredFolder;
    function  Release: boolean;
  {$IFDEF DebugStructuredStorage}
    procedure Dump(var dumpFile: textfile; foldersSoFar: string);
  {$ENDIF DebugStructuredStorage}
    property FirstBlock: cardinal read sfFirstBlock;
  end; { TGpStructuredFolder }

  {:Proxy for the TGpStructuredFolder object which can be stored in the doubly-linked
    MRU folder list.
    @since   2006-11-23
  }
  TGpStructuredFolderProxy = class(TGpDoublyLinkedListObject)
  private
    sfpFolder: TGpStructuredFolder;
  public
    constructor Create(aFolder: TGpStructuredFolder);
    destructor  Destroy; override;
    property Folder: TGpStructuredFolder read sfpFolder;
  end; { TGpStructuredFolderProxy }

  {:One block in the File Allocation Table.
    @since   2003-11-24
  }
  TGpStructuredFATBlock = class
  private
    sfeEmpties: integer;
    sfeEntries: array [1..CFATEntriesPerBlock] of cardinal;
    sfeHeader : TGpStructuredHeader;
    sfeIsDirty: boolean;
    sfeStorage: TGpStructuredStream;
  protected
    function  GetEntries(idxEntry: integer): cardinal;
    procedure SetEntries(idxEntry: integer; const value: cardinal);
  public
    constructor Create(storage: TGpStructuredStream;
      header: TGpStructuredHeader);
    procedure Initialize(atBlock: cardinal);
    procedure Load(fromBlock: cardinal);
    procedure Save(toBlock: cardinal);
    property EmptyEntries: integer read sfeEmpties write sfeEmpties;
    property Entries[idxEntry: integer]: cardinal
      read GetEntries write SetEntries; default;
  end; { TSSFATEntry }

  {:File Allocation Table.
    @since   2003-11-24
  }
  TGpStructuredFAT = class
  private
    sfBlocks : TObjectList {of TGpStructuredFATBlock};
    sfHeader : TGpStructuredHeader;
    sfStorage: TGpStructuredStream;
  protected
    procedure BlockToFAT(blockNum: cardinal;
      var fatBlock: TGpStructuredFATBlock; var fatOffset: integer);
    procedure Flush;
    function  GetEntry(block: cardinal): cardinal;
    procedure SetEntry(block: cardinal; const value: cardinal);
    property Entry[block: cardinal]: cardinal read GetEntry write SetEntry;
  public
    constructor Create(storage: TGpStructuredStream;
      header : TGpStructuredHeader);
    destructor  Destroy; override;
    function  AllocateBlock: cardinal;
    function  AllocateFatBlock: TGpStructuredFATBlock;
    function  AppendBlockAfter(block: cardinal): cardinal;
    procedure Initialize;
    procedure Load;
    function  Next(block: cardinal): cardinal;
    procedure ReleaseBlocksAfter(block: cardinal);
    procedure ReleaseChain(block: cardinal);
    procedure Resolve(firstBlock: cardinal; offset: integer; var block,
      blockOffset: cardinal);
    procedure Truncate;
  {$IFDEF DebugStructuredStorage}
    procedure Dump(var dumpFile: textfile);
  {$ENDIF DebugStructuredStorage}
  end; { TGpStructuredFAT }

  {:Reference-counted folder cache.
    @since   2004-02-16
  }
  TGpStructuredFolderCache = class
  private
    sfcMRUFolders   : TGpDoublyLinkedList;
    sfcParentFolders: TGpObjectMap;
  protected
    procedure Flush;
    function  GetSubFolder(parentFolder: TGpStructuredFolder;
      subFolder: string): TGpStructuredFolder;
    function InternalRemove(markInactive, destroyFolder: boolean; parentFolder:
      TGpStructuredFolder; subFolder: string): boolean;
    procedure SetSubFolder(parentFolder: TGpStructuredFolder;
      subFolder: string; const value: TGpStructuredFolder);
    procedure TrimMRUList;
  public
    constructor Create;
    destructor  Destroy; override;
    function  MarkInactive(parentFolder: TGpStructuredFolder; subFolder: string): boolean;
    function Remove(parentFolder: TGpStructuredFolder; subFolder: string): boolean;
    procedure Rename(parentFolder: TGpStructuredFolder; const oldName, newName: string);
    procedure Reparent(parentFolder: TGpStructuredFolder; const folderName: string;
      newParentFolder: TGpStructuredFolder);
    property SubFolder[parentFolder: TGpStructuredFolder; subFolder: string]:
      TGpStructuredFolder read GetSubFolder write SetSubFolder; default;
  end; { TGpStructuredFolderCache }

  {:Structured storage implementation. File names are eight bit, case-preserving and ansi
    case-insensitive. Maximum file/folder name length is 65535 characters. Depth of the
    directory tree is unlimited. Maximum file size is 2 GB. Maximum storage data file
    size is 2 GB.
    @since   2003-11-10
  }
  TGpStructuredStorage = class(TInterfacedObject, IGpStructuredStorage, IGpDebugStructuredStorage)
  private
    gsmStorageMode : word;
    gssFAT         : TGpStructuredFAT;
    gssFileInfoList: TList;
    gssFileName    : string;
    gssFolderCache : TGpStructuredFolderCache;
    gssHeader      : TGpStructuredHeader;
    gssOwnsStream  : boolean;
    gssRootFolder  : TGpStructuredFolder;
    gssStorage     : TStream;
    gssStream      : TGpStructuredStream;
  protected
    procedure AccessFolder(folder: TGpStructuredFolder); overload;
    function  AccessFolder(parentFolder: TGpStructuredFolder; const subFolder: string;
      autoCreate: boolean = true): TGpStructuredFolder; overload;
    function  AddTrailingDelimiter(const folderName: string): string;
    procedure Close;
    procedure CreateEmptyStorage;
    function  CreateFileInfo(owner: TGpStructuredStorage;
      folder: TGpStructuredFolder; const fileName: string): IGpStructuredFileInfo;
    function  DescendTree(folderName: string; autoCreate: boolean = true):
      TGpStructuredFolder;
    function  GetDataFile: string;
    function  GetDataSize: integer;
    function  GetFileInfo(const fileName: string): IGpStructuredFileInfo;
    procedure InitializeStorage;
    procedure LoadStorageMetadata;
    function  NormalizeFileName(const fileName: string;
      isFolder: boolean = false): string;
    function  OpenAttributeFile(const fileName: string; mode: word): TStream;
    function  OpenStorageAttributeFile: TGpStructuredFile;
    procedure PrepareStructures;
    procedure ReleaseFolder(var folder: TGpStructuredFolder);
    procedure RenameFolder(owner: TGpStructuredFolder; const oldName, newName: string);
    procedure ReparentFolder(oldOwner: TGpStructuredFolder; const folderName: string;
      newOwner: TGpStructuredFolder);
    procedure RootFolderSizeChanged(sender: TObject);
    procedure SplitFileName(const fullName: string; var folderName, fileName: string);
    procedure StorageAttributeFileSizeChanged(sender: TObject);
    function  StripTrailingDelimiter(const fileName: string;
      leaveRootDelimited: boolean = false): string;
    procedure UnregisterAllFileInfo;
    procedure UnregisterFileInfo(fileInfo: TGpStructuredFileInfo);
    function  VerifyHeader: boolean;
    property FAT: TGpStructuredFAT read gssFAT;
    property Storage: TGpStructuredStream read gssStream;
  public
    destructor  Destroy; override;
    procedure Compact;
    procedure CreateFolder(const folderName: string);
    procedure Delete(const objectName: string);
    function  FileExists(const fileName: string): boolean;
    procedure FileNames(const folderName: string; {out} files: TStrings);
    function  FolderExists(const folderName: string): boolean;
    procedure FolderNames(const folderName: string; {out} folders: TStrings);
    procedure Initialize(const storageDataFile: string; mode: word); overload;
    procedure Initialize(storageDataStream: TStream); overload;
    function  IsFolderEmpty(const folderName: string): boolean;
    function  IsStructuredStorage(const storageDataFile: string): boolean; overload;
    function  IsStructuredStorage(storageDataStream: TStream): boolean; overload;
    procedure Move(const objectName, newName: string);
    function  OpenFile(const fileName: string; mode: word): TStream;
    procedure Dump(const fileName: string);
    property DataFile: string read GetDataFile;
    property DataSize: integer read GetDataSize;
    property FileInfo[const fileName: string]: IGpStructuredFileInfo read GetFileInfo;
  end; { TGpStructuredStorage }

function CreateStructuredStorage: IGpStructuredStorage;
begin
  Result := TGpStructuredStorage.Create;
end; { CreateStructuredStorage }

function GetLocaleString(locale, lcType: DWORD): string;
var
  p: array [0..255] of char;
begin
  if GetLocaleInfo(locale, lcType, p, High(p)) > 0 then
    Result := p
  else
    Result := '';
end; { GetLocaleString }

function StringToWideString(const s: AnsiString): TUnicodeString;
var
  codePage: DWORD;
  l       : integer;
begin
  if s = '' then
    Result := ''
  else begin
    codePage := StrToIntDef(GetLocaleString(GetUserDefaultLCID, LOCALE_IDEFAULTANSICODEPAGE), 0);
    if codePage = 0 then
      codePage := StrToIntDef(GetLocaleString(GetSystemDefaultLCID, LOCALE_IDEFAULTANSICODEPAGE), 1252);
    l := MultiByteToWideChar(codePage, MB_PRECOMPOSED, PAnsiChar(@s[1]), -1, nil, 0);
    SetLength(Result, l-1);
    if l > 1 then
      MultiByteToWideChar(CodePage, MB_PRECOMPOSED, PAnsiChar(@s[1]), -1, PWideChar(@Result[1]), l-1);
  end;
end; { StringToWideString }

function WideStringToString (const ws: TUnicodeString): AnsiString;
var
  codePage: DWORD;
  l       : integer;
begin
  if ws = '' then
    Result := ''
  else begin
    codePage := StrToIntDef(GetLocaleString(GetUserDefaultLCID, LOCALE_IDEFAULTANSICODEPAGE), 0);
    if codePage = 0 then
      codePage := StrToIntDef(GetLocaleString(GetSystemDefaultLCID, LOCALE_IDEFAULTANSICODEPAGE), 1252);
    l := WideCharToMultiByte(codePage,
           WC_COMPOSITECHECK or WC_DISCARDNS or WC_SEPCHARS or WC_DEFAULTCHAR,
           @ws[1], -1, nil, 0, nil, nil);
    SetLength(Result, l-1);
    if l > 1 then
      WideCharToMultiByte(codePage,
        WC_COMPOSITECHECK or WC_DISCARDNS or WC_SEPCHARS or WC_DEFAULTCHAR,
        @ws[1], -1, @Result[1], l-1, nil, nil);
  end;
end; { WideStringToString }

function ReadString(str: TStream): string;
var
  len       : integer;
  sAnsiValue: AnsiString;
  sWideValue: TUnicodeString;
begin
  Result := '';
  if (str.Read(len, SizeOf(cardinal)) <> SizeOf(cardinal)) or
     ((len AND $7FFFFFFF) = 0)
  then
    Exit;
  if (len AND $80000000) <> 0 then begin //v2 Unicode format
    len := len AND $7FFFFFFF;
    SetLength(sWideValue, len);
    str.Read(sWideValue[1], len * 2);
    {$IFDEF Unicode}
    Result := sWideValue;
    {$ELSE}
    Result := WideStringToString(sWideValue);
    {$ENDIF Unicode}
  end
  else begin //v1 Ansi format
    SetLength(sAnsiValue, len);
    str.Read(sAnsiValue[1], len);
    {$IFDEF Unicode}
    Result := StringToWideString(sAnsiValue);
    {$ELSE}
    Result := sAnsiValue;
    {$ENDIF Unicode}
  end;
end; { ReadString }

procedure WriteString(str: TStream; value: string);
var
  len       : cardinal;
  sWideValue: TUnicodeString;
begin
  {$IFDEF Unicode}
  sWideValue := value;
  {$ELSE}
  sWideValue := StringToWideString(value);
  {$ENDIF Unicode}
  len := cardinal(Length(sWideValue)) OR $80000000; //v2 Unicode format
  str.Write(len, SizeOf(cardinal));
  len := len AND $7FFFFFFF;
  if len > 0 then
    str.Write(sWideValue[1], len * 2);
end; { WriteString }

function GetTempPath: string;
var
  tempPath: PChar;
  bufSize: DWORD;
begin
  bufSize := Windows.GetTempPath(0, nil);
  GetMem(tempPath, bufSize*SizeOf(char));
  try
    Windows.GetTempPath(bufSize, tempPath);
    Result := StrPas(tempPath);
  finally FreeMem(tempPath); end;
end; { GetTempPath }

function GetTempFileName(const prefix: string): string;
var
  tempFileName: PChar;
begin
  Result := '';
  GetMem(tempFileName, MAX_PATH * SizeOf(char));
  try
    if Windows.GetTempFileName(PChar(GetTempPath), PChar(prefix), 0, tempFileName) <> 0 then
      Result := StrPas(tempFileName)
    else
      Result := '';
  finally FreeMem(tempFileName); end;
end; { GetTempFileName }

{ TGpStructuredStream }

constructor TGpStructuredStream.Create(storage: TStream);
begin
  inherited Create;
  ssStorage := storage;
end; { TGpStructuredStream.Create }

{:Returns offset inside the current block.
  @since   2004-01-08
}        
function TGpStructuredStream.GetOffset: integer;
begin
  Result := ssStorage.Position mod CBlockSize;
end; { TGpStructuredStream.GetOffset }

{:Returns position in blocks.
  @since   2004-01-08
}
function TGpStructuredStream.GetPosition: integer;
begin
  Result := ssStorage.Position div CBlockSize;
end; { TGpStructuredStream.GetPosition }

{:Returns storage size, in blocks.
  @since   2004-01-08
}
function TGpStructuredStream.GetSize: integer;
begin
  Result := ssStorage.Size div CBlockSize;  
end; { TGpStructuredStream.GetSize }

{:Copies 'numBytes' from the storage stream into the 'buffer' and returns number
  of bytes read.
  @since   2004-01-08
}        
function TGpStructuredStream.ReadBuffer(var buffer;
  numBytes: integer): integer;
begin
  Result := ssStorage.Read(buffer, numBytes);
end; { TGpStructuredStream.ReadBuffer }

{:Copies 'numBytes' from self to 'stream'. Always starts at current Position in
  the self and 'stream'.
  @since   2004-01-08
}
function TGpStructuredStream.ReadStream(stream: TStream;
  numBytes: integer): integer;
begin
  if numBytes <= 0 then
    Result := 0
  else
    Result := stream.CopyFrom(ssStorage, numBytes);
end; { TGpStructuredStream.ReadStream }

{:Sets position inside the current block.
  @since   2004-01-08
}        
procedure TGpStructuredStream.SetOffset(const value: integer);
begin
  ssStorage.Position := Position * CBlockSize + value;
end; { TGpStructuredStream.SetOffset }

{:Sets current block.
  @since   2004-01-08
}        
procedure TGpStructuredStream.SetPosition(const value : integer);
begin
  ssStorage.Position := value * CBlockSize;
end; { TGpStructuredStream.SetPosition }

{:Sets storage size, in blocks.
  @since   2004-01-08
}
procedure TGpStructuredStream.SetSize(const value: integer);
begin
  ssStorage.Size := value * CBlockSize;
end; { TGpStructuredStream.SetSize }

{:Truncates storage at specified block.
  @since   2004-01-08
}        
procedure TGpStructuredStream.Truncate(atBlock: integer);
begin
  Size := atBlock;
  Position := atBlock;
end; { TGpStructuredStream.Truncate }

{:Copies 'numBytes' from the 'buffer' into the storage stream.
  @since   2004-01-08
}        
procedure TGpStructuredStream.WriteBuffer(const buffer; numBytes: integer);
begin
  ssStorage.Write(buffer, numBytes);
end; { TGpStructuredStream.WriteBuffer }

{:Copies 'numBytes' from 'stream' to self. If 'numBytes' = 0, copies whole
  'stream'. Always starts at current Position in the 'stream'.
  @since   2004-01-08
}
procedure TGpStructuredStream.WriteStream(stream: TStream; numBytes: integer);
begin
  if numBytes = 0 then
    numBytes := stream.Size - stream.Position;
  if numBytes > 0 then
    ssStorage.CopyFrom(stream, numBytes);
end; { TGpStructuredStream.WriteStream }

{ TGpStructuredHeader }

constructor TGpStructuredHeader.Create(storage: TGpStructuredStream);
begin
  inherited Create;
  shStorage := storage;
end; { TGpStructuredHeader.Create }

{:Create the header in the (empty) storage stream.
  @since   2003-11-10
}
function TGpStructuredHeader.CreateHeader: boolean;
var
  header  : TStringStream;
  iPointer: integer;
begin
  header := TStringStream.Create(CSignature +
    StringOfChar(AnsiChar(' '), CBlockSize - Length(CSignature) - Length(shPointers)*4));
  try
    header.Position := header.Size;
    for iPointer := Low(shPointers) to High(shPointers) do begin
      shPointers[iPointer] := 0;
      header.Write(shPointers[iPointer], 4);
    end; //for
    header.Position := 0;
    shStorage.Truncate(0);
    shStorage.WriteStream(header);
  finally FreeAndNil(header); end;
  Result := (shStorage.Size = 1);
end; { TGpStructuredHeader.CreateSignature }

function TGpStructuredHeader.GetCardinal(index: integer): cardinal;
begin
  Result := shPointers[index];
end; { TGpStructuredHeader.GetCardinal }

function TGpStructuredHeader.LoadHeader: boolean;
var
  header  : TStringStream;
  iPointer: integer;
begin
  Result := false;
  if shStorage.Size < 1 then
    Exit;
  header := TStringStream.Create('');
  try
    shStorage.Position := 0;
    if (shStorage.ReadStream(header, Length(CSignature)) <> Length(CSignature)) or
       (AnsiString(header.DataString) <> CSignature)
    then
      Exit;
  finally FreeAndNil(header); end;
  shStorage.Offset := CBlockSize - Length(shPointers)*4;
  for iPointer := Low(shPointers) to High(shPointers) do
    if shStorage.ReadBuffer(shPointers[iPointer], 4) <> 4 then
      Exit;
  Result := true;
end; { TGpStructuredHeader.LoadHeader }

procedure TGpStructuredHeader.SetCardinal(index: integer;
  const value: cardinal);
begin
  shStorage.Position := 0;
  shStorage.Offset := CBlockSize - 4 + (index * 4);
  shStorage.WriteBuffer(value, 4);
  shPointers[index] := value;
end; { TGpStructuredHeader.SetCardinal }

{ TGpStructuredFile }

constructor TGpStructuredFile.Create(owner: TGpStructuredStorage;
  folder: TGpStructuredFolder; fileName: string; firstBlock, fileSize: cardinal;
  attributes: TGpStructuredFileAttributes);
begin
  inherited Create;
  sfOwner := owner;
  sfFolder := folder;
  sfName := fileName;
  sfFirstBlock := firstBlock;
  sfFileSize := fileSize;
  sfAttributes := attributes;
  sfCurrentPos := 0;
  ResolvePosition;
  sfOwner.AccessFolder(sfFolder);
//GpLog.Log('Create : %s', [FullPath]);
end; { TGpStructuredFile.Create }

destructor TGpStructuredFile.Destroy;
begin
//GpLog.Log('Destroy: %s', [FullPath]);
  if assigned(sfOwner) and assigned(sfFolder) then begin
    sfFolder.FileClosed(Self);
    sfOwner.ReleaseFolder(sfFolder);
  end;
  inherited;
end; { TGpStructuredFile.Destroy }

function TGpStructuredFile.FAT: TGpStructuredFAT;
begin
  Result := sfOwner.FAT;
end; { TGpStructuredFile.FAT }

function TGpStructuredFile.FullPath: string;
begin
  if not assigned(sfFolder) then
    Result := FileName
  else
    Result := sfFolder.FullPath + '/' + FileName;
end; { TGpStructuredFile.FullPath }

procedure TGpStructuredFile.NotifySizeChange;
begin
  if assigned(sfOnSizeChanged) then
    sfOnSizeChanged(self);
end; { TGpStructuredFile.NotifySizeChange }

{:Reads up to 'count' bytes into the 'buffer'. Follows FAT chain.
  @since   2004-02-14
}        
function TGpStructuredFile.Read(var buffer; count: longint): longint;
var
  bytesToRead: integer;
  writer     : TGpFixedMemoryStream;
begin
  // could read more than CBlockSize at once if blocks are sequential
  Result := 0;
  Storage.Position := sfCurrentBlock;
  Storage.Offset := sfCurrentBlockOffset;
  writer := TGpFixedMemoryStream.Create(buffer, count);
  try
    while (count > 0) and (sfCurrentPos < sfFileSize) do begin
      bytesToRead := Min(Min(CBlockSize - sfCurrentBlockOffset, count), sfFileSize - sfCurrentPos);
      if bytesToRead > 0 then // sfCurrentBlockOffset can be equal to CBlockSize
        Result := Result + Storage.ReadStream(writer, bytesToRead);
      Dec(count, bytesToRead);
      Inc(sfCurrentPos, bytesToRead);
      Inc(sfCurrentBlockOffset, bytesToRead);
      if (sfCurrentBlockOffset = CBlockSize) and (count > 0) then begin
        sfCurrentBlock := FAT.Next(sfCurrentBlock);
        sfCurrentBlockOffset := 0;
        Storage.Position := sfCurrentBlock;
      end;
    end; //while
  finally FreeAndNil(writer); end;
end; { TGpStructuredFile.Read }

procedure TGpStructuredFile.ResolvePosition;
begin
  FAT.Resolve(sfFirstBlock, sfCurrentPos, sfCurrentBlock, sfCurrentBlockOffset);
end; { TGpStructuredFile.ResolvePosition }

function TGpStructuredFile.Seek(offset: longint; origin: word): longint;
begin
  Result := 0; // to keep the Delphi happy
  case origin of
    soFromBeginning: Result := offset;
    soFromCurrent:   Result := sfCurrentPos + offset;
    soFromEnd:       Result := sfFileSize + offset;
  end; //case
  if Result < 0 then
    raise Exception.CreateFmt(
      'TGpStructuredStorage: Trying to seek before the first byte (%d) in file %s.',
      [Result, sfName]);
  if Result > sfFileSize then
    raise Exception.CreateFmt(
      'TGpStructuredStorage: Trying to seek past the end of file (%d; %d) in file %s.',
      [Result, sfFileSize, sfName]);
  sfCurrentPos := Result;
  ResolvePosition;
end; { TGpStructuredFile.Seek }

{:Sets new file size and truncates/extends FAT chain when required.
  @since   2004-02-14
}        
procedure TGpStructuredFile.SetParent(newParentFolder: TGpStructuredFolder);
begin
  sfFolder := newParentFolder;
  TMethod(sfOnSizeChanged).Data := pointer(sfFolder);
end; { TGpStructuredFile.SetParent }

procedure TGpStructuredFile.SetSize(newSize: integer);
var
  currBlocks     : cardinal;
  iBlock         : integer;
  lastBlock      : cardinal;      
  lastBlockOffset: cardinal;
  newBlocks      : cardinal;
begin
  if sfFileSize = newSize then
    Exit;
  currBlocks := (sfFileSize - 1) div CBlockSize  + 1;
  newBlocks := (newSize - 1) div CBlockSize  + 1;
  if newBlocks < currBlocks then begin
    FAT.Resolve(sfFirstBlock, newSize, lastBlock, lastBlockOffset);
    FAT.ReleaseBlocksAfter(lastBlock);
  end
  else if newBlocks > currBlocks then begin
    FAT.Resolve(sfFirstBlock, sfFileSize, lastBlock, lastBlockOffset);
    for iBlock := currBlocks+1 to newBlocks do
      lastBlock := FAT.AppendBlockAfter(lastBlock);
  end;
  sfFileSize := newSize;
  if sfCurrentPos > sfFileSize then begin
    sfCurrentPos := sfFileSize;
    ResolvePosition;
  end;
  NotifySizeChange;
end; { TGpStructuredFile.SetSize }

function TGpStructuredFile.Storage: TGpStructuredStream;
begin
  Result := sfOwner.Storage;
end; { TGpStructuredFile.Storage }

{:Writes 'count' bytes from the 'buffer'. Follows FAT chain and appends new blocks if
  necessary.
  @since   2004-02-14
}
function TGpStructuredFile.Write(const buffer; count: longint): longint;
var
  bytesToWrite: integer;
  reader      : TGpFixedMemoryStream;
begin
  // could write more than CBlockSize at once if blocks are sequential
  if sfFileSize < (sfCurrentPos + count) then
    Size := sfCurrentPos + count;
  Result := 0;
  Storage.Position := sfCurrentBlock;
  Storage.Offset := sfCurrentBlockOffset;
  reader := TGpFixedMemoryStream.Create(buffer, count);
  try
    while count > 0 do begin
      bytesToWrite := Min(CBlockSize - sfCurrentBlockOffset, count);
      if bytesToWrite > 0 then // sfCurrentBlockOffset can be equal to CBlockSize
        Storage.WriteStream(reader, bytesToWrite);
      Inc(Result, bytesToWrite);
      Dec(count, bytesToWrite);
      Inc(sfCurrentPos, bytesToWrite);
      Inc(sfCurrentBlockOffset, bytesToWrite);
      if (sfCurrentBlockOffset = CBlockSize) and (count > 0) then begin
        sfCurrentBlock := FAT.Next(sfCurrentBlock);
        sfCurrentBlockOffset := 0;
        Storage.Position := sfCurrentBlock;
      end;
    end; //while
  finally FreeAndNil(reader); end;
end; { TGpStructuredFile.Write }

{ TGpStructuredFolderEntry }

class function TGpStructuredFolderEntry.AttributesToNum(
  attr: TGpStructuredFileAttributes): cardinal;
begin
  Result := 0;
  if sfAttrIsFolder in attr then
    Result := Result OR CAttrIsFolder;
  if sfAttrIsAttributeFile in attr then
    Result := Result OR CAttrIsAttributeFile;
end; { TGpStructuredFolderEntry.AttributesToNum }

constructor TGpStructuredFolderEntry.Create(const entryName: string;
  attributes: TGpStructuredFileAttributes; length, firstFatEntry: cardinal);
begin
  inherited Create;
  sfeFileName := entryName;
  sfeAttributes := attributes;
  sfeLength := length;
  sfeFirstFatEntry := firstFatEntry;
end; { TGpStructuredFolderEntry.Create }

function TGpStructuredFolderEntry.LoadFrom(stream: TStream): boolean;
var
  nameLen  : word;
  numAttr  : cardinal;
  sAnsiName: AnsiString;
  sWideName: TUnicodeString;
begin
  Result := false;
  stream.Read(nameLen, 2);
  if nameLen = 0 then
    Exit;
  if (nameLen AND $8000) <> 0 then begin //v2 Unicode format
    nameLen := nameLen AND $7FFF;
    SetLength(sWideName, nameLen);
    stream.Read(sWideName[1], nameLen * 2);
    {$IFDEF Unicode}
    sfeFileName := sWideName;
    {$ELSE}
    sfeFileName := WideStringToString(sWideName);
    {$ENDIF Unicode}
  end
  else begin //v1 Ansi format
    SetLength(sAnsiName, nameLen);
    stream.Read(sAnsiName[1], nameLen);
    {$IFDEF Unicode}
    sfeFileName := StringToWideString(sAnsiName);
    {$ELSE}
    sfeFileName := sAnsiName;
    {$ENDIF Unicode}
  end;
  stream.Read(numAttr, 4);
  stream.Read(sfeFirstFatEntry, 4);
  stream.Read(sfeLength, 4);
  sfeAttributes := NumToAttributes(numAttr);
  Result := true;
end; { TGpStructuredFolderEntry.LoadFrom }

class function TGpStructuredFolderEntry.NumToAttributes(
  attr: cardinal): TGpStructuredFileAttributes;
begin
  Result := [];
  if (CAttrIsFolder AND attr) <> 0 then
    Include(Result, sfAttrIsFolder);
  if (CAttrIsAttributeFile AND attr) <> 0then
    Include(Result, sfAttrIsAttributeFile);
end; { TGpStructuredFolderEntry.NumToAttributes }

procedure TGpStructuredFolderEntry.SaveTo(stream: TStream);
var
  nameLen  : word;
  numAttr  : cardinal;
  sWideName: TUnicodeString;
begin
  numAttr := AttributesToNum(sfeAttributes);
  {$IFDEF Unicode}
  sWideName := sfeFileName;
  {$ELSE}
  sWideName := StringToWideString(sfeFileName);
  {$ENDIF Unicode}
  nameLen := Length(sWideName) OR $8000; //v2 Unicode format
  stream.Write(nameLen, 2);
  nameLen := nameLen AND $7FFF;
  stream.Write(sWideName[1], nameLen * 2);
  stream.Write(numAttr, 4);
  stream.Write(sfeFirstFatEntry, 4);
  stream.Write(sfeLength, 4);
end; { TGpStructuredFolderEntry.SaveTo }

{ TGpStructuredFileInfo }

procedure TGpStructuredFileInfo.AccessFile(var strFile: TGpStructuredFile);
begin
  if not sfiFolder.FileExists(sfiFileName) then
    strFile := nil
  else
    strFile := sfiFolder.OpenFile(sfiFileName, fmOpenRead);
  if not assigned(strFile) then
    raise EGpStructuredStorage.CreateFmt('File ''%s'' does not exist.', [sfiFileName]);
end; { TGpStructuredFileInfo.AccessFile }

procedure TGpStructuredFileInfo.AttributeNames(attributes: TStrings);
var
  strAttr: TGpStructuredFile;
begin
  if not assigned(sfiOwner) then
    raise EGpStructuredStorage.Create('Structured storage is already destroyed');
  attributes.Clear;
  strAttr := sfiFolder.OpenAttributeFile(sfiFileName, fmOpenRead);
  if assigned(strAttr) then try
    ListAttributes(strAttr, attributes);
  finally FreeAndNil(strAttr); end;
end; { TGpStructuredFileInfo.AttributeNames }

procedure TGpStructuredFileInfo.ClearOwner;
begin
  if assigned(sfiFolder) then
    sfiOwner.ReleaseFolder(sfiFolder);  
  sfiOwner := nil;
end; { TGpStructuredFileInfo.ClearOwner }
              
constructor TGpStructuredFileInfo.Create(owner: TGpStructuredStorage;
  folder: TGpStructuredFolder; const fileName: string);
begin
  inherited Create;
  sfiOwner := owner;
  sfiFolder := folder;
  sfiFileName := fileName;
  sfiOwner.AccessFolder(sfiFolder); // keep folder cached
end; { TGpStructuredFileInfo.Create }

destructor TGpStructuredFileInfo.Destroy;
begin
  if assigned(sfiOwner) and assigned(sfiFolder) then
    sfiOwner.ReleaseFolder(sfiFolder);
  if assigned(sfiOwner) then
    sfiOwner.UnregisterFileInfo(self);
  inherited Destroy;
end; { TGpStructuredFileInfo.Destroy }

{:Retrieves attribute from the attribute file.
  @since   2004-02-18
}        
function TGpStructuredFileInfo.GetAttribute(const attributeName: string): string;
var
  strAttr: TGpStructuredFile;
begin
  if not assigned(sfiOwner) then
    raise EGpStructuredStorage.Create('Structured storage is already destroyed');
  Result := '';
  strAttr := sfiFolder.OpenAttributeFile(sfiFileName, fmOpenRead);
  if assigned(strAttr) then try
    Result := RetrieveAttribute(strAttr, attributeName);
  finally FreeAndNil(strAttr); end;
end; { TGpStructuredFileInfo.GetAttribute }

function TGpStructuredFileInfo.GetSize: cardinal;
var
  strFile: TGpStructuredFile;
begin
  if not assigned(sfiOwner) then
    raise EGpStructuredStorage.Create('Structured storage is already destroyed');
  Result := 0; // to keep Delphi happy
  AccessFile(strFile);
  if assigned(strFile) then try
    Result := strFile.Size;
  finally FreeAndNil(strFile); end;
end; { TGpStructuredFileInfo.GetSize }

{:Lists all attributes in the stream.
  @since   2004-02-22
}        
procedure TGpStructuredFileInfo.ListAttributes(attrStream: TStream; attributes: TStrings);
var
  attrName: string;
begin
  attributes.Clear;
  attrStream.Position := 0;
  repeat
    attrName := ReadString(attrStream);
    if attrName = '' then
      break; //repeat
    attributes.Add(attrName);
    ReadString(attrStream);
  until false;
end; { TGpStructuredFileInfo.ListAttributes }

{:Retrieves attribute from the stream.
  @since   2004-02-18
}
function TGpStructuredFileInfo.RetrieveAttribute(attrStream: TStream;
  const attributeName: string): string;
var
  attrName: string;
begin
  attrStream.Position := 0;
  repeat
    attrName := ReadString(attrStream);
    if attrName = '' then
      break; //repeat
    Result := ReadString(attrStream);
    if attrName = attributeName then
      Exit;
  until false;
  Result := '';
end; { TGpStructuredFileInfo.RetrieveAttribute }

{:Updates attribute in the attribute file.
  @since   2004-02-18
}        
procedure TGpStructuredFileInfo.SetAttribute(const attributeName: string; const value:
  string);
var
  strAttr: TGpStructuredFile;
begin
  if not assigned(sfiOwner) then
    raise EGpStructuredStorage.Create('Structured storage is already destroyed');
  strAttr := sfiFolder.OpenAttributeFile(sfiFileName, fmCreate);
  if not assigned(strAttr) then
    raise Exception.CreateFmt(
      'TGpStructuredStorage(%s): Failed to create attribute file %s.',
      [sfiOwner.DataFile, sfiFileName]);
  try
    UpdateAttribute(strAttr, attributeName, value);
  finally FreeAndNil(strAttr); end;
end; { TGpStructuredFileInfo.SetAttribute }

procedure TGpStructuredFileInfo.SetSize(value: cardinal);
var
  strFile: TGpStructuredFile;
begin
  if not assigned(sfiOwner) then
    raise EGpStructuredStorage.Create('Structured storage is already destroyed');
  AccessFile(strFile);
  if assigned(strFile) then try
    strFile.Size := value;
  finally FreeAndNil(strFile); end;
end; { TGpStructuredFileInfo.SetSize }

{:Updates attribute value in a stream.
  @since   2004-02-18
}
procedure TGpStructuredFileInfo.UpdateAttribute(attrStream: TStream;
  const attributeName, attributeValue: string);
var
  attrName : string;
  attrValue: string;
  found    : boolean;
  tmpStream: TMemoryStream;
begin
  attrStream.Position := 0;
  tmpStream := TMemoryStream.Create;
  try
    found := false;
    repeat
      attrName := ReadString(attrStream);
      if attrName = '' then begin
        if (not found) and (attributeValue <> '') then begin
          WriteString(tmpStream, attributeName);
          WriteString(tmpStream, attributeValue);
        end;
        WriteString(tmpStream, '');
        break; //repeat
      end;
      attrValue := ReadString(attrStream);
      if attrName = attributeName then begin
        if attributeValue <> '' then begin
          WriteString(tmpStream, attrName);
          WriteString(tmpStream, attributeValue);
        end;
        found := true;
      end
      else begin
        WriteString(tmpStream, attrName);
        WriteString(tmpStream, attrValue);
      end;
    until false;
    tmpStream.Position := 0;
    attrStream.Position := 0;
    attrStream.CopyFrom(tmpStream, 0);
    attrStream.Size := attrStream.Position;
  finally FreeAndNil(tmpStream); end;
end; { TGpStructuredFileInfo.UpdateAttribute }

{ TGpStructuredFolder }

procedure TGpStructuredFolder.Access;
begin
  Inc(sfAccessCount);
end; { TGpStructuredFolder.Access }

function TGpStructuredFolder.AccessEntry(const entryName: string;
  mode: word; attributes: TGpStructuredFileAttributes; raiseException: boolean): integer;
begin
  Assert(entryName <> '', 'Trying to access entry with empty name');
  Result := LocateEntry(entryName, attributes);
  if Result < 0 then begin
    if (mode and fmCreate) <> fmCreate then
      Exit
    else begin
      Result := CreateEntry(entryName, attributes, 0, FAT.AllocateBlock);
      Flush;
    end;
  end
  else if (sfAttrIsFolder in Entry[Result].Attributes) xor (sfAttrIsFolder in attributes) then begin
    if raiseException then
      raise EGpStructuredStorage.CreateFmt(
        'Entry %s already exists with different attributes.', [entryName])
    else
      Result := -1;
  end;
end; { TGpStructuredFolder.AccessEntry }

procedure TGpStructuredFolder.AttachEntry(entry: TGpStructuredFolderEntry);
begin
  sfEntries.Add(entry);
  Flush;
end; { TGpStructuredFolder.AttachEntry }

function TGpStructuredFolder.CountEntries: integer;
begin
  Result := sfEntries.Count;
end; { TGpStructuredFolder.CountEntries }

constructor TGpStructuredFolder.Create(owner: TGpStructuredStorage; parentFolder:
  TGpStructuredFolder; folderCache: TGpStructuredFolderCache; const folderName: string;
  firstBlock, folderSize: cardinal);
begin
  inherited Create(owner, parentFolder, folderName, firstBlock, folderSize,
    [sfAttrIsFolder]);
  sfEntries := TObjectList.Create;
  sfAccessCount := 1;
  sfFolderCache_ref := folderCache;
end; { TGpStructuredFolder.Create }

function TGpStructuredFolder.CreateEntry(const entryName: string;
  attributes: TGpStructuredFileAttributes; length, firstFatEntry: cardinal): integer;
begin
  Result := sfEntries.Add(TGpStructuredFolderEntry.Create(entryName, attributes, length,
    firstFatEntry));
end; { TGpStructuredFolder.CreateEntry }

{:Removes all files and folders, recursively.
  @since   2004-02-16
}
procedure TGpStructuredFolder.DeleteAll;
begin
  while CountEntries > 0 do
    if not DeleteEntry(Entry[0].FileName) then
      raise EGpStructuredStorage.CreateFmt(
        'TGpStructuredFolder.DeleteAll: Failed to delete %s', [Entry[0].FileName]);
end; { TGpStructuredFolder.DeleteAll }

{:Removes specified entry from the folder. Deletes subfolders and subfiles too if the
  entry is a folder. If 'name' is empty, deletes everything.
  @returns False if such entry doesn't exist.
  @since   2004-02-16
}
function TGpStructuredFolder.DeleteEntry(const entryName: string): boolean;
var
  idxAttrEntry: integer;
  idxEntry    : integer;
  isFolder    : boolean;
  subFolder   : TGpStructuredFolder;
begin
  if entryName = '' then begin
    DeleteAll;
    Result := true;
  end
  else begin
    idxEntry := LocateEntry(entryName, []);
    if idxEntry < 0 then
      Result := false
    else begin
      isFolder := (sfAttrIsFolder in Entry[idxEntry].Attributes);
      if isFolder then begin
        subFolder := Owner.AccessFolder(self, Entry[idxEntry].FileName);
        try
          if subFolder.NumOpenFiles > 0 then
            raise EGpStructuredStorage.CreateFmt('Cannot delete folder %s/%s because ' +
              'it contains open files.',
              [FileName, Entry[idxEntry].FileName]);
          subFolder.DeleteAll;
        finally Owner.ReleaseFolder(subFolder); end;
      end;
      // delete attribute file
      idxAttrEntry := LocateEntry(entryName, [sfAttrIsAttributeFile]);
      if idxAttrEntry >= 0 then begin
        FAT.ReleaseChain(Entry[idxAttrEntry].FirstFatEntry);
        sfEntries.Delete(idxAttrEntry);
      end;
      FAT.ReleaseChain(Entry[idxEntry].FirstFatEntry);
      sfEntries.Delete(idxEntry);
      Flush;
      if isFolder then
        sfFolderCache_ref.Remove(Self, entryName);
      Result := true;
    end;
  end;
end; { TGpStructuredFolder.DeleteEntry }

{:Opens/creates a file inside the folder.
  @since   2003-11-10
}
destructor TGpStructuredFolder.Destroy;
begin
  FreeAndNil(sfEntries);
  if assigned(Owner) and (sfAccessCount > 0) then
    sfOwner.ReleaseFolder(self);
  inherited;
end; { TGpStructuredFolder.Destroy }

function TGpStructuredFolder.DetachEntry(const entryName: string):
  TGpStructuredFolderEntry;
var
  idxEntry: integer;
begin
  idxEntry := LocateObject(entryName);
  if idxEntry < 0 then
    raise EGpStructuredStorage.CreateFmt('Failed to detach entry %s', [entryName]);
  Result := Entry[idxEntry];
  sfEntries.Extract(Result);
  Flush;
end; { TGpStructuredFolder.DetachEntry }

{$IFDEF DebugStructuredStorage}
procedure TGpStructuredFolder.Dump(var dumpFile: textfile; foldersSoFar: string);
var
  iEntry   : integer;
  subFolder: TGpStructuredFolder;
begin
  System.Writeln(dumpFile, foldersSoFar, FileName);
  for iEntry := 0 to CountEntries-1 do begin
    if sfAttrIsFolder in Entry[iEntry].Attributes  then
      System.Write(dumpFile, 'D ')
    else if sfAttrIsAttributeFile in Entry[iEntry].Attributes then
      System.Write(dumpFile, 'A ')
    else
      System.Write(dumpFile, 'F ');
    System.Writeln(dumpFile, Entry[iEntry].FirstFatEntry, ' ', Entry[iEntry].FileName, ' ', Entry[iEntry].FileLength);
  end; //for
  foldersSoFar := foldersSoFar + FileName + CFolderDelim;
  for iEntry := 0 to CountEntries-1 do
    if sfAttrIsFolder in Entry[iEntry].Attributes then begin
      subFolder := Owner.AccessFolder(self, Entry[iEntry].FileName);
      try
        System.Writeln(dumpFile);
        subFolder.Dump(dumpFile, foldersSoFar);
      finally Owner.ReleaseFolder(subFolder); end;
    end;
end; { TGpStructuredFolder.Dump }
{$ENDIF DebugStructuredStorage}

procedure TGpStructuredFolder.FileClosed(strFile: TGpStructuredFile);
begin
  Dec(sfNumOpenFiles);
end; { TGpStructuredFolder.FileClosed }

function TGpStructuredFolder.FileExists(const fileName: string): boolean;
begin
  Result :=
    (fileName <> '') and
    (AccessEntry(fileName, fmOpenRead, [], false) >= 0);
end; { TGpStructuredFolder.FileExists }

procedure TGpStructuredFolder.FileNames({out} files: TStrings);
var
  iEntry: integer;
begin
  files.Clear;
  for iEntry := 0 to CountEntries-1 do
    if ([sfAttrIsFolder, sfAttrIsAttributeFile] * Entry[iEntry].Attributes) = [] then
      files.Add(Entry[iEntry].FileName);
end; { TGpStructuredFolder.FileSizeChanged }

procedure TGpStructuredFolder.FileSizeChanged(sender: TObject);
var
  idxFile: integer;
  strFile: TGpStructuredFile;
begin
  strFile := TGpStructuredFile(sender);
  idxFile := LocateEntry(strFile.FileName, strFile.Attributes);
  if idxFile < 0 then
    raise Exception.CreateFmt(
      'TGpStructuredStorage: Trying to update size for unexistent file %s',
      [strFile.FileName]);
  Entry[idxFile].FileLength := strFile.Size;
  Flush;
end; { TGpStructuredFolder.FileSizeChanged }

{:Flushes folder to the disk.
  @since   2004-01-08
}
procedure TGpStructuredFolder.Flush;
var
  iEntry    : integer;
  memFolder : TMemoryStream;
  terminator: word;
begin
  memFolder := TMemoryStream.Create;
  try
    for iEntry := 0 to CountEntries-1 do
      Entry[iEntry].SaveTo(memFolder);
    terminator := 0;
    memFolder.Write(terminator, 2);
    Position := 0;
    memFolder.Position := 0;
    CopyFrom(memFolder, 0);
    if Size <> Position then
      Size := Position;
  finally FreeAndNil(memFolder); end;
end; { TGpStructuredFolder.Flush }

function TGpStructuredFolder.FolderExists(const folderName: string): boolean;
begin
  Result :=
    (folderName <> '') and
    (AccessEntry(folderName, fmOpenRead, [sfAttrIsFolder], false) >= 0);
end; { TGpStructuredFolder.FolderExists }

procedure TGpStructuredFolder.FolderNames({out} folders: TStrings);
var
  iEntry: integer;
begin
  folders.Clear;
  for iEntry := 0 to CountEntries-1 do
    if ([sfAttrIsFolder, sfAttrIsAttributeFile] * Entry[iEntry].Attributes) = [sfAttrIsFolder] then
      folders.Add(Entry[iEntry].FileName);
end; { TGpStructuredFolder.FolderNames }

function TGpStructuredFolder.GetEntry(idxEntry: integer): TGpStructuredFolderEntry;
begin
  Result := TGpStructuredFolderEntry(sfEntries[idxEntry]);
end; { TGpStructuredFolder.GetEntry }

procedure TGpStructuredFolder.Initialize(folderSize: cardinal);
begin
  if folderSize = 0 then
    Flush
  else
    ReadEntries;
end; { TGpStructuredFolder.Initialize }

function TGpStructuredFolder.IsEmpty: boolean;
begin
  Result := (CountEntries = 0);
end; { TGpStructuredFolder.IsEmpty }

function TGpStructuredFolder.LocateEntry(const entryName: string;
  attributes: TGpStructuredFileAttributes): integer;
var
  attrIsAttr: TGpStructuredFileAttributes;
begin
  attrIsAttr := attributes * [sfAttrIsAttributeFile];
  for Result := 0 to CountEntries-1 do
    if AnsiSameText(Entry[Result].FileName, entryName) and
       (Entry[Result].Attributes * [sfAttrIsAttributeFile] = attrIsAttr)
    then
      Exit;
  Result := -1;
end; { TGpStructuredFolder.LocateEntry }

function TGpStructuredFolder.LocateObject(const entryName: string): integer;
begin
  for Result := 0 to CountEntries-1 do
    if AnsiSameText(Entry[Result].FileName, entryName) then
      Exit;
  Result := -1;
end; { TGpStructuredFolder.LocateObject }

{:Moves entry from another folder to self.
  @since   2004-03-02
}        
procedure TGpStructuredFolder.MoveFrom(srcFolder: TGpStructuredFolder; const sourceName,
  newName: string);
var
  idxEntry: integer;
  numMoved: integer;
  srcEntry: TGpStructuredFolderEntry;
begin
  if srcFolder = self then begin
    numMoved := 0;
    repeat
      idxEntry := LocateObject(sourceName);
      if idxEntry < 0 then
        break; //repeat
      Entry[idxEntry].FileName := newName;
      Inc(numMoved);
    until false;
    if numMoved = 0 then
      raise EGpStructuredStorage.CreateFmt('Failed to rename entry %s', [sourceName]);
    Owner.RenameFolder(self, sourceName, newName); // update cache
    Flush;
  end
  else begin
    numMoved := 0;
    while srcFolder.ObjectExists(sourceName) do begin
      srcEntry := srcFolder.DetachEntry(sourceName);
      srcEntry.FileName := newName;
      AttachEntry(srcEntry);
      Inc(numMoved);
    end; //while
    if numMoved = 0 then
      raise EGpStructuredStorage.CreateFmt('Failed to rename entry %s', [sourceName]);
    Owner.ReparentFolder(srcFolder, sourceName, self);
    Owner.RenameFolder(self, sourceName, newName);
  end;
end; { TGpStructuredFolder.MoveFrom }

function TGpStructuredFolder.ObjectExists(const objectName: string): boolean;
begin
  Result := (LocateObject(objectName) >= 0);
end; { TGpStructuredFolder.ObjectExists }

{:Opens/creates an internal attribute file.
  @since   2004-02-18
}
function TGpStructuredFolder.OpenAttributeFile(const fileName: string;
  mode: word): TGpStructuredFile;
var
  idxEntry: integer;
begin
  if (fileName = '') and (Folder = nil) then
    Result := Owner.OpenStorageAttributeFile
  else begin
    idxEntry := AccessEntry(fileName, mode, [sfAttrIsAttributeFile]);
    if idxEntry < 0 then
      Result := nil
    else begin
      Result := TGpStructuredFile.Create(Owner, self, fileName,
        Entry[idxEntry].FirstFatEntry, Entry[idxEntry].FileLength, [sfAttrIsAttributeFile]);
      Result.OnSizeChanged := FileSizeChanged;
    end;
  end;
end; { TGpStructuredFolder.OpenAttributeFile }

{:Opens/creates a file information entry.
  @since   2004-02-15
}
function TGpStructuredFolder.OpenFile(const fileName: string; mode: word):
  TGpStructuredFile;
var
  idxEntry: integer;
begin
  if fileName = '' then
    raise EGpStructuredStorage.Create('Trying to open file with empty name');
  idxEntry := AccessEntry(fileName, mode, []);
  if idxEntry < 0 then
    Result := nil
  else begin
    Result := TGpStructuredFile.Create(Owner, self, fileName,
      Entry[idxEntry].FirstFatEntry, Entry[idxEntry].FileLength, []);
    Result.OnSizeChanged := FileSizeChanged;
    Inc(sfNumOpenFiles);
  end;
end; { TGpStructuredFolder.OpenFile }

{:Opens/creates a folder information entry.
  @since   2004-02-16
}
function TGpStructuredFolder.OpenFolder(const folderName: string; mode: word):
  TGpStructuredFolder;
var
  idxEntry: integer;
begin
  idxEntry := AccessEntry(folderName, mode, [sfAttrIsFolder]);
  if idxEntry < 0 then
    Result := nil
  else begin
    Result := TGpStructuredFolder.Create(Owner, self, sfFolderCache_ref, folderName,
      Entry[idxEntry].FirstFatEntry, Entry[idxEntry].FileLength);
    Result.OnSizeChanged := FileSizeChanged;
    Result.Initialize(Entry[idxEntry].FileLength);
  end;
end; { TGpStructuredFolder.OpenFolder }

{:Read folder from the disk.
  @since   2004-02-14
}        
procedure TGpStructuredFolder.ReadEntries;
var
  entry    : TGpStructuredFolderEntry;
  memFolder: TMemoryStream;
begin
  Position := 0;
  memFolder := TMemoryStream.Create;
  try
    memFolder.CopyFrom(Self, 0);
    memFolder.Position := 0;
    repeat
      entry := TGpStructuredFolderEntry.Create;
      if entry.LoadFrom(memFolder) then
        sfEntries.Add(entry)
      else
        FreeAndNil(entry);
    until not assigned(entry);
  finally FreeAndNil(memFolder); end;
end; { TGpStructuredFolder.ReadEntries }

function TGpStructuredFolder.Release: boolean;
begin
  if sfAccessCount > 0 then
    Dec(sfAccessCount);
  Result := (sfAccessCount = 0);
end; { TGpStructuredFolder.Release }

constructor TGpStructuredFolderProxy.Create(aFolder: TGpStructuredFolder);
begin
  inherited Create;
  sfpFolder := aFolder;
//  GpLog.Log('Created  : PROXY %s', [aFolder.FullPath]);
end; { TGpStructuredFolderProxy.Create }

destructor TGpStructuredFolderProxy.Destroy;
begin
//  GpLog.Log('Destroyed: PROXY %s', [sfpFolder.FullPath]);
  inherited;
end; { TGpStructuredFolderProxy.Destroy }

{ TGpStructuredFATBlock }

constructor TGpStructuredFATBlock.Create(storage: TGpStructuredStream;
  header: TGpStructuredHeader);
begin
  inherited Create;
  sfeStorage := storage;
  sfeHeader := header;
end; { TGpStructuredFATBlock.Create }

{:Allocates FAT block that is stored at physical block 'atBlock' and covers
  storage blocks from 'atBlock'+1 to 'atBlock'+256. Connects all entries from
  this FAT block into the emtpy list.
  @since   2004-01-08
}
function TGpStructuredFATBlock.GetEntries(idxEntry: integer): cardinal;
begin
  Result := sfeEntries[idxEntry];
end; { TGpStructuredFATBlock.GetEntries }

{:Initializes FAT block and writes it into the storage.
  @since   2004-02-14
}
procedure TGpStructuredFATBlock.Initialize(atBlock: cardinal);
var
  iEntry: integer;
begin
  sfeEntries[1] := atBlock+2;
  for iEntry := 2 to CFATEntriesPerBlock-1 do
    sfeEntries[iEntry] := sfeEntries[iEntry-1]+1;
  sfeEntries[CFATEntriesPerBlock] := sfeHeader.FirstEmptyBlock;
  sfeIsDirty := true;
  sfeStorage.Size := atBlock;
  Save(atBlock);
  sfeHeader.FirstEmptyBlock := atBlock+1;
end; { TGpStructuredFATBlock.Initialize }

{:Loads FAT block from the file.
  @since   2004-02-14
}
procedure TGpStructuredFATBlock.Load(fromBlock: cardinal);
var
  block : TMemoryStream;
  iEntry: integer;
begin
  block := TMemoryStream.Create;
  try
    sfeStorage.Position := fromBlock;
    sfeStorage.ReadStream(block, CBlockSize);
    block.Position := 0;
    for iEntry := 1 to CFATEntriesPerBlock do
      block.Read(sfeEntries[iEntry], 4);
  finally FreeAndNil(block); end;
end; { TGpStructuredFATBlock.Load }

procedure TGpStructuredFATBlock.Save(toBlock: cardinal);
var
  block : TMemoryStream;
  iEntry: integer;
begin
  if sfeIsDirty then begin
    block := TMemoryStream.Create;
    try
      for iEntry := 1 to CFATEntriesPerBlock do
        block.Write(sfeEntries[iEntry], 4);
      block.Position := 0;
      sfeStorage.Position := toBlock;
      sfeStorage.WriteStream(block);
    finally FreeAndNil(block); end;
    sfeIsDirty := false;
  end;
end; { TGpStructuredFATBlock.Save }

procedure TGpStructuredFATBlock.SetEntries(idxEntry: integer;
  const value: cardinal);
begin
  if sfeEntries[idxEntry] <> value then begin
    sfeEntries[idxEntry] := value;
    sfeIsDirty := true;
  end;
end; { TGpStructuredFATBlock.SetEntries }

{ TGpStructuredFAT }

{:Allocates block and returns its number.
  @since   2004-01-08
}
function TGpStructuredFAT.AllocateBlock: cardinal;
begin
  if sfHeader.FirstEmptyBlock = 0 then
    AllocateFATBlock;
  if sfHeader.FirstEmptyBlock = 0 then
    raise Exception.Create('TGpStructuredFAT.AllocateBlock: internal error');
  Result := sfHeader.FirstEmptyBlock;
  sfHeader.FirstEmptyBlock := Entry[Result];
  Entry[Result] := 0; // return unconnected block
  Flush; 
end; { TGpStructuredFAT.AllocateBlock }

{:Allocates FAT block that is stored at the end of the storage and manages next
  256 blocks.
  @since   2004-01-08
}
function TGpStructuredFAT.AllocateFatBlock: TGpStructuredFATBlock;
begin
  Result := TGpStructuredFATBlock.Create(sfStorage, sfHeader);
  Result.Initialize(sfBlocks.Count*(CFATEntriesPerBlock+1) + 1);
  sfBlocks.Add(Result);
end; { TGpStructuredFAT.AllocateFatBlock }

{:Appends new block after the specified block (which must be last in the chain).
  @since   2004-02-14
}
function TGpStructuredFAT.AppendBlockAfter(block: cardinal): cardinal;
begin
  if Entry[block] <> 0 then
    raise Exception.CreateFmt(
      'TGpStructuredStorage: Block %d is not last in a FAT chain.', [block]);
  if sfHeader.FirstEmptyBlock = 0 then 
    AllocateFATBlock;
  Result := sfHeader.FirstEmptyBlock;
  sfHeader.FirstEmptyBlock := Next(sfHeader.FirstEmptyBlock);
  Entry[block] := Result;
  Entry[Result] := 0;
  Flush;
end; { TGpStructuredFAT.AppendBlockAfter }

{:Converts storage block number into FAT block object and offside inside it.
  @since   2004-01-08
}
procedure TGpStructuredFAT.BlockToFAT(blockNum: cardinal;
  var fatBlock: TGpStructuredFATBlock; var fatOffset: integer);
begin
  fatBlock := TGpStructuredFATBlock(sfBlocks[(blockNum-1) div (CFATEntriesPerBlock+1)]);
  fatOffset := (blockNum-1) mod (CFATEntriesPerBlock+1);
end; { TGpStructuredFAT.BlockToFAT }

constructor TGpStructuredFAT.Create(storage: TGpStructuredStream;
  header : TGpStructuredHeader);
begin
  inherited Create;
  sfStorage := storage;
  sfHeader := header;
end; { TGpStructuredFAT.Create }

destructor TGpStructuredFAT.Destroy;
begin
  FreeAndNil(sfBlocks);
  inherited;
end; { TGpStructuredFAT.Destroy }

{$IFDEF DebugStructuredStorage}
procedure TGpStructuredFAT.Dump(var dumpFile: textfile);

var
  blockList: TGpIntegerList;

   procedure DumpChain(block: cardinal);
   var
     idxBlock: integer;
   begin
     Write(dumpFile, block, ':');
     repeat
       idxBlock := blockList.IndexOf(block);
       if idxBlock >= 0 then
         blockList.Delete(idxBlock);
       block := Next(block);
       Write(dumpFile, ' ', block);
     until block = 0;
     Writeln(dumpFile);
   end; { TGpStructuredFAT.DumpChain }

var
  iBlock   : integer;

begin { TGpStructuredFAT.Dump }
  blockList := TGpIntegerList.Create;
  try
    for iBlock := 1 to sfStorage.Size-1 do
      if (iBlock mod (CFATEntriesPerBlock+1)) <> 1 then
        blockList.Add(iBlock);
    blockList.Sorted := true;
    DumpChain(sfHeader.FirstEmptyBlock);
    DumpChain(sfHeader.StorageAttributeFile);
    while blockList.Count > 0 do
      DumpChain(blockList[0]);
  finally FreeAndNil(blockList); end;
end; { TGpStructuredFAT.Dump }
{$ENDIF DebugStructuredStorage}

procedure TGpStructuredFAT.Flush;
var
  block : cardinal;
  iBlock: integer;
begin 
  block := 1;
  for iBlock := 0 to sfBlocks.Count-1 do begin
    TGpStructuredFATBlock(sfBlocks[iBlock]).Save(block);
    Inc(block, CFATEntriesPerBlock+1); // skip data blocks
  end;
end; { TGpStructuredFAT.Flush }

function TGpStructuredFAT.GetEntry(block: cardinal): cardinal;
var
  fatBlock : TGpStructuredFATBlock;
  fatOffset: integer;
begin
  BlockToFAT(block, fatBlock, fatOffset);
  Result := fatBlock[fatOffset];
end; { TGpStructuredFAT.GetEntry }

{:Initializes first FAT block.
  @since   2004-01-06
}
procedure TGpStructuredFAT.Initialize;
begin
  FreeAndNil(sfBlocks);
  sfBlocks := TObjectList.Create;
  sfStorage.Truncate(1); // leave header alone
  sfHeader.FirstFATBlock := sfStorage.Size;
  sfHeader.FirstEmptyBlock := 0;
  AllocateFatBlock;
end; { TGpStructuredFAT.Initialize }

{:Loads FAT blocks from the storage.
  @since   2004-02-14
}
procedure TGpStructuredFAT.Load;
var
  block      : cardinal;
  fatBlock   : TGpStructuredFATBlock;
  storageSize: cardinal;
begin
  FreeAndNil(sfBlocks);
  sfBlocks:= TObjectList.Create;
  block := 1;
  storageSize := sfStorage.Size;
  repeat
    fatBlock := TGpStructuredFATBlock.Create(sfStorage, sfHeader);
    fatBlock.Load(block);
    sfBlocks.Add(fatBlock);
    Inc(block, CFATEntriesPerBlock+1); // skip data blocks
  until block >= storageSize;
end; { TGpStructuredFAT.Load }

{:Returns block chained after the specified block or 0 at the end of the chain.
  @since   2004-02-14
}
function TGpStructuredFAT.Next(block: cardinal): cardinal;
begin
  Result := Entry[block];
end; { TGpStructuredFAT.Next }

{:Marks all blocks chained after the specified block empty.
  @since   2004-02-14
}
procedure TGpStructuredFAT.ReleaseBlocksAfter(block: cardinal);
var
  nextBlock: cardinal;
begin
  nextBlock := Entry[block];
  Entry[block] := 0;
  while nextBlock > 0 do begin
    block := nextBlock;
    nextBlock := Entry[block];
    Entry[block] := sfHeader.FirstEmptyBlock;
    sfHeader.FirstEmptyBlock := block;
  end; //while
  Flush;
end; { TGpStructuredFAT.ReleaseBlocksAfter }

procedure TGpStructuredFAT.ReleaseChain(block: cardinal);
begin
  ReleaseBlocksAfter(block);
  Entry[block] := sfHeader.FirstEmptyBlock;
  sfHeader.FirstEmptyBlock := block;
end; { TGpStructuredFAT.ReleaseChain }

{:Converts a linear offset into a block index and offset inside this block.
  @since   2004-02-14
}
procedure TGpStructuredFAT.Resolve(firstBlock: cardinal; offset: integer;
  var block, blockOffset: cardinal);                    
begin
  block := firstBlock;
  blockOffset := offset;
  while blockOffset > CBlockSize do begin
    if block = 0 then
      raise Exception.CreateFmt(
        'TGpStructuredStorage: Failed to resolve offset %d inside chain %d.',
        [offset, firstBlock]);
    block := Next(block);
    Dec(blockOffset, CBlockSize);
  end; //while
end; { TGpStructuredFAT.Resolve }

procedure TGpStructuredFAT.SetEntry(block: cardinal;
  const value: cardinal);
var
  fatBlock : TGpStructuredFATBlock;
  fatOffset: integer;
begin
  BlockToFAT(block, fatBlock, fatOffset);
  fatBlock[fatOffset] := value;
end; { TGpStructuredFAT.SetEntry }

{:Truncates all empty trailing FAT blocks.
  @since   2004-02-16
}        
procedure TGpStructuredFAT.Truncate;
var
  block    : cardinal;
  fatBlock : TGpStructuredFATBlock;
  fatOffset: integer;
  freeList : TGpIntegerList;
  iBlock   : integer;
  idxEmpty : integer;
  iEmpty   : integer;
begin
  for iBlock := 0 to sfBlocks.Count-1 do
    TGpStructuredFATBlock(sfBlocks[iBlock]).EmptyEntries := 0;
  freeList := TGpIntegerList.Create;
  try
    block := sfHeader.FirstEmptyBlock;
    while block <> 0 do begin
      freeList.Add(block);
      BlockToFAT(block, fatBlock, fatOffset);
      fatBlock.EmptyEntries := fatBlock.EmptyEntries + 1;
      block := fatBlock[fatOffset];
    end; //while
    freeList.Sorted := true;
    for iBlock := sfBlocks.Count-1 downto 1 do begin // never truncate first FAT block
      if TGpStructuredFATBlock(sfBlocks[iBlock]).EmptyEntries = CFATEntriesPerBlock then
      begin
        sfBlocks.Delete(iBlock);
        sfStorage.Size := sfBlocks.Count*(CFATEntriesPerBlock+1) + 1;
        for iEmpty := sfStorage.Size+1 to sfStorage.Size+CFATEntriesPerBlock do begin
          idxEmpty := freeList.IndexOf(iEmpty);
          if idxEmpty >= 0 then
            freeList.Delete(idxEmpty);
        end;
      end;
    end; //for
    // reorder free list
    if freeList.Count = 0 then
      sfHeader.FirstEmptyBlock := 0
    else begin
      sfHeader.FirstEmptyBlock := freeList[0];
      for iEmpty := 0 to freeList.Count-2 do
        Entry[freeList[iEmpty]] := freeList[iEmpty+1];
      Entry[freeList[freeList.Count-1]] := 0;
    end;
    for iEmpty := freeList.Count-1 downto 0 do
      if freeList[iEmpty] = (sfStorage.Size-1) then
        sfStorage.Size := sfStorage.Size - 1;
  finally FreeAndNil(freeList); end;
  Flush;
end; { TGpStructuredFAT.Truncate }

{ TGpStructuredFolderCache }

constructor TGpStructuredFolderCache.Create;
begin
  inherited Create;
  sfcParentFolders := TGpObjectMap.Create(true);
  sfcMRUFolders := TGpDoublyLinkedList.Create;
end; { TGpStructuredFolderCache.Create }

destructor TGpStructuredFolderCache.Destroy;
begin
  FreeAndNil(sfcMRUFolders);
  FreeAndNil(sfcParentFolders);
  inherited;
end; { TGpStructuredFolderCache.Destroy }

procedure TGpStructuredFolderCache.Flush;

  procedure GetChildlessFolderIndex(var idxFolder: integer);
  var
    folder   : TGpStructuredFolder;
    iFolder  : integer;
    subFolder: TGpStructuredFolder;
    subIndex : integer;
  begin
    idxFolder := 0;
    repeat
      folder := TGpStructuredFolder(sfcParentFolders.Items[idxFolder]);
      subIndex := -1;
      for iFolder := 0 to sfcParentFolders.Count - 1 do begin
        if iFolder <> idxFolder then begin
          subFolder := TGpStructuredFolder(sfcParentFolders.Items[iFolder]);
          if subFolder.Folder = folder then begin
            subIndex := iFolder;
            break; //for iFolder
          end;
        end;
      end; //for iFolder
      if subIndex < 0 then
        break; //until
      idxFolder := subIndex;
    until false;
  end; { GetChildlessFolderIndex }

var
  idxFolder : integer;
  iSubFolder: integer;
  parentList: TStringList;
  subFolder : TGpStructuredFolder;

begin
  sfcMRUFolders.UnlinkAll;
  while sfcParentFolders.Count > 0 do begin
    GetChildlessFolderIndex(idxFolder);
    parentList := TStringList(sfcParentFolders.ValuesIdx[idxFolder]);
    for iSubFolder := 0 to parentList.Count - 1 do begin
      subFolder := TGpStructuredFolder(parentList.Objects[iSubFolder]);
      subFolder.Proxy.Free;
      subFolder.Free;
    end;
    parentList.Clear;
    if TGpStructuredFolder(sfcParentFolders.Items[idxFolder]).FileName = '' then // root folder will be destroyed later
      break; //while
    sfcParentFolders[sfcParentFolders.Items[idxFolder]] := nil;
  end;
end; { TGpStructuredFolderCache.Flush }

{:Tries to find subfolder in the cache.
  @since   2004-02-16
}
function TGpStructuredFolderCache.GetSubFolder(parentFolder: TGpStructuredFolder;
  subFolder: string): TGpStructuredFolder;
var
  idxSubFolder: integer;
  parentList  : TStringList;
begin
  Result := nil;
  parentList := TStringList(sfcParentFolders[parentFolder]);
  if not assigned(parentList) then
    Exit;
  idxSubFolder := parentList.IndexOf(subFolder);
  if idxSubFolder < 0 then
    Exit;
  Result := TGpStructuredFolder(parentList.Objects[idxSubFolder]);
  if assigned(Result.Proxy) then begin
    Result.Proxy.Unlink;
    Result.Proxy.Free;
    Result.Proxy := nil;
  end;
end; { TGpStructuredFolderCache.GetSubFolder }

{:Removes subfolder from the cache.
  @returns False if subfolder is not cached.
  @since   2004-02-16
}
function TGpStructuredFolderCache.MarkInactive(parentFolder: TGpStructuredFolder;
  subFolder: string): boolean;
begin
  Result := InternalRemove(true, false, parentFolder, subFolder);
end; { TGpStructuredFolderCache.MarkInactive }

function TGpStructuredFolderCache.InternalRemove(markInactive, destroyFolder: boolean;
  parentFolder: TGpStructuredFolder; subFolder: string): boolean;
var
  fldSubFolder: TGpStructuredFolder;
  idxSubFolder: integer;
  parentList  : TStringList;
begin
  Result := false;
  parentList := TStringList(sfcParentFolders[parentFolder]);
  if not assigned(parentList) then
    Exit;
  idxSubFolder := parentList.IndexOf(subFolder);
  if idxSubFolder < 0 then
    Exit;
  fldSubFolder := TGpStructuredFolder(parentList.Objects[idxSubFolder]);
  if markInactive then begin
    if not assigned(fldSubFolder.Proxy) then begin
      fldSubFolder.Proxy := TGpStructuredFolderProxy.Create(fldSubFolder);
      sfcMRUFolders.InsertAtHead(fldSubFolder.Proxy);
      TrimMRUList;
    end
    else begin
      fldSubFolder.Proxy.Unlink;
      sfcMRUFolders.InsertAtHead(fldSubFolder.Proxy);
    end;
  end
  else begin
    fldSubFolder.Proxy.Free;
    fldSubFolder.Free;
    parentList.Delete(idxSubFolder);
    if parentList.Count = 0 then
      sfcParentFolders[parentFolder] := nil;
  end;
  Result := true;
end; { TGpStructuredFolderCache.InternalRemove }

function TGpStructuredFolderCache.Remove(parentFolder: TGpStructuredFolder;
  subFolder: string): boolean;
begin
  Result := InternalRemove(false, false, parentFolder, subFolder);
end; { TGpStructuredFolderCache.Remove }

procedure TGpStructuredFolderCache.Rename(parentFolder: TGpStructuredFolder;
  const oldName, newName: string);
var
  idxFolder : integer;
  parentList: TStringList;
begin
  parentList := TStringList(sfcParentFolders[parentFolder]);
  if not assigned(parentList) then // not in cache, ignore request
    Exit;
  idxFolder := parentList.IndexOf(oldName);
  if idxFolder < 0 then // not in cache, ignore request
    Exit;
  parentList[idxFolder] := newName; // rename, keep the cached .Object
  TGpStructuredFolder(parentList.Objects[idxFolder]).FileName := newName;
end; { TGpStructuredFolderCache.Rename }

procedure TGpStructuredFolderCache.Reparent(parentFolder: TGpStructuredFolder;
  const folderName: string; newParentFolder: TGpStructuredFolder);
var
  folder    : TGpStructuredFolder;
  idxFolder : integer;
  parentList: TStringList;
begin
  parentList := TStringList(sfcParentFolders[parentFolder]);
  if not assigned(parentList) then // not in cache, ignore request
    Exit;
  idxFolder := parentList.IndexOf(folderName);
  if idxFolder < 0 then // not in cache, ignore request
    Exit;
  folder := TGpStructuredFolder(parentList.Objects[idxFolder]);
  parentList.Delete(idxFolder);
  folder.SetParent(newParentFolder);
  SubFolder[newParentFolder, folderName] := folder;
end; { TGpStructuredFolderCache.Reparent }

{:Stores subfolder in the cache.
  @since   2004-02-16
}
procedure TGpStructuredFolderCache.SetSubFolder(parentFolder: TGpStructuredFolder;
  subFolder: string; const value: TGpStructuredFolder);
var
  idxSubFolder: integer;
  parentList  : TStringList;
begin
  if not AnsiSameText(subFolder, value.FileName) then
    raise Exception.CreateFmt('TGpStructuredStorage: Folder insertion problem; %s <> %s.',
      [subFolder, value.FileName]);
  if value.Folder <> parentFolder then
    raise Exception.Create('TGpStructuredStorage: Folder insertion problem; parent <> parent');
  parentList := TStringList(sfcParentFolders[parentFolder]);
  if not assigned(parentList) then begin
    parentList := TStringList.Create;
    sfcParentFolders[parentFolder] := parentList;
  end;
  idxSubFolder := parentList.IndexOf(subFolder);
  if idxSubFolder >= 0 then
    raise Exception.CreateFmt(
      'TGpStructuredStorage: Folder %s/%s is already stored in the cache.',
      [parentFolder.FileName, subFolder]);
  parentList.AddObject(subFolder, value);
end; { TGpStructuredFolderCache.SetSubFolder }

procedure TGpStructuredFolderCache.TrimMRUList;
const
  CMaxMRULength = 10; //no hard data behind this number
var
  folderProxy: TGpStructuredFolderProxy;
begin
  while sfcMRUFolders.Count > CMaxMRULength do begin
    folderProxy := TGpStructuredFolderProxy(sfcMRUFolders.RemoveFromTail);
    InternalRemove(false, true, folderProxy.Folder.Folder, folderProxy.Folder.FileName);
  end;
end; { TGpStructuredFolderCache.TrimMRUList }

{ TGpStructuredStorage }

{:Locates folder in the cache and increments its access count. 
  @since   2004-02-18
}
procedure TGpStructuredStorage.AccessFolder(folder: TGpStructuredFolder);
begin
  if not assigned(folder) then
    Exit;
  AccessFolder(folder.Folder, folder.FileName);
end; { TGpStructuredStorage.AccessFolder }

{:Locates folder in the cache and increments its access count. If folder is not found in
  the cache, creates new folder object and inserts it in the cache.
  @since   2004-02-16
}
function TGpStructuredStorage.AccessFolder(parentFolder: TGpStructuredFolder;
  const subFolder: string; autoCreate: boolean): TGpStructuredFolder;
begin
  if parentFolder = nil then
    Result := gssRootFolder
  else begin
    Result := gssFolderCache[parentFolder, subFolder];
    if assigned(Result) then
      Result.Access
    else begin
      if autoCreate then
        Result := parentFolder.OpenFolder(subFolder, fmCreate)
      else begin
        if parentFolder.FolderExists(subFolder) then
          Result := parentFolder.OpenFolder(subFolder, fmOpenRead)
        else
          Result := nil;
      end;
      if assigned(Result) then
        gssFolderCache[parentFolder, subFolder] := Result;
    end;
  end;
end; { TGpStructuredStorage.AccessFolder }

function TGpStructuredStorage.AddTrailingDelimiter(const folderName: string): string;
begin
  if (folderName = '') or (folderName[Length(folderName)] <> CFolderDelim) then
    Result := folderName + CFolderDelim
  else
    Result := folderName;
end; { TGpStructuredStorage.AddTrailingDelimiter }

procedure TGpStructuredStorage.Close;
begin
  UnregisterAllFileInfo;
  if assigned(gssFolderCache) then
    gssFolderCache.Flush;
  if assigned(gssFat) and assigned(gssFat.sfBlocks) then
    gssFAT.Truncate;
  {$IFDEF DebugStructuredStorage}
  //Dump('test.dmp');
  {$ENDIF DebugStructuredStorage}
  FreeAndNil(gssFileInfoList);
  FreeAndNil(gssRootFolder);
  FreeAndNil(gssFolderCache);
  FreeAndNil(gssFAT);
  FreeAndNil(gssStream);
  FreeAndNil(gssHeader);
end; { TGpStructuredStorage.Close }

{:Compacts the structured storage (by copying it to a temporary file).
  @since   2004-02-22
}
procedure TGpStructuredStorage.Compact;
var
  tmpStorage: TGpStructuredStorage;

  procedure CopyStorageAttributeFile;
  var
    destFile: TStream;
    srcFile : TStream;
  begin
    srcFile := OpenStorageAttributeFile;
    try
      destFile := OpenStorageAttributeFile;
      try
        destFile.CopyFrom(srcFile, 0);
      finally FreeAndNil(destFile); end;
    finally FreeAndNil(srcFile); end;
  end; { CopyStorageAttributeFile }

  procedure CopyFolder(const folderName: string);

    procedure CopyFile(const fileName: string);
    var
      destFile: TStream;
      srcFile : TStream;
    begin
      srcFile := OpenFile(fileName, fmOpenRead);
      try
        destFile := tmpStorage.OpenFile(fileName, fmCreate);
        try
          destFile.CopyFrom(srcFile, 0);
        finally FreeAndNil(destFile); end;
      finally FreeAndNil(srcFile); end;
    end; { CopyFile }

    procedure CopyAttributeFile(const fileName: string);
    var
      destFile: TStream;
      srcFile : TStream;
    begin
      srcFile := OpenAttributeFile(fileName, fmOpenRead);
      if assigned(srcFile) then try
        destFile := tmpStorage.OpenAttributeFile(fileName, fmCreate);
        try
          destFile.CopyFrom(srcFile, 0);
        finally FreeAndNil(destFile); end;
      finally FreeAndNil(srcFile); end;
    end; { CopyAttributeFile }

  var
    files   : TStringList;
    folders : TStringList;
    iFile   : integer;
    iFolder : integer;
  begin
    CopyAttributeFile(folderName);
    folders := TStringList.Create;
    try
      FolderNames(folderName, folders);
      for iFolder := 0 to folders.Count-1 do
        tmpStorage.CreateFolder(folderName+folders[iFolder]);
      files := TStringList.Create;
      try
        FileNames(folderName, files);
        for iFile := 0 to files.Count-1 do begin
          CopyFile(folderName+files[iFile]);
          CopyAttributeFile(folderName+files[iFile]);
        end; //for
      finally FreeAndNil(files); end;
      for iFolder := 0 to folders.Count-1 do
        CopyFolder(folderName + folders[iFolder] + CFolderDelim);
    finally FreeAndNil(folders); end;
  end; { TGpStructuredStorage.CopyFolder }

var
  tempFile  : string;
  tempStream: TFileStream;

begin { TGpStructuredStorage.Compact }
  tempFile := GetTempFileName('gss');
  try
    tempStream := TFileStream.Create(tempFile, fmCreate);
    try
      tmpStorage := TGpStructuredStorage.Create;
      try
        tmpStorage.Initialize(tempStream);
        CopyFolder(CFolderDelim);
      finally FreeAndNil(tmpStorage); end;
      Close;
      try
        gssStorage.Position := 0;
        tempStream.Position := 0;
        gssStorage.CopyFrom(tempStream, 0);
        gssStorage.Size := gssStorage.Position;
      finally InitializeStorage; end;
    finally FreeAndNil(tempStream); end;
  finally
    if SysUtils.FileExists(tempFile) then
      SysUtils.DeleteFile(tempFile);
  end;
end; { TGpStructuredStorage.Compact }

{:Create empty storage stream.
  @since   2003-11-24
}
procedure TGpStructuredStorage.CreateEmptyStorage;
begin
  if not gssHeader.CreateHeader then
    raise EGpStructuredStorage.CreateFmt('Failed to create structured storage header.',
      [DataFile]);
  gssHeader.Version := CVersion;
  gssFAT.Initialize;
  gssRootFolder := TGpStructuredFolder.Create(self, nil, gssFolderCache, '', gssFAT.AllocateBlock, 0);
  gssRootFolder.OnSizeChanged := RootFolderSizeChanged;
  gssRootFolder.Initialize(0);
  gssHeader.FirstRootFolderBlock := gssRootFolder.FirstBlock;
  gssHeader.StorageAttributeFile := gssFAT.AllocateBlock;
  gssHeader.StorageAttributeFileSize := 0;
end; { TGpStructuredStorage.CreateEmptyStorage }

function TGpStructuredStorage.CreateFileInfo(owner: TGpStructuredStorage;
  folder: TGpStructuredFolder; const fileName: string): IGpStructuredFileInfo;
var
  fileInfo: TGpStructuredFileInfo;
begin
  fileInfo := TGpStructuredFileInfo.Create(owner, folder, fileName);
  gssFileInfoList.Add(pointer(fileInfo));
  Result := fileInfo;
end; { TGpStructuredStorage.CreateFileInfo }

procedure TGpStructuredStorage.CreateFolder(const folderName: string);
var
  stgFolder: TGpStructuredFolder;
begin
  if FolderExists(folderName) then
    raise EGpStructuredStorage.CreateFmt('Folder %s already exists', [folderName]);
  stgFolder := DescendTree(AddTrailingDelimiter(NormalizeFileName(folderName)));
  if assigned(stgFolder) then
    ReleaseFolder(stgFolder)
  else
    raise EGpStructuredStorage.CreateFmt('Failed to create folder %s', [folderName]);
end; { TGpStructuredStorage.CreateFolder }

{:Deletes a file or folder tree (even if not empty).
  @since   2004-02-16
}
procedure TGpStructuredStorage.Delete(const objectName: string);
var
  folder   : string;
  name     : string;
  stgFolder: TGpStructuredFolder;
begin
  SplitFileName(objectName, folder, name);
  stgFolder := DescendTree(folder, false);
  if assigned(stgFolder) then begin
    try
      stgFolder.DeleteEntry(name);
      if not stgFolder.IsEmpty then
        folder := '';
    finally ReleaseFolder(stgFolder); end;
    if (folder <> '') and (folder <> CFolderDelim) and (name = '') then
      Delete(StripTrailingDelimiter(folder)); // delete folder too; strip last delimiter to prevent recursion
  end;
end; { TGpStructuredStorage.Delete }

{:Descends to the folder inside the storage.
  @precondition  Folder name is not empty and starts with CFolderDelim.
  @postcondition autoCreate is False or Result is assigned.
  @param   autoCreate If True (default), all folders are created automatically. If False,
                      the code returns nil if the folder doesn't exist.
  @raises  EGpStructuredStorage on malformed folder name.
  @since   2003-11-10
}
function TGpStructuredStorage.DescendTree(folderName: string;
  autoCreate: boolean): TGpStructuredFolder;
var
  parent: TGpStructuredFolder;
  pDelim: integer;
begin 
  if (folderName = '') or (folderName[1] <> CFolderDelim) then
    raise Exception.CreateFmt('TGpStructuredStorage: Invalid folder name %s', [folderName]);
  System.Delete(folderName, 1, 1);
  Result := AccessFolder(nil, '', autoCreate);
  repeat
    pDelim := Pos(CFolderDelim, folderName);
    if pDelim > 0 then begin
      parent := Result;
      Result := AccessFolder(parent, Copy(folderName, 1, pDelim-1), autoCreate);
      System.Delete(folderName, 1, pDelim);
      ReleaseFolder(parent);
    end;
  until (pDelim = 0) or (not assigned(Result));
  if autoCreate and (not assigned(Result)) then
    raise Exception.Create('TGpStructuredStorage: Result is not assigned');
end; { TGpStructuredStorage.DescendTree }
  
{:Flushes cached data to the data file and destroyes the structure storate
  object.
  @since   2003-11-10
}
destructor TGpStructuredStorage.Destroy;
begin
  Close;
  if gssOwnsStream then
    FreeAndNil(gssStorage);
  inherited;
end; { TGpStructuredStorage.Destroy }

procedure TGpStructuredStorage.Dump(const fileName: string);
{$IFDEF DebugStructuredStorage}
var
  df: textfile;
{$ENDIF DebugStructuredStorage}
begin
  {$IFNDEF DebugStructuredStorage}
  raise Exception.Create('TGpStructuredStorage.Dump: Not supported');
  {$ELSE}
  AssignFile(df, fileName);
  Rewrite(df);
  try
    Writeln(df, 'File name: ', gssFileName);
    Writeln(df, 'Version: ', Format('%.8x', [gssHeader.Version]));
    Writeln(df, 'First empty block: ', gssHeader.FirstEmptyBlock);
    Writeln(df, 'First FAT block: ', gssHeader.FirstFATBlock);
    Writeln(df, 'First root folder block: ', gssHeader.FirstRootFolderBlock);
    Writeln(df, 'Root folder size: ', gssHeader.RootFolderSize);
    Writeln(df, 'Storage attribute file: ', gssHeader.StorageAttributeFile);
    Writeln(df, 'Storage attribute file size: ', gssHeader.StorageAttributeFileSize);
    Writeln(df);
    Writeln(df, 'FAT:');
    gssFAT.Dump(df);
    Writeln(df);
    Writeln(df, 'Folders:');
    gssRootFolder.Dump(df, '');
  finally CloseFile(df) end;
  {$ENDIF DebugStructuredStorage}
end; { TGpStructuredStorage.Dump }

{:Checks whether the specified file or folder exists.
  @since   2004-03-02
}
function TGpStructuredStorage.FileExists(const fileName: string): boolean;
var
  folder   : string;
  name     : string;
  stgFolder: TGpStructuredFolder;
begin
  Result := false;
  SplitFileName(fileName, folder, name);
  stgFolder := DescendTree(folder, false);
  if not assigned(stgFolder) then
    Exit;
  try
    Result := stgFolder.FileExists(name);
  finally ReleaseFolder(stgFolder); end;
end; { TGpStructuredStorage.FileExists }

{:Returns list of files in folder 'folderName'.
  @since   2004-02-16
}        
procedure TGpStructuredStorage.FileNames(const folderName: string; {out} files: TStrings);
var
  stgFolder: TGpStructuredFolder;
begin
  stgFolder := DescendTree(NormalizeFileName(folderName, true));
  try
    stgFolder.FileNames(files);
  finally ReleaseFolder(stgFolder); end;
end; { TGpStructuredStorage.FileNames }

{:Checks whether the specified file or folder exists.
  @since   2004-03-02
}
function TGpStructuredStorage.FolderExists(const folderName: string): boolean;
var
  stgFolder: TGpStructuredFolder;
begin
  Result := false;
  stgFolder := DescendTree(AddTrailingDelimiter(NormalizeFileName(folderName)), false);
  if assigned(stgFolder) then try
    Result := true;
  finally ReleaseFolder(stgFolder); end;
end; { TGpStructuredStorage.FolderExists }

{:Returns list of folders in folder 'folderName'.
  @since   2004-02-16
}
procedure TGpStructuredStorage.FolderNames(const folderName: string;
  {out} folders: TStrings);
var
  stgFolder: TGpStructuredFolder;
begin
  stgFolder := DescendTree(NormalizeFileName(folderName, true));
  try
    stgFolder.FolderNames(folders);
  finally ReleaseFolder(stgFolder); end;
end; { TGpStructuredStorage.FolderNames }
  
function TGpStructuredStorage.GetDataFile: string;
begin
  Result := gssFileName;
end; { TGpStructuredStorage.GetDataFile }

function TGpStructuredStorage.GetDataSize: integer;
begin
  Result := gssStorage.Size;
end; { TGpStructuredStorage.GetDataSize }

{:Returns file information interface
  @since   2004-02-18
}
function TGpStructuredStorage.GetFileInfo(const fileName: string): IGpStructuredFileInfo;
var
  folder   : string;
  name     : string;
  normName : string;
  stgFolder: TGpStructuredFolder;
begin
  if fileName = '' then
    Result := CreateFileInfo(self, gssRootFolder, '')
  else begin
    normName := NormalizeFileName(fileName);
    if normName = CFolderDelim then
      Result := CreateFileInfo(self, gssRootFolder, '')
    else begin
      Result := nil;
      if FolderExists(normName) then
        SplitFileName(StripTrailingDelimiter(normName), folder, name)
      else
        SplitFileName(normName, folder, name);
      stgFolder := DescendTree(folder);
      try
        if stgFolder.ObjectExists(name) then
          Result := CreateFileInfo(self, stgFolder, name);
      finally ReleaseFolder(stgFolder); end;
    end;
  end;
end; { TGpStructuredStorage.GetFileInfo }

{:Bind structured storage to a file and initialize it.
  @raises  EGpStructuredStorage on any error.
  @since   2004-01-08
}
procedure TGpStructuredStorage.Initialize(const storageDataFile: string;
  mode: word);
begin
  if assigned(gssStorage) then
    raise EGpStructuredStorage.Create('Already initialized');
  if mode = fmOpenWrite then
    mode := fmOpenReadWrite;
  gsmStorageMode := mode;
  gssFileName := storageDataFile;
  gssStorage := TFileStream.Create(storageDataFile, mode);
  gssOwnsStream := true;
  InitializeStorage;
end; { TGpStructuredStorage.Initialize }

{:Bind structured storage to a stream and initialize it.
  @raises  EGpStructuredStorage on any error
  @since   2004-01-08
}
procedure TGpStructuredStorage.Initialize(storageDataStream: TStream);
begin
  if assigned(gssStorage) then
    raise EGpStructuredStorage.Create('Already initialized');
  gssFileName := '';
  gsmStorageMode := fmOpenReadWrite;
  gssStorage := storageDataStream;
  gssOwnsStream := false;
  InitializeStorage;
end; { TGpStructuredStorage.Initialize }
  
{:Checks if a file contains structured storage.
  @since   2004-12-16
}        
function TGpStructuredStorage.IsStructuredStorage(const storageDataFile: string): boolean;
begin
  if assigned(gssStorage) then
    raise EGpStructuredStorage.Create('Already initialized');
  gssFileName := storageDataFile;
  gssStorage := TFileStream.Create(storageDataFile, fmOpenRead);
  Result := VerifyHeader;
  Close;
  FreeAndNil(gssStorage);
end; { TGpStructuredStorage.IsStructuredStorage }

{:Checks if folder is empty.
  @since   2006-01-29
}
function TGpStructuredStorage.IsFolderEmpty(const folderName: string): boolean;
var
  stgFolder: TGpStructuredFolder;
begin
  stgFolder := DescendTree(NormalizeFileName(folderName, true), false);
  if not assigned(stgFolder) then
    Result := true
  else try
    Result := stgFolder.IsEmpty;
  finally ReleaseFolder(stgFolder); end;
end; { TGpStructuredStorage.IsFolderEmpty }

{:Checks if a stream contains structured storage.
  @since   2004-12-16
}
function TGpStructuredStorage.IsStructuredStorage(storageDataStream: TStream): boolean;
begin
  if assigned(gssStorage) then
    raise EGpStructuredStorage.Create('Already initialized');
  gssFileName := '';
  gssStorage := storageDataStream;
  Result := VerifyHeader;
  Close;
end; { TGpStructuredStorage.IsStructuredStorage }

{:Initializes structure storage object.
  @since   2003-11-10
}
procedure TGpStructuredStorage.InitializeStorage;
begin
  PrepareStructures;
  if gssStream.Size = 0 then
    CreateEmptyStorage
  else
    LoadStorageMetadata;
end; { TGpStructuredStorage.InitializeStorage }
  
{:Loads metadata from the storage.
  @since   2004-01-06
}
procedure TGpStructuredStorage.LoadStorageMetadata;
begin
  if not gssHeader.LoadHeader then
    raise EGpStructuredStorage.CreateFmt('Failed to load header.', [DataFile]);
  if (gssHeader.Version > CVersion) or
     (gssHeader.Version < CLowestSupported)
  then
    raise EGpStructuredStorage.CreateFmt('Invalid version (%.8x, expected from %.8x to %.8x).',
      [gssHeader.Version, CLowestSupported, CVersion]);
  if (gssHeader.Version <> CVersion) and (gsmStorageMode <> fmOpenRead) then
    gssHeader.Version := CVersion;
  gssFAT.Load;
  gssRootFolder := TGpStructuredFolder.Create(self, nil, gssFolderCache, '',
    gssHeader.FirstRootFolderBlock, gssHeader.RootFolderSize);
  gssRootFolder.OnSizeChanged := RootFolderSizeChanged;
  gssRootFolder.Initialize(gssHeader.RootFolderSize);
end; { TGpStructuredStorage.LoadStorageMetadata }

{:Moves file or folder to another location.
  @since   2004-03-02
}        
procedure TGpStructuredStorage.Move(const objectName, newName: string);
var
  destFolder     : string;
  destName       : string;
  destStrFolder  : TGpStructuredFolder;
  sourceFolder   : string;
  sourceName     : string;
  sourceStrFolder: TGpStructuredFolder;
begin
  if FolderExists(objectName) then begin
    SplitFileName(StripTrailingDelimiter(objectName), sourceFolder, sourceName);
    SplitFileName(StripTrailingDelimiter(newName), destFolder, destName);
  end
  else begin
    SplitFileName(objectName, sourceFolder, sourceName);
    SplitFileName(newName, destFolder, destName);
  end;
  sourceStrFolder := DescendTree(sourceFolder, false);
  if not assigned(sourceStrFolder) then
    raise EGpStructuredStorage.CreateFmt('Source folder %s does not exist', [sourceFolder]);
  try
    if not sourceStrFolder.ObjectExists(sourceName) then
      raise EGpStructuredStorage.CreateFmt('Source object %s does not exist', [objectName]);
    destStrFolder := DescendTree(destFolder);
    try
      if destStrFolder.ObjectExists(destName) then
        raise EGpStructuredStorage.CreateFmt('Destination object %s already exists', [newName]);
      destStrFolder.MoveFrom(sourceStrFolder, sourceName, destName);
    finally ReleaseFolder(destStrFolder); end;
  finally ReleaseFolder(sourceStrFolder) end;
end; { TGpStructuredStorage.Move }

{:Converts \-delimited folders into /-delimited.
  @raises  EGpStructuredStorage on malformed file name.
  @since   2003-11-10
}
function TGpStructuredStorage.NormalizeFileName(const fileName: string;
  isFolder: boolean): string;
begin
  Result := StringReplace(fileName, '\', CFolderDelim, [rfReplaceAll]);
  if (Result = '') and isFolder then
    Result := CFolderDelim;
  if (Result = '') or (Result[1] <> CFolderDelim) then
    raise EGpStructuredStorage.CreateFmt('Relative paths are not supported: %s',
      [fileName]);
  if isFolder and (Result[Length(Result)] <> CFolderDelim) then
    Result := Result + CFolderDelim;
end; { TGpStructuredStorage.NormalizeFileName }

{:Opens/creates an attribute storage file.
  @since   2004-03-02
}        
function TGpStructuredStorage.OpenAttributeFile(const fileName: string;
  mode: word): TStream;
var
  folder   : string;
  name     : string;
  stgFolder: TGpStructuredFolder;
begin
  SplitFileName(StripTrailingDelimiter(fileName, true), folder, name);
  stgFolder := DescendTree(folder);
  try
    Result := stgFolder.OpenAttributeFile(name, mode);
  finally ReleaseFolder(stgFolder); end;
end; { TGpStructuredStorage.OpenAttributeFile }

{:Opens/creates a file inside structured storage. Automatically creates needed
  folders.
  @param   fileName Name of the file to be open/created. MUST be specified with
                    the absolute path (i.e. MUST start with either / or \).
  @param   mode     Mode to open the file in. Same as TFileStream.Create mode.
                    fmCreate: Creates/overwrites a file.
                    fmOpenRead, fmOpenWrite, fmOpenReadWrite: Opens existing
                    file in read-write mode.
  @returns Nil if file does not exist and mode is not fmCreate; an object
           representing the file otherwise. Caller is responsible for destroying this
           object.
  @raises  EGpStructuredStorage on malformed file name.
  @since   2003-11-10
}
function TGpStructuredStorage.OpenFile(const fileName: string; mode: word): TStream;
var
  folder   : string;
  name     : string;
  stgFolder: TGpStructuredFolder;
begin
  SplitFileName(fileName, folder, name);
  stgFolder := DescendTree(folder);
  try
    Result := stgFolder.OpenFile(name, mode);
  finally ReleaseFolder(stgFolder); end;
  if not assigned(Result) then
    raise EGpStructuredStorage.CreateFmt('File %s doesn''t exist.', [fileName]);
end; { TGpStructuredStorage.OpenFile }

{:Opens storage-global attribute file.
  @since   2004-03-02
}        
function TGpStructuredStorage.OpenStorageAttributeFile: TGpStructuredFile;
begin
  Result := TGpStructuredFile.Create(self, gssRootFolder, '',
    gssHeader.StorageAttributeFile, gssHeader.StorageAttributeFileSize,
    [sfAttrIsAttributeFile]);
  Result.OnSizeChanged := StorageAttributeFileSizeChanged;
end; { TGpStructuredStorage.OpenStorageAttributeFile }

procedure TGpStructuredStorage.PrepareStructures;
begin
  gssFileInfoList := TList.Create;
  gssFolderCache := TGpStructuredFolderCache.Create;
  gssStream := TGpStructuredStream.Create(gssStorage);
  gssHeader := TGpStructuredHeader.Create(gssStream);
  gssFAT := TGpStructuredFAT.Create(gssStream, gssHeader);
end; { TGpStructuredStorage.PrepareStructures }

procedure TGpStructuredStorage.ReleaseFolder(var folder: TGpStructuredFolder);
begin
  if not assigned(folder) then
    Exit;
  if assigned(folder.Folder) and // Root folder is always cached and is not reference-counted
     folder.Release
  then
    gssFolderCache.MarkInactive(folder.Folder, folder.FileName);
end; { TGpStructuredStorage.ReleaseFolder }

{:Renames folder in the folder cache.
  @since   2004-03-02
}          
procedure TGpStructuredStorage.RenameFolder(owner: TGpStructuredFolder;
  const oldName, newName: string);
begin
  gssFolderCache.Rename(owner, oldName, newName);
end; { TGpStructuredStorage.RenameFolder }

{:Reparents folder in the folder cache.
  @since   2004-03-02
}        
procedure TGpStructuredStorage.ReparentFolder(oldOwner: TGpStructuredFolder;
  const folderName: string; newOwner: TGpStructuredFolder);
begin
  gssFolderCache.Reparent(oldOwner, folderName, newOwner);
end; { TGpStructuredStorage.ReparentFolder }

procedure TGpStructuredStorage.RootFolderSizeChanged(sender: TObject);
begin
  gssHeader.RootFolderSize := gssRootFolder.Size;
end; { TGpStructuredStorage.RootFolderSizeChanged }
  
{:Splits file name into the folder and file parts.
  @since   2003-11-10
}
procedure TGpStructuredStorage.SplitFileName(const fullName: string;
  var folderName, fileName: string);
begin
  fileName := NormalizeFileName(fullName);
  // LastDelimiter() > 0 - ensured by the NormalizeFileName
  folderName := Copy(fileName, 1, LastDelimiter(CFolderDelim, fileName));
  System.Delete(fileName, 1, Length(folderName));
end; { TGpStructuredStorage.SplitFileName }

procedure TGpStructuredStorage.StorageAttributeFileSizeChanged(sender: TObject);
begin
  gssHeader.StorageAttributeFileSize := (sender as TGpStructuredFile).Size;
end; { TGpStructuredStorage.StorageAttributeFileSizeChanged }

function TGpStructuredStorage.StripTrailingDelimiter(const fileName: string;
  leaveRootDelimited: boolean): string;
const
  CMinLength: array [false..true] of integer = (0, 1);
begin
  if (Length(fileName) > CMinLength[leaveRootDelimited]) and
     (fileName[Length(fileName)] = CFolderDelim)
  then
    Result := Copy(fileName, 1, Length(fileName)-1)
  else
    Result := fileName;
end; { TGpStructuredStorage.StripTrailingDelimiter }

procedure TGpStructuredStorage.UnregisterAllFileInfo;
var
  iFileInfo: integer;
begin
  if not Assigned(gssFileInfoList) then
    Exit;
  for iFileInfo := 0 to gssFileInfoList.Count-1 do
    TGpStructuredFileInfo(gssFileInfoList[iFileInfo]).ClearOwner;
  gssFileInfoList.Clear;
end; { TGpStructuredStorage.UnregisterAllFileInfo }

procedure TGpStructuredStorage.UnregisterFileInfo(fileInfo: TGpStructuredFileInfo);
begin
  gssFileInfoList.Remove(pointer(fileInfo));
end; { TGpStructuredStorage.UnregisterFileInfo }

function TGpStructuredStorage.VerifyHeader: boolean;
begin
  PrepareStructures;
  if gssStream.Size = 0 then
    Result := false
  else
    Result := gssHeader.LoadHeader and
              (gssHeader.Version <= CVersion) and
              (gssHeader.Version >= CLowestSupported);
end; { TGpStructuredStorage.VerifyHeader }

//initialization
//  GpLog.FileName := 'GpStructuredStorage.log';
//  GpLog.LoggingType := ltFastFile;
end.

