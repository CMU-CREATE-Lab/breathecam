start = 3009;
stitch = imread(sprintf('../trainPics/tframe0%d.jpg',start));
x_translate  = 309;
y_translate  = 0;

confi_points = 20;
confi_perturb = 6;
for i = 1:2000
    num_im1 = start + 3*i;
    num_im2 = start + 3*(i+1);
    big_im1 = imread(sprintf('../trainPics/tframe0%d.jpg',num_im1));
    big_im2 = imread(sprintf('../trainPics/tframe0%d.jpg',num_im2));
        
    x_optimal = confiTrans(x_translate ,confi_points, confi_perturb, big_im1,big_im2);
    x_translate         = x_optimal;
    J  = imtranslate(big_im1,[x_optimal, y_translate],'OutputView','full');
    stitch = [stitch  J(:,end-round(x_optimal):end,:)];
    if size(stitch,2) > 2000
        imshow(stitch(:,end-2000:end,:));
        stitch = stitch(:,end-2000:end,:);
    end
    x_translate = 309;
    %drawnow;
   % imwrite(stitch,'stitch.jpg');
    i
%     pause(0.25)
%     disp(['We are in the iteration ' , i , ' and the x_optimal is ' , num2str(x_optimal)]);
end
