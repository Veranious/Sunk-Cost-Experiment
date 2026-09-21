%% Parameters: Modify before running
base_dir = "C:/Users/Alex/Downloads/bpod_test/Bpod Local/Data/";
subjects = ["FakeSubject"];
males = ["FakeSubject"];
OutputFilepath = "DataTable_1.csv";

% Create table with variable prefixes:
%   - SUB for "Subject Info" (Subject and Session details)
%   - SET for "Settings" (Trial settings as per GUI)
%   - DTA for "Data" (Trial by Trial Data)
DataTableTT = table();
DataTableVariableNames = ["SUB_Rat", "SUB_Sex", "SUB_Date", "SUB_StartTime", ...
            "SET_SoundAttenuation", "SET_RewardAmount", "SET_OfferMu", "SET_OfferShapeKappa", ...
            "SET_NOfferMu", "SET_NOfferKappa", "SET_ReviseMu", "SET_ReviseKappa", "SET_ChoiceLatMax", ...
            "SET_OfferMin", "SET_OfferMax", "SET_ReviseTimeMin", "SET_ReviseTimeMax", ...
            "SET_NewOfferMin", "SET_NewOfferMax", "SET_ReviseProb", "SET_HzMax", "SET_ThresholdHz", ...
            "DTA_TrialNum", "DTA_Offer", "DTA_NewOffer", "DTA_DoRevise", "DTA_ReviseTime", ...
            "DTA_InitLat", "DTA_ChoiceLat", "DTA_TimeWaited", "DTA_TimeWaitedRev", ...
            "DTA_Accepted", "DTA_Rewarded"];

for subject = subjects
    % Load the latest data file for this subject
    data_dir = base_dir + subject + "/RunSunkCost_NoHiFi/Session Data/";
    dirc = dir(data_dir + "/*.mat");
    dirc = dirc(~[dirc.isdir]);
    [A,I] = max([dirc(:).datenum]);
    if ~isempty(I)
        latestfile = dirc(I).name;
    end
    load(data_dir + latestfile);

    % Obtain session info
    nTrials = SessionData.nTrials;
    if (ismember(subject, males))
        Sex = "M";
    else
        Sex = "F";
    end

    % Compose data table
    TempTable = table(repmat(subject, nTrials, 1), ... % Rat
                    repmat(Sex, nTrials, 1), ... % Sex
                    repmat(string(SessionData.Info.SessionDate), nTrials, 1), ... % Date
                    repmat(string(SessionData.Info.SessionStartTime_UTC), nTrials, 1), ... % Time
                    arrayfun(@(x) x.GUI.SoundAttenuation_dB, SessionData.TrialSettings).',...   % Settings
                    arrayfun(@(x) x.GUI.RewardAmount, SessionData.TrialSettings).',...          % Settings
                    arrayfun(@(x) x.GUI.OfferMu, SessionData.TrialSettings).',...           % Settings
                    arrayfun(@(x) x.GUI.OfferKappa, SessionData.TrialSettings).',...          % Settings
                    arrayfun(@(x) x.GUI.NOfferMu, SessionData.TrialSettings).',...          % Settings
                    arrayfun(@(x) x.GUI.NOfferKappa, SessionData.TrialSettings).',...          % Settings
                    arrayfun(@(x) x.GUI.ReviseMu, SessionData.TrialSettings).',...          % Settings
                    arrayfun(@(x) x.GUI.ReviseKappa, SessionData.TrialSettings).',...          % Settings
                    arrayfun(@(x) x.GUI.ChoiceLatMax, SessionData.TrialSettings).',...          % Settings
                    arrayfun(@(x) x.GUI.OfferMin, SessionData.TrialSettings).',...              % Settings
                    arrayfun(@(x) x.GUI.OfferMax, SessionData.TrialSettings).',...              % Settings
                    arrayfun(@(x) x.GUI.ReviseTimeMin, SessionData.TrialSettings).',...         % Settings
                    arrayfun(@(x) x.GUI.ReviseTimeMax, SessionData.TrialSettings).',...         % Settings
                    arrayfun(@(x) x.GUI.NewOfferMin, SessionData.TrialSettings).',...           % Settings
                    arrayfun(@(x) x.GUI.NewOfferMax, SessionData.TrialSettings).',...           % Settings
                    arrayfun(@(x) x.GUI.ReviseProb, SessionData.TrialSettings).',...            % Settings
                    arrayfun(@(x) x.GUI.HzMax, SessionData.TrialSettings).',...                 % Settings
                    arrayfun(@(x) x.GUI.ThresholdHz, SessionData.TrialSettings).',...           % Settings
                    [1:nTrials].',... % TrialNo
                    SessionData.OfferTime.',... % Initial Offer Time
                    SessionData.NewOffer.',... % Revised Offer Time
                    SessionData.DoRevise.',... % Whether or not revised offer was presented
                    SessionData.ReviseTime.',... % Time at which the initial offer was interrupted with the revised offer
                    SessionData.InitLat.',... % Time between central port being available and central port entry
                    SessionData.ChoiceLat.',... % Time between initial offer tone presentation and L/R choice
                    SessionData.TimeWaited.',... % Time in port for initial offer wait
                    SessionData.TimeWaitedRev.',... % Time in port for revised offer wait
                    SessionData.Accepted.',... % Whether initial offer was accepted
                    SessionData.Rewarded.',... % Whether reward was delivered (i.e., whether rat made it to the end)
                    'VariableNames', DataTableVariableNames);

    DataTableTT = [DataTableTT; TempTable];
end

% Write to file
writetable(DataTableTT, OutputFilepath);