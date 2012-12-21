unit PasswUn;

interface

uses Windows;

procedure SetPassword(ParentWnd: hWnd);
function CheckPassword(hWindow: hWnd): Boolean;

implementation

type
  TVSSPFunc = function(Parent: hWnd): Bool; stdcall;
  TPCPAFunc = function(A: PChar; Parent: hWnd; B, C: Integer): Integer; stdcall;

procedure SetPassword(ParentWnd: hWnd);
var
  Lib: THandle;
  Func: TPCPAFunc;
begin
  Lib := LoadLibrary('MPR.DLL');
  If (Lib > 32) then begin
    @Func := GetProcAddress(Lib, 'PwdChangePasswordA');
    If (@Func <> nil) then Func('SCRSAVE', ParentWnd, 0, 0);
    FreeLibrary(Lib);
  end;
end;

function CheckPassword(hWindow: hWnd): Boolean;
var
  Key    : hKey;
  D1, D2 : Integer;
  Value  : Integer;
  Lib    : THandle;
  Func   : TVSSPFunc;
begin
  Result := True;
  If RegOpenKeyEx(HKEY_CURRENT_USER, 'Control Panel\Desktop', 0, Key_Read, Key) = Error_Success then begin
    D2 := SizeOf(Value);
    If RegQueryValueEx(Key, 'ScreenSaveUsePassword', nil, @D1, @Value, @D2) = Error_Success then begin
      If (Value <> 0) then begin
        Lib := LoadLibrary('PASSWORD.CPL');
        If (Lib > 32) then begin
          @Func := GetProcAddress(Lib, 'VerifyScreenSavePwd');
          ShowCursor(True);
          If (@Func <> nil) then Result := Func(hWindow);
          ShowCursor(False);
          FreeLibrary(Lib);
        end;
      end;
    end;
    RegCloseKey(Key);
  end;
end;

end.
