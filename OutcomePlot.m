function OutcomePlot(action, xVal, yVal)

persistent ...
    OldAcceptHandle RecentAcceptHandle FitAcceptHandle AxAccept ...
    OldRewardHandle RecentRewardHandle FitRewardHandle AxReward ...
    XDataRaw YRaw YJitter

MinTrialsForFit = 2; % minimum trials (with both outcomes present) before fitting

switch action

    case 'init'

        XDataRaw = [];
        YRaw = [];
        YJitter = [];
        Fig = figure( ...
            'Name','Outcome Plot', ...
            'NumberTitle','off', ...
            'Position',[100 100 1000 400]);

        %==============================================================
        % LEFT PANEL: Accept/Reject
        %==============================================================
        AxAccept = subplot(1,2,1,'Parent',Fig);
        hold(AxAccept,'on');

        OldAcceptHandle = scatter(AxAccept,NaN,NaN,60,'filled', ...
            'MarkerFaceAlpha',0.5);
        RecentAcceptHandle = scatter(AxAccept,NaN,NaN,60,'filled', ...
            'MarkerFaceAlpha',1);
        FitAcceptHandle = plot(AxAccept,NaN,NaN,'k-','LineWidth',2);

        ylim(AxAccept,[-0.1 1.1]);
        set(AxAccept,'YTick',[0 1]);

        xlabel(AxAccept,'Initial Offer (sec.)');
        ylabel(AxAccept,'P(Accept Offer)');

        grid(AxAccept,'on');

        %==============================================================
        % RIGHT PANEL: Rewarded/Unrewarded among accepted offers
        %==============================================================
        AxReward = subplot(1,2,2,'Parent',Fig);
        hold(AxReward,'on');

        OldRewardHandle = scatter(AxReward,NaN,NaN,60,'filled', ...
            'MarkerFaceAlpha',0.5);
        RecentRewardHandle = scatter(AxReward,NaN,NaN,60,'filled', ...
            'MarkerFaceAlpha',1);
        FitRewardHandle = plot(AxReward,NaN,NaN,'k-','LineWidth',2);

        ylim(AxReward,[-0.1 1.1]);
        set(AxReward,'YTick',[0 1]);

        xlabel(AxReward,'Initial Offer (sec.)');
        ylabel(AxReward,'P(Reward)');

        grid(AxReward,'on');

    case 'update'

        if isempty(RecentAcceptHandle) || ~isvalid(RecentAcceptHandle)
            OutcomePlot('init');
        end

        jitterAmount = 0.05;

        XDataRaw = [XDataRaw, xVal];
        YRaw = [YRaw, yVal];
        YJitter = [YJitter, (rand-0.5)*2*jitterAmount];

        newX = XDataRaw;
        newYraw = YRaw;

        %==============================================================
        % LEFT PANEL: Accept/Reject
        %
        % yVal coding:
        % 0 = rejected
        % 1 = accepted, not rewarded
        % 2 = rewarded
        %==============================================================

        acceptY = min(newYraw,1);
        acceptYplot = acceptY + YJitter;

        acceptColors = zeros(numel(newYraw),3);

        % rejected (red)
        acceptColors(newYraw == 0,:) = repmat( ...
            [0.80 0.10 0.10], sum(newYraw == 0), 1);

        % accepted, not rewarded (green)
        acceptColors(newYraw == 1,:) = repmat( ...
            [0.10 0.60 0.10], sum(newYraw == 1), 1);

        % rewarded (blue)
        acceptColors(newYraw == 2,:) = repmat( ...
            [0.10 0.10 0.80], sum(newYraw == 2), 1);

        nAccept = numel(newX);

        recentIdx = max(1,nAccept-4):nAccept;

        if nAccept > 5
            oldIdx = 1:(nAccept-5);
        else
            oldIdx = [];
        end

        set(OldAcceptHandle,...
            'XData',newX(oldIdx),...
            'YData',acceptYplot(oldIdx),...
            'CData',acceptColors(oldIdx,:));

        set(RecentAcceptHandle,...
            'XData',newX(recentIdx),...
            'YData',acceptYplot(recentIdx),...
            'CData',acceptColors(recentIdx,:));

        %--------------------------------------------------------------
        % Acceptance psychometric fit
        %--------------------------------------------------------------

        if numel(acceptY) >= MinTrialsForFit && ...
                numel(unique(acceptY)) > 1

            try

                b = glmfit(newX(:),acceptY(:), ...
                    'binomial','link','logit');

                slope = b(2);
                bias = -b(1)/b(2);

                xFit = linspace(min(newX),max(newX),200);

                yFit = 1 ./ (1 + exp(-slope*(xFit-bias)));

                set(FitAcceptHandle,...
                    'XData',xFit,...
                    'YData',yFit);

            catch
                % Not enough variation yet
            end

        end

        %==============================================================
        % RIGHT PANEL: Rewarded/Unrewarded among accepted offers
        %
        % accepted/not rewarded -> 0 (green)
        % rewarded -> 1 (blue)
        %
        % rejected trials excluded
        %==============================================================

        acceptedIdx = newYraw > 0;

        rewardX = newX(acceptedIdx);

        rewardY = zeros(size(rewardX));
        rewardY(newYraw(acceptedIdx) == 2) = 1;

        rewardJitter = YJitter(acceptedIdx);
        rewardYplot = rewardY + rewardJitter;

        rewardColors = zeros(numel(rewardY),3);

        % accepted but not rewarded (green)
        rewardColors(rewardY == 0,:) = repmat( ...
            [0.10 0.60 0.10], sum(rewardY == 0), 1);

        % rewarded (blue)
        rewardColors(rewardY == 1,:) = repmat( ...
            [0.10 0.10 0.80], sum(rewardY == 1), 1);

        nReward = numel(rewardX);

        if nReward > 0

            rewardRecentIdx = max(1,nReward-4):nReward;

            if nReward > 5
                rewardOldIdx = 1:(nReward-5);
            else
                rewardOldIdx = [];
            end

            set(OldRewardHandle,...
                'XData',rewardX(rewardOldIdx),...
                'YData',rewardYplot(rewardOldIdx),...
                'CData',rewardColors(rewardOldIdx,:));

            set(RecentRewardHandle,...
                'XData',rewardX(rewardRecentIdx),...
                'YData',rewardYplot(rewardRecentIdx),...
                'CData',rewardColors(rewardRecentIdx,:));

        end

        %--------------------------------------------------------------
        % Reward psychometric fit
        %--------------------------------------------------------------

        if numel(rewardY) >= MinTrialsForFit && ...
                numel(unique(rewardY)) > 1

            try

                b = glmfit(rewardX(:),rewardY(:), ...
                    'binomial','link','logit');

                slope = b(2);
                bias = -b(1)/b(2);

                xFit = linspace(min(rewardX),max(rewardX),200);

                yFit = 1 ./ (1 + exp(-slope*(xFit-bias)));

                set(FitRewardHandle,...
                    'XData',xFit,...
                    'YData',yFit);

            catch
                % Not enough variation yet
            end

        end

        % Keep both axes synchronized and auto-expanding
        if ~isempty(newX)

            xmin = min(newX);
            xmax = max(newX);

            % Prevent xlim error when only one point exists
            if xmin == xmax
                xmin = xmin - 0.1;
                xmax = xmax + 0.1;
            end

            xlim(AxAccept,[xmin xmax]);
            xlim(AxReward,[xmin xmax]);

        end

        drawnow limitrate;

    otherwise

        error('OutcomePlot: unknown action ''%s''. Use ''init'' or ''update''.', action);

end

end
