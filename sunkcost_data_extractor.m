%% Parameters: Modify before running
base_dir = "C:/Users/Alex/Downloads/bpod_test/Bpod Local/Data/";
subjects = ["FakeSubject"];
males = ["FakeSubject"];
OutputFilepath = "DataTable_1.csv";

DataTableTT = table();
DataTableVariableNames = ["SUB_Rat", "SUB_Sex", "SUB_Date", "SUB_StartTime", ...
            "SET_SoundAttenuation", "SET_RewardAmount", "SET_OfferMu", "SET_OfferShapeKappa", ...
            "SET_NOfferMu", "SET_NOfferKappa", "SET_ReviseMu", "SET_ReviseKappa", "SET_ChoiceLatMax", ...
            "SET_OfferMin", "SET_OfferMax", "SET_ReviseTimeMin", "SET_ReviseTimeMax", ...
            "SET_NewOfferMin", "SET_NewOfferMax", "SET_ReviseProb", "SET_HzMax", "SET_ThresholdHz", ...
            "DTA_TrialNum", "DTA_OfferTime", "DTA_NewOffer", "DTA_DoRevise", "DTA_ReviseTime", ...
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

    % Obtain trial by trial info from state data
    init_lat = [];
    choice_lat = [];
    time_waited = SessionData.ReviseTime;
    time_waited_rev = SessionData.NewOffer;
    accepted = zeros(1, nTrials);
    rewarded = zeros(1, nTrials);

    for i = 1:nTrials
        init_lat_val = SessionData.RawEvents.Trial{1, i}.States.OfferAvailable(2);
        init_lat = [init_lat, init_lat_val];

        choice_lat_val = SessionData.RawEvents.Trial{1, i}.States.PlayOfferTone(2) - SessionData.RawEvents.Trial{1, i}.States.PlayOfferTone(1);
        choice_lat = [choice_lat, choice_lat_val];

        if ~isnan(SessionData.RawEvents.Trial{1, i}.States.RejectOfferWait(1))
            if ~isnan(SessionData.RawEvents.Trial{1, i}.States.GracePeriod3(1))
                time_waited_rev(i) = SessionData.RawEvents.Trial{1, i}.States.GracePeriod3(end-1) - SessionData.RawEvents.Trial{1, i}.States.NewOfferTone(1);
            end
            if ~isnan(SessionData.RawEvents.Trial{1, i}.States.GracePeriod2(1))
                time_waited_rev(i) = SessionData.RawEvents.Trial{1, i}.States.GracePeriod2(end-1) - SessionData.RawEvents.Trial{1, i}.States.NewOfferTone(1);
            end
            if ~isnan(SessionData.RawEvents.Trial{1, i}.States.GracePeriod1(1))
                time_waited_rev(i) = NaN;
                time_waited(i) = SessionData.RawEvents.Trial{1, i}.States.GracePeriod1(end-1) - SessionData.RawEvents.Trial{1, i}.States.AcceptOffer(1);
            end
        end

        if isnan(SessionData.RawEvents.Trial{1, i}.States.RejectOffer(1))
            accepted(i) = 1;
        end
        if ~isnan(SessionData.RawEvents.Trial{1, i}.States.RewardDelivery(1))
            rewarded(i) = 1;
        end
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
                    init_lat.',... % Time between central port being available and central port entry
                    choice_lat.',... % Time between initial offer tone presentation and L/R choice
                    time_waited.',... % Time in port for initial offer wait
                    time_waited_rev.',... % Time in port for revised offer wait
                    accepted.',... % Whether initial offer was accepted
                    rewarded.',... % Whether reward was delivered (i.e., whether rat made it to the end)
                    'VariableNames', DataTableVariableNames);

    DataTableTT = [DataTableTT; TempTable];
end

writetable(DataTableTT, OutputFilepath);