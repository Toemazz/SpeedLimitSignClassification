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
