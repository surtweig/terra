unit FMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, GR32, GR32_Image, UTextTerminal;

type
  TMainForm = class(TForm)
    Display: TImage32;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
    procedure Madness;
  end;

var
  MainForm: TMainForm;
  tt : TTextModeTerminal;
  flag : boolean = false;
  //Perfect DOS VGA 437 Win

implementation

{$R *.dfm}

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
	flag:= false;
end;

procedure TMainForm.FormCreate(Sender: TObject);

begin
	tt:= TTextModeTerminal.Create(80, 25);
	tt.SetupFont('DOSLike', 12, 0, 0);
	tt.SetupPalette(TCGA16Palette.Create);

	tt.FillMatrix(0);
	tt.TextStyle(15, 1);
   tt.TextOutLine('Hello, World!');

	tt.Update;
   Display.Bitmap:= tt.Screen;
end;

procedure TMainForm.FormKeyPress(Sender: TObject; var Key: Char);
begin
//	tt.TextOutLine('Key:'+Key);
//	Display.Bitmap:= tt.Update;
	flag:= not flag;

	if flag then
		Madness;
end;

procedure TMainForm.Madness;
var i, j : integer;

begin
   while flag do begin

		for i:= 0 to tt.Columns-1 do
			for j:= 0 to tt.Rows-1 do begin
            tt.Cursor:= Point(i, j);
         	tt.TextStyle(Random(16), Random(16));
				tt.TextOut(char(Random(256)), false, false, false);
         end;

		Display.Bitmap:= tt.Update;
      Application.ProcessMessages;
   end;
end;

end.
