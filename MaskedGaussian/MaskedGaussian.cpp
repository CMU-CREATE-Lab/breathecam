#include <iostream>
#include <opencv2/opencv.hpp>
#include <iostream>
#include <string>
#include <stdio.h>
#define LIGHT_THRESHOLD 170

using namespace cv;
int main(int argc, char** argv )
{
	Mat     input_image,roi;//,output;

	roi  = imread("locate_3_gimp.jpg",0);
	Mat med_blur, light_rem, gaus_blur_small, temp_erode, gaus_blur_big, eroded , mask_from_eroded, temp;
	for(int k =1 ; k<124;k++)
	{
	char Fname[100];

 	sprintf(Fname, "pitt_image_3/%03d.jpg", k);

	std::cout << "File name is " << Fname << std::endl;
	input_image = imread(Fname,0);
//	input_image = imread(argv[1],0);
//	roi  = imread(argv[2],0);


	medianBlur(input_image, med_blur,5);   //remove salt and pepper
	GaussianBlur(med_blur, gaus_blur_small, Size(7,7),4,4); //to have bright regions together

        Mat bright_light = (input_image > LIGHT_THRESHOLD);
	temp_erode = ~bright_light;

	Mat element = getStructuringElement( MORPH_ELLIPSE, Size(5,5)); //eroding element

	erode( temp_erode, eroded, element , Point(-1,-1),2,BORDER_CONSTANT);

	mask_from_eroded = ~eroded;
	
	std::cout << "we are here " << roi.size() << " and "  << mask_from_eroded.size()  << std::endl;
	Mat to_fill = roi.mul(mask_from_eroded);
	bitwise_and(input_image,~to_fill,temp);
	GaussianBlur(temp, gaus_blur_big,Size(101,101),55,55); //hole filling alternative

	Mat tester;
	bitwise_and(gaus_blur_big, to_fill,tester);

	namedWindow("To fill",WINDOW_NORMAL);
	imshow("To fill", to_fill);

	namedWindow("temp",WINDOW_NORMAL);
	imshow("temp", temp);

	Mat output;
	add(temp, tester,output);

	namedWindow("Output",WINDOW_NORMAL);
	imshow("Output", output);
	waitKey(100);


	
/*
	Mat inpainted;
        inpaint(temp, to_fill, inpainted,INPAINT_NS);// CV_INPAINT_TELEA);
	namedWindow("inpainted",WINDOW_NORMAL);
	imshow("inpainted", inpainted);
*/

	}
	vector<int> compression_params;       
	compression_params.push_back(CV_IMWRITE_JPEG_QUALITY);
	compression_params.push_back(100);

	try 
	{
	//    imwrite(argv[3],inpainted,compression_params);
    //        imwrite(argv[3],mask,compression_params);
	    std::cout << "Hi wut" << std::endl;
	}
	catch (...) 
	{
	    std::cout << "Some exception occured. Lookout \n"; 
	    return 1;
	}

/*

        output = image.clone();
        mask  = Scalar::all(255) - mask;
        imshow("See",mask);

        Mat inpainted;
        std::cout << "Trying to inpaint \n"; 
        inpaint(image, mask, inpainted, 3, CV_INPAINT_TELEA);
        imshow("inpainted image", inpainted);
        std::cout << "We inpainted \n";  

        imwrite("inpaintedImage.jpg",inpainted);
        waitKey(0);

        output.copyTo(mask, mask);
        blur(mask, blurred,Size(75,75));
        output.copyTo(blurred,mask);
        GaussianBlur(blurred, output, Size(5,5),2.5);
        image.copyTo(output,mask);
        imwrite( "masked_blurred.jpg", output );
//        waitKey(0);
*/
        return 0;
}
