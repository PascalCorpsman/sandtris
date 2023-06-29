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
  Classes, SysUtils, Graphics, upieces, ufifo;

Const
  WorldWidth = PieceWidth * 10;
  WorldHeight = PieceHeight * 18;

Type

  TGameState = (
    gsPause // Black Screen
    , gsGaming // Das Spiel Läuft
    );

  TPixelColor = Record
    R, G, B: Single;
  End;

  TPixelData = Record
    Occupied: Boolean; // True = Der Pixel existiert, false = das Feld ist leer
    Controllable: Boolean; // Wenn True, dann kann der Spieler diesen Pixel mittels der Tastatur "beeinflussen"
    Colorindex: Byte; // 0,1,2,3 = Eindeutige Farbkennung für interne Berechnungen
    Color: TPixelColor; // "Farbe" die der User sieht (Schattierungen der Farbkennung, siehe upieces.pas)
    FloodFillIndex: integer; // -1 = Nicht genutzt
  End;

  TSubPiece = Record
    Location: TPoint; // Position im Spielfeld
    ColorIndex: Byte; // 0,1,2,3 = Eindeutige Farbkennung für interne Berechnungen
    Color: TPixelColor; // "Farbe" die der User sieht (Schattierungen der Farbkennung, siehe upieces.pas)
  End;

  TPiece = Array[0..4 * 64 - 1] Of TSubPiece; // 4 Teile a 64-Pixels

  TCoordFifo = specialize TBufferedFifo < TPoint > ;

  { TSandTris }

  TSandTris = Class
  private
    fFifo: TCoordFifo;
    fKeys: Array[-1..1] Of Boolean; // Puffer für Links / Rechts Taste
    fGameState: TGameState;
    fArrea: Array Of Array Of TPixelData; // Das Spielfeld der einzelnen "Sandkörnchen"
    fRotationPoint: Tpoint;
    LastMoveControllableTime,
      LastMovePixelDataTime: UInt64; // Der Letzte Zeitpunkt an dem "moveData" Aktiv war


    Function ExtractPieceFromField(Out Piece: TPiece): Boolean; // Schneidet das Aktuelle Controllable aus dem Spielfeld aus und gibt es als Piece zurück, false wenn das nicht ging..
    Procedure DeletePieceFromField; // Löscht alles was "Teil" ist vom Feld (nach einem Gescheiterten Turn / Move ...
    Procedure AddPieceToField(Const Piece: TPiece); // Fügt Piece ungeprüft ein

    Procedure MovePixelData;
    Procedure MovePeace();

    Function AddPixel(Location: TPoint; Color: TColor; ColorIndex: Byte): Boolean;

    Procedure CreateNextPeace(); // Erzeugt ein neues Preview Teil
    Function PlaceNextPeace(): Boolean; // Plaziert das Aktuelle Previewteil und Berechnet ein neues, false wenn das Teil nicht mehr plaziert werden konnte.

    Procedure CheckForFinishedRows;
    Procedure EndGame();
  public
    Points: integer; // Die Aktuelle Punktzahl des Spielers
    NextPiece: TVoxels; // Das Nächste Teil, welches gesetzt wird
    OnEndGameEvent: TNotifyEvent;
    OnStartGameEvent: TNotifyEvent;
    OnNextPreviewPieceEvent: TNotifyEvent;
    OnPointsEvent: TNotifyEvent;

    Constructor Create(); virtual;
    Destructor Destroy(); override;

    Procedure Render();

    Procedure Init(); // Resets the whole game to its init state = Blank Screen
    Procedure Start(); // Start a new Game

    Procedure Turn(Dir: integer); // Dreht den Aktuellen Block 1 = 90 Grad gegen Uhrzeiger, -1 = 90 mit Uhrzeiger
    Procedure SetKey(Dir: integer; State: Boolean); // Dir = links, rechts, State = An / Aus
    Procedure DropDown();
  End;

Implementation

Uses dglOpenGL;

Const
  GravityRefreshRate = 25; // in ms 25
  MoveRefreshRate = 15;

  { TSandTris }

Constructor TSandTris.Create;
Var
  i, j: Integer;
Begin
  Inherited create;
  fFifo := TCoordFifo.create(WorldWidth * WorldHeight * 64);
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

Destructor TSandTris.Destroy();
Begin
  fFifo.Free;
  setlength(fArrea, 0, 0);
End;

Function TSandTris.ExtractPieceFromField(Out Piece: TPiece): Boolean;
Var
  index, i, j: Integer;
Begin
  index := 0;
  For i := 0 To WorldWidth - 1 Do Begin
    For j := 0 To WorldHeight - 1 Do Begin
      If fArrea[i, j].occupied And fArrea[i, j].Controllable Then Begin
        Piece[index].ColorIndex := fArrea[i, j].Colorindex;
        Piece[index].Location := point(i, j);
        Piece[index].Color := fArrea[i, j].Color;
        inc(index);
        fArrea[i, j].occupied := false;
      End;
    End;
  End;
  result := index = length(Piece);
  // Dieser Code darf eigentlich nie ausgeführt werden..
  // Aber wenn doch, dann stellen wir das gerade ausgeschnittene Teil wieder her !
  If Not result Then Begin
    For i := 0 To index - 1 Do Begin
      fArrea[Piece[i].Location.X, Piece[i].Location.y].occupied := true;
    End;
  End;
End;

Procedure TSandTris.DeletePieceFromField;
Var
  k, j: Integer;
Begin
  For k := 0 To WorldWidth - 1 Do Begin
    For j := 0 To WorldHeight - 1 Do Begin
      If fArrea[k, j].occupied And fArrea[k, j].Controllable Then Begin
        fArrea[k, j].occupied := false;
      End;
    End;
  End;
End;

Procedure TSandTris.AddPieceToField(Const Piece: TPiece);
Var
  k: Integer;
  nx, ny: LongInt;
Begin
  For k := 0 To high(Piece) Do Begin
    nx := Piece[k].Location.X;
    ny := Piece[k].Location.Y;
    fArrea[nx, ny].occupied := true;
    fArrea[nx, ny].Colorindex := Piece[k].ColorIndex;
    fArrea[nx, ny].Color := Piece[k].Color;
    fArrea[nx, ny].Controllable := true;
  End;
End;

Procedure TSandTris.MovePixelData;
Var
  j, i, iter, k, l: Integer;
  delta, iterations: QWord;
Begin
  If GetTickCount64 - LastMovePixelDataTime > GravityRefreshRate Then Begin
    delta := GetTickCount64 - LastMovePixelDataTime;
    iterations := delta Div GravityRefreshRate;
    LastMovePixelDataTime := LastMovePixelDataTime + iterations * GravityRefreshRate;
    For iter := 0 To iterations - 1 Do Begin
      fRotationPoint.y := fRotationPoint.y + 1; // Der "Drehpunkt" des fällt ja auch mit ;)
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
              If fArrea[i, j].Controllable Then Begin
                // Damit wird die Kontrolle über alle Blöcke entzogen!
                For k := 0 To WorldWidth - 1 Do Begin
                  For l := 0 To WorldHeight - 1 Do Begin
                    fArrea[k, l].Controllable := false;
                  End;
                End;
                If Not PlaceNextPeace() Then Begin
                  EndGame();
                  exit;
                End;
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
    End;
    (*
     * Eigentlich sollte der Check innerhalb der Iter Schleife sein, aber da der Check doch Recht Rechenaufwändig
     * ist, machen wir den nach den "Iterations", der User sollte den Unterschied eh nicht sehen ...
     *)
    // TODO: Check for Colors to be "Cleared"
    CheckForFinishedRows;
  End;
End;

Procedure TSandTris.MovePeace;
Var
  delta: QWord;
  iterations, iter, dx, i, nx: integer;
  Piece: TPiece;
  ny: LongInt;
Begin
  If GetTickCount64 - LastMoveControllableTime > MoveRefreshRate Then Begin
    delta := GetTickCount64 - LastMoveControllableTime;
    iterations := delta Div MoveRefreshRate;
    LastMoveControllableTime := LastMoveControllableTime + iterations * MoveRefreshRate;
    // Bestimmen der Verschiebungsrichtung
    dx := 0;
    If fKeys[-1] Then dx := -1;
    If fKeys[1] Then dx := 1;
    If dx = 0 Then exit; // Keine Verschiebung Gewünscht -> Raus
    For iter := 0 To iterations - 1 Do Begin
      // 1. Raus schneiden des Teiles
      If Not ExtractPieceFromField(Piece) Then exit;
      // 2. Verschoben einfügen
      For i := 0 To high(Piece) Do Begin
        nx := Piece[i].Location.X + dx;
        ny := Piece[i].Location.Y;
        If (nx < 0) Or (ny < 0) Or (nx >= WorldWidth) Or (ny >= WorldHeight) Or fArrea[nx, ny].occupied Then Begin
          // 2.1 Einfügen ist gescheitetert ->
          DeletePieceFromField;
          AddPieceToField(Piece);
          exit;
        End
        Else Begin
          fArrea[nx, ny].occupied := true;
          fArrea[nx, ny].Colorindex := Piece[i].ColorIndex;
          fArrea[nx, ny].Color := Piece[i].Color;
          fArrea[nx, ny].Controllable := true;
        End;
      End;
    End;
    CheckForFinishedRows;
  End;
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
        MovePeace();
        // 1. Move all Pixels
        MovePixelData();


        // 2. Render them
        glbegin(GL_POINTS);
        For i := 0 To WorldWidth - 1 Do Begin
          For j := 0 To WorldHeight - 1 Do Begin
            If fArrea[i, j].occupied Then Begin
              glcolor3f(fArrea[i, j].Color.R, fArrea[i, j].Color.G, fArrea[i, j].Color.B);
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
  LastMoveControllableTime := GetTickCount64;
  LastMovePixelDataTime := GetTickCount64;
  For i := low(fKeys) To high(fKeys) Do Begin
    fKeys[i] := false;
  End;
End;

Procedure TSandTris.Turn(Dir: integer);
Var
  Piece: TPiece;
  i, nx, ny: Integer;
Begin
  // 1. Raus schneiden des Teiles
  If Not ExtractPieceFromField(Piece) Then exit;
  // 2. Gedreht einfügen
  For i := 0 To high(Piece) Do Begin
    nx := (Piece[i].Location.Y - fRotationPoint.Y) * -1 * dir + fRotationPoint.x;
    ny := (Piece[i].Location.x - fRotationPoint.x) * dir + fRotationPoint.Y;
    If (nx < 0) Or (ny < 0) Or (nx >= WorldWidth) Or (ny >= WorldHeight) Or fArrea[nx, ny].occupied Then Begin
      // 2.1 Einfügen ist gescheitetert ->
      DeletePieceFromField;
      AddPieceToField(Piece);
      exit;
    End
    Else Begin
      fArrea[nx, ny].occupied := true;
      fArrea[nx, ny].Colorindex := Piece[i].ColorIndex;
      fArrea[nx, ny].Color := Piece[i].Color;
      fArrea[nx, ny].Controllable := true;
    End;
  End;
  CheckForFinishedRows;
End;

Procedure TSandTris.SetKey(Dir: integer; State: Boolean);
Begin
  fKeys[dir] := State;
End;

Procedure TSandTris.DropDown;
Var
  Piece: TPiece;
  nx, ny: LongInt;
  i, j: Integer;
Begin
  While ExtractPieceFromField(Piece) Do Begin
    For i := 0 To high(Piece) Do Begin
      nx := Piece[i].Location.X;
      ny := Piece[i].Location.Y + 1;
      If (nx < 0) Or (ny < 0) Or (nx >= WorldWidth) Or (ny >= WorldHeight) Or fArrea[nx, ny].occupied Then Begin
        // 2.1 Einfügen ist gescheitetert ->
        DeletePieceFromField;
        AddPieceToField(Piece);
        // Das Controllable nehmen wir weg, wir sind ja nun unten
        For j := 0 To high(Piece) Do Begin
          fArrea[Piece[j].Location.x, Piece[j].Location.y].Controllable := false;
        End;
        PlaceNextPeace;
        CheckForFinishedRows;
        exit;
      End
      Else Begin
        fArrea[nx, ny].occupied := true;
        fArrea[nx, ny].Colorindex := Piece[i].ColorIndex;
        fArrea[nx, ny].Color := Piece[i].Color;
        fArrea[nx, ny].Controllable := true;
      End;
    End;
  End;
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
  fArrea[Location.x, Location.Y].Color.R := (color And $FF) / $FF;
  fArrea[Location.x, Location.Y].Color.G := ((color Shr 8) And $FF) / $FF;
  fArrea[Location.x, Location.Y].Color.B := ((color Shr 16) And $FF) / $FF;
  fArrea[Location.x, Location.Y].Controllable := true;
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
      NextPiece.Pixels[i].Color, NextPiece.Pixels[i].ColorIndex) Then Begin
      result := false;
      exit;
    End;
  End;
  fRotationPoint.x := NextPiece.RotationPoint.x + WorldWidth Div 2;
  fRotationPoint.Y := NextPiece.RotationPoint.y + PieceHeight * 2;
  CreateNextPeace();
End;

Procedure TSandTris.CheckForFinishedRows;
Var
  i, j: Integer;
  Found: Boolean;
  p: TPoint;
Begin
  // TODO: Implementieren
  // 1. Alle Alten Floodfill Themen Löschen
  For i := 0 To WorldWidth - 1 Do Begin
    For j := 0 To WorldHeight - 1 Do Begin
      fArrea[i, j].FloodFillIndex := -1;
    End;
  End;
  For j := WorldHeight - 1 Downto 0 Do Begin
    // Nur Belegte und noch nicht betrachtete Felder Werden befüllt.
    If fArrea[0, j].Occupied And (fArrea[0, j].FloodFillIndex = -1) Then Begin
      fFifo.Clear; // -- Eigentlich unnötig
      fFifo.Push(point(0, j));
      Found := false;
      While Not fFifo.isempty Do Begin
        p := fFifo.Pop;
        If fArrea[p.x, p.y].Occupied And (fArrea[p.x, p.y].FloodFillIndex = -1) Then Begin
          hier gehts weiter
        End;
      End;
    End;
  End;
End;

Procedure TSandTris.EndGame;
Begin
  fGameState := gsPause;
  OnEndGameEvent(self);
End;


End.

