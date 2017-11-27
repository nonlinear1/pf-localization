clc;
clear all;
close all;
rng default;
addpath bin;
addpath helpers;
loadlibrary p2c;

N = 1000; % particle count
input = 'data/board.mp4'; % video file
positionSigma = 15*[1 1 1]; % mm, in XYZ axes
rotationSigma = 0.2*[1 1 1]; % radians, in Euler axes
groundTruth = ggt(input); % ground truth 2d and 3d data
[positionNoise, rotationNoise] = grn(N, positionSigma, rotationSigma);
frameCount = length(groundTruth); % this is how many total frames we have

% Initialization
vr = VideoReader(input);
load('cameraParams.mat');
readFrame(vr); % discard the first frame, it's used for initialization
% tracking (localization) begins in the second frame (post initialization)
z = zeros(frameCount,7); % all estimates of quaternion and translation (means)

System.wp = zeros(N,1); % particle weights
System.xp = zeros(N,1); % particles
System.cameraParams = cameraParams.IntrinsicMatrix;
System.imagePoints = []; % 2D feature locations in the image
System.worldPoints = []; % corresponding 3D world points
System.N = N; % static constant, number of particles
System.F = 0; % updated every frame, number of features found in image

index = 1;
while hasFrame(vr)
    frame = rgb2gray(readFrame(vr));
    frameUndistorted = undistortImage(frame, cameraParams);
    x = groundTruth(index);
    System.F = size(x.WorldPoints,1);
    System.imagePoints = x.ImagePoints;
    System.worldPoints = x.WorldPoints;
    
    if index == 1
        % first frame is for initialization
        q = x.RotationExtrinsics;
        t = x.TranslationExtrinsics;
        [System.xp,System.wp] = createParticles(q,t,N);
    else
        % second frame onward is for tracking (localization)
        updateParticles(System,positionNoise,rotationNoise);
        updateWeights(System,cameraParams);
        resampleParticles(System);
        [q,t] = extractEstimates(System);
    end
    
    disp(num2str(index));
    index = index + 1;
end

% _________________________________________________________________________
% Extratcs the mean of particles as system's estimate.
function [q,t] = extractEstimates(System)
    Qe = mean(System.xp(:,4:7)); % estimated quaternion
    Te = mean(System.xp(:,1:3)); % estimated translation
    [Qp,t] = cameraPoseToExtrinsics(quat2rotm(Qe),Te);
    q = rotm2quat(Qp);
end

% Systematic resmapling of particles.
function resampleParticles(System)
    R = cumsum(System.wp);
    N = size(System.wp,1);
    T = rand(1, N);
    [~, I] = histc(T, R);
    System.xp = System.xp(I + 1, :);
end

% Updates particle weights based on their liklihood (measurement model).
function updateWeights(System,cameraParams)
    N = size(System.wp,1);
    observationPoints = System.imagePoints * 0;
    System.xp(1,1:3)
    System.xp(1,4:7)
    nativeUpdateWeights(System);
    
    for i=1:N
        t = System.xp(i,1:3);
        R = quat2rotm(System.xp(i,4:7));
        [Rx,tx] = cameraPoseToExtrinsics(R,t);
        camMatrix = cameraMatrix(cameraParams,Rx,tx);

        for j=1:System.F
            projection = [System.worldPoints(j,:) 1] * camMatrix;
            projection = projection ./ projection(3);
            observationPoints(j,:) = projection(1:2);
        end
        
        C = cov(observationPoints(:,:));
        D = zeros(System.F,1);
        
        for j=1:System.F
            d = observationPoints(j,:)-System.imagePoints(j,:);
            D(j) = (d/C)*d';
        end
        
        System.wp(i) = (1/(2*pi*sqrt(det(C))))*exp(-sum(D)/2);
    end
    
    System.wp = System.wp ./ sum(System.wp);
end

function nativeUpdateWeights(System)
    System.wp = libpointer('doublePtr',System.wp);
    calllib('p2c','updateWeights_cpu',System);
    System.wp = get(System.wp,'Value');
end

% Adds noise to particles (system model)
function updateParticles(System,posNoise,rotNoise)
    System.xp(:,1:3) = System.xp(:,1:3) + posNoise;
    System.xp(:,4:7) = quatmultiply(System.xp(:,4:7), rotNoise);
end

% Creates the initial particle cloud
function [xp,wp] = createParticles(q0,t0,N)
    xp = ones(N,7);
    xp(:,1) = xp(:,1) * t0(1); % x
    xp(:,2) = xp(:,2) * t0(2); % y
    xp(:,3) = xp(:,3) * t0(3); % z
    xp(:,4) = xp(:,4) * q0(1); % q-r
    xp(:,5) = xp(:,5) * q0(2); % q-i
    xp(:,6) = xp(:,6) * q0(3); % q-j
    xp(:,7) = xp(:,7) * q0(4); % q-k
    wp = ones(N,1) / N;
end