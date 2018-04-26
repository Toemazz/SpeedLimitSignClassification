%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SCRIPT: Main Program
clear; clc; close all;

% Define images directory and get the .png files in that directory
imagesDir = 'images/GoldStandard/';
fileData = GetFileDataFromDirectory(imagesDir, '*.png');

for i = 1:length(fileData)
    % Construct file path and load image
    filePath = fullfile(imagesDir, fileData(i).name);
    img = imread(filePath);
    
    % Extract black digits
    imageYCbCr = rgb2ycbcr(img);
    yMin = 0.000;
    yMax = 50.000;
    mask = (imageYCbCr(:, :, 1) >= yMin) & (imageYCbCr(:, :, 1) <= yMax);
    
    % Extract ROI of digits and save them
    cc = bwconncomp(mask, 8);
    stats = regionprops(cc, 'BoundingBox');
    
    for j = 1 : length(stats)
        BB = stats(j).BoundingBox;
        
        digitROI = ExtractROI(mask, int16(BB(2)), int16(BB(1)), int16(BB(2)+BB(4)), int16(BB(1)+BB(3)));
        digitROI = imresize(digitROI, [160, 120]);
        imwrite(~digitROI, sprintf('digit%02d%02d.png', i, j));
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