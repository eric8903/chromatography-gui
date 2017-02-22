classdef ChromatographyGUI < handle
    
    properties (Constant = true)
        
        name        = 'Chromatography Toolbox';
        url         = 'https://github.com/chemplexity/chromatography-gui';
        version     = '0.0.4';
        date        = '20170222';
        platform    = ChromatographyGUI.getPlatform();
        environment = ChromatographyGUI.getEnvironment();
        
    end
    
    properties
        
        checkpoint
        
        data
        peaks
        
        figure
        menu
        panel
        table
        axes
        controls
        view
        
        preferences
        
    end
    
    properties (Hidden = true)
        
        font = ChromatographyGUI.getFont();
        
    end
    
    methods
        
        function obj = ChromatographyGUI(varargin)
            
            % ---------------------------------------
            % Path
            % ---------------------------------------
            sourceFile = fileparts(mfilename('fullpath'));
            [sourcePath, sourceFile] = fileparts(sourceFile);
            
            if ~strcmpi(sourceFile, '@ChromatographyGUI')
                sourcePath = [sourcePath, filesep, sourceFile];
            end
            
            addpath(sourcePath);
            addpath(genpath([sourcePath, filesep, 'src']));
            
            % ---------------------------------------
            % Defaults
            % ---------------------------------------
            obj.preferences.plot.color         = [0.1, 0.1, 0.1];
            obj.preferences.plot.linewidth     = 1.25;
            
            obj.preferences.baseline.color     = [0.95, 0.22, 0.17];
            obj.preferences.baseline.linewidth = 1.5;
            
            obj.preferences.peaks.color        = [0.00, 0.30, 0.53];
            obj.preferences.peaks.linewidth    = 2.0;
            
            obj.preferences.labels.fontsize    = 11.0;
            obj.preferences.labels.font        = obj.font;
            
            obj.axes.xmode = 'auto';
            obj.axes.ymode = 'auto';
            obj.axes.xlim  = [0.000, 1.000];
            obj.axes.ylim  = [0.000, 1.000];
            
            obj.view.index = 0;
            obj.view.id    = 'N/A';
            obj.view.name  = 'N/A';
            
            obj.view.plot       = [];
            obj.view.baseline   = [];
            obj.view.peak       = [];
            obj.view.label      = [];
            obj.view.showLabel  = 1;
            obj.view.selectZoom = 1;
            obj.view.selectPeak = 0;
            
            obj.table.selection = [];
            
            obj.peaks.name = {...
                'C36'; 'C37';...
                'C37:3 Me'; 'C37:2 Me';...
                'C38:3 Et'; 'C38:2 Et';...
                'C38:3 Me'; 'C38:2 Me';...
                'C39:3 Et'; 'C39:2 Et'};
            
            obj.peaks.time   = {};
            obj.peaks.width  = {};
            obj.peaks.height = {};
            obj.peaks.area   = {};
            obj.peaks.error  = {};
            obj.peaks.fit    = {};
            
            % ---------------------------------------
            % GUI
            % ---------------------------------------
            obj.initializeGUI();
            
        end
        
        function updateFigure(obj, varargin)
            
            if obj.view.index == 0 && ~isempty(obj.data)
                obj.view.index = 1;
                obj.view.id    = '1';
                obj.view.name  = obj.data(1).sample_name;
                
            elseif isempty(obj.data)
                obj.view.index = 0;
                obj.view.id    = 'N/A';
                obj.view.name  = 'N/A';
            end
            
            obj.updateSampleText();
            obj.updatePlot();
            
        end
        
        function updatePlot(obj, varargin)
            
            cla(obj.axes.main);
            
            if isempty(obj.data) || obj.view.index == 0
                return
            else
                row = obj.view.index;
            end
            
            x = obj.data(row).time;
            y = obj.data(row).intensity(:,1);
            
            obj.view.plot = plot(x, y,...
                'parent',    obj.axes.main,...
                'color',     obj.preferences.plot.color,...
                'linewidth', obj.preferences.plot.linewidth,...
                'visible',   'on',...
                'hittest',   'off',...
                'tag',       'main');
            
            zoom reset
            
            obj.updateAxesXLim();
            obj.updateAxesYLim();
            
            if obj.controls.showBaseline.Value
                obj.plotBaseline();
            end
            
            if obj.controls.showPeak.Value
                obj.plotPeaks();
            end
            
        end
        
        function updateAxesXLim(obj, varargin)
            
            switch obj.axes.xmode
                
                case 'auto'
                    
                    if obj.view.index ~= 0
                        xmin = min(obj.data(obj.view.index).time);
                        xmax = max(obj.data(obj.view.index).time);
                    else
                        xmin = 0;
                        xmax = 1;
                    end
                    
                    xmargin = (xmax - xmin) * 0.02;
                    obj.axes.xlim = [xmin - xmargin, xmax + xmargin];
                    
                    set(obj.axes.main, 'xlim', obj.axes.xlim);
                    
                case 'manual'
                    
                    xmin = str2double(obj.controls.xMin.String);
                    xmax = str2double(obj.controls.xMax.String);
                    
                    if xmin ~= round(obj.axes.xlim(2), 3)
                        obj.axes.xlim(1) = xmin;
                        set(obj.axes.main, 'xlim', obj.axes.xlim);
                    end
                    
                    if xmax ~= round(obj.axes.xlim(2), 3)
                        obj.axes.xlim(2) = xmax;
                        set(obj.axes.main, 'xlim', obj.axes.xlim);
                    end
            end
            
            obj.updateAxesLimitEditText();
            
        end
        
        function updateAxesYLim(obj, varargin)
            
            if obj.view.index ~= 0
                x = obj.data(obj.view.index).time;
                y = obj.data(obj.view.index).intensity(:,1);
            else
                x = [];
                y = [];
            end
            
            if isempty(y)
                x = [0, 1];
                y = [0, 1];
            end
            
            switch obj.axes.ymode
                
                case 'auto'
                    
                    y = y(x >= obj.axes.xlim(1) & x <= obj.axes.xlim(2));
                    
                    if any(y)
                        ymargin = (max(y) - min(y)) * 0.02;
                        obj.axes.ylim = [min(y) - ymargin, max(y) + ymargin];
                    end
                    
                case 'manual'
                    
                    ymin = obj.controls.yMin.String;
                    ymax = obj.controls.yMax.String;
                    
                    obj.axes.ylim = [str2double(ymin), str2double(ymax)];
            end
            
            set(obj.axes.main, 'ylim', obj.axes.ylim);
            
            obj.updateAxesLimitEditText();
            
        end
        
        function updateAxesLimitMode(obj, varargin)
            
            if obj.controls.xManual.Value
                obj.axes.xmode = 'manual';
            else
                obj.axes.xmode = 'auto';
            end
            
            if obj.controls.yManual.Value
                obj.axes.ymode = 'manual';
            else
                obj.axes.ymode = 'auto';
            end
            
        end
        
        function updateAxesLimitToggle(obj, varargin)
            
            switch obj.axes.xmode
                case 'manual'
                    obj.controls.xManual.Value = 1;
                    obj.controls.xAuto.Value = 0;
                case 'auto'
                    obj.controls.xManual.Value = 0;
                    obj.controls.xAuto.Value = 1;
            end
            
            switch obj.axes.ymode
                case 'manual'
                    obj.controls.yManual.Value = 1;
                    obj.controls.yAuto.Value = 0;
                case 'auto'
                    obj.controls.yManual.Value = 0;
                    obj.controls.yAuto.Value = 1;
            end
            
        end
        
        function updateAxesLimitEditText(obj, varargin)
            
            str = @(x) sprintf('%.3f', x);
            
            obj.controls.xMin.String = str(obj.axes.xlim(1));
            obj.controls.xMax.String = str(obj.axes.xlim(2));
            obj.controls.yMin.String = str(obj.axes.ylim(1));
            obj.controls.yMax.String = str(obj.axes.ylim(2));
            
        end
        
        function updatePeakEditText(obj, varargin)
            
            str = @(x) sprintf('%.3f', x);
            
            row = obj.view.index;
            col = obj.controls.peakList.Value;
            
            nRow = length(obj.data);
            nCol = length(obj.peaks.name);
            
            if ~isempty(obj.data) && size(obj.peaks.time, 1) < nRow
                
                if ~isempty(obj.peaks.name)
                    obj.peaks.time{nRow, 1}   = [];
                    obj.peaks.width{nRow, 1}  = [];
                    obj.peaks.height{nRow, 1} = [];
                    obj.peaks.area{nRow, 1}   = [];
                    obj.peaks.error{nRow, 1}  = [];
                    obj.peaks.fit{nRow, 1}    = [];
                end
                
            end
            
            if ~isempty(obj.peaks.name) && size(obj.peaks.time, 2) < nCol
                
                if ~isempty(obj.data)
                    obj.peaks.time{1, nCol}   = [];
                    obj.peaks.width{1, nCol}  = [];
                    obj.peaks.height{1, nCol} = [];
                    obj.peaks.area{1, nCol}   = [];
                    obj.peaks.error{1, nCol}  = [];
                    obj.peaks.fit{1, nCol}    = [];
                end
                
            end
            
            if isempty(col) || col == 0
                id     = '';
                time   = '';
                width  = '';
                height = '';
                area   = '';
            elseif col ~= 0 && (row == 0 || isempty(obj.data))
                id     = obj.peaks.name{col};
                time   = '';
                width  = '';
                height = '';
                area   = '';
            else
                id     = obj.peaks.name{col};
                time   = str(obj.peaks.time{row,col});
                width  = str(obj.peaks.width{row,col});
                height = str(obj.peaks.height{row,col});
                area   = str(obj.peaks.area{row,col});
            end
            
            obj.controls.peakIDEdit.String     = id;
            obj.controls.peakTimeEdit.String   = time;
            obj.controls.peakWidthEdit.String  = width;
            obj.controls.peakHeightEdit.String = height;
            obj.controls.peakAreaEdit.String   = area;
            
        end
        
        function plotBaseline(obj)
            
            obj.clearAxesChildren('baseline');
            
            if isempty(obj.data) || obj.view.index == 0
                return
            else
                row = obj.view.index;
            end
            
            if isempty(obj.data(row).baseline)
                obj.getBaseline();
            end
            
            if ~isempty(obj.data(row).baseline)
                
                x = obj.data(row).baseline(:,1);
                y = obj.data(row).baseline(:,2);
                
                obj.view.baseline = plot(x, y,...
                    'parent',    obj.axes.main,...
                    'color',     obj.preferences.baseline.color,...
                    'linewidth', 1.5,...
                    'visible',   'off',...
                    'tag',       'baseline');
                
                if obj.controls.showBaseline.Value
                    obj.view.baseline.Visible = 'on';
                end
                
            end
            
        end
        
        function plotPeaks(obj, varargin)
            
            obj.clearAxesChildren('peak');
            obj.clearAxesChildren('peaklabel');
            
            obj.updateAxesXLim();
            obj.updateAxesYLim();
            
            if isempty(obj.data) || obj.view.index == 0
                return
            elseif ~obj.controls.showPeak.Value || isempty(obj.peaks.fit)
                return
            else
                row = obj.view.index;
            end
            
            if any(~cellfun(@isempty, obj.peaks.fit(row,:)))
                
                for i = 1:length(obj.peaks.fit(row,:))
                    
                    if isempty(obj.peaks.fit{row,i})
                        continue
                    elseif length(obj.peaks.fit{row,i}(1,:)) ~= 2
                        continue
                    end
                    
                    x = obj.peaks.fit{row,i}(:,1);
                    y = obj.peaks.fit{row,i}(:,2);
                    
                    obj.view.peak{i} = plot(x, y,...
                        'parent',    obj.axes.main,...
                        'color',     obj.preferences.peaks.color,...
                        'linewidth', obj.preferences.peaks.linewidth,...
                        'visible',   'on',...
                        'hittest',   'off',...
                        'tag',       'peak');
                    
                    obj.plotPeakLabels(x,y,i);
                    
                end
            end
            
        end
        
        function plotPeakLabels(obj, x, y, i)
            
            if ~obj.view.showLabel
                return
            end
            
            % Text Label
            textStr = obj.peaks.name{i};
            textStr = deblank(strtrim(textStr(textStr ~= '\')));
            textStr = ['\rm ', textStr];
            
            % Text Position
            [~, yi] = max(y);
            
            textX = x(yi);
            textY = y(yi);
            
            % Plot Text
            obj.view.label{i} = text(textX, textY, textStr,...
                'parent',   obj.axes.main,...
                'clipping', 'on',...
                'hittest',  'off',...
                'tag',      'peaklabel',...
                'fontsize', obj.preferences.labels.fontsize,...
                'fontname', obj.preferences.labels.font,...
                'margin',   3,...
                'units',    'data',...
                'pickableparts',       'none',...
                'horizontalalignment', 'center',...
                'verticalalignment',   'bottom',...
                'selectionhighlight',  'off');
            
            if isprop(obj.view.label{i}, 'extent')
                
                textPos = obj.view.label{i}.Extent;
                
                tL = textPos(1);
                tR = textPos(1) + textPos(3);
                tB = textPos(2);
                tT = textPos(2) + textPos(4);
                tW = textPos(3);
                
                axesMain = obj.getAxes();
                
                if ~isempty(axesMain)
                    
                    x = get(axesMain, 'xdata');
                    y = get(axesMain, 'ydata');
                    
                    y = y(x >= tL & x <= tR);
                    x = x(x >= tL & x <= tR);
                    
                    if ~isempty(x)
                        yOverlap = y >= tB & y <= tT;
                    else
                        yOverlap = [];
                    end
                    
                    % Text / Data
                    if ~isempty(yOverlap) && any(yOverlap) && sum(yOverlap)>2
                        
                        x = x(yOverlap);
                        x(abs(x - textX) < 0.05) = [];
                        
                        if ~isempty(x)
                            
                            xmax = max(x);
                            xmin = min(x);
                            
                            if xmax > tL && xmax < textX
                                
                                obj.view.label{i}.Units = 'characters';
                                t = get(obj.view.label{i}, 'extent');
                                
                                xmargin = (tW - ((t(3)-1) * tW) / t(3)) / 4;
                                
                                obj.view.label{i}.Units = 'data';
                                t = obj.view.label{i}.Position;
                                
                                t(1) = t(1) + xmax - tL + xmargin;
                                obj.view.label{i}.Position = t;
                                
                            elseif xmin < tR && xmin > textX
                                
                                obj.view.label{i}.Units = 'characters';
                                t = obj.view.label{i}.Extent;
                                
                                xmargin = (((t(3)+1) * tW) / t(3) - tW) / 4;
                                
                                obj.view.label{i}.Units = 'data';
                                t = obj.view.label{i}.Position;
                                
                                t(1) = t(1) - xmargin;
                                obj.view.label{i}.Position = t;
                                
                            end
                            
                        end
                    end
                end
                
                % Text / Axes Limits
                textPos = obj.view.label{i}.Extent;
                
                tL = textPos(1);
                tR = textPos(1) + textPos(3);
                tT = textPos(2) + textPos(4);
                
                if textX <= obj.axes.xlim(2) && tR >= obj.axes.xlim(2)
                    
                    set(obj.view.label{i}, 'units', 'characters');
                    tc = get(obj.view.label{i}, 'extent');
                    
                    set(obj.view.label{i}, 'units', 'data');
                    td = get(obj.view.label{i}, 'extent');
                    
                    xmargin = td(3) - (td(3) / tc(3)) * (tc(3) - 0.5);
                    obj.axes.xlim(2) = td(1) + td(3) + xmargin;
                    
                    obj.controls.xMax.String = sprintf('%.3f', obj.axes.xlim(2));
                    set(obj.axes.main, 'xlim', obj.axes.xlim);
                    
                end
                
                if textX >= obj.axes.xlim(1) && tL <= obj.axes.xlim(1)
                    
                    set(obj.view.label{i}, 'units', 'characters');
                    tc = get(obj.view.label{i}, 'extent');
                    
                    set(obj.view.label{i}, 'units', 'data');
                    td = get(obj.view.label{i}, 'extent');
                    
                    xmargin = td(3) - (td(3) / tc(3)) * (tc(3) - 0.5);
                    obj.axes.xlim(1) = td(1) - xmargin;
                    
                    obj.controls.xMin.String = sprintf('%.3f', obj.axes.xlim(1));
                    set(obj.axes.main, 'xlim', obj.axes.xlim);
                    
                end
                
                if tT >= obj.axes.ylim(2) && strcmpi(obj.axes.ymode, 'auto')
                    
                    if textX > obj.axes.xlim(1) && textX < obj.axes.xlim(2)
                        
                        set(obj.view.label{i}, 'units', 'characters');
                        tc = get(obj.view.label{i}, 'extent');
                        
                        set(obj.view.label{i}, 'units', 'data');
                        td = get(obj.view.label{i}, 'extent');
                        
                        ymargin = td(4) - (td(4) / tc(4)) * (tc(4) - 0.5);
                        obj.axes.ylim(2) = td(2) + td(4) + ymargin;
                        
                        obj.controls.yMax.String = sprintf('%.3f', obj.axes.ylim(2));
                        set(obj.axes.main, 'ylim', obj.axes.ylim);
                    end
                    
                end
            end
            
        end
        
        function axesMain = getAxes(obj, varargin)
            
            axesLine = obj.axes.main.Children;
            axesMain = [];
            
            if ~isempty(axesLine)
                axesTag = get(axesLine, 'tag');
                
                if ~isempty(axesTag)
                    axesMain = strcmpi(axesTag, 'main');
                    
                    if any(axesMain)
                        axesIndex = find(axesMain == 1, 1);
                        axesMain = axesLine(axesIndex);
                    end
                end
            end
            
        end
        
        function getBaseline(obj, varargin)
            
            row = obj.view.index;
            
            if isempty(obj.data) || row == 0
                return
            elseif isempty(obj.data(row).intensity)
                return
            end
            
            x = obj.data(row).time;
            y = obj.data(row).intensity;
            
            if ~isempty(x)
                y(x < obj.axes.xlim(1) | x > obj.axes.xlim(2)) = [];
                x(x < obj.axes.xlim(1) | x > obj.axes.xlim(2)) = [];
            end

            a = 10 ^ obj.controls.asymSlider.Value;
            s = 10 ^ obj.controls.smoothSlider.Value;
            
            b = baseline(y, 'asymmetry', a, 'smoothness', s);
            
            if length(x) == length(b)
                obj.data(row).baseline = [x, b];
            end
            
        end
        
        function getPeakFit(obj, varargin)
            
            row = obj.view.index;
            col = obj.controls.peakList.Value;
            
            if isempty(obj.data) || isempty(col) || col == 0 || row == 0
                return
            end
            
            if isempty(varargin)
                time  = str2double(obj.controls.peakTimeEdit.String);
            else
                time = varargin{1};
            end
            
            width = diff(obj.axes.xlim) * 0.02;
            
            if isnan(time) || isinf(time)
                time = [];
            end
            
            x = obj.data(row).time;
            y = obj.data(row).intensity(:,1);
            
            if isempty(x) || isempty(y)
                return
            else
                y(x < obj.axes.xlim(1) | x > obj.axes.xlim(2)) = [];
                x(x < obj.axes.xlim(1) | x > obj.axes.xlim(2)) = [];
            end
            
            if time > max(x) || time < min(x)
                return
            end
            
            if isempty(obj.data(row).baseline) || length(obj.data(row).baseline(:,1)) ~= length(y(:,1))
                obj.getBaseline();
            end
            
            b = obj.data(row).baseline;
            
            if ~isempty(b) && length(b(:,1)) == length(y(:,1))
                y = y - b(:,2);
            end
            
            peak = exponentialgaussian(x, y, 'center', time, 'width', width);
            
            if ~isempty(peak) && peak.area ~= 0 && peak.width ~= 0
                
                if ~isempty(peak.fit)
                    
                    y = peak.fit;
                    
                    if length(peak.fit) == length(x)
                        
                        yFilter = peak.fit ~= 0;
                        
                        if any(yFilter)
                            
                            i0 = find(yFilter > 0, 1);
                            
                            if i0 > 1
                                yFilter(i0-1) = 1;
                            end
                            
                            if i0 > 5
                                yFilter(i0-5:i0-2) = 1;
                            end
                            
                            i0 = find(flipud(yFilter) > 0, 1);
                            
                            if ~isempty(i0)
                                i0 = length(yFilter) - i0 + 2;
                                
                                if i0 <= length(yFilter)
                                    yFilter(i0) = 1;
                                end
                                
                                if i0+5 <= length(yFilter)
                                    yFilter(i0:i0+5) = 1;
                                end
                                
                            end
                            
                            x = x(yFilter);
                            y = y(yFilter);
                            b = b(yFilter,2);
                            
                            yCutoff = 1E-5;
                            yFilter = y >= yCutoff;
                            
                            if any(yFilter)
                                x = x(yFilter);
                                y = y(yFilter);
                                b = b(yFilter);
                            end
                            
                            if size(y,1) == size(b,1)
                                y = y + b;
                            end
                            
                        end
                        
                        if peak.width > 0
                            
                            xCutoff = peak.width * 2.5;
                            xFilter = x > peak.time+xCutoff | x < peak.time-xCutoff;
                            
                            if any(xFilter)
                                x(xFilter) = [];
                                y(xFilter) = [];
                            end
                            
                            if ~isempty(x) && ~isempty(y) && length(x) == length(y)
                                peak.fit = [x,y];
                            end
                            
                        end
                        
                    end
                end
            end
            
            if ~isempty(peak) && peak.area ~= 0 && peak.width ~= 0
                obj.peaks.time{row,col}   = peak.time;
                obj.peaks.width{row,col}  = peak.width;
                obj.peaks.height{row,col} = peak.height;
                obj.peaks.area{row,col}   = peak.area;
                obj.peaks.error{row,col}  = peak.error;
                obj.peaks.fit{row,col}    = peak.fit;
            else
                obj.peaks.time{row,col}   = [];
                obj.peaks.width{row,col}  = [];
                obj.peaks.height{row,col} = [];
                obj.peaks.area{row,col}   = [];
                obj.peaks.error{row,col}  = [];
                obj.peaks.fit{row,col}    = [];
            end
            
            obj.updatePeakEditText();
            
            offset = length(obj.peaks.name);
            
            if offset ~= 0
                
                obj.table.main.Data{row, col+13 + offset*0} = obj.peaks.time{row,col};
                obj.table.main.Data{row, col+13 + offset*1} = obj.peaks.area{row,col};
                obj.table.main.Data{row, col+13 + offset*2} = obj.peaks.height{row,col};
                obj.table.main.Data{row, col+13 + offset*3} = obj.peaks.width{row,col};
                
                if obj.controls.showPeak.Value
                    obj.updateAxesXLim();
                    obj.updateAxesYLim();
                    obj.plotPeaks();
                end
                
            end
            
            obj.userPeak(0);
            
        end
        
        function tableDeleteRow(obj, varargin)
            
            if ~isempty(obj.table.selection)
                
                row = obj.table.selection(:, 1);
                
                obj.data(row) = [];
                obj.peakDeleteRow(row);
                
                obj.table.main.Data(row, :) = [];
                
                if isempty(obj.data)
                    obj.view.index = 0;
                    obj.view.id    = 'N/A';
                    obj.view.name  = 'N/A';
                elseif obj.view.index > length(obj.data)
                    obj.view.index = length(obj.data);
                    obj.view.id    = num2str(length(obj.data));
                    obj.view.name  = obj.data(end).sample_name;
                else
                    obj.view.id   = num2str(obj.view.index);
                    obj.view.name = obj.data(obj.view.index).sample_name;
                end
                
                obj.updateSampleText();
                obj.updatePeakEditText();
                obj.updatePlot();
                
            end
            
            if isempty(obj.data)
                obj.resetAxes();
            end
            
        end
        
        function peakAddColumn(obj, str)
            
            offset = length(obj.peaks.name);
            
            tableHeader = obj.table.main.ColumnName;
            tableData = obj.table.main.Data;
            
            if isempty(tableData) || length(tableData(1,:)) < length(tableHeader)
                if ~isempty(obj.data)
                    tableData{end, length(tableHeader)} = [];
                end
            end
            
            if isempty(obj.peaks.name)
                obj.peaks.name(1,1) = str;
            else
                obj.peaks.name(end+1,1) = str;
            end
            
            if ~isempty(obj.peaks.time) && ~isempty(obj.data)
                obj.peaks.time{end,end+1}   = [];
                obj.peaks.width{end,end+1}  = [];
                obj.peaks.height{end,end+1} = [];
                obj.peaks.area{end,end+1}   = [];
                obj.peaks.error{end,end+1}  = [];
                obj.peaks.fit{end,end+1}    = [];
            end
            
            headerInfo = tableHeader(1:13);
            
            if offset > 0
                headerTime   = tableHeader(14+offset*0:14+offset*1-1);
                headerArea   = tableHeader(14+offset*1:14+offset*2-1);
                headerHeight = tableHeader(14+offset*2:14+offset*3-1);
                headerWidth  = tableHeader(14+offset*3:14+offset*4-1);
            else
                headerTime   = {};
                headerArea   = {};
                headerHeight = {};
                headerWidth  = {};
            end
            
            headerTime{end+1,1}   = ['Time (',   obj.peaks.name{end}, ')'];
            headerArea{end+1,1}   = ['Area (',   obj.peaks.name{end}, ')'];
            headerHeight{end+1,1} = ['Height (', obj.peaks.name{end}, ')'];
            headerWidth{end+1,1}  = ['Width (',  obj.peaks.name{end}, ')'];
            
            tableHeader = [headerInfo; headerTime; headerArea; headerHeight; headerWidth];
            
            if ~isempty(tableData)
                
                if length(tableData(1,:)) < 14+offset*4-1
                    tableData{end,14+offset*4-1} = [];
                end
                
                tableInfo   = tableData(:,1:13);
                tableTime   = tableData(:,14+offset*0:14+offset*1-1);
                tableArea   = tableData(:,14+offset*1:14+offset*2-1);
                tableHeight = tableData(:,14+offset*2:14+offset*3-1);
                tableWidth  = tableData(:,14+offset*3:14+offset*4-1);
                
                tableTime{end, end+1}   = [];
                tableArea{end, end+1}   = [];
                tableHeight{end, end+1} = [];
                tableWidth{end, end+1}  = [];
                
                tableData = [tableInfo, tableTime, tableArea, tableHeight, tableWidth];
                
            end
            
            if isempty(obj.controls.peakList.Value) || obj.controls.peakList.Value == 0
                if ~isempty(obj.peaks.name)
                    obj.controls.peakList.Value = 1;
                end
            end
            
            obj.controls.peakList.String = obj.peaks.name;
            
            obj.table.main.ColumnName = tableHeader;
            obj.table.main.Data = tableData;
            
            if length(obj.peaks.name) == 1
                obj.updatePeakEditText()
            end
            
        end
        
        function peakEditColumn(obj, m, str)
            
            if m == 0
                return
            end
            
            offset = length(obj.peaks.name);
            
            if offset >= m
                obj.peaks.name(m,1) = str;
                obj.controls.peakIDEdit.String = str;
            end
            
            tableHeader = obj.table.main.ColumnName;
            
            if length(tableHeader) >= m
                tableHeader{m+13 + offset*0} = ['Time (', obj.peaks.name{m}, ')'];
                tableHeader{m+13 + offset*1} = ['Area (', obj.peaks.name{m}, ')'];
                tableHeader{m+13 + offset*2} = ['Height (', obj.peaks.name{m}, ')'];
                tableHeader{m+13 + offset*3} = ['Width (', obj.peaks.name{m}, ')'];
            end
            
            obj.controls.peakList.String = obj.peaks.name;
            obj.table.main.ColumnName = tableHeader;
            
            if ~isempty(obj.data)
                obj.plotPeaks();
            end
            
        end
        
        function peakDeleteColumn(obj, m)
            
            if m == 0
                return
            end
            
            offset = length(obj.peaks.name);
            
            tableData = obj.table.main.Data;
            tableHeader = obj.table.main.ColumnName;
            
            obj.peaks.name(m) = [];
            
            if ~isempty(obj.peaks.time) && length(obj.peaks.time(1,:)) >= m
                obj.peaks.time(:,m)   = [];
                obj.peaks.width(:,m)  = [];
                obj.peaks.height(:,m) = [];
                obj.peaks.area(:,m)   = [];
                obj.peaks.error(:,m)  = [];
                obj.peaks.fit(:,m)    = [];
            end
            
            if isempty(tableData) || length(tableData(1,:)) < length(tableHeader)
                if ~isempty(obj.data)
                    tableData{end, length(tableHeader)} = [];
                end
            end
            
            if length(tableHeader) >= m
                tableHeader(m+13 + offset*0 - 0) = [];
                tableHeader(m+13 + offset*1 - 1) = [];
                tableHeader(m+13 + offset*2 - 2) = [];
                tableHeader(m+13 + offset*3 - 3) = [];
            end
            
            if ~isempty(tableData) && length(tableData(1,:)) >= m
                tableData(:, m+13 + offset*0 - 0) = [];
                tableData(:, m+13 + offset*1 - 1) = [];
                tableData(:, m+13 + offset*2 - 2) = [];
                tableData(:, m+13 + offset*3 - 3) = [];
            end
            
            if isempty(tableData) && size(tableData,2) > length(tableHeader)
                tableData(:, length(tableHeader)+1:end) = [];
            end
            
            obj.table.main.Data = tableData;
            obj.table.main.ColumnName = tableHeader;
            
            if isempty(obj.controls.peakList.String) && ~isempty(obj.peaks.name)
                if isempty(obj.controls.peakList.Value) || obj.controls.peakList.Value == 0
                    obj.controls.peakList.Value = 1;
                end
            end
            
            if obj.controls.peakList.Value > length(obj.peaks.name)
                obj.controls.peakList.Value = length(obj.peaks.name);
            end
            
            obj.controls.peakList.String = obj.peaks.name;
            
            if ~isempty(obj.data)
                obj.plotPeaks();
            end
            
        end
        
        function peakDeleteRow(obj, row)
            
            if isempty(obj.peaks.time)
                return
            elseif length(obj.peaks.time(:,1)) >= row
                obj.peaks.time(row, :)   = [];
                obj.peaks.width(row, :)  = [];
                obj.peaks.height(row, :) = [];
                obj.peaks.area(row, :)   = [];
                obj.peaks.error(row, :)  = [];
                obj.peaks.fit(row, :)    = [];
            end
            
        end
        
        % ---------------------------------------
        % Copy Figure Plot
        % ---------------------------------------
        function copyFigure(obj, varargin)
            
            exportFigure = figure('visible', 'off');
            exportPanel = copy(obj.panel.axes);
            
            exportPanel.Units = 'pixels';
            
            exportWidth  = exportPanel.Position(3) - exportPanel.Position(1);
            exportHeight = exportPanel.Position(4) - exportPanel.Position(2);
            
            if exportWidth <= 0
                exportWidth = 1;
            end
            
            if exportHeight <= 0
                exportHeight = 1;
            end
            
            exportPanel.Units = 'normalized';
            
            set(exportFigure,...
                'color',    'white',...
                'units',    'pixels',...
                'position', [0, 0, exportWidth, exportHeight]);
            
            set(exportPanel,....
                'parent',   exportFigure,...
                'position', [0, 0, 1, 1],....
                'backgroundcolor', 'white');
            
            axesHandles = exportPanel.Children;
            
            if isempty(axesHandles)
                
                if ishandle(exportFigure)
                    close(exportFigure);
                end
                
                return
                
            end
            
            axesTags = get(axesHandles, 'tag');
            axesPlot = strcmpi(axesTags, 'axesplot');
            
            if any(axesPlot)
                if isprop(axesHandles(axesPlot), 'outerposition')
                    p1 = axesHandles(axesPlot).Position;
                    p2 = axesHandles(axesPlot).OuterPosition;
                else
                    p1 = axesHandles(axesPlot).Position;
                    p2 = p1;
                end
            else
                if isprop(gca, 'outerposition')
                    p1 = get(gca, 'position');
                    p2 = get(gca, 'outerposition');
                else
                    p1 = get(gca, 'position');
                    p2 = p1;
                end
            end
            
            axesPosition(1) = p1(1) - p2(1);
            axesPosition(2) = p1(2) - p2(2);
            axesPosition(3) = p1(3) - (p2(3)-1);
            axesPosition(4) = p1(4) - (p2(4)-1);
            
            if axesPosition(3) <= 0
                axesPosition(3) = 1;
            end
            
            if axesPosition(4) <= 0
                axesPosition(4) = 1;
            end
            
            for i = 1:length(axesHandles)
                if strcmpi(get(axesHandles(i), 'type'), 'axes')
                    axesHandles(i).Position = axesPosition;
                end
            end
            
            print(exportFigure, '-clipboard', '-dbitmap');
            
            if ishandle(exportFigure)
                close(exportFigure);
            end
            
        end
        
        function copyTable(obj, varargin)
            
            str = '';
            fmtStr = '%s%s\t';
            fmtNum = '%s%.3f\t';
            
            tableHeader = obj.table.main.ColumnName;
            tableData = obj.table.main.Data;
            
            nRow = size(tableData, 1);
            nCol = length(tableHeader);
            
            if size(tableData, 2) ~= nCol && nRow ~= 0
                tableData = obj.validateData(tableData, nRow, nCol);
            end
            
            for i = 1:nCol
                str = sprintf(fmtStr, str, tableHeader{i});
            end
            
            str = sprintf('%s\n', str);
            
            if nRow > 0
                
                for i = 1:nRow
                    
                    for j = 1:nCol
                        if j < 10
                            str = sprintf(fmtStr, str, tableData{i,j});
                        else
                            str = sprintf(fmtNum, str, tableData{i,j});
                        end
                    end
                    
                    if i < nRow
                        str = sprintf('%s\n', str);
                    elseif i == nRow
                        str = sprintf('%s', str);
                    end
                    
                end
                
            end
            
            clipboard('copy', str);
            
        end
        
        function figureMotionCallback(obj, src, ~)
            
            if ~isprop(src, 'CurrentObject') || isempty(src.CurrentObject)
                return
            else
                xObj = src.CurrentObject;
            end
            
            if ~isprop(xObj, 'Tag')
                return
                
            elseif ~isempty(xObj.Tag)
                
                switch xObj.Tag
                    
                    case 'peaklist'
                        
                        obj.userPeak(1);
                        
                    case 'selectpeak'
                        
                        if isprop(xObj, 'Value') && xObj.Value
                            obj.userPeak(1);
                        else
                            obj.userPeak(0);
                        end
                        
                    otherwise
                        
                        obj.userPeak(0);
                        
                end
            end
            
        end
        
        function peakTimeSelectCallback(obj, ~, evt)
            
            switch evt.EventName
                
                case 'Hit'
                    
                    x = evt.IntersectionPoint(1);
                    
                    if obj.view.index == 0 || isempty(obj.peaks.name)
                        obj.clearPeak();
                    elseif x > obj.axes.xlim(1) && x < obj.axes.xlim(2)
                        obj.getPeakFit(x);
                    end
                    
                    obj.userPeak(0);
                    
                otherwise
                    obj.userPeak(0);
                    
            end
            
        end
        
        function zoomCallback(obj, varargin)
            
            if obj.view.index ~= 0
                obj.axes.xmode = 'manual';
                obj.axes.ymode = 'manual';
                obj.axes.xlim = varargin{1,2}.Axes.XLim;
                obj.axes.ylim = varargin{1,2}.Axes.YLim;
                obj.updateAxesLimitToggle();
                obj.updateAxesLimitEditText();
                obj.updateAxesXLim();
                obj.updateAxesYLim();
            else
                obj.axes.main.XLim = obj.axes.xlim;
                obj.axes.main.YLim = obj.axes.ylim;
            end
            
        end
        
    end
    
    methods (Access = private)
        
        function initializeGUI(obj, varargin)
            
            obj.toolboxFigure();
            obj.toolboxMenu();
            obj.toolboxPanel();
            obj.toolboxTable();
            obj.toolboxAxes();
            obj.toolboxButton();
            obj.toolboxResize();
            
            obj.axes.zoom = zoom(obj.figure);
            
            set(obj.axes.zoom,...
                'actionpostcallback', @(src, evt) zoomCallback(obj, src, evt));
            
            obj.userZoom(0);
            
        end
        
        function selectSample(obj, varargin)
            
            currentIndex = obj.view.index;
            
            if ~isempty(currentIndex) && currentIndex ~= 0
                
                newIndex = currentIndex + varargin{1};
                maxIndex = length(obj.data);
                
                if maxIndex == 1
                    return
                elseif newIndex <= maxIndex && newIndex >= 1
                    obj.view.index = newIndex;
                    obj.view.id    = num2str(newIndex);
                    obj.view.name  = obj.data(newIndex).sample_name;
                elseif newIndex > maxIndex
                    obj.view.index = 1;
                    obj.view.id    = '1';
                    obj.view.name  = obj.data(1).sample_name;
                elseif newIndex < 1
                    obj.view.index = maxIndex;
                    obj.view.id    = num2str(maxIndex);
                    obj.view.name  = obj.data(maxIndex).sample_name;
                end
                
                obj.figure.CurrentObject = obj.controls.peakList;
                
                obj.updateSampleText();
                obj.updatePeakText();
                obj.updatePlot();
                obj.userPeak(1);
                
            end
            
        end
        
        function selectPeak(obj, varargin)
            
            currentIndex = obj.controls.peakList.Value;
            
            if ~isempty(currentIndex) && currentIndex ~= 0
                
                newIndex = currentIndex + varargin{1};
                maxIndex = length(obj.peaks.name);
                
                if maxIndex == 1
                    return
                elseif newIndex <= maxIndex && newIndex >= 1
                    obj.controls.peakList.Value = newIndex;
                elseif newIndex > maxIndex
                    obj.controls.peakList.Value = 1;
                elseif newIndex < 1
                    obj.controls.peakList.Value = maxIndex;
                end
                
                obj.figure.CurrentObject = obj.controls.peakList;
                
                obj.updatePeakText();
                obj.userPeak(1);
                
            end
            
        end
        
        function updateSampleText(obj, varargin)
            
            obj.controls.editID.String   = obj.view.id;
            obj.controls.editName.String = obj.view.name;
            
        end
        
        function updatePeakText(obj, varargin)
            
            str = @(x) sprintf('%.3f', x);
            
            row = obj.view.index;
            col = obj.controls.peakList.Value;
            
            if ~isempty(col) && col ~= 0
                obj.controls.peakIDEdit.String = obj.peaks.name{col};
            else
                obj.controls.peakIDEdit.String = '';
            end
            
            if ~isempty(obj.data) && ~isempty(col) && col ~= 0 && row ~= 0
                obj.controls.peakTimeEdit.String   = str(obj.peaks.time{row,col});
                obj.controls.peakAreaEdit.String   = str(obj.peaks.area{row,col});
                obj.controls.peakHeightEdit.String = str(obj.peaks.height{row,col});
                obj.controls.peakWidthEdit.String  = str(obj.peaks.width{row,col});
            end
            
            obj.updatePlot();
            
        end
        
        function appendTableData(obj, varargin)
            
            if isempty(obj.data)
                return
            end
            
            row = size(obj.table.main.Data,1) + 1;
            
            obj.table.main.Data{row,1}  = obj.data(end).file_path;
            obj.table.main.Data{row,2}  = obj.data(end).file_name;
            obj.table.main.Data{row,3}  = obj.data(end).datetime;
            obj.table.main.Data{row,4}  = obj.data(end).instrument;
            obj.table.main.Data{row,5}  = obj.data(end).instmodel;
            obj.table.main.Data{row,6}  = obj.data(end).method_name;
            obj.table.main.Data{row,7}  = obj.data(end).operator;
            obj.table.main.Data{row,8}  = obj.data(end).sample_name;
            obj.table.main.Data{row,9}  = obj.data(end).sample_info;
            obj.table.main.Data{row,10} = obj.data(end).seqindex;
            obj.table.main.Data{row,11} = obj.data(end).vial;
            obj.table.main.Data{row,12} = obj.data(end).replicate;
            
        end
        
        function clearPeak(obj, varargin)
            
            row = obj.view.index;
            col = obj.controls.peakList.Value;
            
            obj.clearPeakText(col);
            
            if ~isempty(col) && col ~= 0 && row ~= 0
                obj.clearPeakData(row, col);
                obj.clearPeakTable(row, col);
            end
            
            obj.updatePlot();
            
        end
        
        function clearPeakText(obj, col)
            
            if ~isempty(col) && col ~= 0
                obj.controls.peakIDEdit.String = obj.peaks.name{col};
            else
                obj.controls.peakIDEdit.String = '';
            end
            
            obj.controls.peakTimeEdit.String   = '';
            obj.controls.peakWidthEdit.String  = '';
            obj.controls.peakHeightEdit.String = '';
            obj.controls.peakAreaEdit.String   = '';

        end
        
        function clearPeakData(obj, row, col)
            
            obj.peaks.time{row,col}   = [];
            obj.peaks.width{row,col}  = [];
            obj.peaks.height{row,col} = [];
            obj.peaks.area{row,col}   = [];
            obj.peaks.error{row,col}  = [];
            obj.peaks.fit{row,col}    = [];
            
        end
        
        function clearPeakTable(obj, row, col)
            
            nCol = length(obj.peaks.name);
            
            obj.table.main.Data{row, col+13 + nCol*0} = [];
            obj.table.main.Data{row, col+13 + nCol*1} = [];
            obj.table.main.Data{row, col+13 + nCol*2} = [];
            obj.table.main.Data{row, col+13 + nCol*3} = [];
            
        end
        
        function clearTableData(obj, varargin)
            
            obj.table.main.Data = [];
            
        end
        
        function clearAxesChildren(obj, tag)
            
            axesChildren = obj.axes.main.Children;
            
            if ~isempty(axesChildren)
                axesTag = get(axesChildren, 'tag');
                delete(axesChildren(strcmpi(axesTag, tag)));
            end
            
        end
        
        function resetAxes(obj)
            
            obj.axes.xlim  = [0.000, 1.000];
            obj.axes.ylim  = [0.000, 1.000];
            
            obj.axes.xmode = 'auto';
            obj.axes.ymode = 'auto';
            
            obj.updateAxesLimitToggle();
            obj.updateAxesLimitEditText();
            obj.updateAxesXLim();
            obj.updateAxesYLim();
            
        end
        
        function resetTableHeader(obj, varargin)
            
            if length(obj.table.main.ColumnName) >= 13
                obj.table.main.ColumnName = obj.table.main.ColumnName(1:13);
            end
            
            if ~isempty(obj.peaks.name)
                
                nCol = length(obj.peaks.name);
                
                for i = 1:length(obj.peaks.name)
                    obj.table.main.ColumnName(i+13 + nCol*0) = {['Time (', obj.peaks.name{i}, ')']};
                    obj.table.main.ColumnName(i+13 + nCol*1) = {['Area (', obj.peaks.name{i}, ')']};
                    obj.table.main.ColumnName(i+13 + nCol*2) = {['Height (', obj.peaks.name{i}, ')']};
                    obj.table.main.ColumnName(i+13 + nCol*3) = {['Width (', obj.peaks.name{i}, ')']};
                end
            end
            
        end
        
        function resetTableData(obj, varargin)
            
            if isempty(obj.data)
                return
            else
                nRow = length(obj.data);
            end
            
            if ~isempty(obj.peaks.name)
                nCol = length(obj.peaks.name);
            else
                nCol = 0;
            end
            
            if nCol ~= 0
                obj.validatePeakData(nRow, nCol);
            end
            
            for i = 1:nRow
                
                obj.table.main.Data{i,1}  = obj.data(i).file_path;
                obj.table.main.Data{i,2}  = obj.data(i).file_name;
                obj.table.main.Data{i,3}  = obj.data(i).datetime;
                obj.table.main.Data{i,4}  = obj.data(i).instrument;
                obj.table.main.Data{i,5}  = obj.data(i).instmodel;
                obj.table.main.Data{i,6}  = obj.data(i).method_name;
                obj.table.main.Data{i,7}  = obj.data(i).operator;
                obj.table.main.Data{i,8}  = obj.data(i).sample_name;
                obj.table.main.Data{i,9}  = obj.data(i).sample_info;
                obj.table.main.Data{i,10} = obj.data(i).seqindex;
                obj.table.main.Data{i,11} = obj.data(i).vial;
                obj.table.main.Data{i,12} = obj.data(i).replicate;
                
                if nCol ~= 0
                    for j = 1:nCol
                        obj.table.main.Data{i, j+13 + nCol*0} = obj.peaks.time{i,j};
                        obj.table.main.Data{i, j+13 + nCol*1} = obj.peaks.area{i,j};
                        obj.table.main.Data{i, j+13 + nCol*2} = obj.peaks.height{i,j};
                        obj.table.main.Data{i, j+13 + nCol*3} = obj.peaks.width{i,j};
                    end
                end
            end
            
        end
        
        function userZoom(obj, state)
            
            if obj.view.selectZoom == state
                return
            end
            
            switch state
                
                case 0
                    
                    obj.view.selectZoom = 0;
                    obj.axes.zoom.Enable = 'off';
                    
                    set(obj.figure, 'windowbuttonmotionfcn',...
                        @(src, evt) figureMotionCallback(obj, src, evt));
                    
                    set(obj.figure, 'windowkeypressfcn',...
                        @(src, evt) keyboardCallback(obj, src, evt));
                    
                case 1
                    
                    obj.view.selectZoom = 1;
                    obj.axes.zoom.Enable = 'on';
                    
                    set(obj.figure, 'windowbuttonmotionfcn',...
                        @(src, evt) figureMotionCallback(obj, src, evt));
                    
            end
            
        end
        
        function userPeak(obj, state)
            
            if obj.view.selectPeak == state
                return
            end
            
            switch state
                
                case 0
                    
                    obj.view.selectPeak = 0;
                    obj.controls.selectPeak.Value = 0;
                    
                    if strcmpi(obj.menu.view.zoom.Checked, 'on')
                        obj.userZoom(1);
                    end
                    
                    set(obj.axes.main, 'buttondownfcn', '');
                    
                case 1
                    
                    obj.view.selectPeak = 1;
                    obj.controls.selectPeak.Value = 1;
                    
                    if strcmpi(obj.menu.view.zoom.Checked, 'on')
                        obj.userZoom(0);
                    end
                    
                    set(obj.axes.main, 'buttondownfcn',...
                        @(src, evt) peakTimeSelectCallback(obj, src, evt));
                    
            end
            
        end
        
        function keyboardCallback(obj, ~, evt)
            
            if any(isprop(obj.figure.CurrentObject, 'tag'))
                if strcmpi(obj.figure.CurrentObject.Tag, 'datatable')
                    return
                end
            end
            
            if isprop(obj.figure.CurrentObject, 'style')
                if any(strcmpi(obj.figure.CurrentObject.Style, {'edit', 'slider'}))
                    return
                end
            end
            
            switch evt.Key
                
                case 'c'
                    
                    if ~isempty(evt.Modifier) && obj.view.index
                        
                        switch evt.Modifier{:}
                            
                            case 'command'
                                
                                if ismac
                                    obj.copyFigure();
                                end
                                
                            case 'control'
                                
                                if ispc || ~ismac
                                    obj.copyFigure();
                                end
                                
                        end
                        
                    end
                    
                case 'space'
                    
                    if isempty(evt.Modifier)
                        
                        if obj.view.selectPeak
                            obj.userPeak(0);
                            obj.figure.CurrentObject = obj.axes.main;
                        else
                            obj.userPeak(1);
                            obj.figure.CurrentObject = obj.controls.peakList;
                        end
                        
                    end
                    
                case 'uparrow'
                    
                    if isempty(evt.Modifier)
                        obj.selectPeak(-1);
                    end
                    
                case 'downarrow'
                    
                    if isempty(evt.Modifier)
                        obj.selectPeak(1);
                    end
                    
                case 'leftarrow'
                    
                    if isempty(evt.Modifier)
                        obj.selectSample(-1);
                    end
                    
                case 'rightarrow'
                    
                    if isempty(evt.Modifier)
                        obj.selectSample(1);
                    end
                    
                case 'backspace'
                    
                    if isempty(evt.Modifier)
                        obj.clearPeak();
                    end
                    
            end
            
        end
        
        function validatePeakData(obj, rows, cols)
            
            obj.peaks.time   = obj.validateData(obj.peaks.time, rows, cols);
            obj.peaks.area   = obj.validateData(obj.peaks.area, rows, cols);
            obj.peaks.height = obj.validateData(obj.peaks.height, rows, cols);
            obj.peaks.width  = obj.validateData(obj.peaks.width, rows, cols);
            obj.peaks.error  = obj.validateData(obj.peaks.error, rows, cols);
            obj.peaks.fit    = obj.validateData(obj.peaks.fit, rows, cols);
            
        end
    end
    
    methods (Static = true)
        
        function x = getPlatform()
            
            if ismac()
                x = 'mac';
            elseif isunix()
                x = 'linux';
            elseif ispc()
                x = 'windows';
            else
                x = 'unknown';
            end
            
        end
        
        function x = getEnvironment()
            
            if ~isempty(ver('MATLAB'))
                x = ver('MATLAB');
                x = ['matlab (',  x.Version, ')'];
            elseif ~isempty(ver('OCTAVE'))
                x = 'octave';
            else
                x = 'unknown';
            end
            
        end
        
        function x = getFont()
            
            fontPref = {'Avenir'; 'SansSerif'; 'Helvetica Neue';
                'Lucida Sans Unicode'; 'Microsoft Sans Serif'; 'Arial'};
            
            sysFonts = listfonts;
            
            for i = 1:length(fontPref)
                if any(strcmpi(fontPref{i}, sysFonts))
                    x = fontPref{i};
                    return
                end
            end
            
            x = 'FixedWidth';
            
        end
        
        function data = validateData(data, rows, cols)
            
            if size(data,1) < rows
                data{rows,1} = [];
            elseif size(data,1) > rows
                data(rows+1:end,:) = [];
            end
            
            if size(data,2) < cols
                data{1,cols} = [];
            elseif size(data,2) > cols
                data(:,cols+1:end) = [];
            end
            
        end
            
    end
end