#include <iostream>
#include <opencv2/opencv.hpp>
#include <iostream>
#include <string>
#include <stdio.h>
#define LIGHT_THRESHOLD 170

using namespace cv;
int main(int argc, char** argv )
{
	Mat mask, original;
	mask  = imread("three_mask.jpg", CV_LOAD_IMAGE_COLOR) < 128;
	original = imread("test/a3.jpg", CV_LOAD_IMAGE_COLOR); 

	Mat input_cutmask = original.mul((mask/255));

	std::cout << "original.size " << original.size() << std::endl;
	std::cout << "original.channels " << original.channels() << std::endl;
	std::cout << "mask.depth " << mask.depth() << std::endl; //0 8 bit unsigned
	std::cout << "original.depth " << original.depth() << std::endl; //0 8 bit unsigned

	int max_pixel_hole = 33;  

	Mat mask_f;
	mask.convertTo(mask_f, CV_32F, 1/255.0); //convert to float, sclat approproately
	
//	namedWindow("float mask",WINDOW_NORMAL);
//	imshow("float mask",mask_f);
//	waitKey(0);

//	std::cout << " mask norm f " << mask_f.depth() << std::endl;

	Mat dest_mask= mask_f.clone();  //Initial destination mask.

	Mat input_cutmask_f;
	input_cutmask.convertTo(input_cutmask_f, CV_32F, 1/255.0); //convert to float


//	std::cout << "Input Cut mask is " << input_cutmask_f.depth() <<std::endl;
  	
	Mat blurred_image_f;     //gaussina of the origianl-windows
	blurred_image_f = input_cutmask_f.clone()*0;
 
	Mat blurred_mask_f;       // gaussian of the alpha channel matrix
	blurred_mask_f = mask_f.clone()*0;

	Mat output_mask_f = blurred_mask_f.clone();   //output_mask_f image
	output_mask_f = output_mask_f*0;



	for (int sigma = 2; sigma < max_pixel_hole; sigma *= 2) 
	{
		std::cout << " sigma value is " << sigma  << std::endl;
		GaussianBlur(input_cutmask_f, blurred_image_f,Size(3*sigma+1,3*sigma+1),sigma,sigma);
		std::cout << "blurred image_type  " <<  blurred_image_f.depth() << std::endl;


	//	namedWindow("blurred image",WINDOW_NORMAL);
	//	imshow("blurred image", blurred_image_f);
	//	waitKey(0);
		

	//	namedWindow("mask f",WINDOW_NORMAL);
	//	imshow("mask f", mask_f);
	//	waitKey(0);

		GaussianBlur(mask_f, blurred_mask_f,Size(3*sigma+1,3*sigma+1),sigma,sigma);
		std::cout << " blurred mask type " <<  blurred_mask_f.depth() << " and out put type " <<  output_mask_f.depth() <<  std::endl;

	//	namedWindow("blurred mask",WINDOW_NORMAL);
	//	imshow("blurred mask", blurred_mask_f);
	//	waitKey(0);

		imwrite("blurred_mask.jpg", blurred_mask_f*255);
//		std::cout << "out put size is " << output_mask_f.channels() << " and blur image is  " << blurred_image_f.channels()  << " blurred mask size " << blurred_mask_f.channels()  << "  and destination mat size " << dest_mask.channels() << std::endl;

		namedWindow("dest mask",WINDOW_NORMAL);
		imshow("dest mask", dest_mask);
		waitKey(0);

		Mat divided;
		divide(Scalar(1.0,1.0,1.0) -dest_mask , blurred_mask_f,divided);

	 	Mat onenes = blurred_mask_f.clone()*0+1;

		output_mask_f = output_mask_f + blurred_image_f.mul(min(onenes, divided));
//		output_mask_f = output_mask_f + blurred_image_f.mul(min(blurred_mask_f, Scalar(1.0,1.0,1.0) -dest_mask));

	//	namedWindow("1-dest mask",WINDOW_NORMAL);
	//	imshow("1-dest mask", Scalar(1.0,1.0,1.0)-dest_mask);
	//	waitKey(0);

		dest_mask+= min(blurred_mask_f,Scalar(1.0,1.0,1.0)-dest_mask); 
	//	namedWindow("output_mask_f",WINDOW_NORMAL);
	//	imshow("output_mask_f",output_mask_f);
	//	waitKey(0);
	}
	imwrite("dest_mask.jpg",dest_mask*255);
	Mat output = input_cutmask_f.clone()*0;
	add(input_cutmask_f, output_mask_f, output);
	namedWindow("output final",WINDOW_NORMAL);
	imshow("output final",output);
	waitKey(0);
	imwrite("output_final.jpg",output*255);
	

return  0;
}


/*


	Mat     input_image,roi;//,output_mask_f;

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

	Mat output_mask_f;
	add(temp, tester,output_mask_f);

	namedWindow("Output",WINDOW_NORMAL);
	imshow("Output", output_mask_f);
	waitKey(100);


	

	Mat inpainted;
        inpaint(temp, to_fill, inpainted,INPAINT_NS);// CV_INPAINT_TELEA);
	namedWindow("inpainted",WINDOW_NORMAL);
	imshow("inpainted", inpainted);


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

        return 0;
}
*/
