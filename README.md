# Geographical Agent-Based Modeling for Rainfall-Runoff Simulation: A Case Study of the Small Catchment Area of Bagmati River, Nepal
## INTRODUCTION
In recent years, Nepal has experienced increasing rainfall in many regions, leading to flooding even in areas with traditionally low precipitation. Understanding streamflow and runoff patterns is crucial to anticipate the peak river overflows that cause such flooding. The Bagmati River, a key contributor to urban flooding in Kathmandu during the monsoon, highlights the need to study the relationship between rainfall and water levels. This project focuses on a portion of the Bagmati catchment area to develop and validate a runoff model that examines this critical relationship. Using precipitation sensor data and river water level measurements, the research aims to address the question: How accurately can a runoff model simulate real-world hydrological dynamics through an agent-based modelling approach? The primary objective is to create an agent-based model capable of simulating runoff dynamics for the Bagmati River and validate its accuracy by comparing simulated outcomes with observed data. This work seeks to advance our understanding of flood dynamics and improve predictive capabilities in similar contexts.

## Study Area
Bagmati River lies in the northern path of Nepal, and a catchment area of approximately 38 km² was delineated to analyze rainfall runoff processes. The catchment includes two main streams, Bagmati and Nagmati, with Nagmati merging into the Bagmati River at a central point within the study area.

## METHOD
**Data Collection and Preparation**
The following data were collected and pre-processed to fed into the model.
a.	Watershed Boundary: The watershed boundary for the study area was delineated manually in Google Earth.

b.	Digital Elevation Model (DEM): The 30m SRTM DEM were downloaded from USGS earth explorer portal. Then, the data was clipped using the watershed boundary and projected into a projected coordinate system i.e. WGS 84 /UTM zone 44N (EPSG: 32644).

c.	River Network: The river network data were downloaded from HDX (Humanterian Data Exchange) portal. The raw data contained of several breakages along the river, making it incomplete. To address this, the data were overlaid on the OpenStreetMap (OSM) base map, and the final continuous and complete river networks within the catchment area were created. The finalized river network was buffered by 5m and then exported into three separate layers: one for the Bagmati River, one for the Nagmati River, and a third representing the combined network after rever merges at their confluence. In addition to this, starting water points for both rivers were marked in google earth. All these datasets were projected into the EPSG: 32644 projected coordinate system.

d.	Precipitation and WaterLevel Data: Precipitation and water level data were obtained from the DHM (Department of Hydrology and Meteorology) web portal for the period from March to November 2024. The raw precipitation data was provided in columns for 1, 3, 6, 12, and 24-hour intervals, with values separated by commas for each hour of the day. However, the dataset contained duplicates and missing values. To address this, a Python script was created to clean the data by removing duplicates, filling in missing values through interpolation, and exporting the data in an hourly format. Similarly, water level data was recorded every 15 minutes, and a script was developed to average the data to an hourly scale while also using the interpolation method to fill in any missing values.

**The scripts are available in the data_preparation folder of the project.**

**UML Diagram**
Figure 1 represents the UML diagram for the rainfall runoff simulation process. The model is initialized by loading DEM, rainfall, and river stations and river networks. The rainfall station agent is responsible for retrieving and providing the rainfall data at regular intervals and distributes it to the cell agents, and the water level station agent is responsible for measuring the water level. These agents serve as input sources for the simulation, influencing the water height within the grid cells and the water flow direction. The cell agents then go through infiltration, where a portion of the water infiltrates into the soil, and the remainder contributes to runoff, which is transferred to neighboring cell agents based on topographic elevation. These cell agents update their water height based on the flow calculations, ensuring that water moves from higher to lower elevation cells. Finally, the water level station agent periodically measures the water levels at specific locations, capturing the changes in water height throughout the simulation. This cycle occurs at each time step, continuously simulating the hydrological processes of rainfall, infiltration, runoff, and water level changes in the environment.
Model 
<img width="1000" alt="image" src="https://github.com/user-attachments/assets/f47929a6-06f4-493a-98a3-90fab085c26f" />

## OUTPUT GAMA MODEL
<img width="1469" alt="Screenshot 2568-03-05 at 12 58 53" src="https://github.com/user-attachments/assets/912c1ccd-d09c-44c3-9208-f9b159355338" />

## DISCUSSION
The simulation effectively provided insights into the complex interactions between rainfall and terrain,
demonstrating how precipitation contributes to streamflow dynamics. By incorporating a spatial
perspective, the model successfully identified rainfall flow patterns and terrain-specific behaviors,
enhancing its contextual relevance. The results are generally plausible, as they align with expected
hydrological behaviors, but certain limitations affected accuracy. The use of a low-resolution DEM may
have led to less precise terrain representation, while the limited number of ground precipitation stations
restricted the model’s ability to capture spatial variability in rainfall. Additionally, factors such as
infiltration, evapotranspiration, land cover types, and human-made structures like dams introduced
uncertainties that could influence the accuracy of predictions. The study reinforced the importance of terrain
characteristics in shaping water flow and highlighted how spatial data analysis helps reveal hydrological
patterns that might otherwise go unnoticed.
Despite these insights, some questions remain open. The extent to which these limitations impact the final
model accuracy is not fully quantified, and future work could explore how integrating higher-resolution
datasets and additional hydrological factors such as soil moisture and vegetation cover—would enhance
model performance. Furthermore, refining calibration and validation steps could improve the reliability of
predictions. Addressing these challenges will be crucial for advancing hydrological modeling techniques
and ensuring more accurate assessments of rainfall-driven streamflow dynamics.
