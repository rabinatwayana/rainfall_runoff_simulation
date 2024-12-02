model RainfallRunoffModel

global{

	// supposed to be used RGB Image, but not satisfied result, thus using DEM for now
	// due to the 0 value in sundarijal_DEM.tif, it could not be used
	field field_display <- field(grid_file("../includes/sundarijal_DEM_by_extent.tif"));
	
	//	field field_display <- field(grid_file("../includes/rgbImage.tif"));
	field var_field <- copy(field_display) - mean(field_display);
	
	
//	Define Envelope that matches the DEM coordinates
//	geometry var3 <- polygon([{0,0}, {100,0}, {0,100}, {100,100}]); // for general test. this is how envelope polygon looks like
//	Since we are adding bigger value of envelope ie. bbox, we need more exageration in scale while displaying. ie. scale <- 3 looks good. 
	float xmin <- 931885.867800-1;
//	float xmin <- 0.0;
	float xmax <- 941275.867800+1;
	float ymin <- 3077102.604300-1;
//	float ymin <- 0.0;
	float ymax <- 3085262.604300+1;

	geometry ev <- polygon([{xmin, ymin}, {xmax, ymin}, {xmin, ymax}, {xmax, ymax}]);
	geometry shape <- envelope(ev);
	
	
//	load watershed boundary
//	file watershed_bdry_file <- shape_file("../includes/watershed_bdry/watershed_polygon.shp");
	file watershed_bdry_file <- file("../includes/watershed_bdry/watershed_polygon.geojson");
	geometry watershed_bdry_polygon <- geometry(watershed_bdry_file);
	
//	load water level station
	geometry water_level_point <- point([{85.42,27.76}]);
	
	init{
		create watershed_bdry_agent from: geometry(watershed_bdry_polygon);
		
		create water_level_agent from: water_level_point;
	}
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

species watershed_bdry_agent {
	
	aspect default{
     	draw watershed_bdry_polygon color:#transparent border: #black; 
     }
}

species water_level_agent {
	
	aspect default{
     	draw water_level_point color:#transparent border: #black; 
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
			mesh field_display color: (brewer_colors("YlGn")) scale: 3 triangulation: true smooth: true refresh: false;
			species watershed_bdry_agent aspect:default transparency: 0.5;
			species water_level_agent aspect:default transparency: 0.5;
			
		}

		display "field through mesh in grey scale" type: 3d {
			mesh field_display grayscale: true scale: 0.03 triangulation: true smooth: true refresh: false;
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
			mesh var_field color: (brewer_colors("RdBu")) scale: 0.03;
		}

	}

}
