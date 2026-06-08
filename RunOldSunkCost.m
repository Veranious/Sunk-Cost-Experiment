MaxTrials = 200;

global BpodSystem SoundParams

%% PARAMETERS
SoundParams.Hz.Min = 1000;
SoundParams.Hz.Max = 8000;

SoundParams.Offer.Min = 2;
SoundParams.Offer.Max = 20;

SoundParams.ThresholdHz = 1000;

RewardValveTime = 0.1;

PsychToolboxSoundServer('init', 192000);
BpodSystem.SoftCodeHandlerFunction = 'SunkCostSoftCodeHandler';

BpodSystem.Data = struct;
BpodSystem.Data.TrialSettings = {};
BpodSystem.Data.RawEvents = {};

%% TRIAL LOOP
for trialNum = 1:MaxTrials

    offerTime = rand * (SoundParams.Offer.Max - SoundParams.Offer.Min) + SoundParams.Offer.Min;
    SoundParams.CurrentOffer = offerTime;

    BpodSystem.Data.TrialSettings{trialNum} = SoundParams;

    sma = NewStateMachine;

    %% ITI
    AddState(sma,'Name','ITI',...
        'Timer',2,...
        'StateChangeConditions',{'Tup','OfferAvailable'},...
        'OutputActions',{});

    %% Offer available (light cue)
    AddState(sma,'Name','OfferAvailable',...
        'Timer',0,...
        'StateChangeConditions',{'Port1In','PlayOfferTone'},...
        'OutputActions',{'PWM1',255});

    %% START OFFER + SOUND
    AddState(sma,'Name','PlayOfferTone',...
        'Timer',0,...
        'StateChangeConditions',{'Port2In','RejectOffer',...
                                 'Port3In','WaitingForReward'},...
        'OutputActions',{'SoftCode',1});  % start tone

    %% MAIN DECISION STATE
    AddState(sma,'Name','WaitingForReward',...
        'Timer',SoundParams.CurrentOffer,...
        'StateChangeConditions',{'Tup','RewardDelivery',...
                                 'Port3Out','GracePeriod'},...
        'OutputActions',{'SoftCode',2,'PWM3',255}); 
        % SoftCode 2 = start decay process ONCE

    %% GRACE PERIOD (simple and clean)
    AddState(sma,'Name','GracePeriod',...
        'Timer',2,...
        'StateChangeConditions',{'Tup','RejectOfferWait',...
                                 'Port3In','WaitingForReward'},...
        'OutputActions',{'PWM3',128,'SoftCode',3});

    %% REJECT
    AddState(sma,'Name','RejectOffer',...
        'Timer',2,...
        'StateChangeConditions',{'Tup','ITI'},...
        'OutputActions',{'PWM2',255,'SoftCode',3});

    AddState(sma,'Name','RejectOfferWait',...
        'Timer',0,...
        'StateChangeConditions',{'Tup','ITI'},...
        'OutputActions',{'SoftCode',3});

    %% REWARD
    AddState(sma,'Name','RewardDelivery',...
        'Timer',RewardValveTime,...
        'StateChangeConditions',{'Tup','ITI'},...
        'OutputActions',{'Valve1',1,'SoftCode',4});

    SendStateMachine(sma);
    RawEvents = RunStateMachine;

    if isempty(RawEvents)
        warning('Trial %d failed', trialNum);
        continue;
    end

    BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
end
