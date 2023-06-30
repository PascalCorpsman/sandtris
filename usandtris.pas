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
    gsidle // Black Screen
    , gsGaming // Das Spiel Läuft
    , gsFlashPoints // Die gerade "Geschaffte" Fläche / Linie wird angezeigt
    , gsPauseGaming
    , gsPauseFlashPoints

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
    fNeedNextPeace: Boolean; // Wenn ein "Fallendes" Teil, ohne den Boden zu berühren ein LineDelete auslöst, dann muss nach der Animation ein neues Teil ausgelöst werden
    fFlashIndex: integer;
    fFifo: TCoordFifo;
    fKeys: Array[-1..1] Of Boolean; // Puffer für Links / Rechts Taste
    fGameState: TGameState;
    fArrea: Array Of Array Of TPixelData; // Das Spielfeld der einzelnen "Sandkörnchen"
    fRotationPoint: Tpoint;
    LastPauseTime,
      LastFlashTime,
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
    Procedure TogglePause();

    Procedure Turn(Dir: integer); // Dreht den Aktuellen Block 1 = 90 Grad gegen Uhrzeiger, -1 = 90 mit Uhrzeiger
    Procedure SetKey(Dir: integer; State: Boolean); // Dir = links, rechts, State = An / Aus
    Procedure DropDown();
  End;

Implementation

Uses dglOpenGL;

Const
  GravityRefreshRate = 25; // in ms 25
  MoveRefreshRate = 15;
  FlashTime = 250;

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
  fGameState := gsidle;
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
      // Variante 1 Die Pixel werden unten "rausgepresst" die Pyramiden entstehen dadurch von unten nach oben
      For i := 0 To WorldWidth - 1 Do Begin
        If fArrea[i, WorldHeight - 1].occupied Then Begin
          For j := WorldHeight - 2 Downto 1 Do Begin
            If (fArrea[i, j + 1].Occupied) And (fArrea[i, j - 1].Occupied) Then Begin
              If (i > 0) And (Not (fArrea[i - 1, j].Occupied)) Then Begin
                fArrea[i - 1, j] := fArrea[i, j];
                For k := j Downto 1 Do Begin
                  fArrea[i, k] := fArrea[i, k - 1];
                  If Not fArrea[i, k - 1].occupied Then break;
                End;
                break;
              End
              Else Begin
                If (i < WorldWidth - 1) And (Not (fArrea[i + 1, j].Occupied)) Then Begin
                  fArrea[i + 1, j] := fArrea[i, j];
                  For k := j Downto 1 Do Begin
                    fArrea[i, k] := fArrea[i, k - 1];
                    If Not fArrea[i, k - 1].occupied Then break;
                  End;
                  break;
                End
              End;
            End;
            If (Not fArrea[i, j - 1].occupied) Then Begin
              break;
            End;
          End;
        End;
      End;
      // Ende Variante 1
      // Variante 2. Die Pixel gleiten oben Ab -> Die Pyramiden entstehen von oben nach Unten
      //For i := 0 To WorldWidth - 1 Do Begin
      //  If fArrea[i, WorldHeight - 1].occupied Then Begin
      //    For j := WorldHeight - 2 Downto 1 Do Begin
      //      If (Not fArrea[i, j - 1].occupied) Then Begin
      //        // Wir haben einen Kandidaten für Links / Rechts Flow
      //        If (i > 0) And (Not fArrea[i - 1, j].occupied) And (Not fArrea[i - 1, j + 1].occupied) Then Begin
      //          fArrea[i - 1, j] := fArrea[i, j];
      //          fArrea[i, j].occupied := false;
      //        End
      //        Else Begin
      //          If (i < WorldWidth - 1) And (Not fArrea[i + 1, j].occupied) And (Not fArrea[i + 1, j + 1].occupied) Then Begin
      //            fArrea[i + 1, j] := fArrea[i, j];
      //            fArrea[i, j].occupied := false;
      //          End;
      //        End;
      //        break;
      //      End;
      //    End;
      //  End;
      //End;
      // Ende Variante 2

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
      fRotationPoint.x := fRotationPoint.x + dx;
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
  i, j, dt, ii: integer;
  UpdatePoints: Boolean;
Begin
  Case fGameState Of
    gsidle: Begin
        // -- Nichts
      End;
    gsPauseGaming,
      gsGaming: Begin
        If fGameState = gsGaming Then Begin
          If fNeedNextPeace Then Begin
            fNeedNextPeace := false;
            PlaceNextPeace;
          End;
          MovePeace();
          // 1. Move all Pixels
          MovePixelData();
        End;
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
    gsPauseFlashPoints,
      gsFlashPoints: Begin
        If fGameState = gsFlashPoints Then Begin
          dt := GetTickCount64 - LastFlashTime;
          ii := (dt * WorldWidth) Div FlashTime; // Für die Clear Animation von Links nach Rechts ;)
        End
        Else Begin
          ii := -1;
        End;
        // 2. Render them
        UpdatePoints := false;
        glbegin(GL_POINTS);
        For i := 0 To WorldWidth - 1 Do Begin
          For j := 0 To WorldHeight - 1 Do Begin
            If fArrea[i, j].occupied Then Begin
              If fFlashIndex = fArrea[i, j].FloodFillIndex Then Begin
                glcolor3f(1, 1, 1);
                If i <= ii Then Begin
                  If fArrea[i, j].Controllable Then fNeedNextPeace := true;
                  fArrea[i, j].occupied := false;
                  inc(Points);
                  UpdatePoints := true;
                End;
              End
              Else Begin
                glcolor3f(fArrea[i, j].Color.R, fArrea[i, j].Color.G, fArrea[i, j].Color.B);
              End;
              glVertex2d(i, j);
            End;
          End;
        End;
        glEnd;
        If UpdatePoints Then Begin
          OnPointsEvent(self);
        End;
        // Die "Flashzeit" ist abgelaufen
        If dt >= FlashTime Then Begin
          LastMoveControllableTime := LastMoveControllableTime + dt;
          LastMovePixelDataTime := LastMovePixelDataTime + dt;
          fGameState := gsGaming;
        End;
      End;
  End;
End;

Procedure TSandTris.Init;
Begin
  fGameState := gsidle;
End;

Procedure TSandTris.Start;
Var
  i, j: Integer;
Begin
  Points := 0;
  fNeedNextPeace := false;
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

Procedure TSandTris.TogglePause();
Var
  dt: QWord;
Begin
  Case fGameState Of
    gsGaming: Begin
        LastPauseTime := GetTickCount64;
        fGameState := gsPauseGaming;
      End;
    gsFlashPoints: Begin
        LastPauseTime := GetTickCount64;
        fGameState := gsPauseFlashPoints;
      End;
    gsPauseGaming: Begin
        fGameState := gsGaming;
        dt := GetTickCount64 - LastPauseTime;
        LastMoveControllableTime := LastMoveControllableTime + dt;
        LastMovePixelDataTime := LastMovePixelDataTime + dt;
      End;
    gsPauseFlashPoints: Begin
        fGameState := gsFlashPoints;
        dt := GetTickCount64 - LastPauseTime;
        LastFlashTime := LastFlashTime + dt;
      End;
  End;
End;

Procedure TSandTris.Turn(Dir: integer);
Var
  Piece: TPiece;
  i, nx, ny: Integer;
Begin
  If fGameState <> gsGaming Then exit;
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
  If fGameState <> gsGaming Then exit;
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
  Procedure Check(x1, y1, x2, y2: integer);
  Begin
    If // Boundary Check
    (x2 >= 0) And (x2 < WorldWidth) And (y2 >= 0) And (y2 < WorldHeight) And
      // Belegt und selbe Farbe ?
    fArrea[x2, y2].Occupied And (fArrea[x1, y1].Colorindex = fArrea[x2, y2].Colorindex) And
      // Noch nicht Besucht
    (fArrea[x2, y2].FloodFillIndex = -1)
      Then Begin
      ffifo.push(point(x2, y2));
    End;
  End;

Var
  i, j: Integer;
  Found: Boolean;
  p: TPoint;
Begin
  fFlashIndex := -1;
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
        // Der Pixel ist Belegt und noch nicht betrachtet worden !
        If fArrea[p.x, p.y].Occupied And (fArrea[p.x, p.y].FloodFillIndex = -1) Then Begin
          fArrea[p.x, p.y].FloodFillIndex := j;
          If p.x = WorldWidth - 1 Then Begin
            // Es hat geklappt, aber Dennoch müssen alle Besucht werden !
            Found := true;
            fFlashIndex := j;
            fGameState := gsFlashPoints;
            LastFlashTime := GetTickCount64;
          End;
          Check(p.x, p.y, p.x + 1, p.y);
          Check(p.x, p.y, p.x - 1, p.y);
          Check(p.x, p.y, p.x, p.y + 1);
          Check(p.x, p.y, p.x, p.y - 1);
          // TODO: Diagonalen auch ?
        End;
      End;
      If Found Then break;
    End;
  End;
End;

Procedure TSandTris.EndGame;
Begin
  fGameState := gsidle;
  OnEndGameEvent(self);
End;


End.

