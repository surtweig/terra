unit USignalPipeline;

interface

uses
	Windows, SysUtils, Bass, Math, UPrimes, Types, UMathEx;

type
	TPinData = single;
	TPinRef = ^TPinData;
	TInputRef = ^TPinRef;
	TOutputRef = TPinRef;

	TNodeInput = array of TPinRef;
	TNodeOutput = array of TPinData;


	TSignalPipelineNode = class

		constructor Create;

		procedure SetInput(index : integer; sourcePin : TPinRef; sourceNode : TSignalPipelineNode = nil);
		function InputCount : integer;
		procedure AddSource(node : TSignalPipelineNode);

		function GetOutput(index : integer = 0) : TPinData;
		function OutputCount : integer;
		function WireOutput(index : integer = 0) : TPinRef;
		
		procedure Reset; virtual;
		
		procedure Update;
		procedure Cycle; virtual;

	protected
		Inputs : TNodeInput;
		Outputs : TNodeOutput;
		Sources : array of TSignalPipelineNode;
		AutoAddInputs, AutoAddOutputs : boolean;
		Updated : boolean;
	
		procedure Process; virtual; abstract;
	
		function AddInput : TInputRef;
		function AddOutput : TOutputRef;
	end;

   TSPTimeSource = class(TSignalPipelineNode)
      constructor Create;
      protected
      	Output : TOutputRef;
         Counter : integer;

			procedure Process; override;
   end;

   TSPConstant = class(TSignalPipelineNode)
      Value : single;

      constructor Create;
      protected
      	Output : TOutputRef;
      	procedure Process; override;
   end;

   TSPSine = class(TSignalPipelineNode)
      Frequency, Phase, Amplitude : single;

      constructor Create;
      procedure SetTimeSource(source : TSignalPipelineNode);
      protected
      	Output : TOutputRef;
         TimeSource : TInputRef;
      	procedure Process; override;
   end;

   TSPCombiner = class(TSignalPipelineNode)

   	Normalize : boolean;

   	constructor Create;
      protected
      	Output : TOutputRef;
      	procedure Process; override;
   end;

   TSPAffineTransformer = class(TSignalPipelineNode)
      Translate, Scale : single;

   	constructor Create;
      protected
      	Output : TOutputRef;
         Input : TInputRef;
      	procedure Process; override;
   end;

   TSPMultiplier = class(TSignalPipelineNode)
   	constructor Create;
      protected
      	Output : TOutputRef;
      	procedure Process; override;
	end;

   TSPModulator = class(TSignalPipelineNode)
   	ModulantsAmplitude : single;

   	constructor Create;
      protected
      	Input : TInputRef;
      	Output : TOutputRef;
      	procedure Process; override;
   end;

   TSPPerlinCosineWave = class(TSignalPipelineNode)
      WaveLength : single;

      constructor Create;
      procedure SetTimeSource(source : TSignalPipelineNode);
      protected
      	Output : TOutputRef;
         TimeSource : TInputRef;

         Frequency, WaveStart, PrevPos, NextPos : single;

      	procedure Process; override;
         function GetNextPos : single;
   end;

   TSPPerlinGaussWave = class(TSignalPipelineNode)
      WaveLength : single;

      constructor Create;
      procedure SetTimeSource(source : TSignalPipelineNode);
      procedure SetConvolutionSize(kernelWidth : integer; kernelSigma : single);

      protected
      	Output : TOutputRef;
         TimeSource : TInputRef;

         WaveStart : single;
         Sigma : single;
         Points : array of single;

         procedure Process; override;
         procedure ScrollConvolution;
   end;

implementation

	constructor TSignalPipelineNode.Create;
   begin
   	setlength(Inputs, 0);
      setlength(Outputs, 0);
      setlength(Sources, 0);
      AutoAddInputs:= false;
      AutoAddOutputs:= false;
      Updated:= false;
   end;

	procedure TSignalPipelineNode.SetInput(index : integer; sourcePin : TPinRef; sourceNode : TSignalPipelineNode);
   begin
   	if index < length(Inputs) then begin
	   	Inputs[index]:= sourcePin;
         if sourceNode <> nil then
         	AddSource(sourceNode);
      end else begin
      	if AutoAddInputs then begin
         	if index = length(Inputs) then begin
		      	setlength(Inputs, index+1);
      		   Inputs[index]:= sourcePin;
               if sourceNode <> nil then
               	AddSource(sourceNode);
            end else
            	raise Exception.Create('TSignalPipelineNode.SetInput : Add #'+IntToStr(length(Inputs))+' input first.');
         end else
         	raise Exception.Create('TSignalPipelineNode.SetInput : No input #'+IntToStr(index));
      end;
   end;

   function TSignalPipelineNode.InputCount : integer;
   begin
		Result:= length(Inputs);
   end;

   procedure TSignalPipelineNode.AddSource(node : TSignalPipelineNode);
   var n, i : integer;

   begin
   	if length(Sources) > 0 then
	   	for i := 0 to high(Sources) do
   	      if Sources[i] = node then
            	Exit;

   	n:= length(Sources);
      setlength(Sources, n+1);
      Sources[n]:= node;
   end;

   function TSignalPipelineNode.GetOutput(index : integer) : TPinData;
   begin
   	if index < length(Outputs) then
	   	Result:= Outputs[index]
      else
      	raise Exception.Create('TSignalPipelineNode.GetOutput : No output #'+IntToStr(index));
   end;

   function TSignalPipelineNode.OutputCount : integer;
   begin
		Result:= length(Outputs);
   end;

   function TSignalPipelineNode.WireOutput(index : integer) : TPinRef;
   begin
   	if index < length(Outputs) then
			Result:= @(Outputs[index])
      else begin
      	if AutoAddInputs then begin
         	if index = length(Outputs) then begin
		      	setlength(Outputs, index+1);
      		   Result:= @(Outputs[index]);
            end else
            	raise Exception.Create('TSignalPipelineNode.WireOutput : Add #'+IntToStr(length(Outputs))+' output first.');
         end else
         	raise Exception.Create('TSignalPipelineNode.WireOutput : No output #'+IntToStr(index));
      end;
   end;

	function TSignalPipelineNode.AddInput : TInputRef;
	var n : integer;

   begin
   	n:= length(Inputs);
      setlength(Inputs, n+1);
      Inputs[n]:= nil;
      Result:= @(Inputs[n]);
   end;

   function TSignalPipelineNode.AddOutput : TOutputRef;
	var n : integer;

   begin
   	n:= length(Outputs);
      setlength(Outputs, n+1);
      Outputs[n]:= 0;
      Result:= @(Outputs[n]);
   end;

   procedure TSignalPipelineNode.Reset;
	var i : integer;

   begin
   	for i := 0 to high(Outputs) do
      	Outputs[i]:= 0;
      Cycle;
   end;

   procedure TSignalPipelineNode.Cycle;
	var
  		i : integer;

   begin
   	Updated:= false;

      for i := 0 to high(Sources) do
      	Sources[i].Cycle;
   end;

	procedure TSignalPipelineNode.Update;
   var i : integer;

   begin
   	if not Updated then begin
	   	for i := 0 to high(Sources) do
   	      Sources[i].Update;

      	Process;
	      Updated:= true;
      end;
   end;


   constructor TSPTimeSource.Create;
   begin
   	inherited Create;
      Output:= AddOutput;
      Counter:= 0;
   end;

   procedure TSPTimeSource.Process;
   begin
		Output^:= Counter*0.0001;
      Counter:= Counter + 1;
   end;


   constructor TSPConstant.Create;
   begin
   	inherited Create;
		Value:= 0;
      Output:= AddOutput;
   end;

   procedure TSPConstant.Process;
   begin
   	Output^:= Value;
   end;


   constructor TSPSine.Create;
   begin
   	inherited Create;
      Frequency:= 1;
      Phase:= 0;
      Amplitude:= 1;
      Output:= AddOutput;
      TimeSource:= AddInput;
   end;

   procedure TSPSine.SetTimeSource(source : TSignalPipelineNode);
   begin
      AddSource(source);
   	TimeSource^:= source.WireOutput();
   end;

   procedure TSPSine.Process;
   begin
   	Output^:= Amplitude * sin(Frequency*(TimeSource^^) + Phase);
   end;


	constructor TSPCombiner.Create;
   begin
   	inherited Create;
      AutoAddInputs:= true;
      Normalize:= true;

      Output:= AddOutput;
   end;

   procedure TSPCombiner.Process;
   var i : integer;

   begin
		Output^:= 0;
      if length(Inputs) > 0 then begin

      	for i := 0 to high(Inputs) do
         	Output^:= Output^ + Inputs[i]^;

	      if Normalize then
   	   	Output^:= Output^ / length(Inputs);
      end;
   end;

	constructor TSPAffineTransformer.Create;
   begin
   	inherited Create;
      Translate:= 0;
      Scale:= 1;

      Output:= AddOutput;
      Input:= AddInput;
   end;

   procedure TSPAffineTransformer.Process;
   begin
		Output^:= Input^^ * Scale + Translate;
   end;


	constructor TSPMultiplier.Create;
   begin
   	inherited Create;
      AutoAddInputs:= true;

      Output:= AddOutput;
   end;

   procedure TSPMultiplier.Process;
	var i : integer;

   begin
   	Output^:= 1;
      if length(Inputs) > 0 then
      	for i := 0 to high(Inputs) do
         	Output^:= Output^ * Inputs[i]^;
   end;


	constructor TSPModulator.Create;
   begin
   	inherited Create;
      AutoAddInputs:= true;
      ModulantsAmplitude:= 1;

      Input:= AddInput;
      Output:= AddOutput;
   end;

   procedure TSPModulator.Process;
   var i : integer;

   begin
		Output^:= Inputs[0]^;
      if length(Inputs) > 1 then
	      for i := 1 to high(Inputs) do
   	      Output^:= Output^ * (0.5*Inputs[i]^ / ModulantsAmplitude + 0.5);
   end;


   constructor TSPPerlinCosineWave.Create;
   begin
		inherited Create;
      WaveLength:= 1;
      WaveStart:= 0;
      PrevPos:= 0;
      NextPos:= GetNextPos;
      //Frequency:= 1/WaveLength;

      Output:= AddOutput;
	   TimeSource:= AddInput;
   end;

   procedure TSPPerlinCosineWave.SetTimeSource(source : TSignalPipelineNode);
   begin
      AddSource(source);
   	TimeSource^:= source.WireOutput();
   end;

   procedure TSPPerlinCosineWave.Process;
	var dt : single;

   begin
   	dt:= (TimeSource^^ - WaveStart) / WaveLength;
      if dt > 1.0 then begin
      	WaveStart:= WaveStart + WaveLength;
         PrevPos:= NextPos;
         NextPos:= GetNextPos;
         dt:= dt - 1.0;
      end;
      Output^:= CosineInterpolation(PrevPos, NextPos, dt);
   end;

   function TSPPerlinCosineWave.GetNextPos;
   begin
      Result:= 2*Random-1;
   end;


   constructor TSPPerlinGaussWave.Create;
   begin
		inherited Create;
      WaveLength:= 1;
      WaveStart:= 0;

      Output:= AddOutput;
	   TimeSource:= AddInput;
      SetConvolutionSize(5, 0.3);
      Output^:= 0;
   end;

   procedure TSPPerlinGaussWave.SetTimeSource(source : TSignalPipelineNode);
   begin
      AddSource(source);
   	TimeSource^:= source.WireOutput();
   end;

   procedure TSPPerlinGaussWave.SetConvolutionSize(kernelWidth : integer; kernelSigma : single);
	var i : integer;

   begin
   	if kernelWidth >= 3 then begin
	   	setlength(Points, kernelWidth);
   	   for i := 1 to high(Points) do
      	   Points[i]:= 2*Random-1;
         Sigma:= kernelSigma;
      end;
   end;

   procedure TSPPerlinGaussWave.Process;
	var dt, f, n, acc : single;
	    i : integer;

   begin
   	dt:= (TimeSource^^ - WaveStart) / WaveLength;
      if dt > 1.0 then begin
      	WaveStart:= WaveStart + WaveLength;
         ScrollConvolution;
         dt:= dt - 1.0;
      end;

      acc:= 0;
      Output^:= 0;
      n:= 1.0/length(Points);
      for i := 0 to high(Points) do begin
         f:= GaussianKernel((i-dt+1)*n*2 - 1, Sigma);
	      Output^:= Output^ + Points[i]*f;
         acc:= acc + f;
      end;
      Output^:= Output^/acc;
   end;

   procedure TSPPerlinGaussWave.ScrollConvolution;
   var i : integer;
   begin
   	for i := 0 to high(Points)-1 do
         Points[i]:= Points[i+1];
      Points[high(Points)]:= (2*Random-1);//*0.0 + 1.0*((round(Points[high(Points)-1]+1) mod 2)*2 - 1)) ;
   end;


end.
