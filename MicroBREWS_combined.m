function [signal_table] = MicroBREWS_combined(whichMovie)
% MicroBREWS_combined('s2') or MicroBREWS_combined('s3')
% - Always processes 34 frames
% - Always saves results
% - Uses S2-style processing for 's2' and S3-style for 's3'

    % ---- Choose movie + parameters based on input ----
    whichMovie = lower(string(whichMovie));

    switch whichMovie
        case "s2"
            imageName      = 'Movie_S2.mov';
            numFrames      = 34;
            useColorSignal = false;   % S2: grayscale signal
            edgeMethod     = '';      % default edge()
            strelRadius    = 5;
            areaThreshold  = 200;
            % S2 ROI polygon
            roiVerticesFun = @(c) [ ...
                c(1)+4,  c(2); ...
                c(1)-9,  c(2); ...
                c(1)-35, c(2)+45; ...
                c(1)+35, c(2)+45];
            
        case "s3"
            imageName      = 'Movie_S3.mov';
            numFrames      = 34;
            useColorSignal = true;    % S3: color-based signal
            edgeMethod     = 'Canny';
            strelRadius    = 8;
            areaThreshold  = 800;
            % S3 ROI polygon
            roiVerticesFun = @(c) [ ...
                c(1)+50, c(2)-25; ...
                c(1)+50, c(2)-55; ...
                c(1),    c(2)-55; ...
                c(1),    c(2)-4];
            
        otherwise
            error('whichMovie must be ''s2'' or ''s3''.');
    end

    % Always save results for this combined version
    should_save = true;

    % ---- Output directories ----
    [~, baseName, ~] = fileparts(imageName);
    outDir = fullfile(pwd, [baseName '_results']);
    roiDir = fullfile(outDir, 'roiFrames');
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    if ~exist(roiDir, 'dir'), mkdir(roiDir); end

    % ---- Video + guard on numFrames ----
    video = VideoReader(imageName);
    maxFrames = min(numFrames, floor(video.NumFrames));

    signal_table = [];

    % ---- Main per-frame loop ----
    for frame_id = 1:maxFrames

        % --- Read & grayscale ---
        v1 = read(video, frame_id);
        if ndims(v1) == 3
            v1_gray = rgb2gray(v1);
        else
            v1_gray = v1;
        end

        % --- Trap mask (different parameters for S2 vs S3) ---
        if isempty(edgeMethod)
            bw = edge(v1_gray);                 % S2 style
        else
            bw = edge(v1_gray, edgeMethod);     % S3 style (Canny)
        end
        bw = imdilate(bw, strel('disk', strelRadius));
        bw = imfill(bw, 'holes');
        bw = bwareaopen(bw, areaThreshold);

        props = regionprops(bw, 'Area', 'Centroid');
        if isempty(props)
            fprintf('Frame %d: no trap detected, skipping.\n', frame_id);
            continue
        end

        % largest component
        [~, k] = max([props.Area]);
        c = props(k).Centroid;
        A = props(k).Area;

        % --- Background-subtracted grayscale (common) ---
        sig_im = im2double(v1_gray);
        bg_gray = mode(sig_im(:));
        sig_im = sig_im - bg_gray;
        sig_im(sig_im < 0) = 0;

        % --- ROI polygon, depends on whichMovie via roiVerticesFun ---
        vertices = roiVerticesFun(c);

        % --- Show frame + ROI polygon (for saving) ---
        fig = figure('Visible','off');
        imshow(sig_im, []); hold on; ax = gca;
        poly = images.roi.Polygon(ax, 'Position', vertices, 'Color', 'r');
        mask = createMask(poly);          % logical MxN

        % --- Signal calculation branch: S2 (gray) vs S3 (color) ---
        if ~useColorSignal
            % S2-style: grayscale signal
            signal = sum(sig_im(mask), 'all');
        else
            % S3-style: color-based ROI signal
            modes = im2double(v1);                % MxNx3 (or MxN)
            if ndims(modes) == 2
                modes = repmat(modes, [1 1 3]);   % ensure MxNx3
            end
            gray_for_bg = rgb2gray(modes);
            bg = mode(gray_for_bg(:));
            modes = modes - bg;
            modes(modes < 0) = 0;

            mask3 = repmat(mask, [1 1 3]);
            mask2 = modes .* mask3;
            signal = sum(mask2(:));
        end

        % --- Append to table ---
        signal_table = [signal_table; frame_id, signal, A, c(1), c(2)];

        % --- Save ROI frame ---
        if should_save
            title(sprintf('%s – frame %d', baseName, frame_id));
            saveas(fig, fullfile(roiDir, sprintf('frame_%03d_roi.png', frame_id)));
        end
        close(fig);

        fprintf('Frame %d (%s): signal=%.4f @ centroid(%.1f, %.1f) area=%d\n', ...
            frame_id, whichMovie, signal, c(1), c(2), A);
    end

    % ---- Save CSV ----
    if should_save && ~isempty(signal_table)
        T = array2table(signal_table, 'VariableNames', ...
            {'frame','signal','area','centroid_x','centroid_y'});
        writetable(T, fullfile(outDir, sprintf('signals_%s.csv', baseName)));
        fprintf('Saved CSV and ROI frames to %s\n', outDir);
    end
end
