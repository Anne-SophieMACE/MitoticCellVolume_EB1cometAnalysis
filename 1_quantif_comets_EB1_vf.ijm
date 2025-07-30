/****** macro quantif_cometes_EB1_vf.ijm
 *  
 *  This function enables to count and measure EB1 comets in fixed image
 *  The comets are detected as Local Maxima; their distance to pole is 
 *  defined using "Distance Transform 3D" Plugin on the ROI of the pole
 *  manually drawn by the user. The comet length is then estimated using a 
 *  Gaussian fit on a line passing through the comet (detected as a Local 
 *  Maximum) and the pole (more specifically one point of the contour of 
 *  the pole, the closest one to the comet), long enough to contain the full 
 *  comet. The length is defined as the FWHM, estimated thanks to the 
 *  standard deviation
 *  
 *  10/23 by A-S MACE, tested on Windows
 */
 
 
roiManager("reset");
run("Close All");
run("Set Measurements...", "area mean centroid bounding redirect=None decimal=5");
run("Clear Results");

// asks the user to choose the image to treat
img_name = File.openDialog("Choose your image to treat");
run("Bio-Formats", "open=["+img_name+"] color_mode=Composite open_files open_all_series rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
tit_img = getTitle();
getDimensions(width, height, channels, slices, frames);
getVoxelSize(pixelWidth, pixelHeight, pixel_depth, unit);
run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel"); // scale in pixels
dir_img = getDirectory("image");
name_noExt = substring(tit_img,0,lastIndexOf(tit_img,".")); // for saving

// asks the user to choose the slices to analyze and the minimal ROI size
setTool("line");
Dialog.createNonBlocking("Choose parameters for analysis");
Dialog.addNumber("Channel GFP (comets)",2);
Dialog.addNumber("Beginning slice for projection", 1);
Dialog.addNumber("End slice for projection", 36);
Dialog.addNumber("Find Maxima prominence parameter (on GFP)",200);
Dialog.addNumber("Maximum size of one comet (pixels)",10);
Dialog.show();
GFP_chan = Dialog.getNumber();
slice_beg = Dialog.getNumber();
slice_end = Dialog.getNumber();
prom_param = Dialog.getNumber();
max_FWHM = Dialog.getNumber();

if( slice_end != slice_beg ){ // several plans: we do a max z-projection
	run("Z Project...", "start="+slice_beg+" stop="+slice_end+" projection=[Max Intensity]");
	img_analysis = getTitle();
	for (i_ch = 1; i_ch <= channels; i_ch++) {
		Stack.setChannel(i_ch);
		resetMinAndMax();
	}
}
else{ // we duplicate the slice of interest
	run("Duplicate...", "duplicate slices="+slice_beg);
	for (i_ch = 1; i_ch <= channels; i_ch++) {
		Stack.setChannel(i_ch);
		resetMinAndMax();
	}
	img_analysis = getTitle();
}

analysePole(img_analysis,GFP_chan,1,prom_param,dir_img+name_noExt);

selectWindow(img_analysis);
close();

bool = getBoolean("Do you want to study the other pole?");

if( bool ){ // the two poles can be on different slices
	roiManager("reset");
	run("Clear Results");
	
	// asks the user to choose the slices to analyze and the minimal ROI size
	Dialog.createNonBlocking("Choose parameters for analysis");
	Dialog.addNumber("Channel GFP (comets)",2);
	Dialog.addNumber("Beginning slice for projection", 1);
	Dialog.addNumber("End slice for projection", slices);
	Dialog.addNumber("Find Maxima prominence param (on GFP)",200);
	Dialog.addNumber("Maximum size coments (pixels)",10);
	Dialog.show();
	GFP_chan = Dialog.getNumber();
	//mCherry_chan = Dialog.getNumber();
	slice_beg = Dialog.getNumber();
	slice_end = Dialog.getNumber();
	prom_param = Dialog.getNumber();
	max_FWHM = Dialog.getNumber();
	
	if( slice_end != slice_beg ){ // several plans: we do a max z-projection
		run("Z Project...", "start="+slice_beg+" stop="+slice_end+" projection=[Max Intensity]");
		img_analysis = getTitle();
		for (i_ch = 1; i_ch <= channels; i_ch++) {
			Stack.setChannel(i_ch);
			resetMinAndMax();
		}
	}
	else{ // we duplicate the slice of interest
		run("Duplicate...", "duplicate slices="+slice_beg);
		for (i_ch = 1; i_ch <= channels; i_ch++) {
			Stack.setChannel(i_ch);
			resetMinAndMax();
		}
		img_analysis = getTitle();
	}
	analysePole(img_analysis,GFP_chan,2,prom_param,dir_img+name_noExt);
}
 
function analysePole(img_analysis,GFP_chan,num_pole,prom_param,path_save){
 	// asks the user to draw the ROIs of interest; should be a polygon (interpolation tested only on those!)
 	setTool("polygon");
 	while (roiManager("count") != 1 || selectionType() != 2 )
	 	waitForUser("Draw the pole (will be excluded from the analysis and used for distance computation), ADD IT to the Manager\n (Use the Polygon tool)");
	
	roiManager("select", roiManager("count")-1);
	roiManager("rename", "ROI_pole"+num_pole);
	
	setTool("polygon");
	while (roiManager("count") != 2 )
	 	waitForUser("Draw the analysis ROI (pole will be removed), ADD IT to the Manager");
	
	// creates the ROI of analysis by remove the pole from the last drawn ROI
	roiManager("Select", newArray(0,1));
	roiManager("XOR");
	roiManager("add");
	roiManager("deselect");
	roiManager("select", roiManager("count")-2);
	roiManager("delete");
	roiManager("select", roiManager("count")-1);
	roiManager("rename", "ROI_analysis_pole"+num_pole);
	
	// applies the Find Maxima for the GFP channel
	selectWindow(img_analysis);
	getDimensions(width, height, channels, slices, frames);
	run("Select All");
	run("Duplicate...", "title=comets_channel duplicate channels="+GFP_chan);
	roiManager("select", roiManager("count")-1);
	run("Find Maxima...", "prominence="+prom_param+" output=[Point Selection]");
	roiManager("add");
	roiManager("select", roiManager("count")-1);
	roiManager("rename", "Comets_pole_"+num_pole);
	roiManager("select", roiManager("count")-1);
	setTool("multipoint");
	waitForUser("Remove some points if corrresponds to wrong comets and add some if missing comets.\n Do not forget to Update the Manager, otherwise changes will be ignored.\n(Remove by clicking on a point, with Ctrl key pressed on PC, Cmd key pressed on Mac)");
	
	// compute the distance for each point from the pole
	getDimensions(width, height, channels, slices, frames);
	newImage("Pole_Distance", "8-bit black", width, height, 1);
	roiManager("select", 0); // the pole ROI
	run("Add...", "value=255"); // put the pole at white
	run("Select All");
	run("Distance Transform 3D");
	
	selectWindow("Distance");
	run("Clear Results");
	roiManager("select", roiManager("count")-1);
	roiManager("measure");
	
	nbComets = nResults();
	// read distance to pole
	distancePole_perComets = newArray(nbComets);
	tabX_pts = newArray(nbComets);
	tabY_pts = newArray(nbComets);
	
	for (i_pt = 0; i_pt < nbComets; i_pt++) {
		distancePole_perComets[i_pt] = getResult("Mean",i_pt); // mean in the distance image is the distance
		tabX_pts[i_pt] = getResult("X",i_pt);
		tabY_pts[i_pt] = getResult("Y",i_pt);
	}
	
	// intermediate results containing distance to pole for all comets
	run("Clear Results");
	for (i_pt = 0; i_pt < nbComets; i_pt++) {
		setResult("CometNumber",i_pt,i_pt+1);
		setResult("DistancePole ("+unit+")",i_pt,distancePole_perComets[i_pt]*pixelWidth);
	}
	saveAs("Results",dir_img+name_noExt+"_distancePole_p"+num_pole+"_AllComets_slices_"+slice_beg+"_"+slice_end+".xls");
	
	
	coordXmiddle_perComet = findClosestPtInPole_andDrawLineForGaussianFit(nbComets,tabX_pts,tabY_pts);
	
	// closes intermediate images
	selectWindow("Distance");
	close();
	selectWindow("Pole_Distance");
	close();
	
	nbROIs_beforeLines = 3;
	findCometsSizeByGaussianFit(nbComets,nbROIs_beforeLines,coordXmiddle_perComet,tabX_pts,tabY_pts,max_FWHM);
	
	selectWindow("comets_channel");
	roiManager("show none");
	roiManager("show all with labels");
	
	waitForUser("Check the comets size (remove abnormal values/modify lines). Do not add any ROI, they will be ignored.");
	
	selectWindow("comets_channel");
	close();
	
	run("Clear Results");
	lengthComets = newArray(nbComets);
	for (i_ROI = nbROIs_beforeLines; i_ROI < roiManager("count"); i_ROI++) {
		roiManager("select", i_ROI);
		roiName = Roi.getName;
		comet_number = parseInt(substring(roiName,lastIndexOf(roiName, "_")+1,lengthOf(roiName)));
		roiManager("select", i_ROI);
		roiManager("measure");
		lengthComets[comet_number] = getResult("Length", nResults-1);
	}
	// final result table
	run("Clear Results");
	for (i_pt = 0; i_pt < nbComets; i_pt++) {
		line_res = nResults;
		if( lengthComets[i_pt] > 0 ){
			setResult("DistanceToPole ("+unit+")", line_res, distancePole_perComets[i_pt]*pixelWidth);
			setResult("SizeComet ("+unit+")", line_res, lengthComets[i_pt]*pixelWidth);
		}
	}
	
	// saves final result
	saveAs("Results",dir_img+name_noExt+"_distancePole_p"+num_pole+"_size_comets_slices_"+slice_beg+"_"+slice_end+".xls");
	
 	// saves the ROI
 	roiManager("deselect");
 	roiManager("save", path_save+"_ROIs_cometsAnalysis_pole"+num_pole+"_slices_"+slice_beg+"_"+slice_end+".zip");
}


function findClosestPtInPole_andDrawLineForGaussianFit(nbPts,tabX_pts,tabY_pts){
	newImage("Pts_Distance", "8-bit black", width, height, 1);
	
	setBatchMode("hide");
	// for each comet, a distance map is created from its position
	for (i_pt = 0; i_pt < nbPts; i_pt++) {
		selectWindow("Pts_Distance");
		run("Select All");
		run("Multiply...", "value=0"); // put the pole at white
		makeRectangle(tabX_pts[i_pt], tabY_pts[i_pt], 1, 1);
		run("Add...", "value=255");
		run("Distance Transform 3D");
		rename("Distance_pt_"+i_pt+1);
	}
	// all distance images are merged
	run("Images to Stack", "name=Stack_dist_pts title=Distance_pt_ use");
	setBatchMode("exit and display");
	
	// 
	roiManager("select", 0);
	Roi.getCoordinates(xpoints, ypoints);
	makeSelection("points", xpoints, ypoints);
	nbCoordInROI = resampleROIContour(xpoints, ypoints);
	
	// ROI with pole contour points
	roiManager("select", roiManager("count")-1);
	
	// Measures the distance to the comet for each point
	// of the contour
	run("Clear Results");
	selectWindow("Stack_dist_pts");
	roiManager("select", roiManager("count")-1);
	run("Measure Stack...");
	
	roiManager("select", roiManager("count")-1);
	roiManager("delete");
	
	index_res = 0;
	tabX_min = newArray(nbPts);
	tabY_min = newArray(nbPts);
	coordXmiddle_perPt = newArray(nbPts); 
	
	for (i_pt = 0; i_pt < nbPts; i_pt++) {
		tab_int = newArray(nbCoordInROI);
		for (i_coord = 0; i_coord < nbCoordInROI; i_coord++) {
			tab_int[i_coord] = getResult("Mean", index_res);
			index_res++;
		}
		ranked_index = Array.rankPositions(tab_int);
		tabX_min[i_pt] = getResult("X",i_pt*nbCoordInROI+ranked_index[0]);
		tabY_min[i_pt] = getResult("Y",i_pt*nbCoordInROI+ranked_index[0]);
	}

	for (i_pt = 0; i_pt < nbPts; i_pt++) {
		a = (tabY_min[i_pt]-tabY_pts[i_pt])/(tabX_min[i_pt]-tabX_pts[i_pt]);
		b = tabY_min[i_pt]-a*tabX_min[i_pt];
		
		sign = 1;
		if( tabX_min[i_pt]-tabX_pts[i_pt] > 0 )
			sign = -1;
		
		xf = tabX_pts[i_pt] + sign*abs(tabX_min[i_pt]-tabX_pts[i_pt]);
		yf = a*xf+b;
		
		coordXmiddle_perPt[i_pt] = distance(tabX_min[i_pt],tabY_min[i_pt],tabX_pts[i_pt],tabY_pts[i_pt]);
		
		makeLine(tabX_min[i_pt],tabY_min[i_pt],xf,yf);
		roiManager("add");
	}
	
	selectWindow("Stack_dist_pts");
	close();
	selectWindow("Pts_Distance");
	close();
	
	return coordXmiddle_perPt;
}

// this function finds the comet size by Gaussian fit
function findCometsSizeByGaussianFit(nbPts,roiBeginLine,coordXmiddle_perComet,tabX_pts,tabY_pts,max_FWHM){
	// pre-processing of the comets canal to help detection
	selectWindow("comets_channel");
	run("Select All");
	run("Duplicate...", "title=comets_channel_forGaussianDetection");
	run("Subtract Background...", "rolling=10");
	run("Gaussian Blur...", "sigma=1");
	
	// tabIndex_ROIline will contain all the ROIs of lines
	lastROILine = roiManager("count");
	tabIndex_ROIline = newArray(lastROILine-roiBeginLine);
	for (i_line = roiBeginLine; i_line < lastROILine; i_line++)
		tabIndex_ROIline[i_line-roiBeginLine] = i_line;
	
	// measures all the line ROIs
	run("Clear Results");
	roiManager("deselect");
	roiManager("select", tabIndex_ROIline);
	roiManager("Measure");
	roiManager("deselect");
		
	tabSizeOK = newArray(lastROILine-roiBeginLine);
	for (i_line = roiBeginLine; i_line < lastROILine; i_line++) {
		selectWindow("comets_channel_forGaussianDetection");
		roiManager("select", i_line);
		y = getProfile();
		x = Array.getSequence(y.length);
		Array.getStatistics(y, ymin, ymax, ymean, ystdDev);
		guesses = newArray(ymin, ymax, 1);
		Xcoord = coordXmiddle_perComet[i_line-roiBeginLine];
		// fit on a gaussian centered on the center of the comets (computed by FindMaxima)
		gaussian_centered = "y = a + b * exp( -((x-"+Xcoord+")*(x-"+Xcoord+"))/(2*c) )";
		Fit.doFit(gaussian_centered, x,y, guesses);
		
		// 
		par_sigma = Fit.p(2);
		FWHM = 2*sqrt(2*log(2))*sqrt(par_sigma);
		selectWindow("comets_channel_forGaussianDetection");
		roiManager("deselect");
		if( FWHM < max_FWHM && !isNaN(FWHM) ){ // the size is correct
			makeLine(tabX_pts[i_line-roiBeginLine]-FWHM/2,tabY_pts[i_line-roiBeginLine],tabX_pts[i_line-roiBeginLine]+FWHM/2,tabY_pts[i_line-roiBeginLine]);
			// rotate to have the correct orientation
			run("Rotate...", "  angle="+(-getResult("Angle",i_line-roiBeginLine)));
			roiManager("add");
			tabSizeOK[i_line-roiBeginLine] = 1; // comet is treated
			roiManager("select", roiManager("count")-1);
			roiManager("rename", "Axe_comet_"+i_line-roiBeginLine+1);
		}
	}
	
	// deletes the line ROIs
	roiManager("select", tabIndex_ROIline);
	roiManager("delete");
	
	selectWindow("comets_channel_forGaussianDetection");
	close();
	
	return tabSizeOK;
}

// function distance between (X1,Y1) --> (X2,Y2)
function distance(X1,Y1,X2,Y2){
	return sqrt( (X1-X2)*(X1-X2) + (Y1-Y2)*(Y1-Y2) );
}

// this function resample the ROI with a number of equidistant points
// this is based on the perimeter
function resampleROIContour(x,y) {
	x = newArray(lengthOf(xpoints)+1);
	y = newArray(lengthOf(xpoints)+1);
	
	for (i_x=0; i_x<lengthOf(xpoints); i_x++){
		x[i_x] = xpoints[i_x];
		y[i_x] = ypoints[i_x];
	}
	x[lengthOf(xpoints)] = x[0];
	y[lengthOf(xpoints)] = y[0];
	perim_tot=0;
	for (i_x=0; i_x<lengthOf(x)-1; i_x++)
	   perim_tot = perim_tot + distance(x[i_x+1],y[i_x+1],x[i_x],y[i_x]);
	
	nbPts = round(perim_tot*2);
	dist_2flwpts = perim_tot/nbPts;
	
	index_bigTab= 1;
	// table that will contain the interpolate positions
	xcoord =  newArray();
	ycoord =  newArray();
	xcoord[0] = x[0];
	ycoord[0] = y[0];
	index_smallTab = 1;
	while(index_bigTab!=lengthOf(x)){
		d = distance(xcoord[index_smallTab-1],ycoord[index_smallTab-1],x[index_bigTab],y[index_bigTab]);
		if( d > dist_2flwpts ){
			if( abs(x[index_bigTab] - xcoord[index_smallTab-1]) > 1e-5  ){ // y =ax+b
				a = ( y[index_bigTab]- ycoord[index_smallTab-1])/(x[index_bigTab]-xcoord[index_smallTab-1]);
				b = ycoord[index_smallTab-1]-a*xcoord[index_smallTab-1];
				xcoord[index_smallTab] = xcoord[index_smallTab-1]+dist_2flwpts/d*(x[index_bigTab]-xcoord[index_smallTab-1]);
				ycoord[index_smallTab] = a*xcoord[index_smallTab]+b;
			}
			else{ // x =cste
				xcoord[index_smallTab] = xcoord[index_smallTab-1];
				if( y[index_bigTab] > ycoord[index_smallTab-1] )
					ycoord[index_smallTab] = ycoord[index_smallTab-1]+dist_2flwpts;
				else 
					ycoord[index_smallTab] = ycoord[index_smallTab-1]-dist_2flwpts;
			}
			index_smallTab = index_smallTab+1;
		}
		else{
			if( index_bigTab < lengthOf(x) ){
				xinter = x[index_bigTab];
				yinter = y[index_bigTab];
				
				// go on segments until the distance dist_2flwpts is obtained
				for (i = index_bigTab+1; i < lengthOf(x); i++) {
					d_der = distance(xinter,yinter,x[i],y[i]);
					if( d+d_der > dist_2flwpts)
						break;
					else{
						d = d+d_der;
						xinter = x[i];
						yinter = y[i];
					}
				}
				
				index_bigTab = i;
				if( index_bigTab  < lengthOf(x) ){
	
					if( abs(x[index_bigTab]-xinter) > 1e-5 ){ // y =ax+b
						a = ( y[index_bigTab]- yinter)/(x[index_bigTab]-xinter);
						b = yinter-a*xinter;
						
						xcoord[index_smallTab] = xinter+(dist_2flwpts-d)/d_der*(x[index_bigTab]-xinter);
						ycoord[index_smallTab] = a*xcoord[index_smallTab]+b;
					}
					else{ // x =cste
						xcoord[index_smallTab] = xinter;
						if(y[index_bigTab] > yinter )
							ycoord[index_smallTab] = yinter-(dist_2flwpts-d)/d_der;
						else 
							ycoord[index_smallTab] = yinter+(dist_2flwpts-d)/d_der;
					}
					index_smallTab = index_smallTab+1;
				}
				else { // to go out of the loop
					index_bigTab = lengthOf(x);
				}
			}
		}
	}
	
	makeSelection("points", Array.slice(xcoord,0,lengthOf(xcoord)-1), Array.slice(ycoord,0,lengthOf(ycoord)-1));
	roiManager("add");
	
	return lengthOf(xcoord)-1;
}

