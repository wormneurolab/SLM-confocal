% Acquire a wide field 3D Z stack image while SLM is in the field stop 

% Author: Yao Wang
% Email: wang.yao2@northeastern.edu

clc
close all
clear all


%% Set some critical parameter for z stack imaging
% for a typical wide field z stack imaging, change only parameters in this
% section
CameraExposureTime=0.1;

ObjectiveMag = 60;% choose objective

ZBottom = 1697; % Z stack start z position, unit is um
ZTop = 1723; % Z stack end z position, unit is um
ZStep = 1; % unit is um

SampleName = 'CHB1226';
SampleNum = 'c';  

IntensityInDec = 30; %this is a linear representation of illumination intensity, 100 means max, 1 means min


%% change until here
Date = datetime('now','TimeZone','local','Format','yMMd');

DateChar = string(Date);
ZstepChar = num2str(ZStep*1000);
SampleNumStr = num2str(SampleNum);
IntensityInDecStr = num2str(IntensityInDec);

ImageNameSect1 = strcat(DateChar,'-ZStackWF',SampleName,'-',SampleNumStr); 
ImageNameSect2 = strcat('-Sola',IntensityInDecStr,'-',ZstepChar,'nmZStep');
ImageNameSect3 = '.tif';
ImageName = strcat(ImageNameSect1,ImageNameSect2,ImageNameSect3); % give image a name based on data, sample name, sample number, illumination intensity


workDir = ('E:\Yao\Nikon');
addpath(workDir)

ShowWhiteToMonitor; % make SLM all transmissive for illuminating wide field

%% creat a figure to check every 2D slice
buf1 = zeros(2048,2048); % change according to camera FOV
FigureForCheck = figure('color','k');
CheckhAxes = subplot(1,1,1);
CheckImage = imshow(buf1,[50 20000],'Parent',CheckhAxes,'border','tight');
set(FigureForCheck,'position',[1000,400,1500,1500]); % to maintain the figure size while move it to a new location



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
% buf2 = zeros(width,height);


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

% disp('Sola connected!!!' );
fprintf(Sola,'%s',char([hex2dec('4F') hex2dec('7D') hex2dec('50')])); %turn light output ON

[IntensityFirstHex, IntensitySecondHex]=SetupSola(IntensityInDec);

fprintf(Sola,'%s',char([hex2dec('53') hex2dec('18') hex2dec('03') hex2dec('04') hex2dec(IntensityFirstHex) hex2dec(IntensitySecondHex) hex2dec('50')])); % Set the intensity acccording to 揇AC Intensity Control Command Strings�

%% acquire z stack image from bottom to top
[a, b] = size(ZTopInUnit:-ZStepInUnit:ZBottomInUnit); % find how many z slice for the defined z range
buf3 = zeros(2048,2048,b); % speed up later data storing

for zposition = ZTopInUnit:-ZStepInUnit:ZBottomInUnit
    ti2.ZPosition.Value=ZTopInUnit-(ZOrderNum-1)*ZStepInUnit;
    pause(0.2) % make sure the Z is right
    ti2.ZPosition.Value=ZTopInUnit-(ZOrderNum-1)*ZStepInUnit; % to make sure the movement is good
        [rc] = AT_QueueBuffer(hndl,imagesize);
        [rc] = AT_Command(hndl,'SoftwareTrigger');
        [rc,buf] = AT_WaitBuffer(hndl,1000);
    [rc,buf2] = AT_ConvertMono16ToMatrix(buf,height,width,stride); % convert camera data to uint16 image
    mip = rot90(buf2,-1);
    buf3(:,:,ZOrderNum)=mip;
    ZOrderNum = ZOrderNum+1;
    set(CheckImage,'CData',mip); % refresh the image to a new one
    drawnow
end
close all

% close the illumination
fprintf(Sola,'%s',char([hex2dec('4F') hex2dec('7F') hex2dec('50')])); %turn light output OFF
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

%% save the 3D z stack image
t = Tiff(ImageName,'w');
tagstruct.ImageLength = size(buf3,1);
tagstruct.ImageWidth = size(buf3,2);
% tagstruct.SampleFormat = 1; % uint
tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
tagstruct.BitsPerSample = 16;
tagstruct.SamplesPerPixel = 1;
tagstruct.Compression = Tiff.Compression.None;
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
tagstruct.Software = 'MATLAB'; 
ImageDescription = strcat('Maginification',num2str(ObjectiveMag),'X;','ExposureTime:',num2str(CameraExposureTime),'s;','ZStep:',num2str(abs(ZStep)),'um;','Sola:',num2str(IntensityInDec),'%.');
tagstruct.ImageDescription = ImageDescription;

for ii=1:size(buf3,3)
   setTag(t,tagstruct);
   write(t,buf3(:,:,ii));
   writeDirectory(t);
end
close(t)
