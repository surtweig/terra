unit UNoiseGenerators;

interface

uses Math, UMathEx, USignalPipeline, UPrimes;

type
	TAirFlowNoiseGenerator = class(TSignalPipelineNode)

   	constructor Create(octavesNumber : integer);

      procedure SetTimeSource(source : TSignalPipelineNode);
      procedure SetFlowVelocity(source : TSignalPipelineNode);

      procedure SetLFORatio(lfo1, lfo2 : single);
      procedure SetLFOWavelengths(lfo1, lfo2 : single);
      procedure SetWaveFiltersSigma(sigma : single);

      protected
      	TimeSource, FlowVelocity : TInputRef;
         Output : TOutputRef;

         Waves : array of TSPPerlinGaussWave;
         WaveTransformers : array of TSPAffineTransformer;
         Combiner : TSPCombiner;

         LFOSource : TSPPerlinGaussWave;
         LFOTransformer : TSPAffineTransformer;
         LFOModulator : TSPModulator;

         LFOSource2 : TSPPerlinGaussWave;
         LFOTransformer2 : TSPAffineTransformer;


         procedure Process; override;
         procedure Build(octavesNumber : integer); virtual;
   end;

implementation

	constructor TAirFlowNoiseGenerator.Create(octavesNumber : integer);
   begin
   	inherited Create;

      Output:= AddOutput;
      TimeSource:= AddInput;
      FlowVelocity:= AddInput;

   	Build(octavesNumber);
   end;

	procedure TAirFlowNoiseGenerator.SetTimeSource(source : TSignalPipelineNode);
   var i : integer;

   begin
   	for i := 0 to high(Waves) do
	      Waves[i].SetTimeSource(source);

      LFOSource.SetTimeSource(source);
      LFOSource2.SetTimeSource(source);
   end;

	procedure TAirFlowNoiseGenerator.SetFlowVelocity(source : TSignalPipelineNode);
   begin
      AddSource(source);
   	FlowVelocity^:= source.WireOutput();
   end;

	procedure TAirFlowNoiseGenerator.Process;
   begin
   	Output^:= LFOModulator.GetOutput();
   end;

   procedure TAirFlowNoiseGenerator.Build(octavesNumber : integer);
	var i : integer;

   begin
   	setlength(Waves, octavesNumber);
      setlength(WaveTransformers, octavesNumber);

      Combiner:= TSPCombiner.Create;

   	for i := 0 to high(Waves) do begin
         Waves[i]:= TSPPerlinGaussWave.Create;
         Waves[i].WaveLength:= 0.1/Power(2, i);
         Waves[i].SetConvolutionSize(5 + 5*i, 0.1);

         WaveTransformers[i]:= TSPAffineTransformer.Create;
         //WaveTransformers[i].Scale:= 1/(i+1);
         WaveTransformers[i].SetInput(0, Waves[i].WireOutput(), Waves[i]);

         Combiner.SetInput(i, WaveTransformers[i].WireOutput(), WaveTransformers[i]);
      end;

      LFOSource:= TSPPerlinGaussWave.Create;
      LFOSource.WaveLength:= 0.1;

      LFOTransformer:= TSPAffineTransformer.Create;
      LFOTransformer.Scale:= 0.8;
      LFOTransformer.Translate:= 0.2;
      LFOTransformer.SetInput(0, LFOSource.WireOutput(), LFOSource);

      LFOSource2:= TSPPerlinGaussWave.Create;
      LFOSource2.WaveLength:= 0.37;

      LFOTransformer2:= TSPAffineTransformer.Create;
      LFOTransformer2.Scale:= 0.5;
      LFOTransformer2.Translate:= 0.5;
      LFOTransformer2.SetInput(0, LFOSource2.WireOutput(), LFOSource2);

      LFOModulator:= TSPModulator.Create;
		LFOModulator.SetInput(0, Combiner.WireOutput(), Combiner);
      LFOModulator.SetInput(1, LFOTransformer.WireOutput(), LFOTransformer);
      LFOModulator.SetInput(2, LFOTransformer2.WireOutput(), LFOTransformer2);

      AddSource(LFOModulator);
   end;

   procedure TAirFlowNoiseGenerator.SetLFORatio(lfo1, lfo2 : single);
   begin
      LFOTransformer.Scale:= lfo1;
      LFOTransformer.Translate:= 1-lfo1;
      LFOTransformer2.Scale:= lfo2;
      LFOTransformer2.Translate:= 1-lfo2;
   end;

   procedure TAirFlowNoiseGenerator.SetLFOWavelengths(lfo1, lfo2 : single);
   begin
   	LFOSource.WaveLength:= lfo1;
   	LFOSource2.WaveLength:= lfo2;
   end;

   procedure TAirFlowNoiseGenerator.SetWaveFiltersSigma(sigma : single);
   var i : integer;

   begin
   	for i := 0 to high(Waves) do
         Waves[i].SetConvolutionSize(5 + 5*i, sigma);
   end;

end.
