classdef denemesonson < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        EditHPCutoffEditField       matlab.ui.control.NumericEditField
        EditHPCutoffEditFieldLabel  matlab.ui.control.Label
        FilterLamp                  matlab.ui.control.Lamp
        FilterLampLabel             matlab.ui.control.Label
        EditLPCutoffEditField       matlab.ui.control.NumericEditField
        EditLPCutoffEditFieldLabel  matlab.ui.control.Label
        EditOrderEditField          matlab.ui.control.NumericEditField
        EditOrderEditFieldLabel     matlab.ui.control.Label
        RecordButton                matlab.ui.control.Button
        ModeSwitch                  matlab.ui.control.Switch
        ModeSwitchLabel             matlab.ui.control.Label
        FilterSwitch                matlab.ui.control.ToggleSwitch
        FilterSwitchLabel           matlab.ui.control.Label
        UIAxes4                     matlab.ui.control.UIAxes
        UIAxes3                     matlab.ui.control.UIAxes
        UIAxes2                     matlab.ui.control.UIAxes
        UIAxes                      matlab.ui.control.UIAxes
        SerialPort                  % Serial port object
        Fs = 8000;
        fs = 5000;
        fc1 = 30;
        fc2 = 200;
        T = 1/5000;
        n = 1;
        m = 1;
        m1 = 1;
        plotWindow = 2000; % Number of samples to display in each subplot
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.SerialPort = serialport("COM8", 9600);
            configureTerminator(app.SerialPort, "CR/LF");
            flush(app.SerialPort);
            app.SerialPort.UserData = struct("Data", [], "Order", 1, "fData", []);

            % Configure UIAxes for plotting
            title(app.UIAxes, 'Original Signal');
            xlabel(app.UIAxes, 'Samples');
            ylabel(app.UIAxes, 'Amplitude');
            grid(app.UIAxes, 'on');

            title(app.UIAxes2, 'Filtered Signal');
            xlabel(app.UIAxes2, 'Samples');
            ylabel(app.UIAxes2, 'Amplitude');
            grid(app.UIAxes2, 'on');

            % Start the data processing loop
            app.dataProcessingLoop();
        end

        % Value changed function: ModeSwitch
        function ModeSwitchValueChanged(app, event)
            % Implement this function based on your requirements
            % For example:
            disp('Mode Switch Value Changed');
        end

       % Value changed function: FilterSwitch
function FilterSwitchValueChanged(app, event)
    % Check the new value of FilterSwitch
    if app.FilterSwitch.Value
        % Handle the case when FilterSwitch is turned ON
        disp('Filter Switch Turned ON');
        % Add your custom code for when the filter is enabled

        % Example: Update the Lamp color
        app.FilterLamp.Color = [0, 1, 0]; % Green

        % Resume the data processing loop
        app.dataProcessingLoop();
    else
        % Handle the case when FilterSwitch is turned OFF
        disp('Filter Switch Turned OFF');
        % Add your custom code for when the filter is disabled

        % Example: Update the Lamp color
        app.FilterLamp.Color = [1, 0, 0]; % Red

        % Stop the data processing loop or perform any necessary actions
        % Add your custom code here to freeze the display or stop any ongoing processes
    end
end
    end 

    % Additional methods for data processing
    methods (Access = public)

        % Data processing loop
        function dataProcessingLoop(app)
            while app.SerialPort.UserData.Order < 100000
                tic;
                data = readline(app.SerialPort);

                app.SerialPort.UserData.Data(end+1) = (str2double(data)*5/512) - 1;
                app.SerialPort.UserData.Order = app.SerialPort.UserData.Order + 1;
                toc;

                if mod(app.SerialPort.UserData.Order, 10) == 0
                    configureCallback(app.SerialPort, "off");

                    % Plot original data
                    plot(app.UIAxes, app.SerialPort.UserData.Data(max(1, end-app.plotWindow+1):end));
                    title(app.UIAxes, 'Original Signal');

                    % Apply Butterworth bandpass filter
                    [coefficient_1, coefficient_2] = butter(4, [app.fc1/(app.fs/2), app.fc2/(app.fs/2)], 'bandpass');
                    app.SerialPort.UserData.fData = filter(coefficient_1, coefficient_2, app.SerialPort.UserData.Data(1:end));

                    % Plot filtered data
                    plot(app.UIAxes2, app.SerialPort.UserData.fData(max(1, end-app.plotWindow+1):end) * 3);
                    title(app.UIAxes2, 'Filtered Signal');
                    drawnow;

                    configureTerminator(app.SerialPort, "CR/LF");
                end

                if mod(app.SerialPort.UserData.Order, 400) == 0
                    configureCallback(app.SerialPort, "off");

                    % FFT processing
                    startIndex2 = app.m;
                    endIndex2 = min(app.m + 399, length(app.SerialPort.UserData.Data));

                    Y = fft(app.SerialPort.UserData.Data(startIndex2:endIndex2));
                    P2 = abs(Y / 400);
                    f = app.fs * (0:(length(Y)/2))/length(Y);
                    P1 = P2(1:length(Y)/2+1);
                    P1(2:end-1) = 2 * P1(2:end-1);

                    % Plot RAW FFT
                    plot(app.UIAxes3, f, P1, 'r');
                    title(app.UIAxes3, 'RAW FFT');
                    set(gca, 'ylim', [0 1]);

                    Y1 = fft(app.SerialPort.UserData.fData(startIndex2:endIndex2));
                    P3 = abs(Y1 / 400);
                    f1 = app.fs * (0:(length(Y1)/2))/length(Y1);
                    P4 = P3(1:length(Y1)/2+1);
                    P4(2:end-1) = 2 * P4(2:end-1);

                    % Plot Filtered FFT
                    plot(app.UIAxes4, f1, P4, 'r');
                    title(app.UIAxes4, 'Filtered FFT');
                    set(gca, 'ylim', [0 1]);

                    grid(app.UIAxes3, 'on');
                    grid(app.UIAxes4, 'on');

                    app.m = app.m + 400;
                    configureTerminator(app.SerialPort, "CR/LF");
                end

                if mod(app.SerialPort.UserData.Order, 250) == 0
                    threshold = 2.78;
                    [peaks, ~] = findpeaks(app.SerialPort.UserData.Data, 'MinPeakHeight', threshold);
                    numPeaks = numel(peaks);
                    bpm = (7500 * numPeaks) / app.SerialPort.UserData.Order;

                    % Do something with bpm
                end
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 718 547];
            app.UIFigure.Name = 'MATLAB App';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Title')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [14 214 300 185];

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.UIFigure);
            title(app.UIAxes2, 'Title')
            xlabel(app.UIAxes2, 'X')
            ylabel(app.UIAxes2, 'Y')
            zlabel(app.UIAxes2, 'Z')
            app.UIAxes2.Position = [14 17 300 185];

            % Create UIAxes3
            app.UIAxes3 = uiaxes(app.UIFigure);
            title(app.UIAxes3, 'Title')
            xlabel(app.UIAxes3, 'X')
            ylabel(app.UIAxes3, 'Y')
            zlabel(app.UIAxes3, 'Z')
            app.UIAxes3.Position = [391 214 300 185];

            % Create UIAxes4
            app.UIAxes4 = uiaxes(app.UIFigure);
            title(app.UIAxes4, 'Title')
            xlabel(app.UIAxes4, 'X')
            ylabel(app.UIAxes4, 'Y')
            zlabel(app.UIAxes4, 'Z')
            app.UIAxes4.Position = [391 17 300 185];

            % Create FilterSwitchLabel
            app.FilterSwitchLabel = uilabel(app.UIFigure);
            app.FilterSwitchLabel.HorizontalAlignment = 'center';
            app.FilterSwitchLabel.Position = [239 411 71 22];
            app.FilterSwitchLabel.Text = 'Filter Switch';

            % Create FilterSwitch
            app.FilterSwitch = uiswitch(app.UIFigure, 'toggle');
            app.FilterSwitch.ValueChangedFcn = createCallbackFcn(app, @FilterSwitchValueChanged, true);
            app.FilterSwitch.Position = [264 469 20 45];

            % Create ModeSwitchLabel
            app.ModeSwitchLabel = uilabel(app.UIFigure);
            app.ModeSwitchLabel.HorizontalAlignment = 'center';
            app.ModeSwitchLabel.Position = [376 445 35 22];
            app.ModeSwitchLabel.Text = 'Mode';

            % Create ModeSwitch
            app.ModeSwitch = uiswitch(app.UIFigure, 'slider');
            app.ModeSwitch.Items = {'Hearth', 'Lung'};
            app.ModeSwitch.ValueChangedFcn = createCallbackFcn(app, @ModeSwitchValueChanged, true);
            app.ModeSwitch.Position = [371 482 45 20];
            app.ModeSwitch.Value = 'Hearth';

            % Create RecordButton
            app.RecordButton = uibutton(app.UIFigure, 'push');
            app.RecordButton.Position = [80 468 100 23];
            app.RecordButton.Text = 'Record Button';

            % Create EditOrderEditFieldLabel
            app.EditOrderEditFieldLabel = uilabel(app.UIFigure);
            app.EditOrderEditFieldLabel.HorizontalAlignment = 'right';
            app.EditOrderEditFieldLabel.Position = [487 492 59 22];
            app.EditOrderEditFieldLabel.Text = 'Edit Order';

            % Create EditOrderEditField
            app.EditOrderEditField = uieditfield(app.UIFigure, 'numeric');
            app.EditOrderEditField.Position = [561 492 100 22];

            % Create EditLPCutoffEditFieldLabel
            app.EditLPCutoffEditFieldLabel = uilabel(app.UIFigure);
            app.EditLPCutoffEditFieldLabel.HorizontalAlignment = 'right';
            app.EditLPCutoffEditFieldLabel.Position = [487 448 79 22];
            app.EditLPCutoffEditFieldLabel.Text = 'Edit LP Cutoff';

            % Create EditLPCutoffEditField
            app.EditLPCutoffEditField = uieditfield(app.UIFigure, 'numeric');
            app.EditLPCutoffEditField.Position = [581 448 80 22];

            % Create FilterLampLabel
            app.FilterLampLabel = uilabel(app.UIFigure);
            app.FilterLampLabel.HorizontalAlignment = 'right';
            app.FilterLampLabel.Position = [310 377 65 22];
            app.FilterLampLabel.Text = 'Filter Lamp';

            % Create FilterLamp
            app.FilterLamp = uilamp(app.UIFigure);
            app.FilterLamp.Position = [390 377 20 20];

            % Create EditHPCutoffEditFieldLabel
            app.EditHPCutoffEditFieldLabel = uilabel(app.UIFigure);
            app.EditHPCutoffEditFieldLabel.HorizontalAlignment = 'right';
            app.EditHPCutoffEditFieldLabel.Position = [487 411 81 22];
            app.EditHPCutoffEditFieldLabel.Text = 'Edit HP Cutoff';

            % Create EditHPCutoffEditField
            app.EditHPCutoffEditField = uieditfield(app.UIFigure, 'numeric');
            app.EditHPCutoffEditField.Position = [583 411 100 22];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = denemesonson

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
