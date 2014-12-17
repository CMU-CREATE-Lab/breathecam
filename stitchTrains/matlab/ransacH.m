function [bestH,bestError,inliers] = ransacH(matches,locs1,locs2,nIter,tol)

%info from http://6.869.csail.mit.edu/fa12/lectures/lecture13ransac/lecture13ransac.pdf

num_good = 0; %number of good points that we use to comp
bestH = 0;    %This and next keep track if H and error in best case
bestError = 0;
inliers = 0;  %number of inliers for our purpose

N = length(matches);
%The following is the initialization of the end results in case all the
%points are shit

%Perform the said number of iterations
for i = 1:nIter
    % create a radom permutation of matches say p =  rand
    p = randperm(N,4); %we need 4 distinct points to solve for H
    points1 = [locs1(p(1),1:2); locs1(p(2),1:2); locs1(p(3),1:2);locs1(p(4),1:2)];  %get one set of points
    points1 = points1'; %we need in 2xN form
    
    points2 = [locs2(p(1),1:2); locs2(p(2),1:2); locs2(p(3),1:2);locs2(p(4),1:2)];  %get the other set of points
    points2 = points2'; %once agin 2xN form
    
    
    %Now find homography using the funtion you have already written
    H2to1       = computeH_norm(points1,points2); 
    
    %check how many of there are good points 
    num_best = 0;
    
    %keep track of the points that work
    inliers_reg  = zeros(N,1);
    
    for i2 =  1:N
        new = H2to1*[locs2(i2,1:2) 1]';
        if norm([locs1(i2,1:2) 1]' - new./new(3))  < tol
            num_best = num_best+1;
            %out point has succeded
            inliers_reg(i2) = 1;
            %keep track of which points are good
        end
    end
    
    %check if this result was better than previous one
    if num_best > num_good
        bestH = H2to1;
        bestError = num_best/N;
        inliers   = inliers_reg;
        %store the better one.
        num_good  = num_best;
    end
end