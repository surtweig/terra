object MainForm: TMainForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'test-audiogen'
  ClientHeight = 361
  ClientWidth = 645
  Color = clWhite
  Font.Charset = ANSI_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Verdana'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 16
    Top = 24
    Width = 70
    Height = 13
    Caption = 'LFO-1 factor'
  end
  object Label2: TLabel
    Left = 16
    Top = 164
    Width = 70
    Height = 13
    Caption = 'LFO-2 factor'
  end
  object Label3: TLabel
    Left = 16
    Top = 94
    Width = 102
    Height = 13
    Caption = 'LFO-1 wavelength'
  end
  object Label4: TLabel
    Left = 16
    Top = 234
    Width = 102
    Height = 13
    Caption = 'LFO-2 wavelength'
  end
  object Label5: TLabel
    Left = 16
    Top = 304
    Width = 66
    Height = 13
    Caption = 'Filter sigma'
  end
  object LFO1FactorLabel: TLabel
    Left = 576
    Top = 24
    Width = 18
    Height = 13
    Caption = '0,2'
  end
  object LFO1WavelengthLabel: TLabel
    Left = 576
    Top = 94
    Width = 18
    Height = 13
    Caption = '0,2'
  end
  object LFO2FactorLabel: TLabel
    Left = 576
    Top = 164
    Width = 18
    Height = 13
    Caption = '0,2'
  end
  object LFO2WavelengthLabel: TLabel
    Left = 576
    Top = 234
    Width = 18
    Height = 13
    Caption = '0,2'
  end
  object FilterSigmaLabel: TLabel
    Left = 576
    Top = 304
    Width = 18
    Height = 13
    Caption = '0,2'
  end
  object LFO1FTrackBar: TTrackBar
    Left = 136
    Top = 8
    Width = 417
    Height = 45
    DoubleBuffered = True
    Max = 100
    ParentDoubleBuffered = False
    Frequency = 2
    ShowSelRange = False
    TabOrder = 0
    TabStop = False
    ThumbLength = 25
    TickMarks = tmBoth
    OnChange = ConfigTrackBarChange
  end
  object LFO1WLTrackBar: TTrackBar
    Left = 136
    Top = 78
    Width = 417
    Height = 45
    DoubleBuffered = True
    Max = 100
    ParentDoubleBuffered = False
    Frequency = 2
    ShowSelRange = False
    TabOrder = 1
    TabStop = False
    ThumbLength = 25
    TickMarks = tmBoth
    OnChange = ConfigTrackBarChange
  end
  object LFO2FTrackBar: TTrackBar
    Left = 136
    Top = 148
    Width = 417
    Height = 45
    DoubleBuffered = True
    Max = 100
    ParentDoubleBuffered = False
    Frequency = 2
    ShowSelRange = False
    TabOrder = 2
    TabStop = False
    ThumbLength = 25
    TickMarks = tmBoth
    OnChange = ConfigTrackBarChange
  end
  object LFO2WLTrackBar: TTrackBar
    Left = 136
    Top = 218
    Width = 417
    Height = 45
    DoubleBuffered = True
    Max = 100
    ParentDoubleBuffered = False
    Frequency = 2
    ShowSelRange = False
    TabOrder = 3
    TabStop = False
    ThumbLength = 25
    TickMarks = tmBoth
    OnChange = ConfigTrackBarChange
  end
  object FilterSigmaTrackBar: TTrackBar
    Left = 136
    Top = 288
    Width = 417
    Height = 45
    DoubleBuffered = True
    Max = 100
    ParentDoubleBuffered = False
    Frequency = 2
    ShowSelRange = False
    TabOrder = 4
    TabStop = False
    ThumbLength = 25
    TickMarks = tmBoth
    OnChange = ConfigTrackBarChange
  end
end
