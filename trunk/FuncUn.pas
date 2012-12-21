unit FuncUn;

interface

uses Windows;


function  wsprintf(Output: PChar; Format: PChar): Integer; cdecl; varargs;
function  AbsL(a: Integer): Integer; Assembler;
function  MaxZero(a: Integer): Integer; Assembler;
function  Max(AValueOne, AValueTwo: Integer): Integer;
function  Min(AValueOne, AValueTwo: Integer): Integer;
function  IntToStr(Value: Integer) : String;
function  StrToInt(const S : String) : Integer;
procedure _DbgPrint(const Format: String); cdecl;
function  _FormatC(const Format: String): String; cdecl;

function  NtQueryTimerResolution(var MinRes: DWORD; var MaxRes: DWORD; var ActRes: DWORD): DWORD; stdcall; external 'ntdll.dll';
function  NtSetTimerResolution(DesiredResolution: DWORD; SetResolution: BOOL; var CurrentResolution: DWORD): DWORD; stdcall; external 'ntdll.dll';

function  NtDelayExecution(Alertable: BOOL; var DelayInterval: Int64): DWORD; stdcall; external 'ntdll.dll';

const // allows us to use "varargs" in Delphi
  DbgPrint: procedure(const Format: String); cdecl varargs = _DbgPrint;
  FormatC:  function(const Format: string): string; cdecl varargs = _FormatC;

implementation

function wsprintf(Output: PChar; Format: PChar): Integer; cdecl; varargs; external 'user32.dll' name 'wsprintfA';

function AbsL(a: Integer): Integer; Assembler;
// -> EAX = a
asm
        cdq
        xor eax,edx
        sub eax,edx
end;

// a = (a < 0) ? 0 : a;
function MaxZero(a: Integer): Integer; Assembler;
// -> EAX = a
asm
        xor  edx, edx
        cmp  eax, edx
        setl dl
        sub  edx, 1
        and  edx, eax
        mov  eax, edx  
end;

function Max(AValueOne, AValueTwo: Integer): Integer;
begin
  if AValueOne < AValueTwo then Result := AValueTwo else Result := AValueOne;
end;

function Min(AValueOne, AValueTwo: Integer): Integer;
begin
  if AValueOne > AValueTwo then Result := AValueTwo else Result := AValueOne;
end;


function IntToStr(Value: Integer) : String;
var
  Int : Integer;
  Ch  : Char;
begin
  Result := '';
  repeat
    Int := Value mod 10;
    Value := Value div 10;
    Result := Result + Chr(Int+48);
  until Value = 0;
  For Int := 1 to Length(Result) div 2 do
  begin
    Ch := Result[Int];
    Result[Int] := Result[Length(Result)-Int+1];
    Result[Length(Result)-Int+1] := Ch;
  end;
end;

function StrToInt(const S : String) : Integer;
var
  N, Len : Integer;
begin
  Result := 0;
  Len := Length(S);
  For N := 1 to Len do begin
    Result := Result*10;
    Result := Result + (Ord(S[N])-48);
  end;
end;

function _FormatC(const Format: string): string; cdecl;
const
  StackSlotSize = SizeOf(Pointer);
var
  Args: va_list;
  Len: Integer;
  Buffer: array[0..1024] of Char;
begin
  // va_start(Args, Format)
  Args := va_list(PAnsiChar(@Format) + ((SizeOf(Format) + StackSlotSize - 1) and not (StackSlotSize - 1)));
  Len := wvsprintf(Buffer, PChar(Format), Args);
  SetString(Result, Buffer, Len);
end;

{$IFDEF DBGLOG}
procedure _DbgPrint(const Format: String); cdecl;
const
  StackSlotSize = SizeOf(Pointer);
var
  Args: va_list;
  Len: Integer;
  str: array[0..1024] of Char;
begin
  // va_start(Args, Format)
  Args := va_list(PAnsiChar(@Format) + ((SizeOf(Format) + StackSlotSize - 1) and not (StackSlotSize - 1)));
  Len := Windows.wvsprintf(str, PChar(Format), Args);
  Windows.OutputDebugStringA(str);
end;
{$ENDIF}

{$IFNDEF DBGLOG}
procedure _DbgPrint(const Format: String); cdecl;
begin
  //
end;
{$ENDIF}

end.
