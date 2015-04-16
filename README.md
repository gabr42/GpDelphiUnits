# GpDelphiUnits

Collection of my open sourced Delphi units.

Contains following units:

## DSiWin32

Collection of Win32/Win64 wrappers and helper functions.

## GpAutoCreate

Parent class that automatically creates/destroys fields in derived classes that are marked with a `[GpManaged]` attribute.

[more info](http://www.thedelphigeek.com/2012/10/automagically-creating-object-fields.html)

## GpCommandLineParser

Attribute based command line parser.

[more info](http://www.thedelphigeek.com/2014/12/attribute-based-command-line-parsing.html)

## GpForm

A simple form with some enhancements.

## GpHttp

Asynchronous HTTP GET/POST with ICS and OmniThreadLibrary.

## GpHugeF

Interface to 64-bit file functions with some added functionality.

## GpLists

Various TList descendants, TList-compatible, and TList-similar classes.

## GpLockFreeQueue

Sample implementation of a dynamically allocated, O(1) enqueue and dequeue, threadsafe, microlocking queue.

[more info](http://www.thedelphigeek.com/2010/02/dynamic-lock-free-queue-doing-it-right.html)

## GpManagedClass

Smarter base class. Handles error codes, has precondition and postcondition checker.

## GpProperty

Simplified access to the published properties.

## GpQueueExec

Queue anonymous procedure to a hidden window executing in a main thread.

## GpRandomGen

RANMAR pseudo-random number generator.

## GpSafeWS

Improved TWinSocketStream.

## GpSecurity

Windows NT security wrapper.

## GpSharedEvents

Distributed multicast event manager - object and component wrapper.

## GpSharedMemory

Shared memory implementation.

## GpStreamWrapper

Some useful stream wrappers.

## GpStreams

TStream descendants, TStream compatible classes and TStream helpers.

## GpStringHash

Preallocated hasher.

## GpStructuredStorage

Structured storage (compound file; file system inside a file) implementation.

[more info](http://www.thedelphigeek.com/2006/09/writing-embedded-file-system.html)
[implementation details](http://www.thedelphigeek.com/2006/09/gpstructuredstorage-internals.html)

## GpStuff

Various stuff with no other place to go.

## GpSync

Enhanced synchronisation primitives.

## GpSysHook

Main unit for the GpSysHookDLL. Implements system-wide keyboard, mouse,
shell, and CBT hooks. Supports multiple listeners, automatic unhooking on
process detach, and only installs the hooks that are needed. Supports
notification listeners and filter listeners (should be used with care because
SendMessage used for filtering can effectively block the whole system if
listener is not processing messages). Each listener can only listen to one
hook because hook code is sent as a message ID. All internal IDs are
generated from the module name so you only have to rename the DLL to make it
peacefully coexist with another GpSysHookDLL DLL.

## GpTextFile

Interface to 8/16-bit text files and streams. Uses GpHugeF unit for file access.

## GpTextStream

Stream wrapper class that automatically converts another stream (containing
text data) into a Unicode stream. Underlying stream can contain 8-bit text
(in any codepage) or 16-bit text (in 16-bit or UTF8 encoding).

## GpTimezone

Time zone conversion.

## GpVCL

VCL helper library.

## GpVersion

Version info accessors and modifiers, version storage and formatting.

## SafeMem

GetMem/FreeMem wrapper that checks for block overruns.

## SpinLock

A scalable atomic lock
