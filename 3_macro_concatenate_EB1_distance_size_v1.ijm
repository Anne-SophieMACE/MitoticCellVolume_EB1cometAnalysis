/******* macro macro_concactenate_EB1_distance_size_v1.ijm
adapted from merge_CSV_files_v1

concatenates results (lengths/distances to pole) obtained by macro 
quantif_cometes_EB1_vf

- by AS MACE, Adpatation 10/23, tested on Fiji 1.54f Windows
*/

run("Close All");
run("Clear Results");
print("\\Clear");

// aks the folder to the user and lists its content
dir_img = getDirectory("Choose your directory to treat (with merged images)");
filelist = getFileList(dir_img);


// asks the user the ending to consider
Dialog.create("Concatenation Results from ImageJ");
Dialog.addMessage("This macro enables to concatenate files saved BY ImageJ by macro quantif_cometes_EB1_v*)");
Dialog.addChoice("Files:", newArray("Only distance to pole (all comets)","Distance and size (measurable comets)"));
Dialog.show();
label_find = Dialog.getChoice();

// endsWith(filelist[i], ".xls") && indexOf(filelist[i],"_distancePole_") != -1 && indexOf(filelist[i],"_AllComets_") != -1
// size_comets
if(label_find == "Only distance to pole (all comets)" ){
	specific_end = "_AllComets_";
	save_name = "distancePole_AllImages.xls";
}
else {
	specific_end = "_size_comets";
	save_name = "distancePoleSizeComets_AllImages.xls";
}

fileToConcat = newArray(lengthOf(filelist));
indexFileToConcat = 0;

for (i_file = 0; i_file < lengthOf(filelist); i_file++) {
	if ( endsWith(filelist[i_file],".xls") &&  indexOf(filelist[i_file],"_distancePole_")!=-1 && indexOf(filelist[i_file],specific_end) !=-1 ) { // keeps only files with correct suffix
		fileToConcat[indexFileToConcat] = dir_img+filelist[i_file];
		indexFileToConcat++;
	}
}


if( indexFileToConcat > 0 ){
	setResult("Label",0,""); // so that a column label does exist
	IJ.renameResults("Results","results_tmp");
	
	for (i_file = 0; i_file < indexFileToConcat; i_file++) { // other files: to concatenate
		run("Results... ","open=["+fileToConcat[i_file]+"]");
		pole_number = parseInt(substring(fileToConcat[i_file],indexOf(fileToConcat[i_file],"Pole_p")+lengthOf("Pole_p"),lastIndexOf(fileToConcat[i_file],specific_end)));
		print("Reading "+fileToConcat[i_file]);
		IJ.renameResults("Results");
		colNames = returnColumnNames(1);
		nbLines = nResults;
		tabRes = newArray(lengthOf(colNames)*nbLines);
		indexAllRes = 0;
	
		// reads all Results
		for (i_res = 0; i_res < nbLines; i_res++) {
			for( i_col = 0; i_col < lengthOf(colNames); i_col ++ ){
				tabRes[indexAllRes] = getResultString(colNames[i_col], i_res);
				indexAllRes++;
			}
		}
	
		// add them to the Result table
		IJ.renameResults("results_tmp","Results");
		indexRes = nResults;
		indexAllRes = 0;
		for (i_res = 0; i_res < nbLines; i_res++) {
			for( i_col = 0; i_col < lengthOf(colNames); i_col ++ ){
				setResult(colNames[i_col], indexRes+i_res, tabRes[indexAllRes]);
				indexAllRes++;
			}
		}
		addImageInLabelName(indexRes,nResults,substring(fileToConcat[i_file],lastIndexOf(fileToConcat[0],File.separator)+1,lastIndexOf(fileToConcat[i_file],"_distancePole"))+"_pole"+pole_number);
		updateResults();
		IJ.renameResults("Results","results_tmp");
	}
	IJ.renameResults("results_tmp","Results");
}
// saves the final table
updateResults();
Table.deleteRows(0, 0);
saveAs("Results",dir_img+"AllResults_"+save_name);

// returns all column names
function returnColumnNames(colBeg){
	selectWindow("Results");
	text = getInfo();
	lines = split(text, "\n");
	columns = split(lines[0], "\t");
	return Array.slice(columns,colBeg,lengthOf(columns));
}

// adds the name of the image as "Label"; if already a label, adds it to the image name
function addImageInLabelName(ind_beg,ind_end,img_name){
	for( i_res = ind_beg; i_res < ind_end; i_res++)
	setResult("Label",i_res,img_name);
}