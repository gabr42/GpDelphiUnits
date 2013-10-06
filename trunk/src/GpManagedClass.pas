(*:Smarter base class. Handles error codes, has precondition and postcondition
   checker.
   @author Primoz Gabrijelcic
   @desc <pre>
   (c) 2002 Primoz Gabrijelcic

This software is distributed under the BSD license.

Copyright (c) 2003, Primoz Gabrijelcic
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
   Creation date     : 2001-09-05
   Last modification : 2002-05-13
   Version           : 1.07
</pre>*)(*
   History:
     1.07: 2002-05-15
       - Modified overloaded methods SetError(mngObj: TGpManagedClass) and
         SetError(mngIntf: IGpManagedErrorHandling) (added second parameter
         'condition' (default False)).
     1.06: 2002-05-13
       - Added class TGpManagedError.
     1.05: 2002-05-12
       - Added overloaded method SetError(mngObj: TGpManagedClass).
     1.04: 2002-04-12
       - Postconditions are only checked when assertions are enabled.
     1.03: 2001-11-16
       - All string parameters of the IGpManagedConditionChecking interface made
         'const';
     1.02: 2001-10-08
       - Interface separated from the implementation.
     1.01: 2001-09-06
       - Added overloaded method SetError(mngIntf: IGpManagedErrorHandling). 
     1.0: 2001-09-05
       - Created & released.
*)

unit GpManagedClass;

interface

uses
  SysUtils {$IFDEF Unicode}, GpAutoCreate{$ENDIF};

const
  //:No error (success).
  ERR_NO_ERROR    = 0;
  //:Error codes should start here.
  ERR_FIRST_ERROR = -1;

type
  {:Interface for setting and retrieving error code and messages.
  }
  IGpManagedErrorHandling = interface
    ['{7E1074ED-56A4-47A0-A243-CC1C06668EE4}']
    //:Clears internal error status and returns True.
    function  ClearError: boolean;
    //:Retrieves default error message for error code. Returns empty string if there is no default error message for this code.
    function  GetDefaultErrorMessage(errorCode: integer): string;
    //:Retrieves last error code and message.
    function  GetLastErrorInfo(var errorMsg: string): integer;
    //:Retrieves last error message.
    function  GetLastErrorMsg: string;
    //:Retrieves last error code.
    function  GetLastErrorNum: integer;
    //:Sets error status to error code and error message. If error message is empty, GetDefaultErrorMessage will be used to retrieve it.
    function  SetError(errorCode: integer; errorMsg: string = ''): boolean; overload;
    //:Sets error status to error code and formatted error message.
    function  SetError(errorCode: integer; errorMsg: string; params: array of const): boolean; overload;
    //:Sets error status to error code and formatted default (retrieved with GetDefaultErrorMessage) error message.
    function  SetError(errorCode: integer; params: array of const): boolean; overload;
    //:Copies error status from another IGpManagedErrorHandling interface.
    function  SetError(const mngIntf: IGpManagedErrorHandling; condition: boolean = false): boolean; overload;
  end; { IGpManagedErrorHandling }

  {:Exception class that simplifies error reporting for the
    IGpManagedErrorHandling interface.
  }
  EGpManagedError = class(Exception)
    //:Retrieve error status from the IGpManagedErrorHandling interface and copy it to the exception text.
    constructor Create(const managedErrorIntf: IGpManagedErrorHandling); reintroduce;
  end; { EGpManagedError }

  {:Interface for checking pre-, post- and oridinary conditions.
  }
  IGpManagedConditionChecking = interface
    ['{FE96E38F-007D-4190-8F7D-54708B0D565A}']
    //:Check condition. If it is false, raise exception with method name and description of the condition.
    procedure Check(const methodName: string; condition: boolean;
      const conditionDescription: string);
    //:Check condition. If it is false, raise exception with check name, method name, and description of the condition.
    procedure CheckCondition(const checkName, methodName: string; condition: boolean;
      const conditionDescription: string);
    //:Check postcondition. If it is false, raise exception with method name and description of the condition.
    procedure Postcondition(const methodName: string; condition: boolean;
      const conditionDescription: string);
    //:Check precondition. If it is false, raise exception with method name and description of the condition.
    procedure Precondition(const methodName: string; condition: boolean;
      const conditionDescription: string);
  end; { IGpManagedConditionChecking }

  {:Parent class implementing IGpManagedErrorHandling and
    IGpManagedConditionChecking interfaces.
  }
  TGpManagedClass = class({$IFDEF Unicode}TGpManaged{$ELSE}TInterfacedObject{$ENDIF}, IGpManagedErrorHandling, IGpManagedConditionChecking)
  private
    mngLastError   : integer;
    mngLastErrorMsg: string;
  protected
    //IGpManagedConditionChecking
    procedure Check(const methodName: string; condition: boolean;
      const conditionDescription: string); virtual;
    procedure CheckCondition(const checkName, methodName: string; condition: boolean;
      const conditionDescription: string); virtual;
    procedure Postcondition(const methodName: string; condition: boolean;
      const conditionDescription: string);
    procedure Precondition(const methodName: string; condition: boolean;
      const conditionDescription: string);
    //IGpManagedErrorHandling
    function  ClearError: boolean; virtual;
    function  GetDefaultErrorMessage(errorCode: integer): string; virtual;
    function  GetLastErrorMsg: string; virtual;
    function  GetLastErrorNum: integer; virtual;
    function  SetError(errorCode: integer; errorMsg: string = ''): boolean; overload;
      virtual;
    function  SetError(errorCode: integer; errorMsg: string;
      params: array of const): boolean; overload; virtual;
    function  SetError(errorCode: integer; params: array of const): boolean; overload;
      virtual;
    function  SetError(const mngIntf: IGpManagedErrorHandling;
      condition: boolean = false): boolean; overload; virtual;
    function  SetError(const mngObj: TGpManagedClass;
      condition: boolean = false): boolean; overload; virtual;
  public
    //IGpManagedConditionChecking
    function  GetLastErrorInfo(var errorMsg: string): integer; virtual;
  {properties}
    property LastError   : integer read GetLastErrorNum;
    property LastErrorMsg: string read GetLastErrorMsg;
  end; { TGpManagedClass }

  TGpManagedError = class(TGpManagedClass)
  public
    function  ClearError: boolean; override;
    function  SetError(errorCode: integer;
      errorMsg: string = ''): boolean; overload; override;
    function  SetError(errorCode: integer;
      errorMsg: string; params: array of const): boolean; overload; override;
    function  SetError(errorCode: integer;
      params: array of const): boolean; overload; override;
    function  SetError(const mngIntf: IGpManagedErrorHandling;
      condition: boolean = false): boolean; overload; override;
    function  SetError(const mngObj: TGpManagedClass;
      condition: boolean = false): boolean; overload; override;
  end; { TGpManagedError }

implementation

{ TGpManagedClass }

{:Check condition. If it is false, raise exception with method name and
  description of the condition.
  @param   methodName           Name of the caller.
  @param   condition            Condition that should evaluate to true.
  @param   conditionDescription Textual description of the condition.
}
procedure TGpManagedClass.Check(const methodName: string; condition: boolean;
  const conditionDescription: string);
begin
  CheckCondition('Check',methodName,condition,conditionDescription);
end; { TGpManagedClass.Check }

{:Check condition. If it is false, raise exception with check name, method name,
  and description of the condition.
  @param   checkName            Name of the checking routine.
  @param   methodName           Name of the caller.
  @param   condition            Condition that should evaluate to true.
  @param   conditionDescription Textual description of the condition.
}
procedure TGpManagedClass.CheckCondition(const checkName, methodName: string;
  condition: boolean; const conditionDescription: string);
begin
 if not condition then
    raise Exception.CreateFmt('%s "%s" was not satisfied in method %s.%s',
      [checkName,conditionDescription,ClassName,methodName]);
end; { TGpManagedClass.CheckCondition }

{:Clear internal error status.
  @returns True.
}
function TGpManagedClass.ClearError: boolean;
begin
  mngLastError := ERR_NO_ERROR;
  mngLastErrorMsg := '';
  Result := true;
end; { TGpManagedClass.ClearError }

{:Retrieve default error message for error code.
  @params  errorCode Error code.
  @returns Returns default error message for the parameter or empty string.
}
function TGpManagedClass.GetDefaultErrorMessage(errorCode: integer): string;
begin
  Result := '';
end; { TGpManagedClass.GetDefaultErrorMessage }

{:Retrieves last error code and message.
  @param   errorMsg (out) Error message.
  @returns Error code.
}
function TGpManagedClass.GetLastErrorInfo(var errorMsg: string): integer;
begin
  errorMsg := GetLastErrorMsg;
  Result := GetLastErrorNum;
end; { TGpManagedClass.GetLastErrorInfo }

{:Retrieves last error message.
  @returns Error message.
}
function TGpManagedClass.GetLastErrorMsg: string;
begin
  Result := mngLastErrorMsg;
end; { TGpManagedClass.GetLastErrorMsg }

{:Retrieves last error code.
  @returns Error code.
}
function TGpManagedClass.GetLastErrorNum: integer;
begin
  Result := mngLastError;
end; { TGpManagedClass.GetLastErrorNum }

{:If assertions are enabled, check postcondition. If it is false, raise
  exception with method name and description of the condition. 
  @param   methodName           Name of the caller.
  @param   condition            Condition that should evaluate to true.
  @param   conditionDescription Textual description of the condition.
}
procedure TGpManagedClass.Postcondition(const methodName: string;
  condition: boolean; const conditionDescription: string);
begin
  {$IFOPT C+}
  CheckCondition('Postcondition',methodName,condition,conditionDescription);
  {$ENDIF C+}
end; { TGpManagedClass.Postcondition }

{:Check precondition. If it is false, raise exception with method name and
  description of the condition.
  @param   methodName           Name of the caller.
  @param   condition            Condition that should evaluate to true.
  @param   conditionDescription Textual description of the condition.
}
procedure TGpManagedClass.Precondition(const methodName: string;
  condition: boolean; const conditionDescription: string);
begin
  CheckCondition('Precondition',methodName,condition,conditionDescription);
end; { TGpManagedClass.Precondition }

{:Set error status to error code and error message. If error message is empty,
  GetDefaultErrorMessage will be used to retrieve it.
  @param   errorCode Error code.
  @param   errorMsg  Error message. Can be empty (and by default is is) - in
                     that case GetDefaultErrorMessage will be used to retrieve
                     error message.
}
function TGpManagedClass.SetError(errorCode: integer; errorMsg: string): boolean;
begin
  mngLastError := errorCode;
  if errorMsg <> '' then
    mngLastErrorMsg := errorMsg
  else
    mngLastErrorMsg := GetDefaultErrorMessage(errorCode);
  Result := false;
end; { TGpManagedClass.SetError }

{:Sets error status to error code and formatted error message.
  @param   errorCode Error code.
  @param   errorMsg  Error message.
  @param   params    Parameters for the error message.     
}
function TGpManagedClass.SetError(errorCode: integer; errorMsg: string;
  params: array of const): boolean;
begin
  Result := SetError(errorCode,Format(errorMsg,params));
end; { TGpManagedClass.SetError }

{:Sets error status to error code and formatted default (retrieved with
  GetDefaultErrorMessage) error message.
  @param   errorCode Error code.
  @param   params    Parameters for the error message.
}
function TGpManagedClass.SetError(errorCode: integer;
  params: array of const): boolean;
begin
  Result := SetError(errorCode,GetDefaultErrorMessage(errorCode),params);
end; { TGpManagedClass.SetError }

{:Copies error status from another IGpManagedErrorHandling interface.
  @param   mngIntf   Interface providing the error code and message.
  @param   condition If True, error will be cleared, not set.
}
function TGpManagedClass.SetError(const mngIntf: IGpManagedErrorHandling;
  condition: boolean): boolean;
begin
  if condition then
    Result := ClearError
  else
    Result := SetError(mngIntf.GetLastErrorNum, mngIntf.GetLastErrorMsg);
end; { TGpManagedClass.SetError }

{:Copies error status from another TGpManagedClass object.
  @param   mngObj Object providing the error code and message.
  @param   condition If True, error will be cleared, not set.
}
function TGpManagedClass.SetError(const mngObj: TGpManagedClass;
  condition: boolean = false): boolean;
begin
  if condition then
    Result := ClearError
  else
    Result := SetError(mngObj.GetLastErrorNum, mngObj.GetLastErrorMsg);
end; { TGpManagedClass.SetError }

{ EGpManagedError }

{:Retrieve error status from the IGpManagedErrorHandling interface and copy it
  to the exception text.
}
constructor EGpManagedError.Create(const managedErrorIntf: IGpManagedErrorHandling);
begin
  inherited Create(managedErrorIntf.GetLastErrorMsg);
end; { EGpManagedError.Create }

{ TGpManagedError }

function TGpManagedError.ClearError: boolean;
begin
  Result := inherited ClearError;
end; { TGpManagedError.ClearError }

function TGpManagedError.SetError(errorCode: integer; errorMsg: string;
  params: array of const): boolean;
begin
  Result := inherited SetError(errorCode, errorMsg, params);
end; { TGpManagedError.SetError }

function TGpManagedError.SetError(errorCode: integer;
  errorMsg: string): boolean;
begin
  Result := inherited SetError(errorCode, errorMsg);
end; { TGpManagedError.SetError }

function TGpManagedError.SetError(errorCode: integer;
  params: array of const): boolean;
begin
  Result := inherited SetError(errorCode, params);
end; { TGpManagedError.SetError }

function TGpManagedError.SetError(const mngObj: TGpManagedClass;
  condition: boolean = false): boolean;
begin
  Result := inherited SetError(mngObj, condition);
end; { TGpManagedError.SetError }

function TGpManagedError.SetError(
  const mngIntf: IGpManagedErrorHandling; condition: boolean = false): boolean;
begin
  Result := inherited SetError(mngIntf, condition);
end; { TGpManagedError.SetError }

end.
