# DSiWin32 - Win32/Win64 Wrappers and Helper Functions

**Version:** 2.18d (2026-10-30)
**Maintainer:** Primoz Gabrijelcic (gabr)
**Contributors:** ales, aoven, gabr, Lee_Nover, _MeSSiah_, Miha-R, Odisej, xtreme, Brdaws, Gre-Gor, krho, Cavlji, radicalb, fora, M.C, MP002, Mitja, Christian Wimmer, Tommi Prami, Miha, Craig Peterson, Tommaso Ercole, bero, Claude Code
**License:** Free for personal and commercial use. No rights reserved.
**Unit File:** dsiwin32.pas

## Overview

DSiWin32 is the largest unit in the `x:\gp\common` library (10,000+ lines) and a hard dependency of dozens of other units in the tree. It collects Win32/Win64 API wrappers, dynamically-loaded forwarders for OS APIs that don't exist on every Windows version, and a number of higher-level utilities: handles, registry, files, processes, memory, windows, desktop/Aero/taskbar/menus/screen/clipboard, system information, install helpers (shortcuts, firewall, uninstall info, autorun), time, 64-bit interlocked ops, and dynamically-loaded API forwarders.

**Almost every project that uses `x:\gp\common` uses DSiWin32.** Some other units (e.g. `GpTimestamp.pas`) conditionally depend on it for Windows-only features (`DSiTimeGetTime64`).

### Key Features

- **Broad Win32/Win64 coverage** - registry, files, processes, threads, windows, desktop, system info, install, time, interlocked ops
- **Dynamically-loaded forwarders** - wraps APIs that may not exist on every Windows version (`DynaLoad` section); auto-loads the DLL and calls the real function, or fails gracefully
- **Higher-level conveniences** - `TDSiRegistry`, `TDSiTimer`, shortcut creation, firewall exception list management, process affinity helpers for hybrid P-core/E-core CPUs
- **Consistent naming** - every public identifier is prefixed `DSi` (or `TDSi` for types), grouped into named, comment-marked sections in the interface

## Dependencies

DSiWin32 is a foundational unit: it depends on standard RTL/VCL units (`Windows`, `SysUtils`, `Classes`, `Registry`, `ActiveX`, `ComObj`, `ShlObj`, etc.) but not on other `Gp*` units, making it safe to use from base infrastructure code. Some other units in the library depend on it — e.g. `GpTimestamp.pas`'s Windows-only time sources call `DSiTimeGetTime64`.

## Section Map

The interface is split into named, comment-marked sections (`{ Handles }`, `{ Registry }`, ...). They appear in this order in both the interface and implementation:

`Handles` · `Registry` · `Files` · `Processes` · `Memory` · `Windows` · `Aero` · `Taskbar` · `Menus` · `Screen` · `Rectangles` · `Clipboard` · `Information` · `Install` · `Time` · `Interlocked` · `DynaLoad` · `Helpers`

---

## { Handles }

```pascal
procedure DSiCloseHandleAndInvalidate(var handle: THandle);   // CloseHandle + handle := INVALID_HANDLE_VALUE
procedure DSiCloseHandleAndNull(var handle: THandle);         // CloseHandle + handle := 0

// Wait helpers
function  DSiMsgWaitForThreeObjectsEx(obj0, obj1, obj2: THandle; timeout, wakeMask, flags: DWORD): DWORD;
function  DSiMsgWaitForTwoObjectsEx  (obj0, obj1: THandle;       timeout, wakeMask, flags: DWORD): DWORD;
function  DSiWaitForThreeObjects   (obj0, obj1, obj2: THandle; waitAll: boolean; timeout: DWORD): DWORD;
function  DSiWaitForThreeObjectsEx (obj0, obj1, obj2: THandle; waitAll: boolean; timeout: DWORD; alertable: boolean): DWORD;
function  DSiWaitForTwoObjects     (obj0, obj1: THandle;       waitAll: boolean; timeout: DWORD): DWORD;
function  DSiWaitForTwoObjectsEx   (obj0, obj1: THandle;       waitAll: boolean; timeout: DWORD; alertable: boolean): DWORD;

function  DSiWin32CheckHandle    (handle: THandle): THandle;   // raises EOSError on INVALID_HANDLE_VALUE
function  DSiWin32CheckNullHandle(handle: THandle): THandle;   // raises EOSError on 0
```

Also defines pretty-print handle aliases (`TDSiFileHandle`, `TDSiPipeHandle`, `TDSiMutexHandle`, `TDSiEventHandle`, `TDSiSemaphoreHandle` - all `THandle`), the callback types used throughout the unit (`TDSiEnumFilesCallback`, `TDSiEnumFilesExCallback`, `TDSiEnumFilesExErrorCallback`, `TDSiOnNewLineCallback`, `TDSiProcessCreatedEvent`, `TDSiCopyFileRestartableCallback`, `TDSiCopyFileRestartableStatus`, `TDSiFileTime`), and constants `KEY_WOW64_64KEY`, `WAIT_OBJECT_1`..`WAIT_OBJECT_9`, `THREAD_*` access rights. `DSiNativeInt`/`DSiNativeUInt` map to `NativeInt`/`NativeUInt` on XE+ and `integer`/`cardinal` on older Delphis.

---

## { Registry }

### `TDSiRegistry` (extends `TRegistry`)

```pascal
function  ReadBinary(const name: string; const defval: RawByteString): RawByteString; overload;
function  ReadBinary(const name: string; dataStream: TStream): boolean; overload;
function  ReadBool   (const name: string; defval: boolean): boolean;            // accepts 't','true'
function  ReadDate   (const name: string; defval: TDateTime): TDateTime;
function  ReadInt64  (const name: string; defval: int64): int64;
function  ReadInteger(const name: string; defval: integer): integer;            // accepts string and 4-byte binary
function  ReadString (const name, defval: string): string;                      // accepts DWORD too
procedure ReadStrings(const name: string; strings: TStrings);                   // MULTI_SZ
function  ReadVariant(const name: string; defval: variant): variant;
procedure WriteBinary(const name: string; data: RawByteString); overload;
procedure WriteBinary(const name: string; data: TStream); overload;
procedure WriteInt64 (const name: string; value: int64);
procedure WriteStrings(const name: string; strings: TStrings);                  // MULTI_SZ
procedure WriteVariant(const name: string; value: variant);
```

### Registry helpers (no class)

```pascal
function  DSiCreateRegistryKey(const registryKey: string; root: HKEY = HKEY_CURRENT_USER): boolean;
function  DSiDeleteRegistryValue(const registryKey, name: string;
            root: HKEY = HKEY_CURRENT_USER; access: longword = KEY_SET_VALUE): boolean;
function  DSiKillRegistry(const registryKey: string; root: HKEY = HKEY_CURRENT_USER;
            access: longword = KEY_QUERY_VALUE OR KEY_SET_VALUE OR KEY_ENUMERATE_SUB_KEYS): boolean;
function  DSiReadRegistry(const registryKey, name: string; defaultValue: Variant;
            root: HKEY = HKEY_CURRENT_USER; access: longword = KEY_QUERY_VALUE): Variant; overload;
function  DSiReadRegistry(const registryKey, name: string; defaultValue: int64;
            root: HKEY = HKEY_CURRENT_USER; access: longword = KEY_QUERY_VALUE): int64; overload;
function  DSiRegistryKeyExists  (const registryKey: string; root: HKEY = HKEY_CURRENT_USER;
            access: longword = KEY_QUERY_VALUE): boolean;
function  DSiRegistryValueExists(const registryKey, name: string; root: HKEY = HKEY_CURRENT_USER;
            access: longword = KEY_QUERY_VALUE): boolean;
function  DSiWriteRegistry(const registryKey, name: string; value: int64;
            root: HKEY = HKEY_CURRENT_USER; access: longword = KEY_SET_VALUE): boolean; overload;
function  DSiWriteRegistry(const registryKey, name: string; value: Variant;
            root: HKEY = HKEY_CURRENT_USER; access: longword = KEY_SET_VALUE): boolean; overload;

procedure DSiRegisterUserFileAssoc(const extension, progID, description, defaultIcon, openCommand: string);
procedure DSiUnregisterUserFileAssoc(const progID: string);

function  DSiCopyRegistry(const sourceKey, targetKey: string;
            root: HKEY = HKEY_CURRENT_USER; doCopySubkeys: boolean = true): boolean;
```

---

## { Files }

### Types/sets

```pascal
TShFileOpFlag = (fofAllowUndo, fofFilesOnly, fofMultiDestFiles, fofNoConfirmation,
  fofNoConfirmMkDir, fofNoConnectedElements, fofNoErrorUI, fofNoRecursion,
  fofNoRecurseReparse, fofRenameOnCollision, fofSilent, fofSimpleProgress,
  fofWantMappingHandle, fofWantNukeWarning, fofNoUI);
TShFileOpFlags = set of TShFileOpFlag;
```

### `TDSiFileInfo`

```pascal
constructor Create(const folder: string; searchRec: TSearchRec; depth: integer);
property Depth: integer;          property Folder: string;
property FullName: string;        property SearchRec: TSearchRec;
```

### Functions

```pascal
function  DSiCanWriteToFolder(const folderName: string): boolean;
function  DSiCompressFile(fileHandle: THandle): boolean;
function  DSiConnectToNetworkResource(const networkResource: string;
            const mappedLetter: string = ''; const username: string = ''; const password: string = ''): boolean;
function  DSiCopyFileAnimated(ownerWindowHandle: THandle; sourceFile, destinationFile: string;
            var aborted: boolean; flags: TShFileOpFlags = [fofNoConfirmMkDir]): boolean;
function  DSiCopyFileRestartable(const sourceFile, destFile: string;
            const callback: TDSiCopyFileRestartableCallback;
            var copyError: DWORD): TDSiCopyFileRestartableStatus;
function  DSiCreateTempFolder: string;
procedure DSiDeleteFiles(const folder, fileMask: string);
function  DSiDeleteOnReboot(const fileName: string): boolean;
procedure DSiDeleteTree(const folder: string; removeSubdirsOnly: boolean; allowRoot: boolean = false);
function  DSiDeleteWithBatch(const fileName: string; rmDir: boolean = false): boolean;
function  DSiDirectoryExistsW(const directory: WideString): boolean;
function  DSiDisableWow64FsRedirection(var oldStatus: pointer): boolean;
function  DSiDisconnectFromNetworkResource(mappedLetter: char; updateProfile: boolean = false): boolean;
function  DSiEjectMedia(deviceLetter: char): boolean;
procedure DSiEmptyFolder(const folder: string);
function  DSiEmptyRecycleBin: boolean;

function  DSiEnumFiles  (const fileMask: string; attr: integer;
            enumCallback: TDSiEnumFilesCallback): integer;
function  DSiEnumFilesEx(const fileMask: string; attr: integer;
            enumSubfolders: boolean; enumCallback: TDSiEnumFilesExCallback;
            maxEnumDepth: integer = 0; ignoreDottedFolders: boolean = false): integer; overload;
function  DSiEnumFilesEx(const fileMask: string; attr: integer; enumSubfolders: boolean;
            enumCallback: TDSiEnumFilesExCallback;
            errorCallback: TDSiEnumFilesExErrorCallback;
            maxEnumDepth: integer = 0; ignoreDottedFolders: boolean = false): integer; overload;
function  DSiEnumFilesEx(const fileMask: string; attr: integer; enumSubfolders: boolean;
            enumCallback: TDSiEnumFilesExCallback; var error: integer; var errorPath: string;
            maxEnumDepth: integer = 0; ignoreDottedFolders: boolean = false): integer; overload;
procedure DSiEnumFilesToSL(const fileMask: string; attr: integer; fileList: TStrings;
            storeFullPath: boolean = false; enumSubfolders: boolean = false;
            maxEnumDepth: integer = 0; ignoreDottedFolders: boolean = false);
procedure DSiEnumFilesToOL(const fileMask: string; attr: integer;
            fileList: TObjectList {of TDSiFileInfo};
            enumSubfolders: boolean = false; maxEnumDepth: integer = 0;
            ignoreDottedFolders: boolean = false);

function  DSiFileExistsW(const fileName: WideString): boolean;
function  DSiFileExtensionIs(const fileName, extension: string): boolean; overload;
function  DSiFileExtensionIs(const fileName: string; const extension: array of string): boolean; overload;
function  DSiFileExtensionIs(const fileName: string; const extension: TArray<string>): boolean; overload;
function  DSiFileSize       (const fileName: string): int64;
function  DSiFileSizeAndTime(const fileName: string; var dtModified_UTC: TDateTime; var size: int64): boolean;
function  DSiFileSizeW      (const fileName: WideString): int64;
function  DSiGetFolderSize  (const folder: string; includeSubfolders: boolean;
                              followSymlinks: boolean = false): int64;
function  DSiGetFileTime    (const fileName: string; whatTime: TDSiFileTime): TDateTime;
function  DSiGetFileTimes   (const fileName: string;
                              var creationTime, lastAccessTime, lastModificationTime: TDateTime): boolean;
function  DSiGetLongPathName(const fileName: string): string;
function  DSiGetNetworkResource(mappedLetter: char; var networkResource: string;
                                var connectionIsAvailable: boolean): boolean;
function  DSiGetSubstDrive(mappedLetter: char): string;
function  DSiGetSubstPath (const path: string): string;
function  DSiGetTempFileName(const prefix: string; const tempPath: string = ''): string;
function  DSiGetTempPath: string;
function  DSiGetUniqueFileName(const extension: string): string;
function  DSiIsFileCompressed (const fileName: string): boolean;
function  DSiIsFileCompressedW(const fileName: WideString): boolean;
function  DSiKillFile         (const fileName: string): boolean;       // also handles LNK files with non-existing targets
function  DSiLoadMedia(deviceLetter: char): boolean;
function  DSiMoveFile(const srcName, destName: string; overwrite: boolean = true): boolean;
function  DSiMoveOnReboot(const srcName, destName: string): boolean;
procedure DSiRemoveFolder(const folder: string);
function  DSiRevertWow64FsRedirection(const oldStatus: pointer): boolean;
function  DSiSetFileTime (const fileName: string; dateTime: TDateTime; whatTime: TDSiFileTime): boolean;
function  DSiSetFileTimes(const fileName: string;
                          creationTime, lastAccessTime, lastModificationTime: TDateTime): boolean;
function  DSiShareFolder(const folder, shareName, comment: string): boolean;
function  DSiUncompressFile(fileHandle: THandle): boolean;
function  DSiUnShareFolder(const shareName: string): boolean;
```

---

## { Processes }

```pascal
// Window-station/desktop ACEs (used by DSiExecuteAsUser)
function  DSiAddAceToDesktop(desktop: HDESK; sid: PSID): boolean;
function  DSiAddAceToWindowStation(station: HWINSTA; sid: PSID): boolean;
function  DSiRemoveAceFromDesktop(desktop: HDESK; sid: PSID): boolean;
function  DSiRemoveAceFromWindowStation(station: HWINSTA; sid: PSID): boolean;

// Affinity (handles up to 64 cores in 64-bit mode)
function  DSiAffinityMaskToString(affinityMask: DSiNativeUInt): string;
function  DSiGetProcessAffinity: string;             function  DSiGetProcessAffinityMask: DSiNativeUInt;
function  DSiGetSystemAffinity: string;              function  DSiGetSystemAffinityMask: DSiNativeUInt;
function  DSiGetSystemECoreAffinity: string;         function  DSiGetSystemECoreAffinityMask: DSiNativeUInt;
function  DSiGetSystemPCoreAffinity: string;         function  DSiGetSystemPCoreAffinityMask: DSiNativeUInt;
function  DSiGetThreadAffinity: string;              function  DSiGetThreadAffinityMask: DSiNativeUInt;
function  DSiSetProcessAffinity(const affinity: string): string;
function  DSiSetThreadAffinity (const affinity: string): string;
function  DSiStringToAffinityMask        (const affinity: string): DSiNativeUInt;
function  DSiValidateProcessAffinity     (const affinity: string): string;
function  DSiValidateProcessAffinityMask (affinityMask: DSiNativeUInt): DSiNativeUInt;
function  DSiValidateThreadAffinity      (const affinity: string): string;
function  DSiValidateThreadAffinityMask  (affinityMask: DSiNativeUInt): DSiNativeUInt;

function  DSiGetCurrentProcessHandle: THandle;
function  DSiGetCurrentThreadHandle: THandle;
function  DSiEnablePrivilege(const privilegeName: string): boolean;

// Execute external commands
function  DSiExecute(const commandLine: string; visibility: integer = SW_SHOWDEFAULT;
            const workDir: string = ''; wait: boolean = false): cardinal; overload;
function  DSiExecute(const commandLine: string; var processInfo: TProcessInformation;
            visibility: integer = SW_SHOWDEFAULT; const workDir: string = '';
            creationFlags: DWORD = CREATE_NEW_CONSOLE or NORMAL_PRIORITY_CLASS;
            stdIn: THandle = 0): cardinal; overload;
function  DSiExecuteAndCapture(const app: string; output: TStrings; const workDir: string;
            var exitCode: longword; waitTimeout_sec: integer = 15;
            onNewLine: TDSiOnNewLineCallback = nil;
            creationFlags: DWORD = CREATE_NEW_CONSOLE or NORMAL_PRIORITY_CLASS;
            const abortHandle: THandle = 0;
            terminateTimeout: DWORD = INFINITE;
            onProcessCreated: TDSiProcessCreatedEvent = nil;
            consoleCodePage: integer = CP_OEMCP;
            environment: pointer = nil): cardinal;
function  DSiExecuteAsAdmin(const path: string; const parameters: string = '';
            const directory: string = ''; parentWindow: THandle = 0;
            showWindow: integer = SW_NORMAL; wait: boolean = false): boolean;
function  DSiExecuteAsUser(const commandLine, username, password: string;
            var winErrorCode: cardinal; const domain: string = '.';
            visibility: integer = SW_SHOWDEFAULT; const workDir: string = '';
            wait: boolean = false): cardinal; overload;
function  DSiExecuteAsUser(const commandLine, username, password: string;
            var winErrorCode: cardinal; var processInfo: TProcessInformation;
            const domain: string = '.'; visibility: integer = SW_SHOWDEFAULT;
            const workDir: string = ''; wait: boolean = false;
            startInfo: PStartupInfo = nil): cardinal; overload;
function  DSiExecuteInSession(sessionID: DWORD; const commandLine: string;
            var processInfo: TProcessInformation; const workDir: string = ''): boolean;

// Process inspection / control
function  DSiGetProcessID(const processName: string; var processID: DWORD): boolean;
function  DSiGetProcessMemory(var memoryCounters: TProcessMemoryCounters): boolean; overload;
function  DSiGetProcessMemory(process: THandle; var memoryCounters: TProcessMemoryCounters): boolean; overload;
function  DSiGetProcessFileName(process: THandle; var processName: string): boolean;
function  DSiGetProcessOwnerInfo(const processName: string; var user, domain: string): boolean; overload;
function  DSiGetProcessOwnerInfo(processID: DWORD; var user, domain: string): boolean; overload;
function  DSiGetProcessTimes(var creationTime: TDateTime; var userTime, kernelTime: int64): boolean; overload;
function  DSiGetProcessTimes(process: THandle; var creationTime, exitTime: TDateTime;
                              var userTime, kernelTime: int64): boolean; overload;

// Thread inspection
function  DSiGetThreadContext(thread: THandle; var context: TContext;
                              contextFlags: DWORD = CONTEXT_FULL): boolean;
function  DSiGetThreadTime: int64; overload;
function  DSiGetThreadTime(thread: THandle): int64; overload;
function  DSiGetThreadTimes(var creationTime: TDateTime; var userTime, kernelTime: int64): boolean; overload;
function  DSiGetThreadTimes(thread: THandle; var creationTime, exitTime: TDateTime;
                            var userTime, kernelTime: int64): boolean; overload;

// Impersonation
function  DSiImpersonateUser(const username, password: string; const domain: string = '.'): boolean;
function  DSiLogonAs(const username, password: string;          var logonHandle: THandle): boolean; overload;
function  DSiLogonAs(const username, password, domain: string;  var logonHandle: THandle): boolean; overload;
procedure DSiStopImpersonatingUser;

// Misc process helpers
function  DSiIncrementWorkingSet(incMinSize, incMaxSize: integer): boolean;
function  DSiIsDebugged: boolean;
function  DSiOpenURL(const URL: string; newBrowser: boolean = false): boolean;   // opens a URL in the default (or a new) browser via ShellExecute
procedure DSiProcessThreadMessages;
function  DSiRealModuleName: string;
function  DSiSetProcessPriorityClass(const processName: string; priority: DWORD): boolean;
function  DSiTerminateProcessById(processID: DWORD; closeWindowsFirst: boolean = true;
            maxWait_sec: integer = 10): boolean;
procedure DSiTrimWorkingSet;
procedure DSiYield;
```

> **Opening a URL at runtime** (as opposed to creating a shortcut to one - see `DSiCreateURLShortcut` under `{ Install }`) is `DSiOpenURL`, a thin `ShellExecute` wrapper.

---

## { Memory }

```pascal
procedure DSiFreePidl(pidl: PItemIDList);
procedure DSiFreeMemAndNil(var mem: pointer);
function  DSiGetGlobalMemoryStatus(var memoryStatus: TMemoryStatusEx): boolean;
```

---

## { Windows }

```pascal
TDSiExitWindows = (ewLogOff, ewForcedLogOff, ewPowerOff, ewForcedPowerOff,
                   ewReboot, ewForcedReboot, ewShutdown, ewForcedShutdown);

// Thread-safe (de)allocate hidden message-only windows
function  DSiAllocateHWnd(wndProcMethod: TWndMethod;
            style: cardinal = WS_EX_TOOLWINDOW OR WS_EX_NOACTIVATE;
            parentWindow: HWND = HWND_MESSAGE): HWND;
procedure DSiDeallocateHWnd(wnd: HWND);

function  DSiDisableStandby: boolean;        // Win XP SP2+
procedure DSiDisableX(hwnd: THandle);        procedure DSiEnableX(hwnd: THandle);
function  DSiExitWindows(exitType: TDSiExitWindows): boolean;
function  DSiFindWindow(const caption: string; const wndClass: string = ''): HWND;
function  DSiForceForegroundWindow(hwnd: THandle; restoreFirst: boolean = true): boolean;
function  DSiGetClassName(hwnd: THandle): string;
function  DSiGetFocusedWindow: THandle;
function  DSiGetProcessWindow(targetProcessID: cardinal): HWND;
function  DSiGetWindowText(hwnd: THandle): string;
procedure DSiProcessMessages(hwnd: THandle; waitForWMQuit: boolean = false);
procedure DSiRebuildDesktopIcons;
procedure DSiRefreshDesktop;
procedure DSiSetTopMost(hwnd: THandle; onTop: boolean = true; activate: boolean = false);
```

---

## { Aero } / { Taskbar } / { Menus } / { Screen } / { Rectangles } / { Clipboard }

```pascal
// Aero (DWM)
function  DSiAeroDisable: boolean;
function  DSiAeroEnable: boolean;
function  DSiAeroIsEnabled: boolean;

// Taskbar
function  DSiGetTaskBarPosition: integer;

// Menus
function  DSiGetHotkey(const item: string): char;
function  DSiGetMenuItem(menu: HMENU; item: integer): string;

// Screen
procedure DSiDisableScreenSaver(out currentlyActive: boolean);
procedure DSiEnableScreenSaver;
function  DSiGetBitsPerPixel: integer;
function  DSiGetBPP: integer;
function  DSiGetDesktopSize: TRect;
function  DSiIsFullScreen: boolean;
procedure DSiMonitorOff;             procedure DSiMonitorOn;     procedure DSiMonitorStandby;
function  DSiSetScreenResolution(width, height: integer): longint;

// Rectangles
procedure DSiCenterRectInRect       (const ownerRect: TRect; var clientRect: TRect);
procedure DSiMakeRectFullyVisibleOnRect(const ownerRect: TRect; var clientRect: TRect);

// Clipboard (HTML format)
function  DSiIsHtmlFormatOnClipboard: boolean;
function  DSiGetHtmlFormatFromClipboard: string;
procedure DSiCopyHtmlFormatToClipboard(const sHtml: string; const sText: string = '');
```

---

## { Information }

### Enumerations

```pascal
TDSiBootType = (btNormal, btFailSafe, btFailSafeWithNetwork, btUnknown);

TDSiWindowsVersion = (wvUnknown, wvWin31, wvWin95, wvWin95OSR2, wvWin98, wvWin98SE, wvWinME,
  wvWin9x, wvWinNT3, wvWinNT4, wvWin2000, wvWinXP, wvWinNT, wvWinServer2003, wvWinVista,
  wvWinServer2008, wvWinServer2008OrVistaSP1, wvWin7, wvWinServer2008R2,
  wvWin7OrServer2008R2, wvWin8, wvWin81, wvWinServer2012, wvWinServer2012R2,
  wvWin10, wvWinServer2016, wvWin11, wvWinServer2022);

TDSiUIElement = (ueMenu, ueMessage, ueWindowCaption, ueStatus);

const CDSiWindowsVersionStr: array [TDSiWindowsVersion] of string = (...);
```

### OS / process info functions

```pascal
function  DSiGetAppCompatFlags(const exeName: string): string;
function  DSiGetBootType: TDSiBootType;
function  DSiGetCompanyName: string;
function  DSiGetComputerName: string;
function  DSiGetDefaultBrowser: string;
function  DSiGetDirectXVer: string;
function  DSiGetDiskLabel(disk: char): string;
function  DSiGetDiskSerial(disk: char): string;
function  DSiGetDomain: string;
function  DSiGetEnvironmentVariable(const envVarName: string): string;
function  DSiGetFolderLocation(const CSIDL: integer): string;
procedure DSiGetKeyboardLayouts(layouts: TStrings);
function  DSiGetLogicalProcessorInfo  (var info: TSystemLogicalProcessorInformationArr):    boolean;
function  DSiGetLogicalProcessorInfoEx(relationshipType: TLogicalProcessorRelationship;
                                       var info: TSystemLogicalProcessorInformationExArr):  boolean;
function  DSiGetMyDocumentsFolder: string;
function  DSiGetProgramFilesFolder: string;
function  DSiGetRegisteredOwner: string;
function  DSiGetSystemFolder: string;
function  DSiGetSystemLanguage: string;
function  DSiGetSystemVersion: string;
function  DSiGetTrueWindowsVersion: TDSiWindowsVersion;     // bypasses app-compat shimming
function  DSiGetUserName: string;
function  DSiGetUserNameEx: string;
function  DSiGetWindowsFolder: string;
function  DSiGetWindowsVersion: TDSiWindowsVersion;
function  DSiHasRoamingProfile(var userHasRoamingProfile: boolean): boolean;
function  DSiIsAdmin: boolean;
function  DSiIsAdminLoggedOn: boolean;
function  DSiIsCodeSigned(const exeFileName: string; var certName: AnsiString): boolean;
function  DSiIsDiskInDrive(disk: char): boolean;
function  DSiIsWinNT: boolean;
function  DSiIsWow64: boolean;
function  DSiVerifyPassword(const username, password: string; const domain: string = '.'): boolean;
```

(This section also declares `OSVERSIONINFOEX*`, `STARTUPINFOW`, `LOGICAL_PROCESSOR_RELATIONSHIP`, `CACHE_DESCRIPTOR`, `SYSTEM_LOGICAL_PROCESSOR_INFORMATION[_EX]`, `GROUP_AFFINITY`, `PROCESSOR_RELATIONSHIP`, `NUMA_NODE_RELATIONSHIP`, `CACHE_RELATIONSHIP`, `GROUP_RELATIONSHIP`, `PROCESSOR_GROUP_INFO` for older Delphis. WinTrust types: `TWinTrustFileInfo`, `TWinTrustData`, `WINTRUST_ACTION_GENERIC_VERIFY_V2`, `WTD_*`. Crypt32 types: `CRYPT_VERIFY_MESSAGE_PARA`, `PCCERT_CONTEXT`.)

---

## { Install }

Shortcuts, autorun/RunOnce entries, uninstall registration, firewall exception lists, and related SID helpers.

### Firewall types

```pascal
TDSiFwIPProtocol  = (fwProtoTCP, fwProtoUDP);
TDSiFwIPProtocols = set of TDSiFwIPProtocol;
TDSiFwIPProfile   = (fwProfileDomain, fwProfilePrivate, fwProfilePublic, fwProfileAll, fwProfileCurrent);
TDSiFwIPProfiles  = set of TDSiFwIPProfile;
TDSiFwResolveConflict = (rcDuplicate, rcOverwrite, rcSkip);
```

### Shortcuts (`.lnk`, `.url`)

```pascal
procedure DSiCreateShortcut(const fileName, displayName, parameters: string;
            folder: integer = CSIDL_STARTUP; const workDir: string = '');
procedure DSiCreateURLShortcut(const url, displayName: string;
            folder: integer = CSIDL_STARTUP);
function  DSiDeleteShortcut(const displayName: string; folder: integer = CSIDL_STARTUP): boolean;
procedure DSiEditShortcut(const lnkName, fileName, workDir, parameters: string);
function  DSiGetShortcutInfo(const lnkName: string;
            var fileName, filePath, workDir, parameters: string): boolean;
function  DSiShortcutExists(const displayName: string; folder: integer = CSIDL_STARTUP): boolean;
```

- `DSiCreateShortcut` creates a classic file-system shortcut (`.lnk`, via `IShellLink`/`IPersistFile`) pointing at an executable, with optional arguments and working directory. `folder` is a `CSIDL_*` constant identifying the destination special folder (e.g. `CSIDL_STARTUP` for the Startup folder, `CSIDL_DESKTOPDIRECTORY` for the current user's desktop, `CSIDL_COMMON_DESKTOPDIRECTORY` for the all-users desktop). The icon is set to the target executable's own icon; `displayName` becomes the `.lnk` file name (extension `CLinkExt = '.lnk'` appended automatically).
- `DSiCreateURLShortcut` *(added 2.17)* creates an **Internet Shortcut** (`.url`) that opens `url` in the default browser - a different, plain-text INI-style file format ( `[InternetShortcut]` / `URL=...`), not a `.lnk`/`IShellLink` object, since `IShellLink.SetPath` is meant for file-system targets rather than URLs. `displayName` becomes the file name (extension `CURLShortcutExt = '.url'` appended automatically); `folder` uses the same `CSIDL_*` convention as `DSiCreateShortcut`. Raises on failure with the underlying OS error code/message.
- `DSiDeleteShortcut` / `DSiShortcutExists` operate on `.lnk` files only (via `CLinkExt`), keyed by `displayName` + `folder`.
- `DSiEditShortcut` / `DSiGetShortcutInfo` read/modify an existing `.lnk` file given its full path.

```pascal
DSiCreateShortcut('C:\MyApp\MyApp.exe', 'My App', '', CSIDL_DESKTOPDIRECTORY, 'C:\MyApp');
DSiCreateURLShortcut('https://example.com', 'My Site', CSIDL_DESKTOPDIRECTORY);
```

### Firewall exception list

```pascal
function  DSiAddApplicationToFirewallExceptionList(const entryName, applicationFullPath: string;
            resolveConflict: TDSiFwResolveConflict = rcDuplicate;
            const description: string = ''; const grouping: string = '';
            const serviceName: string = ''; protocols: TDSiFwIPProtocols = [fwProtoTCP];
            const localPorts: string = '*'; profiles: TDSiFwIPProfiles = [fwProfileAll]): boolean;
function  DSiAddApplicationToFirewallExceptionListAdvanced(...): boolean;    // same params; Vista+
function  DSiAddApplicationToFirewallExceptionListXP(const entryName, applicationFullPath: string;
            resolveConflict: TDSiFwResolveConflict = rcDuplicate;
            profile: TDSiFwIPProfile = fwProfileCurrent): boolean;
function  DSiAddPortToFirewallExceptionList(const entryName: string; portNumber: cardinal): boolean;

function  DSiFindApplicationInFirewallExceptionListAdvanced(const entryName: string;
                                                              var rule: OleVariant): boolean;
function  DSiFindApplicationInFirewallExceptionListXP(const entryName: string;
            var application: OleVariant; profile: TDSiFwIPProfile = fwProfileCurrent): boolean;
function  DSiRemoveApplicationFromFirewallExceptionList        (const entryName, applicationFullPath: string): boolean;
function  DSiRemoveApplicationFromFirewallExceptionListAdvanced(const entryName: string): boolean;
function  DSiRemoveApplicationFromFirewallExceptionListXP      (const applicationFullPath: string): boolean; overload;
function  DSiRemoveApplicationFromFirewallExceptionListXP      (const applicationFullPath: string;
            profile: TDSiFwIPProfile): boolean; overload;
```

### Autorun / RunOnce / uninstall info / SIDs

```pascal
function  DSiAddUninstallInfo(const displayName, uninstallCommand, publisher,
            URLInfoAbout, displayVersion, helpLink, URLUpdateInfo: string): boolean;
function  DSiAutoRunApp(const applicationName, applicationPath: string; enabled: boolean = true): boolean;
function  DSiIsAutoRunApp(const applicationname: string): boolean;
function  DSiGetLogonSID(token: THandle; var logonSID: PSID): boolean;
function  DSiGetProcessSID(var sid: string): boolean;
function  DSiGetUninstallInfo(const displayName: string; out uninstallCommand: string): boolean;
function  DSiRegisterActiveX(const fileName: string; registerDLL: boolean): HRESULT;
procedure DSiRegisterRunOnce(const applicationName, applicationPath: string);
procedure DSiRemoveRunOnce(const applicationName: string);
function  DSiRemoveUninstallInfo(const displayName: string): boolean;
```

(Section also defines `NET_FW_*` constants for IP protocols, versions, scopes, profiles, actions, etc.)

---

## { Time }

### Process-wide state

- **Timer resolution.** The unit initialization calls `timeBeginPeriod(1)` and the finalization `timeEndPeriod(1)`, so every process that uses DSiWin32 runs with a 1 ms system timer resolution (this is what makes `timeGetTime`, `Sleep(1)` and short timeouts precise). It also keeps the CPU from idling in deep power states. Define `DSiNoTimerResolution` (project options or `-D`) to skip both calls; `Sleep(1)` and timeouts of a few milliseconds are then rounded up to the system timer tick (about 15.6 ms). The default is unchanged.
- **Global critical sections.** `GDSiWndHandlerCritSect` (used by `DSiAllocateHwnd`/`DSiDeallocateHwnd`) and `GDSiTimeGetTime64Safe` (used by `DSiTimeGetTime64`) are **not** deleted at finalization (2.18): a thread that outlives the unit, such as an OmniThreadLibrary thread pool maintenance timer, can still call those routines during shutdown. The OS reclaims the critical sections at process exit.
- **Library list.** `DSiLoadLibrary`/`DSiGetProcAddress` keep the loaded libraries in a list protected by a critical section. At finalization `DSiUnloadLibrary` frees the libraries and zeroes their handles (a late caller gets 0/nil), and in a **DLL** (`IsLibrary`) the list and its lock are destroyed; in an **executable** they are kept until the process exits, because a thread that outlives the unit may still be inside those routines (2.18a). The list is allocated on the process heap rather than by the Delphi memory manager, so keeping it in an executable is not reported as a leak at shutdown (2.18b).
- **C++Builder.** Constants that are macros in the Windows SDK headers (`FILE_ANY_ACCESS`, `METHOD_BUFFERED`, `IOCTL_STORAGE_*`, `FSCTL_SET_COMPRESSION`, `SC_MINIMIZE`, `SC_MAXIMIZE`, `ERROR_REQUEST_ABORTED`, `ERROR_REQUEST_PAUSED`, `THREAD_*`) are marked `{$EXTERNALSYM}`, so they are not written into `DSiWin32.hpp`; C++ code uses the SDK definitions.

### `TDSiTimer`

`TTimer` clone using `DSiAllocateHwnd` / `DSiDeallocateHwnd` instead of Delphi's `AllocateHwnd`/`DeallocateHwnd`. Intended to be dynamically created in worker threads (not a `TComponent` descendant). Re-entrancy in `OnTimer` is prevented as of 2.16 (guards against the handler re-entering itself if it pumps messages).

```pascal
constructor Create(enabled: boolean = true; interval: cardinal = 1000;
                   onTimer: TNotifyEvent = nil; tag: longint = 0);
property Enabled:  boolean read dtEnabled write SetEnabled default true;
property Interval: cardinal read dtInterval write SetInterval default 1000;
property Tag:      longint read dtTag write dtTag;
property OnTimer:  TNotifyEvent read dtOnTimer write SetOnTimer;
```

### Functions

```pascal
// Based on GetTickCount (lower precision, beware wraparound) - note the leading underscore
function  _DSiElapsedSince(midTime, startTime: int64): int64;
function  _DSiElapsedTime(startTime: int64): int64;
function  _DSiHasElapsed(startTime: int64; timeout_ms: DWORD): boolean;

// Based on timeGetTime (millisecond precision)
function  DSiTimeGetTime64: int64;
function  DSiElapsedTime64(startTime: int64): int64;
function  DSiHasElapsed64(startTime: int64; timeout_ms: DWORD): boolean;

// FileTime conversions
function  DSiDateTimeToFileTime(dateTime: TDateTime; var fileTime: TFileTime): boolean;
function  DSiFileTimeToDateTime(fileTime: TFileTime): TDateTime; overload;
function  DSiFileTimeToDateTime(fileTime: TFileTime; var dateTime: TDateTime): boolean; overload;
function  DSiFileTimeToMicroSeconds(fileTime: TFileTime): int64;

// Performance counters
function  DSiPerfCounterToMS(perfCounter: int64): int64;
function  DSiPerfCounterToUS(perfCounter: int64): int64;
function  DSiQueryPerfCounterAsUS: int64;
procedure DSiuSecDelay(delay: int64);

function  DSiGetSystemTimePreciseAsFileTime(var fileTime: TFileTime): boolean;
```

> **Naming caveat** (since 2.10): the `_DSi*` functions are `GetTickCount`-based; the `DSi*64` functions are `timeGetTime`-based. Don't mix values from the two families - the leading underscore on `_DSi*` is intentional, to make the distinction visible at call sites. `GpTimestamp.pas` wraps the `timeGetTime`-based `DSiTimeGetTime64` as one of its cross-checked time sources (`tsTimeGetTime`) - prefer `TGpTimestamp` over calling these directly when type-safety across timebases matters.

---

## { Interlocked } - 64-bit interlocked ops

```pascal
function  DSiInterlockedDecrement64    (var addend: int64): int64;
function  DSiInterlockedIncrement64    (var addend: int64): int64;
function  DSiInterlockedExchangeAdd64  (var addend: int64; value: int64): int64;
function  DSiInterlockedExchange64     (var target: int64; value: int64): int64;
function  DSiInterlockedCompareExchange64(var destination: int64; exchange, comparand: int64): int64; overload;
function  DSiInterlockedCompareExchange64(destination: PInt64; exchange, comparand: int64): int64; overload;
```

---

## { DynaLoad } - dynamically-loaded forwarders

These wrap APIs that may not exist on every Windows version. They auto-load the corresponding DLL (`ws2_32`, `crypt32`, `wintrust`, `imagehlp`, `kernel32`, `psapi`, `userenv`, `wtsapi32`, ...) and call the real function, or return a sensible failure if the DLL/entry point isn't present.

```pascal
function  DSi9xNetShareAdd(serverName: PChar; shareLevel: smallint; buffer: pointer; size: word): integer; stdcall;
function  DSi9xNetShareDel(serverName: PChar; netName: PChar; reserved: word): integer; stdcall;

function  DSiCertCreateCertificateContext(dwCertEncodingType: DWORD;
            pbCertEncoded: PBYTE; cbCertEncoded: DWORD): PCCERT_CONTEXT; stdcall;
function  DSiCertFreeCertificateContext(pCertContext: PCCERT_CONTEXT): BOOL; stdcall;
function  DSiCertGetNameStringA(pCertContext: PCCERT_CONTEXT; dwType, dwFlags: DWORD;
            pvTypePara: Pointer; pszNameString: PAnsiChar; cchNameString: DWORD): DWORD; stdcall;
function  DSiCloseServiceHandle(hSCObject: SC_HANDLE): BOOL; stdcall;

// CopyFile2 family (Win 8+)
function  DSiCopyFile2(pwszExistingFileName, pwszNewFileName: PChar;
            pExtendedParameters: PCOPYFILE2_EXTENDED_PARAMETERS): HRESULT; stdcall;

function  DSiCreateProcessAsUser(hToken: THandle; lpApplicationName, lpCommandLine: PChar;
            lpProcessAttributes, lpThreadAttributes: PSecurityAttributes;
            bInheritHandles: BOOL; dwCreationFlags: DWORD; lpEnvironment: pointer;
            lpCurrentDirectory: PChar; const lpStartupInfo: TStartupInfo;
            var lpProcessInformation: TProcessInformation): BOOL; stdcall;
function  DSiCreateProcessWithLogonW(lpUsername, lpDomain, lpPassword: PWideChar;
            dwLogonFlags: DWORD; lpApplicationName, lpCommandLine: PWideChar;
            dwCreationFlags: DWORD; lpEnvironment: pointer; lpCurrentDirectory: PWideChar;
            const lpStartupInfo: TStartupInfoW; var lpProcessInformation: TProcessInformation): BOOL;
function  DSiCreateEnvironmentBlock (var lpEnvironment: pointer; hToken: THandle; bInherit: BOOL): BOOL;
function  DSiDestroyEnvironmentBlock(lpEnvironment: pointer): BOOL;

function  DSiCryptVerifyMessageSignature(const pVerifyPara: CRYPT_VERIFY_MESSAGE_PARA;
            dwSignerIndex: DWORD; pbSignedBlob: PByte; cbSignedBlob: DWORD;
            pbDecoded: PBYTE; pcbDecoded: PDWORD; ppSignerCert: PCCERT_CONTEXT): BOOL; stdcall;

// DWM (Aero composition)
function  DSiDwmEnableComposition(uCompositionAction: UINT): HRESULT; stdcall;     // DWM_EC_DISABLECOMPOSITION = 0; DWM_EC_ENABLECOMPOSITION = 1
function  DSiDwmIsCompositionEnabled(var pfEnabled: BOOL): HRESULT; stdcall;

// Process enumeration (PSAPI)
function  DSiEnumProcesses     (lpidProcess: PDWORD; cb: DWORD; var lpcbNeeded: DWORD): BOOL; stdcall;
function  DSiEnumProcessModules(hProcess: THandle; lphModule: PModule; cb: DWORD;
                                  var lpcbNeeded: DWORD): BOOL; stdcall;

// CPU topology
function  DSiGetLogicalProcessorInformation(
            pBuffer: PSYSTEM_LOGICAL_PROCESSOR_INFORMATION; var ReturnLength: DWORD): BOOL; stdcall;
function  DSiGetLogicalProcessorInformationEx(
            RelationshipType: LOGICAL_PROCESSOR_RELATIONSHIP;
            Buffer: PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX;
            var ReturnedLength: DWORD): BOOL; stdcall;
function  DSiGetNumaHighestNodeNumber(var HighestNodeNunber: ULONG): BOOL; stdcall;
function  DSiGetNumaProximityNodeEx  (ProximityId: ULONG; var NodeNumber: USHORT): BOOL; stdcall;
function  DSiGetSystemFirmwareTable(FirmwareTableProviderSignature, FirmwareTableID: DWORD;
            pFirmwareTableBuffer: pointer; BufferSize: DWORD): UInt; stdcall;
function  DSiGetThreadGroupAffinity(hThread: THandle; var GroupAffinity: TGroupAffinity): BOOL; stdcall;
function  DSiSetThreadGroupAffinity(hThread: THandle; const GroupAffinity: TGroupAffinity;
                                    PreviousGroupAffinity: PGroupAffinity): BOOL; stdcall;

// Thread description (Win 10+)
function  DSiGetThreadDescription(hThread: THandle; var threadDescription: PWideChar): HRESULT; stdcall;
function  DSiSetThreadDescription(hThread: THandle; threadDescription: PWideChar): HRESULT; stdcall;
function  DSiOpenThread(dwDesiredAccess: DWORD; bInheritHandle: BOOL; dwThreadId: DWORD): THandle; stdcall;

function  DSiGetModuleFileNameEx     (hProcess: THandle; hModule: HMODULE; lpFilename: PChar; nSize: DWORD): DWORD; stdcall;
function  DSiGetProcessImageFileName (hProcess: THandle; lpImageFileName: PChar; nSize: DWORD): DWORD; stdcall;
function  DSiGetProcessMemoryInfo(process: THandle; memCounters: PProcessMemoryCounters; cb: DWORD): boolean; stdcall;
function  DSiGetProcAddress(const libFileName, procName: string): FARPROC;       // public dyna-load helper
// DSiLoadLibrary, DSiGetProcAddress and DSiUnloadLibrary are thread-safe (the library list is guarded by a critical section created on first use)
function  DSiGetTickCount64: int64; stdcall;
function  DSiGetUserProfileDirectoryW(hToken: THandle; lpProfileDir: PWideChar; var lpcchSize: DWORD): BOOL; stdcall;
function  DSiGlobalMemoryStatusEx(memStatus: PMemoryStatusEx): boolean; stdcall;

// Image / signature verification (imagehlp / wintrust)
function  DSiImageEnumerateCertificates(FileHandle: THandle; TypeFilter: WORD;
            out CertificateCount: DWORD; Indices: PDWORD; IndexCount: Integer): BOOL; stdcall;
function  DSiImageGetCertificateData(FileHandle: THandle; CertificateIndex: Integer;
            Certificate: PWinCertificate; var RequiredLength: DWORD): BOOL; stdcall;
function  DSiImageGetCertificateHeader(FileHandle: THandle; CertificateIndex: Integer;
            var CertificateHeader: TWinCertificate): BOOL; stdcall;
function  DSiWinVerifyTrust(hwnd: HWND; const ActionID: TGUID; ActionData: Pointer): Longint; stdcall;

function  DSiImpersonateLoggedOnUser(hToken: THandle): BOOL; stdcall;
function  DSiIsWow64Process(hProcess: THandle; var wow64Process: BOOL): BOOL; stdcall;
function  DSiLogonUser(lpszUsername, lpszDomain, lpszPassword: PChar;
                       dwLogonType, dwLogonProvider: DWORD; var phToken: THandle): BOOL; stdcall;

// Net APIs
function  DSiNetApiBufferFree(buffer: pointer): cardinal; stdcall;
function  DSiNetWkstaGetInfo (servername: PChar; level: cardinal; out bufptr: pointer): cardinal; stdcall;
function  DSiNTNetShareAdd(serverName: PChar; level: integer; buf: PChar; var parm_err: integer): DWord; stdcall;
function  DSiNTNetShareDel(serverName: PChar; netName: PWideChar; reserved: integer): DWord; stdcall;

function  DSiOpenSCManager(lpMachineName, lpDatabaseName: PChar; dwDesiredAccess: DWORD): SC_HANDLE; stdcall;
function  DSiRevertToSelf: BOOL; stdcall;
function  DSiSetDllDirectory(path: PChar): boolean; stdcall;
function  DSiSetSuspendState(hibernate: BOOL; forceCritical: BOOL = false;
                              disableWakeEvent: BOOL = false): BOOL; stdcall;
function  DSiSHEmptyRecycleBin(Wnd: HWND; pszRootPath: PChar; dwFlags: DWORD): HRESULT; stdcall;

// Wow64 redirection control
function  DSiWow64DisableWow64FsRedirection(var oldStatus: pointer): BOOL; stdcall;
function  DSiWow64RevertWow64FsRedirection (const oldStatus: pointer): BOOL; stdcall;

// Terminal Services session token
function  DSiWTSQueryUserToken(sessionId: ULONG; var phToken: THandle): BOOL; stdcall;
```

---

## { Helpers }

```pascal
function  DSiWin32FromHresult(hr: HRESULT): DWORD;     // reverse of Winapi.Windows.HResultFromWin32

// Old-Delphi UTF8 helpers (only when DSiNeedUTF is defined)
function UTF8Encode(const ws: WideString): UTF8String;
function UTF8Decode(const sUtf: UTF8String): WideString;
```

---

## When to Use What

- **Process spawning**: `DSiExecute` for fire-and-forget; `DSiExecuteAndCapture` to capture stdout/stderr (supports CR-, LF-, or CRLF-delimited output, abort handle, per-line callback, console code page, custom environment); `DSiExecuteAsAdmin` for elevation; `DSiExecuteAsUser` for impersonation (auto-falls back to `CreateProcessWithLogonW` if needed); `DSiExecuteInSession` to run interactively in a specific session (e.g. from a session-0 service).
- **Affinity**: prefer `DSiGetSystemPCoreAffinityMask` / `DSiGetSystemECoreAffinityMask` on Intel hybrid CPUs to schedule work onto P-cores or E-cores specifically.
- **File enumeration**: `DSiEnumFilesEx` with an anonymous-method callback is the modern path; the `errorCallback` overload reports unexpected errors as they occur; `DSiEnumFilesToOL` returns a `TObjectList` of `TDSiFileInfo` for callers that prefer a materialized list over a callback.
- **Shortcuts**: `DSiCreateShortcut` for `.lnk` shortcuts to executables/files; `DSiCreateURLShortcut` for `.url` shortcuts to web addresses - don't try to point `DSiCreateShortcut` at a URL, it builds an `IShellLink`/`IPersistFile` object meant for file-system targets.
- **Time measurement**: use the `DSi*64` family (`timeGetTime`-based, millisecond precision) or `DSiQueryPerfCounterAsUS` for sub-millisecond precision; the `_DSi*` underscore family is `GetTickCount`-based with worse precision and wraparound risk - don't mix values between the two families. For type-safe cross-timebase arithmetic, prefer `TGpTimestamp` (`GpTimestamp.pas`), which wraps `DSiTimeGetTime64` as one of its sources.
- **Registry**: prefer `TDSiRegistry` (`ReadInt64`, MULTI_SZ helpers via `ReadStrings`/`WriteStrings`, a `ReadInteger` that tolerantly accepts strings and 4-byte binary). Pass the `KEY_WOW64_64KEY` access flag when explicitly addressing the 64-bit hive from a 32-bit process on a 64-bit OS.
- **Opening a URL**: `DSiOpenURL` launches the default (or a new) browser immediately; `DSiCreateURLShortcut` instead persists a `.url` file for later use (e.g. on the desktop or Start Menu).

## Version History

Full history lives in the unit's own header comment (`dsiwin32.pas`, top of file); this is a condensed excerpt of recent entries.

- **2.18d** (2026-10-30): `DSiCreateShortcut`, `DSiEditShortcut` and `DSiGetShortcutInfo` create the shell link with `IID_IShellLinkW` on Unicode Delphi (they used `IID_IShellLinkA` with the Unicode `IShellLink`, which returned garbage from `DSiGetShortcutInfo`).
- **2.18c** (2026-10-21): `DSiFileExistsW` and `DSiDirectoryExistsW` no longer raise `ERangeError` for a missing file when compiled with range checking (`$R+`).
- **2.18b** (2026-10-12): The library list used by `DSiLoadLibrary`/`DSiGetProcAddress` is allocated on the process heap, so FastMM no longer reports it as a leak at shutdown.
- **2.18a** (2026-10-09): A thread that outlives the unit finalization can no longer crash in `DSiLoadLibrary`/`DSiGetProcAddress`: in an executable the library list and its lock are kept until the process exits (in a DLL they are destroyed as before).
- **2.18** (2026-10-09): New define `DSiNoTimerResolution` skips `timeBeginPeriod(1)` (see *Process-wide state* in the Time section). Fixed an access violation in `DSiTimeGetTime64`/`DSiAllocateHwnd` when called by a thread that outlives the unit finalization (the global critical sections are no longer deleted). Constants that are Windows SDK macros are `EXTERNALSYM`-marked so that the generated C++Builder header compiles (OTL issue #72).
- **2.17a** (2026-10-09): `DSiLoadLibrary`, `DSiGetProcAddress` and `DSiUnloadLibrary` are thread-safe (concurrent first calls could corrupt the library list or load a library twice).
- **2.17** (2026-09-09): Implemented `DSiCreateURLShortcut`, creating an Internet Shortcut (`.url`) file pointing to a URL.
- **2.16a** (2026-05-06): Removed `GInterlockedCompareExchange64` - it was not initialized correctly and was not used anywhere.
- **2.16** (2026-03-23 / 2026-03-18): Restored compatibility with D2007+. Implemented `DSiGetThreadDescription`/`DSiSetThreadDescription` wrappers. Prevented `TDSiTimer.OnTimer` re-entrancy.
- **2.15** (2026-02-16): Added thread-specific access rights constants. Implemented `DSiOpenThread`.
- **2.14** (2026-02-11): Implemented `DSiCopyFileRestartable` (restartable `CopyFile2` wrapper).
- **2.13** (2026-02-10): Implemented `DSiWin32FromHresult`, a reverse of `Winapi.Windows.HResultFromWin32`.
- **2.12** (2026-02-09): Implemented `DSiCopyFile2` and its declarations.
- **2.11** (2025-11-05): Fixed and implemented `DSiGetLogicalProcessorInfoEx`; added P-core/E-core affinity helpers.
- **2.10** (2025-05-06): ***Breaking change*** - renamed `GetTickCount`-based time functions to their `_DSi*`-prefixed forms (`_DSiElapsedSince`, `_DSiElapsedTime`, `_DSiHasElapsed`) to reduce accidental mixing with `timeGetTime`-based functions.

## License

Free for personal and commercial use. No rights reserved.
