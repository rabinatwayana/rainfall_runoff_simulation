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
	 //river network load
     file common_river_net_shapefile <- file("../includes/river_network/common/common_net_buff.shp");
     file bhagdwar_river_net_shp <- file("../includes/river_network/bagdwar/bagdwar_river_net_buff_5m.shp");
     file dhap_dam_river_net_shp <- file("../includes/river_network/dhap_dam/dhap_dam_river_net_buff_5m.shp");

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
	float diffusion_rate <- 0.3;

	//Shape of the environment using the dem file
	geometry shape <- envelope(river_shapefile);

	//List of the drain and river cells
	list<cell> drain_cells; // end point of river
	list<cell> river_cells;
	float step <- 1 #h;

	//initialize rainfall and water level data
	matrix rainfall_data;
	matrix water_level_data;
	cell dhap_dam_cell;
	cell bagdwar_cell;
	
	point bagdwar_location <- point(to_GAMA_CRS({932670.207777618896216, 3084048.894010512623936}, "EPSG:32644"));
	
	point dhap_dam_location <- point(to_GAMA_CRS({939112.16664863564074, 3083560.629052739124745}, "EPSG:32644"));
//	bool is_dhap_dam_initialized <- false;

	//hours for each time step - increase by 1
	int hour_count <- 0;
	int steps_count <- 0;
	float hourly_water_input <-0;
	float hourly_water_level_input <-0;
	//divide hourly data to number of intermediate steps
	
	int hour_steps <- 20; //no of steps that is run in an hour. change this to control water flow steps per hour
	int hour_steps_new <- hour_steps;
	bool hour_changed <- false;
	int hour_division <- 60/hour_steps; //hourly data will be divided by hour_division in each step
	float water_input <-0;
	float water_level_input <-0;
	
	float measured_water_level;
	
	//plot chart for validation
	list<float> original_wl_list <- [];
	list<float> measured_wl_list <- [];
	list<float> original_rainfall_list <- [];
	
	
	
	init {
		create rainfall_station number: 1 {
			location <- point(to_GAMA_CRS({939154.872462730738334, 3083799.649202660657465, 2089.31517175}, "EPSG:32644"));
		}

		create water_level_station number: 1 {
			location <- point(to_GAMA_CRS({936020.399171121185645, 3077920.820926873479038, 1352.94620443}, "EPSG:32644"));
//			location <- point(to_GAMA_CRS({935973.399171121185645, 3077920.820926873479038, 1352.94620443}, "EPSG:32644"));
//			location <- point(to_GAMA_CRS({936005.822451834799722, 3077909.181984767317772, 1352.94620443}, "EPSG:32644"));
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
		//			write (matrix(cell).rows);
			water_height <- 0.0;
			is_river <- true;
			is_drain <- grid_y = matrix(cell).rows - 1; //conditon check, whether it is end point of river or not, matrix(cell).rows= total number of rows in grid cells
		}

	}
	
	
       //action to initialize the water cells according to the river shape file and the drain
       action init_river_water {
               geometry common_river_geom <- geometry(common_river_net_shapefile);
               geometry bhagdwar_river_geom <- geometry(bhagdwar_river_net_shp);
               geometry dhap_dam_river_geom <- geometry(dhap_dam_river_net_shp);
       
       
               ask cell overlapping common_river_geom {
				// write "overlpping cell";
                       water_height <- (0.3)*10; //exagerated by 10
               }
               
               ask cell overlapping bhagdwar_river_geom {
                       water_height <- (0.3*0.67)*10;
               }
               
               ask cell overlapping dhap_dam_river_geom {
                       water_height <- (0.3*0.33)*10;
               }
               
               ask cell {
                       do update_color;
               }

       }
	
	reflex add_water_in_start_point_points {
		ask dhap_dam_cell {
			water_height <- (0.3*0.33)*10;
			}
		
		ask bagdwar_cell {
			water_height <- (0.3*0.67)*10;
		}

	}

	//Reflex to add water among the water cells
	reflex adding_input_water {
	//   	  float water_input <- rnd(100)/1000;
		
//		write "hour_division:-----------------"+ hour_division;
//		write "steps_count:-------------------------" + steps_count;
//		write "hour_count:-------------------------" + hour_count;
//		write "rainfall date_time:  " + rainfall_data[3, hour_count];
//		write "rainfall data:  " + rainfall_data[2, hour_count];		
		
		write "step outside "+ steps_count;
		write "hour_count outside "+ hour_count;
	
		if(hour_steps_new = steps_count){
//			write "condition true";
			write "step inside "+ steps_count;
//			 
			
			hourly_water_input <- (float(rainfall_data[2, hour_count])/1000)*10; //*10 is exageration of water input
			
//			if(steps_count = 0){
//				water_input <- hourly_water_input;
//			}
//			else{
				
				water_input <- hourly_water_input / (60/hour_division);
//			}
			
			
//			write "hourly_water_input: "+hourly_water_input;
			write "hour steps new: "+hour_steps_new;
			write "hour steps : "+hour_steps;
			hour_steps_new <- hour_steps_new + hour_steps;
			hour_count <- hour_count +1;
			write "hour_count inside "+ hour_count;
			write "hour_steps inside "+ hour_steps_new;
			
			hour_changed <-true;
			
			
		}
		else if(hour_count = 0){
			hourly_water_input <- (float(rainfall_data[2, 0])/1000)*10; //*10 is exageration of water input
			water_input <- hourly_water_input/(60/hour_division);
			write "hourly rainfall inside "+water_input;
		}
		
		//for validation
		add water_input to: original_rainfall_list;
		
		write "water_input: "+water_input;
//		ask river_cells {
//			water_height <- water_height + 0.0;
//		}
		ask river_cells {
			water_height <- water_height + water_input;
		}
		steps_count <- steps_count + 1;
	}
	//Reflex to flow the water according to the altitute and the obstacle
	reflex flowing {
	//		ask cell {
	//			write self.altitude;
	//		}
		ask (cell sort_by ((each.altitude + each.water_height /* + each.obstacle_height*/))) {
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

	species dhap_dam_point {

		init {
			dhap_dam_cell <- cell(dhap_dam_location);
//			dhap_dam_cell <- cell(self.location);
//			write "dhap_dam_cell location " + dhap_dam_cell;
			
			ask dhap_dam_cell {
//				write "Dhap Dam Cell initialized at: " + self.location.x + ", " + self.location.y;
			}
		}

		aspect default {
			draw circle(30) color: #red;
		}

		//		reflex measure_elevation {
		//			cell c <- cell(self.location);
		//			write "dhap: " + c.altitude;
		//		}

	}

	species bagdwar_point {

		init {
//			bagdwar_cell <- cell(self.location);
			
			bagdwar_cell <- cell(bagdwar_location);
//			is_dhap_dam_initialized <-true;
//			write "Bagdwar Point X: " + self.location.x;
//			write "Bagdwar Point Y: " + self.location.y;
//			write "Bagdwar Point z: " + self.location.altitude;
		}


		aspect default {
			draw circle(30) color: #red;
		}

				reflex measure_elevation {
					cell c <- cell(self.location);
//					write "bagdwar: " + c.altitude;
				}	

	}

	species water_level_station {

		aspect default {
			draw circle(10) color: #brown;
		}

		reflex measure_river_height {
			cell river_cell <- cell(self.location);
//			write "river_cell_water_level"+ river_cell.water_height;
			// Check if the cell exists
			if (river_cell != nil) {
			// Retrieve the water height
//				float cell_water_height <- river_cell.water_height;
				measured_water_level<- river_cell.water_height/10;

				// Print the water height to the console
				write "Measured water height:  " + measured_water_level;
				
				//for validation
				add measured_water_level to: measured_wl_list;
				
			} else {
				write "No grid cell found at station location.";
			}

		}

		reflex read_river_height {
		//			write steps_count;
			write "outside"+hour_count;
			if(hour_changed){
				write "inside"+hour_count;
	//			write "condition true";
//				hour_count_river <- hour_count_river +1;
				hourly_water_level_input <- float(water_level_data[2, hour_count]);
				
//				if(steps_count = 0){
					water_level_input <- hourly_water_level_input*1;
//				}
//				else{
//					water_level_input <- (hourly_water_level_input / (60/hour_division))*1;
//				}
				
	//			write "hourly_water_input: "+hourly_water_input;
				hour_changed <- false;
	
				
			}
			else if(hour_count = 0){
				water_level_input  <- float(water_level_data[2, hour_count]);
			}
			//for validation
			add water_level_input to: original_wl_list;
			
			
			write "Original water_level date_time:  " + water_level_data[3, steps_count];
			write "Original Water level: " + water_level_data[2, steps_count];
		
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
//	float obstacle_height <- 0.0;
	bool already <- false;

	//Action to flow the water 
	action flow {

	//height=altitude+water_height

	//if the height of the water is higher than 0 then, it can flow among the neighbour cells
		if (water_height > 0) {
		//We get all the cells already done
			list<cell> neighbour_cells_al <- neighbour_cells where (each.already);
//			list<cell> neighbour_cells_al <- neighbour_cells;
//			write "water_height: "+water_height;
//			write "altitude: "+altitude;
			//If there are cells already done then we continue
			if (!empty(neighbour_cells_al)) {
			//We compute the height of the neighbours cells according to their altitude, water_height and obstacle_height
				ask neighbour_cells_al {
					height <- altitude + water_height;// + obstacle_height;
//					write "neighbor: "+water_height + "Altitude: "+altitude;
				}
				//The height of the cell is equals to its altitude and water height
				height <- altitude + water_height;
//				write "water height: "+water_height;
//				write "height: "+height;
//				loop neighbour_ over: neighbour_cells_al {
//					write "neighbour cell altitude: "+neighbour_.height;
//				}
				
				//The water of the cells will flow to the neighbour cells which have a height less than the height of the actual cell
				list<cell> flow_cells <- (neighbour_cells_al where (each.height < height));
//				write "flow cells: "+flow_cells;
				//If there are cells, we compute the water flowing
				if (!empty(flow_cells)) {
				// bias minimize in cace of multiple cell avaible with same values
					loop flow_cell over: shuffle(flow_cells) sort_by (each.height) {
//						write "flow cell altitude: "+flow_cell.height; 
					//The max function ensures that the value of water_flowing is not negative.
						//how much water can be flowed form that cell to neighboring cell.
						float water_flowing <- max([0.0, min([(height - flow_cell.height), water_height * diffusion_rate])]);
//						float water_flowing <- water_height;
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

//		val_water <- max([0, min([255, int(255 * (1 - (water_height*100/12)))])]); //consider water_height range from 0 to 12. 
//
//		color <- rgb([val_water, val_water, 255]);
	val_water <- int((1 - (water_height / (0.05*10))) * 255);
		
		if water_height=0{
			color <- rgb([255,255,255]);
		}else if water_height>(0.05*10){  //if water height is greater than 50 mm
			color <- rgb([0,0,255]);
		}
		else if (val_water>255 or val_water<0){
				write "water_height"+water_height;
				write "val_water"+ val_water;
				color <- rgb([255,0,0]);
		}else {
			color <- rgb([val_water,val_water,255]);
		}

	}

}

experiment Run type: gui {
	
	
	
	
	reflex save_data {
		string date_col <- water_level_data[3, steps_count];
		float original_water_level<- water_level_data[2, steps_count];
		
		
		save [cycle,date_col, original_water_level, measured_water_level] to: "../results/results.csv" format: "csv" rewrite: false header: true;
	}
	
	parameter "Shapefile for the river" var: river_shapefile category: "Water data";
	parameter "Diffusion rate" var: diffusion_rate category: "Water dynamic";
	output {
	//layout vertical([0::5000,1::5000]) tabs:false editors: false;
		display map type: 3d {
			species bagdwar_point aspect: default;
			species dhap_dam_point aspect: default;
			species rainfall_station aspect: default;
			species water_level_station aspect: default;
			camera 'default' location: {7071.9529, 10484.5136, 5477.0823} target: {3450.0, 3220.0, 0.0};
			mesh terrain triangulation: true color: palette([#burlywood, #saddlebrown, #darkgreen, #green]) refresh: false smooth: true;
			grid cell transparency: 0.5 elevation: true triangulation: true smooth: true; //scale:0.5
		}
		//      display chart_display refresh: every(24#cycles)  type: 2d  { 
		//         chart "Pressure on Dykes" type: series legend_font: font("Helvetica", 18)  label_font: font("Helvetica", 20, #bold)  title_font: font("Helvetica", 24, #bold){
		//            data "Mean pressure on dykes " value: mean(dyke collect (each.water_pressure)) style: line color: #magenta  ;
		//            data "Rate of dykes with max pressure" value: (dyke count (each.water_pressure = 1.0))/ length(dyke) style: line color: #red ;
		//            data "Rate of dykes with high pressure" value: (dyke count (each.water_pressure > 0.5))/ length(dyke) style: line color: #orange ;
		//            data "Rate of dykes with low pressure" value: (dyke count (each.water_pressure < 0.25))/ length(dyke) style: line color: #green ;
		//         }
		//      }
		
		 display "Actual Vs Predicted Water Level" type: 2d {
				chart "Water Level" type: series x_label: "timestep" memorize: false {
					data "Original Water Level" value: original_wl_list color: #blue marker: false style: line;
					data "Measured Water Level" value: measured_wl_list color: #red marker: false style: line;
//					data "max biomass" value: maxlist color: #green marker: false style: line;
				}
			 }
			 
		display "Original Rainfall Data" type: 2d {
				chart "Rainfall" type: series x_label: "timestep" memorize: false {
					data "Original Rainfall Value in mm" value: original_rainfall_list color: #blue marker: false style: line;
//					data "Measured Water Level" value: measured_wl_list color: #red marker: false style: line;
//					data "max biomass" value: maxlist color: #green marker: false style: line;
				}
			 }
	}
}