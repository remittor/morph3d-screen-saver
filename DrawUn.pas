unit DrawUn;

interface

uses Windows, MorphUn;

var
  SCX : Float = 0; // Относительное смещение начала координат
  SCY : Float = 0; // Moving of the beginning of the coordinates center
  SCZ : Float = 0; //

  ScrX : Integer;  // Абсолютные координаты относительного начала координат
  ScrY : Integer;  // Absolute 2D-coordinates of coordinates center
   
  CoefX : Float;    // Коэффициент умножения - перевод относительных
  //CoefY : Float;  // координат в абсолютные / Multiply coefficient for
                    // counting absolute coordinates

const
  cVectX = 0.00093; // Проекции вектора движения центра отсчета начала координат
  cVectY = 0.00111; // Horizontal and vertical projections of the vector of moving 3D-center
  cVectZ = 0.00180; //

  cVectRotMin = 0.25;
  cVectRotMax = 0.59;
  cVectRotDelta = cVectRotMax - cVectRotMin;

  WaitPer = 4000; // Период превращения фигур
                  // Time of the figure transformation

var
  VectX : Float = cVectX;
  VectY : Float = cVectY;
  VectZ : Float = cVectZ;

  // начальные значения величин
  VectAX : Float = cVectRotMin + 0.1;   // Поворот (pi) фигуры за 1 секунду
  VectAY : Float = cVectRotMin;         // Rotation (pi) of the figure per 1 second
  VectAZ : Float = 0;

var
  LimitPosX: Float;
  LimitPosY: Float;

  LimitRect: TRect;
  CrossScreenX: Boolean = False;    // признак нахождения одной из точек за пределами экрана
  CrossScreenY: Boolean = False;    // признак нахождения одной из точек за пределами экрана

var
  xa, ya, za : Float;  // Углы поворота вокруг начала координат
                       // Rotate angles around the beginning of the coordinates

  Shapes: TShapesArr;     // начальные координаты
  ShapesPCnt: TShapePCnt;

  PCoords1: TCoords3DArr;
  PCoords2: TCoords3DArr;

  Points: TCoords3DArr;      // текущие координаты текущей фигуры

const
  CamZ = 10;        // Положение камеры(точки свода лучей) - (0, 0, CamZ)
                    // Z-coordinate of camera - (X=0, Y=0, Z=CamZ)

  ColorZ0 = 1.732;  // 3^0.5 Координата для расчета цвета точки
                    // 3^0.5 Coordinate for the calculation of
                    // the color of the point

  FogCoef = 64;     // Коэффициент тумана / Fog coefficient
  

procedure InitDrawParam(const WndRect: TRect);  
procedure DrawScreen;

implementation

uses ShapeUn, FuncUn, DirectDrawUn;


procedure InitDrawParam(const WndRect: TRect);
begin
  ScrX  := WndRect.Right  div 2;
  ScrY  := WndRect.Bottom div 2;

  CoefX := WndRect.Right / 8.5;
  //CoefY := WndRect.Bottom / 6.0;

  LimitPosX := 2.75;
  LimitPosY := LimitPosX * ScrY / ScrX;

  LimitRect.Left   := 1;
  LimitRect.Top    := 1;
  LimitRect.Right  := WndRect.Right - LimitRect.Left - 1;
  LimitRect.Bottom := WndRect.Bottom - LimitRect.Top - 1;
end;

procedure DrawPoint(Coords2D : TCoords2D; Color : TColor);
var
  Rect : TRect;
begin
  Rect.Left   := Coords2d.X;
  Rect.Top    := Coords2d.Y;
  Rect.Right  := Coords2d.X + PointSize;
  Rect.Bottom := Coords2d.Y + PointSize;
  SetBkColor(MainWndCompDC, Color);
  if UseDDraw then begin
    DDPutRect(Rect, DWORD(Color));
  end else begin
    ExtTextOut(MainWndCompDC, 0, 0, ETO_OPAQUE, @Rect, nil, 0, nil);
  end;
end;

function GetCoords2D(const Coords3D : TCoords3D) : TCoords2D;
// Движок скринсейвера / Screen Saver's engine
var
  ZNorm, x, s: Float;
begin
  s := Coords3D.Z + SCZ;
  //if (s = CamZ) then Exit;
  ZNorm := 1.0 - s / CamZ;
  x := CoefX / ZNorm;
  Result.X := Round((Coords3D.X + SCX) * x) + ScrX;
  Result.Y := Round((Coords3D.Y + SCY) * x) + ScrY;
  if (Result.X <= LimitRect.Left) or (Result.X >= LimitRect.Right)  then CrossScreenX := True;
  if (Result.Y <= LimitRect.Top)  or (Result.Y >= LimitRect.Bottom) then CrossScreenY := True;
end;

function Rotate3D(const Coords3D : TCoords3D) : TCoords3D;
var
  sina, cosa : Float;
  p1, p2: TCoords3D;
begin
  sina := sin(xa);
  cosa := cos(xa);
  p1.X := Coords3D.X;
  p1.Y := Coords3D.Y*cosa - Coords3D.Z*sina;
  p1.Z := Coords3D.Y*sina + Coords3D.Z*cosa;

  sina := sin(ya);
  cosa := cos(ya);
  Result.X :=  p1.X*cosa + p1.Z*sina;
  Result.Y :=  p1.Y;
  Result.Z := -p1.X*sina + p1.Z*cosa;

  // --- угол  za  всегда 0 !!! -----
  //sina := sin(za);
  //cosa := cos(za);
  //Result.X := p2.X*cosa - p2.Y*sina;
  //Result.Y := p2.X*sina + p2.Y*cosa;
  //Result.Z := p2.Z;
end;

(* // orignal function
function GetColor(Coords3D : TCoords3D) : TColor;
var
  Len : Float;
  R, G, B, Gr : Integer;
begin
  Len := sqrt(sqr(Coords3D.X-0) + sqr(Coords3D.Y-0) + sqr(Coords3D.Z-ColorZ0));
  Gr := Trunc(255-Len*FogCoef);
  If Gr<0 then Gr := 0;

  R := Gr;
  G := Gr;
  B := Gr;

  Result := RGB(R, G, B);
  // Перевод RGB в оттенок серого
  // Translation RGB to the hue of gray
end;
*)

// optimized function
function GetColor(const Coords3D : TCoords3D) : TColor;
var
  x: Integer;
  a: Byte absolute x;
begin
  x := MaxZero(255 - AbsL(Round((ColorZ0 - Coords3D.Z)*FogCoef)));
  if g_iBpp > 16 then begin
    Result := a or (a shl 8) or (a shl 16);
  end else begin
    x := x shr 3;   // 8bit to 5bit
    Result := a or (a shl 6) or (a shl 11);     // 5bit + 6 bit + 5bit
  end;
end;

procedure DrawScreen; // прорисовка экрана / procedure of screen drawing
var
  n, e : Integer;
  Point : TCoords3D;
  Color : TColor;
  dwTimeDelta : DWORD;
  TimeDelta : Float;
  k: Float;
  //mx, my: Float;
const
  MaxTimeDelta = 34;  // 30 FPS !!!
begin
  dwTimeDelta := FrameTimeDelta;
  PrevFrameTime := CurrFrameTime;
  
  if PerfCounter then begin
    TimeDelta := FrameTimeDelta2;
    if TimeDelta > MaxTimeDelta then TimeDelta := MaxTimeDelta;
    PrevFrameTime2 := CurrFrameTime2;
  end else begin
    if LimitFPS then begin
      dwTimeDelta := FramePeriodList[(CurrentFPS.Frame-1) and $03FF];
    end else begin
      if dwTimeDelta > MaxTimeDelta then dwTimeDelta := MaxTimeDelta;
    end;
    TimeDelta := dwTimeDelta;
  end;

{$IFDEF DBGLOG}
  // ------- for testing !!! --------
  if LimitFPS then begin
    Inc(LastTimeCount);
    if PerfCounter then k := 0.5 else k := 1.7;
    if abs(FrameTimeDelta2 - LastTimeDelta2) > k then begin
      DbgPrint('time = %d  count = %d', Trunc(LastTimeDelta2*1000.0), LastTimeCount);
      LastTimeDelta2 := FrameTimeDelta2;
      LastTimeCount := 0;
    end;
  end;  
  // --------------------------------
{$ENDIF}

  If Wait > 0 then begin
    Wait := Wait - TimeDelta;
  end else begin
    System.RandSeed := CurrFrameTime;
    If DoUp then begin
      Percent := Percent + TimeDelta/15;   // выдаётся 1.5 секунды на перерождение фигуры
      If Percent >= 100.0 then begin
        Percent := 100.0;
        DoUp := False;
        Wait := WaitPer;
        InitShape(PCoords1);
      end;
    end else begin
      Percent := Percent - TimeDelta/15;
      If Percent <= 0.0 then begin
        Percent := 0.0;
        DoUp := True;
        Wait := WaitPer;
        InitShape(PCoords2);
      end;
    end;
    CalcPos;   // перерождение фигуры
  end;

  k := (TimeDelta * pi) / 1000;
  xa := xa + VectAX * k;
  ya := ya + VectAY * k;
  //za := za - VectAZ * k;    // всегда 0 !!!

  SCX := SCX + VectX * TimeDelta;
  //if Move3D then mx := 3.5 - SCZ/2.5 else mx := LimitPosX;
  //if abs(SCX) > mx then begin
  if CrossScreenX then begin
    if SCX > 0.0 then begin
      VectX  := -cVectX;
      VectAY := -(cVectRotMin + cVectRotDelta*Random);
    end else begin
      VectX  := cVectX;
      VectAY := cVectRotMin + cVectRotDelta*Random;
    end;
    CrossScreenX := False;
  end;

  SCY := SCY + VectY * TimeDelta;
  //if Move3D then my := 3.0 - SCZ/2.0 else my := LimitPosY;
  //if abs(SCY) > my then begin
  if CrossScreenY then begin
    if SCY > 0.0 then begin
      VectY  := -cVectY;
      VectAX := -(cVectRotMin + cVectRotDelta*Random);
    end else begin
      VectY  := cVectY;
      VectAX := cVectRotMin + cVectRotDelta*Random;
    end;
    CrossScreenY := False;  
  end;

  If Move3D then begin
    SCZ := SCZ + VectZ * TimeDelta;
    If SCZ > 4.0 then begin
      VectZ  := -cVectZ;
      VectAX := -(cVectRotMin + cVectRotDelta*Random);
      VectAY := -(cVectRotMin + cVectRotDelta*Random);
    end else
    If SCZ < -10.0 then begin
      VectZ  := cVectZ;
      VectAX := cVectRotMin + cVectRotDelta*Random;
      VectAY := cVectRotMin + cVectRotDelta*Random;
    end;
  end;

  e := ShapesPCnt[ShapeInd] - 1;
  for n := 0 to e do begin
    Point := Rotate3D(Points[n]);
    DrawPoint(GetCoords2D(Point), GetColor(Point));
  end;
end;

end.
