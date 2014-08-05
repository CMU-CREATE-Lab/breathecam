#include <iostream>
#include <opencv2/opencv.hpp>

using namespace cv;
int main(int argc, char** argv )
{
    Mat     image,mask,blurred,clone,output;
    image = imread(argv[1],1);
    mask  = imread(argv[2],0);

    if ( !image.data | !mask.data)
    {
        std::cout << ("No image data in one of arguments\n");
        return -1;
    }
    else
    {
        output = image.clone();
        mask  = Scalar::all(255) - mask;
        output.copyTo(mask, mask);
        blur(mask, blurred,Size(75,75));
        output.copyTo(blurred,mask);
        GaussianBlur(blurred, output, Size(5,5),2.5);
        image.copyTo(output,mask);
        imwrite( "masked_blurred.jpg", output );
        waitKey(0);
        return 0;
    }
}
