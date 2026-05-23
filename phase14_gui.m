function phase14_gui

couleur='#E1628B';

global unitsG scaleG nodesG edgesG edgeTypeG midpointsG loopsG loopTypeG h0 model nNodes nElem

unitsG=[]; scaleG=[]; nodesG=[]; edgesG=[]; edgeTypeG=[];
midpointsG=[]; loopsG=[]; loopTypeG=[]; h0=[];
nNodes=0; nElem=0;

isComputing=false; stopRequested=false; preComputeModel=[];

model=struct();
model.mesh=[];
model.material=struct('name','','E',[],'nu',[],'density',[],'thickness',[],'analysisType','');
model.results=struct();
model.constraints=struct('type',{},'x_mag',{},'y_mag',{},'affected_nodes',{},'point',{},'regionType',{},'regionID',{});
model.loads      =struct('type',{},'x_mag',{},'y_mag',{},'affected_nodes',{},'point',{},'regionType',{},'regionID',{});

% -------------------------------------------------------------------------
% Refinement region storage
%   center         [1x2]  (cx,cy) metres
%   radius         scalar metres
%   h_target       scalar metres  — desired element size inside the region
%   vertices       [4x2]  CCW bounding-square corners (metres)
%                         order: E=[cx+R,cy]  N=[cx,cy+R]  W=[cx-R,cy]  S=[cx,cy-R]
%   point          [1x2]  = selected anchor point / center for drawing
%   regionType     'RefinementCircle'
%   regionID       integer, 1-based, never reused within a session
%   sourceType     'Vertex' | 'Edge' | 'Node' | 'Point'
%   sourceID       selected geometry/mesh ID. Empty for free point.
%   affected_nodes mesh nodes closest to / associated with the selected target
% -------------------------------------------------------------------------
model.refinementRegions=struct('center',{},'radius',{},'h_target',{},'vertices',{},...
    'point',{},'regionType',{},'regionID',{},'sourceType',{},'sourceID',{},...
    'affected_nodes',{},'shapeType',{},'edgePolyline',{});

leftPanelMode='standard';
refPickActive=false;
refPickCount =0;
refSelectedType='';
refSelectedID=[];
refSelectedPoint=[];
refSelectedNodes=[];
refHoverType='';
refHoverID=[];
refLastHoverKey='';
prevDisplayScale=1; % tracks the last-used display scale for unit conversion

fig=uifigure('Name','2D FEA GUI - Phase 14','Position',[100 100 1120 650]);
fig.CloseRequestFcn=@onFigClose;

leftPanel =uipanel(fig,'Title','Inputs / Actions','Position',[10 10 280 630]);
rightPanel=uipanel(fig,'Title','Display',          'Position',[300 10 810 630]);

sectionLabel=uilabel(leftPanel,'Text','Select Section','Position',[20 575 100 22],'FontWeight','bold');
sectionDropDown=uidropdown(leftPanel,...
    'Items',{'Engineering Data','Geometry / Mesh','Analysis'},...
    'Value','Engineering Data','Position',[20 545 220 22]);

sectionX=15; sectionY=125; sectionW=245; sectionH=400;

progressPanel=uipanel(leftPanel,'Title','Progress','Position',[10 10 255 115]);
pg=uigridlayout(progressPanel,[3 2]);
pg.RowHeight={22,34,26}; pg.ColumnWidth={'1x',44};
pg.RowSpacing=5; pg.ColumnSpacing=8; pg.Padding=[6 6 6 6];

processLabel=uilabel(pg,'Text','Ready','FontWeight','bold');
processLabel.Layout.Row=1; processLabel.Layout.Column=1;

processPercentLabel=uilabel(pg,'Text','0%','HorizontalAlignment','right');
processPercentLabel.Layout.Row=1; processPercentLabel.Layout.Column=2;

processBarTrack=uipanel(pg,'BorderType','line','BackgroundColor',[0.94 0.94 0.94]);
processBarTrack.Layout.Row=2; processBarTrack.Layout.Column=1;

processBarFill=uipanel(processBarTrack,...
    'Position',[1 1 1 30],'BorderType','none','BackgroundColor',[0.1 0.65 0.2]);

runStopBtn=uibutton(pg,'push','Text',char(9654),...
    'FontSize',18,'FontWeight','bold','FontColor','white',...
    'BackgroundColor',[0.1 0.65 0.2],'Tooltip','Ready',...
    'ButtonPushedFcn',@runStopButtonCallback);
runStopBtn.Layout.Row=2; runStopBtn.Layout.Column=2;

processHintLabel=uilabel(pg,'Text','Ready to continue.',...
    'FontColor',[0.35 0.35 0.35],'WordWrap','on');
processHintLabel.Layout.Row=3; processHintLabel.Layout.Column=[1 2];

% =========================================================================
% Engineering data section
% =========================================================================
engPanel=uipanel(leftPanel,'Title','Engineering Data',...
    'Position',[sectionX sectionY sectionW sectionH],'Visible','on');

uilabel(engPanel,'Text','Material','Position',[15 348 100 22]);
uilabel(engPanel,'Text',char(9432),'Position',[63 348 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','Select a preset material to auto-fill properties, or choose Custom');
materialDropDown=uidropdown(engPanel,...
    'Items',{'Custom Material','Nylon','Structural Steel'},...
    'Value','Structural Steel','Position',[15 323 200 22],...
    'ValueChangedFcn',@materialChangedCallback);

eLabelText=uilabel(engPanel,'Text','Young''s Modulus E (Pa)','Position',[15 283 155 22]);
uilabel(engPanel,'Text',char(9432),'Position',[155 283 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','Stiffness of the material. Steel=210e9 Pa, Nylon=2.7e9 Pa');
eField=uieditfield(engPanel,'numeric','Position',[15 258 200 22],'Value',210e9,'ValueDisplayFormat','%.4g');

uilabel(engPanel,'Text','Poisson''s Ratio nu','Position',[15 218 140 22]);
uilabel(engPanel,'Text',char(9432),'Position',[119 218 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','Range: -1 to 0.5. Steel=0.30, Nylon=0.39, rubber~0.49');
nuField=uieditfield(engPanel,'numeric','Position',[15 193 200 22],'Value',0.30,'ValueDisplayFormat','%.4f');

densityLabelText=uilabel(engPanel,'Text','Density (kg/m^3)','Position',[15 153 140 22]);
uilabel(engPanel,'Text',char(9432),'Position',[110 153 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','Mass per unit volume. Steel=7850, Nylon=1150');
densityField=uieditfield(engPanel,'numeric','Position',[15 128 200 22],'Value',7850,'ValueDisplayFormat','%.4g');

uilabel(engPanel,'Text','Analysis Type','Position',[15 88 120 22]);
uilabel(engPanel,'Text',char(9432),'Position',[95 88 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','Plane Stress = thin plate. Plane Strain = long body. Axisymmetric = body of revolution.');
analysisTypeDropDown=uidropdown(engPanel,...
    'Items',{'Pick One','Plane Stress','Plane Strain','Axisymmetric'},...
    'Value','Plane Stress','Position',[15 63 200 22],...
    'ValueChangedFcn',@analysisTypeChangedCallback);

uilabel(engPanel,'Text','Analysis Info','Position',[15 38 150 22]);
engInfo=uitextarea(engPanel,'Position',[15 5 215 33],...
    'Editable','off','Value',{'Select an analysis type above.'});

% =========================================================================
% Geometry / Mesh section
% =========================================================================
geomPanel=uipanel(leftPanel,'Title','Geometry / Mesh',...
    'Position',[sectionX sectionY sectionW sectionH],'Visible','off');

uibutton(geomPanel,'push','Text','Load File',...
    'Position',[20 345 180 32],'ButtonPushedFcn',@loadGeoCallback);
uilabel(geomPanel,'Text',char(9432),'Position',[204 349 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','Load a .dxf geometry file.');

uibutton(geomPanel,'push','Text','Load Mesh',...
    'Position',[20 303 180 32],'ButtonPushedFcn',@loadMeshCallback);
uilabel(geomPanel,'Text',char(9432),'Position',[204 307 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','Generate mesh from the loaded geometry. Generate an overall mesh before defining refinement regions.');

uilabel(geomPanel,'Text','Display Units','Position',[20 278 180 22]);
displayUnitsDropDown=uidropdown(geomPanel,...
    'Items',{'m','cm','mm','in'},'Value','m','Position',[20 253 200 22],...
    'ValueChangedFcn',@displayUnitsChangedCallback);

thicknessLabel=uilabel(geomPanel,'Text','Thickness [m]','Position',[20 228 180 22]);
uilabel(geomPanel,'Text',char(9432),'Position',[204 228 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','Out-of-plane thickness for Plane Stress analyses.');
thicknessField=uieditfield(geomPanel,'numeric','Position',[20 203 200 22],'Value',0.01,'ValueDisplayFormat','%.4f');

h0Label=uilabel(geomPanel,'Text','Element Size [m]','Position',[20 178 180 22]);
uilabel(geomPanel,'Text',char(9432),'Position',[204 178 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','Target element edge length in display units. Smaller = finer mesh.');
h0Field=uieditfield(geomPanel,'numeric','Position',[20 153 200 22],'Value',0.5,'ValueDisplayFormat','%.4f');

uilabel(geomPanel,'Text','Element Type','Position',[20 125 180 22]);
uilabel(geomPanel,'Text',char(9432),'Position',[204 125 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','T3 = linear triangle (only one supported rn)');
elementTypeDropDown=uidropdown(geomPanel,...
    'Items',{'T3','T6','Q4','Q8','Q9'},'Value','T3','Position',[20 100 200 22]);

uibutton(geomPanel,'push','Text','Mesh Refinement Regions',...
    'Position',[20 52 200 32],'BackgroundColor',[0.15 0.45 0.85],'FontColor','white',...
    'Tooltip','Open the mesh refinement UI. Requires an already-generated mesh.',...
    'ButtonPushedFcn',@enterMeshRefinementRegionsCallback);
uilabel(geomPanel,'Text',char(9432),'Position',[224 57 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','Generate/load the overall mesh first. Then use this panel to pick vertices, edges, mesh nodes, or free points for local refinement.');

uitextarea(geomPanel,'Position',[20 8 200 35],'Editable','off','FontSize',9,...
    'Value',{'Generate/load the overall mesh first, then define local refinement regions.'});

% =========================================================================
% Mesh refinement full-left-panel mode
% =========================================================================
meshRefPanel=uipanel(leftPanel,'Title','Mesh Refinement Regions',...
    'Position',[10 10 255 610],'Visible','off');

uilabel(meshRefPanel,'Text','Pick a mesh/geometry target, then add a local refinement region.',...
    'Position',[12 548 225 35],'WordWrap','on','FontColor',[0.25 0.25 0.25]);

uilabel(meshRefPanel,'Text','Selection Type','Position',[12 515 150 20],'FontWeight','bold');
refSelectionTypeDropDown=uidropdown(meshRefPanel,...
    'Items',{'Vertex','Edge','Point'},'Value','Vertex',...
    'Position',[12 490 220 24],...
    'ValueChangedFcn',@refSelectionTypeChangedCallback);

uilabel(meshRefPanel,'Text','Click directly on the Mesh / Status view to select the active entity type.',...
    'Position',[12 448 220 36],'WordWrap','on','FontColor',[0.25 0.25 0.25]);

% Kept hidden so older callback helpers remain harmless if called internally.
refPickBtn=uibutton(meshRefPanel,'push','Text','Pick Entity',...
    'Position',[12 452 220 30],'Visible','off',...
    'ButtonPushedFcn',@toggleRefPickCallback);

uilabel(meshRefPanel,'Text','Selected','Position',[12 418 100 20],'FontWeight','bold');
refSelectedField=uieditfield(meshRefPanel,'text','Position',[12 391 220 24],...
    'Value','(none)','Editable','off','BackgroundColor',[0.95 0.95 0.95]);

refRadiusLabel=uilabel(meshRefPanel,'Text','Radius','Position',[12 358 70 20]);
refRadiusField=uieditfield(meshRefPanel,'numeric','Position',[95 358 95 22],'Value',0.01,'ValueDisplayFormat','%.4f');
refRadiusUnitLabel=uilabel(meshRefPanel,'Text','m','Position',[196 358 30 20]);
uilabel(meshRefPanel,'Text',char(9432),'Position',[224 358 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','For Vertex/Point this is a circular radius. For Edge this is the band thickness measured inward from the selected boundary edge.');

uilabel(meshRefPanel,'Text','Local h','Position',[12 326 70 20]);
refHField=uieditfield(meshRefPanel,'numeric','Position',[95 326 95 22],'Value',0.002,'ValueDisplayFormat','%.4f');
refHUnitLabel=uilabel(meshRefPanel,'Text','m','Position',[196 326 30 20]);
uilabel(meshRefPanel,'Text',char(9432),'Position',[224 326 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','Target element size inside the refinement region, in current display units.');

uibutton(meshRefPanel,'push','Text','Add Refinement Region',...
    'Position',[12 286 220 30],'BackgroundColor',[0.1 0.6 0.2],'FontColor','white',...
    'ButtonPushedFcn',@addSelectedRefinementRegionCallback);

uilabel(meshRefPanel,'Text','Existing Regions','Position',[12 252 150 20],'FontWeight','bold');
refRegionList=uilistbox(meshRefPanel,'Position',[12 115 220 135],...
    'Items',{'No refinement regions defined.'},'ItemsData',0,'Value',0);

uibutton(meshRefPanel,'push','Text','Delete Selected',...
    'Position',[12 78 105 28],'BackgroundColor',[0.75 0.1 0.1],'FontColor','white',...
    'ButtonPushedFcn',@deleteSelectedRefinementCallback);
uibutton(meshRefPanel,'push','Text','Clear All',...
    'Position',[127 78 105 28],'BackgroundColor',[0.75 0.1 0.1],'FontColor','white',...
    'ButtonPushedFcn',@clearAllRefinementsCallback);

uibutton(meshRefPanel,'push','Text','Exit Mesh Refinement Regions',...
    'Position',[12 25 220 34],'BackgroundColor',[0.35 0.35 0.35],'FontColor','white',...
    'ButtonPushedFcn',@exitMeshRefinementRegionsCallback);

% =========================================================================
% Analysis section
% =========================================================================
analysisPanel=uipanel(leftPanel,'Title','Analysis',...
    'Position',[sectionX sectionY sectionW sectionH],'Visible','off');

uibutton(analysisPanel,'push','Text','Solve',...
    'Position',[20 345 180 32],'ButtonPushedFcn',@solveCallback);
uilabel(analysisPanel,'Text',char(9432),'Position',[204 349 20 22],'FontColor',[0.2 0.5 0.9],...
    'Tooltip','Validates inputs and runs the FEA solver.');

uitextarea(analysisPanel,'Position',[15 10 215 310],'Editable','off',...
    'Value',{'Analysis Section','','Current solve performs:',...
    '- material validation','- displacement solve','- model/result storage',...
    '- displacement plotting','',...
    'External post-processing:',...
    '- stress / strain are external',...
    '- func_strain.m computes strain',...
    '- func_stress.m computes stress',...
    '- uses stored BMat when available',...
    '- supports T3/T6/Q4/Q8/Q9 via BMat'});

sectionDropDown.ValueChangedFcn=@switchSection;

% =========================================================================
% Right-side tabs
% =========================================================================
tabGroup=uitabgroup(rightPanel,'Position',[10 10 790 590]);
meshTab  =uitab(tabGroup,'Title','Mesh / Status');
bcLoadTab=uitab(tabGroup,'Title','Boundary Conditions & Loading');
postTab  =uitab(tabGroup,'Title','Post-Processing');

% Mesh tab
ax=uiaxes(meshTab,'Position',[20 170 735 380]);
title(ax,'Mesh View');
xlabel(ax,'$x$','interpreter','latex'); ylabel(ax,'$y$','interpreter','latex');
grid(ax,'on'); axis(ax,'equal'); set(ax,'TickLabelInterpreter','latex');
quietAxesToolbar(ax);
ax.ButtonDownFcn=@meshAxesClickCallback;
ax.PickableParts='all'; ax.HitTest='on';

% Refinement summary strip (thin bar just below main axes)
uilabel(meshTab,'Text','Refinement Regions:',...
    'Position',[20 158 140 14],'FontSize',8,'FontColor',[0.2 0.2 0.2],'FontWeight','bold');
refSummaryBox=uitextarea(meshTab,'Position',[20 130 735 26],...
    'Editable','off','FontSize',8,'Value',{'No refinement regions defined.'});

histAx=uiaxes(meshTab,'Position',[20 10 420 118]);
title(histAx,'Element Quality Distribution');
xlabel(histAx,'Element Quality','interpreter','latex');
ylabel(histAx,'\# Elements','interpreter','latex');
grid(histAx,'on'); set(histAx,'TickLabelInterpreter','latex');
quietAxesToolbar(histAx);

meshStatsBox=uitextarea(meshTab,'Position',[450 10 145 118],'Editable','off',...
    'Value',{'Mesh Stats','','Load a mesh to','see stats.'});

statusBox=uitextarea(meshTab,'Position',[605 10 150 118],'Editable','off',...
    'Value',{'[INFO] GUI started.',...
    '[INFO] Use the dropdown to switch sections.',...
    '[INFO] Load a geometry file to begin.'});

% BC tab
currentMode      ='Constraint';
currentTargetType='Vertex';
selectedTargetType=''; selectedTargetID=[]; selectedTargetPoint=[];
hoverTargetType=''; hoverTargetID=[];
lastHoverKey='';
bcLoadAxLims=[];
currentEdgeDir='xy';
currentPostMode='tiled';
postSelectedResults={'Deformation X'};
postResultListBusy=false;
postHasResults=false;  % true after Plot is pressed at least once
postOverlayEnabled=true;
postProbeEnabled=false;
postProbeDragActive=false;
postProbeDragAx=[];
postProbeDragText=[];
postProbeDragLine=[];
postProbeDragAnchor=[NaN NaN];
postProbeDragOffset=[0 0];
postProbeDragRadius=NaN;

bcHeaderPanel=uipanel(bcLoadTab,'Position',[15 510 755 60],'Title','');
uilabel(bcHeaderPanel,'Text','BC / Loading View',...
    'Position',[15 30 200 22],'FontWeight','bold','FontSize',16);
uilabel(bcHeaderPanel,'Text','Left-click to select target',...
    'Position',[15 10 180 16],'FontSize',10);

uilabel(bcHeaderPanel,'Text','Assignment Mode','Position',[235 38 130 18],'FontWeight','bold');
modeConstraintBtn=uibutton(bcHeaderPanel,'push','Text','Constraint',...
    'Position',[235 10 95 26],'BackgroundColor',[0.3 0.6 1],'FontColor','white',...
    'ButtonPushedFcn',@(~,~) setMode('Constraint'));
modeLoadBtn=uibutton(bcHeaderPanel,'push','Text','Load',...
    'Position',[336 10 80 26],'BackgroundColor',[0.9 0.9 0.9],'FontColor','black',...
    'ButtonPushedFcn',@(~,~) setMode('Load'));

uilabel(bcHeaderPanel,'Text','Select By','Position',[435 38 80 18],'FontWeight','bold');
typeVertexBtn=uibutton(bcHeaderPanel,'push','Text','Vertex',...
    'Position',[435 10 75 26],'BackgroundColor',[0.3 0.6 1],'FontColor','white',...
    'ButtonPushedFcn',@(~,~) setTargetType('Vertex'));
typeEdgeBtn=uibutton(bcHeaderPanel,'push','Text','Edge',...
    'Position',[516 10 70 26],'BackgroundColor',[0.9 0.9 0.9],'FontColor','black',...
    'ButtonPushedFcn',@(~,~) setTargetType('Edge'));
typePointBtn=uibutton(bcHeaderPanel,'push','Text','Point',...
    'Position',[592 10 70 26],'BackgroundColor',[0.9 0.9 0.9],'FontColor','black',...
    'ButtonPushedFcn',@(~,~) setTargetType('Point'));

bcAssignBar=uipanel(bcLoadTab,'Position',[15 458 755 50],'BorderType','line','Title','');
uilabel(bcAssignBar,'Text','Selected:','Position',[8 14 55 22],'FontWeight','bold');
selectedTargetField=uieditfield(bcAssignBar,'text',...
    'Position',[66 14 160 22],'Value','(none)','Editable','off','BackgroundColor',[0.95 0.95 0.95]);
uilabel(bcAssignBar,'Text','Type:','Position',[232 14 33 22]);
bcTypeDropDown=uidropdown(bcAssignBar,...
    'Items',{'Fixed X','Fixed Y','Fixed XY','Deflect X','Deflect Y','Deflect XY'},...
    'Position',[265 14 138 22],'ValueChangedFcn',@bcTypeChangedCallback);

% Val field — shown for simple types
bcValueLabel=uilabel(bcAssignBar,'Text','Value:','Position',[408 14 42 22],'Visible','off','Tag','bcValueLabel');
bcValueField=uieditfield(bcAssignBar,'text','Position',[452 14 80 22],'Value','0','Visible','off');

% Par/perp fields — shown for ∥/⊥ types
parDirLabel =uilabel(bcAssignBar,'Text','∥:','Position',[408 14 24 22],'Visible','off','Tag','parLabel');
bcParField  =uieditfield(bcAssignBar,'text','Position',[434 14 62 22],'Value','0','Visible','off');
perpDirLabel=uilabel(bcAssignBar,'Text','⊥:','Position',[502 14 24 22],'Visible','off','Tag','perpLabel');
bcPerpField =uieditfield(bcAssignBar,'text','Position',[528 14 62 22],'Value','0','Visible','off');
bcParPerpHint=uilabel(bcAssignBar,'Text','(+⊥=out)',...
    'Position',[594 14 44 22],'FontColor',[0.45 0.45 0.45],'FontSize',8,'Visible','off','Tag','perpHint');

% Curved edge warning — shown instead of Value/par/perp fields when a curved edge is selected

% Action buttons — fixed at right edge
uibutton(bcAssignBar,'push','Text','Apply',...
    'Position',[640 12 65 26],'BackgroundColor',[0.1 0.6 0.2],'FontColor','white',...
    'ButtonPushedFcn',@applyBCCallback);
uibutton(bcAssignBar,'push','Text','Del',...
    'Position',[709 12 24 26],'BackgroundColor',[0.75 0.1 0.1],'FontColor','white',...
    'FontSize',8,'Tooltip','Delete BC at selected target','ButtonPushedFcn',@deleteBCCallback);
uibutton(bcAssignBar,'push','Text','✕',...
    'Position',[735 12 16 26],'BackgroundColor',[0.88 0.88 0.88],'FontColor',[0.3 0.3 0.3],...
    'FontSize',8,'Tooltip','Clear selection','ButtonPushedFcn',@clearSelectionCallback);

% Hidden legacy direction widgets
edgeDirLabel    =uilabel(bcAssignBar,'Text','','Position',[0 -99 1 1],'Visible','off');
edgeDirXYBtn    =uibutton(bcAssignBar,'push','Text','','Position',[0 -99 1 1],'Visible','off','ButtonPushedFcn',@(~,~) setEdgeDir('xy'));
edgeDirParPerpBtn=uibutton(bcAssignBar,'push','Text','','Position',[0 -99 1 1],'Visible','off','ButtonPushedFcn',@(~,~) setEdgeDir('parperp'));

bcSummaryPanel=uipanel(bcLoadTab,'Title','Applied BCs & Loads','Position',[15 20 755 210]);
uibutton(bcSummaryPanel,'push','Text','Clear All',...
    'Position',[650 158 90 24],'BackgroundColor',[0.75 0.1 0.1],'FontColor','white',...
    'ButtonPushedFcn',@clearAllBCsCallback);
bcSummaryTable=uitextarea(bcSummaryPanel,'Position',[5 5 640 178],...
    'Editable','off','Value',{'No BCs applied yet.'});
uilabel(bcSummaryPanel,'Text','Entry #:','Position',[650 128 90 22],...
    'HorizontalAlignment','center','FontWeight','bold');
bcDeleteIndexField=uieditfield(bcSummaryPanel,'text',...
    'Position',[655 103 80 22],'Value','','Placeholder','e.g. 2');
uibutton(bcSummaryPanel,'push','Text','Edit #',...
    'Position',[650 75 90 24],'BackgroundColor',[0.15 0.45 0.85],'FontColor','white',...
    'Tooltip','Load this BC back into the assignment bar to tweak it','ButtonPushedFcn',@editByIndexCallback);
uibutton(bcSummaryPanel,'push','Text','Delete #',...
    'Position',[650 47 90 24],'BackgroundColor',[0.75 0.1 0.1],'FontColor','white',...
    'ButtonPushedFcn',@deleteByIndexCallback);

bcLoadAx=uiaxes(bcLoadTab,'Position',[35 243 725 205]);
bcLoadAx.ButtonDownFcn=@bcLoadAxesClickCallback;
bcLoadAx.PickableParts='all'; bcLoadAx.HitTest='on';
xlabel(bcLoadAx,'$x$','interpreter','latex'); ylabel(bcLoadAx,'$y$','interpreter','latex');
grid(bcLoadAx,'on'); axis(bcLoadAx,'normal'); set(bcLoadAx,'TickLabelInterpreter','latex');
bcLoadAx.DataAspectRatioMode='auto';
bcLoadAx.PlotBoxAspectRatioMode='auto';
quietAxesToolbar(bcLoadAx);

% Post-processing tab
% Compact left control stack.  The results list is only tall enough for the
% result names, so the left side no longer has a large empty white block.
uilabel(postTab,'Text','Results','Position',[10 548 60 20],'FontWeight','bold');
uilabel(postTab,'Text',char(9432),'Position',[64 548 20 20],...
    'FontColor',[0.2 0.5 0.9],...
    'Tooltip','Click result items to toggle them on/off. Ctrl/Cmd-click also selects non-adjacent results; Shift-click selects a range. Press Plot when ready.');
uibutton(postTab,'push','Text','Clear',...
    'Position',[115 546 70 22],...
    'Tooltip','Deselect all post-processing results.',...
    'ButtonPushedFcn',@clearPostResultsCallback);
postResultList=uilistbox(postTab,...
    'Items',{'Deformation X','Deformation Y',...
             'Stress X','Stress Y','Stress XY (Shear)',...
             'Strain X','Strain Y','Strain XY (Shear)'},...
    'Multiselect','on','Value',postSelectedResults,'Position',[10 374 175 170],...
    'ValueChangedFcn',@postResultListChangedCallback);
uilabel(postTab,'Text','click = toggle, ctrl/shift also works',...
    'Position',[10 356 175 16],'FontSize',8,'FontColor',[0.5 0.5 0.5]);
uilabel(postTab,'Text','View Mode','Position',[10 330 175 20],'FontWeight','bold');
postModeTiledBtn=uibutton(postTab,'push','Text','Tiled',...
    'Position',[10 303 82 26],'BackgroundColor',[0.3 0.6 1],'FontColor','white',...
    'ButtonPushedFcn',@(~,~) setPostMode('tiled'));
postModeTabBtn=uibutton(postTab,'push','Text','Sub-Tabs',...
    'Position',[98 303 87 26],'BackgroundColor',[0.9 0.9 0.9],'FontColor','black',...
    'ButtonPushedFcn',@(~,~) setPostMode('subtab'));
uibutton(postTab,'push','Text','▶  Plot',...
    'Position',[10 260 175 34],'BackgroundColor',[0.15 0.45 0.85],'FontColor','white',...
    'FontSize',13,'FontWeight','bold','ButtonPushedFcn',@plotResultCallback);

uilabel(postTab,'Text','Plot Options','Position',[10 223 175 20],'FontWeight','bold');
uitextarea(postTab,'Position',[10 178 175 42],'Editable','off','FontSize',9,...
    'Value',{'Color shows the selected result value.','Tiles fill the view; model shape is preserved.'});
postUnitsLabel=uilabel(postTab,'Text',sprintf('Display Units: %s',getDisplayUnit()),...
    'Position',[10 158 175 18],'FontWeight','bold','FontColor',[0.25 0.25 0.25]);

uilabel(postTab,'Text','Original Mesh Overlay','Position',[10 132 175 20],'FontWeight','bold');
postOverlayOnBtn=uibutton(postTab,'push','Text','On',...
    'Position',[10 105 82 26],'BackgroundColor',[0.3 0.6 1],'FontColor','white',...
    'Tooltip','Show the undeformed original mesh on top of the post-processing plot.',...
    'ButtonPushedFcn',@(~,~) setPostOverlayMode(true));
postOverlayOffBtn=uibutton(postTab,'push','Text','Off',...
    'Position',[98 105 87 26],'BackgroundColor',[0.9 0.9 0.9],'FontColor','black',...
    'Tooltip','Hide the undeformed original mesh overlay.',...
    'ButtonPushedFcn',@(~,~) setPostOverlayMode(false));

uilabel(postTab,'Text','Value Probe','Position',[10 75 175 20],'FontWeight','bold');
postProbeOnBtn=uibutton(postTab,'push','Text','On',...
    'Position',[10 48 82 26],'BackgroundColor',[0.9 0.9 0.9],'FontColor','black',...
    'Tooltip','Turn on click-to-read result values on the contour plot. Drag the data box after placing it.',...
    'ButtonPushedFcn',@(~,~) setPostProbeMode(true));
postProbeOffBtn=uibutton(postTab,'push','Text','Off',...
    'Position',[98 48 87 26],'BackgroundColor',[0.3 0.6 1],'FontColor','white',...
    'Tooltip','Turn off click-to-read result values.',...
    'ButtonPushedFcn',@(~,~) setPostProbeMode(false));
postProbeLabel=uilabel(postTab,'Text','Probe off.',...
    'Position',[10 22 175 20],'FontSize',9,'FontColor',[0.35 0.35 0.35]);

postDisplayPanel=uipanel(postTab,'Units','normalized','Position',[0.26 0.01 0.73 0.98],'BorderType','line');
postAx=uiaxes(postDisplayPanel,'Units','normalized','Position',[0.01 0.01 0.97 0.97]);
title(postAx,'Hit Plot to display results');
xlabel(postAx,'$x$','interpreter','latex'); ylabel(postAx,'$y$','interpreter','latex');
grid(postAx,'on'); axis(postAx,'normal'); set(postAx,'TickLabelInterpreter','latex');
colormap(postAx,jet(256));
quietAxesToolbar(postAx);

materialChangedCallback();
analysisTypeChangedCallback();
fig.WindowButtonMotionFcn=@mouseMoveCallback;
fig.WindowButtonUpFcn=@endPostProbeDataTipDrag;

% =========================================================================
% CALLBACKS
% =========================================================================

    function onFigClose(~,~), delete(fig); end

    function rgb = uiColor(c)
        % Convert the top-of-file UI color to an RGB triple for components
        % that do not consistently accept hex strings across MATLAB versions.
        if isnumeric(c) && numel(c)==3
            rgb = c;
            return;
        end
        if isstring(c), c = char(c); end
        if ischar(c) && startsWith(c,'#') && numel(c)==7
            rgb = [hex2dec(c(2:3)), hex2dec(c(4:5)), hex2dec(c(6:7))]/255;
        else
            rgb = [0.33 0.35 0.36];
        end
    end

    function analysisTypeChangedCallback(~,~)
        switch analysisTypeDropDown.Value
            case 'Plane Stress',  engInfo.Value={'Plane Stress: thin parts, out-of-plane stress = 0.'}; logMessage('Analysis type set to Plane Stress.');
            case 'Plane Strain',  engInfo.Value={'Plane Strain: long bodies, out-of-plane strain = 0.'}; logMessage('Analysis type set to Plane Strain.');
            case 'Axisymmetric',  engInfo.Value={'Axisymmetric: bodies of revolution.'}; logMessage('Analysis type set to Axisymmetric.');
            otherwise,            engInfo.Value={'Select an analysis type above.'};
        end
    end

    function logMessage(msg)
        current=statusBox.Value;
        current{end+1}=sprintf('[%s] %s',datestr(now,'HH:MM:SS'),msg);
        statusBox.Value=current; drawnow;
    end

    function beginComputation(label)
        if isComputing
            uialert(fig,'A computation is already running.','Busy');
            error('BUSY:ComputationRunning','A computation is already running.');
        end
        isComputing=true; stopRequested=false; preComputeModel=model;
        setProcessProgress(0,label); setRunStopButton('stop');
        processHintLabel.Text='Computation running...';
        logMessage([label ' started.']); drawnow;
    end

    function updateProgress(percent,msg)
        if stopRequested, error('USER_STOPPED:ComputationStopped','Computation stopped by user.'); end
        setProcessProgress(percent,msg); logMessage(msg); drawnow;
    end

    function finishComputation(msg)
        setProcessProgress(100,msg); setRunStopButton('go');
        processHintLabel.Text='Ready to continue.';
        isComputing=false; stopRequested=false; preComputeModel=[];
        logMessage(msg); drawnow;
    end

    function failComputation(err)
        savedResults=model.results;
        if ~isempty(preComputeModel), model=preComputeModel; end
        if isfield(savedResults,'Deformation')&&~isempty(savedResults.Deformation), model.results=savedResults; end
        setProcessProgress(0,'Stopped. State restored.'); setRunStopButton('go');
        processHintLabel.Text='Previous state restored.';
        isComputing=false; stopRequested=false; preComputeModel=[];
        logMessage(['ERROR: ' err.message]);
        if ~strcmp(err.identifier,'USER_STOPPED:ComputationStopped')
            uialert(fig,['Computation stopped or failed. Previous state restored.' newline newline err.message],'Computation Error');
        end
        drawnow;
    end

    function runStopButtonCallback(~,~)
        if isComputing
            stopRequested=true; processLabel.Text='Stopping...';
            processHintLabel.Text='Stopping after current step...';
            setRunStopButton('stop'); logMessage('Stop requested by user.');
        end
        drawnow;
    end

    function setRunStopButton(mode)
        if strcmp(mode,'stop')
            runStopBtn.Text=char(9632); runStopBtn.BackgroundColor=[0.85 0.1 0.1];
            runStopBtn.Tooltip='Stop current computation';
        else
            runStopBtn.Text=char(9654); runStopBtn.BackgroundColor=[0.1 0.65 0.2];
            runStopBtn.Tooltip='Ready';
        end
        runStopBtn.FontColor='white';
    end

    function setProcessProgress(percent,msg)
        percent=max(0,min(100,percent)); drawnow limitrate;
        % processBarTrack is in a grid layout — Position may not reflect
        % actual rendered size. Use InnerPosition if available, else fallback.
        try
            tp=processBarTrack.InnerPosition;
        catch
            tp=processBarTrack.Position;
        end
        trackW=max(10,tp(3)); trackH=max(8,tp(4));
        fillW=max(1,round((trackW-2)*percent/100));
        fillH=max(1,trackH-2);
        processBarFill.Position=[1 1 fillW fillH];
        processLabel.Text=msg; processPercentLabel.Text=sprintf('%.0f%%',percent); drawnow;
    end

    function switchSection(src,~)
        if strcmp(leftPanelMode,'meshRefinement'), return; end
        engPanel.Visible='off'; geomPanel.Visible='off'; analysisPanel.Visible='off';
        switch src.Value
            case 'Engineering Data', engPanel.Visible='on';
            case 'Geometry / Mesh',  geomPanel.Visible='on';
            case 'Analysis',         analysisPanel.Visible='on';
        end
        if strcmp(tabGroup.SelectedTab.Title,'Boundary Conditions & Loading')
            drawBCLoadAx(); updateBCSummary();
        end
    end

    function showStandardLeftPanel()
        leftPanelMode='standard';
        meshRefPanel.Visible='off';
        sectionLabel.Visible='on'; sectionDropDown.Visible='on'; progressPanel.Visible='on';
        engPanel.Visible='off'; geomPanel.Visible='off'; analysisPanel.Visible='off';
        switch sectionDropDown.Value
            case 'Engineering Data', engPanel.Visible='on';
            case 'Geometry / Mesh',  geomPanel.Visible='on';
            case 'Analysis',         analysisPanel.Visible='on';
        end
    end

    function showMeshRefinementLeftPanel()
        leftPanelMode='meshRefinement';
        sectionLabel.Visible='off'; sectionDropDown.Visible='off'; progressPanel.Visible='off';
        engPanel.Visible='off'; geomPanel.Visible='off'; analysisPanel.Visible='off';
        meshRefPanel.Visible='on';
        tabGroup.SelectedTab=meshTab;
        updateRefinementPanelState();
        redrawMeshAxWithRefinements();
    end

    function materialChangedCallback(~,~)
        isIn=strcmp(getDisplayUnit(),'in');
        switch materialDropDown.Value
            case 'Structural Steel'
                if isIn
                    setMaterialFields(30.5e6, 0.30, 0.284, false); % psi, lb/in^3
                else
                    setMaterialFields(210e9,  0.30, 7850,  false); % Pa, kg/m^3
                end
                logMessage('Material set to Structural Steel.');
            case 'Nylon'
                if isIn
                    setMaterialFields(391e3,  0.39, 0.0415, false); % psi, lb/in^3
                else
                    setMaterialFields(2.7e9,  0.39, 1150,   false); % Pa, kg/m^3
                end
                logMessage('Material set to Nylon.');
            case 'Custom Material'
                setMaterialFields([],[],[],true);
                logMessage('Custom material selected. Enter properties manually.');
        end
    end

    function addPadding(targetAx)
        if isempty(nodesG), return; end
        xl=xlim(targetAx); yl=ylim(targetAx);
        xPad=0.10*max(diff(xl),eps); yPad=0.10*max(diff(yl),eps);
        xlim(targetAx,[xl(1)-xPad xl(2)+xPad]); ylim(targetAx,[yl(1)-yPad yl(2)+yPad]);
    end

    function s=getDisplayScale()
        switch displayUnitsDropDown.Value
            case 'm',  s=1; case 'cm', s=100; case 'mm', s=1000; case 'in', s=39.3701; otherwise, s=1;
        end
    end

    function u=getDisplayUnit(), u=displayUnitsDropDown.Value; end

    function fu=getForceUnit()
        if strcmp(getDisplayUnit(),'in'), fu='lbf'; else, fu='N'; end
    end

    function mu=getMomentUnit()
        if strcmp(getDisplayUnit(),'in'), mu='lbf·in'; else, mu='Nm'; end
    end

    function pu=getPressureUnit()
        if strcmp(getDisplayUnit(),'in'), pu='psi'; else, pu='Pa'; end
    end

    function du=getDensityUnit()
        if strcmp(getDisplayUnit(),'in'), du='lb/in^3'; else, du='kg/m^3'; end
    end

    function updateEngPanelUnits()
        % Update labels
        if strcmp(getDisplayUnit(),'in')
            eLabelText.Text      ='Young''s Modulus E (psi)';
            densityLabelText.Text='Density (lb/in^3)';
        else
            eLabelText.Text      ='Young''s Modulus E (Pa)';
            densityLabelText.Text='Density (kg/m^3)';
        end
        % If a preset material is selected, reload its values in the new units
        % so the numbers shown are correct for the current unit system.
        if ~strcmp(materialDropDown.Value,'Custom Material')
            materialChangedCallback();
        end
    end

    function displayUnitsChangedCallback(~,~)
        u=getDisplayUnit(); newS=getDisplayScale();
        thicknessLabel.Text=sprintf('Thickness [%s]',u);
        h0Label.Text=sprintf('Element Size [%s]',u);
        refRadiusUnitLabel.Text=u;
        refHUnitLabel.Text=u;
        % Convert all display-unit fields: value_new = value_old * (newScale/oldScale)
        ratio=newS/prevDisplayScale;
        h0Field.Value        =sigfig(h0Field.Value        *ratio,4);
        thicknessField.Value =sigfig(thicknessField.Value *ratio,4);
        refRadiusField.Value =sigfig(refRadiusField.Value *ratio,4);
        refHField.Value      =sigfig(refHField.Value      *ratio,4);
        prevDisplayScale=newS;
        updateAllAxisLabels();
        updateEngPanelUnits();
        bcTypeChangedCallback();
        % Refresh load dropdown if currently in Load mode
        if strcmp(currentMode,'Load'), rebuildLoadDropdown(); end
        parDirLabel.Text=sprintf('∥ (%s):',getForceUnit());
        perpDirLabel.Text=sprintf('⊥ (%s):',getForceUnit());
        if exist('postUnitsLabel','var') && isvalid(postUnitsLabel)
            postUnitsLabel.Text=sprintf('Display Units: %s',u);
        end
        if ~isempty(nodesG), drawBCLoadAx(); updateBCSummary(); end

        % Changing display units changes the visible meaning of geometry,
        % thickness, loads, and post-processing readouts.  If the model has
        % already been solved or plotted, warn the user with the same GUI
        % popup style used elsewhere instead of silently leaving stale output.
        hasSolvedResults = isfield(model,'results') && isfield(model.results,'Deformation') && ...
            ~isempty(model.results.Deformation);
        if hasSolvedResults || postHasResults
            uialert(fig, ...
                sprintf(['Display units changed to %s.\n\n' ...
                'This model has already been solved and/or post-processed. Please run Solve again, then click Plot again in Post-Processing.\n\n' ...
                'That refreshes the post-processing values, plot titles, probe readouts, and displayed units.'],u), ...
                'Units Changed');
            logMessage('Units changed after solved/post-processed results existed. User should solve and plot again.');
        end
        logMessage(sprintf('Display units changed to %s.',u));
    end

    function updateAllAxisLabels()
        u=getDisplayUnit(); s=getDisplayScale();

        % Main mesh/status axes.
        if exist('ax','var') && ~isempty(ax) && isvalid(ax)
            xlabel(ax,sprintf('$x$ [%s]',u),'interpreter','latex');
            ylabel(ax,sprintf('$y$ [%s]',u),'interpreter','latex');
            scaleAxTicks(ax,s);
        end

        % BC/loading axes.
        if exist('bcLoadAx','var') && ~isempty(bcLoadAx) && isvalid(bcLoadAx)
            xlabel(bcLoadAx,sprintf('$x$ [%s]',u),'interpreter','latex');
            ylabel(bcLoadAx,sprintf('$y$ [%s]',u),'interpreter','latex');
            scaleAxTicks(bcLoadAx,s);
        end

        % Post-processing axes are dynamic.  The original postAx is deleted
        % whenever the user plots tiled/sub-tab results, so directly calling
        % xlabel(postAx,...) can hit an invalid/deleted axes handle.  Instead,
        % update any currently existing post-processing axes.
        postAxes = [];
        try
            if exist('postDisplayPanel','var') && ~isempty(postDisplayPanel) && isvalid(postDisplayPanel)
                postAxes = findall(postDisplayPanel,'Type','axes');
            end
        catch
            postAxes = [];
        end
        for ii = 1:numel(postAxes)
            try
                if isvalid(postAxes(ii))
                    xlabel(postAxes(ii),sprintf('$x$ [%s]',u),'interpreter','latex');
                    ylabel(postAxes(ii),sprintf('$y$ [%s]',u),'interpreter','latex');
                    scaleAxTicks(postAxes(ii),s);
                end
            catch
            end
        end
    end

    function scaleAxTicks(targetAx,s)
        if isempty(targetAx)||~isvalid(targetAx), return; end
        xl=xlim(targetAx); yl=ylim(targetAx);
        if isequal(xl,[0 1])&&isequal(yl,[0 1]), return; end
        % Reset to auto first so we always read the raw metre-based tick positions
        xticklabels(targetAx,'auto'); yticklabels(targetAx,'auto');
        xt=xticks(targetAx); yt=yticks(targetAx);
        if ~isempty(xt), xticklabels(targetAx,arrayfun(@(v)sprintf('%.4g',v*s),xt,'UniformOutput',false)); end
        if ~isempty(yt), yticklabels(targetAx,arrayfun(@(v)sprintf('%.4g',v*s),yt,'UniformOutput',false)); end
    end

    function setMaterialFields(E,nu,rho,editable)
        if ~editable, eField.Value=E; nuField.Value=nu; densityField.Value=rho; end
        onOff=matlab.lang.OnOffSwitchState(editable);
        eField.Editable=onOff; nuField.Editable=onOff; densityField.Editable=onOff;
        bg=[0.9 0.9 0.9]+double(editable)*[0.1 0.1 0.1];
        eField.BackgroundColor=bg; nuField.BackgroundColor=bg; densityField.BackgroundColor=bg;
    end

    % =========================================================================
    % Load geometry
    % =========================================================================
    function loadGeoCallback(~,~)
        [partFileName,partPath]=uigetfile('*.dxf','Select DXF geometry file');
        if isequal(partFileName,0), logMessage('Geometry loading canceled.'); return; end
        fullPartName=fullfile(partPath,partFileName);

        model.mesh=[]; model.results=struct();
        model.constraints=struct('type',{},'x_mag',{},'y_mag',{},'affected_nodes',{},'point',{},'regionType',{},'regionID',{});
        model.loads      =struct('type',{},'x_mag',{},'y_mag',{},'affected_nodes',{},'point',{},'regionType',{},'regionID',{});
        model.refinementRegions=struct('center',{},'radius',{},'h_target',{},'vertices',{},...
            'point',{},'regionType',{},'regionID',{},'sourceType',{},'sourceID',{},...
            'affected_nodes',{},'shapeType',{},'edgePolyline',{});
        refPickCount=0; clearRefinementSelection(); cancelRefPickMode();

        selectedTargetField.Value='(click axes to select)';
        selectedTargetType=''; selectedTargetID=[]; selectedTargetPoint=[];
        hoverTargetType=''; hoverTargetID=[]; lastHoverKey='';
        bcLoadAxLims=[];
        resetAxes_ = [ax, bcLoadAx];
        if exist('postAx','var') && ~isempty(postAx) && isvalid(postAx)
            resetAxes_ = [resetAxes_, postAx];
        else
            try
                resetAxes_ = [resetAxes_, findall(postDisplayPanel,'Type','axes')'];
            catch
            end
        end
        for resetAx_=resetAxes_
            if isempty(resetAx_) || ~isvalid(resetAx_), continue; end
            cla(resetAx_);
            xticks(resetAx_,'auto'); yticks(resetAx_,'auto');
            xticklabels(resetAx_,'auto'); yticklabels(resetAx_,'auto');
            xlim(resetAx_,'auto'); ylim(resetAx_,'auto');
        end

        [units,scale]                                   =getDXFUnits(fullPartName);
        [nodes,edges,edgeType,midpoints,loops,loopType] =dxfToGeomCircle(fullPartName);
        nodes=nodes*scale; midpoints=midpoints*scale;

        unitsG=units; scaleG=scale; nodesG=nodes; edgesG=edges;
        edgeTypeG=edgeType; midpointsG=midpoints; loopsG=loops; loopTypeG=loopType;

        logMessage(['Loaded: ' partFileName]);
        prevDisplayScale=getDisplayScale();
        hold(ax,'on'); copyGeometryToAxes(ax,'Geometry View'); hold(ax,'off');
        addPadding(ax);

        xRange=max(nodesG(:,1))-min(nodesG(:,1));
        yRange=max(nodesG(:,2))-min(nodesG(:,2));
        defaultH0_m=0.1*min(max(xRange,eps),max(yRange,eps));
        h0Field.Value=sigfig(defaultH0_m*getDisplayScale(),4);
        refRadiusField.Value=sigfig(defaultH0_m*getDisplayScale()*1.5,4);
        refHField.Value=sigfig(defaultH0_m*getDisplayScale()*0.3,4);
        logMessage(sprintf('Default element size set to %.4g %s.',h0Field.Value,getDisplayUnit()));

        if strcmp(leftPanelMode,'meshRefinement')
            sectionDropDown.Value='Geometry / Mesh';
            showStandardLeftPanel();
        end
        updateAllAxisLabels();
        updateRefSummary(); updateRefinementPanelState();
        drawBCLoadAx(); updateBCSummary();
        tabGroup.SelectedTab=meshTab;
    end

    % =========================================================================
    % Load mesh
    % =========================================================================
    function loadMeshCallback(~,~)
        if isempty(nodesG)
            uialert(fig,'Load a geometry file first.','No Geometry');
            logMessage('Mesh generation failed: no geometry loaded.'); return;
        end
        try
            beginComputation('Mesh generation');
            updateProgress(5,'Reading mesh settings...');
            h0=h0Field.Value;
            if isempty(h0)||h0<=0, error('Element size must be greater than 0.'); end
            h0=h0/getDisplayScale();
            logMessage(sprintf('h0 = %.6g m (entered %.6g %s)',h0,h0*getDisplayScale(),getDisplayUnit()));

            updateProgress(15,'Generating mesh...');
            drawnow;
            if stopRequested, error('USER_STOPPED:ComputationStopped','Computation stopped by user.'); end

            [t,p]=generateMesh(nodesG,edgesG,edgeTypeG,midpointsG,loopsG,loopTypeG,scaleG,h0);

            if isempty(t)||size(t,1)==0
                error('Element size (%.4g %s) too large — no elements generated.',h0*getDisplayScale(),getDisplayUnit()); end
            if size(t,1)<3
                error('Only %d element(s) at %.4g %s — too coarse.',size(t,1),h0*getDisplayScale(),getDisplayUnit()); end
            areas=zeros(size(t,1),1);
            for ei=1:size(t,1)
                x1=p(t(ei,1),1); y1=p(t(ei,1),2);
                x2=p(t(ei,2),1); y2=p(t(ei,2),2);
                x3=p(t(ei,3),1); y3=p(t(ei,3),2);
                areas(ei)=0.5*abs((x2-x1)*(y3-y1)-(x3-x1)*(y2-y1));
            end
            if any(areas<1e-20)
                error('Degenerate elements at %.4g %s. Try a different size.',h0*getDisplayScale(),getDisplayUnit()); end
            medEdgeLen=median(sqrt(sum((p(t(:,1),:)-p(t(:,2),:)).^2,2)));
            if medEdgeLen>h0*3
                error('Elements %.1fx larger than requested h0=%.4g %s.',medEdgeLen/h0,h0*getDisplayScale(),getDisplayUnit()); end

            updateProgress(60,'Storing mesh...');
            nElem=size(t,1); nNodes=size(p,1);
            model.mesh.connectivity=t;
            model.mesh.xcoords=p(:,1); model.mesh.ycoords=p(:,2);
            model.mesh.elementType=elementTypeDropDown.Value;
            logMessage(sprintf('Stored %d elements, %d nodes.',nElem,size(p,1)));

            updateProgress(75,'Drawing mesh...');
            cla(ax);
            xticks(ax,'auto'); yticks(ax,'auto');
            xticklabels(ax,'auto'); yticklabels(ax,'auto');
            xlim(ax,'auto'); ylim(ax,'auto');
            cla(bcLoadAx);
            xticks(bcLoadAx,'auto'); yticks(bcLoadAx,'auto');
            xticklabels(bcLoadAx,'auto'); yticklabels(bcLoadAx,'auto');
            xlim(bcLoadAx,'auto'); ylim(bcLoadAx,'auto');
            hold(ax,'on');
            copyGeometryToAxes(ax,'Geometry and Mesh View');
            for i=1:nElem
                triIdx=[t(i,1),t(i,2),t(i,3),t(i,1)];
                plot(ax,p(triIdx,1),p(triIdx,2),'-',...
                    'Color',couleur,'LineWidth',0.55,'HitTest','off','PickableParts','none');
            end
            drawRefinementRegionsOnAx();
            title(ax,'Geometry and Mesh View');
            xlabel(ax,'$x$','interpreter','latex'); ylabel(ax,'$y$','interpreter','latex');
            grid(ax,'on'); axis(ax,'equal'); set(ax,'TickLabelInterpreter','latex');
            addPadding(ax);
            hold(ax,'off');

            updateProgress(90,'Computing mesh quality...');
            plotMeshQualityHistogram(t,p,h0);
            tabGroup.SelectedTab=meshTab;
            updateProgress(95,'Updating BC view...');
            updateAllAxisLabels();
            drawBCLoadAx(); updateBCSummary();
            updateRefinementPanelState();
            finishComputation('Mesh generated.');
        catch err
            failComputation(err);
        end
    end

    % =========================================================================
    % Mesh refinement regions full-panel callbacks/helpers
    % =========================================================================
    function enterMeshRefinementRegionsCallback(~,~)
        if isempty(model.mesh)
            uialert(fig,'Generate or load a mesh first before defining mesh refinement regions.','Mesh Required');
            logMessage('Mesh refinement panel blocked: no mesh exists yet.');
            return;
        end
        showMeshRefinementLeftPanel();
        logMessage('Entered Mesh Refinement Regions mode.');
    end

    function exitMeshRefinementRegionsCallback(~,~)
        cancelRefPickMode();
        clearRefinementSelection();
        clearRefinementHover();
        sectionDropDown.Value='Geometry / Mesh';
        showStandardLeftPanel();
        redrawMeshAxWithRefinements();
        logMessage('Exited Mesh Refinement Regions mode.');
    end

    function refSelectionTypeChangedCallback(~,~)
        cancelRefPickMode();
        clearRefinementSelection();
        clearRefinementHover();
        updateRefinementPanelState();
        redrawMeshAxWithRefinements();
        logMessage(['Refinement selection type set to: ' refSelectionTypeDropDown.Value]);
    end

    function toggleRefPickCallback(~,~)
        if isempty(model.mesh)
            uialert(fig,'Generate or load a mesh first before defining mesh refinement regions.','Mesh Required'); return; end
        if refPickActive, cancelRefPickMode();
        else, activateRefPickMode(); end
    end

    function activateRefPickMode()
        refPickActive=true;
        refPickBtn.Text='Cancel Pick'; refPickBtn.BackgroundColor=[0.8 0.4 0];
        tabGroup.SelectedTab=meshTab;
        logMessage(sprintf('Refinement pick active — click the Mesh/Status axes to pick a %s.',refSelectionTypeDropDown.Value));
    end

    function cancelRefPickMode()
        refPickActive=false;
        if exist('refPickBtn','var')&&isvalid(refPickBtn)
            refPickBtn.Text='Pick Entity'; refPickBtn.BackgroundColor=[0.2 0.55 0.2];
        end
    end

    function clearRefinementSelection()
        refSelectedType=''; refSelectedID=[]; refSelectedPoint=[]; refSelectedNodes=[];
        if exist('refSelectedField','var')&&isvalid(refSelectedField)
            refSelectedField.Value='(none)';
        end
    end

    function clearRefinementHover()
        refHoverType=''; refHoverID=[]; refLastHoverKey='';
    end

    function meshAxesClickCallback(~,~)
        % Mesh refinement mode behaves like the BC/Loading picker:
        % no separate "Pick Entity" button is required. The dropdown controls
        % what the next click selects.
        if ~strcmp(leftPanelMode,'meshRefinement')
            return;
        end
        if isempty(model.mesh)
            uialert(fig,'Generate or load a mesh first.','Mesh Required');
            return;
        end
        cp=ax.CurrentPoint; cx_m=cp(1,1); cy_m=cp(1,2);
        if ~pointIsInsideTargetAxes(ax,cx_m,cy_m), return; end
        pickRefinementTargetAtPoint(cx_m,cy_m,true);
        clearRefinementHover();
        redrawMeshAxWithRefinements();
        updateRefinementPanelState();
    end

    function [targetType,targetID,targetPoint,targetNodes,displayText,ok,msg]=resolveSelectableTargetAtPoint(requestedType,xClick,yClick,targetAx)
        % Shared picker used by both:
        %   1) Boundary Conditions & Loading
        %   2) Mesh Refinement Regions
        targetType=''; targetID=[]; targetPoint=[]; targetNodes=[];
        displayText='(none)'; ok=false; msg='';

        switch requestedType
            case 'Vertex'
                if isempty(nodesG)
                    msg='Load a geometry first.'; displayText='(no geometry)'; return;
                end
                dists=hypot(nodesG(:,1)-xClick,nodesG(:,2)-yClick); [~,idx]=min(dists);
                targetType='Vertex'; targetID=idx; targetPoint=nodesG(idx,:);
                if ~isempty(model.mesh)
                    targetNodes=resolveMeshNodes('Vertex',idx,targetPoint);
                end
                displayText=sprintf('Vertex %d (%.4f,%.4f)',idx,targetPoint(1),targetPoint(2));
                ok=true;

            case 'Edge'
                if isempty(edgesG)
                    msg='Load a geometry first.'; displayText='(no edges)'; return;
                end
                [idx,distToEdge]=nearestEdgeIndexOnAxes(targetAx,xClick,yClick);
                clickTol=edgePickToleranceOnAxes(targetAx)*3;
                if isempty(idx)||isinf(distToEdge)||distToEdge>clickTol
                    msg='Click closer to an edge.'; displayText='(click closer to an edge)'; return;
                end

                [xEdge,yEdge]=getEdgePolyline(idx);
                targetType='Edge'; targetID=idx;
                isCircleEdge=~isempty(edgeTypeG)&&edgeTypeG(idx)==3;
                if isCircleEdge
                    eRow2=edgesG(idx,:);
                    nIDs2=eRow2(~isnan(eRow2)&eRow2>0&eRow2<=size(nodesG,1));
                    if numel(nIDs2)>=1
                        targetPoint=nodesG(nIDs2(1),:);
                    else
                        targetPoint=[mean(xEdge) mean(yEdge)];
                    end
                elseif ~isempty(midpointsG)&&idx<=size(midpointsG,1)&&~isnan(midpointsG(idx,1))&&~isnan(midpointsG(idx,2))
                    targetPoint=midpointsG(idx,:);
                else
                    xv=xEdge(~isnan(xEdge)); yv=yEdge(~isnan(yEdge));
                    targetPoint=[mean(xv) mean(yv)];
                end
                if ~isempty(model.mesh)
                    targetNodes=resolveMeshNodes('Edge',idx,targetPoint);
                end
                displayText=sprintf('Edge %d  mid(%.4f,%.4f)',idx,targetPoint(1),targetPoint(2));
                ok=true;

            case 'Point'
                % Same behavior as the BC/Loading Point picker: click near the mesh,
                % snap to the nearest mesh node, and store that node ID.
                if isempty(model.mesh)
                    msg='Generate a mesh first.'; displayText='(no mesh)'; return;
                end
                mx=model.mesh.xcoords(:); my=model.mesh.ycoords(:);
                [~,meshIdx]=min(hypot(mx-xClick,my-yClick));
                targetType='Point'; targetID=meshIdx;
                targetPoint=[mx(meshIdx) my(meshIdx)];
                targetNodes=meshIdx;
                displayText=sprintf('Point -> Node %d (%.4f,%.4f)',meshIdx,targetPoint(1),targetPoint(2));
                ok=true;

            otherwise
                msg=['Unknown selection type: ' requestedType];
                displayText='(unknown selection type)';
        end
    end

    function pickRefinementTargetAtPoint(xClick,yClick,writeLog)
        [tType,tID,tPoint,tNodes,dispText,ok,msg]=resolveSelectableTargetAtPoint(...
            refSelectionTypeDropDown.Value,xClick,yClick,ax);

        if ~ok
            refSelectedField.Value=dispText;
            if writeLog&&~isempty(msg), logMessage(['Refinement selection: ' msg]); end
            return;
        end

        refSelectedType=tType;
        refSelectedID=tID;
        refSelectedPoint=tPoint;
        refSelectedNodes=tNodes;
        refSelectedField.Value=dispText;

        if writeLog
            switch refSelectedType
                case 'Vertex'
                    logMessage(sprintf('Refinement selected Vertex %d at (%.4g, %.4g) m.',refSelectedID,refSelectedPoint(1),refSelectedPoint(2)));
                case 'Edge'
                    logMessage(sprintf('Refinement selected Edge %d.',refSelectedID));
                case 'Point'
                    logMessage(sprintf('Refinement selected Point snapped to Node %d at (%.4g, %.4g) m.',refSelectedID,refSelectedPoint(1),refSelectedPoint(2)));
            end
        end
    end

    function addSelectedRefinementRegionCallback(~,~)
        if isempty(model.mesh)
            uialert(fig,'Generate or load a mesh first.','Mesh Required'); return; end
        if isempty(refSelectedType)||isempty(refSelectedPoint)
            uialert(fig,'Pick a vertex, edge, node, or point first.','No Refinement Target'); return; end

        R_m=refRadiusField.Value/getDisplayScale();
        h_m=refHField.Value/getDisplayScale();
        if isempty(R_m)||R_m<=0
            if strcmp(refSelectedType,'Edge')
                uialert(fig,'Enter a band thickness > 0 before adding an edge refinement region.','Invalid Thickness');
            else
                uialert(fig,'Enter a radius > 0 before adding a region.','Invalid Radius');
            end
            return;
        end
        if isempty(h_m)||h_m<=0
            uialert(fig,'Enter a local element size > 0 before adding a region.','Invalid h'); return; end

        cx_m=refSelectedPoint(1); cy_m=refSelectedPoint(2);

        if strcmp(refSelectedType,'Edge')
            shapeType='EdgeBand';
            [xEdgeStore,yEdgeStore]=getEdgePolyline(refSelectedID);
            edgePolyline=[xEdgeStore(:), yEdgeStore(:)];
            verts_ccw=[]; % Edge bands are defined by distance to edge polyline, not a square/circle box.
        else
            shapeType='Circle';
            edgePolyline=[];
            % CCW bounding-square: E → N → W → S
            verts_ccw=[cx_m+R_m, cy_m;    ...  % E  (0 deg)
                       cx_m,     cy_m+R_m; ... % N  (90 deg)
                       cx_m-R_m, cy_m;    ...  % W  (180 deg)
                       cx_m,     cy_m-R_m];    % S  (270 deg)
        end

        refPickCount=refPickCount+1;
        n=numel(model.refinementRegions)+1;
        model.refinementRegions(n).center        =[cx_m, cy_m];
        model.refinementRegions(n).radius        =R_m;
        model.refinementRegions(n).h_target      =h_m;
        model.refinementRegions(n).vertices      =verts_ccw;
        model.refinementRegions(n).point         =[cx_m, cy_m];
        if strcmp(shapeType,'EdgeBand')
            model.refinementRegions(n).regionType    ='RefinementEdgeBand';
        else
            model.refinementRegions(n).regionType    ='RefinementCircle';
        end
        model.refinementRegions(n).regionID      =refPickCount;
        model.refinementRegions(n).sourceType    =refSelectedType;
        model.refinementRegions(n).sourceID      =refSelectedID;
        model.refinementRegions(n).affected_nodes=refSelectedNodes;
        model.refinementRegions(n).shapeType     =shapeType;
        model.refinementRegions(n).edgePolyline  =edgePolyline;

        if strcmp(shapeType,'EdgeBand')
            logMessage(sprintf('Refinement #%d added from Edge %d: band thickness=%.4g m  h_target=%.4g m',...
                refPickCount,refSelectedID,R_m,h_m));
        else
            logMessage(sprintf('Refinement #%d added from %s: center=(%.4g, %.4g) m  R=%.4g m  h_target=%.4g m',...
                refPickCount,refSelectedType,cx_m,cy_m,R_m,h_m));
        end

        clearRefinementSelection();
        redrawMeshAxWithRefinements();
        updateRefSummary();
        updateRefinementPanelState();
    end

    function deleteSelectedRefinementCallback(~,~)
        if isempty(model.refinementRegions)
            uialert(fig,'No refinement regions to delete.','None'); return; end
        idx=refRegionList.Value;
        if isempty(idx)||idx==0||idx>numel(model.refinementRegions)
            uialert(fig,'Select a refinement region from the list first.','No Region Selected'); return;
        end
        deletedID=model.refinementRegions(idx).regionID;
        model.refinementRegions(idx)=[];
        logMessage(sprintf('Deleted refinement region #%d.',deletedID));
        redrawMeshAxWithRefinements(); updateRefSummary(); updateRefinementPanelState();
    end

    function clearAllRefinementsCallback(~,~)
        model.refinementRegions=struct('center',{},'radius',{},'h_target',{},'vertices',{},...
            'point',{},'regionType',{},'regionID',{},'sourceType',{},'sourceID',{},'affected_nodes',{});
        refPickCount=0;
        clearRefinementSelection(); clearRefinementHover(); cancelRefPickMode();
        logMessage('All refinement regions cleared.');
        redrawMeshAxWithRefinements();
        updateRefSummary(); updateRefinementPanelState();
    end

    function updateRefinementPanelState()
        if exist('refRadiusUnitLabel','var')&&isvalid(refRadiusUnitLabel)
            refRadiusUnitLabel.Text=getDisplayUnit();
            refHUnitLabel.Text=getDisplayUnit();
            if strcmp(refSelectionTypeDropDown.Value,'Edge')
                refRadiusLabel.Text='Thickness';
            else
                refRadiusLabel.Text='Radius';
            end
        end
        if exist('refSelectedField','var')&&isvalid(refSelectedField)
            if isempty(refSelectedType)
                refSelectedField.Value='(none)';
            else
                switch refSelectedType
                    case {'Vertex','Edge','Node'}
                        refSelectedField.Value=sprintf('%s %d  (%.4g, %.4g)',refSelectedType,refSelectedID,refSelectedPoint(1),refSelectedPoint(2));
                    case 'Point'
                        refSelectedField.Value=sprintf('Point  (%.4g, %.4g)',refSelectedPoint(1),refSelectedPoint(2));
                end
            end
        end
        if exist('refRegionList','var')&&isvalid(refRegionList)
            n=numel(model.refinementRegions);
            if n==0
                refRegionList.Items={'No refinement regions defined.'};
                refRegionList.ItemsData=0;
                refRegionList.Value=0;
            else
                items=cell(1,n);
                for k=1:n
                    rr=model.refinementRegions(k);
                    if isfield(rr,'sourceType')&&~isempty(rr.sourceType), src=rr.sourceType; else, src='Point'; end
                    if isfield(rr,'sourceID')&&~isempty(rr.sourceID), srcStr=sprintf('%s %d',src,rr.sourceID); else, srcStr=src; end
                    if isfield(rr,'shapeType')&&strcmp(rr.shapeType,'EdgeBand')
                        sizeLabel='thk';
                    else
                        sizeLabel='R';
                    end
                    items{k}=sprintf('%d | %s | %s=%.3g %s | h=%.3g %s',...
                        rr.regionID,srcStr,sizeLabel,rr.radius*getDisplayScale(),getDisplayUnit(),rr.h_target*getDisplayScale(),getDisplayUnit());
                end
                refRegionList.Items=items;
                refRegionList.ItemsData=1:n;
                refRegionList.Value=1;
            end
        end
    end

    function redrawMeshAxWithRefinements()
        cla(ax); hold(ax,'on');
        if ~isempty(nodesG)
            copyGeometryToAxes(ax,'');
        end
        if ~isempty(model.mesh)
            p=[model.mesh.xcoords model.mesh.ycoords]; t=model.mesh.connectivity;
            for i=1:size(t,1)
                triIdx=[t(i,1),t(i,2),t(i,3),t(i,1)];
                plot(ax,p(triIdx,1),p(triIdx,2),'-',...
                    'Color',couleur,'LineWidth',0.55,'HitTest','off','PickableParts','none');
            end
            title(ax,'Geometry and Mesh View');
        else
            title(ax,'Geometry View');
        end
        drawRefinementRegionsOnAx();
        drawMeshRefinementSelectableTargets();
        drawMeshRefinementHoverTarget();
        drawCurrentRefinementSelection();
        forceAxesClicksToAxes(ax);
        xlabel(ax,'$x$','interpreter','latex'); ylabel(ax,'$y$','interpreter','latex');
        grid(ax,'on'); axis(ax,'equal'); set(ax,'TickLabelInterpreter','latex');
        hold(ax,'off');
    end

    function drawRefinementRegionsOnAx()
        for k=1:numel(model.refinementRegions)
            rr=model.refinementRegions(k);
            isEdgeBand=isfield(rr,'shapeType')&&strcmp(rr.shapeType,'EdgeBand');
            if isEdgeBand
                drawEdgeBandRegionOnAx(ax,rr);
            else
                theta=linspace(0,2*pi,120);
                xCirc=rr.center(1)+rr.radius*cos(theta);
                yCirc=rr.center(2)+rr.radius*sin(theta);
                plot(ax,xCirc,yCirc,'--','Color',[0 0.78 0.78],'LineWidth',1.8,...
                    'HitTest','off','PickableParts','none');
                plot(ax,rr.center(1),rr.center(2),'+',...
                    'Color',[0 0.6 0.6],'MarkerSize',9,'LineWidth',2,...
                    'HitTest','off','PickableParts','none');
                if isfield(rr,'sourceType')&&~isempty(rr.sourceType), src=rr.sourceType; else, src='Point'; end
                text(ax,rr.center(1),rr.center(2)+rr.radius*1.1,...
                    sprintf('R%d %s  r=%.3g  h=%.3g',rr.regionID,src,rr.radius,rr.h_target),...
                    'FontSize',7,'Color',[0 0.5 0.5],'HorizontalAlignment','center','HitTest','off');
            end
        end
    end

    function drawMeshRefinementSelectableTargets()
        if ~strcmp(leftPanelMode,'meshRefinement')||isempty(model.mesh), return; end
        switch refSelectionTypeDropDown.Value
            case 'Vertex'
                if ~isempty(nodesG)
                    scatter(ax,nodesG(:,1),nodesG(:,2),55,'o',...
                        'MarkerEdgeColor',[0.9 0.1 0.1],...
                        'MarkerFaceColor',[1 0.85 0.85],...
                        'LineWidth',1.4,'HitTest','off','PickableParts','none');
                end
            case 'Edge'
                drawSelectableEdgesOnAxes(ax);
            case 'Point'
                scatter(ax,model.mesh.xcoords,model.mesh.ycoords,18,'o',...
                    'MarkerEdgeColor',[0.9 0.1 0.1],...
                    'MarkerFaceColor',[1 0.85 0.85],...
                    'LineWidth',0.8,'HitTest','off','PickableParts','none');
        end
    end

    function drawMeshRefinementHoverTarget()
        if ~strcmp(leftPanelMode,'meshRefinement')||isempty(refHoverType)||isempty(refHoverID), return; end
        if strcmp(refSelectedType,refHoverType)&&isequal(refSelectedID,refHoverID), return; end
        switch refHoverType
            case 'Vertex'
                if refHoverID<=size(nodesG,1)
                    plot(ax,nodesG(refHoverID,1),nodesG(refHoverID,2),'o',...
                        'MarkerSize',12,'LineWidth',2,'MarkerEdgeColor',[0.95 0.65 0],...
                        'MarkerFaceColor',[1 0.97 0.2],'HitTest','off','PickableParts','none');
                end
            case 'Edge'
                [xEdge,yEdge]=getEdgePolyline(refHoverID);
                if numel(xEdge)>=2
                    plot(ax,xEdge,yEdge,'-','Color',[0.95 0.65 0],'LineWidth',9,'HitTest','off','PickableParts','none');
                    plot(ax,xEdge,yEdge,'-','Color',[1 0.97 0.2],'LineWidth',5,'HitTest','off','PickableParts','none');
                end
            case 'Point'
                if ~isempty(model.mesh)&&refHoverID<=numel(model.mesh.xcoords)
                    px=model.mesh.xcoords(refHoverID); py=model.mesh.ycoords(refHoverID);
                    plot(ax,px,py,'o',...
                        'MarkerSize',13,'LineWidth',2,'MarkerEdgeColor',[0.95 0.65 0],...
                        'MarkerFaceColor',[1 0.97 0.2],'HitTest','off','PickableParts','none');
                end
        end
    end

    function drawCurrentRefinementSelection()
        if ~strcmp(leftPanelMode,'meshRefinement')||isempty(refSelectedType)||isempty(refSelectedPoint), return; end
        switch refSelectedType
            case 'Vertex'
                plot(ax,refSelectedPoint(1),refSelectedPoint(2),'o',...
                    'MarkerSize',13,'LineWidth',2,'MarkerEdgeColor',[0.95 0.55 0],...
                    'MarkerFaceColor',[1 1 0],'HitTest','off','PickableParts','none');
            case 'Edge'
                [xEdge,yEdge]=getEdgePolyline(refSelectedID);
                if numel(xEdge)>=2
                    plot(ax,xEdge,yEdge,'-','Color',[0.95 0.55 0],'LineWidth',8,'HitTest','off','PickableParts','none');
                    plot(ax,xEdge,yEdge,'-','Color',[1 1 0],'LineWidth',4,'HitTest','off','PickableParts','none');
                end
                plot(ax,refSelectedPoint(1),refSelectedPoint(2),'d',...
                    'MarkerSize',10,'LineWidth',2,'MarkerEdgeColor',[0.7 0 0],...
                    'MarkerFaceColor',[1 1 0],'HitTest','off','PickableParts','none');
            case 'Point'
                plot(ax,refSelectedPoint(1),refSelectedPoint(2),'o',...
                    'MarkerSize',14,'LineWidth',2,'MarkerEdgeColor',[0.95 0.55 0],...
                    'MarkerFaceColor',[1 0.95 0.2],'HitTest','off','PickableParts','none');
                plot(ax,refSelectedPoint(1),refSelectedPoint(2),'o',...
                    'MarkerSize',6,'LineWidth',1.5,'MarkerEdgeColor',[0.6 0 0],...
                    'MarkerFaceColor',[1 0.3 0.3],'HitTest','off','PickableParts','none');
        end
    end

    function drawEdgeBandRegionOnAx(targetAx,rr)
        if isfield(rr,'edgePolyline') && ~isempty(rr.edgePolyline)
            xEdge = rr.edgePolyline(:,1);
            yEdge = rr.edgePolyline(:,2);
        else
            [xEdge,yEdge] = getEdgePolyline(rr.sourceID);
        end

        xEdge = xEdge(:);
        yEdge = yEdge(:);
        keep = ~isnan(xEdge) & ~isnan(yEdge);
        xEdge = xEdge(keep);
        yEdge = yEdge(keep);
        if numel(xEdge) < 2
            return;
        end

        [xOff,yOff] = edgeBandOffsetPolyline(xEdge,yEdge,rr.radius);
        isClosed = hypot(xEdge(1)-xEdge(end),yEdge(1)-yEdge(end)) < 1e-10;

        plot(targetAx,xEdge,yEdge,'-','Color',[0 0.78 0.78],'LineWidth',4,'HitTest','off','PickableParts','none');
        plot(targetAx,xOff,yOff,'-','Color',[0 0.78 0.78],'LineWidth',2.5,'HitTest','off','PickableParts','none');

        if ~isClosed
            plot(targetAx,[xEdge(1) xOff(1)],[yEdge(1) yOff(1)],'-','Color',[0 0.78 0.78],'LineWidth',2.5,'HitTest','off','PickableParts','none');
            plot(targetAx,[xEdge(end) xOff(end)],[yEdge(end) yOff(end)],'-','Color',[0 0.78 0.78],'LineWidth',2.5,'HitTest','off','PickableParts','none');
        end

        plot(targetAx,xEdge,yEdge,'--','Color',[0 0.5 0.5],'LineWidth',1.0,'HitTest','off','PickableParts','none');

        labelPt = rr.center;
        text(targetAx,labelPt(1),labelPt(2),sprintf('R%d EdgeBand thk=%.3g h=%.3g',rr.regionID,rr.radius,rr.h_target),'FontSize',7,'Color',[0 0.5 0.5],'HorizontalAlignment','center','HitTest','off');
    end

    function [xOff,yOff] = edgeBandOffsetPolyline(xEdge,yEdge,thickness)
        nPts = numel(xEdge);
        normals = zeros(nPts,2);
        counts = zeros(nPts,1);

        for kk = 1:(nPts-1)
            x1 = xEdge(kk);
            y1 = yEdge(kk);
            x2 = xEdge(kk+1);
            y2 = yEdge(kk+1);
            dx = x2 - x1;
            dy = y2 - y1;
            L = hypot(dx,dy);
            if L <= eps
                continue;
            end

            nA = [-dy/L, dx/L];
            nB = -nA;
            n = chooseInwardNormalFromMesh(0.5*(x1+x2),0.5*(y1+y2),nA,nB);

            normals(kk,:) = normals(kk,:) + n;
            normals(kk+1,:) = normals(kk+1,:) + n;
            counts(kk) = counts(kk) + 1;
            counts(kk+1) = counts(kk+1) + 1;
        end

        for ii = 1:nPts
            if counts(ii) > 0
                normals(ii,:) = normals(ii,:) ./ counts(ii);
            end
            L = hypot(normals(ii,1),normals(ii,2));
            if L > eps
                normals(ii,:) = normals(ii,:) ./ L;
            end
        end

        if nPts > 2 && hypot(xEdge(1)-xEdge(end),yEdge(1)-yEdge(end)) < 1e-10
            normals(end,:) = normals(1,:);
        end

        xOff = xEdge + thickness .* normals(:,1);
        yOff = yEdge + thickness .* normals(:,2);
    end

    function n = chooseInwardNormalFromMesh(xMid,yMid,nA,nB)
        n = nA;
        if isempty(model.mesh)
            return;
        end
        conn = model.mesh.connectivity;
        mx = model.mesh.xcoords(:);
        my = model.mesh.ycoords(:);
        elemCx = mean(mx(conn),2);
        elemCy = mean(my(conn),2);
        [~,idx] = min(hypot(elemCx-xMid,elemCy-yMid));
        v = [elemCx(idx)-xMid, elemCy(idx)-yMid];
        if dot(v,nB) > dot(v,nA)
            n = nB;
        end
    end

    function d=distancePointsToPolyline(px,py,xLine,yLine)
        px=px(:); py=py(:);
        d=inf(size(px));
        for kk=1:(numel(xLine)-1)
            if any(isnan([xLine(kk),yLine(kk),xLine(kk+1),yLine(kk+1)])), continue; end
            d=min(d,distancePointsToSegment(px,py,xLine(kk),yLine(kk),xLine(kk+1),yLine(kk+1)));
        end
    end

    function d=distancePointsToSegment(px,py,x1,y1,x2,y2)
        vx=x2-x1; vy=y2-y1; c2=vx*vx+vy*vy;
        if c2<=eps
            d=hypot(px-x1,py-y1); return;
        end
        a=max(0,min(1,((px-x1).*vx+(py-y1).*vy)./c2));
        d=hypot(px-(x1+a.*vx),py-(y1+a.*vy));
    end

    function updateRefSummary()
        n=numel(model.refinementRegions);
        if n==0, refSummaryBox.Value={'No refinement regions defined.'}; return; end
        parts=cell(1,n);
        for k=1:n
            rr=model.refinementRegions(k);
            if isfield(rr,'sourceType')&&~isempty(rr.sourceType), src=rr.sourceType; else, src='Point'; end
            if isfield(rr,'shapeType')&&strcmp(rr.shapeType,'EdgeBand')
                parts{k}=sprintf('[%d] EdgeBand edge=%d  thk=%.3g  h=%.3g',rr.regionID,rr.sourceID,rr.radius,rr.h_target);
            else
                parts{k}=sprintf('[%d] %s c=(%.3g,%.3g)  R=%.3g  h=%.3g',rr.regionID,src,rr.center(1),rr.center(2),rr.radius,rr.h_target);
            end
        end
        refSummaryBox.Value={strjoin(parts,'   |   ')};
    end

    function [idx,minDist]=nearestEdgeIndexOnAxes(targetAx,xClick,yClick)
        idx=[]; minDist=inf; if isempty(edgesG), return; end
        d=inf(size(edgesG,1),1);
        for e=1:size(edgesG,1)
            [xEdge,yEdge]=getEdgePolyline(e);
            if numel(xEdge)>=2, d(e)=distancePointToPolyline(xClick,yClick,xEdge,yEdge);
            elseif ~isempty(midpointsG)&&e<=size(midpointsG,1)
                d(e)=hypot(midpointsG(e,1)-xClick,midpointsG(e,2)-yClick); end
        end
        [minDist,idx]=min(d); if isinf(minDist), idx=[]; end
        %#ok<NASGU> targetAx
    end

    function tol=edgePickToleranceOnAxes(targetAx)
        if isempty(nodesG), tol=inf; return; end
        axRangeX=diff(targetAx.XLim); axRangeY=diff(targetAx.YLim); axPos=targetAx.Position;
        pixPerUnitX=axPos(3)/axRangeX; pixPerUnitY=axPos(4)/axRangeY;
        tol=8/min(pixPerUnitX,pixPerUnitY);
        modelSpan=max([(max(nodesG(:,1))-min(nodesG(:,1))),(max(nodesG(:,2))-min(nodesG(:,2))),eps]);
        tol=min(tol,0.05*modelSpan);
    end

    function tf=pointIsInsideTargetAxes(targetAx,x,y)
        tf=x>=targetAx.XLim(1)&&x<=targetAx.XLim(2)&&y>=targetAx.YLim(1)&&y<=targetAx.YLim(2);
    end

    % =========================================================================
    % Solve
    % =========================================================================
    function solveCallback(~,~)
        if isempty(model.mesh)
            uialert(fig,'Load a mesh before solving.','No Mesh');
            logMessage('Solve failed: no mesh loaded.');
            return;
        end

        try
            beginComputation('Solve');
            updateProgress(10,'Reading inputs...');

            materialName = materialDropDown.Value;
            analysisType = analysisTypeDropDown.Value;
            E           = eField.Value;
            nu          = nuField.Value;
            rho         = densityField.Value;
            thickness   = thicknessField.Value/getDisplayScale();

            updateProgress(20,'Validating inputs...');
            if E<=0, error('Young''s modulus E must be > 0.'); end
            if nu<=-1 || nu>=0.5, error('Poisson''s ratio nu must be in (-1, 0.5).'); end
            if rho<=0, error('Density must be > 0.'); end
            if thickness<=0, error('Thickness must be > 0.'); end
            if strcmp(analysisType,'Pick One'), error('Select an analysis type first.'); end

            nC = numel(model.constraints);
            nL = numel(model.loads);
            if nC==0 && nL==0
                error(['No boundary conditions or loads have been applied.' newline ...
                       'Add at least one constraint and one load before solving.']);
            end
            if nC==0
                error(['No constraints have been applied.' newline ...
                       'The model is unconstrained and will have rigid body motion.']);
            end
            if nL==0
                error(['No loads have been applied.' newline ...
                       'Add at least one force load before solving.']);
            end

            hasFixedX = false;
            hasFixedY = false;
            for kk = 1:nC
                c = model.constraints(kk);
                if ~isnan(c.x_mag), hasFixedX = true; end
                if ~isnan(c.y_mag), hasFixedY = true; end
            end
            if ~hasFixedX && ~hasFixedY
                error(['Constraints found, but no DOF is actually fixed.' newline ...
                       'Use Fixed X, Fixed Y, Fixed XY, or a prescribed deflection.']);
            end
            if ~hasFixedX
                logMessage('Warning: no X-direction constraint found — model may be under-constrained in X.');
            end
            if ~hasFixedY
                logMessage('Warning: no Y-direction constraint found — model may be under-constrained in Y.');
            end

            updateProgress(40,'Storing material...');
            if strcmp(getDisplayUnit(),'in')
                E_SI   = E   * 6894.76;   % psi -> Pa
                rho_SI = rho * 27679.9;   % lb/in^3 -> kg/m^3
            else
                E_SI   = E;
                rho_SI = rho;
            end

            model.material.name         = materialName;
            model.material.E            = E_SI;
            model.material.nu           = nu;
            model.material.density      = rho_SI;
            model.material.thickness    = thickness;
            model.material.analysisType = lower(analysisType);

            updateProgress(60,'Running solver...');
            model.results = struct();
            drawnow;
            if stopRequested
                error('USER_STOPPED:ComputationStopped','Computation stopped by user.');
            end

            solverName = 'internal T3 solver';
            if exist('func_solve','file')==2
                try
                    [qVec,FVec] = func_solve();
                    solverName = 'external func_solve';
                catch solveErr
                    logMessage(['External solver failed: ' solveErr.message]);
                    logMessage('Falling back to internal T3 solver.');
                    [qVec,FVec] = runInternalT3Solver();
                    solverName = 'internal T3 solver';
                end
            else
                [qVec,FVec] = runInternalT3Solver();
            end

            model.results.Deformation = qVec;
            model.results.FVec        = FVec;
            normalizeDisplacementResults();
            [ux,uy] = getUXUY();
            maxDisp = max(hypot(ux,uy));
            updateProgress(95,'Solver complete.');
            logMessage(sprintf('Solved with %s: max displacement = %.4g m',solverName,maxDisp));
                        logMessage(sprintf('Material=%s  AnalysisType=%s',materialName,analysisType));
            logMessage(sprintf('E=%.4g Pa  nu=%.4g  rho=%.4g kg/m^3  thickness=%.4g m',E_SI,nu,rho_SI,thickness));
            logMessage(sprintf('BCs: %d constraint(s), %d load(s)',numel(model.constraints),numel(model.loads)));

            printModelToCommandWindow();
            finishComputation('Solve complete.');
            if strcmp(tabGroup.SelectedTab.Title,'Post-Processing')
                plotResultCallback([],[]);
            end
            uialert(fig,sprintf(['Solve completed successfully using %s.\n\n' ...
                'Max displacement = %.4g m.'],solverName,maxDisp),'Solve Complete');
        catch err
            failComputation(err);
        end
    end

    function [qVec,FVec] = runInternalT3Solver()
        % Minimal linear-static T3 solver.
        % Assumptions:
        %   - 2D T3 elements only
        %   - SI coordinates internally
        %   - point/edge loads are stored as total force components and are
        %     distributed evenly over the selected affected nodes
        %   - moments are ignored because the current T3 displacement model has
        %     no rotational DOF
        conn = model.mesh.connectivity;
        x    = model.mesh.xcoords(:);
        y    = model.mesh.ycoords(:);
        nN   = numel(x);
        nDof = 2*nN;

        if isempty(conn) || size(conn,2)~=3
            error('Internal solver currently supports T3 triangular elements only.');
        end

        E  = model.material.E;
        nu = model.material.nu;
        th = model.material.thickness;
        D  = makeConstitutiveMatrix(E,nu,model.material.analysisType);

        K = sparse(nDof,nDof);
        F = zeros(nDof,1);

        for e = 1:size(conn,1)
            ids = conn(e,:);
            xe  = x(ids);
            ye  = y(ids);
            A   = 0.5*det([1 xe(1) ye(1); 1 xe(2) ye(2); 1 xe(3) ye(3)]);

            if abs(A) < 1e-18
                error('Degenerate element %d has near-zero area.',e);
            end

            b = [ye(2)-ye(3); ye(3)-ye(1); ye(1)-ye(2)];
            c = [xe(3)-xe(2); xe(1)-xe(3); xe(2)-xe(1)];

            B = 1/(2*A) * [ ...
                b(1) 0    b(2) 0    b(3) 0;
                0    c(1) 0    c(2) 0    c(3);
                c(1) b(1) c(2) b(2) c(3) b(3) ];

            ke   = th*abs(A)*(B.'*D*B);
            dofs = elementDofs(ids);
            K(dofs,dofs) = K(dofs,dofs) + ke;
        end

        forceScale = currentForceToNewtonScale();
        for kk = 1:numel(model.loads)
            ld = model.loads(kk);
            nodes = unique(ld.affected_nodes(:).');
            nodes = nodes(nodes>=1 & nodes<=nN);
            if isempty(nodes), continue; end

            fxTotal = ld.x_mag*forceScale;
            fyTotal = ld.y_mag*forceScale;

            % The GUI labels these as force components, so treat the entered
            % value as total force over the selected target.
            fxEach = fxTotal/numel(nodes);
            fyEach = fyTotal/numel(nodes);
            for nn = nodes
                F(2*nn-1) = F(2*nn-1) + fxEach;
                F(2*nn)   = F(2*nn)   + fyEach;
            end
        end

        fixedDofs = [];
        fixedVals = [];
        for kk = 1:numel(model.constraints)
            bc = model.constraints(kk);
            nodes = unique(bc.affected_nodes(:).');
            nodes = nodes(nodes>=1 & nodes<=nN);
            for nn = nodes
                if ~isnan(bc.x_mag)
                    fixedDofs(end+1,1) = 2*nn-1; %#ok<AGROW>
                    fixedVals(end+1,1) = bc.x_mag; %#ok<AGROW>
                end
                if ~isnan(bc.y_mag)
                    fixedDofs(end+1,1) = 2*nn; %#ok<AGROW>
                    fixedVals(end+1,1) = bc.y_mag; %#ok<AGROW>
                end
            end
        end

        if isempty(fixedDofs)
            error('No fixed/prescribed DOFs were found.');
        end

        % If overlapping constraints exist, the last one in the table wins.
        [fixedDofs,ia] = unique(fixedDofs,'last');
        fixedVals      = fixedVals(ia);

        allDofs  = (1:nDof).';
        freeDofs = setdiff(allDofs,fixedDofs);

        qVec = zeros(nDof,1);
        qVec(fixedDofs) = fixedVals;

        rhs = F(freeDofs) - K(freeDofs,fixedDofs)*qVec(fixedDofs);
        Kff = K(freeDofs,freeDofs);

        if isempty(freeDofs)
            error('All DOFs are constrained; there are no free DOFs to solve.');
        end
        if rcond(full(Kff)) < 1e-14
            error(['The stiffness matrix is singular or badly conditioned.' newline ...
                   'Add enough constraints to remove rigid body motion.']);
        end

        qVec(freeDofs) = Kff\rhs;
        FVec = F;
        model.results.K = K;
        model.results.DOFOrder = 'interleaved';
    end

    function dofs = elementDofs(ids)
        dofs = reshape([2*ids(:).'-1; 2*ids(:).'],1,[]);
    end

    function D = makeConstitutiveMatrix(E,nu,analysisType)
        analysisType = lower(string(analysisType));
        if contains(analysisType,'plane stress')
            D = E/(1-nu^2) * [ ...
                1  nu 0;
                nu 1  0;
                0  0  (1-nu)/2 ];
        elseif contains(analysisType,'plane strain')
            D = E/((1+nu)*(1-2*nu)) * [ ...
                1-nu nu   0;
                nu   1-nu 0;
                0    0    (1-2*nu)/2 ];
        else
            error('Axisymmetric stiffness/recovery is not implemented in the internal T3 solver yet.');
        end
    end

    function s = currentForceToNewtonScale()
        if strcmp(getDisplayUnit(),'in')
            s = 4.4482216152605; % lbf -> N
        else
            s = 1;
        end
    end

    % =========================================================================
    % Post-processing
    % =========================================================================
    function clearPostResultsCallback(~,~)
        postSelectedResults = {};
        postResultListBusy = true;
        try
            postResultList.Value = cell(1,0);
        catch
            % Older MATLAB releases can be picky about clearing listbox
            % selections. Falling back to the stored empty selection still
            % makes Plot show the "Nothing Selected" guard.
        end
        postResultListBusy = false;
        logMessage('Post-processing result selection cleared.');
    end

    function postResultListChangedCallback(src,~)
        if postResultListBusy
            return;
        end

        newSelection = src.Value;
        if ischar(newSelection), newSelection = {newSelection}; end

        % Make normal clicks behave like toggle-select so users can choose
        % non-adjacent results without needing Ctrl/Cmd. Native Ctrl/Cmd and
        % Shift multi-select still work too.
        if numel(newSelection)==1
            clicked = newSelection{1};
            oldSelection = postSelectedResults;
            if ischar(oldSelection), oldSelection = {oldSelection}; end

            if any(strcmp(oldSelection,clicked))
                updatedSelection = oldSelection(~strcmp(oldSelection,clicked));
                % Keep one item selected so the listbox always has a visible
                % active result. The Plot button still guards against empty.
                if isempty(updatedSelection)
                    updatedSelection = {clicked};
                end
            else
                updatedSelection = [oldSelection, {clicked}];
            end
        else
            updatedSelection = newSelection;
        end

        updatedSelection = orderPostResults(updatedSelection,src.Items);
        postSelectedResults = updatedSelection;

        postResultListBusy = true;
        src.Value = updatedSelection;
        postResultListBusy = false;
    end

    function ordered = orderPostResults(selection,items)
        if ischar(selection), selection = {selection}; end
        ordered = {};
        for ii = 1:numel(items)
            if any(strcmp(selection,items{ii}))
                ordered{end+1} = items{ii}; %#ok<AGROW>
            end
        end
    end

    function setPostMode(mode)
        currentPostMode = mode;
        if strcmp(mode,'tiled')
            postModeTiledBtn.BackgroundColor = [0.3 0.6 1];
            postModeTiledBtn.FontColor       = 'white';
            postModeTabBtn.BackgroundColor   = [0.9 0.9 0.9];
            postModeTabBtn.FontColor         = 'black';
        else
            postModeTabBtn.BackgroundColor   = [0.3 0.6 1];
            postModeTabBtn.FontColor         = 'white';
            postModeTiledBtn.BackgroundColor = [0.9 0.9 0.9];
            postModeTiledBtn.FontColor       = 'black';
        end
        logMessage(sprintf('Post-processing view mode: %s',mode));
    end

    function setPostOverlayMode(isOn)
        postOverlayEnabled = logical(isOn);
        if postOverlayEnabled
            postOverlayOnBtn.BackgroundColor  = [0.3 0.6 1];
            postOverlayOnBtn.FontColor        = 'white';
            postOverlayOffBtn.BackgroundColor = [0.9 0.9 0.9];
            postOverlayOffBtn.FontColor       = 'black';
            msg = 'on';
        else
            postOverlayOffBtn.BackgroundColor = [0.3 0.6 1];
            postOverlayOffBtn.FontColor       = 'white';
            postOverlayOnBtn.BackgroundColor  = [0.9 0.9 0.9];
            postOverlayOnBtn.FontColor        = 'black';
            msg = 'off';
        end
        logMessage(['Original mesh overlay: ' msg]);
        if ~isempty(model.mesh) && isfield(model.results,'Deformation') && ~isempty(model.results.Deformation)
            plotResultCallback([],[]);
        end
    end

    function plotResultCallback(~,~)
        if isempty(model.mesh)
            uialert(fig,'Load a mesh first.','No Mesh');
            return;
        end
        if ~isfield(model.results,'Deformation') || isempty(model.results.Deformation)
            uialert(fig,'Solve the model first.','No Results');
            return;
        end

        selected = postResultList.Value;
        if isempty(selected)
            uialert(fig,'Select at least one result.','Nothing Selected');
            return;
        end
        if ischar(selected), selected = {selected}; end

        try
            normalizeDisplacementResults();
            if strcmp(currentPostMode,'tiled')
                plotTiled(selected);
            else
                plotSubTabs(selected);
            end
            tabGroup.SelectedTab = postTab;
        catch err
            logMessage(['Post-processing failed: ' err.message]);
            uialert(fig,err.message,'Post-Processing Error');
        end
    end

    function plotTiled(selected)
        delete(allchild(postDisplayPanel));
        drawnow;

        % Tile layout rule:
        %   Fill downward first, up to 4 plots in one column.
        %   After 4, start a new column to the right.
        % This keeps each plot as a wide horizontal rectangle instead of
        % squeezing multiple plots into tiny side-by-side squares.
        n       = numel(selected);
        maxRows = 4;
        nRows   = min(maxRows,n);
        nCols   = ceil(n/maxRows);

        padX = 0.035;
        padY = 0.035;
        gapX = 0.045;
        gapY = 0.040;

        axW = (1 - 2*padX - (nCols-1)*gapX)/nCols;
        axH = (1 - 2*padY - (nRows-1)*gapY)/nRows;

        % One plot should still be a nice horizontal plotting window, not a
        % full-height square. Center it vertically in the display panel.
        if nRows == 1
            axH = min(axH,0.58);
            padY = (1-axH)/2;
        end

        for k = 1:n
            col  = floor((k-1)/maxRows);
            row  = mod(k-1,maxRows);   % top-to-bottom first
            xPos = padX + col*(axW+gapX);
            yPos = 1 - padY - (row+1)*axH - row*gapY;

            % Use a fixed tile panel with a fixed axes slot and a fixed
            % colorbar slot.  MATLAB otherwise lets each colorbar/tick-label
            % combination resize the axes differently, which makes every
            % other post-processing plot look shifted left/right.
            tilePanel = uipanel(postDisplayPanel,'Units','normalized',...
                'Position',[xPos yPos axW axH],'BorderType','none');
            try
                tilePanel.BackgroundColor = postDisplayPanel.BackgroundColor;
            catch
            end

            axSlot = [0.085 0.200 0.805 0.680];
            cbSlot = [0.920 0.200 0.030 0.680];
            tAx = uiaxes(tilePanel,'Units','normalized','Position',axSlot);
            setappdata(tAx,'PostAxesSlot',axSlot);
            setappdata(tAx,'PostColorbarSlot',cbSlot);
            plotOneResult(tAx,selected{k});
        end
        postHasResults=true;
        enforceAllPostPlotLayouts();
        logMessage(sprintf('Tiled post-processing plot: %d result(s).',n));
    end

    function plotSubTabs(selected)
        delete(allchild(postDisplayPanel));
        drawnow;

        stg = uitabgroup(postDisplayPanel,'Units','normalized','Position',[0 0 1 1]);
        for k = 1:numel(selected)
            st  = uitab(stg,'Title',selected{k});
            axSlot = [0.075 0.120 0.820 0.800];
            cbSlot = [0.925 0.120 0.030 0.800];
            tAx = uiaxes(st,'Units','normalized','Position',axSlot);
            setappdata(tAx,'PostAxesSlot',axSlot);
            setappdata(tAx,'PostColorbarSlot',cbSlot);
            plotOneResult(tAx,selected{k});
        end
        postHasResults=true;
        enforceAllPostPlotLayouts();
        logMessage(sprintf('Sub-tab post-processing plot: %d result(s).',numel(selected)));
    end

    function plotOneResult(tAx,resultType)
        cla(tAx);
        hold(tAx,'on');

        x    = model.mesh.xcoords(:);
        y    = model.mesh.ycoords(:);
        conn = model.mesh.connectivity;
        [ux,uy] = getUXUY();

        xd = x + ux;
        yd = y + uy;

        [vals,titleStr,valueLocation] = getResultValues(resultType);

        % Deformed contour mesh. Use nodal interpolation for nodal
        % results and flat coloring for element results.
        if strcmp(valueLocation,'element')
            patch(tAx,'Faces',conn,'Vertices',[xd yd], ...
                'CData',vals(:), ...
                'FaceColor','flat', ...
                'EdgeColor',[0.20 0.20 0.20], ...
                'LineWidth',0.35, ...
                'HitTest','on','PickableParts','all',...
                'ButtonDownFcn',@postAxesClickCallback);
        else
            patch(tAx,'Faces',conn,'Vertices',[xd yd], ...
                'FaceVertexCData',vals(:), ...
                'FaceColor','interp', ...
                'EdgeColor',[0.20 0.20 0.20], ...
                'LineWidth',0.35, ...
                'HitTest','on','PickableParts','all',...
                'ButtonDownFcn',@postAxesClickCallback);
        end

        % Optional undeformed/original mesh overlay. Draw it last so it remains
        % visible over the colored result surface.
        if postOverlayEnabled
            patch(tAx,'Faces',conn,'Vertices',[x y], ...
                'FaceColor','none', ...
                'EdgeColor',[1.00 0.00 0.00], ...
                'LineStyle','-', ...
                'LineWidth',0.95, ...
                'HitTest','off','PickableParts','none');
        end

        cb = colorbar(tAx);
        colormap(tAx,jet(256));
        safeColorLimits(tAx,vals);

        title(tAx,titleStr,'Interpreter','none');
        xlabel(tAx,sprintf('$x$ [%s]',getDisplayUnit()),'interpreter','latex');
        ylabel(tAx,sprintf('$y$ [%s]',getDisplayUnit()),'interpreter','latex');
        applyPostAxesView(tAx);
        lockPostAxesAndColorbarLayout(tAx,cb);

        annotatePostExtrema(tAx,vals,valueLocation,xd,yd,conn);
        storePostProbeData(tAx,resultType,vals,valueLocation,xd,yd,conn);
        tAx.ButtonDownFcn = @postAxesClickCallback;
        tAx.PickableParts = 'all';
        tAx.HitTest = 'on';
        hold(tAx,'off');

        % A final pass is needed after annotations, exponent labels, probe
        % data, and colorbar ticks have all been created.  MATLAB can nudge
        % uiaxes again after these objects draw, so lock the slots at the
        % end of every individual post-processing plot too.
        lockPostAxesAndColorbarLayout(tAx,cb);
    end

    function [vals,titleStr,valueLocation] = getResultValues(resultType)
        [ux,uy] = getUXUY();
        valueLocation = 'nodal';

        switch resultType
            case 'Deformation X'
                % Deformation results are stored in model length units (metres internally),
                % but the post-processing display should match the active Display Units.
                vals = ux * getDisplayScale();
                titleStr = sprintf('Deformation X [%s]',getDisplayUnit());

            case 'Deformation Y'
                vals = uy * getDisplayScale();
                titleStr = sprintf('Deformation Y [%s]',getDisplayUnit());

            case {'Stress X','Stress Y','Stress XY (Shear)', ...
                  'Strain X','Strain Y','Strain XY (Shear)'}
                [vals,valueLocation] = getExternalStressStrainValues(resultType);
                switch resultType
                    case 'Stress X'
                        titleStr = sprintf('Stress X [%s]',getPressureUnit());
                    case 'Stress Y'
                        titleStr = sprintf('Stress Y [%s]',getPressureUnit());
                    case 'Stress XY (Shear)'
                        titleStr = sprintf('Stress XY [%s]',getPressureUnit());
                    case 'Strain X'
                        titleStr = 'Strain X [-]';
                    case 'Strain Y'
                        titleStr = 'Strain Y [-]';
                    case 'Strain XY (Shear)'
                        titleStr = 'Strain XY [-]';
                end

            otherwise
                error('Unknown result type: %s',resultType);
        end
    end

    function unitLabel = resultDisplayUnit(resultType)
        % Unit label used by post-processing titles and data tips.
        % Deformation follows the active display length unit.
        % Stress follows the active stress unit text used elsewhere in the UI.
        % Strain is dimensionless.
        switch resultType
            case {'Deformation X','Deformation Y'}
                unitLabel = getDisplayUnit();
            case {'Stress X','Stress Y','Stress XY (Shear)'}
                unitLabel = getPressureUnit();
            case {'Strain X','Strain Y','Strain XY (Shear)'}
                unitLabel = '-';
            otherwise
                unitLabel = '';
        end
    end


    function autoDeformScaleCallback(~,~)
        % Auto scaling is not used in this version.
        logMessage('Auto deformation scaling is not used in this version.');
    end

    function sf = applyAutoDeformationScale(~)
        % Kept for backward compatibility with older callbacks/files.
        sf = 1;
    end


    function setPostProbeMode(isOn)
        postProbeEnabled = logical(isOn);
        if postProbeEnabled
            postProbeOnBtn.BackgroundColor  = [0.3 0.6 1];
            postProbeOnBtn.FontColor        = 'white';
            postProbeOffBtn.BackgroundColor = [0.9 0.9 0.9];
            postProbeOffBtn.FontColor       = 'black';
            postProbeLabel.Text = 'Probe on: click plot; drag data box.';
            msg = 'on';
        else
            postProbeOffBtn.BackgroundColor = [0.3 0.6 1];
            postProbeOffBtn.FontColor       = 'white';
            postProbeOnBtn.BackgroundColor  = [0.9 0.9 0.9];
            postProbeOnBtn.FontColor        = 'black';
            postProbeLabel.Text = 'Probe off.';
            cancelPostProbeDataTipDrag();
            msg = 'off';
        end
        logMessage(['Post-processing value probe: ' msg]);
    end

    function annotatePostExtrema(tAx,vals,valueLocation,xd,yd,conn)
        vals = vals(:);
        finiteIdx = find(isfinite(vals));
        if isempty(finiteIdx), return; end

        [~,iMinLocal] = min(vals(finiteIdx));
        [~,iMaxLocal] = max(vals(finiteIdx));
        iMin = finiteIdx(iMinLocal);
        iMax = finiteIdx(iMaxLocal);

        [xMin0,yMin0] = resultLocationXY(iMin,valueLocation,xd,yd,conn);
        [xMax0,yMax0] = resultLocationXY(iMax,valueLocation,xd,yd,conn);

        % MAX/MIN markers are actual triangular callouts. The triangle TIP
        % is exactly on the true max/min point. The triangle body and text
        % sit outward from the part so the label remains in white plot area.
        bbox = postObjectBBox(xd,yd,conn);
        axLims = [xlim(tAx), ylim(tAx)];

        [xMaxTri,yMaxTri,xMaxT,yMaxT,hMax,vMax] = extremaTriangleCallout(xMax0,yMax0,bbox,axLims);
        [xMinTri,yMinTri,xMinT,yMinT,hMin,vMin] = extremaTriangleCallout(xMin0,yMin0,bbox,axLims);

        expandPostAxesForAnnotation(tAx,[xMaxTri(:); xMaxT; xMinTri(:); xMinT],...
                                      [yMaxTri(:); yMaxT; yMinTri(:); yMinT]);

        patch(tAx,xMaxTri,yMaxTri,[1 0 0],...
            'EdgeColor',[0.65 0 0],'LineWidth',1.3,...
            'Tag','PostExtremaMarker','HitTest','off','PickableParts','none');
        text(tAx,xMaxT,yMaxT,sprintf('MAX\n%.4g',vals(iMax)),...
            'HorizontalAlignment',hMax,'VerticalAlignment',vMax,...
            'Color',[0.65 0 0],'FontWeight','bold','FontSize',8,...
            'BackgroundColor','white','Margin',2.0,...
            'Tag','PostExtremaMarker','HitTest','off','Clipping','off');

        patch(tAx,xMinTri,yMinTri,[0 0.2 1],...
            'EdgeColor',[0 0 0.65],'LineWidth',1.3,...
            'Tag','PostExtremaMarker','HitTest','off','PickableParts','none');
        text(tAx,xMinT,yMinT,sprintf('%.4g\nMIN',vals(iMin)),...
            'HorizontalAlignment',hMin,'VerticalAlignment',vMin,...
            'Color',[0 0 0.65],'FontWeight','bold','FontSize',8,...
            'BackgroundColor','white','Margin',2.0,...
            'Tag','PostExtremaMarker','HitTest','off','Clipping','off');
    end

    function bbox = postObjectBBox(xd,yd,conn)
        pts = [xd(:), yd(:)];
        % Include the original mesh if it is visible, because the callouts
        % should sit outside everything the user sees as the part.
        if postOverlayEnabled && ~isempty(model.mesh)
            pts = [pts; model.mesh.xcoords(:), model.mesh.ycoords(:)]; %#ok<AGROW>
        end
        pts = pts(all(isfinite(pts),2),:);
        if isempty(pts)
            bbox = [0 1 0 1];
            return;
        end
        bbox = [min(pts(:,1)), max(pts(:,1)), min(pts(:,2)), max(pts(:,2))];
        if abs(bbox(2)-bbox(1)) < eps(max(abs(bbox(1:2))))
            bbox(1) = bbox(1)-0.5;
            bbox(2) = bbox(2)+0.5;
        end
        if abs(bbox(4)-bbox(3)) < eps(max(abs(bbox(3:4))))
            bbox(3) = bbox(3)-0.5;
            bbox(4) = bbox(4)+0.5;
        end
    end

    function [triX,triY,xt,yt,hAlign,vAlign] = extremaTriangleCallout(x0,y0,bbox,lims)
        xObjMin = bbox(1); xObjMax = bbox(2);
        yObjMin = bbox(3); yObjMax = bbox(4);
        objW = max(xObjMax-xObjMin,eps);
        objH = max(yObjMax-yObjMin,eps);

        xSpan = max(lims(2)-lims(1),objW);
        ySpan = max(lims(4)-lims(3),objH);

        % The triangle tip is fixed at the real result location.  The base
        % extends outward.  Text is placed beyond the base, in white plot area.
        triLenX  = max(0.038*xSpan,0.060*objW);
        triHalfY = max(0.018*ySpan,0.050*objH);
        triLenY  = max(0.038*ySpan,0.080*objH);
        triHalfX = max(0.018*xSpan,0.050*objW);
        textGapX = max(0.012*xSpan,0.020*objW);
        textGapY = max(0.018*ySpan,0.035*objH);

        dRight  = abs(xObjMax-x0);
        dLeft   = abs(x0-xObjMin);
        dTop    = abs(yObjMax-y0);
        dBottom = abs(y0-yObjMin);
        [~,side] = min([dRight dLeft dTop dBottom]);

        % If the result point is not near a boundary, choose the outward
        % direction from the object center.  The label still stays outside.
        cx = 0.5*(xObjMin+xObjMax);
        cy = 0.5*(yObjMin+yObjMax);
        boundaryTolX = 0.10*objW;
        boundaryTolY = 0.10*objH;
        onBoundary = dRight<boundaryTolX || dLeft<boundaryTolX || dTop<boundaryTolY || dBottom<boundaryTolY;
        if ~onBoundary
            if abs((x0-cx)/objW) >= abs((y0-cy)/objH)
                if x0 >= cx, side = 1; else, side = 2; end
            else
                if y0 >= cy, side = 3; else, side = 4; end
            end
        end

        switch side
            case 1 % right: triangle points left, tip touches result point
                triX = [x0, x0+triLenX, x0+triLenX];
                triY = [y0, y0+triHalfY, y0-triHalfY];
                xt = x0 + triLenX + textGapX;
                yt = y0;
                hAlign = 'left';
                vAlign = 'middle';
            case 2 % left: triangle points right
                triX = [x0, x0-triLenX, x0-triLenX];
                triY = [y0, y0+triHalfY, y0-triHalfY];
                xt = x0 - triLenX - textGapX;
                yt = y0;
                hAlign = 'right';
                vAlign = 'middle';
            case 3 % top: triangle points down
                triX = [x0, x0-triHalfX, x0+triHalfX];
                triY = [y0, y0+triLenY, y0+triLenY];
                xt = x0;
                yt = y0 + triLenY + textGapY;
                hAlign = 'center';
                vAlign = 'bottom';
            otherwise % bottom: triangle points up
                triX = [x0, x0-triHalfX, x0+triHalfX];
                triY = [y0, y0-triLenY, y0-triLenY];
                xt = x0;
                yt = y0 - triLenY - textGapY;
                hAlign = 'center';
                vAlign = 'top';
        end
    end

    function expandPostAxesForAnnotation(tAx,xExtra,yExtra)
        xExtra = xExtra(isfinite(xExtra));
        yExtra = yExtra(isfinite(yExtra));
        if isempty(xExtra) && isempty(yExtra), return; end

        xl = xlim(tAx);
        yl = ylim(tAx);
        xr = max(diff(xl),eps);
        yr = max(diff(yl),eps);
        xPad = 0.05*xr;
        yPad = 0.05*yr;

        if ~isempty(xExtra)
            xl = [min([xl(1), xExtra(:)'-xPad]), max([xl(2), xExtra(:)'+xPad])];
        end
        if ~isempty(yExtra)
            yl = [min([yl(1), yExtra(:)'-yPad]), max([yl(2), yExtra(:)'+yPad])];
        end

        xlim(tAx,xl);
        ylim(tAx,yl);
    end

    function [px,py] = resultLocationXY(idx,valueLocation,xd,yd,conn)
        if strcmp(valueLocation,'element')
            ids = conn(idx,:);
            px = mean(xd(ids));
            py = mean(yd(ids));
        else
            px = xd(idx);
            py = yd(idx);
        end
    end

    function storePostProbeData(tAx,resultType,vals,valueLocation,xd,yd,conn)
        ud = struct();
        ud.kind = 'postResultAxes';
        ud.resultType = resultType;
        ud.values = vals(:);
        ud.valueLocation = valueLocation;
        ud.x = xd(:);
        ud.y = yd(:);
        ud.conn = conn;
        ud.coordScale = getDisplayScale();
        ud.coordUnit = getDisplayUnit();
        ud.valueUnit = resultDisplayUnit(resultType);
        tAx.UserData = ud;
    end

    function postAxesClickCallback(src,~)
        if ~postProbeEnabled
            return;
        end

        if isa(src,'matlab.ui.control.UIAxes')
            tAx = src;
        else
            tAx = [];
            try
                tAx = ancestor(src,'matlab.ui.control.UIAxes');
            catch
                try
                    tAx = ancestor(src,'axes');
                catch
                    tAx = [];
                end
            end
            if isempty(tAx) || ~isvalid(tAx)
                return;
            end
        end
        ud = tAx.UserData;
        if ~isstruct(ud) || ~isfield(ud,'kind') || ~strcmp(ud.kind,'postResultAxes')
            return;
        end

        cp = tAx.CurrentPoint;
        xq = cp(1,1);
        yq = cp(1,2);

        [value,usedX,usedY,whereText] = probeResultAtPoint(xq,yq,ud);
        if isempty(value) || ~isfinite(value)
            postProbeLabel.Text = 'Probe: no value found.';
            return;
        end

        % Important: keep hold ON while drawing the probe marker.  With hold
        % off, MATLAB clears the axes on the next plot() call, which made the
        % contour disappear when the user clicked the value probe.
        wasHolding = ishold(tAx);
        hold(tAx,'on');
        delete(findobj(tAx,'Tag','PostProbeMarker'));
        cancelPostProbeDataTipDrag();

        xl = xlim(tAx); yl = ylim(tAx);
        xr = max(diff(xl),eps); yr = max(diff(yl),eps);

        plot(tAx,usedX,usedY,'o','MarkerSize',7,'LineWidth',1.4,...
            'MarkerEdgeColor',[0 0 0],'MarkerFaceColor',[1 1 1],...
            'Tag','PostProbeMarker','HitTest','off','PickableParts','none');

        labelX = usedX + 0.030*xr;
        labelY = usedY + 0.050*yr;
        hAlign = 'left';
        vAlign = 'bottom';

        % Keep the data-tip style box inside the visible axes when possible.
        if labelX > xl(1) + 0.78*xr
            labelX = usedX - 0.030*xr;
            hAlign = 'right';
        end
        if labelY > yl(1) + 0.82*yr
            labelY = usedY - 0.050*yr;
            vAlign = 'top';
        end

        pLine = plot(tAx,[usedX labelX],[usedY labelY],'-',...
            'Color',[0.15 0.15 0.15],'LineWidth',0.75,...
            'Tag','PostProbeMarker','HitTest','off','PickableParts','none');

        coordScale = 1; coordUnit = getDisplayUnit(); valueUnit = resultDisplayUnit(ud.resultType);
        if isfield(ud,'coordScale') && ~isempty(ud.coordScale), coordScale = ud.coordScale; end
        if isfield(ud,'coordUnit') && ~isempty(ud.coordUnit), coordUnit = ud.coordUnit; end
        if isfield(ud,'valueUnit') && ~isempty(ud.valueUnit), valueUnit = ud.valueUnit; end
        tipText = sprintf('X [%s]  %.4g\nY [%s]  %.4g\nValue [%s]  %.4g',...
            coordUnit,usedX*coordScale,coordUnit,usedY*coordScale,valueUnit,value);
        tipUD = struct('anchor',[usedX usedY],...
                       'dragRadius',0.35*min(xr,yr),...
                       'leaderLine',pLine);
        pText = text(tAx,labelX,labelY,tipText,...
            'Color',[0 0 0],'FontWeight','normal','FontSize',8,...
            'HorizontalAlignment',hAlign,'VerticalAlignment',vAlign,...
            'BackgroundColor','white','EdgeColor',[0.15 0.15 0.15],...
            'Margin',4,'Tag','PostProbeMarker','HitTest','on',...
            'PickableParts','all','Clipping','off',...
            'UserData',tipUD,'ButtonDownFcn',@beginPostProbeDataTipDrag);

        try
            pText.Interpreter = 'none';
        catch
        end

        if ~wasHolding
            hold(tAx,'off');
        end

        postProbeLabel.Text = sprintf('%s: %.4g %s',whereText,value,valueUnit);
        logMessage(sprintf('Probe %s at (%.4g %s, %.4g %s): %.6g %s',...
            ud.resultType,usedX*coordScale,coordUnit,usedY*coordScale,coordUnit,value,valueUnit));
    end

    function beginPostProbeDataTipDrag(src,~)
        % Drag only the MATLAB-style value probe data box.  The probed point
        % stays fixed; the box can be moved within a local radius around it.
        tAx = [];
        try
            tAx = ancestor(src,'matlab.ui.control.UIAxes');
        catch
            try
                tAx = ancestor(src,'axes');
            catch
                tAx = [];
            end
        end
        if isempty(tAx) || ~isvalid(tAx)
            return;
        end

        tipUD = src.UserData;
        if ~isstruct(tipUD) || ~isfield(tipUD,'anchor')
            return;
        end

        cp = tAx.CurrentPoint;
        textPos = src.Position;
        postProbeDragActive = true;
        postProbeDragAx = tAx;
        postProbeDragText = src;
        if isfield(tipUD,'leaderLine') && ~isempty(tipUD.leaderLine) && isvalid(tipUD.leaderLine)
            postProbeDragLine = tipUD.leaderLine;
        else
            postProbeDragLine = [];
        end
        postProbeDragAnchor = tipUD.anchor;
        postProbeDragOffset = textPos(1:2) - [cp(1,1) cp(1,2)];
        if isfield(tipUD,'dragRadius') && isfinite(tipUD.dragRadius) && tipUD.dragRadius > 0
            postProbeDragRadius = tipUD.dragRadius;
        else
            xl = xlim(tAx); yl = ylim(tAx);
            postProbeDragRadius = 0.35*min(max(diff(xl),eps),max(diff(yl),eps));
        end

        try
            fig.Pointer = 'hand';
        catch
        end
        try
            src.EdgeColor = [0 0.25 0.95];
            src.LineWidth = 1.2;
        catch
        end
        postProbeLabel.Text = 'Drag the data box; release to place.';
    end

    function handlePostProbeDataTipDrag()
        if ~postProbeDragActive
            return;
        end
        if isempty(postProbeDragAx) || ~isvalid(postProbeDragAx) || ...
                isempty(postProbeDragText) || ~isvalid(postProbeDragText)
            cancelPostProbeDataTipDrag();
            return;
        end

        tAx = postProbeDragAx;
        cp = tAx.CurrentPoint;
        newPos = [cp(1,1) cp(1,2)] + postProbeDragOffset;

        anchor = postProbeDragAnchor;
        xl = xlim(tAx); yl = ylim(tAx);
        xr = max(diff(xl),eps); yr = max(diff(yl),eps);

        % Clamp to a reasonable local radius, like MATLAB's data tips: the
        % point stays fixed and the box can be dragged nearby without getting lost.
        v = newPos - anchor;
        r = hypot(v(1),v(2));
        if isfinite(postProbeDragRadius) && postProbeDragRadius > 0 && r > postProbeDragRadius
            newPos = anchor + v/r*postProbeDragRadius;
        end

        % Also keep the anchor point of the text inside the visible axes area.
        padX = 0.015*xr;
        padY = 0.015*yr;
        newPos(1) = min(max(newPos(1),xl(1)+padX),xl(2)-padX);
        newPos(2) = min(max(newPos(2),yl(1)+padY),yl(2)-padY);

        textPos = postProbeDragText.Position;
        textPos(1:2) = newPos;
        postProbeDragText.Position = textPos;
        dx = newPos(1) - anchor(1);
        dy = newPos(2) - anchor(2);
        if dx >= 0
            postProbeDragText.HorizontalAlignment = 'left';
        else
            postProbeDragText.HorizontalAlignment = 'right';
        end
        if dy >= 0
            postProbeDragText.VerticalAlignment = 'bottom';
        else
            postProbeDragText.VerticalAlignment = 'top';
        end

        if ~isempty(postProbeDragLine) && isvalid(postProbeDragLine)
            postProbeDragLine.XData = [anchor(1) newPos(1)];
            postProbeDragLine.YData = [anchor(2) newPos(2)];
        end
        drawnow limitrate;
    end

    function endPostProbeDataTipDrag(~,~)
        if ~postProbeDragActive
            return;
        end
        if ~isempty(postProbeDragText) && isvalid(postProbeDragText)
            try
                postProbeDragText.EdgeColor = [0.15 0.15 0.15];
                postProbeDragText.LineWidth = 0.5;
            catch
            end
        end
        postProbeDragActive = false;
        postProbeDragAx = [];
        postProbeDragText = [];
        postProbeDragLine = [];
        postProbeDragAnchor = [NaN NaN];
        postProbeDragOffset = [0 0];
        postProbeDragRadius = NaN;
        try
            fig.Pointer = 'arrow';
        catch
        end
        if postProbeEnabled
            postProbeLabel.Text = 'Probe on: click plot or drag data box.';
        end
    end

    function cancelPostProbeDataTipDrag()
        postProbeDragActive = false;
        postProbeDragAx = [];
        postProbeDragText = [];
        postProbeDragLine = [];
        postProbeDragAnchor = [NaN NaN];
        postProbeDragOffset = [0 0];
        postProbeDragRadius = NaN;
        try
            fig.Pointer = 'arrow';
        catch
        end
    end

    function [value,usedX,usedY,whereText] = probeResultAtPoint(xq,yq,ud)
        value = [];
        usedX = xq;
        usedY = yq;
        whereText = 'Probe';

        x = ud.x(:);
        y = ud.y(:);
        conn = ud.conn;
        vals = ud.values(:);
        eIdx = findContainingTriangle(xq,yq,x,y,conn);

        if strcmp(ud.valueLocation,'element')
            if isempty(eIdx)
                [eIdx,usedX,usedY] = nearestElementCentroid(xq,yq,x,y,conn);
            else
                ids = conn(eIdx,:);
                usedX = xq;
                usedY = yq;
            end
            if ~isempty(eIdx) && eIdx<=numel(vals)
                value = vals(eIdx);
                whereText = sprintf('Elem %d',eIdx);
            end
            return;
        end

        if ~isempty(eIdx)
            ids = conn(eIdx,:);
            lam = barycentricCoords(xq,yq,x(ids),y(ids));
            value = sum(lam(:).*vals(ids));
            usedX = xq;
            usedY = yq;
            whereText = sprintf('Elem %d interp',eIdx);
            return;
        end

        [~,nodeIdx] = min(hypot(x-xq,y-yq));
        if ~isempty(nodeIdx)
            value = vals(nodeIdx);
            usedX = x(nodeIdx);
            usedY = y(nodeIdx);
            whereText = sprintf('Node %d',nodeIdx);
        end
    end

    function eIdx = findContainingTriangle(xq,yq,x,y,conn)
        eIdx = [];
        for ee = 1:size(conn,1)
            ids = conn(ee,:);
            lam = barycentricCoords(xq,yq,x(ids),y(ids));
            if all(isfinite(lam)) && all(lam >= -1e-8) && all(lam <= 1+1e-8)
                eIdx = ee;
                return;
            end
        end
    end

    function lam = barycentricCoords(xq,yq,xTri,yTri)
        x1=xTri(1); y1=yTri(1);
        x2=xTri(2); y2=yTri(2);
        x3=xTri(3); y3=yTri(3);
        den = (y2-y3)*(x1-x3) + (x3-x2)*(y1-y3);
        if abs(den) < eps
            lam = [NaN; NaN; NaN];
            return;
        end
        l1 = ((y2-y3)*(xq-x3) + (x3-x2)*(yq-y3))/den;
        l2 = ((y3-y1)*(xq-x3) + (x1-x3)*(yq-y3))/den;
        l3 = 1 - l1 - l2;
        lam = [l1; l2; l3];
    end

    function [eIdx,cx,cy] = nearestElementCentroid(xq,yq,x,y,conn)
        cxAll = mean(x(conn),2);
        cyAll = mean(y(conn),2);
        [~,eIdx] = min(hypot(cxAll-xq,cyAll-yq));
        cx = cxAll(eIdx);
        cy = cyAll(eIdx);
    end

    function normalizeDisplacementResults()
        if ~isfield(model.results,'Deformation') || isempty(model.results.Deformation)
            return;
        end

        [ux,uy,orderName] = splitDisplacementData(model.results.Deformation);
        model.results.Displacement = [ux(:) uy(:)];
        model.results.DOFOrder = orderName;
    end

    function [ux,uy] = getUXUY()
        n = numel(model.mesh.xcoords);
        if isfield(model.results,'Displacement') && ~isempty(model.results.Displacement) && ...
                isequal(size(model.results.Displacement),[n 2])
            ux = model.results.Displacement(:,1);
            uy = model.results.Displacement(:,2);
            return;
        end

        [ux,uy,orderName] = splitDisplacementData(model.results.Deformation);
        model.results.Displacement = [ux(:) uy(:)];
        model.results.DOFOrder = orderName;
    end

    function [ux,uy,orderName] = splitDisplacementData(q)
        n = numel(model.mesh.xcoords);

        if isequal(size(q),[n 2])
            ux = q(:,1);
            uy = q(:,2);
            orderName = 'matrix-n-by-2';
            return;
        end
        if isequal(size(q),[2 n])
            ux = q(1,:).';
            uy = q(2,:).';
            orderName = 'matrix-2-by-n';
            return;
        end

        q = q(:);
        if numel(q) ~= 2*n
            error('Displacement result size is wrong. Expected %d values, got %d.',2*n,numel(q));
        end

        uxI = q(1:2:end);
        uyI = q(2:2:end);
        uxB = q(1:n);
        uyB = q(n+1:end);

        if isfield(model.results,'DOFOrder') && strcmp(model.results.DOFOrder,'block')
            ux = uxB; uy = uyB; orderName = 'block'; return;
        end
        if isfield(model.results,'DOFOrder') && strcmp(model.results.DOFOrder,'interleaved')
            ux = uxI; uy = uyI; orderName = 'interleaved'; return;
        end

        scoreI = displacementSmoothnessScore(uxI,uyI);
        scoreB = displacementSmoothnessScore(uxB,uyB);

        if scoreB < 0.75*scoreI
            ux = uxB;
            uy = uyB;
            orderName = 'block';
        else
            ux = uxI;
            uy = uyI;
            orderName = 'interleaved';
        end
    end

    function score = displacementSmoothnessScore(ux,uy)
        conn = model.mesh.connectivity;
        if isempty(conn)
            score = inf;
            return;
        end

        e = unique(sort([conn(:,[1 2]); conn(:,[2 3]); conn(:,[3 1])],2),'rows');
        du = ux(e(:,1))-ux(e(:,2));
        dv = uy(e(:,1))-uy(e(:,2));
        denom = max(sum(ux.^2 + uy.^2),eps);
        score = sum(du.^2 + dv.^2)/denom;
    end

    function [vals,valueLocation] = getExternalStressStrainValues(resultType)
        % Stress/strain are intentionally not computed inside this GUI.
        % External post-processing should either:
        %   1) populate model.results.StressNodal / StrainNodal as nNodes x 3,
        %   2) populate model.results.StressElem  / StrainElem  as nElem  x 3, or
        %   3) provide external functions named func_strain and func_stress,
        %      or a combined function named func_postprocess / func_stress_strain that fills those
        %      fields. Columns are [X, Y, XY].
        ensureExternalPostResults(resultType);

        [family,col] = stressStrainFamilyAndColumn(resultType);
        if strcmp(family,'stress')
            nodalNames  = {'StressNodal','stressNodal','stress_nodal','NodalStress','nodalStress','Stress','stress'};
            elemNames   = {'StressElem','stressElem','StressElement','stressElement','ElementStress','elementStress'};
            scalarNames = {{'StressX','stressX','Sx','sx','SigmaX','sigmaX'}, ...
                           {'StressY','stressY','Sy','sy','SigmaY','sigmaY'}, ...
                           {'StressXY','stressXY','Sxy','sxy','TauXY','tauXY'}};
        else
            nodalNames  = {'StrainNodal','strainNodal','strain_nodal','NodalStrain','nodalStrain','Strain','strain'};
            elemNames   = {'StrainElem','strainElem','StrainElement','strainElement','ElementStrain','elementStrain'};
            scalarNames = {{'StrainX','strainX','Ex','ex','EpsX','epsX'}, ...
                           {'StrainY','strainY','Ey','ey','EpsY','epsY'}, ...
                           {'StrainXY','strainXY','Exy','exy','GammaXY','gammaXY'}};
        end

        [vals,valueLocation] = readVectorResult(nodalNames,col,'nodal');
        if ~isempty(vals), return; end
        [vals,valueLocation] = readVectorResult(elemNames,col,'element');
        if ~isempty(vals), return; end
        [vals,valueLocation] = readScalarResult(scalarNames{col});
        if ~isempty(vals), return; end

        error(['%s was requested, but the external post-processing results were not found.' newline newline ...
               'Expected one of these in model.results:' newline ...
               '  StressNodal / StrainNodal  = nNodes x 3, columns [X Y XY]' newline ...
               '  StressElem  / StrainElem   = nElem  x 3, columns [X Y XY]' newline ...
               'or scalar vectors such as StressX, StressY, StressXY, StrainX, etc.'],resultType);
    end

    function ensureExternalPostResults(resultType)
        [vals,~] = tryReadExternalStressStrainValues(resultType);
        if ~isempty(vals), return; end

        externalFns = {'func_strain','func_stress','func_postprocess','func_stress_strain','func_stressStrain','func_recover_stress_strain'};
        for ii = 1:numel(externalFns)
            fn = externalFns{ii};
            if exist(fn,'file') ~= 2
                continue;
            end
            logMessage(sprintf('Calling external post-processing function: %s',fn));
            tryRunExternalPostFunction(fn);
            [vals,~] = tryReadExternalStressStrainValues(resultType);
            if ~isempty(vals)
                return;
            end
        end
    end

    function [vals,valueLocation] = tryReadExternalStressStrainValues(resultType)
        vals = [];
        valueLocation = 'nodal';
        try
            [family,col] = stressStrainFamilyAndColumn(resultType);
            if strcmp(family,'stress')
                nodalNames  = {'StressNodal','stressNodal','stress_nodal','NodalStress','nodalStress','Stress','stress'};
                elemNames   = {'StressElem','stressElem','StressElement','stressElement','ElementStress','elementStress'};
                scalarNames = {{'StressX','stressX','Sx','sx','SigmaX','sigmaX'}, ...
                               {'StressY','stressY','Sy','sy','SigmaY','sigmaY'}, ...
                               {'StressXY','stressXY','Sxy','sxy','TauXY','tauXY'}};
            else
                nodalNames  = {'StrainNodal','strainNodal','strain_nodal','NodalStrain','nodalStrain','Strain','strain'};
                elemNames   = {'StrainElem','strainElem','StrainElement','strainElement','ElementStrain','elementStrain'};
                scalarNames = {{'StrainX','strainX','Ex','ex','EpsX','epsX'}, ...
                               {'StrainY','strainY','Ey','ey','EpsY','epsY'}, ...
                               {'StrainXY','strainXY','Exy','exy','GammaXY','gammaXY'}};
            end
            [vals,valueLocation] = readVectorResult(nodalNames,col,'nodal');
            if ~isempty(vals), return; end
            [vals,valueLocation] = readVectorResult(elemNames,col,'element');
            if ~isempty(vals), return; end
            [vals,valueLocation] = readScalarResult(scalarNames{col});
        catch
            vals = [];
            valueLocation = 'nodal';
        end
    end

    function tryRunExternalPostFunction(fn)
        % Supported external conventions:
        %   func_postprocess(model) returns either a result struct or model struct
        %   func_postprocess() modifies global model.results directly
        %   [StressNodal,StrainNodal] = func_postprocess(model)
        %   [StressNodal,StrainNodal,StressElem,StrainElem] = func_postprocess(model)
        lastMsg = '';
        try
            nOut = nargout(fn);
        catch
            nOut = -1;
        end

        callWithModel = true;
        for pass = 1:2
            try
                if nOut == 0
                    if callWithModel, feval(fn,model); else, feval(fn); end
                elseif nOut == 2
                    if callWithModel
                        [a,b] = feval(fn,model);
                    else
                        [a,b] = feval(fn);
                    end
                    assignExternalStressStrainOutputs(a,b,[],[]);
                elseif nOut >= 4
                    if callWithModel
                        [a,b,c,d] = feval(fn,model);
                    else
                        [a,b,c,d] = feval(fn);
                    end
                    assignExternalStressStrainOutputs(a,b,c,d);
                else
                    if callWithModel
                        out = feval(fn,model);
                    else
                        out = feval(fn);
                    end
                    mergeExternalPostOutput(out);
                end
                return;
            catch err
                lastMsg = err.message;
                callWithModel = false;
            end
        end
        logMessage(sprintf('External post-processing function %s did not run: %s',fn,lastMsg));
    end

    function assignExternalStressStrainOutputs(stressNodal,strainNodal,stressElem,strainElem)
        if nargin >= 1 && ~isempty(stressNodal), model.results.StressNodal = stressNodal; end
        if nargin >= 2 && ~isempty(strainNodal), model.results.StrainNodal = strainNodal; end
        if nargin >= 3 && ~isempty(stressElem),  model.results.StressElem  = stressElem;  end
        if nargin >= 4 && ~isempty(strainElem),  model.results.StrainElem  = strainElem;  end
    end

    function mergeExternalPostOutput(out)
        if isempty(out) || ~isstruct(out)
            return;
        end
        if isfield(out,'results') && isstruct(out.results)
            f = fieldnames(out.results);
            for ii = 1:numel(f)
                model.results.(f{ii}) = out.results.(f{ii});
            end
        else
            f = fieldnames(out);
            for ii = 1:numel(f)
                model.results.(f{ii}) = out.(f{ii});
            end
        end
    end

    function [family,col] = stressStrainFamilyAndColumn(resultType)
        switch resultType
            case 'Stress X'
                family = 'stress'; col = 1;
            case 'Stress Y'
                family = 'stress'; col = 2;
            case 'Stress XY (Shear)'
                family = 'stress'; col = 3;
            case 'Strain X'
                family = 'strain'; col = 1;
            case 'Strain Y'
                family = 'strain'; col = 2;
            case 'Strain XY (Shear)'
                family = 'strain'; col = 3;
            otherwise
                error('Unknown stress/strain result type: %s',resultType);
        end
    end

    function [vals,valueLocation] = readVectorResult(fieldNames,col,preferredLocation)
        vals = [];
        valueLocation = preferredLocation;
        for ii = 1:numel(fieldNames)
            f = fieldNames{ii};
            if ~isfield(model.results,f), continue; end
            data = model.results.(f);
            [candidate,loc] = extractResultColumn(data,col,preferredLocation);
            if ~isempty(candidate)
                vals = candidate;
                valueLocation = loc;
                return;
            end
        end
    end

    function [vals,valueLocation] = readScalarResult(fieldNames)
        vals = [];
        valueLocation = 'nodal';
        for ii = 1:numel(fieldNames)
            f = fieldNames{ii};
            if ~isfield(model.results,f), continue; end
            data = model.results.(f);
            [candidate,loc] = extractScalarVector(data);
            if ~isempty(candidate)
                vals = candidate;
                valueLocation = loc;
                return;
            end
        end
    end

    function [vals,valueLocation] = extractResultColumn(data,col,preferredLocation)
        vals = [];
        valueLocation = preferredLocation;
        if isempty(data), return; end
        nN = numel(model.mesh.xcoords);
        nE = size(model.mesh.connectivity,1);
        data = double(data);

        if isvector(data)
            [vals,valueLocation] = extractScalarVector(data);
            return;
        end

        if size(data,1) == nN && size(data,2) >= col
            vals = data(:,col);
            valueLocation = 'nodal';
        elseif size(data,1) == nE && size(data,2) >= col
            vals = data(:,col);
            valueLocation = 'element';
        elseif size(data,2) == nN && size(data,1) >= col
            vals = data(col,:).';
            valueLocation = 'nodal';
        elseif size(data,2) == nE && size(data,1) >= col
            vals = data(col,:).';
            valueLocation = 'element';
        end
    end

    function [vals,valueLocation] = extractScalarVector(data)
        vals = [];
        valueLocation = 'nodal';
        if isempty(data), return; end
        nN = numel(model.mesh.xcoords);
        nE = size(model.mesh.connectivity,1);
        data = double(data(:));
        if numel(data) == nN
            vals = data;
            valueLocation = 'nodal';
        elseif numel(data) == nE
            vals = data;
            valueLocation = 'element';
        end
    end

    function lockPostAxesAndColorbarLayout(tAx,cb)
        % Keep all post-processing axes aligned every time a plot is drawn,
        % redrawn, refreshed, or probed.
        %
        % colorbar() can silently shrink/reposition each axes by a slightly
        % different amount depending on tick text, exponent text, and result
        % range.  That is why the left/right edges sometimes line up only on
        % every other plot.  Each tile/sub-tab stores fixed slots for the axes
        % and colorbar; this helper repeatedly puts both objects back into
        % those slots after MATLAB has had a chance to draw tick/exponent text.
        if nargin < 2 || isempty(cb) || ~isvalid(cb)
            try
                cb = getappdata(tAx,'PostColorbar');
            catch
                cb = [];
            end
        end
        if nargin >= 2 && ~isempty(cb) && isvalid(cb)
            try
                setappdata(tAx,'PostColorbar',cb);
            catch
            end
        end

        try
            axSlot = getappdata(tAx,'PostAxesSlot');
        catch
            axSlot = [];
        end
        try
            cbSlot = getappdata(tAx,'PostColorbarSlot');
        catch
            cbSlot = [];
        end

        for pass = 1:2
            if pass == 2
                drawnow limitrate;
            end
            if ~isempty(axSlot) && ~isempty(tAx) && isvalid(tAx)
                try
                    tAx.Units = 'normalized';
                    tAx.Position = axSlot;
                    tAx.InnerPosition = axSlot;
                catch
                    try
                        tAx.Position = axSlot;
                    catch
                    end
                end
            end
            if ~isempty(cbSlot) && ~isempty(cb) && isvalid(cb)
                try
                    cb.Units = 'normalized';
                    cb.Position = cbSlot;
                catch
                end
            end
        end
    end

    function enforceAllPostPlotLayouts()
        % Apply the fixed axes/colorbar layout to every post-processing axes.
        % This is intentionally called after each Plot button press and after
        % each individual result plot, so the alignment fix survives adding,
        % removing, or re-plotting result selections.
        try
            axList = findall(postDisplayPanel,'Type','axes');
        catch
            axList = [];
        end
        for ii = 1:numel(axList)
            try
                tAx = axList(ii);
                if isappdata(tAx,'PostAxesSlot')
                    lockPostAxesAndColorbarLayout(tAx,[]);
                end
            catch
            end
        end
    end

    function lims = computePostAxesLims(tAx)
        % Auto-fit the AXES VIEW, not the object shape.
        %
        % The object keeps a 1:1 data aspect ratio, so the beam/plate keeps
        % the same visual proportions as it has in Mesh / Status.  We then
        % expand the shorter axis limit to match the plotting rectangle.  That
        % makes the white plotting region use the available tile space without
        % stretching the finite-element mesh itself.
        lims = [];
        pts = [];

        if ~isempty(model.mesh)
            x0 = model.mesh.xcoords(:);
            y0 = model.mesh.ycoords(:);
            pts = [pts; x0 y0];
            try
                [ux0,uy0] = getUXUY();
                if numel(ux0)==numel(x0) && numel(uy0)==numel(y0)
                    pts = [pts; x0+ux0(:), y0+uy0(:)]; %#ok<AGROW>
                end
            catch
            end
        elseif ~isempty(nodesG)
            pts = [pts; nodesG(:,1:2)];
        else
            return;
        end

        pts = pts(all(isfinite(pts),2),:);
        if isempty(pts), return; end

        xmin = min(pts(:,1)); xmax = max(pts(:,1));
        ymin = min(pts(:,2)); ymax = max(pts(:,2));
        xr = xmax-xmin;
        yr = ymax-ymin;

        if xr <= eps(max(abs([xmin xmax 1])))
            xr = max(1,abs(xmin)*0.1);
            xmin = xmin - 0.5*xr;
            xmax = xmax + 0.5*xr;
        end
        if yr <= eps(max(abs([ymin ymax 1])))
            yr = max(1,abs(ymin)*0.1);
            ymin = ymin - 0.5*yr;
            ymax = ymax + 0.5*yr;
        end

        % First add a small natural data padding.
        cx = 0.5*(xmin+xmax);
        cy = 0.5*(ymin+ymax);
        xRange = max(xr*1.08,eps);
        yRange = max(yr*1.25,eps);

        % Expand whichever range is too small so the equal-scale data view
        % fills the rectangular axes box.  This prevents the bad vertical
        % stretching from axis normal while still using the available space.
        axAspect = getPostAxesAspect(tAx);  % width / height of the axes box
        if xRange/yRange > axAspect
            yRange = xRange/axAspect;
        else
            xRange = yRange*axAspect;
        end

        lims = [cx-xRange/2, cx+xRange/2, cy-yRange/2, cy+yRange/2];
    end

    function aspect = getPostAxesAspect(tAx)
        aspect = 2.0;
        if isempty(tAx) || ~isvalid(tAx), return; end
        try
            oldUnits = tAx.Units;
            tAx.Units = 'pixels';
            p = tAx.Position;
            tAx.Units = oldUnits;
            if numel(p)>=4 && p(4)>0
                aspect = p(3)/p(4);
            end
        catch
            try
                p = tAx.Position;
                if numel(p)>=4 && p(4)>0
                    aspect = p(3)/p(4);
                end
            catch
            end
        end
        aspect = max(0.5,min(8,aspect));
    end

    function applyPostAxesView(tAx)
        grid(tAx,'on'); box(tAx,'on');
        set(tAx,'TickLabelInterpreter','latex');

        lims = computePostAxesLims(tAx);
        if ~isempty(lims) && numel(lims)==4 && all(isfinite(lims))
            xlim(tAx,lims(1:2));
            ylim(tAx,lims(3:4));
        else
            axis(tAx,'tight');
        end

        % Keep the model geometry visually correct.  The axes rectangle grows
        % to use the tile space; the object itself is not stretched.
        try
            tAx.DataAspectRatio = [1 1 1];
            tAx.DataAspectRatioMode = 'manual';
            tAx.PlotBoxAspectRatioMode = 'auto';
        catch
            try
                axis(tAx,'equal');
            catch
            end
        end

        try
            tAx.XTickMode = 'auto';
            tAx.YTickMode = 'auto';
            tAx.XTickLabelMode = 'auto';
            tAx.YTickLabelMode = 'auto';
        catch
        end
        scaleAxTicks(tAx,getDisplayScale());
        quietAxesToolbar(tAx);
    end

    function safeColorLimits(tAx,vals)
        vals = vals(isfinite(vals));
        if isempty(vals)
            return;
        end
        vMin = min(vals);
        vMax = max(vals);
        if abs(vMax-vMin) < eps(max(abs([vMin vMax 1])))
            delta = max(abs(vMax),1)*1e-9;
            caxis(tAx,[vMin-delta vMax+delta]);
        else
            caxis(tAx,[vMin vMax]);
        end
    end

    % =========================================================================
    % BC tab helpers
    % =========================================================================
    function setMode(mode)
        currentMode=mode; isC=strcmp(mode,'Constraint');
        if isC
            modeConstraintBtn.BackgroundColor=[0.3 0.6 1]; modeConstraintBtn.FontColor='white';
            modeLoadBtn.BackgroundColor=[0.9 0.9 0.9];     modeLoadBtn.FontColor='black';
            bcTypeDropDown.Items={'Fixed X','Fixed Y','Fixed XY','Deflect X','Deflect Y','Deflect XY'};
            bcTypeChangedCallback();
        else
            modeLoadBtn.BackgroundColor=[0.3 0.6 1];       modeLoadBtn.FontColor='white';
            modeConstraintBtn.BackgroundColor=[0.9 0.9 0.9]; modeConstraintBtn.FontColor='black';
            rebuildLoadDropdown();
        end
        updateEdgeDirRow(); logMessage(['Mode set to: ' mode]); drawBCLoadAx(); updateBCSummary();
    end

    function rebuildLoadDropdown()
        fu=getForceUnit(); mu=getMomentUnit();
        isEdge=strcmp(currentTargetType,'Edge');
        isCurved=isEdge&&selectedEdgeIsCurved();
        if isEdge && ~isCurved
            items={sprintf('Force X (%s)',fu),...
                   sprintf('Force Y (%s)',fu),...
                   sprintf('Force ∥ (%s)',fu),...
                   sprintf('Force ⊥ (%s)',fu),...
                   sprintf('Moment (%s)',mu)};
        else
            items={sprintf('Force X (%s)',fu),...
                   sprintf('Force Y (%s)',fu),...
                   sprintf('Moment (%s)',mu)};
        end
        bcTypeDropDown.Items=items;
        if ~ismember(bcTypeDropDown.Value,items)
            bcTypeDropDown.Value=items{1};
        end
        % Show curved warning instead of input fields when curved edge selected
        if isCurved&&isEdge
            bcValueLabel.Visible='off'; bcValueField.Visible='off';
            hideParPerpFields();
        end
        setParPerpFieldsLocked(false);
        bcTypeChangedCallback();
    end

    function tf=selectedEdgeIsCurved()
        tf=false;
        if isempty(selectedTargetID)||isempty(edgesG), return; end
        idx=selectedTargetID;
        if idx>size(edgesG,1), return; end
        % Full circle/arc — edgeTypeG==3
        if ~isempty(edgeTypeG)&&idx<=numel(edgeTypeG)&&edgeTypeG(idx)==3
            tf=true; return;
        end
        % Arc encoded as two endpoints + a midpoint that lies off the straight line
        if ~isempty(midpointsG)&&idx<=size(midpointsG,1)&&~isnan(midpointsG(idx,1))&&~isnan(midpointsG(idx,2))
            edgeRow=edgesG(idx,:);
            nodeIDs=edgeRow(~isnan(edgeRow)&edgeRow>0&edgeRow<=size(nodesG,1));
            if numel(nodeIDs)>=2
                p1=nodesG(nodeIDs(1),:); p2=nodesG(nodeIDs(2),:);
                pm=midpointsG(idx,:);
                modelSize=max([(max(nodesG(:,1))-min(nodesG(:,1))),(max(nodesG(:,2))-min(nodesG(:,2))),eps]);
                d=distancePointToSegment(pm(1),pm(2),p1(1),p1(2),p2(1),p2(2));
                if d>1e-4*modelSize
                    tf=true; return;
                end
            end
        end
    end

    function bcTypeChangedCallback(~,~)
        val=bcTypeDropDown.Value;
        if strcmp(currentMode,'Constraint')
            isDeflect=startsWith(val,'Deflect');
            bcValueLabel.Visible=matlab.lang.OnOffSwitchState(isDeflect);
            bcValueField.Visible=matlab.lang.OnOffSwitchState(isDeflect);
            if isDeflect, bcValueLabel.Text=sprintf('Val [%s]:',getDisplayUnit()); end
            return;
        end
        % Load mode — ∥/⊥ items only exist for straight edges
        isParPerp=contains(val,'∥')||contains(val,'⊥');
        isCurved=strcmp(currentTargetType,'Edge')&&selectedEdgeIsCurved();
        fu=getForceUnit();
        if isCurved
            % Curved edge — just show the warning, hide everything else
            bcValueLabel.Visible='off'; bcValueField.Visible='off';
            hideParPerpFields();
        elseif isParPerp
            bcValueLabel.Visible='off'; bcValueField.Visible='off';
            showPar=contains(val,'∥'); showPerp=contains(val,'⊥');
            parDirLabel.Text=sprintf('∥ (%s):',fu);
            perpDirLabel.Text=sprintf('⊥ (%s):',fu);
            parDirLabel.Visible=matlab.lang.OnOffSwitchState(showPar);
            bcParField.Visible=matlab.lang.OnOffSwitchState(showPar);
            perpDirLabel.Visible=matlab.lang.OnOffSwitchState(showPerp);
            bcPerpField.Visible=matlab.lang.OnOffSwitchState(showPerp);
            bcParPerpHint.Visible='on';
            setParPerpFieldsLocked(false);
        else
            bcValueLabel.Visible='on'; bcValueField.Visible='on';
            bcValueLabel.Text=sprintf('Value (%s):',fu);
            hideParPerpFields();
        end
    end

    function setParPerpFieldsLocked(locked)
        grey=[0.88 0.88 0.88];
        white=[1 1 1];
        bg=grey*double(locked)+white*double(~locked);
        bcParField.Editable=matlab.lang.OnOffSwitchState(~locked);
        bcPerpField.Editable=matlab.lang.OnOffSwitchState(~locked);
        bcParField.BackgroundColor=bg;
        bcPerpField.BackgroundColor=bg;
        bcParField.FontColor=[0.5 0.5 0.5]*double(locked)+[0 0 0]*double(~locked);
        bcPerpField.FontColor=[0.5 0.5 0.5]*double(locked)+[0 0 0]*double(~locked);
    end

    function hideParPerpFields()
        parDirLabel.Visible='off'; bcParField.Visible='off';
        perpDirLabel.Visible='off'; bcPerpField.Visible='off';
        bcParPerpHint.Visible='off';
    end

    function setTargetType(ttype)
        currentTargetType=ttype;
        for btn=[typeVertexBtn,typeEdgeBtn,typePointBtn]
            btn.BackgroundColor=[0.9 0.9 0.9]; btn.FontColor='black'; end
        switch ttype
            case 'Vertex', typeVertexBtn.BackgroundColor=[0.3 0.6 1]; typeVertexBtn.FontColor='white';
            case 'Edge',   typeEdgeBtn.BackgroundColor  =[0.3 0.6 1]; typeEdgeBtn.FontColor  ='white';
            case 'Point',  typePointBtn.BackgroundColor =[0.3 0.6 1]; typePointBtn.FontColor ='white';
        end
        selectedTargetType=''; selectedTargetID=[]; selectedTargetPoint=[];
        hoverTargetType=''; hoverTargetID=[]; lastHoverKey='';
        selectedTargetField.Value='(click axes to select)';
        updateEdgeDirRow();
        if strcmp(currentMode,'Load'), rebuildLoadDropdown(); end
        logMessage(['Target type set to: ' ttype]);
        drawBCLoadAx(); updateBCSummary();
    end

    function updateEdgeDirRow()
        % Direction row removed — par/perp now handled via Type dropdown
    end

    function setEdgeDir(dirMode)
        currentEdgeDir=dirMode;
        if strcmp(dirMode,'xy')
            edgeDirXYBtn.BackgroundColor=[0.3 0.6 1];       edgeDirXYBtn.FontColor='white';
            edgeDirParPerpBtn.BackgroundColor=[0.9 0.9 0.9]; edgeDirParPerpBtn.FontColor='black';
            bcValueLabel.Visible='on'; bcValueField.Visible='on';
        else
            edgeDirParPerpBtn.BackgroundColor=[0.3 0.6 1];   edgeDirParPerpBtn.FontColor='white';
            edgeDirXYBtn.BackgroundColor=[0.9 0.9 0.9];      edgeDirXYBtn.FontColor='black';
            bcValueLabel.Visible='off'; bcValueField.Visible='off';
        end
    end

    function clearSelectionCallback(~,~)
        selectedTargetType=''; selectedTargetID=[]; selectedTargetPoint=[];
        hoverTargetType=''; hoverTargetID=[]; lastHoverKey='';
        selectedTargetField.Value='(click axes to select)';
        drawBCLoadAx(); updateBCSummary(); logMessage('Selection cleared.');
    end

    function applyBCCallback(~,~)
        if isempty(model.mesh)
            uialert(fig,'Generate a mesh before applying boundary conditions or loads.','No Mesh');
            logMessage('BC apply blocked: no mesh loaded.'); return;
        end
        if isempty(selectedTargetType), uialert(fig,'Select a target on the mesh first.','No Target'); return; end
        xMag=0; yMag=0; bcType=bcTypeDropDown.Value;
        if strcmp(currentMode,'Load')
            fu=getForceUnit(); mu=getMomentUnit();
            isParPerp=contains(bcType,'∥')||contains(bcType,'⊥');
            if isParPerp&&strcmp(selectedTargetType,'Edge')&&selectedEdgeIsCurved()
                uialert(fig,...
                    ['Cannot apply ∥/⊥ load to a curved edge.' newline ...
                     'Switch to Force X or Force Y instead.'],...
                    'Curved Edge');
                return;
            end
            if isParPerp&&strcmp(selectedTargetType,'Edge')
                % Read par and/or perp values
                parVal=0; perpVal=0;
                if contains(bcType,'∥')
                    parVal=str2double(bcParField.Value);
                    if isnan(parVal), uialert(fig,'Enter a valid ∥ value.','Invalid Value'); return; end
                end
                if contains(bcType,'⊥')
                    perpVal=str2double(bcPerpField.Value);
                    if isnan(perpVal), uialert(fig,'Enter a valid ⊥ value.','Invalid Value'); return; end
                end
                [xEdge,yEdge]=getEdgePolyline(selectedTargetID);
                if numel(xEdge)>=2
                    tx=xEdge(end)-xEdge(1); ty=yEdge(end)-yEdge(1); len=hypot(tx,ty);
                    if len>eps, tx=tx/len; ty=ty/len; end
                    nx=-ty; ny=tx;
                    xMag=parVal*tx+perpVal*nx; yMag=parVal*ty+perpVal*ny;
                    logMessage(sprintf('∥/⊥ (%.4g, %.4g) -> Fx=%.4g Fy=%.4g',parVal,perpVal,xMag,yMag));
                else, uialert(fig,'Could not get edge direction.','Edge Error'); return; end
                bcType=sprintf('Force ∥/⊥ (%s)',fu);
            else
                rawVal=str2double(bcValueField.Value);
                if isnan(rawVal), uialert(fig,'Enter a valid load value.','Invalid Value'); return; end
                if strcmp(bcType,sprintf('Force X (%s)',fu)),      xMag=rawVal; yMag=0;
                elseif strcmp(bcType,sprintf('Force Y (%s)',fu)),  xMag=0;      yMag=rawVal;
                elseif strcmp(bcType,sprintf('Moment (%s)',mu)),   xMag=0;      yMag=0;
                end
            end
        else
            switch bcType
                case 'Fixed X',   xMag=0;   yMag=NaN;
                case 'Fixed Y',   xMag=NaN; yMag=0;
                case 'Fixed XY',  xMag=0;   yMag=0;
                case 'Deflect X', d=str2double(bcValueField.Value); if isnan(d), uialert(fig,'Invalid deflection.','Invalid'); return; end; xMag=d/getDisplayScale(); yMag=NaN;
                case 'Deflect Y', d=str2double(bcValueField.Value); if isnan(d), uialert(fig,'Invalid deflection.','Invalid'); return; end; xMag=NaN; yMag=d/getDisplayScale();
                case 'Deflect XY',d=str2double(bcValueField.Value); if isnan(d), uialert(fig,'Invalid deflection.','Invalid'); return; end; xMag=d/getDisplayScale(); yMag=d/getDisplayScale();
            end
        end
        affectedNodes=resolveMeshNodes(selectedTargetType,selectedTargetID,selectedTargetPoint);
        if isempty(affectedNodes), uialert(fig,'Could not find mesh nodes for selected target.','No Nodes'); return; end
        if strcmp(currentMode,'Constraint'), storeType='constraint';
        elseif strcmp(selectedTargetType,'Vertex')||strcmp(selectedTargetType,'Point'), storeType='point load';
        else, storeType='traction load'; end
        if strcmp(currentMode,'Constraint')
            model.constraints=removeBCsAt(model.constraints,selectedTargetType,selectedTargetID,'');
            n=numel(model.constraints)+1;
            model.constraints(n).type=storeType; model.constraints(n).x_mag=xMag;
            model.constraints(n).y_mag=yMag; model.constraints(n).affected_nodes=affectedNodes;
            model.constraints(n).point=selectedTargetPoint; model.constraints(n).regionType=selectedTargetType;
            model.constraints(n).regionID=selectedTargetID;
            logMessage(sprintf('Constraint "%s" -> nodes %s',bcType,mat2str(affectedNodes)));
        else
            if ~confirmReasonableLoad(xMag,yMag,selectedTargetType,selectedTargetID)
                logMessage('Load apply canceled after magnitude warning.');
                return;
            end
            % Do not silently stack duplicate Force X / Force Y loads on the same target.
            % X and Y components may coexist, but re-applying Force X replaces the old Force X.
            model.loads=removeLoadsAtSameComponent(model.loads,selectedTargetType,selectedTargetID,xMag,yMag);
            n=numel(model.loads)+1;
            model.loads(n).type=storeType; model.loads(n).x_mag=xMag;
            model.loads(n).y_mag=yMag; model.loads(n).affected_nodes=affectedNodes;
            model.loads(n).point=selectedTargetPoint; model.loads(n).regionType=selectedTargetType;
            model.loads(n).regionID=selectedTargetID;
            logMessage(sprintf('Load "%s" (x=%.4g,y=%.4g) -> nodes %s',bcType,xMag,yMag,mat2str(affectedNodes)));
        end
        drawBCLoadAx(); updateBCSummary();
    end

    function nodeIdxs=resolveMeshNodes(rType,rID,rPoint)
        nodeIdxs=[]; if isempty(model.mesh), return; end
        mx=model.mesh.xcoords(:); my=model.mesh.ycoords(:);
        switch rType
            case 'Vertex', [~,idx]=min(hypot(mx-rPoint(1),my-rPoint(2))); nodeIdxs=idx;
            case 'Edge'
                [xEdge,yEdge]=getEdgePolyline(rID);
                if numel(xEdge)<2
                    [~,idx]=min(hypot(mx-rPoint(1),my-rPoint(2))); nodeIdxs=idx; return; end
                d=inf(numel(mx),1);
                for k=1:(numel(xEdge)-1)
                    if any(isnan([xEdge(k),yEdge(k),xEdge(k+1),yEdge(k+1)])), continue; end
                    d=min(d,arrayfun(@(i) distancePointToSegment(mx(i),my(i),xEdge(k),yEdge(k),xEdge(k+1),yEdge(k+1)),(1:numel(mx))'));
                end
                dSorted=sort(d); onEdge=dSorted(dSorted<median(dSorted)*0.01+1e-12);
                if ~isempty(onEdge), snapTol=max(onEdge)*2+1e-10;
                else, snapTol=sum(hypot(diff(xEdge),diff(yEdge)))*0.01; end
                nodeIdxs=find(d<=snapTol)';
            case 'Point'
                [~,idx]=min(hypot(mx-rPoint(1),my-rPoint(2))); nodeIdxs=idx;
        end
    end

    function deleteBCCallback(~,~)
        if isempty(selectedTargetType), uialert(fig,'Select a target first.','No Target'); return; end
        nBefore=numel(model.constraints)+numel(model.loads);
        model.constraints=removeBCsAt(model.constraints,selectedTargetType,selectedTargetID,'');
        model.loads=removeBCsAt(model.loads,selectedTargetType,selectedTargetID,'');
        removed=nBefore-(numel(model.constraints)+numel(model.loads));
        if removed>0, logMessage(sprintf('Removed %d BC(s).',removed));
        else, logMessage('No BCs found at selected target.'); end
        drawBCLoadAx(); updateBCSummary();
    end

    function bcArr=removeBCsAt(bcArr,rType,rID,matchType)
        keep=true(1,numel(bcArr));
        for k=1:numel(bcArr)
            sameTarget=strcmp(bcArr(k).regionType,rType)&&isequal(bcArr(k).regionID,rID);
            sameType=isempty(matchType)||strcmp(bcArr(k).type,matchType);
            if sameTarget&&sameType, keep(k)=false; end
        end
        bcArr=bcArr(keep);
    end

    function bcArr=removeLoadsAtSameComponent(bcArr,rType,rID,newFx,newFy)
        % Re-applying a component should edit/replace it, not stack another
        % copy. This prevents accidental double-loading like 1e4 N + 1e14 N
        % on the same edge. Separate X and Y components can still coexist.
        keep=true(1,numel(bcArr));
        newHasX=abs(newFx)>eps;
        newHasY=abs(newFy)>eps;
        newIsMoment=(~newHasX)&&(~newHasY);
        for k=1:numel(bcArr)
            sameTarget=strcmp(bcArr(k).regionType,rType)&&isequal(bcArr(k).regionID,rID);
            if ~sameTarget, continue; end
            oldHasX=abs(bcArr(k).x_mag)>eps;
            oldHasY=abs(bcArr(k).y_mag)>eps;
            oldIsMoment=(~oldHasX)&&(~oldHasY);
            sameComponent=(newIsMoment&&oldIsMoment) || ...
                (newHasX&&~newHasY&&oldHasX&&~oldHasY) || ...
                (~newHasX&&newHasY&&~oldHasX&&oldHasY) || ...
                (newHasX&&newHasY&&oldHasX&&oldHasY);
            if sameComponent, keep(k)=false; end
        end
        bcArr=bcArr(keep);
    end

    function ok=confirmReasonableLoad(Fx,Fy,rType,rID)
        ok=true;
        Fmag=hypot(Fx,Fy);
        if Fmag==0, return; end

        % Student-GUI guardrail: accidental extra zeros are common. This does
        % not change the physics; it only asks for confirmation before storing
        % an extreme force value.
        warnThreshold=1e9; % N or lbf depending on current units
        if Fmag < warnThreshold, return; end

        msg=sprintf(['This load is very large: %.4g %s.\n\n' ...
            'For example, 1e14 N on a 10 m steel bar can produce displacements on the order of 1e5 m.\n' ...
            'That usually means an accidental extra-zero/unit-entry mistake.\n\n' ...
            'Target: %s %s\n\nApply it anyway?'], ...
            Fmag,getForceUnit(),rType,mat2str(rID));
        try
            choice=uiconfirm(fig,msg,'Large Load Warning', ...
                'Options',{'Apply Anyway','Cancel'}, ...
                'DefaultOption',2,'CancelOption',2);
            ok=strcmp(choice,'Apply Anyway');
        catch
            % If uiconfirm is unavailable for any reason, fall back to alert
            % and cancel safely rather than silently accepting a huge value.
            uialert(fig,msg,'Large Load Warning');
            ok=false;
        end
    end

    function bcLoadAxesClickCallback(~,~)
        if isempty(nodesG)||~strcmp(tabGroup.SelectedTab.Title,'Boundary Conditions & Loading'), return; end
        cp=bcLoadAx.CurrentPoint; cx=cp(1,1); cy=cp(1,2);
        if ~pointIsInsideAxes(cx,cy), return; end
        selectTargetAtPoint(cx,cy,true);
    end

    function selectTargetAtPoint(xClick,yClick,writeLog)
        [tType,tID,tPoint,~,dispText,ok,msg]=resolveSelectableTargetAtPoint(...
            currentTargetType,xClick,yClick,bcLoadAx);

        if ~ok
            selectedTargetField.Value=dispText;
            if writeLog&&~isempty(msg), logMessage(['Selection: ' msg]); end
            drawBCLoadAx(); updateBCSummary();
            return;
        end

        selectedTargetType=tType;
        selectedTargetID=tID;
        selectedTargetPoint=tPoint;
        selectedTargetField.Value=dispText;

        if writeLog
            switch selectedTargetType
                case 'Vertex'
                    logMessage(sprintf('Selected Vertex %d at (%.4f,%.4f)',selectedTargetID,selectedTargetPoint(1),selectedTargetPoint(2)));
                case 'Edge'
                    logMessage(sprintf('Selected Edge %d.',selectedTargetID));
                case 'Point'
                    logMessage(sprintf('Snapped to node %d at (%.4f,%.4f)',selectedTargetID,selectedTargetPoint(1),selectedTargetPoint(2)));
            end
        end

        if strcmp(currentMode,'Load'), rebuildLoadDropdown(); end
        drawBCLoadAx(); updateBCSummary();
    end

    function [idx,minDist]=nearestEdgeIndex(xClick,yClick)
        [idx,minDist]=nearestEdgeIndexOnAxes(bcLoadAx,xClick,yClick);
    end

    function tol=edgePickTolerance()
        if isempty(nodesG), tol=inf; return; end
        axRangeX=diff(bcLoadAx.XLim); axRangeY=diff(bcLoadAx.YLim); axPos=bcLoadAx.Position;
        pixPerUnitX=axPos(3)/axRangeX; pixPerUnitY=axPos(4)/axRangeY;
        tol=8/min(pixPerUnitX,pixPerUnitY);
        modelSpan=max([(max(nodesG(:,1))-min(nodesG(:,1))),(max(nodesG(:,2))-min(nodesG(:,2))),eps]);
        tol=min(tol,0.05*modelSpan);
    end

    function tf=pointIsInsideAxes(x,y)
        tf=x>=bcLoadAx.XLim(1)&&x<=bcLoadAx.XLim(2)&&y>=bcLoadAx.YLim(1)&&y<=bcLoadAx.YLim(2);
    end

    function handleMeshRefinementHover()
        if isempty(model.mesh)||~strcmp(tabGroup.SelectedTab.Title,'Mesh / Status')
            if ~isempty(refLastHoverKey)
                clearRefinementHover(); redrawMeshAxWithRefinements();
            end
            return;
        end

        cp=ax.CurrentPoint; newType=''; newID=[]; newKey='none';
        if pointIsInsideTargetAxes(ax,cp(1,1),cp(1,2))
            switch refSelectionTypeDropDown.Value
                case 'Vertex'
                    if ~isempty(nodesG)
                        dists=hypot(nodesG(:,1)-cp(1,1),nodesG(:,2)-cp(1,2));
                        [dMin,idx]=min(dists);
                        if dMin<=pointPickToleranceOnAxes(ax)
                            newType='Vertex'; newID=idx; newKey=sprintf('Vertex:%d',idx);
                        end
                    end
                case 'Edge'
                    [idx,dist]=nearestEdgeIndexOnAxes(ax,cp(1,1),cp(1,2));
                    if ~isempty(idx)&&dist<=edgePickToleranceOnAxes(ax)
                        newType='Edge'; newID=idx; newKey=sprintf('Edge:%d',idx);
                    end
                case 'Point'
                    mx=model.mesh.xcoords(:); my=model.mesh.ycoords(:);
                    [dMin,idx]=min(hypot(mx-cp(1,1),my-cp(1,2)));
                    if dMin<=pointPickToleranceOnAxes(ax)
                        newType='Point'; newID=idx; newKey=sprintf('Point:%d',idx);
                    end
            end
        end

        if ~strcmp(newKey,refLastHoverKey)
            refHoverType=newType; refHoverID=newID; refLastHoverKey=newKey;
            redrawMeshAxWithRefinements();
        end
    end

    function tol=pointPickToleranceOnAxes(targetAx)
        if isempty(nodesG)&&isempty(model.mesh), tol=inf; return; end
        axRangeX=diff(targetAx.XLim); axRangeY=diff(targetAx.YLim); axPos=targetAx.Position;
        pixPerUnitX=axPos(3)/max(axRangeX,eps); pixPerUnitY=axPos(4)/max(axRangeY,eps);
        tol=10/min(pixPerUnitX,pixPerUnitY);
        if ~isempty(nodesG)
            modelSpan=max([(max(nodesG(:,1))-min(nodesG(:,1))),(max(nodesG(:,2))-min(nodesG(:,2))),eps]);
        else
            modelSpan=max([(max(model.mesh.xcoords)-min(model.mesh.xcoords)),(max(model.mesh.ycoords)-min(model.mesh.ycoords)),eps]);
        end
        tol=min(tol,0.05*modelSpan);
    end

    function mouseMoveCallback(~,~)
        if postProbeDragActive
            handlePostProbeDataTipDrag();
            return;
        end
        if strcmp(leftPanelMode,'meshRefinement')
            handleMeshRefinementHover();
            return;
        end
        if isempty(nodesG)||~strcmp(tabGroup.SelectedTab.Title,'Boundary Conditions & Loading')
            if ~isempty(lastHoverKey), hoverTargetType=''; hoverTargetID=[]; lastHoverKey=''; drawBCLoadAx(); updateBCSummary(); end
            return;
        end
        if ~strcmp(currentTargetType,'Edge')
            if ~isempty(lastHoverKey), hoverTargetType=''; hoverTargetID=[]; lastHoverKey=''; drawBCLoadAx(); updateBCSummary(); end
            return;
        end
        cp=bcLoadAx.CurrentPoint; newType=''; newID=[]; newKey='none';
        if pointIsInsideAxes(cp(1,1),cp(1,2))
            [idx,dist]=nearestEdgeIndex(cp(1,1),cp(1,2));
            if ~isempty(idx)&&dist<=edgePickTolerance()
                newType='Edge'; newID=idx; newKey=sprintf('Edge:%d',idx); end
        end
        if ~strcmp(newKey,lastHoverKey)
            hoverTargetType=newType; hoverTargetID=newID; lastHoverKey=newKey;
            drawBCLoadAx(); updateBCSummary();
        end
    end

    function dMin=distancePointToPolyline(px,py,xLine,yLine)
        dMin=inf;
        for k=1:(numel(xLine)-1)
            if any(isnan([xLine(k),yLine(k),xLine(k+1),yLine(k+1)])), continue; end
            dMin=min(dMin,distancePointToSegment(px,py,xLine(k),yLine(k),xLine(k+1),yLine(k+1)));
        end
    end

    function d=distancePointToSegment(px,py,x1,y1,x2,y2)
        vx=x2-x1; vy=y2-y1; c2=vx*vx+vy*vy;
        if c2<=eps, d=hypot(px-x1,py-y1); return; end
        a=max(0,min(1,((px-x1)*vx+(py-y1)*vy)/c2));
        d=hypot(px-(x1+a*vx),py-(y1+a*vy));
    end

    function [xEdge,yEdge]=getEdgePolyline(edgeIdx)
        xEdge=[]; yEdge=[];
        if isempty(edgesG)||edgeIdx>size(edgesG,1), return; end
        edgeRow=edgesG(edgeIdx,:);
        nodeIDs=edgeRow(~isnan(edgeRow)&edgeRow>0&edgeRow<=size(nodesG,1));
        hasMid=~isempty(midpointsG)&&edgeIdx<=size(midpointsG,1);
        isCircle=~isempty(edgeTypeG)&&edgeTypeG(edgeIdx)==3;
        if isCircle
            if numel(nodeIDs)>=1&&hasMid&&~isnan(midpointsG(edgeIdx,1))
                cx_=nodesG(nodeIDs(1),1); cy_=nodesG(nodeIDs(1),2); r=midpointsG(edgeIdx,1);
                if r>eps, theta=linspace(0,2*pi,120); xEdge=cx_+r*cos(theta); yEdge=cy_+r*sin(theta); end
            end
            return;
        end
        if numel(nodeIDs)<2
            if hasMid&&~isnan(midpointsG(edgeIdx,1))&&~isnan(midpointsG(edgeIdx,2))
                xEdge=midpointsG(edgeIdx,1); yEdge=midpointsG(edgeIdx,2); end
            return;
        end
        p1=nodesG(nodeIDs(1),:); p2=nodesG(nodeIDs(2),:);
        if hasMid&&~isnan(midpointsG(edgeIdx,1))&&~isnan(midpointsG(edgeIdx,2))
            pm=midpointsG(edgeIdx,:);
            modelSize=max([(max(nodesG(:,1))-min(nodesG(:,1))),(max(nodesG(:,2))-min(nodesG(:,2))),eps]);
            if distancePointToSegment(pm(1),pm(2),p1(1),p1(2),p2(1),p2(2))>1e-4*modelSize
                [xArc,yArc]=circularArcThroughThreePoints(p1,pm,p2,60);
                if numel(xArc)>=2, xEdge=xArc; yEdge=yArc; return; end
            end
        end
        xEdge=[p1(1) p2(1)]; yEdge=[p1(2) p2(2)];
    end

    function [xArc,yArc]=circularArcThroughThreePoints(p1,pm,p2,nPts)
        xArc=[]; yArc=[];
        A=2*[pm(1)-p1(1),pm(2)-p1(2); p2(1)-p1(1),p2(2)-p1(2)];
        b=[pm(1)^2+pm(2)^2-p1(1)^2-p1(2)^2; p2(1)^2+p2(2)^2-p1(1)^2-p1(2)^2];
        if abs(det(A))<1e-14, return; end
        c=A\b; cx_=c(1); cy_=c(2);
        r=hypot(p1(1)-cx_,p1(2)-cy_); if r<=eps, return; end
        a1=atan2(p1(2)-cy_,p1(1)-cx_); am=atan2(pm(2)-cy_,pm(1)-cx_); a3=atan2(p2(2)-cy_,p2(1)-cx_);
        if mod(am-a1,2*pi)<=mod(a3-a1,2*pi), theta=linspace(a1,a1+mod(a3-a1,2*pi),nPts);
        else, theta=linspace(a1,a1-mod(a1-a3,2*pi),nPts); end
        xArc=cx_+r*cos(theta); yArc=cy_+r*sin(theta);
    end

    function drawSelectableEdges()
        drawSelectableEdgesOnAxes(bcLoadAx);
    end

    function drawSelectableEdgesOnAxes(targetAx)
        if isempty(edgesG), return; end
        for e=1:size(edgesG,1)
            [xEdge,yEdge]=getEdgePolyline(e);
            if numel(xEdge)>=2
                plot(targetAx,xEdge,yEdge,'-','Color',[1 1 1 0],'LineWidth',14,'HitTest','off','PickableParts','none');
                plot(targetAx,xEdge,yEdge,'-','Color',[0.9 0.1 0.1],'LineWidth',2.5,'HitTest','off','PickableParts','none');
            end
        end
        if ~isempty(midpointsG)
            scatter(targetAx,midpointsG(:,1),midpointsG(:,2),36,'s',...
                'MarkerEdgeColor',[0.75 0.05 0.05],'MarkerFaceColor',[1 0.85 0.85],...
                'LineWidth',1.2,'HitTest','off','PickableParts','none');
        end
    end

    function drawHoverTarget()
        if ~strcmp(hoverTargetType,'Edge')||isempty(hoverTargetID), return; end
        if strcmp(selectedTargetType,'Edge')&&isequal(selectedTargetID,hoverTargetID), return; end
        [xEdge,yEdge]=getEdgePolyline(hoverTargetID);
        if numel(xEdge)>=2
            plot(bcLoadAx,xEdge,yEdge,'-','Color',[0.95 0.65 0],'LineWidth',9,'HitTest','off','PickableParts','none');
            plot(bcLoadAx,xEdge,yEdge,'-','Color',[1 0.97 0.2],'LineWidth',5,'HitTest','off','PickableParts','none');
        end
    end

    function drawSelectedTarget()
        if isempty(selectedTargetType), return; end
        switch selectedTargetType
            case 'Vertex'
                if ~isempty(selectedTargetID)&&selectedTargetID<=size(nodesG,1)
                    plot(bcLoadAx,nodesG(selectedTargetID,1),nodesG(selectedTargetID,2),'ro',...
                        'MarkerSize',12,'LineWidth',2,'MarkerFaceColor','y','HitTest','off','PickableParts','none'); end
            case 'Edge'
                if ~isempty(selectedTargetID)
                    [xEdge,yEdge]=getEdgePolyline(selectedTargetID);
                    if numel(xEdge)>=2
                        plot(bcLoadAx,xEdge,yEdge,'-','Color',[0.9 0.5 0],'LineWidth',9,'HitTest','off','PickableParts','none');
                        plot(bcLoadAx,xEdge,yEdge,'-','Color',[1 0.95 0.0],'LineWidth',5,'HitTest','off','PickableParts','none');
                    end
                    if ~isempty(selectedTargetPoint)
                        plot(bcLoadAx,selectedTargetPoint(1),selectedTargetPoint(2),'d',...
                            'MarkerSize',10,'LineWidth',2,'MarkerEdgeColor',[0.7 0 0],...
                            'MarkerFaceColor',[1 1 0],'HitTest','off','PickableParts','none'); end
                end
            case 'Point'
                if ~isempty(selectedTargetPoint)
                    plot(bcLoadAx,selectedTargetPoint(1),selectedTargetPoint(2),'o',...
                        'MarkerSize',16,'LineWidth',2,'MarkerEdgeColor',[0.9 0.5 0],...
                        'MarkerFaceColor',[1 0.95 0.2],'HitTest','off','PickableParts','none');
                    plot(bcLoadAx,selectedTargetPoint(1),selectedTargetPoint(2),'o',...
                        'MarkerSize',7,'LineWidth',1.5,'MarkerEdgeColor',[0.6 0 0],...
                        'MarkerFaceColor',[1 0.3 0.3],'HitTest','off','PickableParts','none'); end
        end
    end

    function drawAppliedBCs()
        if isempty(nodesG), return; end
        modelSize=max([(max(nodesG(:,1))-min(nodesG(:,1))),(max(nodesG(:,2))-min(nodesG(:,2))),eps]);
        mrkSz=16; arrowLen=0.07*modelSize; textOff=0.03*modelSize;
        for k=1:numel(model.constraints)
            bc=model.constraints(k); if isempty(bc.point), continue; end
            px=bc.point(1); py=bc.point(2);
            xFixed=~isnan(bc.x_mag); yFixed=~isnan(bc.y_mag);
            if xFixed&&yFixed
                if bc.x_mag==0&&bc.y_mag==0, lbl='FXY'; else, lbl=sprintf('D%.3g\n%.3g',bc.x_mag,bc.y_mag); end
            elseif xFixed
                if bc.x_mag==0, lbl='FX'; else, lbl=sprintf('DX\n%.3g',bc.x_mag); end
            else
                if bc.y_mag==0, lbl='FY'; else, lbl=sprintf('DY\n%.3g',bc.y_mag); end
            end
            plot(bcLoadAx,px,py,'s','MarkerSize',mrkSz,'MarkerFaceColor',[0.2 0.5 0.95],...
                'MarkerEdgeColor',[0.05 0.2 0.7],'LineWidth',1.5,'HitTest','off','PickableParts','none');
            text(bcLoadAx,px,py,lbl,'FontSize',6.5,'FontWeight','bold','Color','white',...
                'HorizontalAlignment','center','VerticalAlignment','middle','HitTest','off');
        end
        for k=1:numel(model.loads)
            ld=model.loads(k); if isempty(ld.point), continue; end
            px=ld.point(1); py=ld.point(2);
            dx=sign(ld.x_mag+eps)*arrowLen*(ld.x_mag~=0); dy=sign(ld.y_mag+eps)*arrowLen*(ld.y_mag~=0);
            if dx~=0||dy~=0
                quiver(bcLoadAx,px-dx,py-dy,dx,dy,0,'Color',[0.85 0.1 0.1],'LineWidth',2.5,...
                    'MaxHeadSize',0.6,'HitTest','off','PickableParts','none');
                text(bcLoadAx,px+sign(dx+dy)*textOff,py+sign(dy)*textOff,...
                    sprintf('%s\nx=%.3g\ny=%.3g',ld.type,ld.x_mag,ld.y_mag),...
                    'FontSize',7,'Color',[0.7 0 0],'HorizontalAlignment','center','HitTest','off');
            else
                plot(bcLoadAx,px,py,'o','MarkerSize',mrkSz,'MarkerFaceColor',[0.95 0.3 0.3],...
                    'MarkerEdgeColor',[0.6 0 0],'LineWidth',1.5,'HitTest','off','PickableParts','none');
                text(bcLoadAx,px,py-textOff,sprintf('%s',ld.type),...
                    'FontSize',7,'Color',[0.7 0 0],'HorizontalAlignment','center','HitTest','off');
            end
        end
    end

    function drawBCLoadAx()
        cla(bcLoadAx); hold(bcLoadAx,'on');
        if isempty(nodesG)
            text(bcLoadAx,0.5,0.5,'Load geometry to begin','Units','normalized',...
                'HorizontalAlignment','center','FontSize',14,'Color',[0.4 0.4 0.4]);
            xlabel(bcLoadAx,sprintf('$x$ [%s]',getDisplayUnit()),'interpreter','latex');
            ylabel(bcLoadAx,sprintf('$y$ [%s]',getDisplayUnit()),'interpreter','latex');
            grid(bcLoadAx,'on'); axis(bcLoadAx,'normal'); set(bcLoadAx,'TickLabelInterpreter','latex');
            quietAxesToolbar(bcLoadAx);
            hold(bcLoadAx,'off'); return;
        end
        childrenBefore=allchild(bcLoadAx);
        copyGeometryToAxes(bcLoadAx,'');
        childrenAfter=allchild(bcLoadAx);
        newGeomChildren=setdiff(childrenAfter,childrenBefore);
        if ~isempty(newGeomChildren), set(newGeomChildren,'HitTest','off','PickableParts','none'); end
        if ~isempty(model.mesh)
            p=[model.mesh.xcoords model.mesh.ycoords];
            for i=1:size(model.mesh.connectivity,1)
                conn=model.mesh.connectivity(i,:); triIdx=[conn conn(1)];
                plot(bcLoadAx,p(triIdx,1),p(triIdx,2),'-','Color',couleur,'LineWidth',0.55,'HitTest','off','PickableParts','none');
            end
        end
        if strcmp(currentTargetType,'Vertex')
            scatter(bcLoadAx,nodesG(:,1),nodesG(:,2),55,'o','MarkerEdgeColor',[0.9 0.1 0.1],...
                'MarkerFaceColor',[1 0.85 0.85],'LineWidth',1.4,'HitTest','off','PickableParts','none');
        elseif strcmp(currentTargetType,'Edge')
            drawSelectableEdges();
        elseif strcmp(currentTargetType,'Point')&&~isempty(model.mesh)
            scatter(bcLoadAx,model.mesh.xcoords,model.mesh.ycoords,18,'o','MarkerEdgeColor',[0.9 0.1 0.1],...
                'MarkerFaceColor',[1 0.85 0.85],'LineWidth',0.8,'HitTest','off','PickableParts','none');
        end
        drawHoverTarget(); drawSelectedTarget(); drawAppliedBCs();
        xlabel(bcLoadAx,sprintf('$x$ [%s]',getDisplayUnit()),'interpreter','latex');
        ylabel(bcLoadAx,sprintf('$y$ [%s]',getDisplayUnit()),'interpreter','latex');
        applyBCAxesView();
        hold(bcLoadAx,'off');
    end

    function lims=computeBCAxesLims()
        % The BC/loading view is an interaction view, not a metrology view.
        % For long, thin parts, a strict 1:1 aspect ratio compresses the model
        % into a small strip and makes labels/markers look broken. Keep the data
        % limits tight and let the axes fill the available UI space.
        lims=[];
        if ~isempty(model.mesh)
            pts=[model.mesh.xcoords(:), model.mesh.ycoords(:)];
        elseif ~isempty(nodesG)
            pts=nodesG(:,1:2);
        else
            return;
        end
        pts=pts(all(isfinite(pts),2),:);
        if isempty(pts), return; end

        xmin=min(pts(:,1)); xmax=max(pts(:,1));
        ymin=min(pts(:,2)); ymax=max(pts(:,2));
        xr=xmax-xmin; yr=ymax-ymin;
        if xr<=eps, xr=max(1,abs(xmin)*0.1); xmin=xmin-0.5*xr; xmax=xmax+0.5*xr; end
        if yr<=eps, yr=max(1,abs(ymin)*0.1); ymin=ymin-0.5*yr; ymax=ymax+0.5*yr; end

        xPad=max(0.04*xr,0.01*max(xr,yr));
        % Give extra vertical room for BC/load symbols, but do not let a 10:1
        % beam force a huge empty axis region.
        yPad=max(0.15*yr,0.025*xr);
        lims=[xmin-xPad, xmax+xPad, ymin-yPad, ymax+yPad];
    end

    function applyBCAxesView()
        grid(bcLoadAx,'on'); box(bcLoadAx,'on');
        set(bcLoadAx,'TickLabelInterpreter','latex');
        bcLoadAx.DataAspectRatioMode='auto';
        bcLoadAx.PlotBoxAspectRatioMode='auto';
        axis(bcLoadAx,'normal');
        if isempty(bcLoadAxLims)
            bcLoadAxLims=computeBCAxesLims();
        end
        if ~isempty(bcLoadAxLims) && numel(bcLoadAxLims)==4 && all(isfinite(bcLoadAxLims))
            xlim(bcLoadAx,bcLoadAxLims(1:2));
            ylim(bcLoadAx,bcLoadAxLims(3:4));
        end
        quietAxesToolbar(bcLoadAx);
    end

    function quietAxesToolbar(targetAx)
        % Hide MATLAB's floating axes toolbar in app-style views. It was
        % overlapping the assignment controls and making the axes look broken.
        try
            targetAx.Toolbar.Visible='off';
        catch
        end
    end

    function forceAxesClicksToAxes(targetAx)
        kids=allchild(targetAx);
        for kk=1:numel(kids)
            if isprop(kids(kk),'HitTest'), kids(kk).HitTest='off'; end
            if isprop(kids(kk),'PickableParts'), kids(kk).PickableParts='none'; end
        end
        targetAx.ButtonDownFcn=@meshAxesClickCallback;
        targetAx.PickableParts='all';
        targetAx.HitTest='on';
    end

    function copyGeometryToAxes(targetAx,plotTitle)
        try
            set(0,'DefaultFigureVisible','off');
            tempFig=plotGeomCircle(nodesG,edgesG,edgeTypeG,midpointsG,loopsG,loopTypeG,'meters');
            if ~isempty(tempFig)&&isvalid(tempFig)
                origAx=findobj(tempFig,'Type','axes');
                if ~isempty(origAx)
                    copyobj(allchild(origAx(1)),targetAx);
                    kids=allchild(targetAx);
                    for ki=1:numel(kids)
                        if isprop(kids(ki),'FaceColor')
                            fc=kids(ki).FaceColor;
                            if isnumeric(fc)&&~isequal(fc,[1 1 1])&&~isequal(fc,'none')
                                kids(ki).FaceColor=[0.97 0.97 0.97]; end
                        end
                    end
                end
            end
        catch
        end
        close all; set(0,'DefaultFigureVisible','on');
        title(targetAx,plotTitle,'interpreter','latex');
        xlabel(targetAx,sprintf('$x$ [%s]',getDisplayUnit()),'interpreter','latex');
        ylabel(targetAx,sprintf('$y$ [%s]',getDisplayUnit()),'interpreter','latex');
        grid(targetAx,'on'); axis(targetAx,'equal'); set(targetAx,'TickLabelInterpreter','latex');
    end

    function printModelToCommandWindow()
        fprintf('\n==================== MODEL STRUCT ====================\n');
        fprintf('\n-- model.mesh --\n');
        fprintf('  xcoords [%dx1]  ycoords [%dx1]  connectivity [%dx3]\n',...
            numel(model.mesh.xcoords),numel(model.mesh.ycoords),size(model.mesh.connectivity,1));
        fprintf('\n-- model.material --\n');
        fprintf('  name=%s  E=%.4g Pa  nu=%.4g  rho=%.4g kg/m3  thickness=%.4g m  type=%s\n',...
            model.material.name,model.material.E,model.material.nu,...
            model.material.density,model.material.thickness,model.material.analysisType);
        fprintf('\n-- model.constraints (%d) --\n',numel(model.constraints));
        for k=1:numel(model.constraints)
            c=model.constraints(k);
            fprintf('  [%d] %s  x=%s  y=%s  nodes=%s\n',k,c.type,...
                formatMag(c.x_mag),formatMag(c.y_mag),mat2str(c.affected_nodes));
        end
        fprintf('\n-- model.loads (%d) --\n',numel(model.loads));
        for k=1:numel(model.loads)
            ld=model.loads(k);
            fprintf('  [%d] %s  Fx=%.4g  Fy=%.4g  nodes=%s\n',k,ld.type,ld.x_mag,ld.y_mag,mat2str(ld.affected_nodes));
        end
        fprintf('\n-- model.refinementRegions (%d) --\n',numel(model.refinementRegions));
        for k=1:numel(model.refinementRegions)
            rr=model.refinementRegions(k);
            fprintf('  [%d] %s  ID=%d',k,rr.regionType,rr.regionID);
            if isfield(rr,'sourceType')&&~isempty(rr.sourceType)
                fprintf('  source=%s',rr.sourceType);
                if isfield(rr,'sourceID')&&~isempty(rr.sourceID), fprintf(' %d',rr.sourceID); end
            end
            fprintf('\n');
            fprintf('       center    = (%.6g, %.6g) m\n',rr.center(1),rr.center(2));
            if isfield(rr,'shapeType')&&strcmp(rr.shapeType,'EdgeBand')
                fprintf('       shape     = EdgeBand\n');
                fprintf('       thickness = %.6g m\n',rr.radius);
            else
                fprintf('       shape     = Circle\n');
                fprintf('       radius    = %.6g m\n',rr.radius);
            end
            fprintf('       h_target  = %.6g m\n',rr.h_target);
            if isfield(rr,'affected_nodes')&&~isempty(rr.affected_nodes)
                fprintf('       nodes     = %s\n',mat2str(rr.affected_nodes));
            end
            if isfield(rr,'shapeType')&&strcmp(rr.shapeType,'EdgeBand')
                if isfield(rr,'edgePolyline')&&~isempty(rr.edgePolyline)
                    fprintf('       edgePolyline = [%dx2] points along selected edge\n',size(rr.edgePolyline,1));
                end
            elseif ~isempty(rr.vertices)
                fprintf('       vertices (CCW: E->N->W->S):\n');
                labels={'E (0 deg)','N (90 deg)','W (180 deg)','S (270 deg)'};
                for vi=1:4
                    fprintf('         v%d [%s]: (%.6g, %.6g) m\n',vi,labels{vi},rr.vertices(vi,1),rr.vertices(vi,2));
                end
            end
        end
        fprintf('\n-- model.results --\n');
        if isfield(model.results,'Deformation')&&~isempty(model.results.Deformation)
            fprintf('  Deformation [%dx1]  max=%.4g  min=%.4g\n',...
                numel(model.results.Deformation),max(model.results.Deformation),min(model.results.Deformation));
        else, fprintf('  (not solved yet)\n'); end
        fprintf('\n======================================================\n\n');
    end

    function s=formatMag(v)
        if isnan(v), s='NaN (free)'; else, s=sprintf('%.4g (fixed)',v); end
    end

    function plotMeshQualityHistogram(t,p,h0val)
        try
            [quality_elemental,quality_average]=meshQuality(t,p,h0val);
            nElem_=size(t,1); nNodes_=size(p,1); avgQual=mean(quality_elemental);
            elemType=elementTypeDropDown.Value;
            binEdges=linspace(0,1,21); counts=histcounts(quality_elemental,binEdges);
            nonZeroCounts=counts(counts>0);
            if numel(nonZeroCounts)>=2
                peakCount=max(nonZeroCounts); medCount=median(nonZeroCounts);
                useLog=(medCount>0)&&(peakCount/medCount>=1000);
            else, useLog=false; end
            cla(histAx);
            histogram(histAx,quality_elemental,'BinEdges',binEdges,...
                'FaceColor',uiColor(couleur),'EdgeColor','white','LineWidth',0.5);
            xlabel(histAx,'Element Quality','interpreter','latex');
            ylabel(histAx,'\# Elements','interpreter','latex');
            grid(histAx,'on'); set(histAx,'TickLabelInterpreter','latex'); xlim(histAx,[-0.02 1.02]);
            if useLog
                histAx.YScale='log'; ylim(histAx,[0.9 max(counts)*2]);
                title(histAx,sprintf('Quality (avg CV=%.3f) [log]',quality_average));
            else
                histAx.YScale='linear'; ylim(histAx,[0 max(counts)+10]);
                title(histAx,sprintf('Quality Distribution (avg CV=%.3f)',quality_average));
            end
            meshStatsBox.Value={'--- Mesh Stats ---',...
                sprintf('Elements:  %d',nElem_),sprintf('Nodes:     %d',nNodes_),...
                sprintf('Avg qual:  %.3f',avgQual),sprintf('CV:        %.3f',quality_average),...
                sprintf('Type:      %s',elemType)};
            logMessage(sprintf('Mesh: %d elems, %d nodes, avg quality=%.3f, CV=%.3f',...
                nElem_,nNodes_,avgQual,quality_average));
        catch err
            logMessage(['Mesh quality skipped: ' err.message]);
        end
    end

    function updateBCSummary()
        total=numel(model.constraints)+numel(model.loads);
        if total==0, bcSummaryTable.Value={'No BCs applied yet.'}; return; end
        lines={}; idx=0; u=getDisplayUnit(); s=getDisplayScale();
        for k=1:numel(model.constraints)
            idx=idx+1; c=model.constraints(k);
            xFixed=~isnan(c.x_mag); yFixed=~isnan(c.y_mag);
            xZero=xFixed&&c.x_mag==0; yZero=yFixed&&c.y_mag==0;
            if xFixed&&yFixed
                if xZero&&yZero, dof='Fixed XY';
                elseif xZero, dof=sprintf('Fixed X, Deflect Y=%.4g %s',c.y_mag*s,u);
                elseif yZero, dof=sprintf('Deflect X=%.4g %s, Fixed Y',c.x_mag*s,u);
                else, dof=sprintf('Deflect X=%.4g Y=%.4g %s',c.x_mag*s,c.y_mag*s,u); end
            elseif xFixed
                if xZero, dof='Fixed X'; else, dof=sprintf('Deflect X=%.4g %s',c.x_mag*s,u); end
            else
                if yZero, dof='Fixed Y'; else, dof=sprintf('Deflect Y=%.4g %s',c.y_mag*s,u); end
            end
            lines{end+1}=sprintf('[%d] CONSTRAINT  %s  |  %s  |  nodes: %s',...
                idx,dof,c.regionType,mat2str(c.affected_nodes));
        end
        for k=1:numel(model.loads)
            idx=idx+1; ld=model.loads(k);
            lines{end+1}=sprintf('[%d] LOAD  %s  |  Fx=%.4g N  Fy=%.4g N  |  %s  |  nodes: %s',...
                idx,ld.type,ld.x_mag,ld.y_mag,ld.regionType,mat2str(ld.affected_nodes));
        end
        bcSummaryTable.Value=lines;
    end

    function clearAllBCsCallback(~,~)
        model.constraints=struct('type',{},'x_mag',{},'y_mag',{},'affected_nodes',{},'point',{},'regionType',{},'regionID',{});
        model.loads=struct('type',{},'x_mag',{},'y_mag',{},'affected_nodes',{},'point',{},'regionType',{},'regionID',{});
        logMessage('All BCs and loads cleared.'); drawBCLoadAx(); updateBCSummary();
    end

    function editByIndexCallback(~,~)
        raw=str2double(bcDeleteIndexField.Value);
        if isnan(raw)||raw<1||raw~=floor(raw), uialert(fig,'Type a valid entry number.','Invalid'); return; end
        n=round(raw); nC=numel(model.constraints); nL=numel(model.loads);
        if n>nC+nL, uialert(fig,sprintf('Only %d entries exist.',nC+nL),'Out of Range'); return; end
        if n<=nC, bc=model.constraints(n); isConstraint=true;
        else, bc=model.loads(n-nC); isConstraint=false; end
        selectedTargetType=bc.regionType; selectedTargetID=bc.regionID;
        selectedTargetPoint=bc.point;
        selectedTargetField.Value=sprintf('%s (editing #%d)',bc.regionType,n);
        if isConstraint
            setMode('Constraint');
            xFixed=~isnan(bc.x_mag); yFixed=~isnan(bc.y_mag);
            xZero=xFixed&&bc.x_mag==0; yZero=yFixed&&bc.y_mag==0;
            if xFixed&&yFixed
                if xZero&&yZero, bcTypeDropDown.Value='Fixed XY';
                else, bcTypeDropDown.Value='Deflect XY'; bcValueField.Value=num2str(bc.x_mag); end
            elseif xFixed
                if xZero, bcTypeDropDown.Value='Fixed X';
                else, bcTypeDropDown.Value='Deflect X'; bcValueField.Value=num2str(bc.x_mag); end
            else
                if yZero, bcTypeDropDown.Value='Fixed Y';
                else, bcTypeDropDown.Value='Deflect Y'; bcValueField.Value=num2str(bc.y_mag); end
            end
            bcTypeChangedCallback();
        else
            setMode('Load');
            if bc.x_mag~=0&&bc.y_mag==0, bcTypeDropDown.Value='Force X (N)'; bcValueField.Value=num2str(bc.x_mag);
            elseif bc.y_mag~=0&&bc.x_mag==0, bcTypeDropDown.Value='Force Y (N)'; bcValueField.Value=num2str(bc.y_mag);
            else, bcTypeDropDown.Value='Moment (Nm)'; bcValueField.Value='0'; end
        end
        if isConstraint, model.constraints(n)=[]; else, model.loads(n-nC)=[]; end
        logMessage(sprintf('Editing entry %d — make changes and hit Apply.',n));
        drawBCLoadAx(); updateBCSummary();
    end

    function deleteByIndexCallback(~,~)
        raw=str2double(bcDeleteIndexField.Value);
        if isnan(raw)||raw<1||raw~=floor(raw), uialert(fig,'Enter a valid entry number.','Invalid'); return; end
        n=round(raw); nC=numel(model.constraints); nL=numel(model.loads);
        if n>nC+nL, uialert(fig,sprintf('Only %d entries exist.',nC+nL),'Out of Range'); return; end
        if n<=nC, logMessage(sprintf('Deleted constraint #%d.',n)); model.constraints(n)=[];
        else, li=n-nC; logMessage(sprintf('Deleted load #%d (entry %d).',li,n)); model.loads(li)=[]; end
        bcDeleteIndexField.Value=''; drawBCLoadAx(); updateBCSummary();
    end


    function y=sigfig(x,n)
        % Round to n significant figures
        if x==0, y=0; return; end
        d=ceil(log10(abs(x)));
        y=round(x*10^(n-d))*10^(d-n);
    end

end