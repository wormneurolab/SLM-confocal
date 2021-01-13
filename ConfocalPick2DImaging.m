% SLM-confocal 2D imaging

% Author: Yao Wang
% Email: wang.yao2@northeastern.edu


clc
close all
clear all

%% Set some critical parameter for scanning
CameraExposureTime=0.1;

CaptureIt = 1; % 1 for capture the image, 0 for not 

IntensityInDec = 30; %this is a linear representation of illumination intensity, 100 means max, 1 means min

ZPosition = 0; % keep it 0 if you don't want to go to a specific z position

ObjectiveMag = 60; % you can choose from 2, 10, 20, 40, 60. For 60x, it is a oil immersionobjective

SampleName = 'ThinFilm';
SampleNum = '1'; 

SolaOn = 1; % 1 for Sola on, 0 for Sola off

Date = datetime('now','TimeZone','local','Format','yMMd');
DateChar = string(Date);

SampleNumStr = num2str(SampleNum);
IntensityInDecStr = num2str(IntensityInDec);

ImageNameSect1 = strcat(DateChar,'-2DRawScan-',SampleName,'-',SampleNumStr); % check until here
ImageNameSect2 = strcat('-Sola',IntensityInDecStr);
ImageNameSect3 = '.tif';
ImageName = strcat(ImageNameSect1,ImageNameSect2,ImageNameSect3); % give image a name based on data, sample name, sample number, illumination intensity


ImageNamePicking = ImageName;

Space = 6; % SLM unit cell is 6*6
frameCount = double(Space*Space);

workDir = ('E:\Yao\Nikon');
addpath(workDir)

%% load variables from MAT file
load('MatrixForScan-579-Space6','imageForShow','imageInCameraTemp2'); % the MatrixForScan-579-Space6 is specifically made for our SLM and unit cell 6*6
% the load here is for higher code running speed. 

imageInCameraTemp2 = imageInCameraTemp2;


%% show the first image in the matrix generated
Im=imageForShow(:,:,1); % show the first grid illumination pattern
FigureForShow=figure('color','k');
hAxes = subplot(1,1,1);
set(gcf,'unit','pixel');
set(gcf,'menubar','none');
set(gcf,'NumberTitle','off');
set(gcf,'colormap',gray);
hImage = imshow(Im,'Parent',hAxes,'border','loose');
% hImage = imshow(Im,'Parent',hAxes,'border','tight');
[a b]= size(imageForShow(:,:,1));
truesize([a b]);
pos = get(gcf, 'Position');
% x = pos(1);
% y = pos(2);
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
[rc] = AT_SetEnumString(hndl,'SimplePreAmpGainControl','16-bit (low noise & high well capacity)');
% AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'PixelEncoding','Mono16');
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

ti2.iXPOSITIONSpeed=3;
ti2.iYPOSITIONSpeed=3;
ti2.iZPOSITIONSpeed=3;
 
ti2.iTURRET2SHUTTER=0;
ti2.iTURRET2POS=1;
ti2.iDIA_LAMP_Switch=0;
ti2.iDIA_LAMP_Pos=0;
ti2.iTURRET1SHUTTER=1;
ti2.iTURRET2POS=1;

switch ObjectiveMag
    case 2
        ti2. iNOSEPIECE=6;
    case 10
        ti2. iNOSEPIECE=2;
    case 20
        ti2. iNOSEPIECE=3;
    case 40
        ti2. iNOSEPIECE=1;
    case 60
        ti2. iNOSEPIECE=5;
end

if ZPosition ~= 0
    ti2.ZPosition.Value = ZPosition*100;
    pause(0.01)
    ti2.ZPosition.Value = ZPosition*100;
end

%% Setup Sola illumination
if SolaOn == 1
    Sola = serial('COM4'); %creat the serial COM4 for communicate with light engine

    fopen(Sola); % active this COM port

    fprintf(Sola,'%s',char([hex2dec('57') hex2dec('02') hex2dec('FF') hex2dec('50')]));  % Initialization of light engine
    fprintf(Sola,'%s',char([hex2dec('57') hex2dec('03') hex2dec('FD') hex2dec('50')]));  % Initialization of light engine

    % disp('Sola connected!!!' );
    fprintf(Sola,'%s',char([hex2dec('4F') hex2dec('7D') hex2dec('50')])); %turn light output ON

    [IntensityFirstHex, IntensitySecondHex]=SetupSola(IntensityInDec);

    fprintf(Sola,'%s',char([hex2dec('53') hex2dec('18') hex2dec('03') hex2dec('04') hex2dec(IntensityFirstHex) hex2dec(IntensitySecondHex) hex2dec('50')])); % Set the intensity acccording to Intensity Control Command Strings�
end


%% refreash the image figure in a time series to span the whole FOV while acquiring raw images
buf1 = uint16((zeros(height,width,Space*Space)));
buf2 = uint16(zeros(height,width,Space*Space)); 


tic
    for OrderNum =1:frameCount
        set(hImage,'CData',imageForShow(:,:,OrderNum)); % refresh the image to a new one
        drawnow
        pause(0.01) % make sure the SLM is showing the illumination pattern before camera acquiring, varies for different SLM
        [rc] = AT_QueueBuffer(hndl,imagesize);
        [rc] = AT_Command(hndl,'SoftwareTrigger');
        [rc,buf] = AT_WaitBuffer(hndl,1000);
        [rc,buf1(:,:,OrderNum)] = AT_ConvertMono16ToMatrix(buf,height,width,stride);
    end

%% confocal pick to get a 2D image of sample
buf2 = buf1.*imageInCameraTemp2; % confocal pick those only illuminating point on the sample

close all
AcquireTime = toc

% close the illumination
if SolaOn == 1
    fprintf(Sola,'%s',char([hex2dec('4F') hex2dec('7F') hex2dec('50')])); %turn light output OFF
    fclose(Sola) % disconnect COM4
    clear Sola
end

mip = rot90(max(buf2, [], 3),-1); % rotate for normal image direction

% close system
[rc] = AT_Command(hndl,'AcquisitionStop');
AT_CheckWarning(rc);    
[rc] = AT_Flush(hndl);
[rc] = AT_Close(hndl);
AT_CheckWarning(rc);
[rc] = AT_FinaliseLibrary();
AT_CheckWarning(rc);
disp('Camera shutdown');


%% show and save the 2D confocal pick image
imshow(mip,[])
impixelinfo

if CaptureIt == 1
    imwrite(mip,ImageNamePicking)
end

clear [buf2 buf3 buf4]
