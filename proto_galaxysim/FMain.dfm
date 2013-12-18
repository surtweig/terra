object MainForm: TMainForm
  Left = 282
  Top = 133
  Width = 1416
  Height = 758
  Caption = 'proto_galaxysim'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Viewer: TGLSceneViewer
    Left = 0
    Top = 0
    Width = 1280
    Height = 720
    Camera = Camera
    Buffer.BackgroundColor = clBlack
    FieldOfView = 148.951782226562500000
    TabOrder = 0
  end
  object Scene: TGLScene
    Left = 1296
    Top = 16
    object Camera: TGLCamera
      DepthOfView = 1000.000000000000000000
      FocalLength = 100.000000000000000000
      TargetObject = MassSystem
      Position.Coordinates = {0000C8C2000000000000F0410000803F}
      Direction.Coordinates = {0000803F000000000000008000000000}
      Up.Coordinates = {00000000000000000000803F00000000}
    end
    object MassSystem: TGLDummyCube
      CubeSize = 1.000000000000000000
      object Points: TGLPoints
        NoZWrite = True
        Static = False
        Style = psSmoothAdditive
      end
    end
    object GLLines1: TGLLines
      Visible = False
      Nodes = <>
      Options = []
    end
  end
  object Cadencer: TGLCadencer
    Scene = Scene
    OnProgress = CadencerProgress
    Left = 1336
    Top = 16
  end
end
