function OutcomePlot(action, xVal, yVal)

persistent OldPlotHandle RecentPlotHandle AxesHandle FitHandle YRaw XDataRaw

MinTrialsForFit = 2; % minimum trials (with both outcomes present) before fitting

switch action
    case 'init'
        Fig = figure('Name', 'Outcome Plot', 'NumberTitle', 'off', ...
            'Position', [100 100 600 400]);
        AxesHandle = axes(Fig);
        hold(AxesHandle, 'on');
        OldPlotHandle = scatter(AxesHandle, NaN, NaN, 60, 'filled', ...
            'MarkerFaceAlpha', 0.5);
        RecentPlotHandle = scatter(AxesHandle, NaN, NaN, 60, 'filled', ...
            'MarkerFaceAlpha', 1);
        FitHandle = plot(AxesHandle, NaN, NaN, 'k-', 'LineWidth', 2);
        ylim(AxesHandle, [-0.1 1.1]);
        set(AxesHandle, 'YTick', [0 1]);
        xlabel(AxesHandle, 'Initial Offer (sec.)');
        ylabel(AxesHandle, 'P(Accept Offer)');
        title(AxesHandle, 'Trial-by-trial outcomes');
        grid(AxesHandle, 'on');

        YRaw = [];
        XDataRaw = [];

    case 'update'
        if isempty(RecentPlotHandle) || ~isvalid(RecentPlotHandle)
            % Window was never created or was closed - recreate it
            OutcomePlot('init');
        end

        XDataRaw = [XDataRaw, xVal];
        YRaw = [YRaw, yVal];

        newX = XDataRaw;
        newYraw = YRaw;

        newY = min(newYraw,1);

        colors = zeros(numel(newYraw), 3);
        colors(newYraw == 1, :) = repmat([0.10 0.60 0.10], sum(newYraw == 1), 1); % green
        colors(newYraw == 0, :) = repmat([0.80 0.10 0.10], sum(newYraw == 0), 1); % red
        colors(newYraw == 2, :) = repmat([0.10 0.10 0.80], sum(newYraw == 2), 1); % blue

        nPts = numel(newX);
        recentIdx = max(1,nPts-4):nPts;
        oldIdx = [];
        if nPts > 5
            oldIdx = 1:(nPts-5);
        end

        set(OldPlotHandle, ...
            'XData', newX(oldIdx), ...
            'YData', newY(oldIdx), ...
            'CData', colors(oldIdx,:));
        set(RecentPlotHandle, ...
            'XData', newX(recentIdx), ...
            'YData', newY(recentIdx), ...
            'CData', colors(recentIdx,:));

        xlim(AxesHandle, 'auto');

        % Fit and overlay a logistic psychometric curve once there's enough data
        if numel(newY) >= MinTrialsForFit && numel(unique(newY)) > 1
            try
                b = glmfit(newX(:), newY(:), 'binomial', 'link', 'logit');
                % Psychometric parameters
                slope = b(2);
                bias  = -b(1)/b(2);   % x value where P(y=1) = 0.5
                
                % Generate curve
                xFit = linspace(min(newX), max(newX), 200);
                yFit = 1 ./ (1 + exp(-slope * (xFit - bias)));
                set(FitHandle, 'XData', xFit, 'YData', yFit);
                disp(b)
            catch
                % Not enough separation/variation yet - skip this trial's fit
            end
        end

        drawnow limitrate; % keeps redraws cheap so it doesn't slow down trial timing

    otherwise
        error('UpdateOutcomePlot: unknown action ''%s''. Use ''init'' or ''update''.', action);
end

end
