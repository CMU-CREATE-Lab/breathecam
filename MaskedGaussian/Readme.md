##extract, and run
cmake .
make

#cmakelist has -O3 flag for optimiztion

#threshold of 20 used for detecting day or night (max of absolute difference of channel 0 and channel 1. in grayscale , all channels should be same)

#gaussina kernel size(15,15), sigmax=5 and sigmay=5 used

##run as the following

./MaskedGaussian {inputFilename} {inpainted_mask} {gaussian_mask} {outputFilename}

#Masks for all three breathecams in this folder
