%This is the main file for the stitching of trains.

%Ideally the camera should be placed in front of the train, and the tracks 
%should be along the axis in the image

%Should the image be rectified slightly, use "shittyRectification.m" 

rectify_flag = 0;

if ( rectify_flag == 1 )
	load('Homography_folder6.mat')    %homography matrix for rectification from shittyRectification.
	tform = projective2d(H');
else 
	tform = projective2d(eye(3));   %if no rectification is needed
end

start = 690;
first_image_number = 1;
first_pic          = start+ 3*first_image_number;     
%note that we take every third image to consider for stitiching. change 3 here as per the speed of train

tile_size = 2000;  %horizontal width of the tiles we want to generate
stitch = imread(sprintf('../pics/output_%05d.jpg',first_pic));
stitch = stitch(600:1500,:,:);  
%crop image to remove unnecessary part. This was done to speed up the rectification, where each pixel location is multiplied with a martix

% stitch_r = imrotate(stitch,-90);  %No need cause we used ffmpeg to rotate
% the images
%%
stitch_r = imwarp(stitch,tform);  % _r for rectified
%%
x_translate = -206;   %initial seed of displacement. Found out by checking manually 
y_translate = 0;      % should be zero if you rectified reasonably well
confi_points = 20;    %number of features to be detected to consider for finding homography between images
confi_perturb = 10;   %perturbation from current displacement value allowed from ransac. 
%This is from the assumption that train velocity is relatively smooth, and
%to insure from the possibility of having a poor result from ransac with
%few points


count = 0;
big_im1_r = zeros(size(stitch_r));
big_im2_r = zeros(size(stitch_r));
%%
for i = 1:2300  %main loop for stitching
    num_im1 = start + 3*i;
    num_im2 = start + 3*(i+1);
    big_im1 = imread(sprintf('../pics/output_%05d.jpg',num_im1));
    big_im1 = big_im1(600:1500,:,:);    %crop
    big_im1_r = imwarp(big_im1,tform);  %rectify
    % imshow(big_im1_r)
    %%
    big_im2 = imread(sprintf('../pics/output_%05d.jpg',num_im2));
    big_im2 = big_im2(600:1500,:,:);
    big_im2_r = imwarp(big_im2,tform);
    % imshow(big_im2_r)
    %%
    x_optimal = confiTrans(x_translate ,confi_points, confi_perturb, big_im1_r,big_im2_r); %find translation bw images using homography. see confitrans.m
    %  x_optimal = 245
    x_translate = x_optimal;  %output from confitrans
    J = uint8(imtranslate(big_im2_r,[x_optimal, y_translate],'OutputView','full')); %move image 
    what = size(stitch_r,2);
    if (what < 31) %minimum cloums i use for blending.
        stitch_r = pleaseBlend(J(:,1: -x_optimal,:), stitch_r,what-1);    %blending between images so that it doesnt stand out. see please blend
    %     stitch_r = pleaseBlend(stitch_r, J(:,end-round(x_optimal)-what-1:end,:), what-1);
    else
        stitch_r = pleaseBlend(J(:,1: -x_optimal,:), stitch_r,30);
    %     stitch_r = pleaseBlend(stitch_r, J(:,end-round(x_optimal)-25:end,:), 25);
    end
        drawnow
    % stitch = [stitch J(:,end-round(x_optimal):end,:)];

    if size(stitch_r,2) > tile_size    %create tiles of tile_size pixels in width
        count = count+1;
    %    imshow(stitch_r(:,1:tile_size,:));
        cut_image = stitch_r(1:end-300,end-tile_size:end,:);
        imshow(cut_image)
        filename = sprintf('%s_%04d_%d.jpg','/home/Desktop/stitch',count,i);
        %imwrite(cut_image,filename);
        stitch_r = stitch_r(:,1:end-2001,:); %remaining piece of image for next tile
    end
    drawnow
end
