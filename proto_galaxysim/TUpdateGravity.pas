unit TUpdateGravity;

interface

uses
  Classes;

type
  TUpdateGravityThread = class(TThread)
  private
    { Private declarations }
  protected
    procedure Execute; override;
  end;

implementation

{ Important: Methods and properties of objects in visual components can only be
  used in a method called using Synchronize, for example,

      Synchronize(UpdateCaption);

  and UpdateCaption could look like,

    procedure TUpdateGravityThread.UpdateCaption;
    begin
      Form1.Caption := 'Updated in a thread';
    end; }

{ TUpdateGravityThread }

procedure TUpdateGravityThread.Execute;
begin
  { Place thread code here }
end;

end.
