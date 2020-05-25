// ------LICENSE STUFF------


// Description:
// This script performs co-registratioon of histological slices (different stainings) with Elastix.
// it follows the following steps:
// 1. Images are loaded and converted to h5-Format for efficient processing
// 2. A small margin is removed from the edges of the images to account for possible stitching artifacts The extent ofthis margin can be set manually.
// 3. The images are compared in size. The larger image is downsampled to match the size of the smaller image.
// 4. Both images are masked and unnecessary background is remooved from the images for data-efficiiency.
// 5. Elastix is called to perform similarity-registration of the generated masks. This yields a transformation file that can be used to transform other images accordingly.
// 6. Images to be transformed are split into single slices, transformed and put back together.
// 7. Done.

#@ File (label="Moving image filename") moving_image // filename of moving image;
#@ File (label="Target image filename") target_image // filename of target image;

#@ Boolean (label="Moving image is brightfield",  moving_is_BF=true) moving_is_BF
#@ Boolean (label="Target image is brightfield", target_is_BF=false) target_is_BF
#@ Boolean (label="Ram protection", RAM_protection=true) RAM_protection

// Input Parameters:
root = File.getParent(target_image); //path to your directory with the to-be-registered images

// Paths to all necessary input files. Make sure these are set accurately!
Inputs = newArray(3); // don't touch this line.
Inputs[0] = moving_image; 	
Inputs[1] = target_image; 	
Inputs[2] = "B:/Promotion/NCRO/Histologie/Scripts/3_HistoReg/Scripts/"; // Path to the directory of this script

margin = 0.008; // Percentage of the width/height of  the image that's removed around the edges. If set to 0, the image remains untouched.


// use this section only if you intend to call this macro from another macro.
// ------------
/*
args = getArgument();
args = split(args, "- ");
root      = args[0];
Inputs[0] = args[1]; // moving image filename (relative to root directory)
Inputs[1] = args[2]; // target image filename (relative to root directory)
Inputs[2] = args[3]; // script directory
*/
// ------------


// Clean up
run("Close All");
run("Clear Results");
roiManager("reset");

// Format Inputs
elastix_path 		= Inputs[2] + "elastix-4.9.0-win64/elastix.exe";
transformix_path 	= Inputs[2] + "elastix-4.9.0-win64/transformix.exe";
elastix_params   	= Inputs[2] + "elastix_parameters.txt";

// check Inputs
print("Root directory:" + root);
checkInput(moving_image);
checkInput(target_image);
checkInput(elastix_path);
checkInput(transformix_path);
checkInput(elastix_params);

// Make all necessary folders
tmp_path	= root + "/tmp/";
out_path 	= root + "/output/";

if (!File.isDirectory(tmp_path)) {
	File.makeDirectory(tmp_path);
}

if (!File.isDirectory(out_path)) {
	File.makeDirectory(out_path);
}

f = newArray(2); // this array contains the resolution scaling factors
f[0] = 1.0;
f[1] = 1.0;

// First step: Preprocess input:1
// 1. check image sizes
// 2. crop edges
// 3. mask

// ----------------- START ----------------------------

res0 = convert2h5(moving_image, tmp_path, RAM_protection);
res1 = convert2h5(target_image, tmp_path, RAM_protection);

f_init0 = res0[1];
f_init1 = res1[1];
moving_image = res0[0];
target_image = res1[0];


// Remove a small margin around image to account for stitching artefacts (deprecated)
//removeMargin(target_image, margin);
//removeMargin(moving_image, margin);

// Adjust uneven image sizes and create masks. Re-adjust masks afterwards
//f_pre = adjustSizes(moving_image, target_image);
//f[0] = f[0] * f_pre[0]; 
//f[1] = f[1] * f_pre[1];

// Create Masks of images and crop background as much as possible
moving_image_mask = Mask(moving_image, moving_is_BF);
target_image_mask = Mask(target_image, target_is_BF);

// Adjust uneven image sizes to ease registration
f_post = adjustSizes(moving_image, 		target_image);
f_post = adjustSizes(moving_image_mask, 	target_image_mask);
f[0] = f[0] * f_post[0];
f[1] = f[1] * f_post[1];

// calculate pixel resolutions based on previous downsampling
f[0] = f_init0 * f[0];
f[1] = f_init1 * f[1];

file = File.open(out_path + "downsample_factor.txt");
//print(f[0], f_init0, f_pre[0], f_post[0]);
//print(f[1], f_init1, f_pre[1], f_post[1]);

// save downsampling factors
print(file, "Moving image\t" + moving_image + "\t" +d2s(f[0],2) + "\tInitial size\t" + d2s(res0[3],3) + " " + res0[2]);
print(file, "Target image\t" + target_image + "\t" +d2s(f[1],2) + "\tInitial size\t" + d2s(res1[3],3) + " " + res1[2]);
File.close(file);

//Save target image(s)
selectWindow(target_image);
saveAs(".tif", out_path + target_image);
rename(target_image);

selectWindow(target_image_mask);
saveAs(".tif", out_path + target_image_mask);
rename(target_image_mask);

// Register & Transform
trafo_file 			= Align( elastix_path, moving_image_mask, target_image_mask, tmp_path, elastix_params, out_path);
transformed_image 	= Transform( transformix_path, tmp_path, moving_image, 		 out_path, trafo_file, 255.0);
transformed_image 	= Transform( transformix_path, tmp_path, moving_image_mask,  out_path, trafo_file, 1.0);
run("Close All");

// give result image
displayResult(out_path);
print("-----------Registration finished.-----------");






function displayResult(directory){
	// browses a directory for all tiff images that are masks
	// that originate from registration. Displays as compposite and saves as jpg
	// for later use in thesis?

	filelist = getFileList(directory);
	masks    = newArray(0);
	for (i = 0; i < filelist.length; i++) {
		if (endsWith(filelist[i], "_mask.tif")) {
			open(directory + filelist[i]);
			rename(File.nameWithoutExtension);
			run("8-bit");
			masks = Array.concat(masks, getTitle());
		}
	}

	if (masks.length == 2) {
		run("Merge Channels...", "c5="+masks[0]+" c6="+masks[1]+" create");
		saveAs(".png", directory + "registration_agreement");
		waitForUser("That's your result");
	}
}

function checkMask(image, mask, brightBG){
	selectWindow(image);
	run("RGB Color");
	overlay = getTitle();
	run("Enhance Contrast", "saturated=0.35");

	selectWindow(mask);

	if (brightBG){
		run("Add Image...", "image=["+overlay+"] x=0 y=0 opacity="+50);
	} else  {
		run("Add Image...", "image=["+overlay+"] x=0 y=0 opacity="+50);
	}

	waitForUser("Use drawing tools to correct contour");
	run("Remove Overlay");
	run("Fill Holes");

	close(overlay);
	selectWindow(mask);
}

function checkInput(Input){
	// Checks inputs (only files) to check whether they exist.
	if (!File.exists(Input)) {
		waitForUser("Input >>" + Input +"<< not found! Aborting script.");
		exit();			
	}
}

function Transform(transformix_path, working_dir, Source, output_dir, trafo_file, f){
	// calls transformix to transform a given image according to a given transformation file.
	// Can handle Stack images. Inputs:
	// - transformix_path: Path to transformix executable
	// - working_dir: Place to store some intermediate files
	// - Source: Source image to transform (ImageJ image)
	// - output_dir: Directory to save transformed image at.
	// - Elastix transformation file with transformation parameters.

	print("Transforming " + Source + " (source image) according to " + trafo_file + " (transformation file)");
	/// temporarily save source image as separate tif (slice-wise)
	selectWindow(Source);
	
	print("Source image has " + nSlices + " slices");
	N = nSlices;

	// do this for every slice
	for (i = 1; i <= N; i++) {
		selectWindow(Source);
		run("Duplicate...", "title=Slice_" + i + " duplicate channels=" + i);


		run("32-bit");
		run("Divide...", "value="+f);
		saveAs("tif", working_dir + "Slice_" + i);
		close("Slice_" + i + ".tif");
		
		// call transformix
		exec(transformix_path   + " " +  
		"-tp " + trafo_file 	+ " " +
		"-out "+ output_dir     + " " +
		"-in " + working_dir + "Slice_" + i + ".tif");

		open(output_dir + "result.mhd");
		rename("Slice_" + i);
		saveAs("tif", output_dir + "Slice_" + i);
		close();

		// remove tmp file
		File.delete(working_dir + "Slice_" + i + ".tif");
	}
	
	File.delete(output_dir + "result.mhd");
	File.delete(output_dir + "result.raw");

	// Put transformed images back together
	for (i = 1; i <= N; i++) {
		open(output_dir + "Slice_" + i +  ".tif");
	}
	run("Images to Stack", "name=Stack title=Slice_ use");
	rename(Source);	
	saveAs(".tif", output_dir  + Source);
	close();

	// remove leftovers
	for (i = 1; i <= N; i++) {
		File.delete(output_dir + "Slice_" + i +  ".tif");
	}
	
	return Source;
}

function Align(elastix_path, moving, fixed, working_dir, parameter_file, output_dir){
	// calls elastix to perform registration.
	// needs: 
	// - elastix_path: Full path to elastix executable.
	// - moving: full path to moving image.
	// - fixed: full path to fixed image.
	// - parameter_file: full path to elastix parameter file.
	// -output: Directory for output data.

	print("Aligning " + moving + " (moving image) with " + fixed + " (fixed image)");
	selectWindow(moving);
	run("32-bit");
	run("Divide...", "value=255");
	saveAs("tif", working_dir + moving);
	rename(moving);
	
	selectWindow(fixed);
	run("32-bit");
	run("Divide...", "value=255");
	saveAs("tif", working_dir + fixed);
	rename(fixed);

	// Call elastix
	exec(elastix_path    + " "+  
	"-f " +  working_dir + fixed  + ".tif "+
	"-m " +  working_dir + moving + ".tif "+
	"-out "+ output_dir      + " "+
	"-p " + parameter_file);

	// remove temporaries
	File.delete(working_dir + fixed  + ".h5 ");
	File.delete(working_dir + moving + ".h5 ");

	trafo_file = output_dir + "TransformParameters.0.txt";

	return trafo_file;
}

function Mask(Image, brightBG){
	// Takes an image
	// adjusts LUTs of every channel
	// Max intensity Z-projection of all slices
	// Thresholding
	// morphological post-processing

	/*
	if (File.exists(dir + Image + "_mask.tif")) {
		print("I found a mask you already made!");
		open(dir + Image + "_mask.tif");
		rename(Image + "_mask");
		return Image + "_mask";
	}

	*/
	erode_steps = 16;
	remainingMargin = 40;

	t0  = getTime();
	selectWindow(Image);
	run("Duplicate...", "title=Copy duplicate");
	selectWindow("Copy");

	// Adjust LUTs
	for (i = 1; i <= nSlices; i++) {
		setSlice(i);
		run("Enhance Contrast", "saturated=0.35");
		run("Apply LUT", "slice");
	}

	// check for background: brightfield images have bright background!
	if (brightBG == true) {
		run("Invert", "stack");	
	}
	// Collapse stack into single image
	run("Z Project...", "projection=[Max Intensity]");
	setColor(0, 0, 0);
	floodFill(0, 0);
	floodFill(0, getHeight()-1);
	floodFill(getWidth()-1, 0);
	floodFill(getWidth()-1, getHeight()-1);	
	run("Gaussian Blur...", "sigma=5");
	current = getTitle();
	close("Copy");
	
	// Threshold
	setAutoThreshold("Mean dark");
	run("Convert to Mask");
	
	// Morphologic processing: Fill
	for (i = 0; i < erode_steps; i++) {
		run("Dilate");
	}
	run("Fill Holes");
	for (i = 0; i < erode_steps; i++) {
		run("Erode");
	}
	checkMask(Image, current, brightBG);

	// Morphologic processing: Find largest particle
	dt = getTime() - t0;
	print("Normal mode needed " + dt + "ms.");
	roiManager("reset");
	run("Set Measurements...", "area display redirect=None decimal=2");
	run("Analyze Particles...", "add");
	size = 0;
	I = 0;
	
	for (i = 0; i < roiManager("count"); i++) {
		roiManager("select", i);
		roiManager("Measure");
		S = getResult("Area", nResults()-1);
		if ( S > size){
			size = S;
			I = i;
		}
	}

	// remove everything else
	roiManager("select", I);
	run("Clear Outside");
	roiManager("reset");

	rename(Image + "_mask");
	
	// Reduce margins
	selectWindow(Image + "_mask");
	getSelectionBounds(x, y, width, height);
	makeRectangle(	x-remainingMargin, 
					y-remainingMargin, 
					width + 2*remainingMargin, 
					height+ 2*remainingMargin);

	selectWindow(Image);
	run("Restore Selection");
	run("Crop");

	selectWindow(Image + "_mask");
	run("Crop");

	
	return Image + "_mask";
}

function adjustSizes(imageA, imageB) { 
	// Takes two images, compares the sizes and downsamples
	// the larger image so that it sizes matches the smaller image's size.
	// Assumes approximate square images.
	
	run("Set Scale...", "distance=0");
	
	selectWindow(imageA);
	width1  = getWidth();
	height1 = getHeight(); 
	
	selectWindow(imageB);
	width2  = getWidth();
	height2 = getHeight();

	print("Size Image A (" + imageA + "): " + width1*height1);
	print("Size Image B (" + imageB + "): " + width2*height2);
	
	// Compare the sizes
	if (width1 * height1 > width2 * height2) {

		f1 = sqrt((width2 * height2) / (width1 * height1));
		print("Reducing size of " + imageA + " by factor " + f1);
		downsample(imageA, f1);
		f2 = 1.0;

		/*
		Ext.CLIJ_push(imageA);
		Ext.CLIJ_downsample3D(imageA, imageA + "_small", f, f, 1.0);
		close(imageA);
		Ext.CLIJ_pull(imageA + "_small");
		selectWindow(imageA + "_small");
		rename(imageA);	
		*/
	
	} else {
		f2 = sqrt((width1 * height1)/(width2 * height2));
		print("Adjusting size of " + imageB + " by factor " + f2);
		downsample(imageB, f2);
		f1 = 1.0;
	}

	// return downsampling factors so that resolutions can be adjusted later
	f = newArray(2);
	f[0] = f1;
	f[1] = f2;

	return f;
	
}

function convert2h5(filename, path, RAMprotect) {
	// Check the properties of the image and turns the image into h5 (same path)

	f = 1.0; // default downsampling factor
	
	fname = File.getName(filename);
	fname = remove_endings( fname);

	print("Converting " + File.getName(filename) + " to .hdf5");
	run("Bio-Formats (Windowless)", "open="+filename);
	rename(fname);

	// this is only to account for the unnecessary channel from CRTD
	if (nSlices>3) {
		setSlice(1);
		run("Delete Slice", "delete=channel");

	}
	run("Make Composite", "display=Composite");

	getPixelSize(unit, pixelWidth, pixelHeight);
	

	if (RAMprotect) {
		width  = getWidth();
		height = getHeight();
		size = width * height;
		if(size > 1e8){
			f = sqrt(1e8/size);
			downsample(fname, f);
		}
	}
	
	run("Scriptable save HDF5 (new or replace)...", 
		"save="+path + fname + ".h5 dsetnametemplate=/t{t}/channel{c} formattime=%d formatchannel=%d compressionlevel=0");
	
	result = newArray(5);
	result[0] = getTitle();
	result[1] = f;
	result[2] = unit;
	result[3] = pixelWidth;
	return result;
}

function remove_endings(string){

	dot = indexOf(string, "."); 
	if (dot >= 0){
		string = substring(string, 0, dot); 
	}

	return string;
}

function removeMargin(image, margin){
	// removes a margin from the edge of the image to remove the stitching artifacts
	// that often occur when images are obtained with Zen software

	selectWindow(image);
	makeRectangle(	margin * getWidth(), 
					margin * getHeight(), 
					(1-2*margin)* getWidth(), 
					(1-2*margin)* getHeight());
	run("Crop");	
}

function downsample(image, f){
	selectWindow(image);
	width  = getWidth();
	height = getHeight();

	run("Scale...", "x="+f+" y="+f+" z=1.0 width="+f*width+" height="+f*height+" depth="+nSlices+" interpolation=Bilinear average create");
	result = getTitle();

	close(image);
	selectWindow(result);
	rename(image);

	
	
}


