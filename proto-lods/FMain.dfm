object MainForm: TMainForm
  Left = 467
  Top = 299
  Width = 1148
  Height = 580
  Caption = 'proto-lods'
  Color = clBtnFace
  Font.Charset = ANSI_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Verdana'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  DesignSize = (
    1132
    542)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 504
    Width = 37
    Height = 13
    Caption = 'Label1'
  end
  object Viewer: TGLSceneViewer
    Left = 0
    Top = 0
    Width = 870
    Height = 497
    Camera = Camera
    Buffer.BackgroundColor = clBlack
    FieldOfView = 144.309982299804700000
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 0
  end
  object Memo1: TMemo
    Left = 880
    Top = 8
    Width = 241
    Height = 401
    ScrollBars = ssVertical
    TabOrder = 1
    Visible = False
  end
  object Scene: TGLScene
    Left = 80
    Top = 64
    object Camera: TGLCamera
      DepthOfView = 1000.000000000000000000
      FocalLength = 80.000000000000000000
      NearPlaneBias = 0.100000001490116100
      Direction.Coordinates = {000080BF000000000000000000000000}
    end
    object LightSource1: TGLLightSource
      ConstAttenuation = 1.000000000000000000
      SpotCutOff = 180.000000000000000000
    end
    object LevelsContainer: TGLDummyCube
      ObjectsSorting = osNone
      CubeSize = 1.000000000000000000
    end
    object GLIcosahedron1: TGLIcosahedron
    end
  end
  object Cadencer: TGLCadencer
    Scene = Scene
    OnProgress = CadencerProgress
    Left = 136
    Top = 64
  end
  object XPManifest1: TXPManifest
    Left = 912
    Top = 256
  end
end
