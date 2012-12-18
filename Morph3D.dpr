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
  Windows, Messages, ShellApi,
  MorphUn, DrawUn, ShapeUn, FuncUn, DirectDrawUn;

{$E scr}

{$R *.RES}
{$R dialog.res}

const
  USER_TIMER_MINIMUM = 10;
  ABOVE_NORMAL_PRIORITY_CLASS  = $00008000;
  BELOW_NORMAL_PRIORITY_CLASS  = $00004000;

type
  TVSSPFunc = function(Parent : hWnd) : Bool; stdcall;
  TPCPAFunc = function(A : PChar; Parent : hWnd; B, C : Integer) : Integer; stdcall;

var
  MoveCounter : Integer = -1;
  Msg         : TMsg;
  ParamS      : String;
  Dummy       : DWord;
  ParentWnd   : hWnd;
  ActiveWnd   : hWnd=0;
  R           : TRect;
  OldX        : Integer = 0;
  OldY        : Integer = 0;

type
  TPriorityName = array [0..15] of Char;

var
  PriorityList: array [0..4] of DWORD = (
    IDLE_PRIORITY_CLASS,                // 0
    BELOW_NORMAL_PRIORITY_CLASS,        // 1
    NORMAL_PRIORITY_CLASS,              // 2
    ABOVE_NORMAL_PRIORITY_CLASS,        // 3
    HIGH_PRIORITY_CLASS                 // 4
  );

const
  AppName = 'Morph3D Screen Saver';
  RegKey = 'Software\Morph3D';


  dShowFPSID   = 256; // Окно настроек- показ "кадр/с"
                      // Identificator of checkbox "FPS"

  dUnSortID    = 257; // Окно настроек - сортированиие точек
                      // Identificator of checkbox "UnSort"

  dMouseSens   = 258; // Окно настроек - чувствительность мышки
                      // Identificator of spinedit "Mouse Sensivity"

  dMove3DID    = 259; // Окно настроек - перемещение объекта в 3-х мерном пространстве
                      // Identificator of spinedit "Move in 3D"

  dUseDDrawID  = 300; // Окно настроек - рисовать через DirectDraw

  dPointSize   = 400; // Окно настроек - размер точки

  dProcPriority = 401; // Окно настроек - приоритет процесса

  dMorph3DMail = 260; // Окно настроек - e-mail
                      // Identificator of button "morph3d@mail.ru"

  dMorph3DSite = 261; // Окно настроек - сайт
                      // Identificator of button "http://morph3d.nm.ru"


function StrPas(S: PChar) : String;
begin
  Result := S;
end;

function GetRegParam(key: HKEY; ValueName: PChar; DefValue: DWORD): DWORD;
var
  rt, rc: DWORD;
begin
  rt := REG_DWORD;
  rc := 4;
  if RegQueryValueEx(key, ValueName, nil, @rt, @Result, @rc) = 0 then Exit;
  Result := DefValue;
end;

procedure GetReg;
var
  hReg : HKEY;
begin
  RegOpenKeyEx(HKEY_CURRENT_USER, RegKey, 0, KEY_READ, hReg);
  ShowFPS      := Boolean(GetRegParam(hReg, 'ShowFPS', 0));
  UnSortPoints := Boolean(GetRegParam(hReg, 'UnSortPoints', 0));
  MouseSens    := Boolean(GetRegParam(hReg, 'MouseSens', 1));
  Move3D       := Boolean(GetRegParam(hReg, 'Move3D', 0));
  UseDDraw     := Boolean(GetRegParam(hReg, 'UseDirectDraw', 0));
  PointSize    := GetRegParam(hReg, 'PointSize', 4);
  ProcPriority := GetRegParam(hReg, 'ProcessPriority', 2);
  RegCloseKey(hReg);
end;

function SetRegParam(key: HKEY; ValueName: PChar; Value: DWORD): Boolean;
begin
  if RegSetValueEx(key, ValueName, 0, REG_DWORD, @Value, 4) = 0 then Result := True else Result := False;
end;

procedure Regist;
var
  hReg: hKey;
begin
  If RegOpenKeyEx(HKEY_CURRENT_USER, RegKey, 0, KEY_ALL_ACCESS, hReg) <> 0 then begin
    RegCreateKey(HKEY_CURRENT_USER, RegKey, hReg);
  end;
  SetRegParam(hReg, 'ShowFPS',       DWORD(ShowFPS));
  SetRegParam(hReg, 'UnSortPoints',  DWORD(UnSortPoints));
  SetRegParam(hReg, 'MouseSens',     DWORD(MouseSens));
  SetRegParam(hReg, 'Move3D',        DWORD(Move3D));
  SetRegParam(hReg, 'UseDirectDraw', DWORD(UseDDraw));
  SetRegParam(hReg, 'PointSize',     PointSize);
  SetRegParam(hReg, 'ProcessPriority', ProcPriority);
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
  If (RegOpenKeyEx(HKEY_CURRENT_USER, 'Control Panel\Desktop', 0, Key_Read, Key) = Error_Success) then
  begin
    D2 := SizeOf(Value);
    If (RegQueryValueEx(Key, 'ScreenSaveUsePassword', nil, @D1, @Value, @D2) = Error_Success) then
    begin
      If (Value <> 0) then
      begin
        Lib := LoadLibrary('PASSWORD.CPL');
        If (Lib > 32) then
        begin
          @Func := GetProcAddress(Lib, 'VerifyScreenSavePwd');

          DoDraw := False;
          ShowCursor(True);
          If (@Func <> nil) then Result := Func(hWindow);
          ShowCursor(False);
          DoDraw := True;

          MoveCounter := 0;
          FreeLibrary(Lib);
        end;
      end;
    end;
    RegCloseKey(Key);
  end;
end;

function About(Dialog: HWnd; AMessage, WParam: UINT; LParam: LPARAM): Bool; stdcall; export;
begin
  Result := True;
  case AMessage of
    wm_InitDialog :
      begin
        SendMessage(GetDlgItem(Dialog, dShowFPSID),  BM_SETCHECK, Integer(ShowFPS),      0);
        SendMessage(GetDlgItem(Dialog, dUnSortID),   BM_SETCHECK, Integer(UnSortPoints), 0);
        SendMessage(GetDlgItem(Dialog, dMouseSens),  BM_SETCHECK, Integer(MouseSens),    0);
        SendMessage(GetDlgItem(Dialog, dMove3DID),   BM_SETCHECK, Integer(Move3D),       0);
        SendMessage(GetDlgItem(Dialog, dUseDDrawID), BM_SETCHECK, Integer(UseDDraw),     0);

        SendMessage(GetDlgItem(Dialog, dPointSize), CB_ADDSTRING, 0, Integer(PChar('1'#0)));
        SendMessage(GetDlgItem(Dialog, dPointSize), CB_ADDSTRING, 0, Integer(PChar('2'#0)));
        SendMessage(GetDlgItem(Dialog, dPointSize), CB_ADDSTRING, 0, Integer(PChar('3'#0)));
        SendMessage(GetDlgItem(Dialog, dPointSize), CB_ADDSTRING, 0, Integer(PChar('4'#0)));
        SendMessage(GetDlgItem(Dialog, dPointSize), CB_ADDSTRING, 0, Integer(PChar('5'#0)));
        SendMessage(GetDlgItem(Dialog, dPointSize), CB_ADDSTRING, 0, Integer(PChar('6'#0)));
        SendMessage(GetDlgItem(Dialog, dPointSize), CB_SETCURSEL, PointSize-1, 0);

        SendMessage(GetDlgItem(Dialog, dProcPriority), CB_ADDSTRING, 0, Integer(PChar('Idle'#0)));
        SendMessage(GetDlgItem(Dialog, dProcPriority), CB_ADDSTRING, 0, Integer(PChar('Below Normal'#0)));
        SendMessage(GetDlgItem(Dialog, dProcPriority), CB_ADDSTRING, 0, Integer(PChar('Normal'#0)));
        SendMessage(GetDlgItem(Dialog, dProcPriority), CB_ADDSTRING, 0, Integer(PChar('Above Normal'#0)));
        SendMessage(GetDlgItem(Dialog, dProcPriority), CB_ADDSTRING, 0, Integer(PChar('High'#0)));
        SendMessage(GetDlgItem(Dialog, dProcPriority), CB_SETCURSEL, ProcPriority, 0);
      end;

    wm_Command:
      Case WParam of
        idOk, idCancel :
          begin
            If WParam=idOk then begin
              ShowFPS      := (SendMessage(GetDlgItem(Dialog, dShowFPSID),  BM_GETCHECK, 0, 0) = 1);
              UnSortPoints := (SendMessage(GetDlgItem(Dialog, dUnSortID),   BM_GETCHECK, 0, 0) = 1);
              MouseSens    := (SendMessage(GetDlgItem(Dialog, dMouseSens),  BM_GETCHECK, 0, 0) = 1);
              Move3D       := (SendMessage(GetDlgItem(Dialog, dMove3DID),   BM_GETCHECK, 0, 0) = 1);
              UseDDraw     := (SendMessage(GetDlgItem(Dialog, dUseDDrawID), BM_GETCHECK, 0, 0) = 1);
              PointSize    := SendMessage(GetDlgItem(Dialog, dPointSize), CB_GETCURSEL, 0, 0) + 1;
              ProcPriority := SendMessage(GetDlgItem(Dialog, dProcPriority), CB_GETCURSEL, 0, 0);
              Regist;
            end;
            EndDialog(Dialog, 1);
            Exit;
          end;
        dMorph3DMail :
          ShellExecute(0, nil, 'mailto:morph3d@mail.ru', nil, nil, SW_NORMAL);
        dMorph3DSite :
          ShellExecute(0, nil, 'http://morph3d.narod.ru', nil, nil, SW_NORMAL);
      end;
  end;
  Result := False;
end;

procedure Wnd_Create(hWindow : hWnd; var Msg : TWMCreate);
begin
  Msg.Result := 0;
  SecStart := GetTickCount;
  LastFrameTime := SecStart;
  LastTickCount := SecStart;
  Frame := 0;
  FramePrev := 0;
  CurrentFPS.Digit := 0;
  CurrentFPS.StrLen := 0;

  InitAllShapes;

  DoDraw := True;
  InitShape(PCoords1);
  CalcPos;
end;

procedure Wnd_Size(hWindow : hWnd; var Msg : TWMSize);
begin
  DeleteObject(MainWndDC);
  DeleteObject(MainWndCompDC);
  DeleteObject(DCBitmap);

  GetClientRect(hWindow, WndRect);
  MainWndDC := GetDC(hWindow);

  MainWndCompDC := CreateCompatibleDC(MainWndDC);
  SetTextColor(MainWndCompDC, clWhite);
  DCBitmap := CreateCompatibleBitmap(MainWndDC, WndRect.Right, WndRect.Bottom);
  SelectObject(MainWndCompDC, DCBitmap);

  SetBkColor(MainWndCompDC, clBlack); // полная очистка экрана / erase full screen
  ExtTextOut(MainWndCompDC, 0, 0, ETO_OPAQUE, @WndRect, nil, 0, nil);

  InitDrawParam(WndRect);

  LastTickCount := GetTickCount;
end;

procedure Wnd_Destroy;
begin
  If CheckPassword then
  begin
    QuitSaver := True;

    DeleteObject(DCBitmap);
    DeleteObject(MainWndCompDC);
    ReleaseDC(hWindow, MainWndDC);
    DoDraw := False;

    PostQuitMessage(0);
  end;
end;

function WindowProc(Window : HWnd; AMessage, WParam, LParam : Longint) : Longint; stdcall; export;
var
  AMsg: TMessage;
  X, Y : Integer;
begin
  AMsg.Msg := AMessage;
  AMsg.WParam := WParam;
  AMsg.LParam := LParam;
  AMsg.Result := 0;

  case AMessage of
    WM_SYSCOMMAND :
      If WParam = SC_CLOSE then Wnd_Destroy;

    WM_CREATE :
      Wnd_Create(Window, TWMCreate(AMsg));

    WM_DESTROY :
      Wnd_Destroy;

    WM_KEYDOWN, WM_MOUSEWHEEL, WM_LBUTTONDOWN, WM_RBUTTONDOWN :
      If not Preview then Wnd_Destroy;

    wm_MouseMove :
      if (not Preview) and MouseSens then begin
        SetWindowPos(hWindow, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
        Inc(MoveCounter);
        X := LoWord(LParam);
        Y := HiWord(LParam);
        if (MoveCounter > 4) then begin
          if (sqrt(sqr(X-OldX) + sqr(Y-OldY)) > 1) then PostMessage(Window, WM_CLOSE, 0, 0);
        end;
        OldX := X;
        OldY := Y;
        ShowCursor(False);
      end;

    WM_PAINT, WM_TIMER:
      If DoDraw then UpdateDisplay;

    wm_NCDestroy, wm_KillFocus :
      DoDraw := False;
    wm_setFocus :
      DoDraw := True;
    wm_size :
      Wnd_Size(Window, TWMSize(AMsg));
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

procedure MainProc;
var
  hr: Integer;
  wr: TRect;
  bpp, w, h, fmt: Integer;
begin
  If FindWindow(AppName, 'Morph3D Screen Saver')<>0 then Exit;

  if not DoRegister then begin
    MessageBox(0, 'Unable to Register Window Class !', '', mb_Ok or MB_ICONERROR);
    Exit;
  end;

  //ShowFPS := True;
  //UseDDraw := True;
  //DbgPrint('Point Size = %d', PointSize);

  // узнаём количество десктопов
  cMonitors := GetSystemMetrics(SM_CMONITORS);
  //DbgPrint('cMonitors = %d', cMonitors);

  // при различных десктопах отключаем DDraw
  //fmt := GetSystemMetrics(SM_SAMEDISPLAYFORMAT);
  //if fmt = 0 then UseDDraw := False;
  //DbgPrint('Same displays = %d', fmt);

  // узнаём глубину цвета
  bpp := GetDeviceCaps(GetDC(0), BITSPIXEL);
  if (bpp <> 16) and (bpp <> 24) and (bpp <> 32) then UseDDraw := False;

  // узнаём размеры десктопа
  w := GetDeviceCaps(GetDC(0), HORZRES);
  h := GetDeviceCaps(GetDC(0), VERTRES);
  //DbgPrint('Display: Width = %d  Height = %d  BPP = %d', w, h, bpp);

  FillChar(R, SizeOf(R), 0);
  ParentWnd := 0;
  If (ParamS = 'P') or (ParamS = 'p') then begin   // превьюшка / preview mode
    ParentWnd := StrToInt(ParamStr(2));
    GetWindowRect(ParentWnd, R);
    Preview := True;
    UseDDraw := False;
  end;

  If not Preview then begin
    if PointSize > 10 then PointSize := 10;
    ActiveWnd := GetActiveWindow;
    if (ActiveWnd = FindWindow('Shell_TrayWnd', nil)) then ActiveWnd := 0;
    hWindow := CreateWindowEx(WS_EX_TOOLWINDOW or WS_EX_APPWINDOW, AppName, AppName, WS_POPUP,
      0, 0, R.Right-R.Left, R.Bottom-R.Top, ParentWnd, 0, HInstance, nil);
  end else begin
    PointSize := 1;
    hWindow := CreateWindow(AppName, AppName, ws_Child or ws_Visible or ws_Disabled,
      0, 0, R.Right-R.Left, R.Bottom-R.Top, ParentWnd, 0, HInstance, nil);
  end;

  if hWindow = 0 then begin
    MessageBox(0, 'Unable to Create a Window', '', mb_Ok or MB_ICONERROR);
    Exit;
  end;

  If not Preview then begin
    ShowCursor(False);
    ShowWindow(hWindow, SW_SHOWMAXIMIZED);
    SetWindowPos(hWindow, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
  end else begin
    ShowWindow(hWindow, SW_SHOWNORMAL);
  end;

  UpdateWindow(hWindow);

  g_iBpp := 32;
  If not Preview then begin
    if UseDDraw then begin
      if not DDInit(hWindow) then begin
        MessageBox(0, 'ERROR: Unable to create DirectDraw', '', mb_Ok or MB_ICONERROR);
        Exit;
      end;
      hr := DDCreateSurfaces(hWindow, w, h, bpp);
      //DbgPrint('DDCreateSurfaces: %08x', hr);
      if hr <> 0 then begin
        MessageBox(0, 'ERROR: Unable to create DirectDraw', '', mb_Ok or MB_ICONERROR);
        Exit;
      end;
    end;
    if (ProcPriority <> 2) and (ProcPriority >= 0) and (ProcPriority <= High(PriorityList)) then begin
      SetPriorityClass(GetCurrentProcess, PriorityList[ProcPriority]);
    end;
  end;

  SetTimer(hWindow, 0, 10, nil);       // менее 10 мсек указывать нельзя !!!

  If not Preview then
    SystemParametersInfo(SPI_SCREENSAVERRUNNING, 1, @Dummy, 0);

  while GetMessage(Msg, 0, 0, 0) do begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;

  SystemParametersInfo(SPI_SCREENSAVERRUNNING, 0, @Dummy, 0);
  
  //If not Preview then InvalidateRect(0, nil, False);
end;

begin
  Randomize;

  ParamS := ParamStr(1);
  If Length(ParamS) > 1 then Delete(ParamS, 1, 1);

  GetReg;

  //DialogBox(hInstance, 'About', 0, @About);
  //Exit;

  If (ParamS = 'A') or (ParamS = 'a') then begin
    SetPassword;
  end else
  If (ParamS = 'S') or (ParamS = 's') then begin
    Preview := False;
    MainProc;
  end else
  if (ParamS = 'P') or (ParamS = 'p') then begin
    Preview := True;
    MainProc;
  end else begin
    DialogBox(hInstance, 'About', 0, @About);
  end;

  SetActiveWindow(ActiveWnd);
end.
