%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SCRIPT: Main Program
clear; clc; close all;

% Define image directories
detectedSignsDir = 'images/20/';
% detectedSignsDir = 'images/30/';
% detectedSignsDir = 'images/50/';
% detectedSignsDir = 'images/80/';
% detectedSignsDir = 'images/100/';
goldDigitsDir = 'images/GoldStandardDigits_Development/';

% Classify the speed limit for each detected sign in 'detectedSignsDir'
ClassifySpeedLimits(detectedSignsDir, goldDigitsDir, '*.jpg');
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
        mask = bwareafilt(mask, [2000, 10000]);

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

