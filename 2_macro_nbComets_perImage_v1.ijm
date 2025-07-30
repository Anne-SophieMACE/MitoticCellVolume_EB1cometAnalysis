/******* macro_nbComets_perImage_v1 
 *  macro to launch after quantif_comets_EB1_v*
 *  it counts for all treated image the number of comets 
 *  (ALL comets file read) 
 */

// user chooses the directory
directory = getDirectory("Choose your directory to merge results (should have been treated with macro quantif_comets_EB1)");
filelist = getFileList(directory); // all content
tab_nbComets = newArray(); // table to contain number of comets
tab_nameImages = newArray(); // table to contain name + pole number
indexTab = 0; // index of the table -> "exapandable array"

for (i = 0; i < lengthOf(filelist); i++) {
    if (endsWith(filelist[i], ".xls") && indexOf(filelist[i],"_distancePole_") != -1 && indexOf(filelist[i],"_AllComets_") != -1  ) { 
        run("Results... ","open=["+directory + File.separator + filelist[i]+"]"); // open as Results
        name_noExt = substring(filelist[i],0,lastIndexOf(filelist[i],"_distancePole")); // name of the image
        pole_number = parseInt(substring(filelist[i],indexOf(filelist[i],"Pole_p")+lengthOf("Pole_p"),lastIndexOf(filelist[i],"_AllComets")));
        tab_nameImages[indexTab] = name_noExt+"_pole"+pole_number;
        tab_nbComets[indexTab] = nResults;
        indexTab++;
    } 
}

// result table to save
run("Clear Results");
for (i = 0; i < indexTab; i++) {
	setResult("Image Name", i, tab_nameImages[i]);
	setResult("Number of comets", i, tab_nbComets[i]);
}

saveAs("Results",directory+"numberComets_allImages.xls");