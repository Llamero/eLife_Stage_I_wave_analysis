file_suffix = "_?[0-9]*\\.ome-?[0-9]*.tif$"; //Regex pattern for file suffixes
min_pixel_area = 120000; //minimum area of retina
max_pixel_area = 210000; //maximum area of retina
area_step_factor = 0.9; //scale to step threshold by
mask_smooth_median = 5; //Factor by which to smooth mask
close("*");
setBatchMode(true);

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
      else if(startsWith(list[i], "dF stack - ")){
  		count++;
      } 	
  }
}

function processFiles(dir, out_dir) {
  file_list = getFileList(dir);
  for (i=0; i<file_list.length; i++) {
      if(endsWith(file_list[i], "/"))
          processFiles(""+dir+file_list[i], ""+out_dir+file_list[i]);
      else if(startsWith(file_list[i], "dF stack - ") && endsWith(file_list[i], "tif")){
      	close("*");
      	run("Collect Garbage");
      	//Open full length movie as one stack
      	print("---------------------------------------");
      	n++;
      	print("Processing file " + n + " of " + count);
      	print(dir);
      	file_prefix = replace(file_list[i], "dF stack - ", "");
      	file_prefix = replace(file_prefix, ".tif$", "");
      	printUpdate("Prefix: " + file_prefix);
      	watershed_file_list = getFileList(out_dir);
      	for(a=0; a<watershed_file_list.length; a++){
      		if(matches(watershed_file_list[a], "retina mask [0-9 ]*- " + file_prefix + ".tif")){
      			print("Skipped " + file_list[i] + " - already processed.");
      			break;
      		}
      	}
      	if(a>=watershed_file_list.length){
			open(dir + file_list[i]);
			rename("dF");
			processFile(file_prefix, out_dir);
      	}
      }        
  }
}

function processFile(file_prefix, out_dir) {
	area_step_factor = area_step_factor;
	if(isOpen("Results")){
		selectWindow("Results");
		run("Close");
	}
	selectWindow("dF");
	run("Z Project...", "projection=[Standard Deviation]");
	selectWindow("STD_dF");
	setVoxelSize(1, 1, 1, "px");
	getDimensions(width, height, channels, slices, frames);
	setAutoThreshold("Triangle dark");
	getThreshold(lower, upper);
	sign_switch_counter = 0;
	sign = 0;
	run("Set Measurements...", "area center redirect=None decimal=3");
	for(a=0; a<100; a++){
		selectWindow("STD_dF");
		run("Duplicate...", "title=mask");
		selectWindow("mask");
		setThreshold(lower, upper);
		run("Convert to Mask");
		run("Fill Holes");
		run("Median...", "radius=" + mask_smooth_median);
		run("Analyze Particles...", "size=" + min_pixel_area + "-Infinity pixel show=Masks display clear");
		close("mask");
		selectWindow("Mask of mask");
		if(nResults >= 1){
			area = getResult("Area", 0);
			cx = getResult("XM");
			cy = getResult("YM");
			if(sign < 0) sign_switch_counter++;
			sign=1;
			if(area > max_pixel_area) lower /= area_step_factor;
			else break;
		}
		else{
			if(sign > 0) sign_switch_counter++;
			sign = -1;
			lower *= area_step_factor;
		}
		if(sign_switch_counter > 1){ //Stop loop from oscillating across threshold value
			sign_switch_counter = 0;
			area_step_factor += ((1-area_step_factor)/2);
		}
		close("Mask of mask");
	}
	print("Area = " + area);
	if(a>=100) print("Error: " + file_prefix + " did not have a suitable threshold.");
	else{
		print("Threshold = " + lower + ".  " + a + " steps to find threshold.");
		selectWindow("Mask of mask");
		run("Invert");
		close("\\Others");
		saveAs("tiff", out_dir + "retina mask 2 - " + file_prefix + ".tif");
		printUpdate("retina mask saved");
	}
	close("*");
	wait(5000);
	run("Collect Garbage");
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

