Unit TestCase1;

{$MODE objfpc}{$H+}

Interface

Uses
  Classes, SysUtils, fpcunit, testutils, testregistry, usandtris;

Type

  { TTestCase1 }

  TTestCase1 = Class(TTestCase)
  protected
    Procedure SetUp; override;
    Procedure TearDown; override;
  published
    Procedure CanCreateInstance;
  End;

Implementation

Procedure TTestCase1.CanCreateInstance;
Var
  fDut: TSandTris;
Begin
  fdut := TSandTris.Create();
  AssertTrue('Can not create instance', assigned(fDut));
  fdut.free;
End;

Procedure TTestCase1.SetUp;
Begin

End;

Procedure TTestCase1.TearDown;
Begin

End;

Initialization

  RegisterTest(TTestCase1);
End.

