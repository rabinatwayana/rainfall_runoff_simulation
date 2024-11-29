/**
* Name: RainfallRunoffModel
* Based on the internal empty template. 
* Author: rabinatwayana
* Tags: 

* Resources: 
* https://gama-platform.org/wiki/CodeExamples
* 
* ASCII File to DEM Representation, 3 experiments, 3D
* https://gama-platform.org/wiki/ASCII_File_to_DEM_Representation //NOT USED, MOVED TO FIELDS
*
* TOOL: Raster>conversion>translate to export .tif to .asc
* 
* Fields: Library models> GAMA Syntax> Data Types and Structure > Fields.gaml
* Brewer Color: https://colorbrewer2.org/#type=sequential&scheme=YlGn&n=3 
*
*
*/
model RainfallRunoffModel

global{

	// supposed to be used RGB Image, but not satisfied result, thus using DEM for now
	// due to the 0 value in sundarijal_DEM.tif, it could not be used
	field field_display <- field(grid_file("../includes/sundarijal_DEM_by_extent.tif"));
	//	field field_display <- field(grid_file("../includes/rgbImage.tif"));
	field var_field <- copy(field_display) - mean(field_display);
}

species declaring_field {

/*
	 * Declaration of a field
	 */
	//	field field_from_grid <- field(matrix(cell));
	// Initialize a field from a asc simple raster file
	//	field field_from_asc <- field(grid_file("../includes/sundarijal_DEM_by_extent.asc"));
	
	// initialize using a tiff raster file
	field field_from_tiff <- field(grid_file("../includes/sundarijal_DEM_by_extent.tif"));
	//	field field_from_tiff  <-  field(grid_file("../includes/Lesponne.tif"));

	//	// Init from a user defined matrix
	//	field field_from_matrix <- field(matrix([[1, 2, 3], [4, 5, 6], [7, 8, 9]]));
	//	//  init an empty field of a given size
	//	field empty_field_from_size <- field(10, 10);
	//	// init a field for of a given value
	//	field full_field_from_size <- field(10, 10, 1.0);
	//	// init a field of given size, with a given value and no data
	//	field full_field_from_size_with_nodata <- field(1, 1, 1.0, 0.0);
	init {
		write "";
		write "== DECLARING FIELD ==";
		write "";
		//		write sample(field_from_grid);
		//		write sample(field_from_asc);
		write sample(field_from_tiff);
		//		write sample(field_from_matrix);
		//		write sample(empty_field_from_size);
		//		write sample(full_field_from_size);
		//		write sample(full_field_from_size_with_nodata);
		//		write "";
	}

}

species manipulating_field {

	init {
		write "";
		write "== MANIPULATING FIELD ==";
		write "";
		// max-minimum value of the field
		write sample(max(field_display));
		write sample(min(field_display));
		write sample(mean(field_display));

		// accessing bands of the field 
		//		write sample(field_display.bands[1]);
		//		write sample(field_display.bands[2]);
		//		write sample(field_display.bands[3]);
		write "";
	}

}

//Grid that will be saved in the ASC File
grid cell width: 100 height: 100 {
	float grid_value <- rnd(1.0, self distance_to world.location);
	rgb color <- rgb(255 * (1 - grid_value / 100), 0, 0);
}

//experiment Fields type: gui {
//	user_command "Declaring field" {create declaring_field;}	
//	user_command "Manipulating field" {create manipulating_field;}	
//}
experiment rainfall_runoff_view type: gui {
	output {
		layout #split;
		display "field through mesh in brewer colors" type: 3d {
			mesh field_display color: (brewer_colors("YlGn")) scale: 0.05 triangulation: true smooth: true refresh: false;
		}

		display "field through mesh in grey scale" type: 3d {
			mesh field_display grayscale: true scale: 0.05 triangulation: true smooth: true refresh: false;
		}

		// 		Not working
		//		display "rgb field through mesh" type: 3d {
		//			mesh field_display color: field_display.bands scale: 0.1 triangulation: true smooth: 4 refresh: false;
		//		}

		//		output is not satisfied
		//		display "rnd field with palette mesh" type: 3d {
		//			mesh field_display.bands[2] color: scale([#red::100, #yellow::115, #green::101, #darkgreen::105]) scale: 0.2 refresh: false;
		//		}
		display "var field" type: 3d {
			mesh var_field color: (brewer_colors("RdBu")) scale: 0.0;
		}

	}

}
