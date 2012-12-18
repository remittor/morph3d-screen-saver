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
    Digit: DWORD;
    Str: array [0..31] of Char;
    StrLen: Integer;
  end;

var
  hWindow             : hWnd;
  DoDraw              : Boolean = False;

  CurrentFPS          : TCurrentFPS;
  FramePrev           : DWORD;       // число фреймов в предыдущий квант времени
  Frame               : DWORD;       // число фреймов за текущий квант времени
  SecStart            : DWORD;       // время запуска скринсейвера
  LastFrameTime       : DWORD;       // время последнего сброса Frame
  FrameTime           : DWORD;       // текущее время отрисовки экрана
  LastTickCount       : DWORD;

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

  QuitSaver           : Boolean = False;

  Preview             : Boolean = False;
  ShowFPS             : Boolean = False;
  UnSortPoints        : Boolean = False;
  MouseSens           : Boolean = True;
  Move3D              : Boolean = False;
  UseDDraw            : Boolean = False;
  PointSize           : Integer = 4;    // 4px
  ProcPriority        : DWORD = 2;      // normal


  
implementation

uses DrawUn, ShapeUn, FuncUn, DirectDrawUn;


procedure PrintFPS(DC: HDC; X, Y: Integer);
var
  TimeDelta: DWORD;
  fps: DWORD;
begin
  TimeDelta := FrameTime - LastFrameTime;
  if (TimeDelta >= 1000) then begin
    FramePrev := Frame;
    fps := (Frame * 1000) div TimeDelta;
    CurrentFPS.Str[16] := #0;
    CurrentFPS.StrLen := FuncUn.wsprintf(CurrentFPS.Str, '%i FPS     ', fps);
    CurrentFPS.Digit := fps;
    Frame := 0;
    LastFrameTime := FrameTime;
  end;
  if CurrentFPS.StrLen > 0 then begin
    TextOutA(DC, X, Y, CurrentFPS.Str, CurrentFPS.StrLen);
  end;
end;

procedure UpdateDisplay;
var
  LastRect : TRect;
  g_dc: HDC;
begin
  FrameTime := GetTickCount;
  Inc(Frame);

  if UseDDraw then begin
    CheckSurfaces;                // Check for lost surfaces
    DDPutRect(WndRect, clBlack);  // Clear the back buffer
  end else begin
    SetBkColor(MainWndCompDC, clBlack); // очистка экрана / erase screen
    ExtTextOut(MainWndCompDC, 0, 0, ETO_OPAQUE, @WndRect, nil, 0, nil);
  end;

  If (not Preview) and (ShowFPS) then begin
    if UseDDraw then begin
      g_pDDSBack.GetDC(g_dc);
      SetBkColor(g_dc, clBlack);
      SetTextColor(g_dc, clYellow);
      PrintFPS(g_dc, 10, 10);
      g_pDDSBack.ReleaseDC(g_dc);
    end else begin
      PrintFPS(MainWndCompDC, 10, 10);
    end;
  end;

  DrawScreen;

  if UseDDraw then begin
    // Blit the back buffer to the front buffer
    DDFlip;
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









