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
  Windows, Messages, 
  AboutUn, PasswUn,
  MorphUn, DrawUn, ShapeUn, FuncUn, DirectDrawUn;

{$E scr}

{$R *.RES}
{$R dialog.res}

const
  USER_TIMER_MINIMUM = 10;
  ABOVE_NORMAL_PRIORITY_CLASS  = $00008000;
  BELOW_NORMAL_PRIORITY_CLASS  = $00004000;
  ENUM_CURRENT_SETTINGS = $FFFFFFFF;

var
  MoveCounter : Integer = -1;
  ParamS      : String;
  Dummy       : DWord;
  ParentWnd   : hWnd;
  ActiveWnd   : hWnd=0;
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

function StrPas(S: PChar) : String;
begin
  Result := S;
end;

procedure Wnd_Create(hWindow : hWnd; var Msg : TWMCreate);
begin
  Msg.Result := 0;
  SecStart := GetTickCount;
  PrevFrameTime := SecStart;

  CurrentFPS.Frame := DWORD(-1);
  CurrentFPS.FirstFrameTime := SecStart;
  CurrentFPS.TimeDelta := 0;
  CurrentFPS.TimeDelta2 := 0;
  CurrentFPS.Digit := 0;
  CurrentFPS.StrLen := 0;

  SecStart2 := 0;
  {$IFDEF DBGLOG}
  Windows.QueryPerformanceCounter(SecStart2);
  {$ENDIF}
  if PerfCounter then Windows.QueryPerformanceCounter(SecStart2);
  PrevFrameTime2 := SecStart2;
  CurrentFPS.FirstFrameTime2 := SecStart2;

  InitAllShapes;

  InitShape(PCoords1);
  CalcPos;
  DoDraw := True;
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

  PrevFrameTime := SecStart;
  if PerfCounter then PrevFrameTime2 := SecStart2;
end;

procedure Wnd_Destroy;
begin
  if Preview then begin
    DoDraw := False;
    QuitSaver := True;
  end else begin  
    DoDraw := False;
    if CheckPassword(hWindow) then begin
      QuitSaver := True;
      DeleteObject(DCBitmap);
      DeleteObject(MainWndCompDC);
      ReleaseDC(hWindow, MainWndDC);
      PostQuitMessage(0);
    end else begin
      DoDraw := True;
    end;
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
          if AbsL(X-OldX) + AbsL(Y-OldY) > 1 then PostMessage(Window, WM_CLOSE, 0, 0);
        end;
        OldX := X;
        OldY := Y;
        ShowCursor(False);
      end;

    //WM_PAINT, WM_TIMER:
    //  If DoDraw and (not UseNtDelay) then UpdateDisplay;

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

procedure TimerCallBack(uTimerID: DWORD; uMessage: DWORD; dwUser: DWORD; dw1, dw2: DWORD) stdcall;
begin
  if not DoDraw then Exit;
  UpdateDisplay;
end;

procedure MainProc;
var
  Msg: TMsg;
  R: TRect;
  i, hr: Integer;
  wr: TRect;
  bpp, w, h, fmt: Integer;
  sx, sy: Integer;
  MinRes: DWORD;  // Minimum timer resolution
  MaxRes: DWORD;
  ActRes: DWORD;  // Current timer resolution
  fActRes: Float;
  delay: Int64;
  CurrFrameEnd: Int64;
  DoDraw2: Boolean;
  //Display: TDisplayDevice;
  DispMode: TDevMode;
  fp, xp: Float;
  ip: Integer; 
begin
  If FindWindow(AppName, 'Morph3D Screen Saver')<>0 then Exit;

  if not DoRegister then begin
    MessageBox(0, 'Unable to Register Window Class !', '', mb_Ok or MB_ICONERROR);
    Exit;
  end;

  (* // ------- for testing !!! --------
  ShowFPS := Boolean(1);
  UseDDraw := Boolean(1);
  PerfCounter := Boolean(1);
  UseNtDelay := Boolean(1);
  LimitFPS := Boolean(1);
  UseVSync := Boolean(1);
  ProcPriority := 4;
  // --------------------------------
  *)

  FillChar(R, SizeOf(R), 0);
  if Preview then begin   // превьюшка / preview mode
    GetWindowRect(ParentWnd, R);
    Preview     := True;
    ShowFPS     := False;
    LimitFPS    := True;
    PerfCounter := False;
    UseDDraw    := False;
    UseNtDelay  := False;
    UseVSync    := False;
    PointSize   := 1;
    ProcPriority := 2;     // normal
    cMonitors   := 1;
    DisplayFreq := 62;
    FramePeriod := 16.0;   // 62 FPS
    FrameDelay := 16.0;
  end else begin
    // корректируем параметры, полученные из реестра
    if PointSize > 10 then PointSize := 10;
    if PointSize <= 0 then PointSize := 1;
    if ProcPriority > 0 then ProcPriority := High(PriorityList);

    DbgPrint('Point Size = %d', PointSize);
    
    // при использовании функции NtDelayExecution нам просто необходимо точно измерять время !!!
    //if UseNtDelay then PerfCounter := True;

    // коли уж используем высокоточное время, то будем использовать и высокоточную задержку !!!
    if PerfCounter then UseNtDelay := True;

    // синхронизация картинки возможна только в режиме DirectDraw !!!
    if UseVSync and (not UseDDraw) then UseVSync := False;

    // при вертикальной синхронизации на уровне DirectDraw контроль за FPS не нужен (протестировано)
    if UseVSync then LimitFPS := False;

    {$IFDEF DBGLOG}
    Windows.QueryPerformanceFrequency(PerfFreq64);
    PerfCoef := 1000.0 / PerfFreq64;
    {$ENDIF}

    // система может не поддерживать высокоточный таймер
    if PerfCounter then PerfCounter := Boolean(Windows.QueryPerformanceCounter(PerfFreq64));
    if PerfCounter then PerfCounter := Boolean(Windows.QueryPerformanceFrequency(PerfFreq64));
    if PerfCounter then PerfCoef := 1000.0 / PerfFreq64;
    DbgPrint('PerfCounter = %d  PerfFreq64 = %d', Integer(PerfCounter), Integer(PerfFreq64));

    // использование высокоточной задержки не имеет смысла без возможности получения точного времени !!!
    if (not PerfCounter) then UseNtDelay  := False;
    DbgPrint('UseNtDelay = %d  ', Integer(UseNtDelay));

    // Get timer resolutions
    NtQueryTimerResolution(MinRes, MaxRes, ActRes);
    DbgPrint('TimerResolution: Min = %d  Max = %d  Current = %d', MinRes, MaxRes, ActRes);

    //FillChar(Display, sizeof(Display), 0);
    //if EnumDisplayDevices(nil, 0, Display, 0) then begin
    FillChar(DispMode, sizeof(DispMode), 0);
    if not EnumDisplaySettings(nil, ENUM_CURRENT_SETTINGS, DispMode) then begin
      FillChar(DispMode, sizeof(DispMode), 0);
    end;
    DbgPrint('Disp Info: ResX = %d  ResY = %d  BPP = %d  Freq = %d', DispMode.dmPelsWidth, DispMode.dmPelsHeight, DispMode.dmBitsPerPel, DispMode.dmDisplayFrequency);
    DisplayFreq := DispMode.dmDisplayFrequency;
    if DisplayFreq < 8   then DisplayFreq := 60;    // при странных значениях выставляем 60 FPS !!!
    if DisplayFreq < 30  then DisplayFreq := 30;    // меньше 30 Hz не видел
    if DisplayFreq > 120 then DisplayFreq := 120;   // более 120 Hz трудно представить
    DbgPrint('DisplayFreq = %d ', DisplayFreq);

    FramePeriod := 1000.0 / DisplayFreq;
    DbgPrint('FramePeriod = %d ', Trunc(FramePeriod*1000.0));

    // узнаём количество десктопов
    //cMonitors := GetSystemMetrics(SM_CMONITORS);
    //DbgPrint('cMonitors = %d', cMonitors);

    // при различных десктопах отключаем DDraw
    //fmt := GetSystemMetrics(SM_SAMEDISPLAYFORMAT);
    //if fmt = 0 then UseDDraw := False;
    //DbgPrint('Same displays = %d', fmt);

    // узнаём размеры десктопа и глубину цвета
    w := GetDeviceCaps(GetDC(0), HORZRES);
    h := GetDeviceCaps(GetDC(0), VERTRES);
    bpp := GetDeviceCaps(GetDC(0), BITSPIXEL);
    DbgPrint('Display: Width = %d  Height = %d  BPP = %d', w, h, bpp);
  end;

  DbgPrint('LimitFPS = %d ', Integer(LimitFPS));
  if LimitFPS then begin
    if not Preview then begin
      fActRes := ActRes / 10000.0;
      // В функцию Sleep и NtDelayExecuter следует передавать значение, которое чуть меньше FramePeriod и кратно значению параметра ActRes !!!
      FramePeriod := Trunc(FramePeriod / fActRes) * fActRes;
      FrameDelay := Trunc(FramePeriod);
    end;
    if not PerfCounter then begin
      FramePeriod := FrameDelay;
      fp := 0;
      i := 0;
      ip := 0;
      for i:=0 to High(FrameDelayList) do begin
        fp := fp + FramePeriod;
        xp := fp - ip;
        FramePeriodList[i] := Trunc(xp);
        FrameDelayList[i] := Trunc(xp - 0.5);     // 0.5 ms отдадим на сам процесс отрисовки кадра, погрешность Sleep, вспом. процессы
        ip := ip + Trunc(xp);
      end;
    end;
  end;

  DbgPrint('FramePeriod = %d ', Trunc(FramePeriod*1000.0));

  sx := R.Right - R.Left;
  sy := R.Bottom - R.Top;
  if not Preview then begin
    ActiveWnd := GetActiveWindow;
    if (ActiveWnd = FindWindow('Shell_TrayWnd', nil)) then ActiveWnd := 0;
    hWindow := CreateWindowEx(WS_EX_TOOLWINDOW or WS_EX_APPWINDOW, AppName, AppName, WS_POPUP, 0, 0, sx, sy, ParentWnd, 0, HInstance, nil);
  end else begin
    hWindow := CreateWindow(AppName, AppName, ws_Child or ws_Visible or ws_Disabled, 0, 0, sx, sy, ParentWnd, 0, HInstance, nil);
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
  if UseDDraw then begin
    if not DDInit(hWindow) then begin
      MessageBox(0, 'ERROR: Unable to create DirectDraw', '', mb_Ok or MB_ICONERROR);
      Exit;
    end;
    hr := DDCreateSurfaces(hWindow, w, h, bpp, UseVSync);
    if hr <> 0 then begin
      MessageBox(0, 'ERROR: Unable to create DirectDraw surfaces', '', mb_Ok or MB_ICONERROR);
      Exit;
    end;
  end;

  if not Preview then begin
    SetPriorityClass(GetCurrentProcess, PriorityList[ProcPriority]);
    SystemParametersInfo(SPI_SCREENSAVERRUNNING, 1, @Dummy, 0);
  end;

  while (not QuitSaver) do begin
    DoDraw2 := DoDraw;
    if DoDraw2 then begin
      UpdateDisplay;
    end;
    while PeekMessage(Msg, hWindow, 0, 0, PM_REMOVE) do begin
      TranslateMessage(Msg);
      DispatchMessage(Msg);
    end;
    if DoDraw2 then begin
      if LimitFPS then begin
        if UseNtDelay then begin
          Windows.QueryPerformanceCounter(CurrFrameEnd);
          fp := FramePeriod - (CurrFrameEnd - CurrFrameTime2)*PerfCoef;
          delay := Trunc(-10000.0 * fp);
          if fp >= 0 then NtDelayExecution(False, delay);
        end else
        if PerfCounter then begin
          Windows.QueryPerformanceCounter(CurrFrameEnd);
          delay := Trunc(FramePeriod - (CurrFrameEnd - CurrFrameTime2)*PerfCoef);
          if delay >= 0 then Sleep(delay);
        end else begin
          Sleep(FrameDelayList[CurrentFPS.Frame]);
        end;
      end else begin
        Sleep(0);
      end;
    end;
  end;

  {$IFDEF DBGLOG}
  DbgPrint('TIME = %d  Count = %d', Trunc(LastTimeDelta2*1000.0), LastTimeCount);
  {$ENDIF}

  SystemParametersInfo(SPI_SCREENSAVERRUNNING, 0, @Dummy, 0);

  //If not Preview then InvalidateRect(0, nil, False);
end;

begin
  Randomize;

  ParentWnd := 0;
  ParamS := ParamStr(1);
  If Length(ParamS) > 1 then Delete(ParamS, 1, 1);

  // ------- for testing !!! --------
  //GetReg;
  //DialogBox(hInstance, 'About', 0, @About);
  //Exit;
  // --------------------------------

  If (ParamS = 'A') or (ParamS = 'a') then begin
    ParentWnd := StrToInt(ParamStr(2));
    SetPassword(ParentWnd);
  end else
  If (ParamS = 'S') or (ParamS = 's') then begin
    GetReg;
    Preview := False;
    MainProc;
  end else
  if (ParamS = 'P') or (ParamS = 'p') then begin
    ParentWnd := StrToInt(ParamStr(2));
    GetReg;
    Preview := True;
    MainProc;
  end else begin
    GetReg;
    DialogBox(hInstance, 'About', 0, @About);
  end;

  SetActiveWindow(ActiveWnd);
end.
