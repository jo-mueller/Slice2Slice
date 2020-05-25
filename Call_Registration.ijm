// Calls registration script in a loop for a number of directories.

root 		= "E:/Dokumente/Promotion/NCRO/";
script_dir 	= root + "3_HistoReg/Scripts/";
data_dir 	= root + "Histologie/N182/";

reg_file 	= script_dir +  "Registration.ijm";

dirlist = getFileList(data_dir);
for (i = 0; i < dirlist.length; i++) {

	// skip archive
	if (startsWith(dirlist[i], "_")) {
		continue;
	}

	// define default state
	filename_HE = "";
	filename_FL = "";
	
	// browse files in data directory
	filelist = getFileList(data_dir + dirlist[i]);
	for (j = 0; j < filelist.length; j++) {

		//skip all directories
		if (File.isDirectory(root + dirlist[i] + "/" + filelist[j])) {
			continue;
		}

		// skip non-image files
		if (endsWith(filelist[j], ".tif") || endsWith(filelist[j], ".czi")) {
			// find HE image
			if (matches(filelist[j], ".*HE.*")) {
				filename_HE = filelist[j];
				continue;
			}
			filename_FL = filelist[j];
		}
	}

	// gatekeeper for further script
	if (filename_HE == "" || filename_FL == "") {
		continue;
	}

	runMacro(reg_file, 	" -" + data_dir + dirlist[i] +
						" -" + filename_HE + 
						" -" + filename_FL +
						" -" + script_dir);
}
