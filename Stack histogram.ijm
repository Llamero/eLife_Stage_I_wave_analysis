requires("1.34m");
//if(bitDepth == 32){
//	setMinAndMax(0, 65535);
//	run("16-bit");
//}
image=getTitle();
setBatchMode(true);
setBatchMode("hide");
Stack.getStatistics(dummy, dummy, dummy, max, dummy);
Stack.getDimensions(dummy, dummy, dummy, slices, dummy);
run("Set Measurements...", "area modal centroid center perimeter fit redirect=None decimal=3");
results_label_array = newArray("wave area", "wave major", "wave minor", "wave x", "wave y");
//start_label_array = newArray("wave start area", "wave start major" , "wave start minor", "wave start slice", "wave x start", "wave y start");
//end_label_array = newArray("wave end area", "wave end major" , "wave end minor", "wave end slice", "total wave duration", "wave x end", "wave y end");
//int_label_array = newArray("integrated wave area");
newImage("Results Stack", "32-bit black", max, slices, results_label_array.length);
selectWindow("Results Stack");
for(slice=1; slice<=results_label_array.length; slice++){
	setSlice(slice);
	setMetadata("Label", results_label_array[slice-1]);
}
//newImage("Summary", "32-bit black", max, 1, summary_label_array.length);
//selectWindow("Summary");
//for(slice=1; slice<=summary_label_array.length; slice++){
//	setSlice(slice);
//	setMetadata("Label", summary_label_array[slice-1]);
//}
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

		selectWindow("Results Stack");
		for(result_slice=1; result_slice<=results_label_array.length; result_slice++){
			setSlice(result_slice);
			if(matches(getMetadata("Label"), ".* area")) setPixel(ID-1, slice-1, area);
			else if(matches(getMetadata("Label"), ".* major")) setPixel(ID-1, slice-1, major);
			else if(matches(getMetadata("Label"), ".* minor")) setPixel(ID-1, slice-1, minor);
			else if(matches(getMetadata("Label"), ".* x")) setPixel(ID-1, slice-1, x);
			else if(matches(getMetadata("Label"), ".* y")) setPixel(ID-1, slice-1, y);
		}
	}
}

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
			wave_ended = true;	
		}
		if(wave_ended && area>0){ //Check to ensure all waves are unique
			setResult("Error", ID, "Two waves have the same ID!");
		}
		int_area += area;
	}
}


//summary_label_array = newArray("wave start area", "wave end area", "integrated wave area", "wave start major" , "wave start minor", "wave end major", "wave end minor",
//						 "wave start slice", "wave end slice", "total wave duration", "wave x start", "wave y start","wave x end", "wave y end");
setBatchMode("exit and display");