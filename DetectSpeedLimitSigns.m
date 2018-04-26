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
