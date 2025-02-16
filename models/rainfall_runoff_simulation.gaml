/**
* Name: Rainfall Runoff Simulation Model
* Author: Upendra Oli and Rabina Twayana
* Description: The primary objective was to create an agent-based model capable of simulating runoff dynamics for the Bagmati River 
* and validate its accuracy by comparing simulated outcomes with observed data. 
* After the model calibration, simulation was carried for three scenarios (high, medium and low rainfall event). 
* This work seeks to advance our understanding of water flow dynamics and improve predictive capabilities in similar contexts. 
* Tags: shapefile, gis, 3d, gui, hydrology
*/
model rainfall_runoff

global {
	bool calibration_state <- false;

	// read river network shapefiles
	file bhagdwar_river_net_shp <- file("../includes/river_network/bagdwar/bagdwar_river_net_buff_5m.shp"); //bagmati river
	file dhap_dam_river_net_shp <- file("../includes/river_network/dhap_dam/dhap_dam_river_net_buff_5m.shp"); //nagmati river
	file common_river_net_shapefile <- file("../includes/river_network/common/common_net_buff.shp");

	// read DEM fil2
	file dem_file <- file("../includes/DEM/sundarijal_DEM_by_extent.asc");

	//read water level and rainfall data
	file rainfall_file <- csv_file("../includes/Hydromet_Data/rainfall_extreme_event.csv", ",");
	file water_level_file <- csv_file("../includes/Hydromet_Data/water_level_sept_28.csv", ",");

	//read watershed shapefile
	file watershep_shapefile <- file("../includes/watershed_bdry/watershed_polygon.shp");

	//create field from dem_file to plot 3D terrain mesh
	grid_file terrain_dem_file <- file("../includes/DEM/sundarijal_DEM_by_extent.asc");
	field terrain <- field(terrain_dem_file);

	//Diffusion rate
	float low_slope_diffusion_rate <- 0.3;
	float medium_slope_diffusion_rate <- 0.6;
	float high_slope_diffusion_rate <- 0.9;
	
	float constant_river_water_input <- 2.25;
	float infiltration_coeff <- 0.005;
	float water_scale_factor <- 1.0;
	int hour_steps <- 60;

	//Shape of the environment from the watershep_shapefile
	geometry shape <- envelope(watershep_shapefile);

	//List of the drain and river cells
	list<cell> drain_cells; 
	list<cell> river_cells;
	float step <- 1 #h;

	//initialize rainfall and water level data
	matrix rainfall_data;
	matrix water_level_data;
	cell dhap_dam_cell;
	cell bagdwar_cell;

	//	water input start point of bagmati river
	point bagdwar_location <- point(to_GAMA_CRS({932670.207777618896216, 3084048.894010512623936}, "EPSG:32644"));

	//	water input start point of Nagmati river
	point dhap_dam_location <- point(to_GAMA_CRS({939112.16664863564074, 3083560.629052739124745}, "EPSG:32644"));

	//hours for each time step - increase by 1
	int hour_count <- 0;
	int steps_count <- 0;
	float hourly_water_input <- 0.0;
	float hourly_water_level_input <- 0.0;
	
	//divide hourly data to number of intermediate steps
	int hour_steps_new <- hour_steps;
	bool hour_changed <- false;
	float water_input <- 0.0;
	float water_level_input <- 0.0;
	float measured_water_level;

	//list of the values to plot chart for validation, wl means waterlevel
	list<float> original_wl_list <- [];
	list<float> measured_wl_list <- [];
	list<float> original_rainfall_list <- [];

	init {
		create rainfall_station number: 1 {
			location <- point(to_GAMA_CRS({939154.872462730738334, 3083799.649202660657465, 2089.31517175}, "EPSG:32644"));
		}

		create water_level_station number: 1 {
			location <- point(to_GAMA_CRS({936020.399171121185645, 3077920.820926873479038, 1352.94620443}, "EPSG:32644")); //2nd_last
		}

		//dhap dam water flow start point: actual elevation=2066.741245738319776
		create dhap_dam_point number: 1 {
			location <- point(to_GAMA_CRS({939112.16664863564074, 3083560.629052739124745, 2098 + 5}, "EPSG:32644"));
		}

		//Bagdwar water flow start point actual height: 2514.674001746269823
		create bagdwar_point number: 1 {
			location <- point(to_GAMA_CRS({932670.207777618896216, 3084048.894010512623936, 2666 + 5}, "EPSG:32644"));
		}

		//Initialization of the cells
		do init_cells;
		//Initialization of the water cells
		do init_water;

		// Initialization of the water in river cells
		do init_river_water;
		//Initialization of the river cells
		river_cells <- cell where (each.is_river);
		//Initialization of the drain cells
		drain_cells <- cell where (each.is_drain);

		//convert the file into a matrix
		rainfall_data <- matrix(rainfall_file);
		water_level_data <- matrix(water_level_file);
	}

	action init_cells {
		ask cell {
			altitude <- grid_value;
			neighbour_cells <- (self neighbors_at 1);
		}

	}

	//action to initialize the water cells according to the river shape file and the drain
	action init_water {
		geometry river <- geometry(watershep_shapefile);
		ask cell overlapping river {
			water_height <- 0.02;
			is_river <- true;
			is_drain <- (grid_y = (matrix(cell).rows - 1)) or (grid_y = (matrix(cell).rows - 2)) or (grid_y = (matrix(cell).rows - 3));
		}

	}

	//action to initialize the water cells according to the river shape file and the drain
	action init_river_water {
		geometry common_river_geom <- geometry(common_river_net_shapefile);
		geometry bhagdwar_river_geom <- geometry(bhagdwar_river_net_shp);
		geometry dhap_dam_river_geom <- geometry(dhap_dam_river_net_shp);
		ask cell overlapping common_river_geom {
			water_height <- constant_river_water_input * (1 + water_scale_factor); //exagerated by 10
		}

		ask cell overlapping bhagdwar_river_geom {
			water_height <- (constant_river_water_input * 0.67) * (1 + water_scale_factor);
		}

		ask cell overlapping dhap_dam_river_geom {
			water_height <- (constant_river_water_input * 0.33) * (1 + water_scale_factor);
		}

		ask cell {
			do update_color;
		}

	}

	reflex add_water_in_start_point_points {
		ask dhap_dam_cell {
			water_height <- (constant_river_water_input * 0.33) * (1 + water_scale_factor);
		}

		ask bagdwar_cell {
			water_height <- (constant_river_water_input * 0.67) * (1 + water_scale_factor);
		}

	}

	//Reflex to add water among the water cells
	reflex adding_input_water {
		write "------------";
		if (hour_steps_new = steps_count) {
			hourly_water_input <- (float(rainfall_data[2, hour_count]) / 1000) * (1 + water_scale_factor); //*10 is exageration of water input
			water_input <- hourly_water_input / hour_steps;
			hour_steps_new <- hour_steps_new + hour_steps;
			hour_count <- hour_count + 1;
			hour_changed <- true;
			
		} else if (hour_count = 0) {
			hourly_water_input <- (float(rainfall_data[2, 0]) / 1000) * (1 + water_scale_factor);
			water_input <- hourly_water_input / hour_steps;
		}

		//for validation
		add water_input to: original_rainfall_list;
		//		write "water_input: " + water_input;
		ask river_cells {
			water_height <- water_height + water_input;
		}

		steps_count <- steps_count + 1;
	}

	//Reflex to flow the water according to the altitute and the obstacle
	reflex flowing {
		ask (cell sort_by ((each.altitude + each.water_height /* + each.obstacle_height*/))) {
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

	species dhap_dam_point {

		init {
			dhap_dam_cell <- cell(dhap_dam_location);
			ask dhap_dam_cell {
			}

		}

		aspect default {
			draw circle(30) color: #yellow;
		}

	}

	species bagdwar_point {

		init {
			bagdwar_cell <- cell(bagdwar_location);
		}

		aspect default {
			draw circle(30) color: #yellow;
		}

		reflex measure_elevation {
			cell c <- cell(self.location);
		}

	}

	species water_level_station {

		aspect default {
			draw circle(30) color: #brown;
		}

		reflex measure_river_height {
			cell river_cell <- cell(self.location);

			// Check if the cell exists
			if (river_cell != nil) {
				measured_water_level <- river_cell.water_height;

				// Display the water height to the console
				write "Measured water height:  " + measured_water_level;

				//for validation
				add measured_water_level to: measured_wl_list;
			} else {
				write "No grid cell found at station location.";
			}

		}

		reflex read_river_height {
			if (hour_changed) {
				hourly_water_level_input <- float(water_level_data[2, hour_count]);
				water_level_input <- hourly_water_level_input * 1;
				hour_changed <- false;
			} else if (hour_count = 0) {
				water_level_input <- float(water_level_data[2, hour_count]);
			}
			//for validation
			add water_level_input to: original_wl_list;
			write "hour: " + hour_count;
			write "steps: " + steps_count;
			if calibration_state {
				write "Original water_level date_time:  " + water_level_data[3, hour_count];
				write "Original Water level: " + water_level_data[2, hour_count];
			}

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
	bool already <- false;

	//Action to flow the water 
	action flow {
		if water_height > 1 {
			water_height <- water_height - (infiltration_coeff * water_height);
		}

		//if the height of the water is higher than 0 then, it can flow among the neighbour cells
		if (water_height > 0) {

		//We get all the cells already done
			list<cell> neighbour_cells_al <- neighbour_cells where (each.already);
			//If there are cells already done then we continue
			if (!empty(neighbour_cells_al)) {
			//We compute the height of the neighbours cells according to their altitude, water_height and obstacle_height
				ask neighbour_cells_al {
					height <- altitude + water_height; // + obstacle_height;
				}

				//The height of the cell is equals to its altitude and water height
				height <- altitude + water_height;
				//					write "neighbour cell altitude: "+neighbour_.height;
				//				}

				//The water of the cells will flow to the neighbour cells which have a height less than the height of the actual cell
				list<cell> flow_cells <- (neighbour_cells_al where (each.height < height));
				//If there are cells, we compute the water flowing
				if (!empty(flow_cells)) {
				// bias minimize in cace of multiple cell avaible with same values
					loop flow_cell over: shuffle(flow_cells) sort_by (each.height) {
					//	The max function ensures that the value of water_flowing is not negative.
					//	how much water can be flowed form that cell to neighboring cell.
					//						add (height - flow_cell.height) to: slope_list;
						float updated_diffusion_rate <- low_slope_diffusion_rate;
						if (height - flow_cell.height) > 60 {
							updated_diffusion_rate <- high_slope_diffusion_rate;
						} else if (height - flow_cell.height) > 30 {
							updated_diffusion_rate <- medium_slope_diffusion_rate;
						}

						float water_flowing <- max([0.0, min([(height - flow_cell.height), water_height * updated_diffusion_rate])]);
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
		val_water <- int((1 - (water_height / (0.05 * 10))) * 255);
		if water_height = 0 {
			color <- rgb([255, 255, 255]);
		} else if water_height > (0.05 * 10) { //if water height is greater than 50 mm
			color <- rgb([0, 0, 255]);
		} else if (val_water > 255 or val_water < 0) {
			color <- rgb([255, 0, 0]);
		} else {
			color <- rgb([val_water, val_water, 255]);
		} } }

experiment Run type: gui {

	reflex save_data {
		string date_col <- water_level_data[3, hour_count];
		float original_water_level <- water_level_data[2, hour_count];
		save [cycle, steps_count, date_col, original_water_level, measured_water_level] to: "../results/results.csv" format: "csv" rewrite: cycle = 0 header: true;
	}

	parameter "csv input" var: rainfall_file category: "Rainfall";
	parameter "Low slope diffusion rate" var: low_slope_diffusion_rate category: "Water dynamic";
	parameter "Medium slope diffusion rate" var: medium_slope_diffusion_rate category: "Water dynamic";
	parameter "High slope diffusion rate" var: high_slope_diffusion_rate category: "Water dynamic";
	output {
		display map type: 3d {
			species bagdwar_point aspect: default;
			species dhap_dam_point aspect: default;
			species rainfall_station aspect: default;
			species water_level_station aspect: default;
			camera 'default' location: {7071.9529, 10484.5136, 5477.0823} target: {3450.0, 3220.0, 0.0};
			mesh terrain triangulation: true color: palette([#burlywood, #saddlebrown, #darkgreen, #green]) refresh: false smooth: true;
			grid cell transparency: 0.5 elevation: true triangulation: true smooth: true; //scale:0.5
		}

		display "Measured Water Level" type: 2d {
			chart "Water Level" type: series x_label: "timestep" memorize: false {
			//	uncomment follwing line during calibration state
			//	data "Original Water Level" value: original_wl_list color: #blue marker: false style: line;	
				data "Measured Water Level" value: measured_wl_list color: #red marker: false style: line;
			}

		}

		display "Original Rainfall Data" type: 2d {
			chart "Rainfall" type: series x_label: "timestep" memorize: false {
				data "Rainfall Value in mm" value: original_rainfall_list color: #blue marker: false style: line;
			}

		}

	}

}