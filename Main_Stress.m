%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SCRIPT: Main Program
clear; clc; close all;

% Define image directories
inputImagesDir = 'images/Stress/';
detectedSignsDir = 'images/StressSigns/';
goldDigitsDir = 'images/GoldStandardDigits_Stress';

% Detect signs in images in 'inputImagesDir' and save them in
% 'detectedSignsDir'
DetectSpeedLimitSigns(inputImagesDir, detectedSignsDir, '*.TIF');

% Classify the speed limit for each detected sign in 'detectedSignsDir'
ClassifySpeedLimits(detectedSignsDir, goldDigitsDir, '*.png');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FUNCTION: Used to load images from a specified directory
function fileData = GetFileDataFromDirectory(dirPath, fileExtension)
    % Check to make sure that folder actually exists.  Warn user if it doesn't.
    if ~isdir(dirPath)
        errorMessage = sprintf('[ERROR]: The following folder does not exist:\n%s', dirPath);
        uiwait(warndlg(errorMessage));
        return;
    end

    % Get a list of all '.jpg' files in the directory
    filePattern = fullfile(dirPath, fileExtension);
    fileData = dir(filePattern);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FUNCTION: Used to extract a ROI (Region of Interest) from an image
function imageOut = ExtractROI(imageIn, y1, x1, y2, x2)
% Check if any of the points are '0'
if x1 == 0 || x2 == 0 || y1 == 0 || y2 == 0
    errorMessage = sprintf('[ERROR]: Ooops you forgot MATLAB indices start at 1!\n');
    uiwait(warndlg(errorMessage));
    return;
end

% Get image dimensions
[h, w, ~] = size(imageIn);

if x1 > w || x2 > w || y1 > h || y2 > h
    errorMessage = sprintf('[ERROR]: Images dimensions (%d, %d) exceeded!\n', h, w);
    uiwait(warndlg(errorMessage));
    return;
end

imageOut = imageIn(y1:y2, x1:x2, :);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FUNCTION: Used to find the speed limit by finding its best match from a
% list of gold standard images
function bestSpeedMatch = FindBestSpeedMatch(testImage, goldDigitsDir)
    % Load digits extracted from the gold standard images
    goldFileData = GetFileDataFromDirectory(goldDigitsDir, '*.png');

    % Loop over all gold standard digits to find the best match
    for i = 1:length(goldFileData)
        % Construct file path and load image
        filePath = fullfile(goldDigitsDir, goldFileData(i).name);
        goldImage = imread(filePath);

        % Subtract test image from gold standard image
        output = imsubtract(goldImage, testImage);
        
        % Calculate the percentage of black pixels in the binary image
        blackPercentValues(i) = 100*(sum(output(:)==0)/numel(output(:)));
    end
    
    % The output image with the highest percentage of black pixels is the
    % best match
    [~, index] = max(blackPercentValues);
    
    % Return string of the best matched speed
    bestSpeedMatch = goldFileData(index).name(1:end-4);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FUNCTION: Used to detect and extract the ROI of speed limit signs from a
% set of images
function DetectSpeedLimitSigns(inputImagesDir, outputImagesDir, inputImagesExt)
    % Load stress images from 'inputImagesDir'
    inputFileData = GetFileDataFromDirectory(inputImagesDir, inputImagesExt);

    for i = 1:length(inputFileData)
        % Construct file path
        filePath = fullfile(inputImagesDir, inputFileData(i).name);

        % Load RGB image
        img = imread(filePath);
        % Detect areas with red pixels
        redBW = DetectRed(img);

        % Remove connected components less than 20 pixels in area
        redBW = bwareaopen(redBW, 20);

        % Remove connected components touching the image border
        redBW = imclearborder(redBW);

        % Construct a disk-shaped structuring element
        se = strel('disk', 5);

        % Dilation followed by erosion (worked better than 'imclose')
        redBW = imdilate(redBW, se);
        redBW = imerode(redBW, se);

        % Label objects and get properties about each object
        [labelBW, numObjects] = bwlabel(redBW);
        stats  = regionprops(labelBW, 'Area', 'Perimeter', 'BoundingBox');
        count = 0;

        for j = 1:numObjects
            % Calculate measurements about each object in the image
            area = stats(j).Area;
            peri = stats(j).Perimeter;
            bbox = stats(j).BoundingBox;
            form = 4.*pi.*area./(peri.^2);

            % Find 'complete' circles
            complete = (form >= 0.22 && form < 0.36) &&...
                ((area >= 500 && area < 600) || (area >= 900 && area < 1800)) &&...
                (peri >= 140 && peri < 280); 

            % Find 'filled' circles
            filled = (form > 0.9) &&...
                ((area >= 140 && area < 155)) &&...
                (peri >= 30 && peri < 50);

            % Find circles with a 'square' perimeter
            square = (form >= 0.44 && form < 0.62) &&...
                (area >= 180 && area < 800) &&...
                (peri >= 70 && peri < 160);

            % Find 'incomplete' circles
            incomplete = (form < 0.2) &&...
                (area >= 600 && area < 700) &&...
                (peri >= 200 && peri < 300);

            % 'True' if speed limit sign was found
            signFound = complete || filled || square || incomplete;

            if signFound
                % Extract the ROI of the sign
                signROI = ExtractROI(img, int16(bbox(2)), int16(bbox(1)),...
                    int16(bbox(2)+bbox(4)-1), int16(bbox(1)+bbox(3)-1));

                % Enhance contrast using histogram equalization
                signROIAdjusted = histeq(signROI);

                % Detect areas with white pixels
                whiteBW = DetectWhite(signROIAdjusted);

                % Calculate the percentage of white pixels in the binary image
                whitePercent = 100 * (sum(whiteBW(:)==1) / numel(whiteBW(:)));

                % ROI contains a sign if % white pixels greater than 25%
                if whitePercent >= 25
                    count = count + 1;

                    % Save ROI containing the sign to 'outputImagesDir'
                    imwrite(signROI, sprintf('%s/%s_%02d.png',...
                        outputImagesDir, inputFileData(i).name(1:end-4), count));
                end
            end
        end 
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FUNCTION: Used to detect red pixels in an image
function outBW = DetectRed(imageRGB)
    % Convert RGB image to HSV
    imageHSV = rgb2hsv(imageRGB);

    % Define thresholds for 'H' channel
    hMin = 0.9;
    hMax = 0.1;

    % Define thresholds for 'S' channel
    sMin = 0.5;
    sMax = 1.0;
    
    % Threshold image
    outBW = (imageHSV(:, :, 1) >= hMin | imageHSV(:, :, 1) <= hMax) &...
        (imageHSV(:, :, 2) >= sMin & imageHSV(:, :, 2) <= sMax);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FUNCTION: Used to detect white pixels in an image
function outBW = DetectWhite(imageRGB)
    % Convert RGB image to HSV
    imageHSV = rgb2hsv(imageRGB);

    % Define thresholds for 'S' channel
    sMin = 0.0;
    sMax = 0.4;
    
    % Define thresholds for 'V' channel
    vMin = 0.4;
    VMax = 1.0;
    
    % Threshold image
    outBW = (imageHSV(:, :, 2) >= sMin & imageHSV(:, :, 2) <= sMax) &...
        (imageHSV(:, :, 3) >= vMin | imageHSV(:, :, 3) <= VMax);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FUNCTION: Used to classify the speed limit on a detected sign
function ClassifySpeedLimits(inputImagesDir, goldDigitsDir, inputImagesExt)
    % Get images from 'inputImagesDir'
    inputFileData = GetFileDataFromDirectory(inputImagesDir, inputImagesExt);

    for i = 1:length(inputFileData)
        % Construct file path and load image
        filePath = fullfile(inputImagesDir, inputFileData(i).name);
        img = imread(filePath);

        % Get image dimensions
        [h, w, ~] = size(img);

        % Extract square ROI of the sign
        if w >= h   
            imgROI = ExtractROI(img, 1, 1, h, h);
        else
            imgROI = ExtractROI(img, h-w, 1, h-1, w);
        end

        % Resize image
        imgROI = imresize(imgROI, [450, 450]);

        % Extract black digits by converting to YCbCr, setting limits for the
        % 'y' channel and creating the mask
        imageROIYCbCr = rgb2ycbcr(imgROI);
        yMin = 0.0;
        yMax = 85.0;
        mask = (imageROIYCbCr(:, :, 1) >= yMin) & (imageROIYCbCr(:, :, 1) <= yMax);

        % Construct a disk-shaped structuring element
        se = strel('disk', 5);

        % Erosion followed by dilation (worked better than 'imopen')
        mask = imerode(mask, se);
        mask = imdilate(mask, se);

        % Remove objects touching the image border
        mask = imclearborder(mask);

        % Remove small and large objects
        mask = bwareafilt(mask, [4500, 12000]);

        % Remove objects with an 'extent' value less than 0.25
        % where Extent = ObjectArea / BoundingBoxArea
        cc = bwconncomp(mask);
        labelMatrix = labelmatrix(cc);
        statsExtent = regionprops(cc, 'Extent');
        indexes = [statsExtent.Extent] >= 0.3;
        mask = ismember(labelMatrix, find(indexes));

        % Keep the 2 objects with the largest area
        mask = bwareafilt(mask, 2);
        
        % Get bounding box for each digit as the ROI
        statsBB = regionprops(mask, 'BoundingBox');

        % Check if any digits remain
        if ~isempty(statsBB)
            % Extract the ROI for the left digit by setting the index of the object
            % in the labelled image to '1'
            bbox = statsBB(1).BoundingBox;
            digitROI = ExtractROI(mask, int16(bbox(2)), int16(bbox(1)), int16(bbox(2)+bbox(4)), int16(bbox(1)+bbox(3)));

            % Resize each image to [160, 120]
            digitROI = imresize(digitROI, [160, 120]);
            
            % Get the best match for the digits detected on the sign
            speedLimit = FindBestSpeedMatch(~digitROI, goldDigitsDir);

            % Print results
            fprintf('%s: %s\n', inputFileData(i).name(1:end-4), speedLimit);
        else
            % Print failure result if no digits were detected
            fprintf('%s: Speed limit could not be found!\n', inputFileData(i).name(1:end-4));
        end
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
