classdef ChromatographyGUI < handle
    
    properties (Constant = true)
        
        name        = 'Chromatography Toolbox';
        url         = 'https://github.com/chemplexity/chromatography-gui';
        version     = '0.0.5';
        date        = '20170301';
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
            addpath(genpath([sourcePath, filesep, 'lib']));
            
            % ---------------------------------------
            % Defaults
            % ---------------------------------------
            obj.preferences.plot.color         = [0.10, 0.10, 0.10];
            obj.preferences.baseline.color     = [0.95, 0.22, 0.17];
            obj.preferences.peaks.color        = [0.00, 0.30, 0.53];
            
            obj.preferences.plot.linewidth     = 1.25;
            obj.preferences.baseline.linewidth = 1.50;
            obj.preferences.peaks.linewidth    = 2.00;
            
            obj.preferences.gui.fontsize    = 11.0;
            obj.preferences.labels.fontsize = 11.0;
            obj.preferences.labels.font     = obj.font;
            
            obj.preferences.labels.legend = {...
                'instrument',...
                'datetime',...
                'sample_name',...
                'vial'};
            
            obj.preferences.peakModel = 'nn';
            obj.preferences.peakArea  = 'rawData';
            
            obj.preferences.baselineSmoothness = 5.5;
            obj.preferences.baselineAsymmetry  = -5.5;
            
            obj.preferences.selectZoom = 0;
            
            obj.axes.xmode = 'auto';
            obj.axes.ymode = 'auto';
            obj.axes.xlim  = [0.000, 1.000];
            obj.axes.ylim  = [0.000, 1.000];
            
            obj.view.index = 0;
            obj.view.id    = 'N/A';
            obj.view.name  = 'N/A';
            
            obj.view.plotLine   = [];
            obj.view.plotLabel  = [];
            obj.view.baseLine   = [];
            obj.view.peakLine   = [];
            obj.view.peakLabel  = [];
            obj.view.selectZoom = obj.preferences.selectZoom;
            obj.view.selectPeak = 0;
            
            obj.view.showPlotLabel = 1;
            obj.view.showBaseLine  = 1;
            obj.view.showPeakLabel = 1;
            obj.view.showPeakLine  = 1;
            
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
            obj.loadPreferences();
            
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
                obj.updateAxesLimits();
                return
            else
                row = obj.view.index;
            end
            
            x = obj.data(row).time;
            y = obj.data(row).intensity(:,1);
            
            if any(ishandle(obj.view.peakLine))
                set(obj.view.plotLine, 'xdata', x, 'ydata', y);
            else
                obj.view.plotLine = plot(x, y,...
                    'parent',    obj.axes.main,...
                    'color',     obj.preferences.plot.color,...
                    'linewidth', obj.preferences.plot.linewidth,...
                    'visible',   'on',...
                    'hittest',   'off',...
                    'tag',       'main');
            end
            
            zoom reset
            
            obj.updateAxesLimits();
            
            if obj.controls.showBaseline.Value
                obj.plotBaseline();
            end
            
            if obj.controls.showPeak.Value
                obj.plotPeaks();
            end
            
            obj.updatePlotLabel();
            
        end
        
        function updateAxesXLim(obj, varargin)
            
            switch obj.axes.xmode
                
                case 'auto'
                    
                    if obj.view.index ~= 0
                        xmin = min(obj.data(obj.view.index).time);
                        xmax = max(obj.data(obj.view.index).time);
                        xmargin = (xmax - xmin) * 0.02;
                        obj.axes.xlim = [xmin - xmargin, xmax + xmargin];
                    end
                    
                    obj.axes.main.XLim = obj.axes.xlim;
                    
                case 'manual'
                    
                    if obj.view.index ~= 0
                        
                        xmin = str2double(obj.controls.xMin.String);
                        xmax = str2double(obj.controls.xMax.String);
                        
                        if xmin ~= round(obj.axes.xlim(2), 3)
                            obj.axes.xlim(1) = xmin;
                            obj.axes.main.XLim = obj.axes.xlim;
                        end
                        
                        if xmax ~= round(obj.axes.xlim(2), 3)
                            obj.axes.xlim(2) = xmax;
                            obj.axes.main.XLim = obj.axes.xlim;
                        end
                        
                    else
                        obj.axes.main.XLim = obj.axes.xlim;
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
                    
                    if ~isempty(y)
                        
                        y = y(x >= obj.axes.xlim(1) & x <= obj.axes.xlim(2));
                        
                        if any(y)
                            ymargin = (max(y) - min(y)) * 0.02;
                            obj.axes.ylim = [min(y) - ymargin, max(y) + ymargin];
                        end
                        
                    end
                    
                case 'manual'
                    
                    ymin = obj.controls.yMin.String;
                    ymax = obj.controls.yMax.String;
                    
                    obj.axes.ylim = [str2double(ymin), str2double(ymax)];
            end
            
            
            obj.axes.main.YLim = obj.axes.ylim;
            obj.updateAxesLimitEditText();
            obj.updatePlotLabelPosition();
            
        end
        
        function updateAxesLimitMode(obj, varargin)
            
            if obj.controls.xUser.Value
                obj.axes.xmode = 'manual';
            else
                obj.axes.xmode = 'auto';
            end
            
            if obj.controls.yUser.Value
                obj.axes.ymode = 'manual';
            else
                obj.axes.ymode = 'auto';
            end
            
        end
        
        function updateAxesLimitToggle(obj, varargin)
            
            switch obj.axes.xmode
                case 'manual'
                    obj.controls.xUser.Value = 1;
                    obj.controls.xAuto.Value = 0;
                case 'auto'
                    obj.controls.xUser.Value = 0;
                    obj.controls.xAuto.Value = 1;
            end
            
            switch obj.axes.ymode
                case 'manual'
                    obj.controls.yUser.Value = 1;
                    obj.controls.yAuto.Value = 0;
                case 'auto'
                    obj.controls.yUser.Value = 0;
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
        
        function plotBaseline(obj)
            
            if isempty(obj.data) || obj.view.index == 0
                return
            elseif ~obj.controls.showBaseline.Value
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
                
                if any(ishandle(obj.view.baseLine))
                    set(obj.view.baseLine, 'xdata', x, 'ydata', y);
                else
                    obj.view.baseLine = plot(x, y,...
                        'parent',    obj.axes.main,...
                        'color',     obj.preferences.baseline.color,...
                        'linewidth', obj.preferences.baseline.linewidth,...
                        'visible',   'on',...
                        'tag',       'baseline');
                end
                
            end
            
        end
        
        function plotPeaks(obj, varargin)
            
            obj.clearAxesChildren('peak');
            obj.clearAxesChildren('peaklabel');
            
            obj.updateAxesLimits();
            
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
                    
                    if obj.view.showPeakLine
                        
                        obj.view.peakLine{i} = plot(x, y,...
                            'parent',    obj.axes.main,...
                            'color',     obj.preferences.peaks.color,...
                            'linewidth', obj.preferences.peaks.linewidth,...
                            'visible',   'on',...
                            'hittest',   'off',...
                            'tag',       'peak');
                        
                    end
                    
                end
                
                obj.plotPeakLabels();
            end
            
        end
        
        function plotPeakLabels(obj, varargin)
            
            if ~obj.controls.showPeak.Value || ~obj.view.showPeakLabel
                return
            elseif isempty(obj.data) || obj.view.index == 0
                return
            elseif isempty(obj.peaks.fit)
                return
            else
                row = obj.view.index;
            end
            
            if ~isempty(varargin)
                col = varargin{1};
            else
                col = 1:length(obj.peaks.fit(row,:));
            end
            
            if any(~cellfun(@isempty, obj.peaks.fit(row,:)))
                
                for i = 1:length(col)
                    
                    if isempty(obj.peaks.fit{row,col(i)})
                        continue
                    elseif length(obj.peaks.fit{row,col(i)}(1,:)) ~= 2
                        continue
                    end
                    
                    obj.clearPeakLabel(col(i));
                    
                    x = obj.peaks.fit{row,col(i)}(:,1);
                    y = obj.peaks.fit{row,col(i)}(:,2);
                    
                    % Text Label
                    textStr = obj.peaks.name{col(i)};
                    textStr = deblank(strtrim(textStr(textStr ~= '\')));
                    textStr = ['\rm ', textStr];
                    
                    % Text Position
                    [~, yi] = max(y);
                    
                    textX = x(yi);
                    textY = y(yi);
                    
                    dataX = obj.data(row).time(:,1);
                    xi = find(obj.data(row).time(:,1) >= textX, 1);
                    xf = dataX >= dataX(xi)-0.05 & dataX <= dataX(xi)+0.05;
                    dataY = max(obj.data(row).intensity(xf,1));
                    
                    textY = max([textY, dataY]);
                    
                    % Plot Text
                    obj.view.peakLabel{col(i)} = text(textX, textY, textStr,...
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
                    
                    if isprop(obj.view.peakLabel{col(i)}, 'extent')
                        
                        textPos = obj.view.peakLabel{col(i)}.Extent;
                        
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
                                        
                                        obj.view.peakLabel{col(i)}.Units = 'characters';
                                        t = get(obj.view.peakLabel{col(i)}, 'extent');
                                        
                                        xmargin = (tW - ((t(3)-1) * tW) / t(3)) / 4;
                                        
                                        obj.view.peakLabel{col(i)}.Units = 'data';
                                        t = obj.view.peakLabel{col(i)}.Position;
                                        
                                        t(1) = t(1) + xmax - tL + xmargin;
                                        obj.view.peakLabel{col(i)}.Position = t;
                                        
                                    elseif xmin < tR && xmin > textX
                                        
                                        obj.view.peakLabel{col(i)}.Units = 'characters';
                                        t = obj.view.peakLabel{col(i)}.Extent;
                                        
                                        xmargin = (((t(3)+1) * tW) / t(3) - tW) / 4;
                                        
                                        obj.view.peakLabel{col(i)}.Units = 'data';
                                        t = obj.view.peakLabel{col(i)}.Position;
                                        
                                        t(1) = t(1) - xmargin;
                                        obj.view.peakLabel{col(i)}.Position = t;
                                        
                                    end
                                    
                                end
                            end
                        end
                        
                        % Text / Axes Limits
                        textPos = obj.view.peakLabel{col(i)}.Extent;
                        
                        tL = textPos(1);
                        tR = textPos(1) + textPos(3);
                        tT = textPos(2) + textPos(4);
                        
                        if textX <= obj.axes.xlim(2) && tR >= obj.axes.xlim(2)
                            
                            set(obj.view.peakLabel{col(i)}, 'units', 'characters');
                            tc = get(obj.view.peakLabel{col(i)}, 'extent');
                            
                            set(obj.view.peakLabel{col(i)}, 'units', 'data');
                            td = get(obj.view.peakLabel{col(i)}, 'extent');
                            
                            xmargin = td(3) - (td(3) / tc(3)) * (tc(3) - 0.5);
                            obj.axes.xlim(2) = td(1) + td(3) + xmargin;
                            
                            obj.controls.xMax.String = sprintf('%.3f', obj.axes.xlim(2));
                            obj.axes.main.XLim = obj.axes.xlim;
                            
                        end
                        
                        if textX >= obj.axes.xlim(1) && tL <= obj.axes.xlim(1)
                            
                            set(obj.view.peakLabel{col(i)}, 'units', 'characters');
                            tc = get(obj.view.peakLabel{col(i)}, 'extent');
                            
                            set(obj.view.peakLabel{col(i)}, 'units', 'data');
                            td = get(obj.view.peakLabel{col(i)}, 'extent');
                            
                            xmargin = td(3) - (td(3) / tc(3)) * (tc(3) - 0.5);
                            obj.axes.xlim(1) = td(1) - xmargin;
                            
                            obj.controls.xMin.String = sprintf('%.3f', obj.axes.xlim(1));
                            obj.axes.main.XLim = obj.axes.xlim;
                            
                        end
                        
                        if (tT >= obj.axes.ylim(2) && strcmpi(obj.axes.ymode, 'auto')) || ...
                                (tT >= obj.axes.ylim(2) && textPos(2) < obj.axes.ylim(2) && strcmpi(obj.axes.ymode, 'manual'))
                            
                            if textX > obj.axes.xlim(1) && textX < obj.axes.xlim(2)
                                
                                set(obj.view.peakLabel{col(i)}, 'units', 'characters');
                                tc = get(obj.view.peakLabel{col(i)}, 'extent');
                                
                                set(obj.view.peakLabel{col(i)}, 'units', 'data');
                                td = get(obj.view.peakLabel{col(i)}, 'extent');
                                
                                ymargin = td(4) - (td(4) / tc(4)) * (tc(4) - 0.5);
                                obj.axes.ylim(2) = td(2) + td(4) + ymargin;
                                
                                obj.controls.yMax.String = sprintf('%.3f', obj.axes.ylim(2));
                                obj.axes.main.YLim = obj.axes.ylim;
                                
                                obj.updatePlotLabelPosition();
                            end
                        end
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
        
        function tableDeleteRow(obj, varargin)
            
            if ~isempty(obj.table.selection)
                
                row = obj.table.selection(:,1);
                
                obj.data(row) = [];
                obj.peakDeleteRow(row);
                obj.table.main.Data(row, :) = [];
                
                if any(obj.view.index == row)
                    
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
                    obj.updatePeakText();
                    obj.updatePlot();
                    
                    if isempty(obj.data)
                        obj.resetAxes();
                    end
                end
                
                obj.validatePeakData(length(obj.data), length(obj.peaks.name));
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
            
            if ischar(str) && ~iscell(str)
                str = {str};
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
                
                if length(tableData(1,:)) < 14 + offset*4 - 1
                    tableData{end,14 + offset*4 - 1} = [];
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
            
            obj.validatePeakData(length(obj.data), length(obj.peaks.name));
            
            if length(obj.peaks.name) == 1
                obj.updatePeakText()
            end
            
        end
        
        function peakEditColumn(obj, col, str)
            
            if col == 0
                return
            end
            
            offset = length(obj.peaks.name);
            
            if offset >= col
                obj.peaks.name(col,1) = str;
                obj.controls.peakIDEdit.String = str;
            end
            
            if length(obj.table.main.ColumnName) >= col
                obj.table.main.ColumnName{col+13 + offset*0} = ['Time (', obj.peaks.name{col}, ')'];
                obj.table.main.ColumnName{col+13 + offset*1} = ['Area (', obj.peaks.name{col}, ')'];
                obj.table.main.ColumnName{col+13 + offset*2} = ['Height (', obj.peaks.name{col}, ')'];
                obj.table.main.ColumnName{col+13 + offset*3} = ['Width (', obj.peaks.name{col}, ')'];
            end
            
            obj.controls.peakList.String = obj.peaks.name;
            
            obj.plotPeakLabels(col);
            
        end
        
        function peakDeleteColumn(obj, col)
            
            if col == 0
                return
            else
                nCol = length(obj.peaks.name);
            end
            
            obj.peaks.name(col) = [];
            
            if ~isempty(obj.peaks.time) && length(obj.peaks.time(1,:)) >= col
                obj.peaks.time(:,col)   = [];
                obj.peaks.width(:,col)  = [];
                obj.peaks.height(:,col) = [];
                obj.peaks.area(:,col)   = [];
                obj.peaks.error(:,col)  = [];
                obj.peaks.fit(:,col)    = [];
            end
            
            if isempty(obj.table.main.Data) || length(obj.table.main.Data(1,:)) < length(obj.table.main.ColumnName)
                if ~isempty(obj.data)
                    obj.table.main.Data{end, length(obj.table.main.ColumnName)} = [];
                end
            end
            
            if length(obj.table.main.ColumnName) >= col
                obj.table.main.ColumnName(col+13 + nCol*0 - 0) = [];
                obj.table.main.ColumnName(col+13 + nCol*1 - 1) = [];
                obj.table.main.ColumnName(col+13 + nCol*2 - 2) = [];
                obj.table.main.ColumnName(col+13 + nCol*3 - 3) = [];
            end
            
            if ~isempty(obj.table.main.Data) && length(obj.table.main.Data(1,:)) >= col
                obj.table.main.Data(:, col+13 + nCol*0 - 0) = [];
                obj.table.main.Data(:, col+13 + nCol*1 - 1) = [];
                obj.table.main.Data(:, col+13 + nCol*2 - 2) = [];
                obj.table.main.Data(:, col+13 + nCol*3 - 3) = [];
            end
            
            if isempty(obj.table.main.Data) && size(obj.table.main.Data,2) > length(obj.table.main.ColumnName)
                obj.table.main.Data(:, length(obj.table.main.ColumnName)+1:end) = [];
            end
            
            if isempty(obj.controls.peakList.String) && ~isempty(obj.peaks.name)
                if isempty(obj.controls.peakList.Value) || obj.controls.peakList.Value == 0
                    obj.controls.peakList.Value = 1;
                end
            end
            
            if obj.controls.peakList.Value > length(obj.peaks.name)
                obj.controls.peakList.Value = length(obj.peaks.name);
            end
            
            obj.controls.peakList.String = obj.peaks.name;
            obj.clearPeakLine(col);
            
            if length(obj.view.peakLine) >= col && any(ishandle(obj.view.peakLine{col}))
                delete(obj.view.peakLine{col});
                obj.view.peakLine(col) = [];
            end
            
            if length(obj.view.peakLabel) >= col && any(ishandle(obj.view.peakLabel{col}))
                delete(obj.view.peakLabel{col});
                obj.view.peakLabel(col) = [];
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
            
            exportFigure = figure(...
                'visible', 'off',...
                'menubar', 'none',...
                'toolbar', 'none');
            
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
                'parent', exportFigure,...
                'position', [0, 0, 1, 1],....
                'bordertype', 'none',...
                'backgroundcolor', 'white');
            
            axesHandles = exportPanel.Children;
            
            if isempty(axesHandles)
                
                if any(ishandle(exportFigure))
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
            
            if any(ishandle(exportFigure))
                close(exportFigure);
            end
            
        end
        
        function copyTable(obj, varargin)
            
            str = '';
            fmtStr = '%s%s\t';
            fmtNum = '%s%.4f\t';
            
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
            
            if isprop(src, 'CurrentObject')
                
                if isprop(src.CurrentObject, 'Tag')
                    
                    switch src.CurrentObject.Tag
                        
                        case 'peaklist'
                            obj.userPeak(1);
                            
                        case 'selectpeak'
                            
                            if isprop(src.CurrentObject, 'Value')
                                if src.CurrentObject.Value
                                    obj.userPeak(1);
                                end
                            else
                                obj.userPeak(0);
                            end
                            
                        otherwise
                            obj.userPeak(0);
                    end
                    
                else
                    obj.userPeak(0);
                end
                
            else
                obj.userPeak(0);
            end
        end
        
        function peakTimeSelectCallback(obj, ~, evt)
            
            switch evt.EventName
                
                case 'Hit'
                    
                    x = evt.IntersectionPoint(1);
                    
                    if obj.view.index == 0 || isempty(obj.peaks.name)
                        obj.clearPeak();
                    elseif x > obj.axes.xlim(1) && x < obj.axes.xlim(2)
                        obj.toolboxPeakFit(x);
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
                obj.updateAxesLimits();
                obj.updatePlotLabelPosition();
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
            set(obj.axes.zoom, 'actionpostcallback', @obj.zoomCallback);
            obj.userZoom([], 0);
            
            obj.figure.Visible = 'on';
            
        end
        
        function selectSample(obj, varargin)
            
            currentIndex = obj.view.index;
            
            if ~isempty(currentIndex) && currentIndex ~= 0
                
                if length(varargin) == 1
                    n = varargin{1};
                elseif length(varargin) == 3
                    n = varargin{3};
                end
                
                newIndex = currentIndex + n;
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
            
            if ~isempty(col) && col ~= 0 && length(obj.peaks.name) >= col
                obj.controls.peakIDEdit.String = obj.peaks.name{col};
            else
                obj.controls.peakIDEdit.String = '';
            end
            
            if length(obj.peaks.name) < col
                return
            elseif ~isempty(obj.data) && ~isempty(col) && col ~= 0 && row ~= 0
                obj.controls.peakTimeEdit.String   = str(obj.peaks.time{row,col});
                obj.controls.peakAreaEdit.String   = str(obj.peaks.area{row,col});
                obj.controls.peakHeightEdit.String = str(obj.peaks.height{row,col});
                obj.controls.peakWidthEdit.String  = str(obj.peaks.width{row,col});
            end
            
        end
        
        function updatePlotLabel(obj, varargin)
            
            if any(ishandle(obj.view.plotLabel))
                delete(obj.view.plotLabel);
            end
            
            if isempty(obj.data) || obj.view.index == 0
                return
            elseif ~obj.view.showPlotLabel
                return
            else
                row = obj.view.index;
            end
            
            if isempty(obj.preferences.labels.legend)
                return
            else
                labelFields = obj.preferences.labels.legend;
            end
            
            str = '';
            
            for i = 1:length(labelFields)
                
                if isfield(obj.data, labelFields{i})
                    
                    n = obj.data(row).(labelFields{i});
                    
                    if isempty(n)
                        continue
                    elseif isnumeric(n)
                        n = num2str(n);
                    end
                    
                    switch labelFields{i}
                        case 'datetime'
                            n(n=='-') = '/';
                            n(n=='T') = ' ';
                        case 'operator'
                            n = ['Operator: ', n];
                        case 'seqindex'
                            n = ['SeqIndex: ', n];
                        case 'vial'
                            n = ['Vial: ', n];
                    end
                    
                    n(n=='_') = ' ';
                    
                    if i == 1 || isempty(str)
                        str = n;
                    else
                        str = [str, char(10), n];
                    end
                    
                end
            end
            
            if ~isempty(str)
                
                str = deblank(strtrim(str(str ~= '\')));
                str = ['\rm ', str];
                
                x = obj.axes.main.XLim(2);
                y = obj.axes.main.YLim(2);
                
                obj.view.plotLabel = text(x, y, str,...
                    'parent',   obj.axes.main,...
                    'clipping', 'on',...
                    'hittest',  'off',...
                    'tag',      'plotlabel',...
                    'fontsize', obj.preferences.labels.fontsize,...
                    'fontname', obj.preferences.labels.font,...
                    'margin',   3,...
                    'units',    'data',...
                    'pickableparts',       'none',...
                    'horizontalalignment', 'right',...
                    'verticalalignment',   'bottom',...
                    'selectionhighlight',  'off');
                
                a = obj.view.plotLabel.Extent;
                
                xlimit = obj.axes.main.XLim;
                ylimit = obj.axes.main.YLim;
                
                if a(1)+a(3) >= xlimit(2) - diff(xlimit)*0.01
                    b = obj.view.plotLabel.Position(1);
                    b = b - (a(1)+a(3) - (xlimit(2) - diff(xlimit)*0.01));
                    obj.view.plotLabel.Position(1) = b;
                end
                
                if a(2)+a(4) >= ylimit(2) - diff(ylimit)*0.01
                    b = obj.view.plotLabel.Position(2);
                    b = b - (a(2)+a(4) - (ylimit(2) - diff(ylimit)*0.01));
                    obj.view.plotLabel.Position(2) = b;
                end
            end
            
        end
        
        function updatePlotLabelPosition(obj, varargin)
            
            if any(ishandle(obj.view.plotLabel))
                
                a = obj.view.plotLabel.Extent;
                xlimit = obj.axes.main.XLim;
                ylimit = obj.axes.main.YLim;
                
                b = obj.view.plotLabel.Position(1);
                b = b - (a(1)+a(3) - (xlimit(2) - diff(xlimit)*0.01));
                obj.view.plotLabel.Position(1) = b;
                
                b = obj.view.plotLabel.Position(2);
                b = b - (a(2)+a(4) - (ylimit(2) - diff(ylimit)*0.01));
                obj.view.plotLabel.Position(2) = b;
                
            end
            
        end
        
        function updatePeakLine(obj, varargin)
            
            if isempty(obj.data) || obj.view.index == 0
                return
            elseif ~obj.controls.showPeak.Value || ~obj.view.showPeakLine
                return
            else
                row = obj.view.index;
            end
            
            if ~isempty(varargin)
                col = varargin{1};
            elseif ~isempty(obj.peaks.fit)
                col = 1:length(obj.peaks.fit(row,:));
            else
                return
            end
            
            for i = 1:length(col)
                
                if size(obj.peaks.fit,1) >= row && size(obj.peaks.fit,2) >= col(i)
                    
                    if isempty(obj.peaks.fit{row,col(i)})
                        continue
                    elseif size(obj.peaks.fit{row,col(i)},2) ~= 2
                        continue
                    else
                        x = obj.peaks.fit{row,col(i)}(:,1);
                        y = obj.peaks.fit{row,col(i)}(:,2);
                    end
                    
                    if length(obj.view.peakLine) >= col(i) && any(ishandle(obj.view.peakLine{col(i)}))
                        set(obj.view.peakLine{col(i)}, 'xdata', x, 'ydata', y);
                    else
                        obj.view.peakLine{col(i)} = plot(x, y,...
                            'parent',    obj.axes.main,...
                            'color',     obj.preferences.peaks.color,...
                            'linewidth', obj.preferences.peaks.linewidth,...
                            'visible',   'on',...
                            'hittest',   'off',...
                            'tag',       'peak');
                    end
                end
            end
            
        end
        
        function updateBaseLine(obj, varargin)
            
            if ~obj.controls.showBaseline.Value || isempty(obj.data)
                return
            elseif obj.view.index == 0
                return
            else
                row = obj.view.index;
            end
            
            if ~isempty(obj.data(row).baseline) && size(obj.data(row).baseline, 2) == 2
                
                x = obj.data(row).baseline(:,1);
                y = obj.data(row).baseline(:,2);
                
                if any(ishandle(obj.view.baseLine))
                    set(obj.view.baseLine, 'xdata', x, 'ydata', y);
                else
                    obj.view.baseLine = plot(x, y,...
                        'parent',    obj.axes.main,...
                        'color',     obj.preferences.baseline.color,...
                        'linewidth', obj.preferences.baseline.linewidth,...
                        'visible',   'on',...
                        'tag',       'baseline');
                end
            end
            
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
        
        function clearTableData(obj, varargin)
            
            obj.table.main.Data = [];
            
        end
        
        function clearPeak(obj, varargin)
            
            row = obj.view.index;
            col = obj.controls.peakList.Value;
            
            if isempty(col) || row == 0
                return
            end
            
            if row ~= 0 && col ~= 0
                obj.clearPeakText(col);
                obj.clearPeakLine(col);
                obj.clearPeakLabel(col);
                obj.clearPeakData(row, col);
                obj.clearPeakTable(row, col);
            end
            
        end
        
        function clearPeakText(obj, col)
            
            if col ~= 0
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
        
        function updatePeakData(obj, row, col, peak)
            
            obj.peaks.time{row,col}   = peak.time;
            obj.peaks.width{row,col}  = peak.width;
            obj.peaks.height{row,col} = peak.height;
            obj.peaks.area{row,col}   = peak.area;
            obj.peaks.error{row,col}  = peak.error;
            obj.peaks.fit{row,col}    = peak.fit;
            
        end
        
        function clearPeakTable(obj, row, col)
            
            nCol = length(obj.peaks.name);
            
            obj.table.main.Data{row, col+13 + nCol*0} = [];
            obj.table.main.Data{row, col+13 + nCol*1} = [];
            obj.table.main.Data{row, col+13 + nCol*2} = [];
            obj.table.main.Data{row, col+13 + nCol*3} = [];
            
        end
        
        function updatePeakTable(obj, row, col)
            
            nCol = length(obj.peaks.name);
            
            obj.table.main.Data{row, col+13 + nCol*0} = obj.peaks.time{row,col};
            obj.table.main.Data{row, col+13 + nCol*1} = obj.peaks.area{row,col};
            obj.table.main.Data{row, col+13 + nCol*2} = obj.peaks.height{row,col};
            obj.table.main.Data{row, col+13 + nCol*3} = obj.peaks.width{row,col};
            
        end
        
        function clearPeakLine(obj, col)
            
            if length(obj.view.peakLine) >= col && any(ishandle(obj.view.peakLine{col}))
                set(obj.view.peakLine{col}, 'xdata', [], 'ydata', []);
            end
            
        end
        
        function clearPeakLabel(obj, col)
            
            if length(obj.view.peakLabel) >= col && any(ishandle(obj.view.peakLabel{col}))
                
                if isprop(obj.view.peakLabel{col}, 'extent')
                    
                    xlimit = obj.axes.main.XLim;
                    ylimit = obj.axes.main.YLim;
                    
                    y = obj.view.peakLabel{col}.Extent;
                    y = y(2) + y(4);
                    
                    if y >= ylimit(2) - diff(ylimit) * 0.05
                        
                        isReset = 1;
                        
                        for i = 1:length(obj.view.peakLabel)
                            
                            if any(ishandle(obj.view.peakLabel{i})) && i ~= col
                                
                                xy = obj.view.peakLabel{i}.Extent;
                                
                                if xy(1) < xlimit(1) || xy(1) > xlimit(2)
                                    continue
                                end
                                
                                if xy(2)+xy(4) >= ylimit(2) - diff(ylimit)*0.05
                                    isReset = 0;
                                end
                            end
                        end
                        
                        if isReset
                            obj.updateAxesYLim();
                            obj.updatePlotLabelPosition();
                        end
                    end
                end
                
                delete(obj.view.peakLabel{col});
                
            end
            
        end
        
        function clearAllPlot(obj)
            
            obj.clearAllLine();
            obj.clearAllBaseLine();
            obj.clearAllPeakLine();
            obj.clearAllPeakLabel();
            
        end
        
        function clearAllPlotLine(obj)
            
            if any(ishandle(obj.view.plotLine))
                set(obj.view.plotLine, 'xdata', [], 'ydata', []);
            end
            
        end
        
        function clearAllBaseLine(obj)
            
            if any(ishandle(obj.view.baseLine))
                set(obj.view.baseLine, 'xdata', [], 'ydata', []);
            end
            
        end
        
        function clearAllPeakLine(obj)
            
            if ~isempty(obj.view.peakLine)
                for i = 1:length(obj.view.peakLine)
                    if any(ishandle(obj.view.peakLine{i}))
                        set(obj.view.peakLine{i}, 'xdata', [], 'ydata', []);
                    end
                end
            end
            
        end
        
        function clearAllPeakLabel(obj)
            
            if ~isempty(obj.view.peakLabel)
                for i = 1:length(obj.view.peakLabel)
                    if any(ishandle(obj.view.peakLabel{i}))
                        delete(obj.view.peakLabel{i});
                    end
                end
            end
            
        end
        
        function clearAxesChildren(obj, tag)
            
            axesChildren = obj.axes.main.Children;
            
            if ~isempty(axesChildren)
                axesTag = get(axesChildren, 'tag');
                delete(axesChildren(strcmpi(axesTag, tag)));
            end
            
        end
        
        function updateAxesLimits(obj)
            
            obj.updateAxesXLim();
            obj.updateAxesYLim();
            
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
        
        function userZoom(obj, state, varargin)
            
            if ~isempty(varargin)
                state = varargin{1};
            elseif obj.view.selectZoom == state
                return
            end
            
            switch state
                
                case 0
                    
                    obj.view.selectZoom = 0;
                    obj.axes.zoom.Enable = 'off';
                    
                    set(obj.figure, 'pointer', 'arrow');
                    set(obj.figure, 'windowkeypressfcn', @obj.keyboardCallback);
                    set(obj.figure, 'windowbuttonmotionfcn', @obj.figureMotionCallback);
                    
                case 1
                    
                    obj.view.selectZoom = 1;
                    obj.axes.zoom.Enable = 'on';
                    
                    set(obj.figure, 'windowbuttonmotionfcn', @obj.figureMotionCallback);
                    
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
                    
                    set(obj.figure, 'pointer', 'arrow');
                    set(obj.axes.main, 'buttondownfcn', '');
                    
                case 1
                    
                    if ~isempty(obj.data) && ~isempty(obj.peaks.name)
                        
                        obj.view.selectPeak = 1;
                        obj.controls.selectPeak.Value = 1;
                        
                        if strcmpi(obj.menu.view.zoom.Checked, 'on')
                            obj.userZoom(0);
                        end
                        
                        set(obj.figure, 'pointer', 'circle');
                        set(obj.axes.main, 'buttondownfcn', @obj.peakTimeSelectCallback);
                        
                    end
                    
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
                        
                        if strcmpi(evt.Modifier{:}, 'command') && ismac
                            obj.copyFigure();
                        elseif strcmpi(evt.Modifier{:}, 'control') && ~ismac
                            obj.copyFigure();
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
        
        function loadPreferences(obj, varargin)
            
            sourceFile = fileparts(mfilename('fullpath'));
            [sourcePath, sourceFile] = fileparts(sourceFile);
            
            if ~strcmpi(sourceFile, '@ChromatographyGUI')
                sourcePath = [sourcePath, filesep, sourceFile];
            end
            
            filePath = [sourcePath, filesep, 'lib', filesep, 'default', filesep];
            fileName = 'default_preferences.mat';
            
            [isFile, fileInfo] = fileattrib([filePath, fileName]);
            
            if ~isFile
                return
            end
            
            if ~fileInfo.directory && fileInfo.UserRead
                
                try
                    userSettings = load(fileInfo.Name);
                    
                    if isstruct(userSettings) && isfield(userSettings, 'user_preferences')
                        userSettings = userSettings.user_preferences;
                        
                        if isfield(userSettings, 'name') && strcmpi(userSettings.name, 'global_settings')
                            
                            if isfield(userSettings, 'data') && ~isempty(userSettings.data)
                                userSettings = userSettings.data;
                                
                                obj.preferences = userSettings;
                                
                                obj.view.showPlotLabel = obj.preferences.showPlotLabel;
                                obj.view.showBaseLine  = obj.preferences.showBaseLine;
                                obj.view.showPeakLabel = obj.preferences.showPeakLabel;
                                obj.view.showPeakLine  = obj.preferences.showPeakLine;
                                obj.view.selectZoom    = obj.preferences.selectZoom;
                                
                                obj.controls.asymSlider.Value   = obj.preferences.baselineAsymmetry;
                                obj.controls.smoothSlider.Value = obj.preferences.baselineSmoothness;
                                
                                obj.axes.xmode = obj.preferences.xmode;
                                obj.axes.ymode = obj.preferences.ymode;
                                obj.axes.xlim  = obj.preferences.xlim;
                                obj.axes.ylim  = obj.preferences.ylim;
                                
                                legendNames = obj.preferences.labels.legend;
                                legendMenu  = obj.menu.dataLabel.Children;
                                
                                for i = 1:length(legendMenu)
                                    
                                    if any(ishandle(legendMenu(i)))
                                        if any(strcmpi(legendMenu(i).Tag, legendNames))
                                            legendMenu(i).Checked = 'on';
                                        else
                                            legendMenu(i).Checked = 'off';
                                        end
                                    end
                                    
                                end
                                
                                switch obj.preferences.peakModel
                                    case 'nn'
                                        obj.menu.peakNeuralNetwork.Checked = 'on';
                                        obj.menu.peakExponentialGaussian.Checked = 'off';
                                    case 'egh'
                                        obj.menu.peakNeuralNetwork.Checked = 'off';
                                        obj.menu.peakExponentialGaussian.Checked = 'on';
                                end
                                
                                switch obj.preferences.peakArea
                                    case 'rawData'
                                        obj.menu.peakOptionsAreaActual.Checked = 'on';
                                        obj.menu.peakOptionsAreaFit.Checked = 'off';
                                    case 'fitData'
                                        obj.menu.peakOptionsAreaActual.Checked = 'off';
                                        obj.menu.peakOptionsAreaFit.Checked = 'on';
                                end
                                
                                if obj.view.showPlotLabel
                                    obj.menu.view.dataLabel.Checked = 'on';
                                else
                                    obj.menu.view.dataLabel.Checked = 'off';
                                end
                                
                                if obj.preferences.showBaseLine
                                    obj.controls.showBaseline.Value = 1;
                                else
                                    obj.controls.showBaseline.Value = 0;
                                end
                                
                                if obj.preferences.showPeaks
                                    obj.controls.showPeak.Value = 1;
                                else
                                    obj.controls.showPeak.Value = 0;
                                end
                                
                                if obj.view.showPeakLabel
                                    obj.menu.view.peakLabel.Checked = 'on';
                                else
                                    obj.menu.view.peakLabel.Checked = 'off';
                                end
                                
                                if obj.view.showPeakLine
                                    obj.menu.view.peakLine.Checked = 'on';
                                else
                                    obj.menu.view.peakLine.Checked = 'off';
                                end
                                
                                if strcmpi(obj.preferences.showZoom, 'on')
                                    obj.menu.view.zoom.Checked = 'on';
                                    obj.view.selectZoom = 1;
                                    obj.userZoom(1);
                                    obj.userPeak(0);
                                else
                                    obj.menu.view.zoom.Checked = 'off';
                                    obj.view.selectZoom = 0;
                                    obj.userZoom(0);
                                end
                                
                                obj.updateAxesLimitToggle();
                                obj.updateAxesLimitMode();
                                
                                if strcmpi(obj.axes.xmode, 'manual')
                                    obj.axes.main.XLim = obj.axes.xlim;
                                end
                                
                                if strcmpi(obj.axes.ymode, 'manual')
                                    obj.axes.main.YLim = obj.axes.ylim;
                                end
                                
                                obj.updateAxesLimitEditText();
                                obj.updatePlot();
                                
                            end
                        end
                    end
                    
                catch
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