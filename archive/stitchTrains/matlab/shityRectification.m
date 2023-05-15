%rudimentary recification algorithm specific to our kind of videos
%Idea is simple. select the points on the train track. we want them to be
%along the horizontal axis in the image

%I followed the simple algorithm
%choose points on track
%destincation points of these pixels have the same x coordinate, and a
%constant y coordinte. find homography reqd to achieve this

% for i =  1000:4000
    i = 1515;
    filename = sprintf('../pics/output_%05d.jpg',i);
    temp = imread(filename);
    temp = temp(500:1400,:,:);
    i
    imshow(temp)
    drawnow
% end

%%
%choose points on the track, 1
[line1_x,line1_y] = ginput
line1_x_k = line1_x 
line1_y_k = line1_y(1)*ones(length(line1_y),1)
%%
%choose points on the track, or top of train
[line2_x,line2_y] = ginput
line2_x_k = line2_x 
line2_y_k = line2_y(1)*ones(length(line2_y),1)
%%
%choose points on the track or on train.
[line3_x,line3_y] = ginput
line3_x_k = line3_x 
line3_y_k = line3_y(1)*ones(length(line3_y),1)

%%

prev = [[line1_x;line2_x;line3_x] [line1_y;line2_y;line3_y]];
new  = [[line1_x_k;line2_x_k;line3_x_k] [line1_y_k;line2_y_k;line3_y_k]];  %x coordinate same, y coordinate constant
%%

H = computeH_norm(new',prev')
tform = projective2d(H');
outputImage = imwarp(temp,tform);
imshow(outputImage)
save('Homography_folder6.mat','H');
%%