unit AboutUn;

interface

uses Windows, Messages;

const
  dShowFPSID   = 256; // Окно настроек- показ "кадр/с"
                      // Identificator of checkbox "FPS"

  dLimitFPS    = 303;

  dUnSortID    = 257; // Окно настроек - сортированиие точек
                      // Identificator of checkbox "UnSort"

  dMouseSens   = 258; // Окно настроек - чувствительность мышки
                      // Identificator of spinedit "Mouse Sensivity"

  dMove3DID    = 259; // Окно настроек - перемещение объекта в 3-х мерном пространстве
                      // Identificator of spinedit "Move in 3D"

  dPerfCounter = 302;

  dUseDDrawID  = 300; // Окно настроек - рисовать через DirectDraw

  dUseVSync    = 301;


  dPointSize   = 400; // Окно настроек - размер точки

  dProcPriority = 401; // Окно настроек - приоритет процесса

  dMorph3DMail = 260; // Окно настроек - e-mail
                      // Identificator of button "morph3d@mail.ru"

  dMorph3DSite = 261; // Окно настроек - сайт
                      // Identificator of button "http://morph3d.nm.ru"

                      
procedure GetReg;

function About(Dialog: HWnd; AMessage, WParam: UINT; LParam: LPARAM): Bool; stdcall; export;                      

const
  RegKey = 'Software\Morph3D';


implementation

uses MorphUn, ShellApi;


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
  LimitFPS     := Boolean(GetRegParam(hReg, 'LimitFPS', 1));
  PerfCounter  := Boolean(GetRegParam(hReg, 'PerformanceCounter', 0));
  UseDDraw     := Boolean(GetRegParam(hReg, 'UseDirectDraw', 0));
  UseVSync     := Boolean(GetRegParam(hReg, 'UseVSync', 0));
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
  SetRegParam(hReg, 'LimitFPS',      DWORD(LimitFPS));
  SetRegParam(hReg, 'PerformanceCounter', DWORD(PerfCounter));
  SetRegParam(hReg, 'UseDirectDraw', DWORD(UseDDraw));
  SetRegParam(hReg, 'UseVSync',      DWORD(UseVSync));
  SetRegParam(hReg, 'PointSize',     PointSize);
  SetRegParam(hReg, 'ProcessPriority', ProcPriority);
  RegCloseKey(hReg);
end;

function InitAbout(Dialog: HWnd): Integer;
var
  h: HWND;
begin
  SendMessage(GetDlgItem(Dialog, dShowFPSID),   BM_SETCHECK, Integer(ShowFPS),      0);
  SendMessage(GetDlgItem(Dialog, dUnSortID),    BM_SETCHECK, Integer(UnSortPoints), 0);
  SendMessage(GetDlgItem(Dialog, dMouseSens),   BM_SETCHECK, Integer(MouseSens),    0);
  SendMessage(GetDlgItem(Dialog, dMove3DID),    BM_SETCHECK, Integer(Move3D),       0);

  SendMessage(GetDlgItem(Dialog, dLimitFPS),    BM_SETCHECK, Integer(LimitFPS),     0);
  SendMessage(GetDlgItem(Dialog, dPerfCounter), BM_SETCHECK, Integer(PerfCounter),  0);
  SendMessage(GetDlgItem(Dialog, dUseDDrawID),  BM_SETCHECK, Integer(UseDDraw),     0);

  if UseDDraw then begin
    EnableWindow(GetDlgItem(Dialog, dUseVSync), True);
    SendMessage(GetDlgItem(Dialog, dUseVSync), BM_SETCHECK, Integer(UseVSync), 0);
  end;

  h := GetDlgItem(Dialog, dPointSize);
  SendMessage(h, CB_ADDSTRING, 0, Integer(PChar('1'#0)));
  SendMessage(h, CB_ADDSTRING, 0, Integer(PChar('2'#0)));
  SendMessage(h, CB_ADDSTRING, 0, Integer(PChar('3'#0)));
  SendMessage(h, CB_ADDSTRING, 0, Integer(PChar('4'#0)));
  SendMessage(h, CB_ADDSTRING, 0, Integer(PChar('5'#0)));
  SendMessage(h, CB_ADDSTRING, 0, Integer(PChar('6'#0)));
  SendMessage(h, CB_SETCURSEL, PointSize-1, 0);

  h := GetDlgItem(Dialog, dProcPriority);
  SendMessage(h, CB_ADDSTRING, 0, Integer(PChar('Idle'#0)));
  SendMessage(h, CB_ADDSTRING, 0, Integer(PChar('Below Normal'#0)));
  SendMessage(h, CB_ADDSTRING, 0, Integer(PChar('Normal'#0)));
  SendMessage(h, CB_ADDSTRING, 0, Integer(PChar('Above Normal'#0)));
  SendMessage(h, CB_ADDSTRING, 0, Integer(PChar('High'#0)));
  SendMessage(h, CB_SETCURSEL, ProcPriority, 0);

  Result := 0;
end;

function AboutToReg(Dialog: HWnd): Integer;
begin
  ShowFPS      := (SendMessage(GetDlgItem(Dialog, dShowFPSID),   BM_GETCHECK, 0, 0) = 1);
  UnSortPoints := (SendMessage(GetDlgItem(Dialog, dUnSortID),    BM_GETCHECK, 0, 0) = 1);
  MouseSens    := (SendMessage(GetDlgItem(Dialog, dMouseSens),   BM_GETCHECK, 0, 0) = 1);
  Move3D       := (SendMessage(GetDlgItem(Dialog, dMove3DID),    BM_GETCHECK, 0, 0) = 1);

  LimitFPS     := (SendMessage(GetDlgItem(Dialog, dLimitFPS),    BM_GETCHECK, 0, 0) = 1);
  PerfCounter  := (SendMessage(GetDlgItem(Dialog, dPerfCounter), BM_GETCHECK, 0, 0) = 1);
  UseDDraw     := (SendMessage(GetDlgItem(Dialog, dUseDDrawID),  BM_GETCHECK, 0, 0) = 1);
  UseVSync     := (SendMessage(GetDlgItem(Dialog, dUseVSync),    BM_GETCHECK, 0, 0) = 1);

  PointSize    := SendMessage(GetDlgItem(Dialog, dPointSize), CB_GETCURSEL, 0, 0) + 1;
  ProcPriority := SendMessage(GetDlgItem(Dialog, dProcPriority), CB_GETCURSEL, 0, 0);

  Regist;    // save parameters to registry
  Result := 0;
end;

function About(Dialog: HWnd; AMessage, WParam: UINT; LParam: LPARAM): Bool; stdcall; export;
var
  st: Boolean;
begin
  Result := True;
  case AMessage of
    wm_InitDialog :
      InitAbout(Dialog);

    wm_Command:
      Case WParam of
        idOk, idCancel :
          begin
            if WParam = idOk then AboutToReg(Dialog);
            EndDialog(Dialog, 1);
            Exit;
          end;
        dUseDDrawID :
          begin;
            st := (SendMessage(GetDlgItem(Dialog, dUseDDrawID), BM_GETCHECK, 0, 0) = 1);
            if not st then SendMessage(GetDlgItem(Dialog, dUseVSync), BM_SETCHECK, 0, 0);
            EnableWindow(GetDlgItem(Dialog, dUseVSync), st);
          end;
        dMorph3DMail :
          ShellExecute(0, nil, 'mailto:morph3d@mail.ru', nil, nil, SW_NORMAL);
        dMorph3DSite :
          ShellExecute(0, nil, 'http://morph3d.narod.ru', nil, nil, SW_NORMAL);
      end;
  end;
  Result := False;
end;

end.
