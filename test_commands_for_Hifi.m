%% HiFi bench test - run with Bpod already started
global BpodSystem
sf = 96000;

H = BpodHiFi(BpodSystem.ModuleUSB.HiFi1);
H.SamplingRate = sf;
nEnv = round(sf * 0.002);
H.AMenvelope = (1:nEnv)/nEnv;   % same 2 ms fade the protocol uses

%% 1) plain tone: 0.5 s beep at 3 kHz (this is the trial-start pip)
H.load(1, GenerateSineWave(sf, 3000, 0.5) * 0.9);
H.push; H.play(1);
pause(1);

%% 2) long-offer sweep: 8 kHz -> 1 kHz over 5 s
H.load(1, GenerateSweep(sf, 8000, 1000, 5) * 0.9);
H.push; H.play(1);
pause(6);

%% 3) short-offer sweep: 1700 Hz -> 1 kHz over 2 s (what a 2 s offer sounds like)
H.load(1, GenerateSweep(sf, 1700, 1000, 2) * 0.9);
H.push; H.play(1);
