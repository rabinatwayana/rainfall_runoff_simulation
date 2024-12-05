model RainfallRunoffModel

global {
	myCA centreCell;
	// supposed to be used RGB Image, but not satisfied result, thus using DEM for now
	// due to the 0 value in sundarijal_DEM.tif, it could not be used
	field field_display <- field(grid_file("../includes/sundarijal_DEM_by_extent.tif"));

	//	field field_display <- field(grid_file("../includes/rgbImage.tif"));
	field var_field <- copy(field_display) - mean(field_display);
	file raster_file <- file("../includes/sundarijal_DEM_by_extent.asc");
	geometry shape <- envelope(raster_file);

	init {
		create rainfall_station number: 1 {
			location <- point(to_GAMA_CRS({936580.8678, 3081182.6043, 5800}, "EPSG:32644"));
		}
//		write "Grid bounds shape: " + shape; // POLYGON ((0 8160, 9390 8160, 9390 0, 0 0, 0 8160))
//		write "Grid bouunds rasterfile: " + envelope(raster_file);
//		write "Grid bouunds myCA: " + envelope(myCA);
		centreCell <- myCA[75, 85];

		// set the water column at the first time step
		ask centreCell {
			water_level <- 200.0 #mm;
		}

		ask myCA {
		// assign grey color shades for the DEM
			color <- rgb([int((grid_value - 230) * 8), int((grid_value - 230) * 8), int((grid_value - 230) * 8)]);
		}

	}

	reflex deliver_water {
		ask centreCell {
			water_level <- water_level + 100 #mm;
		}

		write "update";
	}

}

species rainfall_station {

	aspect default {
		draw circle(100) color: #brown;
	}

}

grid myCA file: raster_file {
	float water_level;
	//240 is just to avoid the jump from zero at the first time step.
	float water_elev <- 240.0;

	reflex run_off when: water_level >= 100.0 #mm {
	//take the neighbour with the lowest elevation
		ask neighbors with_min_of (grid_value + water_level) {
		//if the elevation + water column of the sending cell is higher than the neighbour
			if (myself.grid_value + myself.water_level) > (grid_value + water_level) {
			//give all the water to the neighbour
				water_level <- water_level + 100.0 #mm;
				//write the elevation for this water cell into a variable (needed for the chart)
				water_elev <- grid_value;
				//subtract the water from myself
				myself.water_level <- myself.water_level - 100 #mm;
			}

		}

		do update_colour;
	}

	// show grid values in shades of grey and the water in blue
	action update_colour {
	// recolour DEM, if there is no water; only for blue cells to avoid pointless recolouring of all cells at every time step
		if (water_level <= 0 and color = #blue) {
		// DEM colour
			color <- rgb([int((grid_value - 230) * 8), int((grid_value - 230) * 8), int((grid_value - 230) * 8)]);
		} else {
		// water colour
		//color <- rgb(0,0,int(water_level*255));
			color <- #blue;
		}

	}

}

experiment rainfall_runoff_view type: gui {
	output {
		layout #split;
		//			display map {
		//			species rainfall_station aspect: default;
		//		}
		display "field through mesh in brewer colors" type: 3d {

		//			species PointMarker aspect: sphere;
			species rainfall_station aspect: default;
			grid myCA;
			mesh field_display color: (brewer_colors("YlGn")) scale: 3 triangulation: true smooth: true refresh: false;
			//			species rainfall_station aspect: default;
			//			ask myCA {
			//				draw color: #red; // Draw the grid with the assigned color
			//			}
			//			grid myCA color: myCA.color scale: 1.0 triangulation: true smooth: true refresh: false transparency: 0.5;

			//			draw sphere(center: location(centreCell), radius: 0.1) color: #red;
			//			species watershed_bdry_agent aspect:default transparency: 0.5;
			//			species water_level_agent aspect:default transparency: 0.5;

		}

		//		display "field through mesh in grey scale" type: 3d {
		//			mesh field_display grayscale: true scale: 0.03 triangulation: true smooth: true refresh: false;
		//		}

		// 		Not working
		//		display "rgb field through mesh" type: 3d {
		//			mesh field_display color: field_display.bands scale: 0.1 triangulation: true smooth: 4 refresh: false;
		//		}

		//		output is not satisfied
		//		display "rnd field with palette mesh" type: 3d {
		//			mesh field_display.bands[2] color: scale([#red::100, #yellow::115, #green::101, #darkgreen::105]) scale: 0.2 refresh: false;
		//		}
		//		display "var field" type: 3d {
		//			mesh var_field color: (brewer_colors("RdBu")) scale: 0.03;
		//		}
		//
	}

}
