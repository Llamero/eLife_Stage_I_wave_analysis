requires("1.34m");
//if(bitDepth == 32){
//	setMinAndMax(0, 65535);
//	run("16-bit");
//}
close("\\Others");
image=getTitle();
setBatchMode(true);
setBatchMode("hide");
Stack.getStatistics(dummy, dummy, dummy, max, dummy);
Stack.getDimensions(image_width, image_height, dummy, slices, dummy);
run("Set Measurements...", "area modal centroid center perimeter bounding fit redirect=None decimal=3");
results_label_array = newArray("wave area", "wave x", "wave y", "wave major", "wave minor", "ellipse area", "wave width", "wave height", "box area");
newImage("Results Stack", "32-bit black", max, slices, results_label_array.length);
selectWindow("Results Stack");
for(slice=1; slice<=results_label_array.length; slice++){
	setSlice(slice);
	setMetadata("Label", results_label_array[slice-1]);
}
measureWaves();
summaryStatistics();
setBatchMode("exit and display");

function measureWaves(){
	for (slice=1; slice<=slices; slice++) {
		showProgress(slice, slices);
		selectWindow(image);
		setSlice(slice);
		setThreshold(1, max);
		run("Analyze Particles...", "clear slice");
		for(row=0; row<nResults; row++){
			area = getResult("Area", row);
			ID = getResult("Mode", row);
			x = getResult("X", row);
			y = getResult("Y", row);
			major = getResult("Major", row);
			minor = getResult("Minor", row);
			ellipse_area = PI*major*minor;
			width = getResult("Width", row);
			height = getResult("Height", row);
			box_area = width*height;
	
	
			selectWindow("Results Stack");
			for(result_slice=1; result_slice<=results_label_array.length; result_slice++){
				setSlice(result_slice);
				if(matches(getMetadata("Label"), ".*wave area")) setPixel(ID-1, slice-1, area);
				else if(matches(getMetadata("Label"), ".*wave x")) setPixel(ID-1, slice-1, x);
				else if(matches(getMetadata("Label"), ".*wave y")) setPixel(ID-1, slice-1, y);
				else if(matches(getMetadata("Label"), ".*wave major")) setPixel(ID-1, slice-1, major);
				else if(matches(getMetadata("Label"), ".*wave minor")) setPixel(ID-1, slice-1, minor);
				else if(matches(getMetadata("Label"), ".*ellipse area")) setPixel(ID-1, slice-1, ellipse_area);
				else if(matches(getMetadata("Label"), ".*wave width")) setPixel(ID-1, slice-1, width);
				else if(matches(getMetadata("Label"), ".*wave height")) setPixel(ID-1, slice-1, height);
				else if(matches(getMetadata("Label"), ".*box area")) setPixel(ID-1, slice-1, box_area);
			}
		}
	}
}

function summaryStatistics(){
	selectWindow("Results Stack");
	//Initialize results table
	updateResults();
	selectWindow("Results");
	run("Close");
	selectWindow("Results Stack");
	for(ID=0; ID<max; ID++){
		showProgress(ID, max);
		updateResults();
		area_slice = -1;
		for(result_slice=1; result_slice<=results_label_array.length; result_slice++){ //Find the area slice
			setSlice(result_slice);
			if(matches(getMetadata("Label"), ".* area")){
				area_slice = result_slice;
				break;
			}
		}
		int_area = 0;
		max_area = -1;
		max_ellipse = -1;
		max_ellipse_slice = -1;
		max_box = -1;
		max_box_slice = -1;
		wave_ended = false;
		for(y=0; y<slices; y++){
			setSlice(area_slice);
			area = getPixel(ID, y);
			if(area > 0 && int_area == 0){ //If start of wave
				for(result_slice=1; result_slice<=results_label_array.length; result_slice++){
					selectWindow("Results Stack");
					setSlice(result_slice);
					value = getPixel(ID, y);
					metadata = getMetadata("Label");
					column = metadata + " start";
					setResult(column, ID, value);
				}
				setResult("start slice", ID, y+1);
			}
			else if(area == 0 && int_area > 0 && !wave_ended){ //if end of wave
				for(result_slice=1; result_slice<=results_label_array.length; result_slice++){
					selectWindow("Results Stack");
					setSlice(result_slice);
					value = getPixel(ID, y-1);
					metadata = getMetadata("Label");
					column = metadata + " end";
					setResult(column, ID, value);
				}
				setResult("end slice", ID, y);
				start_slice = getResult("start slice", ID);
				duration = y-start_slice+1;
				setResult("wave duration", ID, duration);
				setResult("integrated area", ID, int_area);
				setResult("max ellipse area", ID, max_ellipse);
				setResult("max ellipse slice", ID, max_ellipse_slice);
				setResult("max box area", ID, max_box);
				setResult("max box slice", ID, max_box_slice);
				
				wave_ended = true;	
			}
			if(wave_ended && area>0){ //Check to ensure all waves are unique
				setResult("Error", ID, "Two waves have the same ID!");
			}
			if(area > 0){
				for(result_slice=1; result_slice<=results_label_array.length; result_slice++){
					setSlice(result_slice);
					value = getPixel(ID, y);
					if(matches(getMetadata("Label"), ".*wave area") && value > max_area) max_area = value;
					else if(matches(getMetadata("Label"), ".*ellipse area") && value > max_ellipse){
						max_ellipse = value;
						max_ellipse_slice = y+1;
					}
					else if(matches(getMetadata("Label"), ".*box area") && value > max_box){
						max_box = value;
						max_box_slice = y+1;
					}
				}
			}
			int_area += area;
		}
	}
}


//summary_label_array = newArray("wave start area", "wave end area", "integrated wave area", "wave start major" , "wave start minor", "wave end major", "wave end minor",
//						 "wave start slice", "wave end slice", "total wave duration", "wave x start", "wave y start","wave x end", "wave y end");
