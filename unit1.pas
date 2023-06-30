(******************************************************************************)
(* Sandtris                                                        27.06.2023 *)
(*                                                                            *)
(* Version     : 0.01                                                         *)
(*                                                                            *)
(* Author      : Uwe Schächterle (Corpsman)                                   *)
(*                                                                            *)
(* Support     : www.Corpsman.de                                              *)
(*                                                                            *)
(* Description : This is a mix between sandflow simulation and the Tetris     *)
(*               classical game.                                              *)
(*               inspired by: https://www.youtube.com/shorts/aaCWkot8mIU      *)
(*                                                                            *)
(* License     : See the file license.md, located under:                      *)
(*  https://github.com/PascalCorpsman/Software_Licenses/blob/main/license.md  *)
(*  for details about the license.                                            *)
(*                                                                            *)
(*               It is not allowed to change or remove this text from any     *)
(*               source file of the project.                                  *)
(*                                                                            *)
(* Warranty    : There is no warranty, neither in correctness of the          *)
(*               implementation, nor anything other that could happen         *)
(*               or go wrong, use at your own risk.                           *)
(*                                                                            *)
(* Known Issues: none                                                         *)
(*                                                                            *)
(* History     : 0.01 - Initial version                                       *)
(*                                                                            *)
(******************************************************************************)

Unit Unit1;

{$MODE objfpc}{$H+}

{$DEFINE DebuggMode}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  OpenGLContext,
  (*
  * Kommt ein Linkerfehler wegen OpenGL dann: sudo apt-get install freeglut3-dev
  *)
  dglOpenGL // http://wiki.delphigl.com/index.php/dglOpenGL.pas
  //, uopengl_graphikengine // Die OpenGLGraphikengine ist eine Eigenproduktion von www.Corpsman.de, und kann getrennt geladen werden.
  , usandtris
  , upieces
  ;

Type

  { TForm1 }

  TForm1 = Class(TForm)
    Button1: TButton;
    Label1: TLabel;
    Label3: TLabel;
    OpenGLControl1: TOpenGLControl;
    PaintBox1: TPaintBox;
    Timer1: TTimer;
    Procedure Button1Click(Sender: TObject);
    Procedure FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
    Procedure FormCreate(Sender: TObject);
    Procedure FormKeyDown(Sender: TObject; Var Key: Word; Shift: TShiftState);
    Procedure FormKeyUp(Sender: TObject; Var Key: Word; Shift: TShiftState);
    Procedure OpenGLControl1MakeCurrent(Sender: TObject; Var Allow: boolean);
    Procedure OpenGLControl1Paint(Sender: TObject);
    Procedure OpenGLControl1Resize(Sender: TObject);
    Procedure Timer1Timer(Sender: TObject);
  private
    SandTris: TSandTris;
    Procedure Go2d();
    Procedure Exit2d();
    Procedure OnEndGame(sender: TObject);
    Procedure OnStartGame(sender: TObject);
    Procedure OnNextPreviewPiece(sender: TObject);
    Procedure OnPoints(sender: TObject);
    Procedure Init();
  public
  End;

Var
  Form1: TForm1;
  Initialized: Boolean = false; // Wenn True dann ist OpenGL initialisiert

Implementation

{$R *.lfm}

Uses LCLType;

{ TForm1 }

Procedure TForm1.Go2d;
Begin
  glMatrixMode(GL_PROJECTION);
  glPushMatrix(); // Store The Projection Matrix
  glLoadIdentity(); // Reset The Projection Matrix
  //  glOrtho(0, 640, 0, 480, -1, 1); // Set Up An Ortho Screen
  glOrtho(0, WorldWidth, worldheight, 0, -1, 1); // Set Up An Ortho Screen
  glMatrixMode(GL_MODELVIEW);
  glPushMatrix(); // Store old Modelview Matrix
  glLoadIdentity(); // Reset The Modelview Matrix
  glPointSize(4);
End;

Procedure TForm1.Exit2d;
Begin
  glMatrixMode(GL_PROJECTION);
  glPopMatrix(); // Restore old Projection Matrix
  glMatrixMode(GL_MODELVIEW);
  glPopMatrix(); // Restore old Projection Matrix
End;

Procedure TForm1.OnEndGame(sender: TObject);
Begin
  // TODO: den Text dieses Dialogs sieht man nicht weil wir noch mitten im OpenGL onpaint sind ..
  showmessage('You reached: ' + IntToStr(SandTris.Points));
  Button1.Visible := true;
  Init();
  Button1.SetFocus;
End;

Procedure TForm1.OnStartGame(sender: TObject);
Begin
  label1.caption := '0';
  button1.visible := false;
End;

Procedure TForm1.OnNextPreviewPiece(sender: TObject);

  Procedure SetPixel(p: TPoint; c: TColor);
  Begin
    PaintBox1.Canvas.Brush.Color := c;
    PaintBox1.Canvas.pen.Color := c;
    PaintBox1.Canvas.Rectangle(p.x * 4, p.Y * 4, p.x * 4 + 4, p.Y * 4 + 4);
{$IFDEF Linux}
    PaintBox1.Canvas.Pixels[p.x * 4 + 4 - 1, p.Y * 4 + 4 - 1] := c;
{$ENDIF}
  End;

Var
  i: Integer;
Begin
  // 1. Das nächste Teil, welches erstellt werden soll erstellen
  // 2. Dieses Teil in der Preview anzeigen
  PaintBox1.Canvas.Brush.Color := clBlack;
  PaintBox1.Canvas.Rectangle(-1, -1, PaintBox1.Width + 1, PaintBox1.Height + 1);
  For i := 0 To high(SandTris.NextPiece.Pixels) Do Begin
    SetPixel(
      point(SandTris.NextPiece.Pixels[i].Location.x, SandTris.NextPiece.Pixels[i].Location.y + PieceHeight)
      , SandTris.NextPiece.Pixels[i].Color);
  End;
End;

Procedure TForm1.OnPoints(sender: TObject);
Begin
  label1.Caption := inttostr(SandTris.Points);
End;

Procedure TForm1.Init;
Begin
  Label1.caption := 'Please start';
  SandTris.Init;
  button1.Visible := true;
  PaintBox1.Canvas.Brush.Color := clBlack;
  PaintBox1.Canvas.Rectangle(-1, -1, PaintBox1.Width + 1, PaintBox1.Height + 1);
End;

Procedure TForm1.OpenGLControl1Paint(Sender: TObject);
Begin
  If Not Initialized Then Exit;
  // Render Szene
  glClearColor(0.0, 0.0, 0.0, 0.0);
  glClear(GL_COLOR_BUFFER_BIT Or GL_DEPTH_BUFFER_BIT);
  glLoadIdentity();
  go2d;
  SandTris.Render();
  exit2d;
  OpenGLControl1.SwapBuffers;
End;

Procedure TForm1.OpenGLControl1Resize(Sender: TObject);
Begin
  If Initialized Then Begin
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glViewport(0, 0, OpenGLControl1.Width, OpenGLControl1.Height);
    gluPerspective(45.0, OpenGLControl1.Width / OpenGLControl1.Height, 0.1, 100.0);
    glMatrixMode(GL_MODELVIEW);
  End;
End;

Procedure TForm1.Timer1Timer(Sender: TObject);
{$IFDEF DebuggMode}
Var
  i: Cardinal;
  p: Pchar;
{$ENDIF}
Begin
  If Initialized Then Begin
    OpenGLControl1.Invalidate;
{$IFDEF DebuggMode}
    i := glGetError();
    If i <> 0 Then Begin
      Timer1.Enabled := false;
      p := gluErrorString(i);
      showmessage('OpenGL Error (' + inttostr(i) + ') occured.' + LineEnding + LineEnding +
        'OpenGL Message : "' + p + '"' + LineEnding + LineEnding +
        'Applikation will be terminated.');
      close;
    End;
{$ENDIF}
  End;
End;

Var
  allowcnt: Integer = 0;

Procedure TForm1.OpenGLControl1MakeCurrent(Sender: TObject; Var Allow: boolean);
Begin
  If allowcnt > 2 Then Begin
    exit;
  End;
  inc(allowcnt);
  // Sollen Dialoge beim Starten ausgeführt werden ist hier der Richtige Zeitpunkt
  If allowcnt = 1 Then Begin
    // Init dglOpenGL.pas , Teil 2
    ReadExtensions; // Anstatt der Extentions kann auch nur der Core geladen werden. ReadOpenGLCore;
    ReadImplementationProperties;
  End;
  If allowcnt = 2 Then Begin // Dieses If Sorgt mit dem obigen dafür, dass der Code nur 1 mal ausgeführt wird.
    // Der Anwendung erlauben zu Rendern.
    Initialized := True;
    OpenGLControl1Resize(Nil);
    SandTris := TSandTris.Create();
    SandTris.OnStartGameEvent := @OnStartGame;
    SandTris.OnEndGameEvent := @OnEndGame;
    SandTris.OnNextPreviewPieceEvent := @OnNextPreviewPiece;
    SandTris.OnPointsEvent := @OnPoints;
    Init();
  End;
  Form1.Invalidate;
End;

Procedure TForm1.FormCreate(Sender: TObject);
Begin
  (*
   * History: 0.01 = Initial version
   *
   * Known Bugs: die "Hoch / Runter" funktion zum Teil drehen fühlt sich "Hackelig" an, aber funktioniert..
   * Missing Feature: 
   *       - Wenn die Space bar gedrückt wird sollte das Spielfeld kurz wackeln
   *       - Einen Rahmen fürs Spielfeld Rendern
   * 
   *)
  Caption := 'Sandtris ver. 0.01';
  Randomize;
  Color := clBlack;
  Constraints.MinHeight := Height;
  Constraints.MaxHeight := Height;
  Constraints.MinWidth := Width;
  Constraints.MaxWidth := Width;
  // Init dglOpenGL.pas , Teil 1
  If Not InitOpenGl Then Begin
    showmessage('Error, could not init dglOpenGL.pas');
    Halt;
  End;
  (*
  60 - FPS entsprechen
  0.01666666 ms
  Ist Interval auf 16 hängt das gesamte system, bei 17 nicht.
  Generell sollte die Interval Zahl also dynamisch zum Rechenaufwand, mindestens aber immer 17 sein.
  *)
  Timer1.Interval := 17;
  OpenGLControl1.Width := WorldWidth * 4;
  OpenGLControl1.Height := WorldHeight * 4;
End;

Procedure TForm1.FormKeyDown(Sender: TObject; Var Key: Word; Shift: TShiftState
  );
Begin
  If key = VK_ESCAPE Then close; // Boss Key
  If key = VK_LEFT Then Begin
    SandTris.SetKey(-1, true);
  End;
  If key = VK_RIGHT Then Begin
    SandTris.SetKey(1, true);
  End;
  If key = VK_SPACE Then Begin
    SandTris.DropDown();
  End;
  If key = vK_P Then Begin
    SandTris.TogglePause;
  End;
End;

Procedure TForm1.FormKeyUp(Sender: TObject; Var Key: Word; Shift: TShiftState);
Begin
  If key = VK_LEFT Then Begin
    SandTris.SetKey(-1, false);
  End;
  If key = VK_RIGHT Then Begin
    SandTris.SetKey(1, false);
  End;
  If key = VK_UP Then Begin
    SandTris.Turn(1);
  End;
  If key = VK_DOWN Then Begin
    SandTris.Turn(-1);
  End;
End;

Procedure TForm1.FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
Begin
  Initialized := false;
  SandTris.Free;
End;

Procedure TForm1.Button1Click(Sender: TObject);
Begin
  // Start New Game
  SandTris.Start;
End;



End.

