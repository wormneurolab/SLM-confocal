% Show an outline and a cross to the SLM

% Author: Yao Wang
% Email: wang.yao2@northeastern.edu


%% Creat original picture
Width = 579; % Match to the camera FOV, how many pixels in width
Height = Width; % Match to the camera FOV, how many pixels in height
Image = zeros(Height,Width);


if mod(Width,2) == 1
    %% Matrix for outline
    A=1;
    B=Width;
    C=(Width+1)/2;


    %% Generate Outline
    Image(A,:) = 255;
    Image(B,:) = 255;
    Image(:,A) = 255;
    Image(:,B) = 255;
    Image(C,:) = 255;
    Image(:,C) = 255;
    Image(50:53,200:203)=255; %generate a dot for rotation reference
    Image(300:303,400:403)=255;  %generate a dot for rotation reference

    %% show and save pictures
    Im=Image;
    Im2=fliplr(Image);
    Im2=rot90(Im2);  
    imshow(Im2) %this Im2 is to see how the final image like from camera
    FigureForShow=figure('color','k');
    hAxes = subplot(1,1,1);
    set(gcf,'unit','pixel');
    set(gcf,'menubar','none');
    set(gcf,'NumberTitle','off');
    set(gcf,'colormap',gray);
    imshow(Im,'Parent',hAxes,'border','loose');
    [a b]= size(Image);
    truesize([a b]);
    pos = get(gcf, 'Position');
    x=3979;  % set the location of the outline picture showing
    y=53;  % set the location of the outline picture showing
    WidthOfFig = pos(3);
    HeightOfFig = pos(4);
    set(gcf,'position',[x,y,WidthOfFig,HeightOfFig]); % to maintain the figure size while move it to a new location
    
end

if mod(Width,2) == 0
    %% Matrix for outline
    A=1;
    B=Width;
    C=Width/2;
    D=Width/2+1;


    %% Generate Outline
    Image(A,:) = 255;
    Image(B,:) = 255;
    Image(:,A) = 255;
    Image(:,B) = 255;
    Image(C,:) = 255;
    Image(:,C) = 255;
    Image(D,:) = 255;
    Image(:,D) = 255;
    Image(50:53,200:203)=255;
    Image(300:303,400:403)=255;  %generate a dot for rotation reference

    %% show and save pictures
    Im=Image;
    Im2=fliplr(Image);
    Im2=rot90(Im2);  
    imshow(Im2) %this Im2 is to see how the final image like from camera
    FigureForShow=figure('color','k');
    hAxes = subplot(1,1,1);
    set(gcf,'unit','pixel');
    set(gcf,'menubar','none');
    set(gcf,'NumberTitle','off');
    set(gcf,'colormap',gray);
    imshow(Im,'Parent',hAxes,'border','loose');
    [a b]= size(Image);
    truesize([a b]);
    pos = get(gcf, 'Position');
    x=3979; % set the location of the outline picture showing
    y=53; % set the location of the outline picture showing
    WidthOfFig = pos(3);
    HeightOfFig = pos(4);
    set(gcf,'position',[x,y,WidthOfFig,HeightOfFig]); % to maintain the figure size while move it to a new location
    
end
