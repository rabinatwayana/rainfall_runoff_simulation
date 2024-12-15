/**
* Name: Hydrological Model
* Author: Patrick Taillandier
* Description: A model showing how to represent a flooding system with dykes and buildings. It uses 
* 	a grid to discretize space, and has a 3D display. The water can flow from one cell to another considering 
* 	the height of the cells, and the water pressure. It is also possible to delete dyke by clicking on one of them 
* 	in the display.
* Tags: shapefile, gis, grid, 3d, gui, hydrology
*/
model hydro

global {

//Shapefile for the watershed
	file river_shapefile <- file("../includes/watershed_bdry/watershed_polygon.shp");

	//Data elevation file
	file dem_file <- file("../includes/sundarijal_DEM_by_extent.asc");
	grid_file dem_file1 <- file("../includes/sundarijal_DEM_by_extent.asc");
	field terrain <- field(dem_file1);

	//import water level and rainfall data
	file rainfall_file <- csv_file("../includes/Hydromet_Data/rainfall_test_data.csv", ",");
	file water_level_file <- csv_file("../includes/Hydromet_Data/water_level_test_data.csv", ",");

	//Diffusion rate
	float diffusion_rate <- 0.6;

	//Shape of the environment using the dem file
	geometry shape <- envelope(river_shapefile);

	//List of the drain and river cells
	list<cell> drain_cells; // end point of river
	list<cell> river_cells;
	float step <- 1 #h;

	//initialize rainfall and water level data
	matrix rainfall_data;
	matrix water_level_data;

	//hours for each time step - increase by 1
	int hour_count <- 0;

	init {
		create rainfall_station number: 1 {
			location <- point(to_GAMA_CRS({939154.872462730738334, 3083799.649202660657465, 2089.31517175}, "EPSG:32644"));
		}

		create water_level_station number: 1 {
			location <- point(to_GAMA_CRS({936005.822451834799722, 3077909.181984767317772, 1352.94620443}, "EPSG:32644"));
		}
		//Initialization of the cells
		do init_cells;
		//Initialization of the water cells
		do init_water;
		//Initialization of the river cells
		river_cells <- cell where (each.is_river);
		//Initialization of the drain cells
		drain_cells <- cell where (each.is_drain);

		//convert the file into a matrix
		rainfall_data <- matrix(rainfall_file);
		water_level_data <- matrix(water_level_file);
	}
	//Action to initialize the altitude value of the cell according to the dem file
	action init_cells {
		ask cell {
			altitude <- grid_value;
			neighbour_cells <- (self neighbors_at 1);
		}

	}
	//action to initialize the water cells according to the river shape file and the drain
	action init_water {
		geometry river <- geometry(river_shapefile);
		ask cell overlapping river {
			write (matrix(cell).rows);
			water_height <- 0.0;
			is_river <- true;
			is_drain <- grid_y = matrix(cell).rows - 1; //conditon check, whether it is end point of river or not, matrix(cell).rows= total number of rows in grid cells
		}

	}

	//Reflex to add water among the water cells
	reflex adding_input_water {
	//   	  float water_input <- rnd(100)/1000;
		write "hour:-------------------------" + hour_count;
		write "rainfall date_time:  " + rainfall_data[3, hour_count];
		write "rainfall data:  " + rainfall_data[2, hour_count];
		float water_input <- float(rainfall_data[2, hour_count]);
		ask river_cells {
			water_height <- water_height + water_input;
		}

		hour_count <- hour_count + 1;
	}
	//Reflex to flow the water according to the altitute and the obstacle
	reflex flowing {
	//		ask cell {
	//			write self.altitude;
	//		}
		ask (cell sort_by ((each.altitude + each.water_height + each.obstacle_height))) {
		//			write altitude;
			already <- false;
			do flow;
		}

	}
	//Reflex to update the color of the cell
	reflex update_cell_color {
		ask cell {
			do update_color;
		}

	}
	//Reflex for the drain cells to drain water
	reflex draining {
		ask drain_cells {
			water_height <- 0.0;
		}

	}

	species rainfall_station {

		aspect default {
			draw circle(50) color: #red;
		}

	}

	species water_level_station {

		aspect default {
			draw circle(50) color: #brown;
		}

		reflex measure_river_height {
			cell river_cell <- cell(self.location);
			// Check if the cell exists
			if (river_cell != nil) {
			// Retrieve the water height
				float cell_water_height <- river_cell.water_height;

				// Print the water height to the console
				write "CA water height:  " + cell_water_height;
			} else {
				write "No grid cell found at station location.";
			}

		}

		reflex read_river_height {
		//			write hour_count;
			write "water_level date_time:  " + water_level_data[3, hour_count];
			write "Water level: " + water_level_data[2, hour_count];
		}

	}

}

//Grid cell to discretize space, initialized using the dem file
grid cell file: dem_file neighbors: 8 frequency: 0 use_regular_agents: false use_individual_shapes: false use_neighbors_cache: false schedules: [] {
//Altitude of the cell
	float altitude;
	//Height of the water in the cell
	float water_height <- 0.0 min: 0.0;
	//Height of the cell
	float height;
	//List of the neighbour cells
	list<cell> neighbour_cells;
	//Boolean to know if it is a drain cell
	bool is_drain <- false;
	//Boolean to know if it is a river cell
	bool is_river <- false;

	//Height of the obstacles
	float obstacle_height <- 0.0;
	bool already <- false;

	//Action to flow the water 
	action flow {

	//height=altitude+water_height

	//if the height of the water is higher than 0 then, it can flow among the neighbour cells
		if (water_height > 0) {
		//We get all the cells already done
			list<cell> neighbour_cells_al <- neighbour_cells where (each.already);
			//If there are cells already done then we continue
			if (!empty(neighbour_cells_al)) {
			//We compute the height of the neighbours cells according to their altitude, water_height and obstacle_height
				ask neighbour_cells_al {
					height <- altitude + water_height + obstacle_height;
				}
				//The height of the cell is equals to its altitude and water height
				height <- altitude + water_height;
				//The water of the cells will flow to the neighbour cells which have a height less than the height of the actual cell
				list<cell> flow_cells <- (neighbour_cells_al where (height > each.height));
				//If there are cells, we compute the water flowing
				if (!empty(flow_cells)) {
				// bias minimize in cace of multiple cell avaible with same values
					loop flow_cell over: shuffle(flow_cells) sort_by (each.height) {
					//The max function ensures that the value of water_flowing is not negative.
						float water_flowing <- max([0.0, min([(height - flow_cell.height), water_height * diffusion_rate])]);
						water_height <- water_height - water_flowing;
						flow_cell.water_height <- flow_cell.water_height + water_flowing;
						height <- altitude + water_height; // height- water_flowing
					}

				}

			}

		}

		already <- true;
	}
	//Update the color of the cell
	action update_color {
		int val_water <- 0;
		val_water <- max([0, min([255, int(255 * (1 - (water_height / 12.0)))])]); //consider water_height range from 0 to 12
		color <- rgb([val_water, val_water, 255]);
		//		grid_value <- water_height + altitude;  //seem to be no effect
	}

}

experiment Run type: gui {
   parameter "Shapefile for the river" var:river_shapefile category:"Water data";
   parameter "Diffusion rate" var:diffusion_rate category:"Water dynamic";
   output { 
   //layout vertical([0::5000,1::5000]) tabs:false editors: false;
      display map type: 3d {

         camera 'default' location: {7071.9529,10484.5136,5477.0823} target: {3450.0,3220.0,0.0};
//		 mesh terrain scale: 5 triangulation: true  color: palette([#burlywood, #saddlebrown, #darkgreen, #green]) refresh: false smooth: true;
         grid cell transparency:0.5 elevation:true;
      }
//      display chart_display refresh: every(24#cycles)  type: 2d  { 
//         chart "Pressure on Dykes" type: series legend_font: font("Helvetica", 18)  label_font: font("Helvetica", 20, #bold)  title_font: font("Helvetica", 24, #bold){
//            data "Mean pressure on dykes " value: mean(dyke collect (each.water_pressure)) style: line color: #magenta  ;
//            data "Rate of dykes with max pressure" value: (dyke count (each.water_pressure = 1.0))/ length(dyke) style: line color: #red ;
//            data "Rate of dykes with high pressure" value: (dyke count (each.water_pressure > 0.5))/ length(dyke) style: line color: #orange ;
//            data "Rate of dykes with low pressure" value: (dyke count (each.water_pressure < 0.25))/ length(dyke) style: line color: #green ;
//         }
//      }
   }
}