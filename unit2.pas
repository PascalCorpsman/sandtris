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
Unit Unit2;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  uHighscoreEngine;

Type

  { TForm2 }

  TForm2 = Class(TForm)
    Button1: TButton;
    Label1: TLabel;
    Label2: TLabel;
    Procedure FormCreate(Sender: TObject);
  private

  public

    Procedure LoadHighscore(Const List: TItemList);
  End;

Var
  Form2: TForm2;

Implementation

{$R *.lfm}

{ TForm2 }

Procedure TForm2.FormCreate(Sender: TObject);
Begin
  caption := 'Highscore';
  Color := clBlack;
End;

Procedure TForm2.LoadHighscore(Const List: TItemList);
Var
  i: Integer;
Begin
  If high(list) = -1 Then Begin
    label1.caption := '-';
    label2.Caption := '-';
  End
  Else Begin
    label1.caption := '';
    label2.Caption := '';
    For i := 0 To high(List) Do Begin
      label1.caption := List[i].Name + LineEnding;
      label2.caption := inttostr(List[i].Points) + LineEnding;
    End;
  End;
End;

End.

