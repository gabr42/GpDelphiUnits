{$B-,H+,J+,Q-,T-,X+}

(*:Some useful stream wrappers.
   @author Primoz Gabrijelcic
   @desc <pre>
   (c) 2006 Primoz Gabrijelcic
   Free for personal and commercial use. No rights reserved.

   Author           : Primoz Gabrijelcic
   Creation date    : 2001-07-17
   Last modification: 2006-09-21
   Version          : 1.04
   </pre>
*)(*
   History:
     1.04: 2006-09-21
       - TGpStreamWindow class moved to the GpStreams unit.
     1.03: 2006-08-31
       - Enable int64-based interface for Delphi 6.
     1.02: 2006-04-14
       - Added TGpStreamWindow class.
     1.01: 2003-05-16
       - Made Delphi 7 compatible.
     1.0: 2001-07-17
       - Released.
*)

unit GpStreamWrapper;

{$IFDEF CONDITIONALEXPRESSIONS}
  {$IF (RTLVersion >= 14)} // Delphi 6.0 or newer
    {$DEFINE D6PLUS}
  {$IFEND}
{$ENDIF}

interface

uses
  Classes;

type
  {:Base stream wrapper class implementing the delayed Seek.
  }
  TGpStreamWrapper = class(TStream)
  private
    swDelayedSeek   : boolean;
    swSeekMode      : word;
    swSeekOffset    : longint;
    swStoredPosition: longint;
    swStream        : TStream;
  protected
    function  GetPosition: {$IFDEF D6PLUS}int64;{$ELSE}longint;{$ENDIF D6PLUS} virtual;
    function  GetSize: {$IFDEF D6PLUS}int64; override;{$ELSE}longint; virtual;{$ENDIF D6PLUS}
    procedure SetPosition(newPosition: {$IFDEF D6PLUS}int64{$ELSE}longint{$ENDIF D6PLUS}); virtual;
    procedure SetSize({$IFDEF D6PLUS}const{$ENDIF D6PLUS}newSize: {$IFDEF D6PLUS}int64{$ELSE}longint{$ENDIF D6PLUS}); override;
    function  WrappedSeek(offset: integer; mode: word): longint; {$IFDEF D6PLUS}overload;{$ENDIF D6PLUS}virtual;
    {$IFDEF D6PLUS}
    function  WrappedSeek(offset: int64; origin: TSeekOrigin): int64; overload; virtual;
    {$ENDIF D6PLUS}
  public
    constructor Create(wrappedStream: TStream);
    procedure DelayedSeek; virtual;
    function  Seek(offset: integer; mode: word): longint; {$IFDEF D6PLUS}overload;{$ENDIF D6PLUS} override;
    {:Wrapped (underlying) stream.}
    property  WrappedStream: TStream read swStream;
  end; { TGpStreamWrapper }

implementation

{ TGpStreamWrapper }

constructor TGpStreamWrapper.Create(wrappedStream: TStream);
begin
  inherited Create;
  swStream := wrappedStream;
end; { TGpStreamWrapper.Create }

{:Repositions stream pointer in the wrapped stream (if required). Call this
  method as a first thing in the descendant Read and Write methods.
}
procedure TGpStreamWrapper.DelayedSeek;
begin
  if swDelayedSeek then begin
    if (swSeekOffset <> 0) or (swSeekMode <> soFromCurrent) then
      WrappedSeek(swSeekOffset,swSeekMode);
    swDelayedSeek := false;
  end;
end; { TGpStreamWrapper.DelayedSeek }

{:Returns the position in the wrapping (virtual) stream. Trivial implementation
  from this class returns position of the wrapped (underlying) stream.
  If descendant overrides this method, it must never call TGpStreamWrapper.Seek
  (directly or indirectly).
}
function TGpStreamWrapper.GetPosition: {$IFDEF D6PLUS}int64;{$ELSE}longint;{$ENDIF D6PLUS}
begin
  Result := WrappedStream.Position;
end; { TGpStreamWrapper.GetPosition }

{:Returns the size of the wrapping (virtual) stream. Trivial implementation
  from this class returns size of the wrapped (underlying) stream.
  If descendant overrides this method, it must never call TGpStreamWrapper.Seek
  (directly or indirectly).
}
function TGpStreamWrapper.GetSize: {$IFDEF D6PLUS}int64;{$ELSE}longint;{$ENDIF D6PLUS}
begin
  Result := WrappedStream.Size;
end; { TGpStreamWrapper.GetSize }

{:Repositions stream pointer. Actually only stores this information for later
  use (when stream pointer position is really used).
  @param   offset Offset from start, current position, or end of stream (as set
                  by the 'mode' parameter) in bytes.
  @param   mode   Specifies starting point for offset calculation
                  (soFromBeginning, soFromCurrent, soFromEnd).
  @returns New position of stream pointer.
}
function TGpStreamWrapper.Seek(offset: longint; mode: word): longint;
begin
  // TStream is using following code to get Size of the stream:
  // Pos := Seek(0, soFromCurrent);
  // Result := Seek(0, soFromEnd);
  // Seek(Pos, soFromBeginning);
  // This code tries to hack around this stupid behaviour.
  if not swDelayedSeek then begin
    if (mode = soFromCurrent) and (offset = 0) then begin
      // possible GetSize call
      swDelayedSeek := true;
      swSeekOffset  := offset;
      swSeekMode    := mode;
      swStoredPosition := GetPosition;
      Result := swStoredPosition;
    end
    else // not a GetSize call, forward it
      Result := WrappedSeek(offset,mode);
  end
  else begin
    if mode = soFromCurrent then
      // not a GetSize call; saved Seek can only be (0,fromCurrent) - it is not
      // necessary to call DelayedSeek
      Result := WrappedSeek(offset,mode)
    else if mode = soFromEnd then begin
      if swSeekMode = soFromCurrent then begin
        // possible GetSize call
        swSeekOffset := offset;
        swSeekMode   := mode;
        Result := GetSize;
      end
      else // not a GetSize call
        Result := WrappedSeek(offset,mode);
    end
    else {if mode = soFromBeginning} begin
      if (swSeekMode = soFromEnd) and (swStoredPosition = offset) then begin
        // definitely GetSize call
        swDelayedSeek := false;
        Result := swStoredPosition;
      end
      else // not a GetSize call
        Result := WrappedSeek(offset,mode);
    end;
  end;
end; { TGpStreamWrapper.Seek }

{:Sets the position in the wrapping (virtual) stream. Trivial implementation
  from this class sets position of the wrapped (underlying) stream.
  If descendant overrides this method, it must never call TGpStreamWrapper.Seek
  (directly or indirectly).
}
procedure TGpStreamWrapper.SetPosition(newPosition: {$IFDEF D6PLUS}int64{$ELSE}longint{$ENDIF D6PLUS});
begin
  WrappedStream.Position := newPosition;
end; { TGpStreamWrapper.SetPosition }

{:Sets the size of the wrapping (virtual) stream. Trivial implementation
  from this class sets position of the wrapped (underlying) stream.
  If descendant overrides this method, it must never call TGpStreamWrapper.Seek
  (directly or indirectly).
}
procedure TGpStreamWrapper.SetSize({$IFDEF D6PLUS}const{$ENDIF D6PLUS}newSize: {$IFDEF D6PLUS}int64{$ELSE}longint{$ENDIF D6PLUS});
begin
  WrappedStream.Size := newSize;
end; { TGpStreamWrapper.SetSize }

{:Implementation of the 'true' Seek. Called only when Seek is really needed.
  Trivial implementation from this class calls Seek on the wrapped (underlying) stream.
  WrappedSeek must never call TGpStreamWrapper.Seek (directly or indirectly) but use
  directly WrappedStream.Seek.
}
function TGpStreamWrapper.WrappedSeek(offset: integer;
  mode: word): longint;
begin
  Result := WrappedStream.Seek(offset, mode);
end; { TGpStreamWrapper.WrappedSeek }

{$IFDEF D6PLUS}
function TGpStreamWrapper.WrappedSeek(offset: int64; origin: TSeekOrigin): int64;
begin
  Result := WrappedStream.Seek(offset, origin);
end;
{$ENDIF D6PLUS}

end.
