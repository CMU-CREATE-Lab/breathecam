#include <iostream>
#include <fstream>
#include <omp.h>
#include <opencv2/opencv.hpp>
#include "ImageUlti.h"
#include "GCPhase.h"
#include "Ulti.h"


double LensHomo(double *Homography, double *HPhase, double *VPhase, double &hmp, double &vmp, int width, int height, int lcdwidth, int lcdheight)
{
	int ii, jj, mid_x = width/2, mid_y = height/2, range =25*width/1280, step = 10*width/1280;

	hmp = HPhase[mid_x+mid_y*width];
	vmp = VPhase[mid_x+mid_y*width];

	std::vector<Point2f> src;
	std::vector<Point2f> dst;
	for(jj=mid_y-range; jj<mid_y+range+1; jj+=step)
	{
		for(ii=mid_x-range; ii<mid_x+range+1; ii+=step)
		{
			//point in LCD + origin in middle
			Point2f xy; xy.x = HPhase[ii+jj*width] - hmp, xy.y =VPhase[ii+jj*width] - vmp;
			src.push_back(xy);

			//point in captured image + origin in middle
			Point2f uv; uv.x = (1.0*ii - width/2), uv.y = (1.0*jj - height/2);
			dst.push_back(uv);
		}
	}

	//trying to map lcd to camera
	Mat H = findHomography( src, dst,0);

	//Compute error
	for(jj=0; jj<3; jj++)
		for(ii=0; ii<3; ii++)
			Homography[ii+jj*3] = H.at<double>(jj,ii)/H.at<double>(2, 2);

	double wx, wy, u, v, U, V, A, B, C, err = 0;
	for(ii=0; ii<src.size(); ii++)
	{
		wx = src.at(ii).x, wy = src.at(ii).y;
		u = dst.at(ii).x, v = dst.at(ii).y;

		A = Homography[0]*wx+Homography[1]*wy+Homography[2];
		B = Homography[3]*wx+Homography[4]*wy+Homography[5];
		C = Homography[6]*wx+Homography[7]*wy+Homography[8];

		U = A/C, V = B/C;
		err += (U - u)*(U - u) + (V - v)*(V - v) ;
	}

	return err;
}

void PhaseRange(CPoint2 *PhaseRangeH, CPoint2 *PhaseRangeV, double *HPhase, double *VPhase, CPoint2 &Hrange, CPoint2 &Vrange, int width, int height, int npartitions = 50)
{
	int ii, jj, mm, nn;
	double hmax, hmin, vmax, vmin;
	double subwx = 1.0*width/npartitions;
	double subwy = 1.0*height/npartitions;

	Hrange.x = 0.0, Hrange.y = 999.9;
	Vrange.x = 0.0, Vrange.y = 999.9;

	for(jj=0; jj<npartitions; jj++)
	{
		for(ii=0; ii<npartitions; ii++)
		{
			hmax = 0.0, hmin = 1.0*width, vmax = 0.0, vmin = 1.0*height;
			for(mm=(int)(subwy*jj); mm<=(int)(subwy*(jj+1)); mm++)
			{
				for(nn=(int)(subwx*ii); nn<=(int)(subwx*(ii +1)); nn++)
				{
					if(mm >height-1 || nn>width-1)
						continue;
					if(abs(HPhase[nn+mm*width] - 1000.0f)>0.1) //only choose points in projected regions
					{
						if(HPhase[nn+mm*width] > hmax)
							hmax = HPhase[nn+mm*width];
						if(HPhase[nn+mm*width] < hmin)
							hmin = HPhase[nn+mm*width];
					}
					if(abs(VPhase[nn+mm*width] - 1000.0f)>0.1) //only choose points in projected regions
					{
						if(VPhase[nn+mm*width] > vmax)
							vmax = VPhase[nn+mm*width];
						if(VPhase[nn+mm*width] < vmin)
							vmin = VPhase[nn+mm*width];
					}
				}
			}
			PhaseRangeH[ii+jj*npartitions].x = hmax;
			PhaseRangeH[ii+jj*npartitions].y = hmin;
			PhaseRangeV[ii+jj*npartitions].x = vmax;
			PhaseRangeV[ii+jj*npartitions].y = vmin;

			if(Hrange.x <hmax)
				Hrange.x = hmax;
			if(Hrange.y > hmin)
				Hrange.y = hmin;
			if(Vrange.x <vmax)
				Vrange.x = vmax;
			if(Vrange.y >vmin)
				Vrange.y = vmin;
		}
	}
	return;
}
void LCDtoIM(CPoint2 lcdpt, CPoint2 &impt, CPoint2 *PhaseRangeH, CPoint2 *PhaseRangeV, CPoint2 &Hrange, CPoint2 &Vrange, double *HPhase, double *VPhase, int LF1, int LF2, int width, int height, int lcdwidth, int lcdheight, int npartitions = 50 )
{
	int ii, jj;
	double hp = lcdpt.x /lcdwidth*LF1, vp = lcdpt.y /lcdheight*LF2;

	//Super coarse:
	if(hp< Hrange.y || hp >Hrange.x || vp < Vrange.y || vp > Vrange.x) //out of captured image range
	{
		impt.x = -1.0; impt.y = -1.0;
		return;
	}	

	//Coarse:
	bool breakF = false;
	for(jj=0; jj<npartitions; jj++)
	{
		for(ii=0; ii<npartitions; ii++)
		{
			if(abs(PhaseRangeH[ii+jj*npartitions].x-1000.f)<0.1 || abs(PhaseRangeV[ii+jj*npartitions].x-1000.f)<0.1) //failture cause
			{
				impt.x = -1.0, impt.y = -1.0; 
				return;
			}
			if(PhaseRangeH[ii+jj*npartitions].x >= hp && PhaseRangeH[ii+jj*npartitions].y <= hp && PhaseRangeV[ii+jj*npartitions].x >= vp && PhaseRangeV[ii+jj*npartitions].y <= vp)
			{
				breakF = true;
				break;
			}
		}
		if(breakF)
			break;
	}

	if(jj == npartitions && ii == jj) //no good. Nothing found
	{
		impt.x = -1.0, impt.y = -1.0; 
		return;
	}

	//A better coarse:
	int i0, j0;
	double f1, f2, t2, t1 = 1e16;
	double subwx = 1.0*width/npartitions, subwy = 1.0*height/npartitions;
	double cenWinx = (0.5+ii)*subwx, cenWiny = (0.5+jj)*subwy;

	for(jj=int(cenWiny-subwy/2-.5); jj<int(cenWiny+subwy/2+0.5); jj++)
	{
		for(ii=int(cenWinx-subwx/2-.5); ii<int(cenWinx+subwx/2+0.5); ii++)
		{
			f1 = HPhase[jj*width+ii];
			f2 = VPhase[jj*width+ii];

			t2 = (f1-hp)*(f1-hp)+(f2-vp)*(f2-vp);
			if(t2<t1)
			{
				t1 = t2;
				i0 = ii;
				j0 = jj;
			}
		}
	}

	if(i0<1 || i0>width-2 || j0<1 || j0>height-2 || t1 > 1.0) //Discard those at the boundary & t1 is greater than the threshold
	{
		impt.x = -1.0, impt.y = -1.0;
		return;
	}

	//Fine: 
	double A[27], B[9];
	//Ax+By+C = hp
	int pcount = 0;
	for(jj=-1; jj<=1; jj++)
	{
		for(ii=-1; ii<=1; ii++)
		{
			A[3*pcount+0]=ii, A[3*pcount+1]=jj, A[3*pcount+2]=1.0;
			B[pcount] = HPhase[(j0+jj)*width+i0+ii];
			pcount++;
		}
	}
	QR_Solution_Double(A, B, 9, 3);
	double a = B[0], b = B[1], c = B[2];

	//ax+by+c = vp
	pcount = 0;
	for(jj=-1; jj<=1; jj++)
	{
		for(ii=-1; ii<=1; ii++)
		{
			A[3*pcount+0]=ii, A[3*pcount+1]=jj, A[3*pcount+2]=1.0;
			B[pcount] = VPhase[(j0+jj)*width+i0+ii];
			pcount++;
		}
	}
	QR_Solution_Double(A, B, 9, 3);
	double aa = B[0], bb = B[1],	cc = B[2];

	//Solve Ax+By+C = hp, ax+by+c = vp
	A[0] = a, A[1] = b, A[2] = aa, A[3] = bb, B[0] = hp-c, B[1] = vp-cc;
	QR_Solution_Double(A, B, 2, 2);

	impt.x = i0+B[0];
	impt.y = j0+B[1];

	return;
}
void NonParametricLensCalib_LUT(char *PATH, int width, int height, int lcdwidth, int lcdheight, int *frequency1, int *frequency2, int nfrequency, int sstep, int LFstep, int hFilter, int m_mask, int npartitions = 10, double magnified = 2.0, double scale = 3.0)
{
	//magnified: change the image size, scale: zoom in
	char Fname[1024];
	int ii, jj, kk, length = width*height, LF1 = frequency1[nfrequency-1], LF2 = frequency2[nfrequency-1], nimages = (sstep*(nfrequency-1)+LFstep);

	double *VPhaseUW = new double[length];
	double *HPhaseUW = new double[length];
	IplImage* Image = 0;

	//Compute dense correspondences between captured image and LCD image
	int LoadPhase = 0;
	sprintf(Fname, "%s/UWh.dat", PATH); 
	if(ReadGridBinary(Fname, HPhaseUW, width, height, true))
		LoadPhase += 1;

	sprintf(Fname, "%s/UWv.dat", PATH); 
	if(ReadGridBinary(Fname, VPhaseUW, width, height, true))
		LoadPhase += 1;

	if(LoadPhase <2)
	{
		char *AllImage = new char [length*nimages];
		char *PBM = new char[length*nfrequency];
		for(kk=0; kk<2; kk++)
		{
			for(ii=0; ii<nimages; ii++)
			{
				if(kk==0)
					sprintf(Fname, "%s/(%d).jpg", PATH, ii+1+nimages);  
				else
					sprintf(Fname, "%s/(%d).jpg", PATH, ii+1); 
				Image = cvLoadImage(Fname, CV_LOAD_IMAGE_GRAYSCALE   );
				//cvShowImage("X", Image), cvWaitKey(-1);
				//cout<<"3"<<endl;
				for(jj=0; jj<length; jj++)
					AllImage[jj+ii*length] = Image->imageData[jj];
					
				cvReleaseImage(&Image);	
			}

			if(kk==0)
			{
				DecodePhaseShift2(AllImage, PBM, HPhaseUW, width, height, frequency1, nfrequency, sstep, LFstep, hFilter, m_mask);

				//Manually added to remove the effect of uncover LCD
				for(jj=0; jj<30; jj++)
					for(ii=0; ii<30; ii++)
						HPhaseUW[ii+jj*width] = 1000.0;
				for(jj=height-60; jj<height; jj++)
					for(ii=0; ii<60; ii++)
						HPhaseUW[ii+jj*width] = 1000.0;
				for(jj=0; jj<30; jj++)
					for(ii=width-30; ii<width; ii++)
						HPhaseUW[ii+jj*width] = 1000.0;
				for(jj=height-60; jj<height; jj++)
					for(ii=width-60; ii<width; ii++)

				sprintf(Fname, "%s/UWh.dat", PATH, ii+1);
				WriteGridBinary(Fname, HPhaseUW, width, height, true);
			}
			else
			{
				DecodePhaseShift2(AllImage, PBM, VPhaseUW, width, height, frequency2, nfrequency, sstep, LFstep, hFilter, m_mask);

				//Manually added to remove the effect of uncover LCD
				for(jj=0; jj<30; jj++)
					for(ii=0; ii<30; ii++)
						VPhaseUW[ii+jj*width] = 1000.0;
				for(jj=height-60; jj<height; jj++)
					for(ii=0; ii<60; ii++)
						VPhaseUW[ii+jj*width] = 1000.0;
				for(jj=0; jj<30; jj++)
					for(ii=width-30; ii<width; ii++)
						VPhaseUW[ii+jj*width] = 1000.0;
				for(jj=height-60; jj<height; jj++)
					for(ii=width-60; ii<width; ii++)
						VPhaseUW[ii+jj*width] = 1000.0;

				sprintf(Fname, "%s/UWv.dat", PATH, ii+1);
				WriteGridBinary(Fname, VPhaseUW, width, height, true);
			}
		}
		delete []PBM;
		delete []AllImage;
	}
	printf("Finish computing phase\n");

	//Compute Homography
	double Homography[9], iHomography[9], hmp, vmp;
	double err = LensHomo(Homography, HPhaseUW, VPhaseUW, hmp, vmp, width, height, lcdwidth, lcdheight);
	if(err > 1.0)
		printf("Caution! Homography is not accurate\n");
	Homography[0] /= 2.0; Homography[4] /= 2.0;
	mat_invert(Homography, iHomography);

	//Divide the Phase map to many small region so that searching is faster
	CPoint2 Hrange, Vrange;
	CPoint2 *PhaseRangeH = new CPoint2[npartitions*npartitions];
	CPoint2 *PhaseRangeV = new CPoint2[npartitions*npartitions];
	PhaseRange(PhaseRangeH, PhaseRangeV, HPhaseUW, VPhaseUW, Hrange, Vrange, width, height, npartitions);
	printf("Finish estimating phase range\n");

	//Create LUT map
	int Zwidth = (int)(magnified*width), Zheight = (int)(magnified*height), Zlength = Zwidth*Zheight, hZwidth = Zwidth/2, hZheight = Zheight/2;
	float *LUTLensx = new float[Zlength];
	float *LUTLensy = new float[Zlength];

	omp_set_num_threads(omp_get_max_threads());
#pragma omp parallel 
	{
#pragma omp for nowait
		for(int jj=0; jj<Zheight; jj++)
		{
			for(int ii=0; ii<Zwidth; ii++)
			{
				double ptx, pty, t;
				CPoint2 lcdpt, impt;
				ptx = (1.0*ii-hZwidth)/scale, pty = (1.0*jj-hZheight)/scale;// normalize
				t = iHomography[6]*ptx+iHomography[7]*pty+iHomography[8];
				lcdpt.x = (iHomography[0]*ptx+iHomography[1]*pty+iHomography[2])/t;
				lcdpt.y = (iHomography[3]*ptx+iHomography[4]*pty+iHomography[5])/t;

				lcdpt.x = (lcdpt.x + hmp)/LF1*lcdwidth;
				lcdpt.y = (lcdpt.y + vmp)/LF2*lcdheight;
				LCDtoIM(lcdpt, impt, PhaseRangeH, PhaseRangeV, Hrange, Vrange, HPhaseUW, VPhaseUW, LF1, LF2, width, height, lcdwidth, lcdheight, npartitions);

				LUTLensx[ii+jj*Zwidth] = impt.x, LUTLensy[ii+jj*Zwidth] = impt.y;
			}
		}
	}
	printf("Finish computing LUT... writing it down.\n");

	sprintf(Fname, "%s/LUTx.dat", PATH);	WriteGridBinary(Fname, LUTLensx, Zwidth, Zheight);
	sprintf(Fname, "%s/LUTy.dat", PATH);	WriteGridBinary(Fname, LUTLensy, Zwidth, Zheight);

	delete []PhaseRangeH;
	delete []PhaseRangeV;
	delete []HPhaseUW;
	delete []VPhaseUW;

	return;
}
void NonParametricLensUndistort(char *Image, float *LUTx, float *LUTy, int width, int height, int nchannels, double magnified, int nimages = 1, int interpolation_algorithm = 5)
{
	int ii, jj, kk, ll, length = width*height, Zwidth = (int)(magnified*width), Zheight = (int) (magnified*height), Zlength = Zwidth*Zheight;

	double u, v, S[6];
	double *Para = new double[length*nchannels];

	for(kk=0; kk<nimages; kk++)
	{
		for(ll=0; ll<nchannels; ll++)
			Generate_Para_Spline(Image+(ll+kk*nchannels)*length, Para+ll*length, width, height, interpolation_algorithm);

		for(jj=0; jj<Zheight; jj++)
		{
			for(ii=0; ii<Zwidth; ii++)
			{
				u = LUTx[ii+jj*Zwidth];
				v = LUTy[ii+jj*Zwidth];

				if(u < 0 ||u > width-1 || v < 0 || v > height-1)
					for(ll=0; ll<nchannels; ll++)
						Image[ii+jj*Zwidth+(ll+kk*nchannels)*Zlength] = 0;
				else
				{
					for(ll=0; ll<nchannels; ll++)
					{
						Get_Value_Spline(Para+ll*length, width, height,u, v, S, -1, interpolation_algorithm);
						if(S[0] < 0.0)
							S[0] = 0.0;
						else if(S[0] > 255.0)
							S[0] = 255.0;

						Image[ii+jj*Zwidth+(ll+kk*nchannels)*Zlength]  = (char)((int)(S[0]+0.5));
					}
				}
			}
		}
	}

	delete []Para;

	return;
}
//Be careful to the manually cropped corners to remove the effect of uncover LCD
void NonParametricLensUndistortDriver(int nchannels = 3, double magnified = 2.0, double scale = 1.8)
{
	char PATH[] = "/home/vamshi/Desktop/semester2/breathecam/breathecam/calibMinhVo/labNo_NameGoProImages", Fname[200];
	int ii, jj, kk, width = 4000, height = 3000, length = width*height, lcdwidth = 3600, lcdheight = 2160, npartitions = max(height/20, width/20); //assuming each window is of size 10x10
	int frequency1[] = {1, 2, 6, 18, 90}, frequency2[] = {1, 2, 6, 18, 54}, nfrequency = 5, sstep = 6, LFstep = 10, hFilter = 0, mMask = 5; 

	int Zwidth = (int)(magnified*width), Zheight = (int)(magnified*height), Zlength = Zwidth*Zheight;

	float *LUTx = new float[Zlength];
	float *LUTy = new float[Zlength];
	sprintf(Fname, "%s/LUTx.txt", PATH);
	int LoadLUT = 0;
	sprintf(Fname, "%s/LUTx.dat", PATH); 
	if(ReadGridBinary(Fname, LUTx, Zwidth, Zheight, true))
		LoadLUT += 1;

	sprintf(Fname, "%s/LUTy.dat", PATH); 
	if(ReadGridBinary(Fname, LUTy, Zwidth, Zheight, true))
		LoadLUT += 1;

	if(LoadLUT<2)
	{
		NonParametricLensCalib_LUT(PATH, width, height, lcdwidth, lcdheight, frequency1, frequency2, nfrequency, sstep, LFstep, hFilter, mMask, npartitions, magnified, scale);

		sprintf(Fname, "%s/LUTx.dat", PATH); 
		ReadGridBinary(Fname, LUTx, Zwidth, Zheight, true);

		sprintf(Fname, "%s/LUTy.dat", PATH); 
		ReadGridBinary(Fname, LUTy, Zwidth, Zheight, true);
	}

	sprintf(Fname, "%s/train.jpg", PATH);
	IplImage* Image = cvLoadImage(Fname, nchannels == 1?0:1);
	char *IM = new char[Zlength*nchannels];
	for(kk=0; kk<nchannels; kk++)
		for(jj=0; jj<height; jj++)
			for(ii=0; ii<width; ii++)
				IM[ii+jj*width+kk*length] = Image->imageData[nchannels*ii+kk+jj*nchannels*width];

	NonParametricLensUndistort(IM, LUTx, LUTy, width, height, nchannels, magnified, 1, 5);

	sprintf(Fname, "%s/UndistortTest.jpg", PATH);
	SaveDataToImage(Fname, IM, Zwidth, Zheight, nchannels);

	delete []IM;
	delete []LUTx;
	delete []LUTy;
	cvReleaseImage(&Image);

	return;
}
int main(int argc, char* argv[])
{
	if(true)
	{
		NonParametricLensUndistortDriver(3, 2.0, 1.8);
	}
	else
	{
		//23"
		//int frequency1[] = {1, 2, 4, 20, 100}, frequency2[] = {1, 2, 4, 12, 60};
		//ProjectPhaseShift(1800, 1080, 0, 0, 1.0, frequency1, frequency2, 5, 6, 8, 500, true, "");

		//30"
		//int frequency1[] = {1, 2, 4, 20, 100}, frequency2[] = {1, 2, 6, 16, 64};
		//ProjectPhaseShift(2500, 1600, 0, 0, 1.0, frequency1, frequency2, 5, 6, 8, 500, true, "");

		//4K
		int frequency1[] = {1, 2, 6, 18, 90}, frequency2[] = {1, 2, 6, 18, 54};
		ProjectPhaseShift(3600, 2160, 2560, 0, 1.0, frequency1, frequency2, 5, 6, 8, 10000, true, "");

		//*************//
		//phase shift wavelength. typically 6 or 8. must be at least 6. The number of necessary gray code patterns depends on the pattern resolution. 
		//N slides can encode 2^N stripes. if eg 800 pixels are to be encoded and the stripe width is 4, we need 200 stripes, so 8 slides are enough. 
		//mind that the gray code stripe width is half the wavelength of the phase shift patterns.
		//Eg: stripewidth = wavelength/2, stripes = resx/stripewidth.......find nGCSlides such that  2^(nGCSlides) > stripes
		//const int resx = 3600, resy = 2160, wavelength = 40, nshiftstep = 8, nGCSlides = 8; 
		//DisplayGC_PS_Images(resx, resy, 2560, 0, wavelength, nshiftstep, nGCSlides, 500);
		//DisplayGC_PS_Images();
	}
	return 0;
}
