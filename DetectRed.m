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
