//Written by Ricardo Bessa
version = "1.0.0";
requires("1.53f");
//Requires CLIJ2
//Requires MorphoLIbJ
//Requires Extended Depth of Field

function fileHandling(input, output, filename) {
	//Initial file handling
	input = replace(input,"/","\\");
	run("Bio-Formats Importer", "open=" + "[" + input + filename + "]" + " " + "color_mode=Colorized view=Hyperstack split_channels autoscale stack_order=XYZCT windowless=true");
	logfilename = filename;
	findChannelDye();
	selectWindow(filename + " - C=0");
	if (findByLUT == true) {
		channelDye1 = assignDyeByLUT();
	}
	rename(channelDye1);
	selectWindow(filename + " - C=1");
	if (findByLUT == true) {
		channelDye2 = assignDyeByLUT();
	}
	rename(channelDye2);
	if (isOpen(filename + " - C=2") == true) {
		selectWindow(filename + " - C=2");
		if (findByLUT == true) {
		channelDye3 = assignDyeByLUT();
		}
		rename(channelDye3);
	}
	
	selectWindow("Red");
	if (brand == "Zeiss") {exposure_Red = parseInt(Property.get("Information|Image|Channel|ExposureTime #1")) / 1000000;}
	getStatistics(area, Red_mean, Red_min, Red_max, std, histogram);
	
	selectWindow("Green");
	if (brand == "Zeiss") {exposure_Green = parseInt(Property.get("Information|Image|Channel|ExposureTime #2")) / 1000000;}
	getStatistics(area, Green_mean, Green_min, Green_max, std, histogram);

	if (isOpen("Cyan") == true) {
		selectWindow("Cyan");
		if (brand == "Zeiss") {exposure_Cyan = parseInt(Property.get("Information|Image|Channel|ExposureTime #3")) / 1000000;}
		getStatistics(area, Cyan_mean, Cyan_min, Cyan_max, std, histogram);
		run("Cyan");
	}

	width = getWidth();
	height = getHeight();
	if ( width >= height) {
		maxsize = width;
	}
	else {
		maxsize = height;
	}
	getPixelSize(unit, pixelWidth, pixelHeight);
	resolution = 1/pixelWidth;

	//reset discrepancy control variables
	disable_green_tresh=false;
	disable_red_tresh=false;

	//discrepancy filter
	discrepancyFilter(Green_max,Red_max);

	autoBackgroundRemoval = Math.round(resolution / 3);
	
	imgArea = (width * pixelWidth) * (height * pixelHeight); //gives image area in square microns
	imgArea = imgArea * 0.000001; //converting square microns to square milimeters

	stackProcessing(input, output, filename);
	naturalImages(input, output, truncFilename, method);
}

function discrepancyFilter(gmax,rmax) {
	//check if red and green channels show great intensity discrepancy. This function is used to filter out extreme cases where one channel may not have positive events at all
    //and inteferes with downstream threhsolding
	discrep_threshold = 0.25; 
	if (gmax <= rmax * discrep_threshold) {
		disable_green_tresh = true;
	}
	else if (rmax <= gmax * discrep_threshold) {
		disable_red_tresh = true;
	}
}

function assignDyeByLUT() {
		getLut(reds, greens, blues);
		if (reds[reds.length-1] == 255) {
			return "Red";
		}
		else if (greens[greens.length-1] == 255) {
			return "Green";
		}
		else if (blues[blues.length-1] == 255) {
			return "Cyan";
		}
		else {
			print("Automatic dye assignment by LUT not possible. Falling back to default channel assignment:\nChannel 1 - Red\nChannel 2 - Green\n Channel 3 - Cyan.");
			findByLUT = false;
			channelDye1="Red";
			channelDye2="Green";
			channelDye3="Cyan";
		}
}

function findChannelDye() {
	function assignDye(channelToAssign) {
		if (channelToAssign > 570 && channelToAssign < 760) {
			return "Red";
		}
		else if (channelToAssign > 500 && channelToAssign < 570) {
			return "Green";
		}
		else if (channelToAssign > 400 && channelToAssign < 500) {
			return "Cyan";
		}
	}
	//for Zeiss images
	if (brand == "Zeiss" && man_dyeAssignment == "Automatic") {
		channelDye1=assignDye(parseInt(Property.get("Information|Image|Channel|EmissionWavelength #1")));
		channelDye2=assignDye(parseInt(Property.get("Information|Image|Channel|EmissionWavelength #2")));
		if (isOpen(filename + " - C=2") == true) {
			channelDye3=assignDye(parseInt(Property.get("Information|Image|Channel|EmissionWavelength #3")));
		}
		findByLUT = false;
	}
	//for Leica images
	else if (brand == "Leica" && man_dyeAssignment == "Automatic") {
		print("Automatic dye assignment by wavelength not possible. Falling back to channel detection by LUT.");
		findByLUT = true;
	}
	else if (brand == "Other" && man_dyeAssignment == "Automatic") {
		print("Automatic dye assignment by wavelength not possible. Falling back to channel detection by LUT.");
		findByLUT = true;
	}
	else if (man_dyeAssignment != "Automatic") {
		channelDye1=substring(man_dyeAssignment, 0, indexOf(man_dyeAssignment, "-"));
		channelDye2=substring(man_dyeAssignment, indexOf(man_dyeAssignment, "-") + 1, lastIndexOf(man_dyeAssignment, "-"));
		if (isOpen(filename + " - C=2") == true) {
			channelDye3=substring(man_dyeAssignment, lastIndexOf(man_dyeAssignment, "-") + 1);
		}
		findByLUT = false;
	}
}

function GetTime() {
	MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
    DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    TimeString ="Date: "+DayNames[dayOfWeek]+" ";
    if (dayOfMonth<10) {TimeString = TimeString+"0";}
    TimeString = TimeString+dayOfMonth+"-"+MonthNames[month]+"-"+year+"\nTime: ";
    if (hour<10) {TimeString = TimeString+"0";}
    TimeString = TimeString+hour+":";
    if (minute<10) {TimeString = TimeString+"0";}
    TimeString = TimeString+minute+":";
    if (second<10) {TimeString = TimeString+"0";}
    TimeString = TimeString+second;
}

function findMinMax(input, output, filename) {
	run("Bio-Formats Importer", "open=" + "[" + input + filename + "]" + " " + "color_mode=Colorized view=Hyperstack split_channels stack_order=XYZCT windowless=true");
	selectWindow(filename + " - C=1");
	resetMinAndMax;
	getStatistics(area, mean, Green_min, Green_max, std, histogram);
	greenMaxArray = Array.concat(greenMaxArray,Green_max);
	greenMinArray = Array.concat(greenMinArray,Green_min);
	selectWindow(filename + " - C=0");
	resetMinAndMax;
	getStatistics(area, mean, Red_min, Red_max, std, histogram);
	redMaxArray = Array.concat(redMaxArray,Red_max);
	redMinArray = Array.concat(redMinArray,Red_min);
	run("Close All");
}
function applyMinMax() {
	selectWindow("Red");
	setMinAndMax(Red_min_mean, Red_max_mean);
	run("Apply LUT", "stack");

	selectWindow("Green");
	setMinAndMax(Green_min_mean, Green_max_mean);
	run("Apply LUT", "stack");
}

function enhanceContrast(channel) {
	if (channel == "Green") {
		getStatistics(area, mean, Green_min, Green_max, std, histogram);
		green10 = Green_max * 0.1;
		Green_max = Green_max - green10;
		Green_min = Green_max + green10;
		setMinAndMax(Green_min, Green_max);
	}
	if (channel == "Red") {
		getStatistics(area, mean, Red_min, Red_max, std, histogram);
		red10 = Red_max * 0.1;
		Red_max = Red_max - red10;
		Red_min = Red_max + red10;
		setMinAndMax(Red_min, Red_max);
	}
	if (channel == "Cyan") {
		getStatistics(area, mean, Cyan_min, Cyan_max, std, histogram);
		cyan10 = Cyan_max * 0.1;
		Cyan_max = Cyan_max - cyan10;
		Cyan_min = Cyan_max + cyan10;
		setMinAndMax(Cyan_min, Cyan_max);
	}
}

function fluoroControlFindValues() {
	//Find intensity values from control file
	run("Bio-Formats Importer", "open=" + "[" + dyeControl + "]" + " " + "color_mode=Colorized view=Hyperstack split_channels autoscale stack_order=XYZCT windowless=true");
	dyeControl=File.name;
	filename=File.name;
	findChannelDye();
	selectWindow(dyeControl + " - C=0");
	rename(channelDye1 + "-Control");
	selectWindow(dyeControl + " - C=1");
	rename(channelDye2 + "-Control");
	if (isOpen(dyeControl + " - C=2") == true) {
		selectWindow(dyeControl + " - C=2");
		rename(channelDye3 + "-Control");
	}

	selectWindow("Red-Control");
	exposure_RedControl = parseInt(Property.get("Information|Image|Channel|ExposureTime #1")) / 1000000;
	getStatistics(area, RedControl_mean, RedControl_min, RedControl_max, std, histogram);
	
	selectWindow("Green-Control");
	exposure_GreenControl = parseInt(Property.get("Information|Image|Channel|ExposureTime #2")) / 1000000;
	getStatistics(area, GreenControl_mean, GreenControl_min, GreenControl_max, std, histogram);

	if (find_biofilm == true) {
		selectWindow("Cyan-Control");
		exposure_CyanControl = parseInt(Property.get("Information|Image|Channel|ExposureTime #3")) / 1000000;
		getStatistics(area, CyanControl_mean, CyanControl_min, CyanControl_max, std, histogram);
	}
	closingStatement("Control");
}

function removeBackground() {
	if (channel == "Cyan") {
		run("Subtract Background...", "rolling=" + Math.round(autoBackgroundRemoval * 16.6) + " stack");
	}
	else if (channel == "composite") {
		run("Subtract Background...", "rolling=" + autoBackgroundRemoval * 2 + " stack");
	}
	else {
		run("Subtract Background...", "rolling=" + autoBackgroundRemoval + " stack");
		//run("Subtract Background...", "rolling=5 stack");
	}
}

function emptyThresholding() {
	getStatistics(temp_area, temp_mean, temp_min, temp_max, temp_std, temp_histogram);
	setOption("BlackBackground", true);
	setThreshold(temp_max, temp_max);
	run("Convert to Mask", "method=Default background=Dark black");
}

function autoThresholding(method) {
	if (channel != "Cyan") {
		setOption("BlackBackground", true);
		resetThreshold;
		setAutoThreshold(method + " dark");
		run("Convert to Mask", "method=Yen background=Dark black");
		run("Erode");
		run("Dilate");
		run("Watershed");
	}
	else {
		setOption("BlackBackground", true);
		resetThreshold;
		setAutoThreshold("Otsu dark");
		run("Convert to Mask", "method=Otsu background=Dark black");
	}
	getStatistics(area, mean, min, max, std, histogram);
	if (mean == 255) {
		run("Invert");
	}
}

function alignStacks() {
	selectWindow("Green");
	run("Rigid Registration", "initialtransform=[] n=1 tolerance=1.000 level=7 stoplevel=2 materialcenterandbbox=[] showtransformed template=[" + "Red" + "] measure=Correlation");
	while (isOpen("transformed") == false) {
				wait(100);
			}
	close("Green");
	selectWindow("transformed");
	rename("Green");
	run("Green");
}

function stackProcessing(input, output, filename) {
	//Stack processing
	slices = nSlices();
	if (slices >= 2 && dostacks == true) {
		if (processingType == "CPU") {
			if (align == true || forceAlign == 1) {
				alignStacks();
				forceAlign = 1;
			}
			//Green Channel
			channel = "Green";
			selectWindow("Green");
			if (dyeControl != "") {run("Subtract...", "value=" + GreenControl_mean + " stack");}
			run("Despeckle", "stack");
			run("EDF Easy mode", "quality=" + edf_quality + " topology='2' show-topology='off' show-view='off'");
			while (isOpen("Output") == false) {
				wait(100);
			}		
			close("Green");
			selectWindow("Output");
			rename("Green");
			run("16-bit");
			run("Green");
			run("Duplicate..."," ");
			rename("Green-procColor");
			if (dyeControl != "") {run("Subtract...", "value=" + GreenControl_mean + " stack");}
			selectWindow("Green");
			removeBackground();
			run("Set Scale...", "distance=" + resolution + " known=1 unit=micron");
			
			//Red Channel
			channel = "Red";
			selectWindow("Red");
			if (dyeControl != "") {run("Subtract...", "value=" + RedControl_mean + " stack");}
			run("Despeckle", "stack");
			run("EDF Easy mode", "quality=" + edf_quality + " topology='2' show-topology='off' show-view='off'");
			while (isOpen("Output") == false) {
				wait(100);
			}		
			close("Red");
			selectWindow("Output");
			rename("Red");
			run("16-bit");
			run("Red");
			run("Duplicate..."," ");
			rename("Red-procColor");
			if (dyeControl != "") {run("Subtract...", "value=" + RedControl_mean + " stack");}
			selectWindow("Red");
			removeBackground();
			run("Set Scale...", "distance=" + resolution + " known=1 unit=micron");
			
			//Cyan channel
			if (find_biofilm == true) {
				channel = "Cyan";
				selectWindow("Cyan");
				if (dyeControl != "") {run("Subtract...", "value=" + CyanControl_mean + " stack");}
				removeBackground();
				run("Despeckle", "stack");
				run("EDF Easy mode", "quality=" + edf_quality + " topology='2' show-topology='off' show-view='off'");
				while (isOpen("Output") == false) {
					wait(100);
				}		
				close("Cyan");
				selectWindow("Output");
				rename("Cyan");
				if (dyeControl != "") {run("Subtract...", "value=" + CyanControl_mean*0.2);}
				else {run("Subtract...", "value=" + Cyan_mean*0.1);}
				if (method == "Intensity") {run("Remove Outliers...", "radius=3 threshold=50 which=Bright");}
				run("16-bit");
				run("Despeckle");
				run("Cyan");
				run("Set Scale...", "distance=" + resolution + " known=1 unit=micron");
			}
		}
			
		else if(processingType == "GPU") { 
			if (align == true || forceAlign == 1) {
				alignStacks();
				forceAlign = 1;
			}
			//activate GPU mode
			run("CLIJ2 Macro Extensions", "cl_device=" + gpu);
			Ext.CLIJ2_clear();
			
			//Green Channel
				selectWindow("Green");
				channel = "Green";
				if (dyeControl != "") {run("Subtract...", "value=" + GreenControl_mean + " stack");}
				if (dyeControl == "") {run("Subtract...", "value=" + Green_mean*0.05 + " stack");}
				run("Despeckle", "stack");
				//extended depth of focus
					Ext.CLIJ2_push("Green");
					close("Green");
					if (gpu_algorithm == "Tenengrad") {Ext.CLIJ2_extendedDepthOfFocusTenengradProjection("Green", green_final, 10);}
					else if (gpu_algorithm == "Sobel") {Ext.CLIJ2_extendedDepthOfFocusSobelProjection("Green", green_final, 10);}
					else if (gpu_algorithm == "Variance") {Ext.CLIJ2_extendedDepthOfFocusVarianceProjection("Green", green_final, 2, 2, 10);}
					Ext.CLIJ2_release("Green");
					Ext.CLIJ2_pull(green_final);
				rename("Green");
				run("Subtract...", "value=5");
				selectWindow("Green");
				run("Enhance Contrast...", "saturated=0.3");
				run("Green");
				run("16-bit");
				run("Duplicate..."," ");
				rename("Green-procColor");
				if (dyeControl != "") {run("Subtract...", "value=" + GreenControl_mean + " stack");}
				selectWindow("Green");
				removeBackground();
				run("Set Scale...", "distance=" + resolution + " known=1 unit=micron");
	
			//Red Channel
				selectWindow("Red");
				channel = "Red";
				if (dyeControl != "") {run("Subtract...", "value=" + RedControl_mean + " stack");}
				if (dyeControl == "") {run("Subtract...", "value=" + Red_mean*0.05 + " stack");}
				run("Despeckle", "stack");
				//extended depth of focus
					Ext.CLIJ2_push("Red");
					close("Red");
					if (gpu_algorithm == "Tenengrad") {Ext.CLIJ2_extendedDepthOfFocusTenengradProjection("Red", red_final, 10);}
					else if (gpu_algorithm == "Sobel") {Ext.CLIJ2_extendedDepthOfFocusSobelProjection("Red", red_final, 10);}
					else if (gpu_algorithm == "Variance") {Ext.CLIJ2_extendedDepthOfFocusVarianceProjection("Red", red_final, 2, 2, 10);}
					Ext.CLIJ2_release("Red");
					Ext.CLIJ2_pull(red_final);
				rename("Red");
				run("Subtract...", "value=5");
				selectWindow("Red"); 
				run("Enhance Contrast...", "saturated=0.3");
				run("Red");
				run("16-bit");
				run("Duplicate..."," ");
				rename("Red-procColor");
				if (dyeControl != "") {run("Subtract...", "value=" + RedControl_mean + " stack");}
				selectWindow("Red");
				removeBackground();
				run("Set Scale...", "distance=" + resolution + " known=1 unit=micron");

			//cyan channel
			if (find_biofilm == true) {
				channel = "Cyan";
				selectWindow("Cyan");
				if (dyeControl != "") {run("Subtract...", "value=" + CyanControl_mean + " stack");}
				removeBackground();
				if (dyeControl == "") {run("Subtract...", "value=" + Cyan_mean*0.05 + " stack");}
				run("Despeckle", "stack");
				//extended depth of focus
					Ext.CLIJ2_push("Cyan");
					close("Cyan");
					if (gpu_algorithm == "Tenengrad") {Ext.CLIJ2_extendedDepthOfFocusTenengradProjection("Cyan", cyan_final, 10);}
					else if (gpu_algorithm == "Sobel") {Ext.CLIJ2_extendedDepthOfFocusSobelProjection("Cyan", cyan_final, 10);}
					else if (gpu_algorithm == "Variance") {Ext.CLIJ2_extendedDepthOfFocusVarianceProjection("Cyan", cyan_final, 2, 2, 10);}
					Ext.CLIJ2_release("Cyan");
					Ext.CLIJ2_pull(cyan_final);
				rename("Cyan");
				if (dyeControl != "") {run("Subtract...", "value=" + CyanControl_mean*0.2);}
				if (method == "Intensity") {run("Remove Outliers...", "radius=3 threshold=50 which=Bright");}
				run("Enhance Contrast...", "saturated=0.3");
				run("Cyan");
				run("Set Scale...", "distance=" + resolution + " known=1 unit=micron");
			}
			
		}
	}
	else if(slices >= 2 && dostacks != true){
		close("*");
		continue;
	}
	else if(slices == 1) {
		if (align == true || forceAlign == 1) {
			alignStacks();
			forceAlign = 1;
		}

		//green channel
		channel="Green";
		selectWindow("Green");
		run("Duplicate..."," ");
		rename("Green-procColor");
		if (dyeControl != "") {run("Subtract...", "value=" + GreenControl_mean + " stack");}
		selectWindow("Green");
		removeBackground();
		if (dyeControl != "") {run("Subtract...", "value=" + GreenControl_mean*0.5 + " stack");}
		run("Despeckle");
		if (method == "Intensity") {run("Remove Outliers...", "radius=3 threshold=50 which=Bright");}
		
		//red channel
		channel="Red";
		selectWindow("Red");
		run("Duplicate..."," ");
		rename("Red-procColor");
		if (dyeControl != "") {run("Subtract...", "value=" + RedControl_mean + " stack");}
		selectWindow("Red");
		removeBackground();
		if (dyeControl != "") {run("Subtract...", "value=" + RedControl_mean*0.5 + " stack");}
		run("Despeckle");
		if (method == "Intensity") {run("Remove Outliers...", "radius=3 threshold=50 which=Bright");}
		if (find_biofilm == true) {
			selectWindow("Cyan");
			channel="Cyan";
			removeBackground();
			if (dyeControl != "") {run("Subtract...", "value=" + CyanControl_mean*0.5 + " stack");}
			else {run("Subtract...", "value=" + Cyan_mean*0.1);}
			run("Despeckle");
			if (method == "Intensity") {run("Remove Outliers...", "radius=3 threshold=50 which=Bright");}
		}
	}
}

function closingStatement(method) {
		close("*Histogram");
		close("*Composite*");
		close("*mask*");
		close("*shape*");
		close("*single*");
		close("*Stack*");
		close("(M*");
		close("*" + method + "*");
		close("Summary");
		close("Montage");
		close("(Frag)*");
		run("Clear Results");
}

function readData(mode) {
	selectWindow("Summary");
	IJ.renameResults("Results");
	if (mode == "mortality") {
		//Number counts
			greenCount = getResult("Count",0);
			redCount = getResult("Count",1);
			if (method == "Intensity") {
				trueredCount = getResult("Count",2);
			}
			else {
				yellowCount = getResult("Count",2);
			}
		//Average size and size fraction (area)
			greenAvgArea = getResult("Average Size", 0);
			redAvgArea = getResult("Average Size", 1);
			greenAreaFrac = getResult("%Area", 0);
			redAreaFrac = getResult("%Area", 1);
		//Shape descriptors
			//Perimeter
				greenAvgPeri = getResult("Perim.", 0);
				redAvgPeri = getResult("Perim.", 1);
			//Circularity
				greenAvgCirc = getResult("Circ.", 0);
				redAvgCirc = getResult("Circ.", 1);
			//Feret's diameter
				greenFeret = getResult("Feret", 0);
				redFeret = getResult("Feret", 1);
		//calculate death fraction
		if (method == "Intensity") {
			totalbac = greenCount + trueredCount;
			totalbac_intensity = totalbac;
			}
		else {
			totalbac = greenCount + redCount + yellowCount;
			totalbac_color = totalbac;
			}
		totalbacNorm = totalbac / imgArea;
		if (totalbac == 0) {mortality = 0;}
		else {
			if (method == "Intensity") {
				mortality = (redCount / totalbac) * 100;
				mortality_intensity = mortality;
			}
			else {
				mortality = ((redCount + yellowCount) / totalbac) *100;
				mortality_color = mortality;
			}
		}
	}
	if (mode == "secondary") {
		if (find_biofilm != true) {
			fragArea = getResult("%Area",0);
		}
		else if (find_biofilm == true) {
			fragArea = getResult("%Area",0);
			biofilmArea = getResult("%Area",1);
		}
	}
}

function saveData(type) {
	if (type == "full") {
		if (find_biofilm == true) {
			File.append(filename + "," + bac + "," + processingType + "," + greenCount + "," + redCount + "," + yellowCount + "," + totalbac + "," + totalbacNorm + "," + mortality + "," + fragArea + "," + greenAvgArea + "," + redAvgArea + "," + greenAreaFrac + "," + redAreaFrac + "," + greenAvgPeri + "," + redAvgPeri + "," + greenAvgCirc + "," + redAvgCirc + "," + greenFeret + "," + redFeret,output + "Full_data.txt");
		}
		else {
			File.append(filename + "," + bac + "," + processingType + "," + greenCount + "," + redCount + "," + yellowCount + "," + totalbac + "," + totalbacNorm + "," + mortality + "," + fragArea + "," + biofilmArea + "," + greenAvgArea + "," + redAvgArea + "," + greenAreaFrac + "," + redAreaFrac + "," + greenAvgPeri + "," + redAvgPeri + "," + greenAvgCirc + "," + redAvgCirc + "," + greenFeret + "," + redFeret,output + "Full_data.txt");
		}
	}
	else {
		totalbac_sum = totalbac_intensity +  totalbac_color;
		weight_int = totalbac_intensity / totalbac_sum;
		weight_color = totalbac_color / totalbac_sum;
		mortality_calc = ((mortality_intensity * weight_int) + (mortality_color * weight_color)) / (weight_int + weight_color);
		File.append(logfilename + "," + processingType + "," + mortality_calc,output + "Mortality.txt");
	}
}

function addScaleBar() {
	run("Scale Bar...", "width=6 height=5 font=18 color=Black background=White location=[Lower Right] bold overlay");
	run("Flatten");
}

function fragImg() {
	channel = "FragSelect";
	//copy for fragment analysis
	selectWindow("Green" + method);
	run("Duplicate...", " ");
	rename("GreenFrag" + method);
	selectWindow("Red" + method);
	run("Duplicate...", " ");
	rename("RedFrag" + method);
	if (method == "Color") {
		selectWindow("Yellow" + method);
		run("Duplicate...", " ");
		rename("YellowFrag" + method);
	}
	//image merges
	if (method == "Intensity") {
		imageCalculator("OR create", "RedFrag" + method,"GreenFrag" + method);
	}
	else {
		imageCalculator("OR create", "RedFrag" + method,"GreenFrag" + method);
		rename("ColorFragMidpoint");
		imageCalculator("OR create", "YellowFrag" + method,"ColorFragMidpoint");
		close("ColorFragMidpoint");
		selectWindow("Result of YellowFrag" + method);	
	}
	rename("Binary Select");
	strainCounter(method,channel);
	close("Binary Select");
	selectWindow("Count Masks of Binary Select");
	setThreshold(1, 65535, "raw");
	run("Convert to Mask");
	rename("(Frag) Binary" + method);
	run("Dilate");
}

function findFragments() {
	channel = "Frag";
	imageCalculator("Subtract create", "Fragments Channel","(Frag) Binary" + method);
	selectWindow("Result of Fragments Channel");
	rename("Fragments Channel-C-" + method);
	run("Magenta");
	if (find_biofilm != true) {run("Duplicate...", " ");
}
	if (find_biofilm == true) {
		imageCalculator("Subtract create","Fragments Channel-C-" + method,"Cyan-binary");
		rename("Fragments Channel-C-" + method + "no_biof");
	}
	//measurements
	if (find_biofilm == true) {
		channel="Frag";
		selectWindow("Fragments Channel-C-" + method + "no_biof");
		run("Duplicate...", " ");
		strainCounter(method,channel);
	
		channel = "Cyan";
		selectWindow("Cyan-binary");
		run("Duplicate...", " ");
		strainCounter(method,channel);
	}
	else {
		channel="Frag";
		selectWindow("Fragments Channel-C-" + method + "-1");
		strainCounter(method,channel);
	}
	//full composites
	if (find_biofilm == true) {		
		selectWindow("Fragments Channel-C-" + method + "no_biof");
		run("Magenta");
		addScaleBar();
		if (montages == true || saveindividual == true) {saveAs("Tiff", imgOutput_lite + "/" + method + " Method/Fragments Binary");}

		selectWindow("Cyan-binary");
		run("Duplicate...", " ");
		run("Cyan");
		addScaleBar();
		if (montages == true || saveindividual == true) {saveAs("Tiff", imgOutput_lite + "/" + method + " Method/Biofilm Binary");}
		
		run("Merge Channels...", "c5=[Cyan-binary] c6=[Fragments Channel-C-" + method + "no_biof] create keep ignore");
		addScaleBar();
		if (montages == true || saveindividual == true) {saveAs("Tiff", imgOutput_lite + "/" + method + " Method/Fragments and Biofilm Binary Composite");}
	}
	else {
		selectWindow("Fragments Channel-C-" + method + "-1");
		run("Magenta");
		addScaleBar();
		if (montages == true || saveindividual == true) {saveAs("Tiff", imgOutput_lite + "/" + method + " Method/Fragments Binary");}
	}
}

function calc_biofilm() {
	channel = "Cyan";
	selectWindow("Cyan");
	run("Duplicate...", " ");
	rename("Cyan-binary");
	autoThresholding("Mean");
	run("Cyan");
	selectWindow("Cyan");
	run("Duplicate...", " ");
}

function createFolders() {
	if (saveindividual == true) {
		File.makeDirectory(output + "/Individual Files/");
		File.makeDirectory(output + "/Individual Files/" + truncFilename);
		File.makeDirectory(output + "/Individual Files/" + truncFilename + "/Intensity Method");
		File.makeDirectory(output + "/Individual Files/" + truncFilename + "/Color Method");
		File.makeDirectory(output + "/Individual Files/" + truncFilename + "/Base Channels");
	}
	else {
		File.makeDirectory(output + "temp");
		File.makeDirectory(output + "temp/Intensity Method");
		File.makeDirectory(output + "temp/Color Method");
		File.makeDirectory(output + "temp/Base Channels");
	}
}

function cleanupFolders(imgOutput_lite, imageTemp, mode) {
	function deleteFiles(dir) {
	 	list = getFileList(dir);
	    for (i=0; i<list.length; i++) {
	       if (endsWith(list[i], "/"))
	          deleteFiles(""+dir+list[i]);
	       else
	          File.delete(dir + list[i]);
	    }
	}
	function deleteFolders(dir) {
	 	list = getFileList(dir);
	    for (i=0; i<list.length; i++) {
	          File.delete(dir + list[i]);
	    }
	}
	if (mode == "no_indiv") {
		deleteFiles(imgOutput_lite + "/"); 
		deleteFolders(imgOutput_lite + "/"); 
		File.delete(imgOutput_lite);
	}
	else if (mode == "temp2") {
		deleteFiles(imageTemp + "/"); 
		File.delete(imageTemp);
	}
}

function defineOutput(input, output, truncFilename, method) {
	if (saveindividual == true) {
		imgOutput = output + "/Individual Files/" + truncFilename + "/" + method;
		imgOutput_lite = output + "/Individual Files/" + truncFilename;
	}
	else {
		imgOutput = output + "temp/" + method;
		imgOutput_lite = output + "temp";
	}
}


function naturalImages(input, output, truncFilename, method) {
	defineOutput(input, output, truncFilename, method);

	//save base channels
		//Red
		selectWindow("Red-procColor");
		run("Duplicate..."," ");
		run("Set Scale...", "distance=" + resolution + " known=1 unit=micron");
		addScaleBar();
		if (montages == true || saveindividual == true) {saveAs("Tiff", imgOutput_lite + "/Base Channels/Red");}
		//Green
		selectWindow("Green-procColor");
		run("Duplicate..."," ");
		run("Set Scale...", "distance=" + resolution + " known=1 unit=micron");
		addScaleBar();
		if (montages == true || saveindividual == true) {saveAs("Tiff", imgOutput_lite + "/Base Channels/Green");}
		//Cyan
		if (find_biofilm == true) {
			selectWindow("Cyan");
			run("Duplicate..."," ");
			run("Set Scale...", "distance=" + resolution + " known=1 unit=micron");
			addScaleBar();
			if (montages == true || saveindividual == true) {saveAs("Tiff", imgOutput_lite + "/Base Channels/Cyan");}
		}

	if (find_biofilm == true) {
		run("Merge Channels...", "c1=[Red-procColor] c2=[Green-procColor] c5=[Cyan] create keep ignore");
		rename("biof_composite");
	}
	run("Merge Channels...", "c1=[Red-procColor] c2=[Green-procColor] create keep ignore");
	rename("Fragments Pre-Composite");
	
	//duplicate for find fragment
	selectWindow("Fragments Pre-Composite");
	run("Duplicate...", " ");
	rename("Fragments Channel");
	setAutoThreshold("Default dark");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	getStatistics(area, mean, min, max, std, histogram);
	if (mean == 255) {
		run("Invert");
	}
	run("Erode");
	
	if (find_biofilm == true) {
		selectWindow("biof_composite");
	}
	else {
		selectWindow("Fragments Pre-Composite");
	}
	run("RGB Color");
	addScaleBar();
	rename("(M4) Natural Composite");
	if (montages == true || saveindividual == true) {saveAs("Tiff", imgOutput_lite + "/Base Channels/Natural Composite");}
	close("RGB Color");
	close("Composite");
}

function createImages(input, output, truncFilename, method) {
	defineOutput(input, output, truncFilename, method);
	//Create binary composite images
		extra_channels_bin = " ";
		if (method == "Color") {
			extra_channels_bin = extra_channels_bin + "c7=[Yellow" + method + "] ";
		}
		run("Merge Channels...", "c1=[Red" + method +"] c2=[Green" + method +"]" + extra_channels_bin + "create ignore");
		selectWindow("Composite");
		run("RGB Color");
		addScaleBar();
		rename("(M5) Binary Composite");
		if (montages == true || saveindividual == true) {saveAs("Tiff", imgOutput + " Method/Binary Composite");}
		close("RGB Color");
		close("Composite");
	//create count outline composite
		extra_channels_outline = " ";
		if (method == "Color") {
			extra_channels_outline = extra_channels_outline + " c7=[Drawing of Yellow" + method + "] ";
		}
		run("Merge Channels...", "c1=[Drawing of Red" + method + "] c2=[Drawing of Green" + method + "]" + extra_channels_outline + "create ignore");
		selectWindow("Composite");
		run("RGB Color");
		addScaleBar();
		rename("(M8) Count Outline Composite");
		if (montages == true || saveindividual == true) {saveAs("Tiff", imgOutput + " Method/Count Outline Composite");}
		close("RGB Color");
		close("Composite");
}

//temp file handling function
function imageManage(image_name,new_name,method) {
	if (saveindividual == true) {
		File.copy(imgOutput_lite + "/" + method + "/" + image_name,imageTemp + "/" + image_name);
		File.rename(imageTemp + "/" + image_name,imageTemp + "/" + new_name);
	}
	else {
		File.rename(imgOutput_lite + "/" + method + "/" + image_name,imageTemp + "/" + new_name);
	}
}

function createMontage(input, output, filename) {
	//create montages directory
	montageFolder = output + "/Final Montages/";
	File.makeDirectory(montageFolder);

	
	//create temp directory for stack
	imageTemp = output + "temp2";
	if (File.exists(imageTemp) != 1) {
		File.makeDirectory(imageTemp);
	}
	
	//select and rename images for montage
	imageManage("Green.tif","(M1) Green Channel.tif","Base Channels");
	imageManage("Red.tif","(M2) Red Channel.tif","Base Channels");
	imageManage("Natural Composite.tif","(M3) Natural Composite.tif","Base Channels");
	
	imageManage("Binary Composite.tif","(M4) Binary Composite - Intensity Method.tif","Intensity Method");
	imageManage("Count Outline Composite.tif","(M5) Count Outlines - Intensity Method.tif","Intensity Method");
	
	imageManage("Binary Composite.tif","(M7) Binary Composite - Color Method.tif","Color Method");
	imageManage("Count Outline Composite.tif","(M8) Count Outline - Color Method.tif","Color Method");
	
	if (find_biofilm == true) {
		imageManage("Fragments and Biofilm Binary Composite.tif","(M6) Fragments and Biofilm Binary - Intensity method.tif","Intensity Method");
		imageManage("Fragments and Biofilm Binary Composite.tif","(M9) Fragments and Biofilm Binary - Color method.tif","Color Method");
	}
	else {
		imageManage("Fragments Binary.tif","(M6) Fragments Binary - Intensity method.tif","Intensity Method");
		imageManage("Fragments Binary.tif","(M9) Fragments Binary - Color method.tif","Color Method");
	}

	//open and sort images
	File.openSequence(imageTemp, "sort bitdepth=24");

	//define montage size and layout
	run("Make Montage...", "columns=3 rows=3 scale=1 font=50 label");

	selectWindow("Montage");
	//create lines function
	function lineFill() {
		run("Line to Area");
		run("Fill");
	}

	getDimensions(mon_width, mon_height, channels, slices, frames);
	//vertical lines
	makeLine(floor(mon_width/3), 0, floor(mon_width/3), mon_height, 4);
	lineFill();
	makeLine(floor((mon_width/3)*2), 0, floor((mon_width/3)*2), mon_height, 4);
	lineFill();
	//horizontal lines
	makeLine(0, floor(mon_height/3), mon_width, floor(mon_height/3), 4);
	lineFill();
	makeLine(0, floor((mon_height/3)*2), mon_width, floor((mon_height/3)*2), 4);
	lineFill();

	
	//save montage file
	saveAs("Jpeg", montageFolder + truncFilename + "-Montage");
	
	//delete temporary files
	if (saveindividual != true) {
		cleanupFolders(imgOutput_lite, imageTemp, "no_indiv");
	}
	cleanupFolders(imgOutput_lite, imageTemp, "temp2");
	
	close("Log");
}

function strainCounter(method,channel) {
	//Size definitions
	if (bac == "Pseudomonas") {
		min_circ=0.3;
		max_circ=1;
		min_size=0.5;
		max_size=1.5;
	}
	else if (bac == "E.Coli") {
		min_circ=0.3;
		max_circ=1;
		min_size=0.3;
		max_size=1.5;
	}
	else if (bac == "S.Aureus") {
		min_circ=0.8;
		max_circ=1;
		min_size=0.1;
		max_size=0.5;
	}
	else if (bac == "Non-specific") {
		min_circ=0;
		max_circ=1;
		min_size=0;
		max_size="Infinity";
	}
	else {}
	run("Set Scale...", "distance=" + resolution + " known=1 unit=micron");
	//Counting commands
	if (channel == "Frag" || channel == "Cyan") {
		run("Analyze Particles...", "  circularity=0.00-1.00 show=[Bare Outlines] exclude clear summarize size=0.00-Infinity");
	}
	else if (channel == "Truered") {
		run("Analyze Particles...", "  circularity=0.20-1.00 exclude clear summarize size=" + min_size + "-Infinity");  //might need some fine tuning (especially when considering Aureus)
	}
	else if (channel == "FragSelect") {
		run("Analyze Particles...", "  circularity=" + min_circ + "-" + max_circ + " show=[Count Masks] size=" + min_size + "-" + max_size);
	}
	else {
		run("Analyze Particles...", "  circularity=" + min_circ + "-" + max_circ + " show=[Bare Outlines] exclude clear summarize size=" + min_size + "-" + max_size);
		selectWindow("Drawing of " + channel + method);
		run("Invert");
	}
}

function individualChannels(method,channel) {
	if (channel == "Green") {
		montagepos = "(M1) ";
	}
	else {
		montagepos = "(M2) ";
	}
	run("Duplicate...", " ");
	selectWindow(channel + method + "-1");
	rename(montagepos + channel);
	run("Set Scale...", "distance=" + resolution + " known=1 unit=micron");
	addScaleBar();
	selectWindow(montagepos + channel);
	rename("tempname");
	selectWindow(montagepos + channel + "-1");
	rename(montagepos + channel);
	selectWindow("tempname");
	rename(montagepos + channel + "-1");
}

function processIntensity(input, output, filename) {
		method = "Intensity";
		defineOutput(input, output, truncFilename, method);
		//Initial file handling
			selectWindow("Green");
			run("Duplicate...", "title=Green" + method);
			selectWindow("Red");
			run("Duplicate...", "title=Red" + method);
		//Green channel
			channel = "Green";
			selectWindow("Green" + method);
			if (method == "Intensity") {run("Remove Outliers...", "radius=3 threshold=50 which=Bright");}
			selectWindow("Green" + method);
			individualChannels(method,channel);
			selectWindow("Green" + method);
			if (disable_green_tresh != true) {
				autoThresholding(thresh_method_green);
			}
			else {
				emptyThresholding();
			}
			strainCounter(method,channel);
		//Red channel
			channel = "Red";
			selectWindow("Red" + method);
			if (method == "Intensity") {run("Remove Outliers...", "radius=3 threshold=50 which=Bright");}
			selectWindow("Red" + method);
			individualChannels(method,channel);
			selectWindow("Red" + method);
			if (disable_red_tresh != true) {
				autoThresholding(thresh_method_red);
			}
			else {
				emptyThresholding();
			}
			strainCounter(method,channel);
		//Count single stained red bacteria
			channel = "Truered";
			imageCalculator("Subtract create", "Red" + method,"Green" + method);
			selectWindow("Result of Red" + method);
			rename("Red single stained");
			strainCounter(method,channel);
	readData("mortality");
	
	fragImg();
	createImages(input, output, truncFilename, method);
	findFragments();
	readData("secondary");
	saveData("full");
	closingStatement(method);
}
function processColor(input, output, filename) {
	method = "Color";
	defineOutput(input, output, truncFilename, method);
	//Initial file handling
		//create composite for process color
			channel="composite";
			run("Merge Channels...", "c1=[Red-procColor] c2=[Green-procColor] create keep ignore");
			selectWindow("Composite");
			run("RGB Color");
			removeBackground();
			run("Despeckle");
			rename("procColor");
			close("Composite");
		//Green channel
			channel = "Green";
			selectWindow("Green-procColor");
			selectWindow("Green-procColor");
		//Red channel
			channel = "Red";
			selectWindow("Red-procColor");
			selectWindow("Red-procColor");
		
	//Segmentation
		color_thresh = "Mean";
		//GREEN
			channel = "Green";
			selectWindow("procColor");
			run("Duplicate...", " ");
			rename("GreenCount");
				min=newArray(3);
				max=newArray(3);
				filter=newArray(3);
				a=getTitle();
				run("HSB Stack");
				run("Convert Stack to Images");
				selectWindow("Hue");
				rename("0");
				selectWindow("Saturation");
				rename("1");
				selectWindow("Brightness");
				rename("2");
				min[0]=55;
				max[0]=106;
				filter[0]="pass";
				min[1]=0;
				max[1]=255;
				filter[1]="pass";
				min[2]=26;
				max[2]=255;
				filter[2]="pass";
				for (i=0;i<3;i++){
				  if (i == 3) {
					selectWindow(""+i);
					setAutoThreshold(color_thresh + " dark");
					run("Convert to Mask", "method=" + color_thresh + " background=Dark black");
				  }
				  else {
					selectWindow(""+i);
					setThreshold(min[i], max[i]);
					run("Convert to Mask");
				  }
				  if (filter[i]=="stop")  run("Invert");
				}
				imageCalculator("AND create", "0","1");
				imageCalculator("AND create", "Result of 0","2");
				for (i=0;i<3;i++){
				  selectWindow(""+i);
				  close();
				}
				selectWindow("Result of 0");
				close();
				selectWindow("Result of Result of 0");
				rename("Green" + method);
				run("Despeckle");
			strainCounter(method,channel);
		//RED
			channel = "Red";
			selectWindow("procColor");
			run("Duplicate...", " ");
			rename("RedCount");
				min=newArray(3);
				max=newArray(3);
				filter=newArray(3);
				a=getTitle();
				run("HSB Stack");
				run("Convert Stack to Images");
				selectWindow("Hue");
				rename("0");
				selectWindow("Saturation");
				rename("1");
				selectWindow("Brightness");
				rename("2");
				min[0]=0;
				max[0]=17;
				filter[0]="pass";
				min[1]=0;
				max[1]=255;
				filter[1]="pass";
				min[2]=26;
				max[2]=255;
				filter[2]="pass";
				for (i=0;i<3;i++){
				  if (i == 3) {
					selectWindow(""+i);
					setAutoThreshold(color_thresh + " dark");
					run("Convert to Mask", "method=" + color_thresh + " background=Dark black");
				  }
				  else {
					selectWindow(""+i);
					setThreshold(min[i], max[i]);
					run("Convert to Mask");
				  }
				  if (filter[i]=="stop")  run("Invert");
				}
				imageCalculator("AND create", "0","1");
				imageCalculator("AND create", "Result of 0","2");
				for (i=0;i<3;i++){
				  selectWindow(""+i);
				  close();
				}
				selectWindow("Result of 0");
				close();
				selectWindow("Result of Result of 0");
				rename("Red" + method);
				run("Despeckle");
			strainCounter(method,channel);
		//YELLOW
			channel = "Yellow";
			selectWindow("procColor");
			run("Duplicate...", " ");
			rename("YellowCount");
				min=newArray(3);
				max=newArray(3);
				filter=newArray(3);
				a=getTitle();
				run("HSB Stack");
				run("Convert Stack to Images");
				selectWindow("Hue");
				rename("0");
				selectWindow("Saturation");
				rename("1");
				selectWindow("Brightness");
				rename("2");
				min[0]=27;
				max[0]=51;
				filter[0]="pass";
				min[1]=0;
				max[1]=255;
				filter[1]="pass";
				min[2]=26;
				max[2]=255;
				filter[2]="pass";
				for (i=0;i<3;i++){
				  if (i == 3) {
					selectWindow(""+i);
					setAutoThreshold(color_thresh + " dark");
					run("Convert to Mask", "method=" + color_thresh + " background=Dark black");
				  }
				  else {
					selectWindow(""+i);
					setThreshold(min[i], max[i]);
					run("Convert to Mask");
				  }
				  if (filter[i]=="stop")  run("Invert");
				}
				imageCalculator("AND create", "0","1");
				imageCalculator("AND create", "Result of 0","2");
				for (i=0;i<3;i++){
				  selectWindow(""+i);
				  close();
				}
				selectWindow("Result of 0");
				close();
				selectWindow("Result of Result of 0");
				rename("Yellow" + method);
				run("Despeckle");
			strainCounter(method,channel);
	readData("mortality");
	
	fragImg();
	createImages(input, output, truncFilename, method);
	findFragments();
	readData("secondary");
	saveData("full");
	closingStatement(method);
}

//Global variable declarations
var logfilename;
var bac=0;
var totalbac=0;
var totalbacNorm;
var method=0;
var replicate=0;
var sampleid=0;
var slices=0;
var greenCount=0;
var redCount=0;
var trueredCount=0;
var yellowCount;
var greenAvgArea=0;
var redAvgArea=0;
var greenAreaFrac=0;
var redAreaFrac=0;
var	greenAvgPeri=0;
var	redAvgPeri=0;
var	greenAvgCirc=0;
var	redAvgCirc=0;
var	greenFeret=0;
var	redFeret=0;
var mortality=0;
var discardedImages=0;
var analysisCount=0;
var gpu;
var resolution=0;
var green_final;
var red_final;
var fragArea=0;
var greenMaxArray = newArray(0);
var	greenMinArray = newArray(0);
var redMaxArray = newArray(0);
var	redMinArray = newArray(0);
var Green_max_mean;
var Green_min_mean;
var Red_max_mean;
var Red_min_mean;
var Green_min;
var Green_max;
var Red_min;
var Red_max;
var Cyan_min;
var Cyan_max;
var Red_mean;
var Green_mean;
var Cyan_mean;
var RedControl_mean;
var RedControl_min;
var RedControl_max;
var GreenControl_mean;
var GreenControl_min;
var GreenControl_max;
var CyanControl_mean;
var CyanControl_min;
var CyanControl_max;
var maxsize;
var align;
var truncFilename;
var method2;
var imgArea;
var exposure_Green;
var exposure_Red;
var TimeString;
var totaltime;
var mode = 1;
var channelDye1;
var channelDye2;
var channelDye3;
var biofilmArea;
var exposure_Cyan;
var input_type;
var extension;
var brand;
var man_dyeAssignment;
var autoBackgroundRemoval;
var findByLUT=false;
var gpu_algorithm;
var forceAlign;
var thresh_method_green="Yen";
var thresh_method_red="Yen";
var disable_green_tresh;
var disable_red_tresh;
var mortality_calc;
var mortality_intensity;
var mortality_color;
var filename;
var imageTemp;
var imgOutput;
var imgOutput_lite;
var totalbac_color;
var totalbac_intensity;

//Options prompt
Dialog.create("Options");
Dialog.addFile("Input file", "");
Dialog.setInsets(-7, 200, 5);
Dialog.addMessage("(For single file or project file)");
Dialog.addDirectory("Input folder", "");
Dialog.setInsets(-7, 200, 5);
Dialog.addMessage("(For multiple files)");
Dialog.addDirectory("Output folder","");
Dialog.setInsets(-7, 200, 5);
Dialog.addMessage("(Leave blank to use subfolder in input location)");
Dialog.addFile("Dye Control File", "");
Dialog.setInsets(-7, 200, 5);
Dialog.addMessage("(Optional but recommended)");
Dialog.addChoice("Microscope Brand/File Origin:", newArray("Automatic Detection", "Zeiss", "Leica", "Other"));
Dialog.addChoice("Channel Dye Assignment:", newArray("Automatic", "Red-Green-Cyan", "Green-Red-Cyan", "Cyan-Green-Red", "Cyan-Red-Green", "Red-Cyan-Green", "Green-Cyan-Red"));
Dialog.addChoice("Strain:", newArray("Non-specific", "Pseudomonas", "E.coli", "S.Aureus", "Custom"));
Dialog.setInsets(0, 20, 0);
Dialog.addCheckbox("_Process Z-Stacks", true);
items = newArray("CPU","GPU");
Dialog.setInsets(0, 20, 0);
Dialog.addRadioButtonGroup("", items, 1, 2, "CPU");
Dialog.addSlider("Projection Quality (CPU)", 0, 4, 3);
Dialog.addChoice("Projection Algorhithm (GPU)", newArray("Sobel", "Tenengrad", "Variance"));
Dialog.addCheckbox("Align Channels", false);
Dialog.addCheckbox("Detect biofilm", false);
Dialog.setInsets(0, 20, 0);
Dialog.addMessage("(Requires a channel with calcofluor white stain)");
Dialog.addMessage("Data Options");
Dialog.addCheckbox("Create Montages", true);
Dialog.addCheckbox("Save individual files", false);
Dialog.addCheckbox("Debug Mode", false);
Dialog.setInsets(10, 20, 10);
Dialog.addMessage("Required plugins: MorphoLIbJ, Extended Depth of Field, CLIJ2 (for GPU Processing use)");
Dialog.setInsets(10, 20, 10);
Dialog.show();

//Options handling. The order matters here, careful when changing
input_file = Dialog.getString();
input_folder = Dialog.getString();
output = Dialog.getString();
dyeControl = Dialog.getString();
brand=Dialog.getChoice();
man_dyeAssignment=Dialog.getChoice();
bac = Dialog.getChoice();
dostacks = Dialog.getCheckbox();
processingType = Dialog.getRadioButton();
edf_quality = Dialog.getNumber();
gpu_algorithm = Dialog.getChoice();
align = Dialog.getCheckbox();
find_biofilm = Dialog.getCheckbox();
montages = Dialog.getCheckbox();
saveindividual = Dialog.getCheckbox();
debug_mode = Dialog.getCheckbox();

//Custom strain filter setup
if (bac == "Custom") {
	Dialog.create("Options");
	Dialog.addMessage("Please define the custom size settings for this filter.\nExample default values are those of the Pseudomonas strain.\nSet maximum size to Infinity for no upper bounds");
	Dialog.addNumber("Minimum cirularity", 0.3);
	Dialog.addNumber("Maximum circularity", 1);
	Dialog.addNumber("Minimum size (μm2)", 0.3);
	Dialog.addNumber("Maximum size (μm2)", 1.5);
	min_circ=Dialog.getNumber();
	max_circ=Dialog.getNumber();
	min_size=Dialog.getNumber();
	max_size=Dialog.getNumber();
}

//GPU selection
if (processingType == "GPU") {
	setBatchMode(true);
	run("CLIJ2 Macro Extensions", "cl_device=");
	Ext.CLIJ2_listAvailableGPUs();
	selectWindow("Results");
	gpu_list = Table.getColumn("GPUName");
	close("Results");
	setBatchMode(false);
	if (gpu_list.length > 1) {
		run("Change OpenCL device");
	}
}

if(debug_mode == true){}
else {
	setBatchMode(true);
}

//input and output handling
// the default directory path can be added to this comparison
if (input_file != "" && input_folder != "") {
	Dialog.create("Error");
	Dialog.addMessage("You can't have both a file and directory input");
	Dialog.show();
	break;
}
else if (input_file != "") {
	input_type = "file";
	input = File.getDirectory(input_file);
	input_file = substring(input_file,lengthOf(input));
	if (output == "") {
		output = input + "processed\\";
		File.makeDirectory(output);
	}
}
else {
	input_type = "list";
	list = getFileList(input_folder);
	input = input_folder;
	if (output == "") {
		output = input + "processed\\";
		File.makeDirectory(output);
	}
}

//extension parser
function extensionChoose() {
	if (indexOf(input_file, ".lif") != -1 || brand == "Leica") {
		extension = ".lif";
		brand = "Leica";
	}
	else if (indexOf(input_file, ".czi") != -1 || brand == "Zeiss") {
		extension = ".czi";
		brand = "Zeiss";
	}
	else {
		brand = "Other";
	}
}
if (input_type == "file") {
	extensionChoose();
}
else if (input_type == "list") {
	input_file = list[1];
	extensionChoose();
}

//Leica project file pre handling
if (extension == ".lif" || brand == "Leica" && input_type == "file") {
	islif = true;
	File.makeDirectory(input + "individual_originals/");
	run("Bio-Formats Importer", "open=" + "[" + input_file + "]" + " " + "color_mode=Colorized open_all_series view=Hyperstack stack_order=XYZCT use_virtual_stack windowless=true");
	lif_list = getList("image.titles");
	for (i=0; i<lif_list.length; i++) {
		saveAs("Tiff", input + "individual_originals/" + substring(lif_list[i],indexOf(lif_list[i], "-") + 2));
		close();
	}
	input = input + "individual_originals/";
	list = getFileList(input);
	input_file = list[1];
	input_type = "list";
}

//catch invalid channel options
if (input_type == "file") {
	run("Bio-Formats Importer", "open=" + "[" + input + input_file + "]" + " " + "color_mode=Colorized open_all_series view=Hyperstack stack_order=XYZCT use_virtual_stack windowless=true");
	getDimensions(width, height, num_channels, slices, frames);
	close(File.getName(input_file));
}
else {
	run("Bio-Formats Importer", "open=" + "[" + input + list[1] + "]" + " " + "color_mode=Colorized open_all_series view=Hyperstack stack_order=XYZCT use_virtual_stack windowless=true");
	getDimensions(width, height, num_channels, slices, frames);
	close(list[1]);
}

if (find_biofilm == 1 && num_channels <= 2) {
	Dialog.create("Error");
	Dialog.addMessage("You chose to find biofilm but images appear to only have 2 channels.\nBiofilm identification will be deactivated.");
	Dialog.show();
	find_biofilm = false;
}

//create .txt output files
if (find_biofilm == true) {
	File.append("Filename," + "Strain," + "Processing," + "Green Count," + "Red Count," + "R/G diff Count," + "Total Bacteria," + "Total Bacteria (by mm2)," + "Mortality %," + "Fragment/Biofilm Area%," + "Green Avg Area," + "Red Avg Area," + "Green Area fraction," + "Red Area Fraction," + "Green Perimeter," + "Red Perimeter," + "Green Circularity," + "Red Circularity," + "Green Feret's Diameter," + "Red Feret's Diameter,",output + "Full_data.txt");
}
else {
	File.append("Filename," + "Strain," + "Processing," + "Green Count," + "Red Count," + "R/G diff Count," + "Total Bacteria," + "Total Bacteria (by mm2)," + "Mortality %," + "Fragment Area%," + "Biofilm Area%," + "Green Avg Area," + "Red Avg Area," + "Green Area fraction," + "Red Area Fraction," + "Green Perimeter," + "Red Perimeter," + "Green Circularity," + "Red Circularity," + "Green Feret's Diameter," + "Red Feret's Diameter,",output + "Full_data.txt");
}

File.append("Filename," + "Processing," + "Mortality %",output + "Mortality.txt");

//create log file
File.append("---------------Log start---------------", output + "log.txt");
GetTime();
File.append("Script version: " + version, output + "log.txt");
File.append("Start Time:\n" + TimeString, output + "log.txt");
File.append("\nRun options:\n", output + "log.txt");
if (dyeControl != "") {File.append("Dye Control file: " + dyeControl, output + "log.txt");}
File.append("Process Z-Stacks: " + dostacks, output + "log.txt");
if (dostacks == true) {
	File.append("Processing type: " + processingType, output + "log.txt");
	if (processingType == "CPU") {
		File.append("Projection Quality: " + edf_quality, output + "log.txt");
		}
	else {
		File.append("Projection Algorithm: " + gpu_algorithm, output + "log.txt");
		}
	}
File.append("Microscope brand/File origin: " + brand, output + "log.txt");
File.append("Channel dye assignment: " + man_dyeAssignment, output + "log.txt");
File.append("Strain Settings: " + bac, output + "log.txt");
File.append("Align Stacks: " + align, output + "log.txt");
File.append("Detect Biofilm (Calcofluor): " + find_biofilm, output + "log.txt");
File.append("Create Montages: " + montages, output + "log.txt");
File.append("\n--------------Individual file details--------------", output + "log.txt");
////////////
//Program execution
run("Set Measurements...", "area mean standard min perimeter shape feret's area_fraction redirect=None decimal=3");
if (dyeControl != "") {fluoroControlFindValues();}
if (input_type == "file") {
	time1 = getTime();
	truncFilename = File.getNameWithoutExtension(input_file);
	if (montages == true || saveindividual == true) {createFolders();}
	fileHandling(input, output, input_file);
	forceAlign = 0;
	if (find_biofilm == true) {calc_biofilm();}
	processIntensity(input, output, input_file);
	processColor(input, output, input_file);
	saveData("calc");
	analysisCount = analysisCount +1;
	if (montages == true) {createMontage(input, output, truncFilename);}
	close("*");
	time2 = getTime();
	duration = d2s((time2 - time1) / 1000,2);
	totaltime = totaltime + duration;
	File.append(logfilename + " Processed in " + duration + " seconds", output + "log.txt");
}
else {
	ETA_array = newArray();
	for (i = 0; i < list.length; i++) {
		time1 = getTime();
		truncFilename = File.getNameWithoutExtension(input + list[i]);
		if (montages == true || saveindividual == true) {createFolders();}
		fileHandling(input, output, list[i]);
		forceAlign = 0;
		if (find_biofilm == true) {calc_biofilm();}
		processIntensity(input, output, list[i]);
		processColor(input, output, list[i]);
		saveData("calc");
		analysisCount = analysisCount +1;
		if (montages == true) {createMontage(input, output, truncFilename);}
		close("*");
		time2 = getTime();
		duration = d2s((time2 - time1) / 1000,2);
		totaltime = totaltime + duration;
		ETA_array = Array.concat(ETA_array,duration);
		Array.getStatistics(ETA_array, duration_min, duration_max, duration_avg, duration_stdDev);
		ETA = d2s((duration_avg * (list.length - i)) / 60,0);
		File.append(logfilename + " Processed in " + duration + " seconds", output + "log.txt");
		showProgress(i/list.length);
		print("Estimated remaining time until completion: " + ETA + " minutes");
	}
}
close("*");
if (processingType == "GPU") {
	Ext.CLIJ2_clear();
}
close("Results");
setBatchMode(false);

//finish prompt
GetTime();
File.append("--------------Individual file details end--------------\n", output + "log.txt");
File.append("End Time:\n" + TimeString, output + "log.txt");
if (totaltime > 3600) {
	avg_time = d2s(totaltime / analysisCount,2);
	totaltime = d2s(totaltime / 60 / 60,2);
	File.append("Analysis complete. " + analysisCount + " images processed in " + totaltime + " hours (average of " + avg_time + " seconds per image).", output + "log.txt");
}
else {
	avg_time = d2s(totaltime / analysisCount,2);
	totaltime = d2s(totaltime / 60,2);
	File.append("Analysis complete. " + analysisCount + " images processed in " + totaltime + " minutes (average of " + avg_time + " seconds per image).", output + "log.txt");
}
File.append("Script has run successfully\n", output + "log.txt");
File.append("---------------Log end---------------", output + "log.txt");
Dialog.create("Analysis Finished");
Dialog.addMessage("Analysis complete. " + analysisCount + " images processed");
Dialog.show();
