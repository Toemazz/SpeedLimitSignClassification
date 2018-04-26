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
