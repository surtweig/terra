unit FMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Types, ComCtrls, XPMan,

  Bass, Math, UPrimes, StdCtrls, USignalPipeline, UMathEx, UNoiseGenerators;

type
  TMainForm = class(TForm)
    LFO1FTrackBar: TTrackBar;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    LFO1WLTrackBar: TTrackBar;
    LFO2FTrackBar: TTrackBar;
    LFO2WLTrackBar: TTrackBar;
    FilterSigmaTrackBar: TTrackBar;
    Label5: TLabel;
    LFO1FactorLabel: TLabel;
    LFO1WavelengthLabel: TLabel;
    LFO2FactorLabel: TLabel;
    LFO2WavelengthLabel: TLabel;
    FilterSigmaLabel: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ConfigTrackBarChange(Sender: TObject);
  private
    { Private declarations }
  public
  	 canReadConfig : boolean;

    procedure WriteConfig;
    procedure ReadConfig;
    procedure InitConfig;
  end;

var
  MainForm: TMainForm;

  BASSInfo: BASS_INFO;
  Stream: HSTREAM;

  L : TStringList;

  pnTime : TSPTimeSource;
  noiseL, noiseR : TAirFlowNoiseGenerator;

  lfo1f, lfo2f, lfo1wl, lfo2wl, filtersigma : single;

implementation

{$R *.dfm}


function WriteStream(Handle : HSTREAM; Buffer : Pointer; Len : DWORD; User : Pointer) : DWORD; stdcall;
type
  BufArray = array[0..0] of SmallInt;
var
  I, J, K : Integer;
  fL, fR, e       : Single;
  Buf     : ^BufArray absolute Buffer;
  pcounter : Int64;
begin
	FillChar(Buffer^, Len, 0);
	for K := 0 to (Len div 4 - 1) do begin
      noiseL.Update;
      fL:= noiseL.GetOutput();
      noiseL.Cycle;

      noiseR.Update;
      fR:= noiseR.GetOutput();
      noiseR.Cycle;

      Buf[K * 2 + 1] := round(32766*fL);
      Buf[K * 2]     := round(32766*fR);
      //L.Add(FloatToStr(f) + #9 + FloatToStr(e) + #9 + FloatToStr(pnTime.GetOutput));//FloatToStr(-T*0.000005));
	end;
	Result := Len;
   L.Add(IntToStr(Len) + #9 + IntToStr(Len mod 4));
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
	BASS_Free;
   L.SaveToFile('output.adv');
end;

procedure TMainForm.InitConfig;
begin
	WriteConfig;

	canReadConfig:= false;
   LFO1FTrackBar.Position:= round(lfo1f*100);
   LFO2FTrackBar.Position:= round(lfo2f*100);
   LFO1WLTrackBar.Position:= round((lfo1wl-0.05)*100/1.95);
   LFO2WLTrackBar.Position:= round((lfo2wl-0.05)*100/1.95);
   FilterSigmaTrackBar.Position:= round((filtersigma-0.01)*100/0.99);
   canReadConfig:= true;
end;

procedure TMainForm.WriteConfig;
begin
	LFO1FactorLabel.Caption:= FloatToStrF(lfo1f, ffGeneral, 5, 3);
	LFO1WavelengthLabel.Caption:= FloatToStrF(lfo1wl, ffGeneral, 5, 3);
	LFO2FactorLabel.Caption:= FloatToStrF(lfo2f, ffGeneral, 5, 3);
	LFO2WavelengthLabel.Caption:= FloatToStrF(lfo2wl, ffGeneral, 5, 3);
   FilterSigmaLabel.Caption:= FloatToStrF(filtersigma, ffGeneral, 5, 3);
end;

procedure TMainForm.ReadConfig;
begin
	if canReadConfig then begin
		lfo1f:= LFO1FTrackBar.Position*0.01;
		lfo2f:= LFO2FTrackBar.Position*0.01;
	   lfo1wl:= 1.95*LFO1WLTrackBar.Position*0.01 + 0.05;
   	lfo2wl:= 1.95*LFO2WLTrackBar.Position*0.01 + 0.05;
	   filtersigma:= 0.99*FilterSigmaTrackBar.Position*0.01 + 0.01;

      noiseL.SetLFORatio(lfo1f, lfo2f);
      noiseL.SetLFOWavelengths(lfo1wl, lfo2wl);
      noiseL.SetWaveFiltersSigma(filtersigma);
      noiseR.SetLFORatio(lfo1f, lfo2f);
      noiseR.SetLFOWavelengths(lfo1wl, lfo2wl);
      noiseR.SetWaveFiltersSigma(filtersigma);
   end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var i : integer;
begin
   L:= TStringList.Create;
   L.Add('#Len'#9'LenMod4');//'#f'#9'e'#9't');

   lfo1f:= 0.8;
   lfo1wl:= 0.3;
   lfo2f:= 0.5;
   lfo2wl:= 0.7;
   filtersigma:= 0.15;
   InitConfig;

   pnTime:= TSPTimeSource.Create;

   noiseL:= TAirFlowNoiseGenerator.Create(8);
   noiseL.SetTimeSource(pnTime);
   noiseR:= TAirFlowNoiseGenerator.Create(8);
   noiseR.SetTimeSource(pnTime);

   ReadConfig;

  	BASS_SetConfig(BASS_CONFIG_UPDATEPERIOD, 200);
   BASS_Init(-1, 22050, BASS_DEVICE_LATENCY, 0, NIL);
   BASS_GetInfo(BASSInfo);
   BASS_SetConfig(BASS_CONFIG_BUFFER, 200 + BASSInfo.minbuf);
   if BASSInfo.freq = 0 then BASSInfo.freq := 22050;

   Stream := BASS_StreamCreate(BASSInfo.freq, 2, 0, @WriteStream, NIL);
   BASS_ChannelPlay(Stream, False);
end;

procedure TMainForm.ConfigTrackBarChange(Sender: TObject);
begin
	ReadConfig;
   WriteConfig;
end;

end.
