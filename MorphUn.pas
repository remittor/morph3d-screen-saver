unit MorphUn;

interface

uses Windows, Messages;

type
  Float = Single;

type
  TColor = -$7FFFFFFF-1..$7FFFFFFF;

const
  clBlack = TColor($000000);
  clWhite = TColor($FFFFFF);
  clYellow = TColor($00FFFF);

  PointsCount = 200;      // максимальное количество точек на 1 фигуру

  shCount = 17;           // общее количество фигур

type
  TCoords3D = record
    X, Y, Z : Float;
  end;

  TCoords2D = record
    X, Y : Integer;
  end;

  PCoords3DArr = ^TCoords3DArr;
  TCoords3DArr = array [0..PointsCount-1] of TCoords3D;

  PShapesArr = ^TShapesArr;
  TShapesArr = array [0..shCount-1] of TCoords3DArr;

  PShapePCnt = ^TShapePCnt;
  TShapePCnt = array [0..shCount-1] of Integer;

procedure UpdateDisplay;
function  XYZ(X, Y, Z : Float) : TCoords3D;
procedure AddPoint(var CoordsArr : TCoords3DArr; Coords : TCoords3D); overload;
procedure AddPoint(var CoordsArr : TCoords3DArr; X, Y, Z : Float); overload;
procedure AddPointsBetween(var CoordsArr : TCoords3DArr; Index1, Index2, Num : Integer);
procedure AddPointBetween3(var CoordsArr : TCoords3DArr; const Coords1 : TCoords3D; const Coords2 : TCoords3D; const Coords3 : TCoords3D);
procedure DupPoint(var CoordsArr : TCoords3DArr; Index : Integer);

const
  FrameHistMax = 10;

type
  TCurrentFPS = record
    Frame: DWORD;            // число фреймов за текущий квант времени (1 секунда)
    FirstFrameTime: DWORD;   // начало отрисовки первого фрейма
    FirstFrameTime2: Float;
    TimeDelta: DWORD;        // время, прошедшее с начала отрисовки первого фрейма
    TimeDelta2: Float;
    Digit: DWORD;            // число фреймов на предыдущем кванте (предыдущая секунда)
    StrLen: Integer;
    Str: array [0..31] of Char;  // символьное представление Digit 
  end;

var
  hWindow             : hWnd;
  DoDraw              : Boolean = False;
  
  CurrentFPS          : TCurrentFPS;
  
  SecStart            : DWORD;       // время запуска скринсейвера
  CurrFrameTime       : DWORD;       // текущее время отрисовки экрана
  PrevFrameTime       : DWORD;
  FrameTimeDelta      : DWORD;

  PerfFreq64          : Int64;
  PerfCoef            : Float;       // коэффициент для преобразования PerfCounter в миллисекунды
  SecStart2           : Int64;
  CurrFrameTime2      : Int64;       // текущее время отрисовки экрана
  PrevFrameTime2      : Int64;
  FrameTimeDelta2     : Float;

  MainWndDC           : HDC;
  MainWndCompDC       : HDC;
  DCBitmap, OldBitmap : HBITMAP;
  Rect, WndRect       : TRect;

  PIndex              : Integer = 0;
  CurShape            : PCoords3DArr;
  CurShape1           : PCoords3DArr;
  CurShape2           : PCoords3DArr;

  DoUp                : Boolean;
  Wait, Percent       : Float;

  cMonitors           : Integer;
  DisplayFreq         : Integer = 0;  // частота основного дисплея
  FramePeriod         : Float;        // переод отрисовки кадров (ms)
  FrameDelay          : Float;        // задержка, используемая в Sleep и NtDelayExecution
  FrameDelayList      : array [0..1023] of Integer;  // задержки на каждый кадр, используемые при UseNtDelay = False
  FramePeriodList     : array [0..1023] of Integer;  // прогнозируемые интервалы отображения кадров

  QuitSaver           : Boolean = False;

  Preview             : Boolean = False;
  ShowFPS             : Boolean = False;
  UnSortPoints        : Boolean = False;
  MouseSens           : Boolean = True;
  Move3D              : Boolean = False;
  UseDDraw            : Boolean = False;
  LimitFPS            : Boolean = True;
  PerfCounter         : Boolean = False;
  UseNtDelay          : Boolean = False;
  UseVSync            : Boolean = False; // only DirectDraw mode !!!
  PointSize           : Integer = 4;     // 4px
  ProcPriority        : DWORD = 2;       // normal

{$IFDEF DBGLOG}
  // ------- for testing !!! --------
  LastTimeDelta2: Float = 0.0;
  LastTimeCount: DWORD;
  // --------------------------------
{$ENDIF}

implementation

uses DrawUn, ShapeUn, FuncUn, DirectDrawUn;


procedure PrintFPS(DC: HDC; X, Y: Integer; ChangeValue: Boolean);
begin
  if ChangeValue and (CurrentFPS.Frame >= 1) then begin
    CurrentFPS.Digit := CurrentFPS.Frame - 1;
    CurrentFPS.Str[16] := #0;
    CurrentFPS.StrLen := FuncUn.wsprintf(CurrentFPS.Str, '%i FPS  ', CurrentFPS.Digit);
  end;
  if CurrentFPS.StrLen > 0 then TextOutA(DC, X, Y, CurrentFPS.Str, CurrentFPS.StrLen);
end;

procedure UpdateDisplay;
var
  LastRect: TRect;
  NeedResetFrame: Boolean;
  xdc: HDC;
begin
  NeedResetFrame := False;
  Inc(CurrentFPS.Frame);
  CurrFrameTime := GetTickCount;
  FrameTimeDelta := CurrFrameTime - PrevFrameTime;
  CurrentFPS.TimeDelta := CurrFrameTime - CurrentFPS.FirstFrameTime;

  if PerfCounter then begin
    Windows.QueryPerformanceCounter(CurrFrameTime2);
    FrameTimeDelta2 := (CurrFrameTime2 - PrevFrameTime2) * PerfCoef;
    //if LimitFPS and (FrameTimeDelta2 < 0.5) then begin
    //  DbgPrint('WARNING: TimeDelta2 < 0.5 (%d)', Trunc(FrameTimeDelta2*1000.0));
    //end;
    CurrentFPS.TimeDelta2 := (CurrFrameTime2 - CurrentFPS.FirstFrameTime2) * PerfCoef;
    if CurrentFPS.TimeDelta2 >= 1000.0 then NeedResetFrame := True;
  end else begin
    {$IFDEF DBGLOG}
    Windows.QueryPerformanceCounter(CurrFrameTime2);
    FrameTimeDelta2 := (CurrFrameTime2 - PrevFrameTime2) * PerfCoef;
    PrevFrameTime2 := CurrFrameTime2;
    {$ENDIF}
    if CurrentFPS.TimeDelta >= 1000 then NeedResetFrame := True;
  end;    

  if UseDDraw then begin
    CheckSurfaces;                // Check for lost surfaces
    DDPutRect(WndRect, clBlack);  // Clear the back buffer
  end else begin
    SetBkColor(MainWndCompDC, clBlack); // очистка экрана / erase screen
    ExtTextOut(MainWndCompDC, 0, 0, ETO_OPAQUE, @WndRect, nil, 0, nil);
  end;

  If ShowFPS then begin
    if UseDDraw then begin
      g_pDDSBack.GetDC(xdc);
      SetBkColor(xdc, clBlack);
      SetTextColor(xdc, clYellow);
      PrintFPS(xdc, 10, 10, NeedResetFrame);
      g_pDDSBack.ReleaseDC(xdc);
    end else begin
      PrintFPS(MainWndCompDC, 10, 10, NeedResetFrame);
    end;
  end;

  if NeedResetFrame then begin
    CurrentFPS.Frame := 0;      // первый фрейм в текущей серии кадров
    CurrentFPS.FirstFrameTime := CurrFrameTime;
    CurrentFPS.FirstFrameTime2 := CurrFrameTime2;
    NeedResetFrame := False;
  end;

  DrawScreen;

  if UseDDraw then begin
    // Blit the back buffer to the front buffer
    DDFlip(UseVSync);
  end else begin
    // перерисовка на экран
    BitBlt(MainWndDC, WndRect.Left, WndRect.Top, WndRect.Right-WndRect.Left, WndRect.Bottom-WndRect.Top, MainWndCompDC, 0, 0, SRCCOPY);
  end;
end;

function XYZ(X, Y, Z : Float) : TCoords3D;
begin
  Result.X := X;
  Result.Y := Y;
  Result.Z := Z;
end;

procedure AddPoint(var CoordsArr: TCoords3DArr; Coords: TCoords3D);
begin
  if PIndex >= PointsCount then Exit;
  CoordsArr[PIndex] := Coords;
  Inc(PIndex);
end;

procedure AddPoint(var CoordsArr : TCoords3DArr; X, Y, Z : Float);
begin
  If PIndex >= PointsCount then Exit;
  CoordsArr[PIndex].X := X;
  CoordsArr[PIndex].Y := Y;
  CoordsArr[PIndex].Z := Z;
  Inc(PIndex);
end;

procedure DupPoint(var CoordsArr : TCoords3DArr; Index : Integer);
begin
  If Index >= PointsCount then Exit;
  AddPoint(CoordsArr, CoordsArr[Index]);
end;

procedure AddPointsBetween(var CoordsArr : TCoords3DArr; Index1, Index2, Num : Integer);
var
  n : Integer;
  Coords : TCoords3D;
begin
  If Num = -1 then Exit;
  For n := 1 to Num do begin
    Coords.X := CoordsArr[Index1].X + (CoordsArr[Index2].X - CoordsArr[Index1].X)*n/(Num+1);
    Coords.Y := CoordsArr[Index1].Y + (CoordsArr[Index2].Y - CoordsArr[Index1].Y)*n/(Num+1);
    Coords.Z := CoordsArr[Index1].Z + (CoordsArr[Index2].Z - CoordsArr[Index1].Z)*n/(Num+1);

    AddPoint(CoordsArr, Coords);
  end;
end;

procedure AddPointBetween3(var CoordsArr : TCoords3DArr;
                           const Coords1 : TCoords3D;
                           const Coords2 : TCoords3D;
                           const Coords3 : TCoords3D);
var
  Coords, CoordsH : TCoords3D;
begin
  //      1
  //     / \
  //    /   \
  // 2 ------- 3
  //      |
  //   CoordsH

  CoordsH.X := (Coords2.X + Coords3.X) / 2;
  CoordsH.Y := (Coords2.Y + Coords3.Y) / 2;
  CoordsH.Z := (Coords2.Z + Coords3.Z) / 2;

  Coords.X := Coords1.X + (CoordsH.X - Coords1.X)*2/3;
  Coords.Y := Coords1.Y + (CoordsH.Y - Coords1.Y)*2/3;
  Coords.Z := Coords1.Z + (CoordsH.Z - Coords1.Z)*2/3;

  AddPoint(CoordsArr, Coords);
end;

end.









