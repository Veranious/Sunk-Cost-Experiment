global BpodSystem
H = BpodHiFi(BpodSystem.ModuleUSB.HiFi1);
H.SamplingRate = 96000;
H.load(1, GenerateSineWave(96000, 3000, 0.5));
H.push;
H.play(1);

H.load(1, GenerateSweep(96000, 8000, 1000, 5));  % 5 s descent, needs the helper on your path
H.push; H.play(1);
