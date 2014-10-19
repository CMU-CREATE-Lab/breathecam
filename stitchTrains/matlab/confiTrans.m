function [x_optimal] = confiTrans(x_seed,confi_points, confi_perturb, big_im1,big_im2)
%%
im1 = big_im1(25:1175,:,:);
im2 = big_im2(25:1175,:,:);

%convert to double precision grayscale images
if (size(im1,3) == size(im2,3)) && (size(im1,3) == 3)

    im1 = im2double(im1);
    im1 = rgb2gray(im1);

    im2 = im2double(im2);
    im2 = rgb2gray(im2);
end

%find the points using default detector. points is a structure btw
points1 = detectSURFFeatures(im1);
points2 = detectSURFFeatures(im2);

%extract the features from these points
[features1, valid_points1] = extractFeatures(im1, points1);
[features2, valid_points2] = extractFeatures(im2, points2);

%match them
indexPairs = matchFeatures(features1, features2);

%find out the matched points. output is a structure 
matched_points1 = valid_points1(indexPairs(:, 1), :);
matched_points2 = valid_points2(indexPairs(:, 2), :);

%find out the locations of the matches
locs1 = round(matched_points1.Location);
locs2 = round(matched_points2.Location);

sprintf('The size of locs 1 is ');size(locs1)

N           = size(locs1,1);
% disp(['The number of points matching is ' , num2str(N)]);
if (N >= confi_points)
    matches     = [(1:N)' (1:N)'];
    nIter       = 300;
    tol         = 2;
    [bestH,~,~] = ransacH(matches,locs1,locs2,nIter,tol);
    H2to1       = bestH;
    if (abs(bestH(7) - x_seed) < confi_perturb)
        x_optimal = H2to1(7);
        disp(['The value as per ransac observed is ', num2str(H2to1(7)), ' number of observations is ' ,num2str(N)]);
    else
        x_optimal = x_seed;
    end
else
    x_optimal = x_seed;
end
