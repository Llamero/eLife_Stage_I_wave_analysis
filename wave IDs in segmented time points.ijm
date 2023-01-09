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
	if(isOpen("segmented time points.csv")){
		selectWindow("segmented time points.csv");
		run("Close");
	}
	open(dir + "segmented time points.csv");
	start_slice = getResult("startSlice", 0);
	end_slice = getResult("endSlice", 0);
	run("Bio-Formats Importer", "open=[" + dir + "watershed low - " + file_prefix + ".tif] autoscale color_mode=Default rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT z_begin=" + start_slice + " z_end=" + end_slice + " z_step=1");
	
	open(dir + "Wave speed histogram - " + file_prefix + ".tif");
	selectWindow("Wave speed histogram - " + file_prefix + ".tif");
	getDimensions(n_IDs, dummy, dummy, dummy, dummy);
	segmented_IDs = newArray(n_IDs+1);
	transition_IDs = newArray(n_IDs+1);
	close("Wave speed histogram - " + file_prefix + ".tif");
	newImage("Segmented Time ID mask", "8-bit black", n_IDs, 1, 2);
	selectWindow("Segmented Time ID mask");
	setSlice(1);
	setMetadata("Label", "Including IDs spanning end of time window");
	setSlice(2);
	setMetadata("Label", "Excluding IDs spanning end of time window");
	selectWindow("watershed low - " + file_prefix + ".tif");
	for (slice=start_slice; slice<end_slice; slice++) {
	  setSlice(slice);
	  getHistogram(values,counts,n_IDs+1,0,n_IDs+1);
	  for (i=0; i<=n_IDs; i++) {
		if(counts[i] > 0) segmented_IDs[i] = 1; 
	  }
	}
	setSlice(end_slice);
  	getHistogram(values,counts,n_IDs+1,0,n_IDs+1);
	for (i=0; i<n_IDs+1; i++) {
		if(counts[i] > 0){
			segmented_IDs[i] = 1;
			transition_IDs[i] = 1; 
		}
	}
	selectWindow("Segmented Time ID mask");
	setSlice(1);
	for (i=0; i<n_IDs+1; i++) if(segmented_IDs[i] > 0) setPixel(i,0,1);
	setSlice(2);
	for (i=0; i<n_IDs+1; i++) if(segmented_IDs[i] > 0 && transition_IDs[i] == 0) setPixel(i,0,1);	
	saveAs("tiff", dir + "Segmented Time ID mask - " +file_prefix + ".tif");
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

