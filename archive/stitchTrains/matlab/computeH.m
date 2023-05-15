function H2to1 = computeH(p1,p2)
%we want to compute least squared homography for two sets of points 
%here p1 and p2 represent 2xN matrices of both the sets
%use min eigen vector of A'A matrix (see notes written in question paper)
p1_temp = p1';
p2_temp = p2';
%did transpose because easier column operations
N       = length(p1);
row0    = zeros(N,3); %rwo vector with three zeros

if length(p1) ~= length(p2)
%essentially I am doing nothing   
else
A = [p2_temp ones(N,1) row0      -p1_temp(:,1).*p2_temp(:,1) -p1_temp(:,1).*p2_temp(:,2) -p1_temp(:,1) ;...
     row0    p2_temp   ones(N,1) -p1_temp(:,2).*p2_temp(:,1) -p1_temp(:,2).*p2_temp(:,2) -p1_temp(:,2)];
%see question paper for this. we are making a linear system essentially
[v,~]  = eig(A'*A);
%find out the eigen vector with the least eigen values, which will be th
%first column here
H2to1  = v(:,1);
H2to1  = (reshape(H2to1./H2to1(end),[3,3]))';
%reshape it to a 3x3 matrix after scaling the last term
end