function H2to1 = computeH_norm(p1,p2)

% Note that each set of points are to be in a 2xN form. i.e 2 rows and a bunch of columns
points = [p1;p2];
N      = length(points);
%section 2 in http://lyle.smu.edu/~prangara/ICIP09_Homography.PDF
newpoints = zeros(size(points));

average = mean(points,2);
% test    = mean([p1 p2]);
 
s1 = sum(sqrt( (points(1,:)-average(1)).^2 + (points(2,:)-average(2)).^2 ));
s2 = sum(sqrt( (points(3,:)-average(3)).^2 + (points(4,:)-average(4)).^2 ));

s1=s1/(sqrt(2)*N);
s2=s2/(sqrt(2)*N);

%tranform the coordinate system to stables numbers system
T1 = [1/s1  0  -average(1)/s1 ; 0 1/s1 -average(2)/s1 ; 0 0 1];
T2 = [1/s2  0  -average(3)/s2 ; 0 1/s2 -average(4)/s2 ; 0 0 1];

Z = zeros(2,2);

for i = 1:N
    newpoints(:,i) = [T1(1:2,1:2)  Z;Z T2(1:2,1:2)]*points(:,i) + [T1(1:2,3);T2(1:2,3)];
end

%we now have the coordinates in the numerically stable way we want.We can
%just pass on the previous compute H funtion here

H2to1 = computeH(newpoints(1:2,:),newpoints(3:4,:));
H2to1 = (T1\H2to1)*T2;



