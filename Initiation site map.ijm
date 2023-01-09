image=getTitle();
setBatchMode(true);
Stack.getDimensions(image_width, image_height, dummy, slices, dummy);
getVoxelSize(voxel_width, voxel_height, depth, unit);
newImage("Initiation", "32-bit black", image_width, image_height, 1);
for(row=0; row<nResults; row++){
	if(row%20 == 0) showProgress(row, nResults);
	x = getResult("wave x start", row);
	y = getResult("wave y start", row);
	x /= voxel_width;
	y /= voxel_height;
	duration = getResult("integrated area", row);
	selectWindow("Initiation");
	setPixel(x, y, duration);
}

setBatchMode("exit and display");