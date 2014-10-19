start = 3009;
first_image_number = 2103;
first_pic          = start+ 3*first_image_number;
stitch = imread(sprintf('../trainPics/tframe0%d.jpg',first_pic));
x_translate = 285;
y_translate = 0;
confi_points = 20;
confi_perturb = 3;
count = 298;
%%
for i = first_image_number:2300
num_im1 = start + 3*i;
num_im2 = start + 3*(i+1);
big_im1 = imread(sprintf('../trainPics/tframe0%d.jpg',num_im1));
big_im2 = imread(sprintf('../trainPics/tframe0%d.jpg',num_im2));

x_optimal = confiTrans(x_translate ,confi_points, confi_perturb, big_im1,big_im2);
% x_optimal = 245
x_translate = x_optimal
J = imtranslate(big_im2,[x_optimal, y_translate],'OutputView','full');
what = size(stitch,2)
if (what < 26)
    stitch = pleaseBlend(stitch, J(:,end-round(x_optimal)-what-1:end,:), what-1);
else
    stitch = pleaseBlend(stitch, J(:,end-round(x_optimal)-25:end,:), 25);
end
    imshow(stitch);
    drawnow
%     pause(1)
% stitch = [stitch J(:,end-round(x_optimal):end,:)];

if size(stitch,2) > 2000
    count = count+1;
    imshow(stitch(:,1:2000,:));
    cut_image = stitch(:,1:2000,:);
    filename = sprintf('%s_%d_%d.jpg','potrait/stitch',count,i);
    imwrite(cut_image,filename);
    stitch = stitch(:,2001:end,:);
end
drawnow
% x_translate = 309;
%drawnow;
i
% pause(0.25)
% disp(['We are in the iteration ' , i , ' and the x_optimal is ' , num2str(x_optimal)]);
end
