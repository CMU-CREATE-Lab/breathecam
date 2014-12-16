#include <iostream>
#include <opencv2/opencv.hpp>
 
using namespace cv;

int main(int argc, char** argv )
{
	Mat image, mask_inpaint , mask_gaus;
	image = imread(argv[1],CV_LOAD_IMAGE_COLOR);  
	mask_inpaint  = imread(argv[2],CV_LOAD_IMAGE_GRAYSCALE);  //inpaint mask
	mask_gaus = imread(argv[3],CV_LOAD_IMAGE_GRAYSCALE);  //gaussian mask


	Mat hsvImage;   //convert to hsv space to differenciate between night and day
	cvtColor(image, hsvImage, CV_BGR2HSV);
	Scalar avgValue = mean(hsvImage);

	Mat channel_image[3];
	split(image, channel_image);
	Mat absolute;
	absdiff(channel_image[0],channel_image[1],absolute); 
	//content in all channels should be same when camera switches to grayscale.
	// so diff should be close to zero for grayscale

	double min,max;
	minMaxLoc(absolute, &min, &max);

	Mat inpainted;
	inpaint(image, mask_inpaint, inpainted, 5, CV_INPAINT_TELEA); //inpainting using fast marching algo. 
	//replaces mask pixels with the weighted median of pixel in the neighbourhood.

	vector<int> compression_params;  //quality of saved jpeg image
	compression_params.push_back(CV_IMWRITE_JPEG_QUALITY);
	compression_params.push_back(100);

	if (max < 30)   //if night then blur.
	{
		Mat gaus_blur;
		GaussianBlur(image, gaus_blur, Size(15,15), 5, 5 );  //gaussian kernel for night time
		std::cout << "Detected night" << std::endl;
		namedWindow("gaus blur",WINDOW_NORMAL);
		imshow("gaus blur",gaus_blur);
		gaus_blur.copyTo(inpainted,mask_gaus);
	}

	try 
	{
		imwrite(argv[4],inpainted,compression_params);
	}
	catch (...) 
	{
		std::cout << "Some exception occured. Lookout \n"; 
        	return 1;
    	}
	return 0;
}
