#include <stdio.h>
#include <opencv2/opencv.hpp>
using namespace cv;

int main(int argc, char** argv )
{
    Mat frame;
    namedWindow("video", 1);
    VideoCapture cap("http://10.5.5.9:8080/live/amba.m3u8");
    while ( cap.isOpened() )
    {
        cap >> frame;
        if(frame.empty()) break;

        imshow("video", frame);
        if(waitKey(30) >= 0) break;
    }
    return 0;
}
