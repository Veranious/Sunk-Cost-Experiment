function SunkCostSoftCodeHandler(softcode)
global SoundParams

switch softcode

%%OFFER TONE
case 1
    % Stop any previous decay timer
    stopDecayTimer();
    SoundParams.Accepting = false;
    
    %Play offer tone
    SoundParams.CurrentHz = SoundParams.Hz.Max;
    tone = GenerateSineWave(192000, SoundParams.CurrentHz, 0.5);
    PsychToolboxSoundServer('Load', 1, tone);
    PsychToolboxSoundServer('Play', 1);

%%START DECAY PROCESS
case 2
    SoundParams.Accepting = true;
    SoundParams.CurrentHz = SoundParams.Hz.Max;

    totalSteps = SoundParams.CurrentOffer / 0.05; %number of Hz intervals per 50mseconds
    SoundParams.DecreaseRate = (SoundParams.Hz.Max - SoundParams.ThresholdHz) / totalSteps; 
    % tone reaches ThresholdHz exactly when offer timer expires

    % Start decay timer
    stopDecayTimer();  % clear any leftover
    t = timer;
    t.Period        = 0.05;
    t.ExecutionMode = 'fixedRate';
    t.TimerFcn      = @decreaseStep;
    SoundParams.ToneTimer = t;
    start(t);

%%STOP EVERYTHING
case 3
    SoundParams.Accepting = false;
    stopDecayTimer();
    PsychToolboxSoundServer('Stop', 1);  %stop offer/decay tone
    PsychToolboxSoundServer('Stop', 2);  %stop reward tone if still playing

%%REWARD
case 4
    SoundParams.Accepting = false;
    stopDecayTimer();
    rewardTone = GenerateSineWave(192000, 4000, 0.2);
    PsychToolboxSoundServer('Load', 2, rewardTone);
    PsychToolboxSoundServer('Play', 2);

end
end


%%DECAY STEP — called every 50ms by the timer
function decreaseStep(~, ~)
global SoundParams

if ~SoundParams.Accepting
    return
end

SoundParams.CurrentHz = SoundParams.CurrentHz - SoundParams.DecreaseRate;

if SoundParams.CurrentHz <= SoundParams.ThresholdHz
    SoundParams.CurrentHz = SoundParams.ThresholdHz;
    SoundParams.Accepting = false;
    % Note: do NOT delete the timer from inside its own callback
    % The run file's state machine handles what happens next via Tup
    return
end

%Load and play updated tone
tone = GenerateSineWave(192000, SoundParams.CurrentHz, 0.1);
PsychToolboxSoundServer('Load', 1, tone);
PsychToolboxSoundServer('Play', 1);
end

%%safely stop and delete timer from outside its callback
function stopDecayTimer()
global SoundParams

if isfield(SoundParams, 'ToneTimer') && ~isempty(SoundParams.ToneTimer)
    if isvalid(SoundParams.ToneTimer)
        stop(SoundParams.ToneTimer);
        delete(SoundParams.ToneTimer);
    end
    SoundParams.ToneTimer = [];
end
end
