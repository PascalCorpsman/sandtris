(******************************************************************************)
(*                                                                            *)
(* Author      : Uwe Schächterle (Corpsman)                                   *)
(*                                                                            *)
(* This file is part of sandtris                                              *)
(*                                                                            *)
(*  See the file license.md, located under:                                   *)
(*  https://github.com/PascalCorpsman/Software_Licenses/blob/main/license.md  *)
(*  for details about the license.                                            *)
(*                                                                            *)
(*               It is not allowed to change or remove this text from any     *)
(*               source file of the project.                                  *)
(*                                                                            *)
(******************************************************************************)
Unit usandtris;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Graphics, upieces;

Const
  WorldWidth = PieceWidth * 10;
  WorldHeight = PieceHeight * 18;

Type

  TGameState = (
    gsPause // Black Screen
    , gsGaming // Das Spiel Läuft
    );

  TPixel = Record
    R, G, B: Single;
    Controllable: Boolean; // Kann der Pixel von Außen kontrolliert werden, for future use
  End;

  TPixelData = Record
    occupied: Boolean; // True, if Pixel is valid
    Colorindex: Byte;
    Pixel: TPixel;
  End;

  { TSandTris }

  TSandTris = Class
  private
    fGameState: TGameState;
    fArrea: Array Of Array Of TPixelData; // Das Spielfeld der einzelnen "Sandkörnchen"
    LastMoveTime: UInt64; // Der Letzte Zeitpunkt an dem "moveData" Aktiv war
    Procedure MoveData;
    Function AddPixel(Location: TPoint; Color: TColor; ColorIndex: Byte): Boolean;
    Procedure CreateNextPeace(); // Erzeugt ein neues Preview Teil
    Function PlaceNextPeace(): Boolean; // Plaziert das Aktuelle Previewteil und Berechnet ein neues, false wenn das Teil nicht mehr plaziert werden konnte.
    Procedure EndGame();
  public
    Points: integer; // Die Aktuelle Punktzahl des Spielers
    NextPiece: TPixels; // Das Nächste Teil, welches gesetzt wird
    OnEndGameEvent: TNotifyEvent;
    OnStartGameEvent: TNotifyEvent;
    OnNextPreviewPieceEvent: TNotifyEvent;
    OnPointsEvent: TNotifyEvent;
    Constructor Create();
    Procedure Render();
    Procedure Init(); // Resets the whole game to its init state = Blank Screen
    Procedure Start(); // Start a new Game
  End;

Implementation

Uses dglOpenGL;

Const
  RefreshRate = 25; // in ms

  { TSandTris }

Procedure TSandTris.MoveData;
Var
  j, i, iter, k, l: Integer;
  delta, iterations: QWord;
Begin
  If GetTickCount64 - LastMoveTime > RefreshRate Then Begin
    delta := GetTickCount64 - LastMoveTime;
    iterations := delta Div RefreshRate;
    LastMoveTime := LastMoveTime + iterations * RefreshRate;
    For iter := 0 To iterations - 1 Do Begin
      // Das Nach Links und Rechts "Gleiten"
      For i := 0 To WorldWidth - 1 Do Begin
        If fArrea[i, WorldHeight - 1].occupied Then Begin
          For j := WorldHeight - 2 Downto 1 Do Begin
            If (Not fArrea[i, j - 1].occupied) Then Begin
              // Wir haben einen Kandidaten für Links / Rechts Flow
              If (i > 0) And (Not fArrea[i - 1, j].occupied) And (Not fArrea[i - 1, j + 1].occupied) Then Begin
                fArrea[i - 1, j] := fArrea[i, j];
                fArrea[i, j].occupied := false;
              End
              Else Begin
                If (i < WorldWidth - 2) And (Not fArrea[i + 1, j].occupied) And (Not fArrea[i + 1, j + 1].occupied) Then Begin
                  //fArrea[i, j].Pixel.Moved := true;
                  fArrea[i + 1, j] := fArrea[i, j];
                  fArrea[i, j].occupied := false;
                End;
              End;
              break;
            End;
          End;
        End;
      End;
      // Die Schwerkraft
      For j := WorldHeight - 2 Downto 0 Do Begin
        For i := 0 To WorldWidth - 1 Do Begin
          // 1. Apply Gravity
          If fArrea[i, j].occupied Then Begin
            If (fArrea[i, j + 1].occupied) Then Begin
              // Ein Block, der auch "Kontrolliert" wird berührt einen "Liegenden" Block
              If fArrea[i, j].Pixel.Controllable Then Begin
                // Damit wird die Kontrolle über alle Blöcke entzogen!
                For k := 0 To WorldWidth - 1 Do Begin
                  For l := 0 To WorldHeight - 1 Do Begin
                    fArrea[k, l].Pixel.Controllable := false;
                  End;
                End;
                GameState umschalten auf xx ms warten bis der Preview gestartet wird
              End;
            End
            Else Begin
              // Der Block fällt weiter hinunter
              fArrea[i, j + 1] := fArrea[i, j];
              fArrea[i, j].occupied := false;
              Continue;
            End;
          End;
        End;
      End;
      // TODO: Check for Colors to be "Cleared"
    End;
  End;
End;

Constructor TSandTris.Create;
Var
  i, j: Integer;
Begin
  OnEndGameEvent := Nil;
  OnStartGameEvent := Nil;
  OnNextPreviewPieceEvent := Nil;
  OnPointsEvent := Nil;
  setlength(fArrea, WorldWidth, WorldHeight);
  For i := 0 To WorldWidth - 1 Do Begin
    For j := 0 To WorldHeight - 1 Do Begin
      fArrea[i, j].occupied := false;
    End;
  End;
  fGameState := gsPause;
End;

Procedure TSandTris.Render;
Var
  i, j: Integer;
Begin
  Case fGameState Of
    gsPause: Begin
        // -- Nichts
      End;
    gsGaming: Begin
        // 1. Move all Pixels
        MoveData();
        // 2. Render them
        glbegin(GL_POINTS);
        For i := 0 To WorldWidth - 1 Do Begin
          For j := 0 To WorldHeight - 1 Do Begin
            If fArrea[i, j].occupied Then Begin
              glcolor3f(fArrea[i, j].Pixel.R, fArrea[i, j].Pixel.G, fArrea[i, j].Pixel.B);
              glVertex2d(i, j);
            End;
          End;
        End;
        glEnd;
      End;
  End;
End;

Procedure TSandTris.Init;
Begin
  fGameState := gsPause;
End;

Procedure TSandTris.Start;
Var
  i, j: Integer;
Begin
  Points := 0;
  // Clear Game Field
  For i := 0 To WorldWidth - 1 Do Begin
    For j := 0 To WorldHeight - 1 Do Begin
      fArrea[i, j].occupied := false;
    End;
  End;
  OnStartGameEvent(self);
  OnPointsEvent(self);
  // Everything needed to create a new empty field
  CreateNextPeace;
  PlaceNextPeace();
  fGameState := gsGaming;
  LastMoveTime := GetTickCount64;
End;

Function TSandTris.AddPixel(Location: TPoint; Color: TColor; ColorIndex: Byte
  ): Boolean;
Begin
  result := false;
  If (Location.x < 0) Or (Location.X > high(fArrea)) Or
    (Location.Y < 0) Or (Location.Y > high(fArrea[0])) Then exit;
  If fArrea[Location.x, Location.Y].occupied Then exit;
  result := true;
  fArrea[Location.x, Location.Y].occupied := true;
  fArrea[Location.x, Location.Y].Pixel.R := (color And $FF) / $FF;
  fArrea[Location.x, Location.Y].Pixel.G := ((color Shr 8) And $FF) / $FF;
  fArrea[Location.x, Location.Y].Pixel.B := ((color Shr 16) And $FF) / $FF;
  fArrea[Location.x, Location.Y].Pixel.Controllable := true;
  fArrea[Location.x, Location.Y].Colorindex := ColorIndex;
End;

Procedure TSandTris.CreateNextPeace;
Begin
  NextPiece := GetRandomPiece();
  OnNextPreviewPieceEvent(self);
End;

Function TSandTris.PlaceNextPeace: Boolean;
Var
  i: Integer;
Begin
  result := true;
  For i := 0 To high(NextPiece.Pixels) Do Begin
    If Not AddPixel(
      point(NextPiece.Pixels[i].Location.x - NextPiece.RotationPoint.x + WorldWidth Div 2, NextPiece.Pixels[i].Location.Y - NextPiece.RotationPoint.Y + PieceHeight * 2),
      NextPiece.Pixels[i].Color, NextPiece.ColorIndex) Then Begin
      result := false;
      exit;
    End;
  End;
  CreateNextPeace();
End;

Procedure TSandTris.EndGame();
Begin
  fGameState := gsPause;
  OnEndGameEvent(self);
End;

End.





