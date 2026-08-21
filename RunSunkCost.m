function RunSunkCost

global BpodSystem

% SOUND MAP (HiFi wave slots; play byte is slot-1):
%   slot 1 ['P' 0] = offer tone O    - static pitch encoding ORIGINAL offer  (PlayOfferTone)
%   slot 2 ['P' 1] = offer tone R    - static pitch encoding NEW offer       (NewOfferTone)
%   slot 3 ['P' 2] = decay sweep O   - startHz(O) -> ThresholdHz over offerTime   (AcceptOffer)
%   slot 4 ['P' 3] = decay sweep R   - startHz(R) -> ThresholdHz over NewOffer    (DecreaseNew)
%   slot 5 ['P' 4] = reward tone                                             (RewardDelivery)
%   slot 6 ['P' 5] = reject/abort tone (playing any wave interrupts others)  (RejectOffer, RejectOfferWait)
%   slot 7 ['P' 6] = trial-start tone                                        (OfferAvailable)
%   'X'            = stop all playback, silent reset                         (ITI)
%
% PITCH CODE: pitch = ThresholdHz * r^(timeRemaining/PitchMax), r = HzMax/ThresholdHz,
%             PitchMax = max(OfferMax, NewOfferMax).
%   -> LOG-pitch is linear in time remaining: every second is a constant PERCENTAGE
%      step (not a constant Hz step), which is what Weber's law says the ear resolves.
%      Long offers start high, short offers start low; O and R share one scale.
%
% GLOBAL TIMERS (run independently of states in order to survive grace periods):
%   GT1 = waitDuration (is reviseTime on revise trials, is offerTime otherwise)
%   GT2 = NewOffer (second new offer countdown)

%% HiFi module setup
BpodSystem.assertModule('HiFi', 1);
H = BpodHiFi(BpodSystem.ModuleUSB.HiFi1);
sf = 96000;
H.SamplingRate = sf;
H.HeadphoneAmpEnabled = true; H.HeadphoneAmpGain = 10;  % ignored on HD module
H.DigitalAttenuation_dB = 0;   % negative = quieter; tune at the rig
H.SynthAmplitude = 0;          % make sure the synth is silent
nEnv = round(sf * 0.002);      % 2 ms fade applied at every sound onset,
H.AMenvelope = (1:nEnv)/nEnv;  % and mirrored at offset - kills speaker clicks

%% Parameters (editable GUI)
S = BpodSystem.ProtocolSettings; % load settings chosen in launch manager
if isempty(fieldnames(S))
    S.GUI.RewardAmount = 3;      % ul, converted to valve time via calibration
    %Ks MUST BE > 0
    S.GUI.OfferShapeK  = 1;      % Distribution of Offer times (k = 1 uniform | k < 1 U-shaped | k > 1 bell)
    S.GUI.NOfferShapeK = 1;      % Distribution of New Offer times (same convention)
    S.GUI.ROfferShapeK = 1;      % Distribution of Revise times (same convention)
    %
    S.GUI.OfferMin     = 2;      % s, keep > ReviseTimeMin (see guard in trial-type branch)
    S.GUI.OfferMax     = 20;     % s
    S.GUI.ReviseTimeMin = 0.5;   % s, minimum elapsed wait before a revise can fire
    S.GUI.ReviseTimeMax = 20;    % s, cap on revise timing (extra leverage)
    S.GUI.NewOfferMin  = 2;      % s
    S.GUI.NewOfferMax  = 20;     % s
    S.GUI.ReviseProb   = 0.5;    % probability a trial gets a revise offer (yes/no)
    % TONE RANGE: 1000-8000 Hz is fully audible to a human, good for bench testing.
    % Note : BEFORE RUNNING RATS, consider 4000/20000 instead: rats are most sensitive
    %      : around 8-38 kHz and relatively deaf near 1 kHz, which is exactly where the
    %      : countdown spends its final, most decision-critical seconds.
    S.GUI.HzMax        = 8000;   % pitch of the LONGEST possible offer (OfferMax)
    S.GUI.ThresholdHz  = 1000;   % pitch at reward time (sweep endpoint)
end
BpodParameterGUI('init', S);

MaxTrials = 200;

%% Fixed sounds (those that are the same every trial, so loaded and pushed once here.)
%% push() only commits slots that were newly loaded, so these survive the per-trial pushes below.
rewardTone     = GenerateSineWave(sf, 4000, 0.2) * 0.9;   % slot 5
rejectTone     = GenerateSineWave(sf, 300, 0.15) * 0.6;   % slot 6 - brief, low, deliberately neutral
trialStartTone = GenerateSineWave(sf, 3000, 0.1) * 0.9;   % slot 7
H.load(5, rewardTone);
H.load(6, rejectTone);
H.load(7, trialStartTone);
H.push;

%%logs for data
BpodSystem.Data.OfferTime   = []; % original offer O (s)
BpodSystem.Data.NewOffer    = []; % new offer R (s), independent of O (NaN if none)
BpodSystem.Data.ReviseTime  = []; % wait elapsed when revise fires = sunk cost S (NaN if none)
BpodSystem.Data.DoRevise    = []; % 1 = revise trial, 0 = normal trial

%%The Trial specific code
for trialNum = 1:MaxTrials

    S = BpodParameterGUI('sync', S); %%which pulls any live GUI changes

    %% Reward valve time from the liquid calibration table (port 3 = wait/reward port)
     try
        vt = GetValveTimes(S.GUI.RewardAmount, 3);
        RewardValveTime = vt(1);
    catch %% DRY BENCH TEST
        RewardValveTime = 0.1;   % no calibration table yet - dry bench test
        if trialNum == 1
            warning('No liquid calibration for port 3. Using RewardValveTime = 0.1 s.');
        end
    end

    %% Draw this trial's revision decision schedule up front
    offerTime = shapedRand(S.GUI.OfferShapeK) * (S.GUI.OfferMax - S.GUI.OfferMin) + S.GUI.OfferMin;
    doRevise  = rand < S.GUI.ReviseProb;
    hi = min(S.GUI.ReviseTimeMax, offerTime);   % revise can never land past the actual offer

    %% Build & upload this trial's sounds
    PitchMax = max(S.GUI.OfferMax, S.GUI.NewOfferMax);  % duration that maps to HzMax
    r        = S.GUI.HzMax / S.GUI.ThresholdHz;         % total pitch ratio, e.g. 8 = 3 octaves
    startHzO = S.GUI.ThresholdHz * r^(offerTime / PitchMax);
    offerToneO = GenerateSineWave(sf, startHzO, 0.5) * 0.9;
    sweepO     = GenerateSweep(sf, startHzO, S.GUI.ThresholdHz, offerTime) * 0.9;
    H.load(1, offerToneO);
    H.load(3, sweepO);

    %% Trial-type branch: sets the first countdown's length and where it leads, plus its sounds depends on doRevise
    if doRevise && hi > S.GUI.ReviseTimeMin %%guards against OfferMin < ReviseTimeMin settings
        reviseTime   = S.GUI.ReviseTimeMin + shapedRand(S.GUI.ROfferShapeK) * (hi - S.GUI.ReviseTimeMin);
        waitDuration = reviseTime;
        waitEndDest  = 'NewOfferTone';
        NewOffer     = shapedRand(S.GUI.NOfferShapeK) * (S.GUI.NewOfferMax - S.GUI.NewOfferMin) + S.GUI.NewOfferMin;
        startHzR   = S.GUI.ThresholdHz * r^(NewOffer / PitchMax);
        offerToneR = GenerateSineWave(sf, startHzR, 0.5) * 0.9;
        sweepR     = GenerateSweep(sf, startHzR, S.GUI.ThresholdHz, NewOffer) * 0.9;
        H.load(2, offerToneR);
        H.load(4, sweepR);
    else
        doRevise     = false;   %keep the log honest if the guard blocked it
        reviseTime   = NaN;
        waitDuration = offerTime;
        waitEndDest  = 'RewardDelivery';
        NewOffer     = NaN;
    end

    H.push;   % commit new waveforms to the playback buffers

    sma = NewStateMachine;

    %% Global timers: countdowns that keep running across state changes
    gt2Duration = NewOffer;
    if isnan(gt2Duration)
        gt2Duration = 1;   % placeholder : GT2 is never triggered on non-revise trials
    end
    sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', waitDuration);
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', gt2Duration);

    %% Condition 1: Port 3 is LOW (rat is currently out) - level test
    sma = SetCondition(sma, 1, 'Port3', 0);

    %% Offer available (light cue)
    sma = AddState(sma,'Name','OfferAvailable',...
        'Timer',0,...
        'StateChangeConditions',{'Port2In','PlayOfferTone'},...
        'OutputActions',{'HiFi1',['P' 6],'PWM2',255}); %%trial-start tone (slot 7)

    %% START OFFER + SOUND
    sma = AddState(sma,'Name','PlayOfferTone',...
        'Timer',0,...
        'StateChangeConditions',{'Port1In','RejectOffer',...
                                 'Port3In','AcceptOffer'},...
        'OutputActions',{'HiFi1',['P' 0],'PWM1',255,'PWM3',255}); %%offer tone O (slot 1)

    %% ACCEPT: start the decay sweep AND the countdown together
    sma = AddState(sma,'Name','AcceptOffer',...
        'Timer',0.1,...
        'StateChangeConditions',{'Tup','WaitingForReward',...
                                 'Port3Out','GracePeriod1',...
                                 'GlobalTimer1_End',waitEndDest},... %%safe if GT1 is ever ~0
        'OutputActions',{'HiFi1',['P' 2],'GlobalTimerTrig',1,'PWM3',255}); %%decay sweep O (slot 3)

    %% WAIT: no Tup - GT1 decides when this ends, and where it goes
    sma = AddState(sma,'Name','WaitingForReward',...
        'Timer',0,...
        'StateChangeConditions',{'GlobalTimer1_End',waitEndDest,...
                                 'Port3Out','GracePeriod1'},...
        'OutputActions',{'PWM3',255});

    %% NEW OFFER (revise trials only)
    sma = AddState(sma,'Name','NewOfferTone',...
        'Timer',0.1,...
        'StateChangeConditions',{'Tup','DecreaseNew',...
                                 'Port3Out','GracePeriod2'},...
        'OutputActions',{'HiFi1',['P' 1],'PWM3',255});   %%offer tone R (slot 2)
    sma = AddState(sma,'Name','DecreaseNew',...
        'Timer',0.1,...
        'StateChangeConditions',{'Tup','WaitingForRewardNew',...
                                 'Port3Out','GracePeriod3'},...
        'OutputActions',{'HiFi1',['P' 3],'GlobalTimerTrig',2,'PWM3',255}); %%decay sweep R (slot 4)
    sma = AddState(sma,'Name','WaitingForRewardNew',...
        'Timer',0,...
        'StateChangeConditions',{'GlobalTimer2_End','RewardDelivery',...
                                 'Port3Out','GracePeriod3'},...
        'OutputActions',{'PWM3',255});

    %% GRACE PERIODS (countdowns and sweeps keep running throughout - both are hardware now)
    sma = AddState(sma,'Name','GracePeriod1',...
        'Timer',0.5,...
        'StateChangeConditions',{'Tup','RejectOfferWait',...
                                 'Port3In','WaitingForReward',...
                                 'GlobalTimer1_End',waitEndDest},...
        'OutputActions',{'PWM3',128});
    sma = AddState(sma,'Name','GracePeriod2',...
        'Timer',0.5,...
        'StateChangeConditions',{'Tup','RejectOfferWait',...
                                 'Port3In','DecreaseNew'},...
        'OutputActions',{'PWM3',128});
    sma = AddState(sma,'Name','GracePeriod3',...
        'Timer',0.5,...
        'StateChangeConditions',{'Tup','RejectOfferWait',...
                                 'Port3In','WaitingForRewardNew',...
                                 'GlobalTimer2_End','RewardDelivery'},...
        'OutputActions',{'PWM3',128});

    %% REWARD
    sma = AddState(sma,'Name','RewardDelivery',...
        'Timer',RewardValveTime,...
        'StateChangeConditions',{'Tup','Drinking'},...
        'OutputActions',{'Valve3',1,'HiFi1',['P' 4]}); %%reward tone (slot 5) interrupts the sweep
    sma = AddState(sma,'Name','Drinking',...
        'Timer',0,...
        'StateChangeConditions',{'Condition1','DrinkingGrace'},...
        'OutputActions',{});
    sma = AddState(sma,'Name','DrinkingGrace',...
        'Timer',0.5,...
        'StateChangeConditions',{'Tup','ITI',...
                                 'Port3In','Drinking'},...
        'OutputActions',{});

    %% REJECT
    sma = AddState(sma,'Name','RejectOffer',...
        'Timer',2,...
        'StateChangeConditions',{'Tup','ITI'},...
        'OutputActions',{'PWM2',255,'HiFi1',['P' 5]}); %%reject tone (slot 6) interrupts any sweep
    sma = AddState(sma,'Name','RejectOfferWait',...
        'Timer',2,...
        'StateChangeConditions',{'Tup','ITI'},...
        'OutputActions',{'PWM2',255,'HiFi1',['P' 5]}); %%reject tone

    %% ITI
    sma = AddState(sma,'Name','ITI',...
        'Timer',2,...
        'StateChangeConditions',{'Tup','exit'},...
        'OutputActions',{'HiFi1','X'}); %%hard stop on all playback - silent safety net

    SendStateMachine(sma);
    RawEvents = RunStateMachine; %%results returned at trial end

    if ~isempty(fieldnames(RawEvents)) % if trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
        BpodSystem.Data.TrialSettings(trialNum) = S;          %%params this trial ran under
        BpodSystem.Data.OfferTime(trialNum)     = offerTime;
        BpodSystem.Data.NewOffer(trialNum)      = NewOffer;
        BpodSystem.Data.ReviseTime(trialNum)    = reviseTime; %%NaN on non-revise trials
        BpodSystem.Data.DoRevise(trialNum)      = doRevise;
        SaveBpodSessionData();  %%write to disk
    else
        warning('Trial %d failed', trialNum);
    end
    
    HandlePauseCondition(); %respects the pause button
    if BpodSystem.Status.BeingUsed == 0
        H.stop;             % silence any sound still playing when the user hits Stop
        return                  % respects the stop button
    end
end
end

function u = shapedRand(k)
%% Shaped random number on [0,1]
%   k = 1 uniform | k < 1 U-shaped (mass at extremes) | k > 1 bell (mass in middle)
v = 2*rand - 1;                      % uniform on [-1, 1]
u = 0.5 * (1 + sign(v) * abs(v)^k);  % reshaped, still on [0, 1]
end

function w = GenerateSweep(sf, f0, f1, dur)
%% Exponential (log-linear) frequency sweep, f0 -> f1 Hz over dur seconds.
%  Descends at a constant octaves/second, so perceived rate of change is uniform.
%  Phase is still the integral of frequency - only the frequency curve changed.
n     = round(dur * sf);
f     = f0 * (f1/f0).^linspace(0, 1, n);   % geometric steps (was: linspace, arithmetic)
phase = 2*pi*cumsum(f)/sf;                 % numerical integration
w     = sin(phase);
end
