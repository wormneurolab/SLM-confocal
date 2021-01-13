% This code can be used for multiply purpose
% 1. live image of sample and choose to save the image or not
% 2. Align the Spatial light modulator to make sure it is in the right
% position and rotation
% 3. If you use laser to shoot you sample, this code can generate a laser
% spot on screen for easy shooting
% Author: Yao Wang
% Email: wang.yao@northeastern.edu

clc
close all
clear all

workDir = ('E:\Yao\Nikon');
addpath(workDir)
cd('E:\Yao\Nikon')

%% set camera parameters
CameraExposureTime=0.1;
ImageLowLimitForShow = 80; % For better image visulization

AlignMode = 1; % 1 for SLM alignment, 0 for real imaging

LaserMode = 0; % 1 for Laser use, 0 for SLM alignment and real imaging

LaserPosX = 1031; % need it only when LaserMode = 1
LaserPosY = 1143; % need it only when LaserMode = 1

if AlignMode == 1
    ImageUpLimitForShow = 10000;   % for contrast showing 
    CaptureIt = 0; % 1 for capture the image, 0 for not 
    SolaIntensity = 10; % 0-100 linear intensity representation of illumination intensity
    ObjectiveMag = 20; % you can choose from 2, 10, 20, 40, 60. For 60x, it is a oil immersion objective
end

if AlignMode == 0
    ImageUpLimitForShow = 2000; % for contrast showing 
    CaptureIt = 1; % 1 for capture the image, 0 for not 
    SolaIntensity = 20; % 0-100 linear intensity representation of illumination intensity
    ObjectiveMag =60; % you can choose from 2, 10, 20, 40, 60. For 60x, it is a oil immersionobjective
end

ImageName = '20201006-Grid-BPAE-3-Space3-Sola80.tif'; 
SolaOn = 1; % 1 for Sola on, 0 for Sola off

% %% Creat white background for illumination
% WhiteBackGround = ones(750,750);
% BackGoundFigure = figure('color','k');
% WhiteBackImage = subplot(1,1,1);
% CheckImage = imshow(WhiteBackGround,'Parent',WhiteBackImage,'border','loose');
% set(BackGoundFigure,'position',[3969,0,768,800]); % to maintain the figure size while move it to a new location

ShowOutlineToMonitor; % use this showed figure for SLM alignment only
ShowWhiteToMonitor; % use this showed figure for laser shooting and wide field image

%% initialize camera
disp('Andor SDK3 Live Mode Example');
[rc] = AT_InitialiseLibrary();
AT_CheckError(rc);
[rc,hndl] = AT_Open(0);
AT_CheckError(rc);
disp('Camera initialized');
[rc] = AT_SetFloat(hndl,'ExposureTime',CameraExposureTime);
AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'CycleMode','Continuous');
AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'TriggerMode','Software');
AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'SimplePreAmpGainControl','16-bit (low noise & high well capacity)'); % 12-bit (low noise) or 16-bit (low noise & high well capacity)
AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'PixelEncoding','Mono16');
AT_CheckWarning(rc);
[rc] = AT_SetBool(hndl,'SpuriousNoiseFilter',1);  % 0 for no noise filter, 1 for with noise filter
% AT_CheckWarning(rc);
[rc,imagesize] = AT_GetInt(hndl,'ImageSizeBytes');
AT_CheckWarning(rc);
[rc,height] = AT_GetInt(hndl,'AOIHeight');
AT_CheckWarning(rc);
[rc,width] = AT_GetInt(hndl,'AOIWidth');
AT_CheckWarning(rc);
[rc,stride] = AT_GetInt(hndl,'AOIStride'); 
AT_CheckWarning(rc);
% warndlg('To Abort the acquisition close the image display.','Starting Acquisition')    
disp('Starting acquisition...');
[rc] = AT_Command(hndl,'AcquisitionStart');
AT_CheckWarning(rc);


buf1 = zeros(width,height,'gpuArray'); % for faster imaging use gpu to store and process data
figure % creat a window for live imaging
h=imshow(buf1,[ImageLowLimitForShow ImageUpLimitForShow]); 
impixelinfo
set(gcf,'position',[600,50,2000,2000])


%% Setup Nikon microscope
addpath('C:\Program Files\Nikon\Ti2-SDK\bin'); % microscope SDK location
addpath('E:\Yao\Nikon\ScanningPattern'); % scanning pattern location
addpath('E:\Yao\Nikon\AndorSDK3'); % Camera SDK location
!regsvr32 /s NkTi2Ax.dll;
% global ti2;
ti2 = actxserver('Nikon.Ti2.AutoConnectMicroscope');
        
xposition=get(ti2,'iXPOSITION');
yposition=get(ti2,'iYPOSITION');
zposition=get(ti2,'iZPOSITION');

ti2.iXPOSITIONSpeed=3;
ti2.iYPOSITIONSpeed=3;
ti2.iZPOSITIONSpeed=3;

ti2.iLIGHTPATH=4;
 
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

%% Setup Sola illumination
% we use a Lumencor Sola light engine for illumination
if SolaOn == 1
    IntensityinDec = SolaIntensity; %this is a linear representation of intensity, 100 means max, 1 means min
    DepthOfIntensity = 256;
    Intensityin256 = floor((IntensityinDec/100)*DepthOfIntensity);
    Intensityin256Inv = 256 - Intensityin256;
    Intensityin256InvHEX = dec2hex(Intensityin256Inv);
    IntensityFirstDigit = sscanf(Intensityin256InvHEX(1), '%s');
    IntensitySecondDigit = sscanf(Intensityin256InvHEX(2), '%s');
    IntensityFirstHex = strcat('F',IntensityFirstDigit);
    IntensitySecondHex = strcat(IntensitySecondDigit,'0');

    Sola = serial('COM4'); %creat the serial COM4 for communicate with light engine

    fopen(Sola); % active this COM port

    fprintf(Sola,'%s',char([hex2dec('57') hex2dec('02') hex2dec('FF') hex2dec('50')]));  % Initialization of light engine
    fprintf(Sola,'%s',char([hex2dec('57') hex2dec('03') hex2dec('FD') hex2dec('50')]));  % Initialization of light engine

    % disp('Sola connected!!!' );
    fprintf(Sola,'%s',char([hex2dec('4F') hex2dec('7D') hex2dec('50')])); %turn light output ON
    fprintf(Sola,'%s',char([hex2dec('53') hex2dec('18') hex2dec('03') hex2dec('04') hex2dec(IntensityFirstHex) hex2dec(IntensitySecondHex) hex2dec('50')])); % Set the intensity acccording to Intensity Control Command Strings�
end
 
%% align the SLM or image the sample   
if LaserMode == 0
    while(ishandle(h))
        [rc] = AT_QueueBuffer(hndl,imagesize);
        AT_CheckWarning(rc);
        [rc] = AT_Command(hndl,'SoftwareTrigger');
        AT_CheckWarning(rc);
        [rc,buf] = AT_WaitBuffer(hndl,1000);
        [rc,buf2] = AT_ConvertMono16ToMatrix(buf,height,width,stride); % convert data from camera to uint16 image
        set(h,'CData',rot90(buf2,-1)); % rotate the image for a normal view
        hold on;
        line([100 1948],[1023 1023]); % we creat a cross for align the SLM
        line([100 1948],[1026 1026]);
        line([1023 1023],[100 1948]);
        line([1026 1026],[100 1948]);
        hold off
        drawnow;
    end
end

if LaserMode == 1
    while(ishandle(h))
        [rc] = AT_QueueBuffer(hndl,imagesize);
        AT_CheckWarning(rc);
        [rc] = AT_Command(hndl,'SoftwareTrigger');
        AT_CheckWarning(rc);
        [rc,buf] = AT_WaitBuffer(hndl,1000);
        [rc,buf2] = AT_ConvertMono16ToMatrix(buf,height,width,stride); % convert data from camera to uint16 image
        set(h,'CData',rot90(buf2,-1)); % rotate the image for a normal view
        hold on;
        line([LaserPosX-13 LaserPosX+13],[LaserPosY LaserPosY]); % draw the location of laser spot
        line([LaserPosX LaserPosX],[LaserPosY-13 LaserPosY+13]); % draw the location of laser spot
        hold off
        drawnow;
    end
end
close all


% close the illumination
if SolaOn == 1 
    fprintf(Sola,'%s',char([hex2dec('4F') hex2dec('7F') hex2dec('50')])); %turn light output OFF
    fclose(Sola) % disconnect COM4
    clear Sola
end

% save the 2D image
if CaptureIt == 1
    imwrite(rot90(buf2,-1),ImageName);
end

% close system
disp('Acquisition complete');
[rc] = AT_Command(hndl,'AcquisitionStop');
AT_CheckWarning(rc);         
[rc] = AT_Close(hndl);
AT_CheckWarning(rc);
[rc] = AT_FinaliseLibrary();
AT_CheckWarning(rc);
disp('Camera shutdown');


