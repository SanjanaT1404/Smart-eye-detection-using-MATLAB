function RealTimeEyeDetectionWithIrisColor
    % Create GUI window
    hFig = figure('Name', 'Eye Detection with Iris Color', 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', 'Position', [100, 100, 800, 600]);

    % Add buttons
    startButton = uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Start Webcam', ...
        'Position', [50, 500, 150, 50], 'Callback', @startWebcam);

    stopButton = uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Stop Webcam', ...
        'Position', [250, 500, 150, 50], 'Callback', @stopWebcam, 'Enable', 'off');

    saveButton = uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Save Eye Image', ...
        'Position', [450, 500, 150, 50], 'Callback', @saveEyeImage, 'Enable', 'off');

    % Input field for image name
    uicontrol('Parent', hFig, 'Style', 'text', 'String', 'Image Name:', ...
        'Position', [650, 520, 100, 20]);
    nameEdit = uicontrol('Parent', hFig, 'Style', 'edit', 'Position', [650, 500, 100, 20]);

    % Blink Count Display
    uicontrol('Parent', hFig, 'Style', 'text', 'String', 'Blink Count:', ...
        'Position', [650, 470, 100, 20]);
    blinkCountText = uicontrol('Parent', hFig, 'Style', 'text', 'String', '0', ...
        'Position', [650, 450, 100, 20], 'BackgroundColor', 'white');

    % Iris Color Display
    uicontrol('Parent', hFig, 'Style', 'text', 'String', 'Iris Color:', ...
        'Position', [650, 410, 100, 20]);
    irisColorText = uicontrol('Parent', hFig, 'Style', 'text', 'String', '-', ...
        'Position', [650, 390, 100, 20], 'BackgroundColor', 'white');

    % Axes for webcam feed
    hAxes = axes('Parent', hFig, 'Units', 'pixels', 'Position', [50, 50, 700, 400]);

    % Variables
    cam = [];
    timerObj = [];
    detectedEye = [];
    faceDetector = vision.CascadeObjectDetector('FrontalFaceCART');
    eyeDetector = vision.CascadeObjectDetector('EyePairBig');
    blinkCount = 0;  % Track blinks
    eyesOpen = false;  % Track eye state (open/closed)

    % Start Webcam Function
    function startWebcam(~, ~)
        try
            cam = webcam; % Initialize webcam
        catch
            msgbox('Failed to initialize the webcam. Ensure it is connected.', 'Error', 'error');
            return;
        end
        
        set(startButton, 'Enable', 'off');
        set(stopButton, 'Enable', 'on');
        set(saveButton, 'Enable', 'on');

        % Start timer for processing frames
        timerObj = timer('ExecutionMode', 'fixedRate', 'Period', 0.1, ...
            'TimerFcn', @processFrame);
        start(timerObj);
    end

    % Stop Webcam Function
    function stopWebcam(~, ~)
        if ~isempty(timerObj) && strcmp(timerObj.Running, 'on')
            stop(timerObj);
            delete(timerObj);
        end
        if ~isempty(cam)
            clear cam;
        end
        set(startButton, 'Enable', 'on');
        set(stopButton, 'Enable', 'off');
        set(saveButton, 'Enable', 'off');
    end

    % Process Frame Function
    function processFrame(~, ~)
        if isempty(cam)
            msgbox('Webcam is not initialized. Please start the webcam.', 'Error', 'error');
            return;
        end

        try
            frame = snapshot(cam);
        catch
            msgbox('Error capturing frame from webcam. Please check the connection.', 'Error', 'error');
            return;
        end

        grayFrame = rgb2gray(frame); % Convert to grayscale for detection

        % Detect face
        faceBox = step(faceDetector, grayFrame);
        if ~isempty(faceBox)
            % Annotate face
            frame = insertObjectAnnotation(frame, 'rectangle', faceBox, 'Face', 'Color', 'yellow');

            % Detect eyes in the face region
            faceRegion = imcrop(grayFrame, faceBox(1, :)); % Crop to face
            eyeBox = step(eyeDetector, faceRegion);

            if ~isempty(eyeBox)
                % Adjust eye coordinates to the full frame
                eyeBox(1, 1:2) = eyeBox(1, 1:2) + faceBox(1, 1:2);

                % Annotate eyes
                frame = insertObjectAnnotation(frame, 'rectangle', eyeBox, 'Eyes', 'Color', 'cyan');

                % Extract detected eye region
                detectedEye = imcrop(frame, eyeBox(1, :));

                % Identify iris color
                irisColor = detectIrisColor(detectedEye);
                set(irisColorText, 'String', irisColor);

                % Update eye state
                if ~eyesOpen
                    eyesOpen = true;  % Eyes detected (open state)
                end
            else
                % Eyes not detected
                if eyesOpen
                    blinkCount = blinkCount + 1;  % Increment blink count
                    eyesOpen = false;  % Transition to closed state

                    % Update blink count on GUI
                    set(blinkCountText, 'String', num2str(blinkCount));
                end
            end
        end

        % Display frame
        imshow(frame, 'Parent', hAxes);
        title(hAxes, 'Webcam Feed');
    end

    % Save Eye Image Function
    function saveEyeImage(~, ~)
        if isempty(detectedEye)
            msgbox('No eyes detected to save!', 'Error', 'error');
            return;
        end

        % Get image name from user input
        imageName = get(nameEdit, 'String');
        if isempty(imageName)
            msgbox('Please enter a valid image name!', 'Error', 'error');
            return;
        end

        % Define save path
        outputFolder = fullfile(pwd, 'CapturedEyes');
        if ~exist(outputFolder, 'dir')
            mkdir(outputFolder);
        end
        fileName = fullfile(outputFolder, [imageName, '.jpg']);

        % Save the image
        imwrite(detectedEye, fileName, 'Quality', 100);
        msgbox(['Image saved as ', fileName], 'Success');
    end

    % Iris Color Detection Function
    function irisColor = detectIrisColor(eyeImage)
        if isempty(eyeImage)
            irisColor = '-';
            return;
        end

        % Convert to HSV color space
        hsvImage = rgb2hsv(eyeImage);

        % Extract hue channel
        hueChannel = hsvImage(:, :, 1);

        % Compute the dominant hue
        dominantHue = mode(hueChannel(:));

        % Determine iris color based on dominant hue
        if dominantHue < 0.1 || dominantHue > 0.9
            irisColor = 'Brown';
        elseif dominantHue > 0.2 && dominantHue < 0.4
            irisColor = 'Green';
        elseif dominantHue > 0.5 && dominantHue < 0.7
            irisColor = 'Blue';
        else
            irisColor = 'Unknown';
        end
    end

    % Cleanup on Close
    hFig.CloseRequestFcn = @(~, ~) closeGUI();

    function closeGUI()
        stopWebcam();
        blinkCount = 0;  % Reset blink count
        delete(hFig);
    end
end
