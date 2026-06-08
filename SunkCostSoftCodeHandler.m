function SunkCostSoftCodeHandler(softcode)

global SoundParams

switch softcode

%% ---------------- OFFER TONE ----------------
case 1
    % stop any previous dynamics
    SoundParams.Accepting = false;
    SoundParams.CurrentHz = SoundParams.Hz.Max;

    if isfield(SoundParams,'ToneTimer') && ~isempty(SoundParams.ToneTimer)
        try
            stop(SoundParams.ToneTimer);
            delete(SoundParams.ToneTimer);
        end
    end

    % start offer tone
    hz = SoundParams.Hz.Max;
    SoundParams.CurrentHz = hz;

    tone = GenerateSineWave(192000, hz, 0.5);
    PsychToolboxSoundServer('Load',1,tone);
    PsychToolboxSoundServer('Play',1);

%% ---------------- START DECAY PROCESS ----------------
case 2
    SoundParams.Accepting = true;
    SoundParams.CurrentHz = SoundParams.Hz.Max;

    if isfield(SoundParams,'ToneTimer') && ~isempty(SoundParams.ToneTimer)
        try
            stop(SoundParams.ToneTimer);
            delete(SoundParams.ToneTimer);
        end
    end

    % create decay timer
    t = timer;
    t.Period = 0.05;
    t.ExecutionMode = 'fixedRate';
    t.TimerFcn = @decreaseStep;

    SoundParams.ToneTimer = t;
    start(t);

%% ---------------- STOP EVERYTHING ----------------
case 3
    SoundParams.Accepting = false;

    PsychToolboxSoundServer('Stop',1);

    if isfield(SoundParams,'ToneTimer') && ~isempty(SoundParams.ToneTimer)
        try
            stop(SoundParams.ToneTimer);
            delete(SoundParams.ToneTimer);
        end
    end
    SoundParams.ToneTimer = [];

%% ---------------- REWARD ----------------
case 4
    rewardTone = GenerateSineWave(192000, 4000, 0.2);
    PsychToolboxSoundServer('Load',2,rewardTone);
    PsychToolboxSoundServer('Play',2);

end
end


% Decay function

function decreaseStep(~,~)

global SoundParams

% safety stop
if ~isfield(SoundParams,'Accepting') || ~SoundParams.Accepting
    return
end

% update frequency
SoundParams.CurrentHz = SoundParams.CurrentHz - SoundParams.DecreaseRate;

if SoundParams.CurrentHz <= SoundParams.ThresholdHz
    SoundParams.CurrentHz = SoundParams.ThresholdHz;

    if isfield(SoundParams,'ToneTimer') && ~isempty(SoundParams.ToneTimer)
        try
            stop(SoundParams.ToneTimer);
            delete(SoundParams.ToneTimer);
        end
    end
    SoundParams.ToneTimer = [];
    return
end

% play updated tone chunk
tone = GenerateSineWave(192000, SoundParams.CurrentHz, 0.1);
PsychToolboxSoundServer('Load',1,tone);
PsychToolboxSoundServer('Play',1);

end
