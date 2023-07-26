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
  Buttons, OpenGLContext,
  (*
  * Kommt ein Linkerfehler wegen OpenGL dann: sudo apt-get install freeglut3-dev
  *)
  dglOpenGL // http://wiki.delphigl.com/index.php/dglOpenGL.pas
  //, uopengl_graphikengine // Die OpenGLGraphikengine ist eine Eigenproduktion von www.Corpsman.de, und kann getrennt geladen werden.
  , usandtris
  , upieces
  , uHighscoreEngine
  ;

Type

  { TForm1 }

  TForm1 = Class(TForm)
    Button1: TButton;
    ImageList1: TImageList;
    Label1: TLabel;
    Label3: TLabel;
    OpenGLControl1: TOpenGLControl;
    PaintBox1: TPaintBox;
    SpeedButton1: TSpeedButton;
    Timer1: TTimer;
    Timer2: TTimer;
    Procedure Button1Click(Sender: TObject);
    Procedure FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
    Procedure FormCreate(Sender: TObject);
    Procedure FormKeyDown(Sender: TObject; Var Key: Word; Shift: TShiftState);
    Procedure FormKeyUp(Sender: TObject; Var Key: Word; Shift: TShiftState);
    Procedure OpenGLControl1MakeCurrent(Sender: TObject; Var Allow: boolean);
    Procedure OpenGLControl1Paint(Sender: TObject);
    Procedure OpenGLControl1Resize(Sender: TObject);
    Procedure SpeedButton1Click(Sender: TObject);
    Procedure Timer1Timer(Sender: TObject);
    Procedure Timer2Timer(Sender: TObject);
  private
    SandTris: TSandTris;
    Highscore: THighscoreEngine;
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

Uses LCLType, Unit2;

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
  glPointSize(Scale96ToForm(4));
End;

Procedure TForm1.Exit2d;
Begin
  glMatrixMode(GL_PROJECTION);
  glPopMatrix(); // Restore old Projection Matrix
  glMatrixMode(GL_MODELVIEW);
  glPopMatrix(); // Restore old Projection Matrix
End;


Procedure TForm1.Timer2Timer(Sender: TObject);
Var
  s: String;
Begin
  // We do this only one time
  timer2.enabled := false;
  // TODO: den Text dieses Dialogs sieht man nicht weil wir noch mitten im OpenGL onpaint sind ..
  //showmessage('You reached: ' + IntToStr(SandTris.Points));
  s := InputBox('Results', 'You reached: ' + IntToStr(SandTris.Points) + ' points, please enter your name for highscores.', 'Anonymos');
  If s <> '' Then Begin
    Highscore.Add(s, SandTris.Points);
    Highscore.Save;
    SpeedButton1Click(Nil);
  End;
  Button1.Visible := true;
  Init();
  Button1.SetFocus;
End;

Procedure TForm1.OnEndGame(sender: TObject);
Begin
  // This is not elegant but easy
  // and needed to decouple the OnRender routine from the showmessage routine
  // which is needed on Linux systems to be able to actually display a messages
  // Content
  timer2.enabled := true;
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
    PaintBox1.Canvas.Rectangle(Scale96ToForm(p.x * 4), Scale96ToForm(p.Y * 4), Scale96ToForm(p.x * 4 + 4), Scale96ToForm(p.Y * 4 + 4));
{$IFDEF Linux}
    PaintBox1.Canvas.Pixels[Scale96ToForm(p.x * 4 + 4 - 1), Scale96ToForm(p.Y * 4 + 4 - 1)] := c;
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

Procedure TForm1.SpeedButton1Click(Sender: TObject);
Var
  List: TItemList;
Begin
  // Show Highscore
  list := Highscore.Show(false);
  form2.LoadHighscore(List);
  form2.ShowModal;
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
   *          0.02 = Fix DPI Scaling
   *          0.03 = improve texture of straight block
   *          0.04 = Add Simple Highscore Engine
   *
   * Known Bugs: - On Linux the Highscreen is not readable
   *             - The very first previewed piece is not shown (Linux and Windows)
   *)
  Caption := 'Sandtris ver. 0.04';
  Randomize;
  Color := clBlack;
  Constraints.MinHeight := Height;
  Constraints.MaxHeight := Height;
  Constraints.MinWidth := Width;
  Constraints.MaxWidth := Width;
  Highscore := THighscoreEngine.Create('Highscores.dat', 'This should be a good password, not such a lame text.', 10);
  Highscore.InsertAlways := true;
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
  OpenGLControl1.Width := Scale96ToForm(WorldWidth * 4);
  OpenGLControl1.Height := Scale96ToForm(WorldHeight * 4);
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
  If key = VK_UP Then Begin
    SandTris.Turn(1);
  End;
  If key = VK_DOWN Then Begin
    SandTris.Turn(-1);
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
End;

Procedure TForm1.FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
Begin
  Initialized := false;
  Highscore.free;
  SandTris.Free;
End;

Procedure TForm1.Button1Click(Sender: TObject);
Begin
  // Start New Game
  SandTris.Start;
End;



End.

