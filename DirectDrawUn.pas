unit DirectDrawUn;

interface

uses Windows, DirectX;

{$DEFINE USEDD7}

var
  g_iBpp: DWORD = 0;                      // Remember the main surface bit depth
{$IFNDEF USEDD7}
  g_pDD: IDirectDraw = nil;               // The DirectDraw object
  g_pDDS: IDirectDrawSurface = nil;       // Primary surface
  g_pDDSBack: IDirectDrawSurface = nil;   // Back surface
{$ENDIF}
{$IFDEF USEDD7}
  g_pDDBase: IDirectDraw = nil;
  g_pDD: IDirectDraw7 = nil;               // The DirectDraw object
  g_pDDS: IDirectDrawSurface7 = nil;       // Primary surface
  g_pDDSBack: IDirectDrawSurface7 = nil;   // Back surface
{$ENDIF}


function  DDInit(hWnd: HWND): Boolean;
function  DDCreateSurfaces(hWnd: HWND; dwWidth, dwHeight, dwBpp: DWORD): Integer;
procedure DDDestroySurfaces;
procedure DDDone;
function  DDPutPixel(x, y: Integer; c: DWORD): Integer;
function  DDPutRect(const rect: TRect; c: DWORD): Integer;
function  CheckSurfaces: Integer;
function  DDFlip: Integer;



implementation

// Initialize DirectDraw stuff
function DDInit(hWnd: HWND): Boolean;
var
  hr: Integer;
begin
  // Initialize DirectDraw
{$IFNDEF USEDD7}
  hr := DirectDrawCreate(nil, g_pDD, nil);
  if hr <> 0 then Result := False else Result := True;
{$ELSE}
  hr := DirectDrawCreate(nil, g_pDDBase, nil);
  if hr <> 0 then Result := False else Result := True;
  hr := g_pDDBase.QueryInterface(IID_IDirectDraw7, g_pDD);
  if hr <> 0 then Result := False else Result := True;
{$ENDIF}
end;

// Create surfaces
function DDCreateSurfaces(hWnd: HWND; dwWidth, dwHeight, dwBpp: DWORD): Integer;
var
  hr: Integer;
{$IFDEF USEDD7}
  ddsd: DDSURFACEDESC2;   // A structure to describe the surfaces we want
  BackBufferCaps: TDDSCaps2;
{$ELSE}
  ddsd: DDSURFACEDESC;   // A structure to describe the surfaces we want
  BackBufferCaps: TDDSCaps;
{$ENDIF}
begin
  Result := DDERR_NODC;
  if dwBpp < 16 then begin Result := DDERR_NOBLTHW; Exit; end;

  // Set the "cooperative level" so we can use full-screen mode
  hr := g_pDD.SetCooperativeLevel(hWnd, DDSCL_EXCLUSIVE or DDSCL_FULLSCREEN or DDSCL_NOWINDOWCHANGES);
  if hr <> 0 then begin Result := hr; Exit; end;

  OutputDebugStringA('SetDisplayMode ... ');
  // Set full-screen mode
  hr := g_pDD.SetDisplayMode(dwWidth, dwHeight, dwBpp {$IFDEF USEDD7}, 0, 0 {$ENDIF});
  OutputDebugStringA('SetDisplayMode Finish ');
  if hr <> 0 then begin Result := hr; Exit; end;

  // Clear all members of the structure to 0
  FillChar(ddsd, sizeof(ddsd), 0);
  // The first parameter of the structure must contain the size of the structure
  ddsd.dwSize := sizeof(ddsd);

  //-- Create the primary surface
  ddsd.dwFlags := DDSD_CAPS or DDSD_BACKBUFFERCOUNT;
  ddsd.dwBackBufferCount := 1;
  ddsd.ddsCaps.dwCaps := DDSCAPS_PRIMARYSURFACE or DDSCAPS_FLIP or DDSCAPS_COMPLEX;

  hr := g_pDD.CreateSurface(ddsd, g_pDDS, nil);
  if hr <> 0 then begin Result := hr; Exit; end;

  FillChar(BackBufferCaps, sizeof(BackBufferCaps), 0);
  BackBufferCaps.dwCaps := DDSCAPS_BACKBUFFER;
  hr := g_pDDS.GetAttachedSurface(BackBufferCaps, g_pDDSBack);
  if hr <> 0 then begin Result := hr; Exit; end;

  //-- Lock back buffer to retrieve surface information
  if g_pDDSBack <> nil then begin
    hr := g_pDDSBack.Lock(nil, ddsd, DDLOCK_WAIT, 0);
    if hr <> 0 then begin Result := hr; Exit; end;

    // Store bit depth of surface
    g_iBpp := ddsd.ddpfPixelFormat.dwRGBBitCount;

    // Unlock surface
    hr := g_pDDSBack.Unlock(nil);
    if hr <> 0 then begin Result := hr; Exit; end;
  end;

  Result := 0;
end;

// Destroy surfaces
procedure DDDestroySurfaces;
begin
  // fix me
end;

// Clean up DirectDraw stuff
procedure DDDone;
begin
{$IFNDEF USEDD7}
  if g_pDD <> nil then begin g_pDD._Release; g_pDD := nil; end;
{$ELSE}
  if g_pDD <> nil then begin g_pDD._Release; g_pDD := nil; end;
  if g_pDDBase <> nil then begin g_pDDBase._Release; g_pDDBase := nil; end;
{$ENDIF}
end;

// PutPixel routine for a DirectDraw surface
function DDPutPixel(x, y: Integer; c: DWORD): Integer;
var
  hr: Integer;
  ddbfx: DDBLTFX;
  rcDest: TRect;
begin
  // Initialize the DDBLTFX structure with the pixel color
  ddbfx.dwSize := sizeof(ddbfx);
  ddbfx.dwFillColor := c;
  // Prepare the destination rectangle as a 1x1 (1 pixel) rectangle
  Windows.SetRect(rcDest, x, y, x+1, y+1);
  // Blit 1x1 rectangle using solid color op
  Result := g_pDDSBack.Blt(rcDest, nil, PRect(nil)^, DDBLT_WAIT or DDBLT_COLORFILL, ddbfx);
end;

function DDPutRect(const rect: TRect; c: DWORD): Integer;
var
  hr: Integer;
  ddbfx: DDBLTFX;
begin
  // Initialize the DDBLTFX structure with the pixel color
  ddbfx.dwSize := sizeof(ddbfx);
  ddbfx.dwFillColor := c;
  // Blit 1x1 rectangle using solid color op
  Result := g_pDDSBack.Blt(rect, nil, PRect(nil)^, DDBLT_WAIT or DDBLT_COLORFILL, ddbfx);
end;

// Checks if the memory associated with surfaces is lost and restores if necessary.
function CheckSurfaces: Integer;
begin
  Result := 0;
  // Check the primary surface
  if g_pDDS <> nil then begin
    if g_pDDS.IsLost = DDERR_SURFACELOST then Result := g_pDDS.Restore;
  end;
  // Check the back buffer
  if g_pDDSBack <> nil then begin
    if g_pDDSBack.IsLost = DDERR_SURFACELOST then Result := g_pDDSBack.Restore;
  end;
end;

// Double buffering flip
function DDFlip: Integer;
var
  hr: Integer;
begin
  Result := g_pDDS.Flip(nil, DDFLIP_WAIT);
end;


end.
