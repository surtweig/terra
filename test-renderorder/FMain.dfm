object MainForm: TMainForm
  Left = 560
  Top = 179
  Width = 772
  Height = 573
  Caption = 'test-renderorder'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 13
  object Viewer: TGLSceneViewer
    Left = 0
    Top = 0
    Width = 756
    Height = 535
    Camera = Camera
    Buffer.BackgroundColor = clBlack
    Buffer.AmbientColor.Color = {0000000000000000000000000000803F}
    FieldOfView = 139.005325317382800000
    Align = alClient
    TabOrder = 0
  end
  object Scene: TGLScene
    ObjectsSorting = osNone
    Left = 8
    Top = 8
    object Camera: TGLCamera
      DepthOfView = 100.000000000000000000
      FocalLength = 100.000000000000000000
      Position.Coordinates = {0000803F00000000000000000000803F}
    end
    object Cube2: TGLCube
      Material.MaterialLibrary = MaterialLibrary
      Material.LibMaterialName = 'Mat2'
      Position.Coordinates = {00000000000000000000A0C00000803F}
      CubeSize = {000000400000004000000040}
    end
    object DGLClearBuffer: TGLDirectOpenGL
      UseBuildList = False
      OnRender = DGLClearBufferRender
      Blend = False
    end
    object Cube1: TGLCube
      Material.MaterialLibrary = MaterialLibrary
      Material.LibMaterialName = 'Mat1'
      Position.Coordinates = {0000000000000000000070C10000803F}
    end
    object Cube3: TGLCube
      Material.MaterialLibrary = MaterialLibrary
      Material.LibMaterialName = 'Mat3'
      Position.Coordinates = {00000000000000000000A0C10000803F}
      Visible = False
      CubeSize = {000080400000804000008040}
    end
  end
  object Cadencer: TGLCadencer
    Scene = Scene
    Left = 40
    Top = 8
  end
  object MaterialLibrary: TGLMaterialLibrary
    Materials = <
      item
        Name = 'Mat1'
        Material.FrontProperties.Ambient.Color = {0000000000000000000000000000803F}
        Material.FrontProperties.Diffuse.Color = {0000000000000000000000000000803F}
        Material.FrontProperties.Emission.Color = {0000803F00000000000000000000803F}
        Tag = 0
      end
      item
        Name = 'Mat2'
        Material.FrontProperties.Ambient.Color = {0000000000000000000000000000803F}
        Material.FrontProperties.Diffuse.Color = {0000000000000000000000000000803E}
        Material.FrontProperties.Emission.Color = {00000000000000000000803F0000803F}
        Tag = 0
      end
      item
        Name = 'Mat3'
        Material.FrontProperties.Ambient.Color = {0000000000000000000000000000803F}
        Material.FrontProperties.Diffuse.Color = {0000000000000000000000000000003F}
        Material.FrontProperties.Emission.Color = {000000000000803F000000000000803F}
        Material.BlendingMode = bmTransparency
        Tag = 0
      end>
    Left = 72
    Top = 8
  end
end
