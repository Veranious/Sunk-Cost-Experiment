MaxTrials = 200;

global BpodSystem SoundParams

%% ---------------- SOUND PARAMETERS ----------------

SoundParams.Hz.Min = 1000;

SoundParams.Hz.Max = 8000;

SoundParams.Offer.Min = 2;

SoundParams.Offer.Max = 20;

SoundParams.ThresholdHz = 1000;

SoundParams.DecreaseRate = 50;

SoundParams.State.Accepting = false;

%% define reward timing 

RewardValveTime = 0.1;

BpodSystem.Data.Custom.SoundParams = SoundParams;

%% Initialize audio

PsychToolboxSoundServer('init', 192000);

%% Softcode handler

BpodSystem.SoftCodeHandlerFunction = 'SunkCostSoftCodeHandler';

%% Preallocate

BpodSystem.Data = struct;

BpodSystem.Data.TrialSettings = {};

BpodSystem.Data.RawEvents = {};

%% ---------------- TRIAL LOOP ----------------

for trialNum = 1:MaxTrials

    offerTime = rand * ...

        (SoundParams.Offer.Max - SoundParams.Offer.Min) ...

        + SoundParams.Offer.Min;

    SoundParams.CurrentOffer = offerTime;

    BpodSystem.Data.TrialSettings{trialNum} = SoundParams;

    sma = NewStateMachine;

    AddState(sma,'Name', 'ITI',...
        'Timer', 2,...
        'StateChangeConditions', {'Tup', 'OfferAvailable'},... 
        'OutputActions', {});
    AddState(sma,'Name', 'OfferAvailable',...
        'Timer', 0,...
        'StateChangeConditions', {'Port1In', 'PlayOfferTone'},...
        'OutputActions', {'PWM1',255});
    AddState(sma, 'Name', 'PlayOfferTone',...
        'Timer', 0,...
        'StateChangeConditions', {'Port2In', 'RejectOffer', ...
                                  'Port3In', 'WaitingForReward'}, ...
        'OutputActions', {'SoftCode', 1});
    % --- RejectOffer ---
    AddState(sma, 'Name', 'RejectOffer', ...
        'Timer', 2, ...
        'StateChangeConditions', {'Tup', 'ITI'}, ...
        'OutputActions', {'PWM2', 255, 'SoftCode', 3});  % SoftCode 3 = stop all tone
    % --- AcceptOffer ---
    AddState(sma, 'Name', 'WaitingForReward',...
        'Timer', offerTime,...
        'StateChangeConditions',{'Tup', 'RewardDelivery',...
                                 'Port3Out', 'GracePeriod'},...
        'OutputActions',{'SoftCode', 2, 'PWM3', 255});   %SoftCode 2 = Stop tone & Activate Same tone + Decrease
    % Grace Period (2seconnds)   
    AddState(sma, 'Name', 'GracePeriod', ...
        'Timer', 2, ...
        'StateChangeConditions', {'Tup',    'RejectOfferWait', ...
                                  'Port3In', 'WaitingForReward'}, ...  % re-entered in time
        'OutputActions', {'SoftCode', 2, 'PWM3', 128});   % dim light as warning
    % --- RejectOfferWait ---
    AddState(sma, 'Name', 'RejectOfferWait', ...
        'Timer', 0, ...
        'StateChangeConditions', {'Tup', 'ITI'}, ...
        'OutputActions', {'SoftCode', 3});    % SoftCode 3 = stop all tone
    % --- RewardDelivery ---
    AddState(sma, 'Name', 'RewardDelivery', ...
        'Timer', RewardValveTime, ...         % e.g. 0.1s for a water drop
        'StateChangeConditions', {'Tup', 'ITI'}, ...
        'OutputActions', {'Valve1', 1, 'SoftCode', 4});

    SendStateMachine(sma);
    RawEvents = RunStateMachine;

    if isempty(RawEvents)
        warning('Trial %d failed', trialNum);
        continue;
    end

    BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
    BpodSystem.Data.TrialSettings{trialNum} = SoundParams;
end