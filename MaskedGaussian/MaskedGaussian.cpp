#include <iostream>
#include <opencv2/opencv.hpp>
#include <iostream>

using namespace cv;
int main(int argc, char** argv )
{
    Mat     image,mask,blurred,clone,output;
    image = imread(argv[1],1);
    mask  = imread(argv[2],0);
    Mat inpainted;
    inpaint(image, mask, inpainted, 30, CV_INPAINT_TELEA);

    vector<int> compression_params;
    compression_params.push_back(CV_IMWRITE_JPEG_QUALITY);
    compression_params.push_back(100);

    try 
    {
        imwrite("inpaintedImage.jpg",inpainted,compression_params);
    }
    catch (...) 
    {
        std::cout << "Some exception occured. Lookout \n"; 
        return 1;
    }

//    imwrite("inpaintedImage.jpg",inpainted,compression_params);
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
