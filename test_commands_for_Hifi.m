%% HiFi bench test - run with Bpod already started
global BpodSystem
sf = 96000;

clear H
H = BpodHiFi(BpodSystem.ModuleUSB.HiFi1);
H.SamplingRate = sf;
nEnv = round(sf * 0.002);
H.AMenvelope = (1:nEnv)/nEnv;   % same 2 ms fade the protocol uses

%% 1) plain tone: 0.5 s beep at 3 kHz (this is the trial-start pip)
H.load(1, GenerateSineWave(sf, 3000, 0.5) * 0.9);
H.push; H.play(1);
pause(1);

%% 2) long-offer sweep: 8 kHz -> 1 kHz over 5 s
GenerateSweep = @(sf,f0,f1,dur) sin(2*pi*cumsum(linspace(f0,f1,round(dur*sf)))/sf);
H.load(1, GenerateSweep(sf, 8000, 1000, 5) * 0.9);
H.push; H.play(1);
pause(6);

%% 3) short-offer sweep: 1700 Hz -> 1 kHz over 2 s (what a 2 s offer sounds like)
GenerateSweep = @(sf,f0,f1,dur) sin(2*pi*cumsum(linspace(f0,f1,round(dur*sf)))/sf);
H.load(1, GenerateSweep(sf, 1700, 1000, 2) * 0.9);
H.push; H.play(1);

%% 4) what a revise sounds like: 3 s into a 10 s offer, the offer changes
GenerateSweep = @(sf,f0,f1,dur) sin(2*pi*cumsum(linspace(f0,f1,round(dur*sf)))/sf);
H.load(1, GenerateSweep(sf, 8000, 1000, 10) * 0.9);   % original 10 s offer
H.load(2, GenerateSweep(sf, 2400, 1000, 4)  * 0.9);   % new 4 s offer (good news)
H.push;
H.play(1); pause(3);   % listen to 3 s of the original descent
H.play(2);             % revise fires
