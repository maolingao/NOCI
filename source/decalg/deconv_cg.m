function [cg_dI,errs,tDeconv,rerrs] = deconv_cg(F,im,nature,iter,start,tol,eta,option)
% conjugate gradient

startup;

a = 1e-30; % ensure pos-def

if nargin < 4
    iter = 100;
end
if nargin < 5
    start = F'*im;
%    start = F'*(F*(F'*im));
%    start = start./sum(start(:)); % nfactor
end
if nargin < 6
    tol = 10^-6;
end
if nargin < 7
    eta = 0;
end
if nargin < 8
    option.figPath = '/is/ei/mgao/figure2drag';
end

b = F'*im;
imageSize = size(b);
%##### Tikhonov #####
l = [0 -1 0
     -1 4 -1
     0 -1 0]; % laplacian matrix WORK! 
L = conv2MatOp(l,imageSize,'same');
% eta = 0.01;

%##### setup #####
x            =   start;
r            =   (F'*(F*x) + eta*((L*x)) + a*x) - b;
p            =   -r(:);
epsl         =   1e-30; % numerical stable % ***********************************************
errs         =   nan(1,iter);
rerrs        =   nan(1,iter);
errRelChange =   nan;
time         =   1e-2;

%##### iteration #####
for i = 1: (iter + 1)  %numel(im)
    cg_dI    =   reshape(x,imageSize);
    % -----------------------------------------------
    % if solving f, regularize kernel f
    kernelSize = min(F.xsize, F.fsize);
    if unique(abs(kernelSize - size(cg_dI)) > abs(max(F.xsize, F.fsize) - size(cg_dI)))
        NOP;                                    % current solving x, BOP    
    else
%         cg_dI   =   lowerBound(cg_dI);          % current solving f, low bound f
%         cg_dI   =   preserveNorm(cg_dI);        % preserve energy norm of f
    end
    % -----------------------------------------------
    % residual error
%         im_residual = F'*(F * cg_dI) - F'*im; % cg_dIdepad - nature; % 
    im_residual     =   betterMinus(F * cg_dI, im); % cg_dIdepad - nature; % 
    % -----------------------------------------------
    % crop away edges
    corpMarginSize  =   kernelSize;
    Pim             =   patimat('same',size(im_residual),corpMarginSize,0);
    im_residual     =   Pim'*im_residual;
    % -----------------------------------------------
    % register images r.t. ground truth 
    fixed       =   nature;                            % r.t. ground truth
    moving      =   cg_dI;
    subpixel    =   0.1;
    [cg_dI_reg, output]     =   efficient_imregister(fixed, moving, subpixel);
    % -----------------------------------------------
    % absolute error
    errorabso = cg_dI_reg - nature;
    if unique(abs(kernelSize - size(cg_dI)) > abs(max(F.xsize, F.fsize) - size(cg_dI)))
        errorabso   =   Pim'*errorabso;        % current solving x, crop    
        natureCrop  =   Pim'*nature;
    else
        errorabso   =   errorabso;             % current solving f, NOT crop
        natureCrop  =   nature;
    end
    % -----------------------------------------------
    % average residual & relative error of ground truth
    if norm(im_residual ,'fro')==0
        errs(i)     =   1e-20;
        rerrs(i)    =   1e-20;
    else
        errs(i)     =   (norm(im_residual,'fro') / numel(im_residual)); % average, absolute residual
        rerrs(i)    =   (norm(errorabso,'fro')   / norm(natureCrop,'fro')); % relative error ||x - hat(x)|| / ||x||
    end
    % -----------------------------------------------
    % plot 
    f3 = figure(3); subplot(121)
    imagesc(clip(cg_dI,1,0)); axis image, colormap(gray)
    title(sprintf('cg - iteration %d/%d',i,iter + 1))
    drawnow
    subplot(122)
    hData   = loglog(errs, 'Color', mpg);
    hYLabel = ylabel('$\|Fx - y\| / pixel$', 'Interpreter','Latex');
    hXLabel = xlabel('$\#steps$', 'Interpreter','Latex');
    thisFigure;   
    drawnow
    % -----------------------------------------------
    % stop creterien 1 : solution found
    if norm(im_residual,'fro') < numel(im_residual)*tol
        disp('==> solution found!')
        cg_dI = clip(cg_dI,1,0);
        break
    else
    % -----------------------------------------------
    % stop creterien 2 : error decreasing tiny or even increasing
        if i > 3
            errRelChange    =   errs(2:i) - errs(1:i-1);
            errRelChange    =   sum(errRelChange(i-3:i-1)) / sum(errs(i-3:i)) * 4/3 ;
        end
    % -----------------------------------------------
    % stop creterien 3 : iteration number reached        
        if i == (iter + 1) || errRelChange > -1e-3
            cg_dI   =   clip(reshape(x,imageSize),1,0);
            break
        end
    % -----------------------------------------------
    % main calculation
        tStart = tic; 
        % ###################
        q       =   (F'*(F*(reshape(p,imageSize))) + eta*((L*(reshape(p,imageSize)))) + a*reshape(p,imageSize)); % A*p register
        
        alpha   =   ((p'*q(:)) + epsl)\(r(:)'*r(:));
        
        x       =   x(:) + alpha*p;
        r_1     =   r;
        r       =   r_1 + alpha*q;
        beta    =   ((r_1(:)'*r_1(:)) + epsl)\(r(:)'*r(:));
        p_1     =   p;
        p       =   -r(:) + beta*p_1;
        % ###################
        tElapsed =  toc(tStart);
        time     =  [time; time(end) + tElapsed];
    % -----------------------------------------------
    % display orthogonality and conjugacy 
    % conjugate
        conj = p_1'*vec((F'*(F*reshape(p,imageSize))) + eta*(L*(reshape(p,imageSize))) + a*reshape(p,imageSize))
    end
    
end
tDeconv = time(end);


%##### figure #####
%----- main curves -----
errs    =   errs(~isnan(errs));
rerrs   =   rerrs(~isnan(rerrs));
if option.plotFlag == 1
color = mpg;
% for debug
fclk = figure(14); set(fclk,'visible','on'),
subplot(121), hData = loglog(time ,errs,'Color',color); thisFigure; hold on
subplot(122), hData = loglog(time,rerrs,'Color',color); thisFigure; hold on
fstp = figure(15); set(fstp,'visible','on'),
subplot(121), hData = loglog( errs,'Color',color); thisFigure; hold on
subplot(122), hData = loglog(rerrs,'Color',color); thisFigure; hold on
% for latex
f10=figure(10); set(f10,'visible','off');
hData = loglog(time, errs,'Color',color); 
axis tight; thisFigure; hold on
f12=figure(12); set(f12,'visible','off');
hData = loglog(time,rerrs,'Color',color); 
axis tight; thisFigure; hold on
f11=figure(11); set(f11,'visible','off');
hData = loglog(errs, 'Color',color); 
set(gca,'Yscale','log'), axis tight; thisFigure; hold on 
f13=figure(13); set(f13,'visible','off');
hData = loglog(rerrs,'Color',color); 
set(gca,'Yscale','log'), axis tight; thisFigure; hold on 
end
%
%----- image evolution and residual curve -----
figPath = option.figPath;
%
f3 = figure(3); set(f3,'visible','on')
filename = 'deconv_cg_with_curve';
filename = fullfile(figPath,filename);
print(gcf, '-depsc2', filename)
% keyboard
%----- cg deconved image -----
f_cg = figure; set(f_cg,'visible','off');
imagesc(clip(cg_dI,1,0)); axis image off, colormap(gray)
title('cg')
filename = 'deconv_cg';
filename = fullfile(figPath,filename);
print(gcf, '-depsc2', filename)
close gcf
end