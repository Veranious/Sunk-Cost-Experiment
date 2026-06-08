function SunkCostSoftCodeHandler(softcode)

global SoundParams

switch softcode

case 1
    % start offer tone
    hz = SoundParams.Hz.Max;
    SoundParams.CurrentHz = hz;

    sound = GenerateSineWave(192000, hz, 0.5);
    PsychToolboxSoundServer('Load',1,sound);
    PsychToolboxSoundServer('Play',1);

case 2
    % ONE STEP DECREASE (key change!)
    SoundParams.CurrentHz = SoundParams.CurrentHz - SoundParams.StepSize;

    if SoundParams.CurrentHz <= SoundParams.ThresholdHz
        SoundParams.CurrentHz = SoundParams.ThresholdHz;
    end

    sound = GenerateSineWave(192000, SoundParams.CurrentHz, 0.1);
    PsychToolboxSoundServer('Load',1,sound);
    PsychToolboxSoundServer('Play',1);

case 3
    PsychToolboxSoundServer('Stop',1);

case 4
    r = GenerateSineWave(192000,4000,0.2);
    PsychToolboxSoundServer('Load',2,r);
    PsychToolboxSoundServer('Play',2);
    
end
end
