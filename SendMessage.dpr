
program SendMessage;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  UnitConfig in 'UnitConfig.pas' {FormConfig},
  Unit2 in 'Unit2.pas' {Form2};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
