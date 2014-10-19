%%
for i = 2103:2300
num_im1 = start + 3*i;
num_im2 = start + 3*(i+1);
big_im1 = imread(sprintf('../trainPics/tframe0%d.jpg',num_im1));
big_im2 = imread(sprintf('../trainPics/tframe0%d.jpg',num_im2));

% H =  findBestH(big_im1(764:1340,:,:),big_im2(764:1340,:,:));
% x_optimal = H(7)
x_optimal = 285;
J = imtranslate(big_im2,[x_optimal, y_translate],'OutputView','full');
% subplot(1,3,3)
imshow([big_im1 J(:,end-round(x_optimal):end,:)]);
drawnow
% result = input('prompt')
% pause(2)
i
end

