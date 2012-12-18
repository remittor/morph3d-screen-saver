// Программа-заставка Morph3D для Windows 9x/ME/NT/2000/XP
// Основа графики - графика WinGDI
// Начало работы 1.сен.2001, beta-версия - 20.ноя.2001
// http://morph3d.narod.ru
// http://morph3d.nm.ru        сайты программы
// Проверяйте их иногда - вдруг новая версия !
// Разработал Чернов Сергей
// E-mail: morph3d@mail.ru, sergey_chernow@mail.ru

// Morph3D Screen Saver for Windows 9x/ME/NT/2000/XP
// Graphics - WinGDI
// Visit Morph3D sites : http://morph3d.narod.ru
//                       http://morph3d.nm.ru
// Check for new versions !
// Made by Chernow Sergey
// E-mail: morph3d@mail.ru, sergey_chernow@mail.ru

program Morph3D;
uses
  Windows,
  Messages,
  ShellApi,
  MorphUn in 'MorphUn.pas',
  DrawUn in 'DrawUn.pas',
  ShapeUn in 'ShapeUn.pas';

{$E scr}

{$R *.RES}
{$R dialog.res}

type
  TVSSPFunc = function(Parent : hWnd) : Bool; stdcall;
  TPCPAFunc = function(A : PChar; Parent : hWnd; B, C : Integer) : Integer; stdcall;

var
  MoveCounter : Integer;
  Msg         : TMsg;
  S           : String;
  Dummy       : DWord;
  ParentWnd   : hWnd;
  ActiveWnd   : hWnd=0;
  R           : TRect;

const
  AppName = 'Morph3D';
  RegKey = 'Software\Morph3D';

  dShowFPSID=256; // Окно настроек- показ "кадр/с"
                  // Identificator of checkbox "FPS"

  dUnSortID=257; // Окно настроек - сортированиие точек
                 // Identificator of checkbox "UnSort"

  dMouseSens=258; // Окно настроек - чувствительность мышки
                  // Identificator of spinedit "Mouse Sensivity"
  dMove3DID=259; // Окно настроек - перемещение объекта в 3-х мерном пространстве
                 // Identificator of spinedit "Move in 3D"
  dMorph3DMail=260; // Окно настроек - e-mail
                    // Identificator of button "morph3d@mail.ru"
  dMorph3DSite=261; // Окно настроек - сайт
                    // Identificator of button "http://morph3d.nm.ru"

function IntToStr(Value : Integer) : String;
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

function StrPas(S : PChar) : String;
begin
  Result := S;
end;

procedure GetReg;
var
  hReg : hKey;
  Buff : array[0..127] of Char;
  rt   : Integer;
  rc   : DWord;
begin
  RegOpenKeyEx(HKEY_LOCAL_MACHINE, RegKey, 0, KEY_ALL_ACCESS, hReg);

  FillChar(Buff, SizeOf(Buff), #0);
  rt := REG_SZ; rc := 127;
  If RegQueryValueEx(hReg, 'ShowFPS', nil, @rt, @Buff, @rc)=0 then
    If StrPas(Buff)='1' then ShowFPS := True;
  If RegQueryValueEx(hReg, 'UnSortPoints', nil, @rt, @Buff, @rc)=0 then
    If StrPas(Buff)='1' then UnSortPoints := True;
  If RegQueryValueEx(hReg, 'MouseSens', nil, @rt, @Buff, @rc)=0 then
    If StrPas(Buff)='0' then MouseSens := False;
  If RegQueryValueEx(hReg, 'Move3D', nil, @rt, @Buff, @rc)=0 then
    If StrPas(Buff)='0' then Move3D := False;  
  RegCloseKey(hReg);
end;

procedure Regist;
var
  Str  : String;
  hReg : hKey;
  rt   : Cardinal;
begin
  rt := REG_SZ;
  If RegOpenKeyEx(HKEY_LOCAL_MACHINE, RegKey, 0, KEY_ALL_ACCESS, hReg) <> 0 then
    RegCreateKey(HKEY_LOCAL_MACHINE, RegKey, hReg);

  Str := IntToStr(Integer(ShowFPS));
  RegSetValueEx(hReg, 'ShowFPS', 0, rt, PChar(Str), Length(Str));

  Str := IntToStr(Integer(UnSortPoints));
  RegSetValueEx(hReg, 'UnSortPoints', 0, rt, PChar(Str), Length(Str));

  Str := IntToStr(Integer(MouseSens));
  RegSetValueEx(hReg, 'MouseSens', 0, rt, PChar(Str), Length(Str));

  Str := IntToStr(Integer(Move3D));
  RegSetValueEx(hReg, 'Move3D', 0, rt, PChar(Str), Length(Str));

  RegCloseKey(hReg);
end;

procedure SetPassword;
var
  Lib  : THandle;
  Func : TPCPAFunc;
begin
  Lib := LoadLibrary('MPR.DLL');
  If (Lib > 32) then
  begin
    @Func := GetProcAddress(Lib, 'PwdChangePasswordA');
    If (@Func <> nil) then Func('SCRSAVE', StrToInt(ParamStr(2)), 0, 0);
    FreeLibrary(Lib);
  end;
end;

function CheckPassword : Boolean;
var
  Key    : hKey;
  D1, D2 : Integer;
  Value  : Integer;
  Lib    : THandle;
  Func   : TVSSPFunc;
begin
  Result := True;
  If Preview then Exit;
  If (RegOpenKeyEx(hKey_Current_User, 'Control Panel\Desktop', 0, Key_Read,
    Key) = Error_Success) then
  begin
    D2 := SizeOf(Value);
    If (RegQueryValueEx(Key, 'ScreenSaveUsePassword', nil, @D1, @Value, @D2) =
      Error_Success) then
    begin
      If (Value <> 0) then
      begin
        Lib := LoadLibrary('PASSWORD.CPL');
        If (Lib > 32) then
        begin
          @Func := GetProcAddress(Lib, 'VerifyScreenSavePwd');
          ShowCursor(True); DoDraw := False;
          If (@Func <> nil) then Result := Func(hWindow);
          ShowCursor(False); DoDraw := True;
          MoveCounter := 0;
          FreeLibrary(Lib);
        end;
      end;
    end;
    RegCloseKey(Key);
  end;
end;

function About(Dialog: HWnd; AMessage, WParam: UINT;
  LParam: LPARAM): Bool; stdcall; export;
begin
  Result := True;
  case AMessage of
    wm_InitDialog :
      begin
        SendMessage(GetDlgItem(Dialog, dShowFPSID), BM_SETCHECK,
          Integer(ShowFPS), 0);

        SendMessage(GetDlgItem(Dialog, dUnSortID), BM_SETCHECK,
          Integer(UnSortPoints), 0);

        SendMessage(GetDlgItem(Dialog, dMouseSens), BM_SETCHECK,
          Integer(MouseSens), 0);

        SendMessage(GetDlgItem(Dialog, dMove3DID), BM_SETCHECK,
          Integer(Move3D), 0);  
      end;

    wm_Command:
      Case WParam of
        idOk, idCancel :
        begin
          If WParam=idOk then
          begin
            ShowFPS := (SendMessage(GetDlgItem(Dialog, dShowFPSID),
              BM_GETCHECK, 0, 0) = 1);

            UnSortPoints := (SendMessage(GetDlgItem(Dialog, dUnSortID),
              BM_GETCHECK, 0, 0) = 1);

            MouseSens := (SendMessage(GetDlgItem(Dialog, dMouseSens),
              BM_GETCHECK, 0, 0) = 1);

            Move3D := (SendMessage(GetDlgItem(Dialog, dMove3DID),
              BM_GETCHECK, 0, 0) = 1);

            Regist;
          end;
          EndDialog(Dialog, 1);
          Exit;
        end;
        dMorph3DMail : ShellExecute(0, nil, 'mailto:morph3d@mail.ru',
          nil, nil, SW_NORMAL);
        dMorph3DSite : ShellExecute(0, nil, 'http://morph3d.nm.ru',
          nil, nil, SW_NORMAL);
      end;
  end;
  Result := False;
end;

procedure Wnd_Create(hWindow : hWnd; var Msg : TWMCreate);
begin
  Msg.Result := 0;
  DoDraw := True;
  SecStart := GetTickCount;

  InitShape(PCoords1);

  CalcPos;
end;

procedure Wnd_Size(hWindow : hWnd; var Msg : TWMSize);
begin
  DeleteObject(DC);
  DeleteObject(CDC);
  DeleteObject(DCBitmap);

  GetClientRect(hWindow, WndRect);
  DC := GetDC(hWindow);

  CDC := CreateCompatibleDC(DC);
  SetTextColor(CDC, clWhite);
  DCBitmap := CreateCompatibleBitmap(DC, WndRect.Right, WndRect.Bottom);
  SelectObject(CDC, DCBitmap);

  SetBkColor(CDC, clBlack); // полная очистка экрана / erase full screen
  ExtTextOut(CDC, 0, 0, ETO_OPAQUE, @WndRect, nil, 0, nil);

  ScrX := (WndRect.Right div 2);
  ScrY := (WndRect.Bottom div 2);
  CoefX := (WndRect.Right div 8);
  CoefY := (WndRect.Bottom div 6);

  LastTickCount := GetTickCount;
end;

procedure Wnd_Destroy;
begin
  If CheckPassword then
  begin
    QuitSaver := True;

    DeleteObject(DCBitmap);
    DeleteObject(CDC);
    ReleaseDC(hWindow, DC);
    DoDraw := False;

    PostQuitMessage(0);
  end;
end;

function WindowProc(Window : HWnd; AMessage, WParam,
  LParam : Longint) : Longint; stdcall; export;
var
  AMsg: TMessage;
begin
  AMsg.Msg := AMessage;
  AMsg.WParam := WParam;
  AMsg.LParam := LParam;
  AMsg.Result := 0;

  case AMessage of
    WM_SYSCOMMAND : If WParam = SC_CLOSE then Wnd_Destroy;

    WM_CREATE : Wnd_Create(Window, TWMCreate(AMsg));
    WM_DESTROY : Wnd_Destroy;

    WM_KEYDOWN, WM_MOUSEWHEEL,
    WM_LBUTTONDOWN, WM_RBUTTONDOWN : If not Preview then Wnd_Destroy;

    wm_MouseMove :
      If (not Preview) and (MouseSens) then
      begin
        Inc(MoveCounter);
        If MoveCounter > 4 then Wnd_Destroy;
        ShowCursor(False);
      end;

    wm_Paint: If DoDraw then UpdateDisplay;
    wm_NCDestroy, wm_KillFocus : DoDraw := False;
    wm_setFocus : DoDraw := True;
    wm_size : Wnd_Size(Window, TWMSize(AMsg));
  end;

  Result := DefWindowProc(Window, AMessage, WParam, LParam);
end;

function DoRegister : Boolean;
var
  WndClass : TWndClass;
begin
  WndClass.style := CS_HREDRAW or CS_VREDRAW;
  WndClass.lpfnWndProc := @WindowProc;
  WndClass.cbClsExtra := 0;
  WndClass.cbWndExtra := 0;
  WndClass.hInstance := hInstance;
  WndClass.hIcon := LoadIcon(0, IDI_APPLICATION);
  WndClass.hCursor := LoadCursor(0, IDC_ARROW);
  WndClass.hbrBackground := GetStockObject(NULL_BRUSH);
  WndClass.lpszMenuName := nil;
  WndClass.lpszClassName := AppName;

  Result := (RegisterClass(WndClass) <> 0);
end;

begin
  Randomize;

  S := ParamStr(1);
  If (Length(S)>1) then
    Delete(S, 1, 1);

  GetReg;

  If (S='A') or (S='a') then SetPassword else
  If ((S='S') or (S='s')) or ((S='P') or (S='p')) then
  begin
    If FindWindow(AppName, 'Morph3D Screen Saver')<>0 then Exit;

    if not DoRegister then
    begin
      MessageBox(0, 'Невозможно зарегистрировать окно !', '', mb_Ok);
//                  'Unable to Register Window Class !'
      Exit;
    end;

    FillChar(R, SizeOf(R), 0); ParentWnd := 0;
    If ((S='P') or (S='p')) then // превьюшка / preview mode
    begin
      ParentWnd := StrToInt(ParamStr(2));
      GetWindowRect(ParentWnd, R);
      Preview := True;
    end;

    If not Preview then
    begin
      ActiveWnd := GetActiveWindow;
      hWindow := CreateWindow(AppName, 'Morph3D Screen Saver', ws_popup,
        0, 0, R.Right-R.Left, R.Bottom-R.Top, ParentWnd, 0, HInstance, nil);
    end else
      hWindow := CreateWindow(AppName, 'Morph3D Screen Saver',
        ws_Child or ws_Visible or ws_Disabled, 0, 0, R.Right-R.Left,
        R.Bottom-R.Top, ParentWnd, 0, HInstance, nil);

    if hWindow = 0 then
    begin
      MessageBox(0, 'Невозможно создать окно !', '', mb_Ok);
//                  'Unable to Create a Window'
      Exit;
    end;

    If not Preview then ShowCursor(False);

    If not Preview then
      ShowWindow(hWindow, SW_SHOWMAXIMIZED) else
      ShowWindow(hWindow, SW_SHOWNORMAL);
///////////////////////////////////////////////////////////////////////
    If not Preview then
      SetWindowPos(hWindow, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or
        SWP_NOSIZE or SWP_NOACTIVATE);
///////////////////////////////////////////////////////////////////////
    UpdateWindow(hWindow);

    CreateThread(nil, 0, @PreviewThreadProc, nil, 0, Dummy);

    If not Preview then
      SystemParametersInfo(spi_ScreenSaverRunning, 1, @Dummy, 0);

    while GetMessage(Msg, 0, 0, 0) do
    begin
      TranslateMessage(Msg);
      DispatchMessage(Msg);
    end;
    SystemParametersInfo(spi_ScreenSaverRunning, 0, @Dummy, 0);
    If not Preview then InvalidateRect(0, nil, False);
  end else
  begin
    DialogBox(hInstance, 'About', 0, @About);
  end;
  SetActiveWindow(ActiveWnd);
end.
