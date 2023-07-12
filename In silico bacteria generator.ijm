//Written by ricardo Bessa
//global var declarations
var noise_int_mean;
var zoneX=0;
var zoneY=0;
var id;

//settings
	//file prefix naming convention
		name = "synth";
	//output folder
		output = "D:/";
		folder = "SynthMix";
	//number of images
		nImg = 10;
	//image dimensions
		width = 1388;
		height = 1040;
	//number of bacteria (range)
		bacMin = 50;
		bacMax = 700;
	//number of fake bacteria (false positives and negatives, aka "Lies")
		bacLiesMin = bacMin * 0.1;
		bacLiesMax = bacMax * 0.2;
	//number of double stained bacteria
		bacDoubleMin = bacMin * 0.01;
		bacDoubleMax = bacMax * 0.1;
	//bacteria pseudo fluorescence intensity
		intMin = 350;
		intMax = 500;
	//background noise intensity
		backgroundInt = intMin * 0.33;
	//bacteria morphology settings
		//bacteria shape (rod or coccus)
		shape = "mixed"; //or "rod" or "mixed"
		//rod settings
			var rod_sizeMin = 20;
			var rod_sizeMax = 40;
			var rod_bacRatioMin = 0.1;
			var rod_bacRatioMax = 0.2;
		//coccus settings
			var coccus_sizeMin = 7;
			var coccus_sizeMax = 10;
			var coccus_bacRatioMin = 0.9;
			var coccus_bacRatioMax = 1;
			//clustering
				var nClustersMin = 10;
				var nClustersMax = 64;
			//cluster calcs
				nClusters = nClustersMin + round(random * ((nClustersMax - nClustersMin) + 1));
				nClustersDiv = round(sqrt(nClustersMax));
				zoneSizeX = width / nClustersDiv;
				zoneSizeY = height / nClustersDiv;
			//define clusters (starting points)
				y_array = newArray(0);
				x_array = newArray(0);
				for (p = 0; p < nClustersDiv; p++) {
					zoneY = zoneSizeY * p;
					y_array = Array.concat(y_array, zoneY);
					zoneX = zoneSizeX * p;
					x_array = Array.concat(x_array, zoneX);
				}
	
setBatchMode(true);
File.makeDirectory(output + folder + "/");
if (shape == "mixed") {
	File.append("Filename," + "Red Coccus," + "Fake Red Coccus," + "Green Coccus," + "Fake Green Coccus," + "Double Stained Coccus," + "Mortality Coccus," + "Red Rod," + "Fake Red Rod," + "Green Rod," + "Fake Green Rod," + "Double Stained Rod," + "Mortality Rod" , output + folder + "/" + "synth_data.txt");
}
else {
	File.append("Filename," + "Red," + "Fake Red," + "Green," + "Fake Green," + "Double Stained," + "Mortality", output + folder + "/" + "synth_data.txt");
}

function createNoise() {
	newImage("noise", "16-bit black", width, height, 1);
	setColor(backgroundInt);
	fillRect(0, 0, width, height);
	run("Add Noise");
	run("Mean...", "radius=5");
	run("Gaussian Blur...", "sigma=3 stack");
	getStatistics(area, noise_int_mean, noise_min, noise_max, std, histogram);
}
function localBiofilm() {
	setColor(intRand / 10);
	run("Enlarge...", "enlarge=15");
	fill();
	run("Enlarge...", "enlarge=-15");
	setColor(intRand);
}
function bacGen(truth,stack) {
	if (truth == "truth") {
		intRand = intMin + round(random * ((intMax - intMin) + 1));
		setColor(intRand);
	}
	else {
		intRand = intMin + round(random * ((intMax - intMin) + 1));
		setColor(intRand / 5);
	}
	if (shape == "rod") {
		//ellipse - Pseudomonas and other rod shaped bacteria
		x1 = random() * width;
		y1 = random() * height;
		bacWidth = rod_sizeMin + round(random * ((rod_sizeMax - rod_sizeMin) + 1));
		bacHeight = rod_sizeMin + round(random * ((rod_sizeMax - rod_sizeMin) + 1));
		//define random rotation
		rotRand = 1 + round(random * ((360 - 1) + 1));
		//ellipse bounds
		x2 = x1 - (bacWidth / 2);
		x3 = x1 + (bacWidth / 2);
		y2 = y1 - (bacHeight / 2);
		y3 = y1 + (bacHeight / 2);
		//randomize aspect ratio
		bacRatio = rod_bacRatioMin + random * (rod_bacRatioMax - rod_bacRatioMin);
		//draw shapes
		makeEllipse(x1, y1, x2, y2, bacRatio);
		run("Rotate...", "  angle=" + rotRand);
		run("Enlarge...", "enlarge=2");
		if (stack == "stack") {
			setSlice(1);
	    	fill();
	    	setSlice(2);
	    	fill();
		}
		else {
			//localBiofilm();
			fill();
		}
	}
	else if (shape == "coccus") {			
		//ellipse - using a high aspect ration ellipse for small variations on circularity
		x1 = coord_X + round(random * (((coord_X + zoneSizeX) - coord_X) + 1)) + round((random() * 0.15 * zoneSizeX));
		y1 = coord_Y + round(random * (((coord_Y + zoneSizeY) - coord_Y) + 1)) + round((random() * 0.15 * zoneSizeY));
		bacWidth = coccus_sizeMin + round(random * ((coccus_sizeMax - coccus_sizeMin) + 1));
		bacHeight = coccus_sizeMin + round(random * ((coccus_sizeMax - coccus_sizeMin) + 1));
		//define random rotation
		rotRand = 1 + round(random * ((360 - 1) + 1));
		//ellipse bounds
		x2 = x1 - (bacWidth / 2);
		x3 = x1 + (bacWidth / 2);
		y2 = y1 - (bacHeight / 2);
		y3 = y1 + (bacHeight / 2);
		//randomize aspect ratio
		bacRatio = coccus_bacRatioMin + random * (coccus_bacRatioMax - coccus_bacRatioMin);
		//draw shapes
		makeEllipse(x1, y1, x2, y2, bacRatio);
		run("Rotate...", "  angle=" + rotRand);
		run("Enlarge...", "enlarge=2");
		if (stack == "stack") {
			setSlice(1);
			fill();
			setSlice(2);
			fill();
		}
		else {
			//localBiofilm();
			fill();
		}
	}
}

function makeReal() {
	run("Select None");
	run("Smooth", "stack");
	run("Gaussian Blur...", "sigma=1 stack");
}

function bacGenExec(id,nbacLiesRed,nbacRed,nbacLiesGreen,nbacGreen,nbacDouble) {
	selectWindow(name + "Red" + i + 1);
	//generate redfake bacteria
		for (j = 0; j < nbacLiesRed; j++) {
			bacGen("lies","slice");
		}
	//generate red true bacteria
		for (j = 0; j < nbacRed; j++) {
			bacGen("truth","slice");
		}
	selectWindow(name + "Green" + i + 1);
	//generate green fake bacteria
		for (j = 0; j < nbacLiesGreen; j++) {
			bacGen("lies","slice");
		}
	//generate green true bacteria
		for (j = 0; j < nbacGreen; j++) {
			bacGen("truth","slice");
		}	
	//generate double stained
		run("Images to Stack", "name=Synth" + id + " title=[" + id + "] use");
		for (j = 0; j < nbacDouble; j++) {
			bacGen("truth","stack");
		}
		run("Stack to Images");
}

//generate images
for (i = 0; i < nImg; i++) {
	imgNumber = IJ.pad(i + 1, 4);
	//Generate red channel
		newImage(name + "Red" + i + 1, "16-bit black", width, height, 1);
	//Generate green channel
		newImage(name + "Green" + i + 1, "16-bit black", width, height, 1);
	id = parseInt(i) + 1;
	if (shape == "rod") {
		nbacRed = bacMin + round(random * ((bacMax - bacMin) + 1));
		nbacLiesRed = bacLiesMin + round(random * ((bacLiesMax - bacLiesMin) + 1));
		nbacGreen = bacMin + round(random * ((bacMax - bacMin) + 1));
		nbacLiesGreen = bacLiesMin + round(random * ((bacLiesMax - bacLiesMin) + 1));
		nbacDouble = bacDoubleMin + round(random * ((bacDoubleMax - bacDoubleMin) + 1));

		bacGenExec(id,nbacLiesRed,nbacRed,nbacLiesGreen,nbacGreen,nbacDouble);
	}
	else if (shape == "coccus") {
		nbacRed = bacMin + round(random * ((bacMax - bacMin) + 1));
		nbacRed_div = round(nbacRed / nClusters);
		nbacLiesRed = bacLiesMin + round(random * ((bacLiesMax - bacLiesMin) + 1));
		nbacLiesRed_div = round(nbacLiesRed / nClusters);
		nbacGreen = bacMin + round(random * ((bacMax - bacMin) + 1));
		nbacGreen_div = round(nbacGreen / nClusters);
		nbacLiesGreen = bacLiesMin + round(random * ((bacLiesMax - bacLiesMin) + 1));
		nbacLiesGreen_div = round(nbacLiesGreen / nClusters);
		nbacDouble = bacDoubleMin + round(random * ((bacDoubleMax - bacDoubleMin) + 1));
		nbacDouble_div = round(nbacDouble / nClusters);
		for (n = 0; n < nClusters; n++) {
			//pick random coordinates
			rCoord = 0 + floor(random * (nClustersDiv - 0));
			coord_X = x_array[rCoord];
			Array.deleteValue(x_array, rCoord);	
			rCoord = 0 + floor(random * (nClustersDiv - 0));
			coord_Y = y_array[rCoord];
			Array.deleteValue(x_array, rCoord);

			bacGenExec(id,nbacLiesRed_div,nbacRed_div,nbacLiesGreen_div,nbacGreen_div,nbacDouble_div);
		}
	}
	else if (shape == "mixed") {
		//mixed calcs
		total_nbacRed = bacMin + round(random * ((bacMax - bacMin) + 1));
		total_nbacLiesRed = bacLiesMin + round(random * ((bacLiesMax - bacLiesMin) + 1));
		total_nbacGreen = bacMin + round(random * ((bacMax - bacMin) + 1));
		total_nbacLiesGreen = bacLiesMin + round(random * ((bacLiesMax - bacLiesMin) + 1));
		total_nbacDouble = bacDoubleMin + round(random * ((bacDoubleMax - bacDoubleMin) + 1));
		//rod calcs
		rod_nbacRed = round(random * ((total_nbacRed) + 1));
		rod_nbacLiesRed = round(random * ((total_nbacLiesRed) + 1));
		rod_nbacGreen = round(random * ((total_nbacGreen) + 1));
		rod_nbacLiesGreen = round(random * ((total_nbacLiesGreen) + 1));
		rod_nbacDouble = round(random * ((total_nbacDouble) + 1));
		//coccus calcs
		coccus_nbacRed = round(total_nbacRed - rod_nbacRed);
		coccus_nbacRed_div = round(coccus_nbacRed / nClusters);
		coccus_nbacLiesRed = round(total_nbacLiesRed - rod_nbacLiesRed);
		coccus_nbacLiesRed_div = round(coccus_nbacLiesRed / nClusters);
		coccus_nbacGreen = round(total_nbacGreen - rod_nbacGreen);
		coccus_nbacGreen_div = round(coccus_nbacGreen / nClusters);
		coccus_nbacLiesGreen = round(total_nbacLiesGreen - rod_nbacLiesGreen);
		coccus_nbacLiesGreen_div = round(coccus_nbacLiesGreen / nClusters);
		coccus_nbacDouble = round(total_nbacDouble - rod_nbacDouble);
		coccus_nbacDouble_div = round(coccus_nbacDouble / nClusters);
		//generate rods
		shape = "rod";
		bacGenExec(id,rod_nbacLiesRed,rod_nbacRed,rod_nbacLiesGreen,rod_nbacGreen,rod_nbacDouble);
		//generate coccus
		shape = "coccus";
		for (n = 0; n < nClusters; n++) {
			//pick random coordinates
			rCoord = 0 + floor(random * (nClustersDiv - 0));
			coord_X = x_array[rCoord];
			Array.deleteValue(x_array, rCoord);	
			rCoord = 0 + floor(random * (nClustersDiv - 0));
			coord_Y = y_array[rCoord];
			Array.deleteValue(x_array, rCoord);
			bacGenExec(id,coccus_nbacLiesRed_div,coccus_nbacRed_div,coccus_nbacLiesGreen_div,coccus_nbacGreen_div,coccus_nbacDouble_div);
		}
		shape = "mixed";
	}
	run("Images to Stack", "name=Synth" + id + " title=[" + id + "] use");
	makeReal();
	if (backgroundInt != 0) {
		createNoise();
		selectWindow("Synth" + id);
		run("Subtract...", "value=" + noise_int_mean + " stack");
		imageCalculator("Add stack", "Synth" + id,"noise");
		close("noise");
	}
	resetThreshold();
	run("Properties...", "channels=2 slices=1 frames=1 pixel_width=0.0645000 pixel_height=0.0645000 voxel_depth=0.0645000");
	rename(name + imgNumber);
	Stack.setXUnit("micron");
	if (shape == "rod" || shape == "coccus") {
		totalbac = nbacRed + nbacGreen + nbacDouble;
		mortality = (nbacRed + nbacDouble) / totalbac;
		File.append(name + imgNumber + "," + nbacRed + "," + nbacLiesRed + "," + nbacGreen + "," + nbacLiesGreen + "," + nbacDouble + "," + mortality, output + folder + "/" + "synth_data.txt");
	}
	else if (shape == "mixed") {
		rod_totalbac = rod_nbacRed + rod_nbacGreen + rod_nbacDouble;
		rod_mortality = (rod_nbacRed + rod_nbacDouble) / rod_totalbac;
		coccus_totalbac = coccus_nbacRed + coccus_nbacGreen + coccus_nbacDouble;
		coccus_mortality = (coccus_nbacRed + coccus_nbacDouble) / coccus_totalbac;
		File.append(name + imgNumber + "," + coccus_nbacRed + "," + coccus_nbacLiesRed + "," + coccus_nbacGreen + "," + coccus_nbacLiesGreen + "," + coccus_nbacDouble + "," + coccus_mortality + "," + rod_nbacRed + "," + rod_nbacLiesRed + "," + rod_nbacGreen + "," + rod_nbacLiesGreen + "," + rod_nbacDouble + "," + rod_mortality, output + folder + "/" + "synth_data.txt");
	}
	saveAs("Tiff", output + folder + "/" + name + imgNumber);
	close("*");
}
setBatchMode(false);
