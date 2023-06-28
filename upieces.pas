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
Unit upieces;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Graphics;

Const

  PieceWidth = 8;
  PieceHeight = 8;

  //                              Dark       Medium     Bright
  Green: Array[0..2] Of TColor = ($00006956, $00028971, $00069A83);
  Blue: Array[0..2] Of TColor = ($007B5837, $009F7551, $00B4845D);
  Yellow: Array[0..2] Of TColor = ($004197C0, $0061C3F2, $0076D0FF);
  Red: Array[0..2] Of TColor = ($00223987, $0029439A, $003858C9);

  Pieces: Array[0..6] Of Array[0..3] Of TPoint = (
    // XXXX
    ((x: 0; y: 0), (x: 1; y: 0), (x: 2; y: 0), (x: 3; y: 0)),
    //   X
    // XXX
    ((x: 0; y: 0), (x: 1; y: 0), (x: 2; y: 0), (x: 2; y: - 1)),
    //  X
    // XXX
    ((x: 0; y: 0), (x: 1; y: 0), (x: 1; y: - 1), (x: 2; y: 0)),
    // X
    // XXX
    ((x: 0; y: 0), (x: 0; y: - 1), (x: 1; y: 0), (x: 2; y: 0)),
    // XX
    // XX
    ((x: 0; y: 0), (x: 0; y: - 1), (x: 1; y: 0), (x: 1; y: - 1)),
    //  XX
    // XX
    ((x: 0; y: 0), (x: 1; y: 0), (x: 1; y: - 1), (x: 2; y: - 1)),
    // XX
    //  XX
    ((x: 0; y: - 1), (x: 1; y: 0), (x: 1; y: - 1), (x: 2; y: 0))
    );

  // ColorShading per Piece
  PieceSheme: Array[0..6] Of Array[0..7, 0..7] Of byte =
  (
    ((0, 0, 0, 0, 0, 0, 0, 0), // XXXX
    (0, 2, 2, 2, 1, 2, 2, 0), //
    (0, 1, 2, 2, 2, 2, 2, 0),
    (0, 2, 2, 1, 2, 2, 2, 0),
    (0, 2, 2, 2, 2, 2, 1, 0),
    (0, 2, 1, 2, 2, 2, 2, 0),
    (0, 2, 2, 2, 1, 2, 2, 0),
    (0, 0, 0, 0, 0, 0, 0, 0)),

    ((0, 0, 0, 0, 0, 0, 0, 0), //   X
    (0, 1, 1, 1, 1, 1, 1, 0), //  XXX
    (0, 1, 1, 1, 1, 1, 1, 0),
    (0, 2, 1, 1, 1, 1, 1, 0),
    (0, 2, 1, 1, 1, 1, 1, 0),
    (0, 2, 1, 1, 1, 1, 1, 0),
    (0, 2, 2, 1, 1, 1, 1, 0),
    (0, 0, 0, 0, 0, 0, 0, 0)),

    ((0, 0, 0, 0, 0, 0, 0, 0), //  X
    (0, 1, 1, 1, 1, 1, 1, 0), //  XXX
    (0, 1, 2, 2, 2, 0, 1, 0),
    (0, 1, 2, 1, 1, 0, 1, 0),
    (0, 1, 2, 1, 1, 0, 1, 0),
    (0, 1, 0, 0, 0, 0, 1, 0),
    (0, 1, 1, 1, 1, 1, 1, 0),
    (0, 0, 0, 0, 0, 0, 0, 0)),

    ((0, 0, 0, 0, 0, 0, 0, 0), // X
    (0, 1, 1, 1, 1, 2, 2, 0), //  XXX
    (0, 1, 0, 0, 0, 0, 2, 0),
    (0, 1, 0, 2, 2, 0, 1, 0),
    (0, 1, 0, 2, 2, 0, 1, 0),
    (0, 1, 0, 0, 0, 0, 1, 0),
    (0, 1, 1, 1, 1, 1, 1, 0),
    (0, 0, 0, 0, 0, 0, 0, 0)),

    ((0, 0, 0, 0, 0, 0, 0, 0), // XX
    (0, 2, 2, 2, 2, 2, 2, 0), //  XX
    (0, 2, 0, 0, 0, 0, 2, 0),
    (0, 2, 0, 0, 0, 0, 2, 0),
    (0, 2, 0, 0, 0, 0, 2, 0),
    (0, 2, 0, 0, 0, 0, 2, 0),
    (0, 2, 2, 2, 2, 2, 2, 0),
    (0, 0, 0, 0, 0, 0, 0, 0)),

    ((0, 0, 0, 0, 0, 0, 0, 0), //  XX
    (0, 1, 1, 1, 1, 1, 1, 0), //  XX
    (0, 1, 0, 0, 0, 0, 1, 0),
    (0, 1, 0, 2, 2, 0, 1, 0),
    (0, 1, 0, 2, 2, 0, 1, 0),
    (0, 1, 0, 0, 0, 0, 1, 0),
    (0, 1, 1, 1, 1, 1, 1, 0),
    (0, 0, 0, 0, 0, 0, 0, 0)),

    ((0, 0, 0, 0, 0, 0, 0, 0), // XX
    (0, 2, 2, 2, 1, 1, 1, 0), //   XX
    (0, 2, 1, 1, 1, 1, 1, 0),
    (0, 1, 1, 0, 0, 1, 1, 0),
    (0, 1, 1, 0, 0, 1, 1, 0),
    (0, 1, 1, 1, 1, 1, 1, 0),
    (0, 1, 1, 1, 1, 1, 1, 0),
    (0, 0, 0, 0, 0, 0, 0, 0))
    );

Type
  TPixel = Record
    Location: TPoint;
    Color: TColor;
  End;

  TPixels = Record
    Pixels: Array[0..4 * 64 - 1] Of TPixel; // 4 Teile a 64-Pixels
    RotationPoint: TPoint;
    ColorIndex: integer; // Eine Farbe hat zwar Schattierungen, aber der ColorIndex ist immer der Gleiche
  End;

Function GetRandomPiece(): TPixels;

Implementation

Uses math;

(*
 * Erstellt ein Zufälliges Teil, in einer Zufälligen Farbe
 *)

Function GetRandomPiece(): TPixels;
Var
  x, y, dx, dy, p, i, index: integer;
  pc: Byte;
Begin
  p := random(length(Pieces));
  result.ColorIndex := random(4);
  dx := 0;
  dy := 0;
  index := 0;
  For i := 0 To 3 Do Begin
    For x := 0 To 7 Do Begin
      For y := 0 To 7 Do Begin
        pc := PieceSheme[p][x, y];
        Case result.ColorIndex Of
          0: result.Pixels[index].Color := Green[pc];
          1: result.Pixels[index].Color := Blue[pc];
          2: result.Pixels[index].Color := Yellow[pc];
          3: result.Pixels[index].Color := Red[pc];
        End;
        result.Pixels[index].Location.x := Pieces[p][i].x * 8 + x;
        result.Pixels[index].Location.Y := Pieces[p][i].Y * 8 + y;
        dx := max(dx, Pieces[p][i].x * 8);
        dy := max(dy, abs(Pieces[p][i].y * 8));
        inc(index);
      End;
    End;
  End;
  result.RotationPoint.x := dx Div 2;
  result.RotationPoint.Y := dy Div 2;
End;


End.

