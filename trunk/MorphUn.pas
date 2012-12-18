unit MorphUn;

interface

uses Windows, Messages;

type
  TColor = -$7FFFFFFF-1..$7FFFFFFF;
const
  clBlack = TColor($000000);
  clWhite = TColor($FFFFFF);

  PointsCount = 200;
type
  TCoords3D = record
    X, Y, Z : Single;
  end;
  TCoords2D = record
    X, Y : Integer;
  end;
  TCoords3DArr = array[0..PointsCount-1] of TCoords3D;

function  StrToInt(S : String) : Integer;
procedure UpdateDisplay;
function  XYZ(X, Y, Z : Single) : TCoords3D;
procedure AddPoint(var CoordsArr : TCoords3DArr; Coords : TCoords3D);
procedure AddPointsBetween(var CoordsArr : TCoords3DArr;
  Index1, Index2, Num : Integer);
procedure AddPointBetween3(var CoordsArr : TCoords3DArr;
  Coords1, Coords2, Coords3 : TCoords3D);  
procedure DupPoint(var CoordsArr : TCoords3DArr; Index : Integer);
function  PreviewThreadProc(Data : Integer) : Integer; StdCall;

var
  hWindow             : hWnd;
  DoDraw              : Boolean = False;
  Frame               : Integer=0;
  SecStart, SecEnd    : Integer;
  DC, CDC             : hDC;
  DCBitmap, OldBitmap : hBitmap;
  Rect, WndRect       : TRect;
  PIndex              : Integer=0;
  DoUp                : Boolean;
  Wait, Percent       : Single;
  QuitSaver           : Boolean=False;
  Preview             : Boolean=False;
  ShowFPS             : Boolean=False;
  UnSortPoints        : Boolean=False;
  MouseSens           : Boolean=True;
  Move3D              : Boolean=True;

implementation

uses DrawUn, ShapeUn;

function IntToStr(Value : Integer) : String;
var
  Int : Integer;
begin
  Result := '';
  repeat
    Int := Value mod 10;
    Value := Value div 10;
    Result := Chr(Int+48)+Result;
  until Value = 0;
end;

function StrToInt(S : String) : Integer;
var
  N : byte;
begin
  Result := 0;
  For N := 1 to Length(S) do
  begin
    Result := Result*10;
    Result := Result + (Ord(S[N])-48);
  end;
end;

function GetFPSStr : String;
var
  TimeDelta : Integer;
begin
  TimeDelta := Trunc(GetTickCount)-SecStart;
  If TimeDelta <> 0 then
    Result := IntToStr(Trunc(Frame/TimeDelta*1000))+' кадр/с'; // FPS
end;

function PreviewThreadProc(Data : Integer) : Integer; StdCall;
begin
  repeat
    InvalidateRect(hWindow, nil, False);
    Sleep(10);
  until QuitSaver;
  PostMessage(hWindow, wm_Destroy, 0, 0);
  Result := 0;
end;

procedure UpdateDisplay;
var
  LastRect : TRect;
begin
  LastRect.Left := LastLeft;
  LastRect.Right := LastRight;
  LastRect.Top := LastTop;
  LastRect.Bottom := LastBottom;

  Inc(Frame);
  SetBkColor(CDC, clBlack); // очистка экрана / erase screen
  ExtTextOut(CDC, 0, 0, ETO_OPAQUE, @LastRect, nil, 0, nil);

  If ShowFPS then // кадр/с / FPS
    TextOutA(CDC, 10, 10, PChar(GetFPSStr+'  '), Length(GetFPSStr)+2);

  LastLeft := WndRect.Right;
  LastRight := WndRect.Left;
  LastTop := WndRect.Bottom;
  LastBottom := WndRect.Top;

  DrawScreen;

  // перерисовка на экран
  BitBlt(DC, WndRect.Left, WndRect.Top, WndRect.Right-WndRect.Left,
    WndRect.Bottom-WndRect.Top, CDC, 0, 0, SRCCOPY);
end;

function XYZ(X, Y, Z : Single) : TCoords3D;
begin
  Result.X := X;
  Result.Y := Y;
  Result.Z := Z;
end;

procedure AddPoint(var CoordsArr : TCoords3DArr; Coords : TCoords3D);
begin
  If (0<=PIndex) and (PIndex<=PointsCount-1) then
    CoordsArr[PIndex] := Coords;
  Inc(PIndex);
end;

procedure DupPoint(var CoordsArr : TCoords3DArr; Index : Integer);
begin
  If Index <= PointsCount-1 then
    AddPoint(CoordsArr, CoordsArr[Index]);
end;

procedure AddPointsBetween(var CoordsArr : TCoords3DArr;
  Index1, Index2, Num : Integer);
var
  n : Integer;
  Coords : TCoords3D;
begin
  If Num <> -1 then 
  For n := 1 to Num do
  begin
    Coords.X := CoordsArr[Index1].X+(CoordsArr[Index2].X-
      CoordsArr[Index1].X)*n/(Num+1);
    Coords.Y := CoordsArr[Index1].Y+(CoordsArr[Index2].Y-
      CoordsArr[Index1].Y)*n/(Num+1);
    Coords.Z := CoordsArr[Index1].Z+(CoordsArr[Index2].Z-
      CoordsArr[Index1].Z)*n/(Num+1);

    AddPoint(CoordsArr, Coords);
  end;
end;

procedure AddPointBetween3(var CoordsArr : TCoords3DArr;
  Coords1, Coords2, Coords3 : TCoords3D);
var
  Coords, CoordsH : TCoords3D;
begin
  //      1
  //     / \
  //    /   \
  // 2 ------- 3
  //      |
  //   CoordsH

  CoordsH.X := (Coords2.X+Coords3.X) / 2;
  CoordsH.Y := (Coords2.Y+Coords3.Y) / 2;
  CoordsH.Z := (Coords2.Z+Coords3.Z) / 2;

  Coords.X := Coords1.X+(CoordsH.X-Coords1.X)*2/3;
  Coords.Y := Coords1.Y+(CoordsH.Y-Coords1.Y)*2/3;
  Coords.Z := Coords1.Z+(CoordsH.Z-Coords1.Z)*2/3;

  AddPoint(CoordsArr, Coords);
end;

end.









