function RunOldSunkCost

MaxTrials = 200;

global BpodSystem SoundParams %%parameters for both run file & handler

SoundParams.Hz.Min = 1000;
SoundParams.Hz.Max = 8000;

SoundParams.Offer.Min = 2;
SoundParams.Offer.Max = 20;

SoundParams.ThresholdHz = 1000;

RewardValveTime = 0.1;

PsychToolboxSoundServer('init', 192000); %%sampling rate, sound quality
BpodSystem.SoftCodeHandlerFunction = 'SunkCostSoftCodeHandler';

%%create folders for data
BpodSystem.Data = struct;
BpodSystem.Data.SoundParams = {};
BpodSystem.Data.RawEvents = {};

%%The Trial
for trialNum = 1:MaxTrials
    
    offerTime = rand * (SoundParams.Offer.Max - SoundParams.Offer.Min) + SoundParams.Offer.Min; %%offerTime function {0to1}(20-1) +2 > so random between 2 to 20 seconds
    SoundParams.CurrentOffer = offerTime; %%variable named for soundhandler
    
    BpodSystem.Data.SoundParams{trialNum} = SoundParams; %%saves in the result folder the sound offer
    
    sma = NewStateMachine;
    
    %% Offer available (light cue)
    AddState(sma,'Name','OfferAvailable',...
        'Timer',0,...
        'StateChangeConditions',{'Port2In','PlayOfferTone'},...
        'OutputActions',{'PWM2',255});
    
    %% START OFFER + SOUND
    AddState(sma,'Name','PlayOfferTone',...
        'Timer',0,...
        'StateChangeConditions',{'Port1In','RejectOffer',...
                                 'Port3In','AcceptReward'},...
        'OutputActions',{'SoftCode', 1, 'PWM1', 255, 'PWM3', 255});  % start tone
    
    %% MAIN DECISION STATE
    AddState(sma,'Name','AcceptReward',...
        'Timer',0.1,...
        'StateChangeConditions',{'Tup','WaitingForReward'},...
        'OutputActions',{'SoftCode',2,'PWM3',255}); 
        % SoftCode 2 = start decay process ONCE
        
    AddState(sma,'Name','WaitingForReward',...
        'Timer',SoundParams.CurrentOffer,...
        'StateChangeConditions',{'Tup','RewardDelivery',...
                                 'Port3Out','GracePeriod'},...
        'OutputActions',{'PWM3',255});
    
    %% GRACE PERIOD (simple and clean)
    AddState(sma,'Name','GracePeriod',...
        'Timer',0.5,...
        'StateChangeConditions',{'Tup','RejectOfferWait',...
                                 'Port3In','WaitingForReward'},...
        'OutputActions',{'PWM3',128});
    
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

    %% ITI
    AddState(sma,'Name','ITI',...
        'Timer',2,...
        'StateChangeConditions',{'Tup','Exit'},...
        'OutputActions',{});

    %% ADD A DRINKING GRACE PERIOD 
    
    SendStateMachine(sma);
    RawEvents = RunStateMachine; %%saved results from the trial at the end in the results folder
    
    if isempty(RawEvents)
        warning('Trial %d failed', trialNum);
        continue;
    end
    
    BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
    SaveBpodSessionData(); %add data to disk, not only memory
    HandlePauseCondition(); %respects the pause button
    
    if BpodSystem.BeingUsed == 0
        break                  % respects the stop button
    end
    
end
end
