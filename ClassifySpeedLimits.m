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
