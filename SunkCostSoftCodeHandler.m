function SunkCostSoftCodeHandler(softcode)
global SoundParams
switch softcode
    case 1
        SoundParams.Accepting = false;
        hz = sampleOfferHz(SoundParams);
        SoundParams.CurrentHz = hz;
        sound = GenerateSineWave(192000, hz, 0.5);
        PsychToolboxSoundServer('Load',1,sound);
        PsychToolboxSoundServer('Play',1);
    case 2
        SoundParams.Accepting = true;
        SoundParams.CurrentHz = SoundParams.Hz.Max;
        if isfield(SoundParams,'ToneTimer') && ~isempty(SoundParams.ToneTimer)
            try
                stop(SoundParams.ToneTimer);
                delete(SoundParams.ToneTimer);
            catch
            end
        end
        t = timer;
        t.Period = 0.05;
        t.ExecutionMode = 'fixedRate';
        t.TimerFcn = @decreaseStep;
        SoundParams.ToneTimer = t;
        start(t);
    
    case 3
        SoundParams.Accepting = false;
        PsychToolboxSoundServer('Stop',1);
        if isfield(SoundParams,'ToneTimer') && ~isempty(SoundParams.ToneTimer)
            try
                stop(SoundParams.ToneTimer);
                delete(SoundParams.ToneTimer);
            catch
            end
        end
        
    case 4
        r = GenerateSineWave(192000,4000,0.2);
        PsychToolboxSoundServer('Load',2,r);
        PsychToolboxSoundServer('Play',2);
end
end

function decreaseStep(~,~)
global SoundParams
if ~isfield(SoundParams,'Accepting') || ~SoundParams.Accepting
    return
end
SoundParams.CurrentHz = SoundParams.CurrentHz - SoundParams.DecreaseRate;
if SoundParams.CurrentHz <= SoundParams.ThresholdHz
    SoundParams.CurrentHz = SoundParams.ThresholdHz;
    if isfield(SoundParams,'ToneTimer') && ~isempty(SoundParams.ToneTimer)
        try
            stop(SoundParams.ToneTimer);
            delete(SoundParams.ToneTimer);
        catch
        end
    end
    return
end

sound = GenerateSineWave(192000, SoundParams.CurrentHz, 0.1);
PsychToolboxSoundServer('Load',1,sound);
PsychToolboxSoundServer('Play',1);

end