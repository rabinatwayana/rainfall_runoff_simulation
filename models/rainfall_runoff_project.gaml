model RainfallRunoffModel

global {
    grid_file dem_file <- file("../includes/sundarijal_DEM_by_extent.asc");
    field terrain <- field(dem_file);
    field flow <- field(terrain.columns, terrain.rows);
    field combined_height <- field(terrain.columns, terrain.rows); // Field to combine terrain and flow

    geometry shape <- envelope(dem_file);
    bool fill <- false;

    // Diffusion rate and other parameters
    float diffusion_rate <- 0.8;
    int frequence_input <- 3;
    list<point> drain_cells <- [];
    list<point> source_cells <- [];
    map<point, float> heights <- [];
    list<point> points <- flow points_in shape;
    map<point, list<point>> neighbors <- points as_map (each::(flow neighbors_of each));
    map<point, bool> done <- points as_map (each::false);
    map<point, float> h <- points as_map (each::terrain[each]);
    float input_water;

    init {
        // Create a rainfall station
        create rainfall_station number: 1 {
            location <- point(to_GAMA_CRS({936580.8678, 3081182.6043, 5800}, "EPSG:32644"));
        }

        // Load river geometry and classify cells
        geometry river_g <- first(file("../includes/watershed_bdry/watershed_polygon.shp"));
        float c_h <- shape.height / flow.rows;
        list<point> rivers_pt <- points where ((each overlaps river_g) and (terrain[each] < 3000.0));

        if (fill) {
            loop pt over: rivers_pt {
                flow[pt] <- 1.0;
            }
        }

        loop pt over: rivers_pt {
            if (pt.y < c_h) {
                source_cells << pt;
            }
        }
        loop pt over: rivers_pt {
            if (pt.y > (shape.height - c_h)) {
                drain_cells << pt;
            }
        }
    }

    // Reflex to add water among the source cells
    reflex adding_input_water when: every(frequence_input # cycle) {
        loop p over: source_cells {
            flow[p] <- flow[p] + input_water;
        }
    }

    // Reflex for the drain cells to drain water
    reflex draining {
        loop p over: drain_cells {
            flow[p] <- 0.0;
        }
    }

    float height(point c) {
        return h[c] + flow[c];
    }

    // Reflex to flow the water according to the altitude and the obstacle
    reflex flowing {
        done[] <- false;
        heights <- points as_map (each::height(each));
        list<point> water <- points where (flow[each] > 0) sort_by (heights[each]);
        loop p over: points - water {
            done[p] <- true;
        }
        loop p over: water {
            float height <- height(p);
            loop flow_cell over: (neighbors[p] where (done[each] and height > heights[each])) sort_by heights[each] {
                float water_flowing <- max(0.0, min((height - heights[flow_cell]), flow[p] * diffusion_rate));
                flow[p] <- flow[p] - water_flowing;
                flow[flow_cell] <- flow[flow_cell] + water_flowing;
                heights[p] <- height(p);
                heights[flow_cell] <- height(flow_cell);
            }
            done[p] <- true;
        }
    }

    // Reflex to update the combined height field
    reflex update_combined_height {
        loop p over: points {
            combined_height[p] <- terrain[p] + flow[p];
        }
    }
}

species rainfall_station {
    aspect default {
        draw circle(100) color: #brown;
    }
}

experiment rainfall_runoff_view type: gui {
    parameter "Input water at source" var: input_water <- 100.0 min: 0.0 max: 300.0 step: 0.1;
    parameter "Fill the river" var: fill <- true;

    output {
        layout #split;

        display "field through mesh in brewer colors" type: 3d {
            species rainfall_station aspect: default;

            // Terrain mesh with its original elevation
            mesh terrain 
                color: (brewer_colors("YlGn")) 
                scale: 3 
                triangulation: true 
                smooth: true 
                refresh: false;

            // Flow mesh using combined height
            mesh combined_height 
                scale: 3
                triangulation: true 
                color: palette(reverse(brewer_colors("Blues"))) 
                transparency: 0.5 
                no_data: 0.0;
        }
    }
}
