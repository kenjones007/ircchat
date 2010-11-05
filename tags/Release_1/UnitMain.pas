unit UnitMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls,
  IdAntiFreezeBase, IdAntiFreeze, ExtCtrls,
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient,
  IdCmdTCPClient, IdIRC, IdContext, IdSync, 
  StdCtrls, Buttons, FrameChatImpl, Inifiles, Menus, ActnList, XPMan,
  ImgList, ToolWin;

type
  TMyThread = class(TThread)
  public
    a1: string;
    a2: string;
    a3: string;
  protected
    procedure Execute; override;
  end;

  TForm2 = class(TForm)
    Label1: TLabel;
    IdIRC1: TIdIRC;
    Timer1: TTimer;
    PageControl1: TPageControl;
    TabControle: TTabSheet;
    TabPublico: TTabSheet;
    LogMsgControle: TRichEdit;
    FrameChat1: TFrameChat;
    ListBox1: TListBox;
    Splitter1: TSplitter;
    StatusBar1: TStatusBar;
    PopupMenu1: TPopupMenu;
    Delete1: TMenuItem;
    IdAntiFreeze1: TIdAntiFreeze;
    ImageList1: TImageList;
    XPManifest1: TXPManifest;
    ActionList1: TActionList;
    ActConfigurar: TAction;
    ActConectar: TAction;
    ActManual: TAction;
    ActSair: TAction;
    ActDisconectar: TAction;
    Action1: TAction;
    CoolBar1: TCoolBar;
    ToolBar2: TToolBar;
    ToolButton10: TToolButton;
    ToolButton11: TToolButton;
    ToolButton12: TToolButton;
    ToolButton13: TToolButton;
    ToolButton14: TToolButton;
    ToolButton15: TToolButton;
    ToolButton16: TToolButton;
    procedure FormCreate(Sender: TObject);
    procedure IdIRC1Connected(Sender: TObject);
    procedure IdIRC1Join(ASender: TIdContext; const ANickname, AHost,
      AChannel: string);
    procedure IdIRC1Raw(ASender: TIdContext; AIn: Boolean;
      const AMessage: string);
    procedure IdIRC1Notice(ASender: TIdContext; const ANicknameFrom, AHost,
      ANicknameTo, ANotice: string);
    procedure ListBox1DblClick(Sender: TObject);
    procedure IdIRC1PrivateMessage(ASender: TIdContext;
      const ANicknameFrom, AHost, ANicknameTo, AMessage: string);
    procedure PopupMenu1Popup(Sender: TObject);
    procedure Delete1Click(Sender: TObject);
    procedure IdIRC1Quit(ASender: TIdContext; const ANickname, AHost,
      AReason: string);
    procedure ActConfigurarExecute(Sender: TObject);
    procedure ActConectarExecute(Sender: TObject);
    procedure ActSairExecute(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure IdIRC1Disconnected(Sender: TObject);
    procedure ActDisconectarExecute(Sender: TObject);
    procedure Action1Execute(Sender: TObject);
  private
    { Private declarations }
    FInChannel: Boolean;
    NickIdx: Integer;
    IRCChannel: string;
    Users: TStrings;

    procedure Conectar();
    function Configura: boolean;
    procedure Disconnect;
    function ConfiguraIRC: Boolean;
    procedure Connect;
    procedure Nick(NickName: string);
    procedure Identify(Password: string);
    procedure Join(AChannel: string);
    function GetFrame(ANickFrom, ANickTo: string): TFrameChat;
    function GetTabPage(ANickFrom, ANickTo: string): TTabSheet;
    function WaitFor(var BoolVar: Boolean; Timeout: Cardinal = 5): Boolean;
    procedure LogControle(s: string);
  public
    { Public declarations }
    canSay: Boolean;
    procedure Say(ATarget, Texto: string);
    procedure ShowPVTMSG(const ANicknameFrom, ANicknameTo, AMessage: string);
  end;

const
  TimerInterval =  2 * 60 * 1000;
 // TimerInterval = 2 * 60 * 100;
var

  Form2: TForm2;

implementation

uses UnitConfig;

{$R *.dfm}

function TForm2.WaitFor(var BoolVar: Boolean; Timeout: Cardinal = 5): boolean;
var
  start: Cardinal;
begin
  start := GetTickCount();
  while (not BoolVar) and (GetTickCount() - start < (Timeout * 1000)) do
    Application.ProcessMessages;
  result := BoolVar;
end;

function TForm2.Configura(): boolean;
var
  FrmConfig: TFormConfig;
begin
  FrmConfig := TFormConfig.Create(self);
  try
    result := FrmConfig.ShowModal() = mrOK;
  finally
    FreeAndNil(FrmConfig);
  end;
end;

procedure TForm2.Conectar;
begin
  FInChannel := False;
  ConfiguraIRC();
  NickIdx := Users.Count - 1;
  IdIrc1.Nickname := Users[NickIdx];
  IdIRC1.AltNickname := Users[NickIdx];

  try
    IdIRC1.Connect();
  except

    if not idIRC1.Connected then
    begin
      MessageDlg('Erro ao tentar conectar:' + idIRC1.Host, mtError, [mbOK], 0);
      Exit;
    end;
  end;
end;

procedure TForm2.FormCreate(Sender: TObject);
begin
  FInChannel := False;
  NickIdx := 0;
  IRCChannel := '';
  Users := TStringList.Create();
  FrameChat1.Clear();
  FrameChat1.ParentForm := Form2;

  TabControle.TabVisible := False;

  //:???  if not Configura() then Halt;
  if not ConfiguraIRC() then
    if not Configura() then
      Halt
    else
      ConfiguraIRC();

  Connect();

  Timer1.interval := TimerInterval;

  Label1.Caption := Version;

end;

procedure TForm2.Connect();
begin
  FInChannel := False;
  NickIdx := Users.Count - 1;
  IdIrc1.Nickname := Users[NickIdx];
  IdIRC1.AltNickname := Users[NickIdx];

  try
    IdIRC1.Connect();
  except

    if not idIRC1.Connected then
    begin
      MessageDlg('Erro ao tentar conectar:' + idIRC1.Host, mtError, [mbOK], 0);
      Exit;
    end;
  end;
end;

procedure TForm2.Disconnect();
begin
  Timer1.Enabled := False;
  IdIRC1.Disconnect();
end;

function TForm2.ConfiguraIRC(): Boolean;
var
  Ini: TCustomIniFile;
  old: boolean;
  CfgFile: string;
begin
  old := Timer1.Enabled;
  Timer1.Enabled := False;
  CfgFile := ExtractFilePath(ParamStr(0)) + '\config.ini';

  Result := False;
  If not FileExists(cfgFile) then
    Exit;

  Ini := TMemIniFile.Create(CfgFile);
  try
    IdIRC1.Host := ini.readstring('irc', 'host', '200.142.160.127');
    IdIRC1.Port := ini.ReadInteger('irc', 'port', 8000);
    IdIRC1.Username := ini.readstring('irc', 'username', '');
    IdIRC1.Password := ini.readstring('irc', 'password', '');
    IdIRC1.AltNickname := ini.readstring('irc', 'altnick', '');
    IdIRC1.RealName := ini.readstring('irc', 'realname', '');
    IRCChannel := ini.readstring('irc', 'channel', '');
    Timer1.Interval := ini.ReadInteger('irc', 'timetodisconnect', TimerInterval);
    Ini.ReadSection('Usuarios', Users);
  finally
    Ini.Free();
    Result := True;
  end;
  Timer1.Enabled := old;
end;

procedure TForm2.Nick(NickName: string);
begin
  IdIRC1.Raw(format('NICK %s', [NickName]));
end;

procedure TForm2.IdIRC1Connected(Sender: TObject);
begin
  LogControle('Conectado.');

  ActConectar.Enabled := False;
  ActDisconectar.Enabled := True;
  ListBox1.Enabled := True;
  Timer1.Enabled := True;
end;

function Ordena(lista: TStrings): string;
var
  l: TStrings;
begin
  l := TStringList.Create();
  l.AddStrings(lista);
  TStringList(l).Sort;
  result := l.text;
end;

procedure TForm2.IdIRC1Join(ASender: TIdContext; const ANickname, AHost,
  AChannel: string);

begin
  LogControle('>>Usu�rio ' + ANickname + ' conectou-se');
  //adiciona na lista caso n�o exista
  if not (ListBox1.Items.IndexOf(ANickname) > -1) then
  begin
    ListBox1.Items.Add(ANickname);
  end;
  ListBox1.Items.Text := Ordena(ListBox1.Items);

  //se for meu nome, avisa que estou no canal.
  if Pos(ANickname, IdIRC1.Nickname) > 0 then
  begin
    FInChannel := True;
    StatusBar1.Panels[0].Text :=
      Format('Conectado como %s em %s : %d - [%s]',
      [ANickname, IdIRC1.Host, IdIRC1.Port, IdIRC1.RealName]); ;
    PageControl1.Pages[0].Caption := IRCChannel;
  end;

end;

procedure TForm2.IdIRC1Raw(ASender: TIdContext; AIn: Boolean;
  const AMessage: string);
  function ParseNames(s: string): string;
  var
    Lista: TStrings;
  begin
    Lista := TStringList.Create();
    Lista.Delimiter := ' ';
    Lista.CommaText := Copy(s, pos(':', s) + 1, Length(s));
    Result := Lista.Text;
  end;

var
  oldDest: string;
begin
  LogControle('OnRaw: ' + AMessage);

  //User in uso, tenta alterar nick
  if Copy(AMessage, 1, 3) = '433' then
  begin
    Dec(NickIdx);
    if NickIdx < 0 then
      IdIRC1.Disconnect();
    Nick(Users[NickIdx]);
  end;

  //lista de usuarios
  if Copy(AMessage, 1, 3) = '353' then
  begin
    ListBox1.Items.Text := ParseNames(AMessage);
    ListBox1.Items.Text := Ordena(ListBox1.Items);
    canSay := True;
  end;

  if Copy(AMessage, 1, 3) = '401' then
  begin
    oldDest := 'O usuario n�o est� mais conectado' + #10 +
      'Tente enviar a mensagem para o chat p�blico: #' + IRCChannel;

    TFrameChat(TabPublico.Controls[0]).AddMessage(oldDest, clRed);
  end;
end;

procedure TForm2.Identify(Password: string);
begin
  IdIRC1.Say('NickServ', 'IDENTIFY ' + IdIRC1.Password);
end;

procedure TForm2.Join(AChannel: string);
begin
  if (AChannel = '') then
    AChannel := IRCChannel;

  if AChannel[1] <> '#' then
    AChannel := '#' + AChannel;

  //  if not Identified then
  IdIRC1.Raw(Format('JOIN %s', [AChannel]));
end;


procedure TForm2.IdIRC1Notice(ASender: TIdContext; const ANicknameFrom,
  AHost, ANicknameTo, ANotice: string);
begin
  //need Identify
  if Pos('IDENTIFY_REQUEST', ANotice) > 0 then
    Identify(IdIRC1.Password);

  //Do Join
  if Pos('IDENTIFY Password accepted', ANotice) > 0 then
    Join(IRCChannel);

  LogControle('OnNotice' + #13 + 'nick:' + ANicknameFrom + ' host:' + AHost +
    ' to:' + ANicknameTo + ' notice:' + ANotice);

end;

function TForm2.GetTabPage(ANickFrom, ANickTo: string): TTabSheet;
var
  i: integer;
  Page: TTabSheet;
begin
  Result := nil;

  //tenta localizar
  for i := 0 to PageControl1.PageCount - 1 do
  begin
    Page := PageControl1.Pages[i];

    if AnsiPos(Page.Caption, ANickFrom) > 0 then
    begin
      Result := Page;
      Break;
    end;
  end;
end;

function TForm2.GetFrame(ANickFrom, ANickTo: string): TFrameChat;
var
  i: integer;
  Page: TTabSheet;
begin
  Result := nil;

  //tenta localizar
  for i := 0 to PageControl1.PageCount - 1 do
  begin
    Page := PageControl1.Pages[i];

    if AnsiPos(Page.Caption, ANickFrom) > 0 then
      Result := TFrameChat(Page.Components[0]);
  end;

  if not Assigned(Result) then
  begin
    Page := TTabSheet.Create(PageControl1);
    Page.PageControl := PageControl1;
    Page.Caption := ANickFrom;
    Result := TFrameChat.Create(Page);
    Result.Parent := Page;

    Result.ParentForm := Form2;
    Result.From := ANickFrom;
  end;
end;


procedure TForm2.Say(ATarget, Texto: string);
var
  AMsg: string;
  Msg: string;
begin
// retirado de SendMessage
  if not IdIRC1.Connected then
  begin
    ConfiguraIRC();
    Connect();
    Join(IRCChannel);
  end;

  try
    WaitFor(FInChannel,10);
  except
    MessageDlg('Erro ao tentar entrar no canal: ' + idIRC1.Host, mtError, [mbOK], 0);
    Disconnect();
    Exit;
  end;

  if not FInChannel then
  begin
    MessageDlg('Erro ao tentar entrar no canal: ' + idIRC1.Host, mtError, [mbOK], 0);
    exit;
  end;

  //Refresh timer
  Timer1.Enabled := False;
  Timer1.Enabled := True;

  //ops... algo aconteceu!
  if not canSay then
    Exit;

  if ATarget = '' then
    ATarget := '#' + IRCChannel;

  ATarget := StringReplace(ATarget, '@', '', [rfReplaceAll]);
  ATarget := StringReplace(ATarget, '+', '', [rfReplaceAll]);
  AMsg := StringReplace(AMsg, #13, '', [rfReplaceAll]);
  AMsg := StringReplace(AMsg, #10, ' ', [rfReplaceAll]);
  AMsg := Format('[%s] %s', [IdIRC1.RealName, Texto]);

  Msg := Format('PRIVMSG %s :%s', [ATarget, AMsg]);
  IdIRC1.Raw(Msg);

  if Pos(IRCChannel, ATarget) > 0 then
    FrameChat1.AddMessage(AMsg)
  else
  begin
    GetFrame(ATarget, '').
      AddMessage(
      Format('[%s] <%s>: %s', [IdIRC1.RealName, ATarget, Texto])
      );
  end;
end;

procedure TForm2.ListBox1DblClick(Sender: TObject);
var
  Page: TTabSheet;
  Frame: TFrameChat;
  ATarget: string;
begin
  ATarget := ListBox1.Items[ListBox1.itemindex];
  ATarget := StringReplace(ATarget, '@', '', [rfReplaceAll]);
  ATarget := StringReplace(ATarget, '+', '', [rfReplaceAll]);

  Frame := GetFrame(ATarget, '');
  Page := TTabSheet(Frame.Parent);
  PageControl1.ActivePage := Page;
end;

procedure TForm2.ShowPVTMSG(const ANicknameFrom, ANicknameTo, AMessage: string);
var
  Frame: TFrameChat;
  Page: TTabSheet;
begin
  //� chat p�blico???
  if Pos(IRCChannel, ANicknameTo) > 0 then
    FrameChat1.AddMessage(
      Format('<%s> %s', [ANicknameFrom, AMessage]))
  else
  //� Privado!
  begin
    Page := GetTabPage(ANicknameFrom, '');
    //J� tem tab criada?
    if Assigned(Page) then
    begin
      Frame := TFrameChat(Page.Components[0]);
      Frame.AddMessage(
        Format('<%s>: %s', [ANicknameFrom, AMessage]));
      PageControl1.ActivePage := Page;
    end
    else
    begin
      FrameChat1.AddMessage('Clique duas vezes sobre este usuario para iniciar uma conversa Privada!', clRed);
      FrameChat1.AddMessage(
        Format('PRIVADO <%s>: %s', [ANicknameFrom, AMessage]), clRed);
    end;
  end;
  Application.ProcessMessages;
end;

procedure TForm2.IdIRC1PrivateMessage(ASender: TIdContext;
  const ANicknameFrom, AHost, ANicknameTo, AMessage: string);
var
  t1: TMyThread;
begin
  t1 := TMyThread.Create(True);
  t1.FreeOnTerminate := True;
  t1.a1 := ANicknameFrom;
  t1.a2 := ANicknameTo;
  t1.a3 := AMessage;
  t1.Resume;
end;

procedure TForm2.PopupMenu1Popup(Sender: TObject);
begin
  Delete1.Caption := 'Remover ' + PageControl1.ActivePage.Caption;

  if PageControl1.ActivePage = TabControle then
    Delete1.Caption := 'Ocultar aba de Controle';
end;

procedure TForm2.Delete1Click(Sender: TObject);
begin
  if PageControl1.ActivePage = TabControle then
    TabControle.TabVisible := False
  else
  begin
    PageControl1.ActivePage.Destroy;
    PageControl1.ActivePage := TabPublico;
  end;
end;

procedure TForm2.IdIRC1Quit(ASender: TIdContext; const ANickname, AHost,
  AReason: string);
var
  i: Integer;
begin
  {TODO: Retirar o nome da lista}

  //retira da lista caso exista.
  i := ListBox1.Items.IndexOf(ANickname);
  if i > -1 then
    ListBox1.Items.Delete(i);

  //se for meu nome, avisa que estou no canal.
  if Pos(LowerCase(ANickname), LowerCase(IdIRC1.Nickname)) > 0 then
    FInChannel := False
  else
    LogControle('<<Usu�rio ' + ANickname + ' desconectou-se');
end;

{ TMyThread }

procedure TMyThread.Execute;
begin
  Form2.ShowPVTMSG(a1, a2, a3);
  inherited;
end;

procedure TForm2.ActConfigurarExecute(Sender: TObject);
begin
  if Configura() then
  begin
    Disconnect();
    ConfiguraIRC();
    Connect();
  end;
end;

procedure TForm2.ActConectarExecute(Sender: TObject);
begin
  Conectar();
end;

procedure TForm2.ActSairExecute(Sender: TObject);
begin
  Close();
end;

procedure TForm2.Timer1Timer(Sender: TObject);
begin
  FrameChat1.AddMessage('<< Desconectado automaticamente.', clRed);
  Disconnect();
end;

procedure TForm2.IdIRC1Disconnected(Sender: TObject);
begin
  StatusBar1.Panels[0].Text := 'Desconectado!';
  FInChannel := False;
  Timer1.Enabled := False;

  //Bot�es
  ActConectar.Enabled := True;
  ActDisconectar.Enabled := False;
  ListBox1.Enabled := False;
end;

procedure TForm2.ActDisconectarExecute(Sender: TObject);
begin
  Disconnect();
end;

procedure TForm2.LogControle(s: string);
begin
  LogMsgControle.Lines.Add(s);
end;

procedure TForm2.Action1Execute(Sender: TObject);
begin
  TabControle.TabVisible := not TabControle.TabVisible;
end;

end.

//  TFrameChat(TabPublico.Controls[0]).AddMessage(oldDest);
//  LogRecebidas.SelAttributes.Style := [fsBold];
//  LogRecebidas.Lines.Add(Format('<%s> [%s]: %s',[IdIRC1.RealName,ANickFrom, AMessage]));
//  LogRecebidas.SelAttributes.Color := clBtnText;

