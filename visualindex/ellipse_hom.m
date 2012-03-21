function H= ellipse_hom( x1, y1, a1, b1, c1, x2, y2, a2, b2, c2 )
% To compute the homography which maps ellipse 1 (specified by x1, y1, a1, b1, c1) into ellipse 2 (specified by x2, y2, a2, b2, c2)
% call
% H= hom( x1, y1, a1, b1, c1, x2, y2, a2, b2, c2 )
% 
% The "direction" of the homography is such that applying it to ellipse 1 you get ellipse 2, for example [x2;y2;1]= H * [x1;x2;1]
% 
% I don't know if you know about homographies etc, in case you do this might be useful (a small test you can run to see the code computes a correct transformation):
% 
% % centre of ellipse 1:
% x1=2; y1=7; p1=[x1;y1];
% 
% % shape of ellipse 1:
% a1=3; b1= 0.5; c1= 1; C1=[a1, b1; b1, c1];
% 
% % affine transformation which preserves verticality
% A=[3,0;0.5,1];
% 
% % transform the centre of ellipse 1:
% p2= A*p1;
% 
% % transform the shape of ellipse 1:
% C2= inv(A')*C1*inv(A);
% 
% % compute the homography:
% H=hom( x1, y1, a1, b1, c1, p2(1), p2(2), C2(1,1), C2(1,2), C2(2,2) )
% 
% The result should be:
% H =
%    3     0   0
%    0.5  1   0
%    0     0   1
% 
% I.e. exactly the same as A


    [ma1, mb1, mc1]= choles( a1, b1, c1 );
    [ma2, mb2, mc2]= choles( a2, b2, c2 );
    [ma2i, mb2i, mc2i]= lowerTriInv( ma2, mb2, mc2 );
    
    a= ma1*ma2i;
    c= mc1*mc2i;
    b= ma1*mb2i + mb1*mc2i;
    
    tx= x2-a*x1;
    ty= y2-b*x1-c*y1;
    
    H= [a, 0, tx; b, c, ty; 0, 0, 1];
    
end


function [at, bt, ct]= choles( a, b, c )
    ct= sqrt(c);
    bt= b/ct;
    at= sqrt(a-bt*bt);
end


function [at, bt, ct]= lowerTriInv( a, b, c)
    invdet = 1.0/(a*c);
    at=  c*invdet;
    bt= -b*invdet;
    ct=  a*invdet;
end