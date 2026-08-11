function RunSunkCost

global BpodSystem SoundParams %%parameters for both run file & handler

% SOFT CODE MAP (all FSM -> handler, sound only):
%   1 = offer tone O      - announces the ORIGINAL offer    (PlayOfferTone)
%   2 = offer tone R      - announces the REVISED offer     (NewOfferTone)
%   3 = decay sweep over CurrentOffer                       (AcceptOffer)
%   4 = decay sweep over NewOffer                        (DecreaseNew)
%   5 = stop decay, play reward tone                        (RewardDelivery)
%   6 = STOP all sound + play reject/abort tone             (RejectOffer, RejectOfferWait)
%   7 = STOP all sound, silent reset (safety net)           (ITI)
%   8 = trial-start tone  - announces a new trial           (OfferAvailable)
%
% GLOBAL TIMERS (run independently of states, survive grace periods):
%   GT1 = waitDuration (reviseTime on revise trials, offerTime otherwise)
%   GT2 = NewOffer  (revised countdown)

%% Parameters (editable GUI)
S = BpodSystem.ProtocolSettings; % load settings chosen in launch manager
if isempty(fieldnames(S))
    S.GUI.RewardAmount = 3;      % ul, converted to valve time via calibration
    S.GUI.OfferShapeK  = 1;      % Distribution of Offer times (k = 1 uniform | k < 1 U-shaped (mass at extremes) | k > 1 bell (mass in middle))
    S.GUI.NOfferShapeK = 1;      % Distribution of New Offer times (k = 1 uniform | k < 1 U-shaped (mass at extremes) | k > 1 bell (mass in middle))
    S.GUI.ROfferShapeK = 1;      % Distribution of Revised Offer time (k = 1 uniform | k < 1 U-shaped (mass at extremes) | k > 1 bell (mass in middle))
    S.GUI.OfferMin     = 2;      % s, make sure that this is > ReviseTimeMin, or we get small probabilities for doRevise (see doRevise && hi > S.GUI.ReviseTimeMin section)
    S.GUI.OfferMax     = 20;     % s
    S.GUI.ReviseTimeMin = 0.5;   % s, minimum time needed elapsed before the revised offer, 0.5 since it cannot be 0, must be > 0.1
    S.GUI.ReviseTimeMax = 20;    % s, max time elapsed before the revised offer, identical to OfferMax unless changed (this exists for additional leverage)
    S.GUI.NewOfferMin  = 2;      % s
    S.GUI.NewOfferMax  = 20;     % s
    S.GUI.ReviseProb   = 0.5;    % probability a trial gets a revise offer (yes/no)
    S.GUI.HzMax        = 8000;   % tone starts here
    S.GUI.HzMin        = 1000;   % (kept for reference)
    S.GUI.ThresholdHz  = 1000;   % tone decays to here as offer expires
end
BpodParameterGUI('init', S);

MaxTrials = 200;

PsychToolboxSoundServer('init', 192000); %%sampling rate, sound quality
BpodSystem.SoftCodeHandlerFunction = 'SunkCostSoftCodeHandler';

%%logs for data
BpodSystem.Data.OfferTime   = []; % original offer O (s)
BpodSystem.Data.NewOffer = []; % revised offer R (s), independent of O
BpodSystem.Data.ReviseTime  = []; % wait elapsed when revise fires = sunk cost S (NaN if none)
BpodSystem.Data.DoRevise    = []; % 1 = revise trial, 0 = normal trial

%%The Trial
for trialNum = 1:MaxTrials

    S = BpodParameterGUI('sync', S); %%pull any live GUI changes

    %% Reward valve time from the liquid calibration table (port 3 = wait/reward port)
    vt = GetValveTimes(S.GUI.RewardAmount, 3);
    RewardValveTime = vt(1);

    %% Draw this trial's schedule up front
    offerTime   = shapedRand(S.GUI.OfferShapeK) * (S.GUI.OfferMax - S.GUI.OfferMin) + S.GUI.OfferMin; %%original offer O, 2-20 s
    NewOffer = shapedRand(S.GUI.NOfferShapeK) * (S.GUI.NewOfferMax - S.GUI.NewOfferMin) + S.GUI.NewOfferMin; %%revised new offer R, INDEPENDENT of O
    doRevise    = rand < S.GUI.ReviseProb; %%logical: true or false
    hi = min(S.GUI.ReviseTimeMax, offerTime);   % guard so it never past the actual offer

    %% Trial-type branch: sets the first countdown's length and where it leads
    if doRevise && hi > S.GUI.ReviseTimeMin %%safe guard against Gui parameters set as OfferMin < ReviseTimeMin
        reviseTime   = S.GUI.ReviseTimeMin + shapedRand(S.GUI.ROfferShapeK) * (hi - S.GUI.ReviseTimeMin);
        waitDuration = reviseTime;
        waitEndDest  = 'NewOfferTone';
    else
        reviseTime   = NaN;
        waitDuration = offerTime;
        waitEndDest  = 'RewardDelivery';
    end

    %% Hand the sound-relevant values to the softcode handler via the global
    SoundParams.Hz.Max       = S.GUI.HzMax;
    SoundParams.Hz.Min       = S.GUI.HzMin;
    SoundParams.ThresholdHz  = S.GUI.ThresholdHz;
    SoundParams.CurrentOffer = offerTime;   %%case 3 decays over the FULL original offer
    SoundParams.NewOffer     = NewOffer; %%case 4 decays over the New Offer

    sma = NewStateMachine;

    %% Global timers: countdowns that keep running across state changes
    sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', waitDuration);
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', NewOffer);

    %% Condition 1: Port 3 is LOW (rat is currently out) - level test, not an edge
    sma = SetCondition(sma, 1, 'Port3', 0);

    %% Offer available (light cue)
    sma = AddState(sma,'Name','OfferAvailable',...
        'Timer',0,...
        'StateChangeConditions',{'Port2In','PlayOfferTone'},...
        'OutputActions',{'SoftCode',8,'PWM2',255}); %softcode8 : trial start tone, announces a new trial

    %% START OFFER + SOUND
    sma = AddState(sma,'Name','PlayOfferTone',...
        'Timer',0,...
        'StateChangeConditions',{'Port1In','RejectOffer',...
                                 'Port3In','AcceptOffer'},...
        'OutputActions',{'SoftCode',1,'PWM1',255,'PWM3',255}); %softcode1 : offer tone O Tone

    %% ACCEPT: start the decay AND the countdown together
    sma = AddState(sma,'Name','AcceptOffer',...
        'Timer',0.1,...
        'StateChangeConditions',{'Tup','WaitingForReward',...
                                 'Port3Out','GracePeriod1',...
                                 'GlobalTimer1_End',waitEndDest},... %%safe in case the Global timer is ever set at t=0
        'OutputActions',{'SoftCode',3,'GlobalTimerTrig',1,'PWM3',255}); %softcode3 : decay sweep over CurrentOffer O

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
        'OutputActions',{'SoftCode',2,'PWM3',255});   %softcode2 : offer tone R Tone (revised tone)
    sma = AddState(sma,'Name','DecreaseNew',...
        'Timer',0.1,...
        'StateChangeConditions',{'Tup','WaitingForRewardNew',...
                                 'Port3Out','GracePeriod3'},...
        'OutputActions',{'SoftCode',4,'GlobalTimerTrig',2,'PWM3',255}); %softcode4 : decay sweep over RevisedOffer R
    sma = AddState(sma,'Name','WaitingForRewardNew',...
        'Timer',0,...
        'StateChangeConditions',{'GlobalTimer2_End','RewardDelivery',...
                                 'Port3Out','GracePeriod3'},...
        'OutputActions',{'PWM3',255});

    %% GRACE PERIODS (countdowns keep running throughout)
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
        'OutputActions',{'Valve3',1,'SoftCode',5}); %softcode5 : stop all softcodes, play simple or complex reward tone
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
        'OutputActions',{'PWM2',255,'SoftCode',6}); %softcode6 : stop all softcodes, play simple rejection tone
    sma = AddState(sma,'Name','RejectOfferWait',...
        'Timer',0,...
        'StateChangeConditions',{'Tup','ITI'},...
        'OutputActions',{'PWM2',255,'SoftCode',6}); %softcode6 : stop all softcodes, play simple rejection tone

    %% ITI
    sma = AddState(sma,'Name','ITI',...
        'Timer',2,...
        'StateChangeConditions',{'Tup','exit'},...
        'OutputActions',{'SoftCode',7}); %softcode7 : reset the softcodes, silent (safety net)

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
        return                  % respects the stop button
    end
end
end

function u = shapedRand(k)
%% Shaped random number on [0,1]
%   k = 1  -> uniform (flat)
%   k < 1  -> mass pushed toward BOTH extremes (U-shaped, "reversed normal")
%   k > 1  -> mass pulled toward the middle (bell-like)
v = 2*rand - 1;                      % uniform on [-1, 1]
u = 0.5 * (1 + sign(v) * abs(v)^k);  % reshaped, still on [0, 1]
end
