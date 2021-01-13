% this code acquires both SLM-confocal pick 3D image and SLM-MaxProjection
% images
% you can also choose whether to save all the scanned raw images or not

% Author: Yao Wang
% Email: wang.yao2@northeastern.edu


clc
close all
clear all


%% Set some critical parameter for scanning
% for a typical SLM-confocal z stack imaging, change only parameters in this
% section

CameraExposureTime=0.1;

ZBottom = 1697; % Z stack start z position, unit is um
ZTop = 1723; % Z stack end z position, unit is um
ZStep = 1; % unit is um

SampleName = 'CHB1226';
SampleNum = 'c';  

IntensityInDec = 80; %this is a linear representation of illumination intensity, 100 means max, 1 means min

KeepRawData = 0; % If want to keep all the scanning raw data, use 1. If not, use 0.

%% change until here
Date = datetime('now','TimeZone','local','Format','yMMd');

DateChar = string(Date);
ZstepChar = num2str(ZStep*1000);
SampleNumStr = num2str(SampleNum);
IntensityInDecStr = num2str(IntensityInDec);

ImageNameSect1 = strcat(DateChar,'-3DRawScan',SampleName,'-',SampleNumStr); % check until here
ImageNameSect2 = strcat('-Sola',IntensityInDecStr,'-',ZstepChar,'nmZStep');
ImageNameSect3 = '.tif';
ImageName = strcat(ImageNameSect1,ImageNameSect2,ImageNameSect3);

Space = 6; % when SLM unit cell is 6*6

workDir = ('E:\Yao\Nikon');
addpath(workDir)

%% load variables from MAT file
load('MatrixForScan-579-Space6','imageForShow','imageInCameraTemp2'); % the MatrixForScan-579-Space6 is specifically made for our SLM and unit cell 6*6


%% show the first image in the matrix generated
Im=imageForShow(:,:,1); % show the first grid illumination pattern
FigureForShow=figure('color','k');
hAxes = subplot(1,1,1);
set(gcf,'unit','pixel');
set(gcf,'menubar','none');
set(gcf,'NumberTitle','off');
set(gcf,'colormap',gray);
hImage = imshow(Im,'Parent',hAxes,'border','loose');
[a, b]= size(imageForShow(:,:,1));
truesize([a b]);
pos = get(gcf, 'Position');
x=3979;  % set the location of the outline picture showing
y=53;  % set the location of the outline picture showing
WidthOfFig = pos(3);
HeightOfFig = pos(4);
set(FigureForShow,'position',[x,y,WidthOfFig,HeightOfFig]); % to maintain the figure size while move it to a new location

clear width
clear height

%% intialize the camera
% disp('Andor SDK3 Live Mode Example');
[rc] = AT_InitialiseLibrary();
% AT_CheckError(rc);
[rc,hndl] = AT_Open(0);
AT_CheckError(rc);
% disp('Camera initialized');
[rc] = AT_SetFloat(hndl,'ExposureTime',CameraExposureTime);
% AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'CycleMode','Continuous');
% AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'TriggerMode','Software');
% AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'SimplePreAmpGainControl','16-bit (low noise & high well capacity)'); % 12-bit (low noise) or 16-bit (low noise & high well capacity)
% AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'PixelEncoding','Mono16');
% AT_CheckWarning(rc);
[rc] = AT_SetBool(hndl,'SpuriousNoiseFilter',1);  % 0 for no noise filter, 1 for with noise filter
% AT_CheckWarning(rc);
[rc,imagesize] = AT_GetInt(hndl,'ImageSizeBytes');
% AT_CheckWarning(rc);
[rc,height] = AT_GetInt(hndl,'AOIHeight');
% AT_CheckWarning(rc);
[rc,width] = AT_GetInt(hndl,'AOIWidth');
% AT_CheckWarning(rc);
[rc,stride] = AT_GetInt(hndl,'AOIStride'); 
% AT_CheckWarning(rc);
[rc] = AT_Command(hndl,'AcquisitionStart');
% AT_CheckWarning(rc);


%% creat a figure to check every 2D slice
buf1 = zeros(width,height);
FigureForCheck = figure('color','k');
CheckhAxes = subplot(1,1,1);
CheckImage = imshow(buf1,[50 2000],'Parent',CheckhAxes,'border','tight');
set(FigureForCheck,'position',[1200,400,1500,1500]); % to maintain the figure size while move it to a new location


%% Setup Nikon microscope
addpath('C:\Program Files\Nikon\Ti2-SDK\bin'); % microscope SDK location
addpath('E:\Yao\Nikon\ScanningPattern'); % scanning pattern location
addpath('E:\Yao\Nikon\AndorSDK3'); % Camera SDK location
!regsvr32 /s NkTi2Ax.dll;
global ti2;
ti2 = actxserver('Nikon.Ti2.AutoConnectMicroscope');
        
xposition=get(ti2,'iXPOSITION');
yposition=get(ti2,'iYPOSITION');
zposition=get(ti2,'iZPOSITION');
% 
ti2.iXPOSITIONSpeed=3;
ti2.iYPOSITIONSpeed=3;
ti2.iZPOSITIONSpeed=3;
%  
ti2.iTURRET2SHUTTER=0;
ti2.iTURRET2POS=1;
ti2.iDIA_LAMP_Switch=0;
ti2.iDIA_LAMP_Pos=0;
ti2.iTURRET1SHUTTER=1;
ti2.iTURRET1POS=1;


%% setup the bottom and top layer z coordinates
ZBottomInUnit = ZBottom*100;
ZTopInUnit = ZTop*100;
ZStepInUnit = ZStep*100;

ti2.ZPosition.Value=ZBottomInUnit;
pause(0.5)
ti2.ZPosition.Value=ZBottomInUnit; % to make sure the movement is good
zposition=get(ti2,'iZPOSITION');
ZOrderNum = 1;

%% setup Sola illumination
Sola = serial('COM4'); %creat the serial COM4 for communicate with light engine

fopen(Sola); % active this COM port

fprintf(Sola,'%s',char([hex2dec('57') hex2dec('02') hex2dec('FF') hex2dec('50')]));  % Initialization of light engine
fprintf(Sola,'%s',char([hex2dec('57') hex2dec('03') hex2dec('FD') hex2dec('50')]));  % Initialization of light engine
[IntensityFirstHex, IntensitySecondHex]=SetupSola(IntensityInDec);

disp('Sola connected!!!' );


%% acquire z stack image from bottom to top
buf2 = uint16(zeros(height,width,Space*Space));

ConfocalImageRaw = uint16(zeros(height,width,Space*Space));

ZOrder = 1;
ZInitial = ZBottom*100; % this is in 10nm unit
ZEnd = ZTop*100; % this is in 10nm unit
ZStepInName = ZStep*100;  % this is in 10nm unit
ZTotal = uint8((ZEnd - ZInitial)/ZStepInName + 1);

ConfocalImage2DSlice = uint16(zeros(2048,2048,ZTotal));
buf3 = uint16(zeros(2048,2048,ZTotal));

for zposition = ZTopInUnit:-ZStepInUnit:ZBottomInUnit
    tic
    ti2.ZPosition.Value=ZTopInUnit-(ZOrderNum-1)*ZStepInUnit;
    pause(0.1)  % make sure the microscope stage is stable
    ti2.ZPosition.Value=ZTopInUnit-(ZOrderNum-1)*ZStepInUnit; % to make sure the z movement is good
    
    fprintf(Sola,'%s',char([hex2dec('4F') hex2dec('7D') hex2dec('50')])); %turn light output ON, we don't turn it on before to prevent photobleach
    fprintf(Sola,'%s',char([hex2dec('53') hex2dec('18') hex2dec('03') hex2dec('04') hex2dec(IntensityFirstHex) hex2dec(IntensitySecondHex) hex2dec('50')])); % Set the intensity acccording to Intensity Control Command Strings�

    if  KeepRawData == 1  % this will keep all scanned raw data
        for OrderNum = 1:Space*Space
            set(hImage,'CData',imageForShow(:,:,OrderNum)); % refresh the image to a new one
            drawnow
            pause(0.01) % make sure the SLM is showing the illumination pattern before camera acquiring, varies for different SLM
            [rc] = AT_QueueBuffer(hndl,imagesize);
            [rc] = AT_Command(hndl,'SoftwareTrigger');
            [rc,buf] = AT_WaitBuffer(hndl,1000);
            [rc,buf2(:,:,OrderNum)] = AT_ConvertMono16ToMatrix(buf,height,width,stride);      
        end
        
        ConfocalImageRaw = buf2.*imageInCameraTemp2;% pickup those only illuminating point on the sample
        
        fprintf(Sola,'%s',char([hex2dec('4F') hex2dec('7F') hex2dec('50')])); %turn light output OFF

        ConfocalImage2DSlice(:,:,ZOrder) = max(ConfocalImageRaw, [], 3);
        ZOrder = ZOrder+1;

        % save all the scanned raw images
        zpositionChar = num2str(zposition);
        buf3Rotated = gather(rot90(buf2,-1));
        PlaneImageName = strcat(ImageNameSect1,ImageNameSect2,'-Z',zpositionChar,ImageNameSect3);
        PlaneImage = Tiff(PlaneImageName,'w');
        tagstruct.ImageLength = size(buf3Rotated,1);
        tagstruct.ImageWidth = size(buf3Rotated,2);
        % tagstruct.SampleFormat = 1; % uint
        tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
        tagstruct.BitsPerSample = 16;
        tagstruct.SamplesPerPixel = 1;
        tagstruct.Compression = Tiff.Compression.None;
        tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
        tagstruct.Software = 'MATLAB'; 
        ImageDescription = strcat('ExposureTime:',num2str(CameraExposureTime),'s;','ZStep:',num2str(abs(ZStep)),'um;','Sola:',num2str(IntensityInDec),'%.');
        tagstruct.ImageDescription = ImageDescription;

        for ii=1:size(buf3Rotated,3)
           setTag(PlaneImage,tagstruct);
           write(PlaneImage,buf3Rotated(:,:,ii));
           writeDirectory(PlaneImage);
        end
        close(PlaneImage)
        
        mip = gather(rot90(max(buf2, [], 3),-1));
        buf3(:,:,ZOrderNum)=mip;
        set(CheckImage,'CData',mip); % refresh the image to a new one
        drawnow       
    end

    if  KeepRawData == 0  % this will discard scanned raw data but keep only confocal picked image
        for OrderNum = 1:Space*Space
            set(hImage,'CData',imageForShow(:,:,OrderNum)); % refresh the image to a new one
            drawnow
            pause(0.01) % make sure the SLM is showing the illumination pattern before camera acquiring
            [rc] = AT_QueueBuffer(hndl,imagesize);
            [rc] = AT_Command(hndl,'SoftwareTrigger');
            [rc,buf] = AT_WaitBuffer(hndl,1000);
            [rc,buf2(:,:,OrderNum)] = AT_ConvertMono16ToMatrix(buf,height,width,stride);     
        end

        ConfocalImageRaw=buf2.*imageInCameraTemp2;% pickup those only illuminating point on the sample
        
        fprintf(Sola,'%s',char([hex2dec('4F') hex2dec('7F') hex2dec('50')])); %turn illumination output OFF
        
        ConfocalImage2DSlice(:,:,ZOrder) = max(ConfocalImageRaw, [], 3); % produce confocal picked 2D slice
        mip = gather(rot90(ConfocalImage2DSlice(:,:,ZOrder),-1)); % rotate the 2D slice for normal view
        set(CheckImage,'CData',mip); % refresh the image to a new one 
        drawnow   
        
        mipOfMaxProjection = gather(rot90(max(buf2, [], 3),-1)); % make SLM-MaxProjection image
        buf3(:,:,ZOrderNum)=mipOfMaxProjection;

        ZOrder = ZOrder+1;  
    end    
    
    ZOrderNum = ZOrderNum+1;
    
    
    OneSlicePeriod = toc
    SlidesLeft = (ti2.ZPosition.Value-ZBottomInUnit)/(ZStepInUnit);
    TimeLeft = num2str(SlidesLeft*OneSlicePeriod+5);
    TimeLeft=strcat('About ',TimeLeft,' seconds left until finish');
    disp(TimeLeft)
end

close all

fclose(Sola) % disconnect COM4
clear Sola

% close system
[rc] = AT_Command(hndl,'AcquisitionStop');
AT_CheckWarning(rc);         
[rc] = AT_Close(hndl);
AT_CheckWarning(rc);
[rc] = AT_FinaliseLibrary();
AT_CheckWarning(rc);
disp('Camera shutdown');

clear [buf2 buf3 buf4]


%% save the SLM-MaxProjection 3D z stack image
ImageNameMaxProjection = strcat(ImageNameSect1,ImageNameSect2,'-MaxProjection',ImageNameSect3);

t = Tiff(ImageNameMaxProjection,'w');
tagstruct.ImageLength = size(buf3,1);
tagstruct.ImageWidth = size(buf3,2);
% tagstruct.SampleFormat = 1; % uint
tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
tagstruct.BitsPerSample = 16;
tagstruct.SamplesPerPixel = 1;
tagstruct.Compression = Tiff.Compression.None;
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
tagstruct.Software = 'MATLAB'; 
ImageDescription = strcat('ExposureTime:',num2str(CameraExposureTime),'s;','ZStep:',num2str(abs(ZStep)),'um;','Sola:',num2str(IntensityInDec),'%.');
tagstruct.ImageDescription = ImageDescription;

for ii=1:size(buf3,3)
   setTag(t,tagstruct);
   write(t,buf3(:,:,ii));
   writeDirectory(t);
end
close(t)


%% save the SLM-confocal pick 3D z stack image
ConfocalImage2DSlice = gather(rot90(ConfocalImage2DSlice,-1));

ImageNameConfocal = strcat(ImageNameSect1,ImageNameSect2,'-ConfocalPick',ImageNameSect3);

t = Tiff(ImageNameConfocal,'w');
tagstruct.ImageLength = size(ConfocalImage2DSlice,1);
tagstruct.ImageWidth = size(ConfocalImage2DSlice,2);
% tagstruct.SampleFormat = 1; % uint
tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
tagstruct.BitsPerSample = 16;
tagstruct.SamplesPerPixel = 1;
tagstruct.Compression = Tiff.Compression.None;
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
tagstruct.Software = 'MATLAB'; 
ImageDescription = strcat('ExposureTime:',num2str(CameraExposureTime),'s;','ZStep:',num2str(abs(ZStep)),'0nm;','Sola:',num2str(IntensityInDec),'%.');
tagstruct.ImageDescription = ImageDescription;

for ii=1:size(ConfocalImage2DSlice,3)
   setTag(t,tagstruct);
   write(t,ConfocalImage2DSlice(:,:,ii));
   writeDirectory(t);
end
close(t)
