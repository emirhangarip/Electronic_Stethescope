clear all;
close all;

a = serialport("COM6", 9600);
configureTerminator(a, "CR/LF");
flush(a);
a.UserData = struct("Data", [], "Order", 1,"fData",[],"ffdata",[]);
Fs=8000;
fs = 5000;
fc1 = 30;
fc2 = 200;
fc3=30;
fc4=1000;
T = 1/fs;
n=1;
m=1;
m1=1;
plotWindow = 2000; % Number of samples to display in each subplot
tic

while a.UserData.Order < 100000
      %Taking values from arduino
    data = readline(a);

    a.UserData.Data(end+1) = (str2double(data));
    a.UserData.Order = a.UserData.Order + 1;
    

    if mod(a.UserData.Order, 20) == 0
        configureCallback(a, "off");
        
        % Plot original data
        subplot(4, 1, 1);
        plot(a.UserData.Data(max(1, end-plotWindow+1):end));
        title('Original Signal');
        
        % Apply Butterworth bandpass filter
        [coefficient_1, coefficient_2] = butter(4, fc3/(fs/2), 'high');
        a.UserData.ffData = filter(coefficient_1, coefficient_2, a.UserData.Data(1:end));
        
        [coefficient_3, coefficient_4] = butter(4, [fc1/(fs/2), fc2/(fs/2)], 'bandpass');
        a.UserData.fData = filter(coefficient_3, coefficient_4, a.UserData.Data(1:end));
         
        

        % Plot filtered data
        subplot(4, 1, 2);
        plot(a.UserData.fData(max(1, end-plotWindow+1):end) * 3);
        title('Filtered Signal');
        drawnow;
        
        configureTerminator(a, "CR/LF");
    end
    if mod(a.UserData.Order, 500) == 0
        configureCallback(a, "off")
    
    Y = fft(a.UserData.ffData(end-499+1:end));
    P2 = abs(Y / 500); % Use 400 for normalization
    f = fs * (0:(length(Y)/2))/length(Y); % Adjust frequency axis
    P1 = P2(1:length(Y)/2+1);
    P1(2:end-1) = 2 * P1(2:end-1);

    % Plot FFT
    subplot(4, 1, 3);
    plot(f, P1, 'r')
    title('RAW FFT');
    set(gca,'ylim',[0 15]);

    Y1 = fft(a.UserData.fData(end-499+1:end));
        P3 = abs(Y1 / 500); % Use 400 for normalization
        f1 = fs * (0:(length(Y1)/2))/length(Y1); % Adjust frequency axis
        P4 = P3(1:length(Y1)/2+1);
        P4(2:end-1) = 2 * P4(2:end-1);

        subplot(4, 1, 4);
        plot(f1, P4, 'r')
        title('Filtered FFT');
        set(gca,'ylim',[0 15]);

        

    grid on
    m = m + 500;
    configureTerminator(a, "CR/LF");
    end
    %if mod(a.UserData.Order, 1000) == 0
%startIndex1=n;
%endIndex1=min(n+999,length(a.UserData.fData));
%y=reshape(normalize(a.UserData.fData(:),'range',[-1,1]),size(a.UserData.fData));
%audiowrite('ses.wav',y(startIndex1:endIndex1),Fs);
%[yy,Fs]=audioread('ses.wav');
%sound(y);
 %   end

 %BPM
   if mod(a.UserData.Order, 1500) == 0
     % Measure elapsed time
    timeAtPointBPM = toc;
    % Reset the timer immediately for the next interval
     

    % Detect peaks in the data
    threshold = 490; % Adjust this threshold as needed
    [peaks, ~] = findpeaks(a.UserData.Data(end-1499+1:end), 'MinPeakHeight', threshold);
    numPeaks = numel(peaks); % Count the number of peaks

    % Calculate BPM
    bpm = (60 * numPeaks) / timeAtPointBPM; % BPM calculation
    disp(int16(bpm)); % Display BPM
    tic;
    end

end
