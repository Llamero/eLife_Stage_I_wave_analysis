min_integrated_wave = 10; //minimum wave area * duration
min_duration = 3; //Minimum number of slices a wave had to be present
close("*");
setBatchMode(true);
run("Bio-Formats Macro Extensions");

dir = getDirectory("Choose the root directory to process");
out_dir = dir;
count = 0;
countFiles(dir, out_dir);
print(count);
n = 0;
processFiles(dir, out_dir);

function countFiles(dir, out_dir) {
  list = getFileList(dir);
  File.makeDirectory(out_dir);
  for (i=0; i<list.length; i++) {
      if (endsWith(list[i], "/"))
      	countFiles(""+dir+list[i], ""+out_dir+list[i]);
      else if(startsWith(list[i], "watershed low - ")){
  		count++;
      } 	
  }
}

function processFiles(dir, out_dir) {
    file_list = getFileList(dir);
	for (i=0; i<file_list.length; i++) {
	  if(endsWith(file_list[i], "/"))
	      processFiles(""+dir+file_list[i], ""+out_dir+file_list[i]);
	  else if(startsWith(file_list[i], "histogram low -") && endsWith(file_list[i], "tif")){
  		//Open full length movie as one stack
		print("---------------------------------------");
		n++;
		print("Processing file " + n + " of " + count);
	  	close("*");
	  	run("Collect Garbage");
	  	print(dir);
	  	file_prefix = replace(file_list[i], "histogram low -", "");
	  	file_prefix = replace(file_prefix, ".tif$", "");
	  	printUpdate("Prefix: " + file_prefix);
	  	print(dir + "dF stack - " + file_prefix + ".tif");
	  	if(File.exists(dir + "segmented time points.csv")){
			processFile(file_prefix, out_dir);
	  	}
	  }       
  }
}

function processFile(file_prefix, out_dir) {
	open(dir + "histogram low -" + file_prefix + ".tif");
	rename("histogram");
	Ext.setId(dir + "dF stack - " + file_prefix + ".tif");
	
	//Bin histogram to get integrated area of each wave
	selectWindow("histogram");
	Stack.getDimensions(width, height, channels, slices, frames);
	run("Z Project...", "projection=[Sum Slices]");
	selectWindow("SUM_histogram");
	run("Bin...", "x=1 y=" + height + " bin=Sum");
	newImage("Wave speed histogram", "32-bit black", width+1, 256, 1);
	run("Bio-Formats Importer", "open=[" + dir + "watershed low - " + file_prefix + ".tif] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	//Find largest wave by area
	id = 1;
	max_id = 0;
	prev_max = 1e30;
	for(id=1; id<=width; id++){
		selectWindow("SUM_histogram");
		integrated_wave = getPixel(id, 0);
		if(integrated_wave >= min_integrated_wave){
			//Find start and end slide of wave
			selectWindow("histogram");
			start_slice = -1;
			end_slice = -1;
			for(slice=1; slice<=slices; slice++){
				setSlice(slice);
				for(y=0; y<height; y++){
					value = getPixel(id, y);
					if(value > 0){
						if(start_slice < 1) start_slice = (slice-1)*height + y + 1;
					}
					else if(start_slice > 0 && end_slice < 1){
						end_slice = (slice-1)*height + y;
						break;
					}
				}
				if(start_slice > 0 && end_slice > 1) break;
			}
			if(end_slice-start_slice >= min_duration){
				showProgress(id, width);
				//load wave substack
				selectWindow("watershed low - " + file_prefix + ".tif");
				run("Duplicate...", "title=[mask] duplicate range=" + start_slice + "-" + end_slice);
				selectWindow("mask");
				run("Macro...", "code=[if(v==" + id + ") v=1; else v=0;] stack");
				setMinAndMax(0, 1);
				run("8-bit");
				run("Duplicate...", "title=edge duplicate");
				selectWindow("edge");
				run("Find Edges", "stack");
				run("Skeletonize", "stack");
				setSlice(1);
				run("Delete Slice");
				run("Divide...", "value=255 stack");
				selectWindow("mask");
				run("Duplicate...", "title=edt duplicate");
				selectWindow("edt");
				run("Invert", "stack");
				run("Distance Map", "stack");
				setSlice(nSlices);
				run("Delete Slice");
				imageCalculator("Multiply stack", "edge","edt");
				close("edt");
				stack_histogram = stackHisto("edge");
				stack_histogram[0] = 0; //Do not count 0 pixels
				selectWindow("Wave speed histogram");
				Array.getStatistics(stack_histogram, dummy, dummy, mean, dummy);
				for(bin=0; bin<256; bin++) setPixel(id, bin, stack_histogram[bin]/(mean*256));
				
				close("edge");
				close("mask");
			}
		}
	}
	selectWindow("Wave speed histogram");
	saveAs("tiff", out_dir + "Wave speed histogram - " + file_prefix + ".tif");
}
function stackHisto(image){
	selectWindow(image);
	stack_histogram = newArray(256);
	for (j=1; j<=nSlices; j++){
	    setSlice(j);
	    getHistogram(values, counts, 256);
	    for (i=0; i<256; i++)
	       stack_histogram[i] += counts[i];
	}
	return stack_histogram;
}

function printUpdate(message){ //https://imagej.nih.gov/ij/macros/GetDateAndTime.txt
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
	print(TimeString +  " - " + message);
}

setBatchMode("exit and display");

