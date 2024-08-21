# Segmenting Arctic Hillslope Failures
## Math 76 Mathematics and AI Final Project
#### Christian Erikson, Kyrylo Bakumenko, Sonia Meytin, and Joshua Piesner

### Introduction

As the fastest warming area of the world (IPCC, 2014), the Arctic is among the most sensitive regions to anthropogenic climate change. Arctic regions are warming as much as four times faster than the global average (Rantanen et al. 2022), creating the potential for rapid environmental change as semi-permanently frozen soils, known as permafrost, begin to thaw. The thawing of permafrost can destabilize hillslopes, leading to mass wasting and erosion and increasing sediment flux to the downstream watershed (Kokelj & Jorgenson, 2013; Kokelj et al., 2013). Hillslope failures such as permafrost thaw slumps, are an increasing as the climate warms (Kokelj et al. 2021), serving as a signature of the new climatic regime on the landscape. 

Sediment flux to river networks derived from hillslope failures is a particular concern because of the possibility of driving a climatic postive feedback (Lininger & Wohl, 2019). Permafrost is often carbon-rich, with the potential of releasing large amounts of carbon into atmospheric cycles as hillslopes are degraded. It is unclear whether sediment entering river networks from thawing permafrost will accelerate climate change by diminshing the largest terrestrial carbon stock, or if these sediments are redposited within the fluvial network with minimal effect (Douglas et al., 2022; Tank et al., 2023). Regardless of the possible pathways destabilized hillslope sediment may take, predicting the effects of thawing permafrost reqires estimates of the total hillslope derived sediment flux from failures. Depsite this need, most studies of arctic hillslope failures have either tracked changes in sediment flux with a local scope (Kokelj et al., 2013) or have braodly identified failures but without detailed analyses of sediment dynamics (Huang et al., 2023).

In order to address the need for estimates of hillslope derived sediment flux to fluvial networks, we track the growth of hillslope failures over time using image segmentation and compare our segemntation results to manually selected failure regions. By seeding segmentation regions, we extract failure areas from Sentinel-2 satellite imagery and quantify average growth rates during the summer season from 2019 to 2024. These growth rates serve as an estimate of carbon-rich sediments transitioning from colluvial to alluvial systems.

### Methods
##### Data Preprocessing
We performed image segmentation using Sentinel-2 harmonized surface reflectance satellite imagery. We download Sentinel-2 rasters using the Google Earth Engine Python API and selected the Red, Green, Blue, Near-Infrared, and Shortwave Infrared bands with the `Sentinel_Download.py` script. To create imagery more readily vizualized than in GeoTiff format, we created true color imagery using the Red, Green, and Blue bands (Figure 1), as in the script `Process_TIFF.py`. This script also established a naming convention and generated other band combinations. 

<figure>
    <center>
    <img src=Data/Sentinel-s002/RGB/RGB_2024-08-06.jpg width="200" height="100">
    <figcaption> <b>Figure 1</b>: RGB imagery of site s002. </figcaption>
    </center>
</figure>

Specific band combinations not produced by the inital processing was carried out with the `Select_Bands.py` script. This script allows for user specified band combinations. Importantly, when less than three bands are specified, the script constructs and image using a normalized difference index. Images based on both the Normalized Difference Vegetation Index (NDVI) and the Normalized Difference Water Index were created in this way for subsequent processing. 

We define NDVI as:

$$NDVI = \frac{Red - NIR}{Red + NIR}$$

and NDWI as:

$$NDWI = \frac{NIR - SWIR}{NIR + SWIR}$$

where NIR and SWIR are the Near-infrared and Shortwave Infrared bands, respectively.

NDVI serves a useful metric for identifiy image pixels with vegetation. NDWI similarly serves as a metric for identifying pixels with water. Each index acts like a probability score, with which the liklihood of a pixel being vegetation or water is approximated.

The processed satellite imagery with true-color (RGB) and NDVI images provided a dataset ready for segmentation. We selected images at five sites in the Canadian Arctic and Alaska using imagery from 2019-2024 during the range of June to September (Table 1). We selected images on a weekly basis with a cloud cover score less than 20%. Not all weeks had images meeting this criterion. For weeks with multiple images meeting this criterion, we used the image with the least cloud cover.

<center><b>Table 1</b>: Sampled Sites</center>

Site ID|Latitude|Longitude
---|:---:|---: 
s002|68.632100|-131.755200
s003|68.356460|-122.512000
s004|67.947201|-161.092834
s015|68.889200|-131.571700
s019|68.948500|-131.365400

##### Validation Data
To develop a validation dataset for comparing later segmentation algorithms, we randomly selected ten images from each site and manually clicked out the boundary of the failure (Figure 2 and `Manual_Segmentation.ipynb`). A line was interpolated between the clicked points to define the fialed region. In addition to the randomly sampled images, we manually segmented all images for site s002.

<figure>
    <center>
        <img src=Output/s002/RGB_2022-07-01_segmented.jpg>
        <figcaption><b>Figure 2</b>: Example manual segmentation.</figcaption>
    </center>
</figure>

##### Algorithim Comparison

We compared three main approaches to image segmentation. The first of these was using various algorithms in Python, including the Canny Edge Detection, Felzenswab, and Watershed algorithms. The second approach was using NDVI thresholding. Because hillslope failure are typically unvegetation, a threshold NDVI value may distinguish the failure from the sorrounding vegetated landscape. The third approach was using a series of masks on RGB imagery. Both the NDVI and RGB segmentation relied on seeded segmentation in the Julia programming language.

The performance of the Python-based algorithms was unsatisfactory (see `Sentinel.ipynb`) compared to the Julia-based algorithms, so we focus our discussion on the Julia segmentation.

*RGB Segmentation with Masks*

The `Julia_Segment.jl` script provides the main functionality for our image segmentation and is further detailed in the `Example_Segmentation.ipynb` notebook in the Examples folder. It works by generating an RGB image of each raster in a specified folder. Seed regions are selected and segmetation propogates from those seeds, classifying each pixel into one of the three. We are only interested in the classification of failed hillslope and not failed hillslope, but the third seed helps to account for the rivers in the image, which can prevent "not failed hillslope" areas from being continuous (Figure 3). The most recent image in the folder is always segmented first. This is that an NDVI mask of the, presumably, largest failure area is created. Because we expect failures to primarily grow with time, earlier failures where the seeded segmentation suggests the failure is larger than the temporally subsequent image are overlain with this NDVI mask. Within the mask, pixels of the current image below the threshold are selected, ensuring the number cannot be larger in earlier times. Otherwise, the seeded segmentation proceeds normally. The NDVI mask is updated with each sucessfully segmented image.

<figure>
    <center>
        <img src=Output/Segmentation_Example_Image.png width="200", height="200">
        <figcaption><b>Figure 3</b>: Basic RGB segmentation without application of any masks or thresholds.</figcaption>
    </center>
</figure>

After the images are segmented, and NDWI mask is applied to remove pixels were there is water. To create this mask, pixels above a threshold in an image where water was especially clear were dialted to form a continuous area. These pixels were then assigned a value of zero an multplied by the image matrix resulting from the segmentation, preserving only those pixel values with the "failed hillslope" label. After segmentation is complete, the script returns a table of the image dates and the number of pixels with the "failed hillslope" label, an optionally displays a heatmap of the failed area (Figure 4).

<figure>
    <center>
        <img src=Output/s003_heatmap.png width="300", height="200">
        <figcaption><b>Figure 4</b>: A heatmap showing slump growth at site s003. Darker colors are more recent times and brighter colors are earlier times.</figcaption>
    </center>
</figure>

*NDVI Segmentation*

The NDVI segmentation approach set an NDVI threshold and created a binary image. Values below the threshold were set to one whereas values below the threshold were set to zero. This creates a simple segmentation task, so we utlized the seeded segmentation framework we had already developed for RGB imagery. 

*Python-Based Mean Threshold Segmentation*

In addition to the above Python/Julia implementations of segmentation algorithms, we also attempted to segment the images using existing Python packages. After reviewing available resources, we concluded that Scikit Image was the best approach, as it operated in a similar way to SciKit Learn resources that we had previously used for MATH 76.01 homework assignments. The simplest method of segmentation available in this package is Mean Threshold Segmentation, where one would assign a segmentation threshold by which to separate a given image. Based on various trials, it was determined that a threshold of 1.25 * the mean pixel value of a given grayscale image would generally best match prior segmentation methods. 

*Python-Based Automatic Threshold Segmentation*

A further segmentation method explored through SciKit learn was Automatic Threshold Segmentation. This employs the package's inbuilt Otsu's Method to automatically segment an image. Results from this form of segmentation mirrored those achieved through previous segmentation methods. This method proved to be somewhat more consistently reliable than Mean Threshold Segmentation; as such, the Mean Threshold Segmentation value was retroactively adjusted to more closely align with Automatic Threshold Segmentation results.

##### Manual Data Analysis
Using the validation dataset created by manually segmenting the images, we explored failure growth sensitivity to time of year and latitude. To do this, we used best-subset selection on a series of linear models. Model parameters included were image month and year, and site latitude. We also included the possibility for non-linear effects by creating additional features as the square of month and year. The variable predicted was the total failed area normalized by the maximum failed area of the images for a given site, such that all sites could be compared. After year, we expected that vegetation would be the next most influential on segmentation by making failures appear smaller during the growing season. The best model was selected accoriding to the Bayesian Information Criterion. Data analysis was performed in the file `Threshold_Analysis.R`

### Results

##### Algorithm Comparison

#### Julia-Based Segmentation

Julia-based seeded segmentation had the best performance of the analyzed algorithms. Between the two Julia seeded segmentation approaches, the NDVI thresholding approach was able to achieve the lowest overall Root Mean Square Errors (RMSE), but only for specific failures. Across all sites, the NDVI thrsholding approach had an RSME of 0.007 square kilometers while the masking approach had and RMSE of 0.0002 square kilometers. Because of the higher general accuracy, remaining results are shown for the masking approach.

#### Python-Based Threshold Segmentation Comparison

Between the two Python-based threshold segmentation approaches, the Automatic Threshold Segmentation approach was able to more consistently achieve accurate results; due to software limitations, we were unable to calculate RMSE to confirm this, and instead confirmed manually through independent review. Individually, it is evident that both Python-based threshold segmentation approaches are somewhat viable, as they are able to semi-accurately segment images chosen from the data at random.

<figure>
    <center>
        <img src=Output/Fig5composite.png >
        <figcaption><b>Figure 5</b>: Individual Python-based threshold segmentation of a randomly-selected image from the data.</figcaption>
    </center>
</figure>

Notably, however, the Python-based threshold segmentation methods vary in their efficacy across timecourse data. Both methods (but most especially Automatic Threshold Segmentation) capture the seasonal changes in slump each year. This is evidenced by the plotting of slump size (in pixels) for each set of data/images over time: there is a distinct spike in the size every mid-year/summer and a dip every year-end/winter, likely due to snow coverage (discussed elsewhere in this writeup). General trends of increase and decrease in slump are also somewhat visible, but are more difficult to objectively quantify due to the variability of the data. This is compounded by the clear presence of large irregular spikes in the data, indicating outliers.

<figure>
    <center>
        <img src=Output/Fig6composite.png >
        <figcaption><b>Figure 6</b>: Changes in slump size over time, visualized by both Python-based threshold segmentation methods.</figcaption>
    </center>
</figure>

##### Growth Rates

Mean growth rates over the observation period vary between failures (Table 2). Three of the five failures show consistent growth, while the remaining two were mostly stagnant (Figure 5). These two show a rapid growth at the end. It is possible this is an artifact of the forced size being smaller at earlier times, but the resultant heatmaps do appear reasonable (see `Main_Segmentation.ipynb`).

<figure>
    <center>
        <img src=Output/Growth_Plots.png >
        <figcaption><b>Figure 7</b>: Results of the masked Julia-based seeded segmentation algorithm.</figcaption>
    </center>
</figure>

<center><b>Table 2</b>: Growth Rates</center>

Site ID|Growth Rate|Total Growth
---|:---:|---: 
s002|0.02580|0.1290
s003|0.00684|0.0342
s004|0.00764|0.0382
s015|0.15318|0.7659
s019|0.00366|0.0183

##### Best Model Subset Selection

The best model resulting from the subset selection was of the form:

$$y = a_0 (month) + a_1 (month^2) + b_0 (year^2) + c_0 (latitude) + d_0$$

where $y$ is the predicted normalized failure area, $month$ is the image month, $year$ is the year of the image, $latitude$ is the latitude of the site, $a$, $b$, and $c$ are coefficeints, and $d_0$ is the intercept.

We used the model to calcualte predicted values for purposes if vizualization (Figure). Model coefficients are listed in Table 2. They show that the failure size has a complex dependence on month, but that failure size is positively related to year and inversely related to latitude.

<figure>
    <center>
        <img src=Output/One_to_One_plot.png>
        <figcaption><b>Figure 8</b>: Comparison between measured data and predicted data using the model resulting from best subset selection. A one to one line is shown only for convinience.</figcaption>
    </center>
</figure>

<center><b>Table 3</b>: Best Model Coefficients</center>

Variable|Coefficeint|Relationship
---|:---:|---: 
month|-0.7057713|Inverse
month^2|0.04985282|Positive
year^2|1.654948e-05|Positive
latitude|-0.2663452|Inverse
intercept|-46.14890|

### Discussion

The seeded segmentation approach using NDVI and NDWI masks was the most generalizable model. This is likley because the approach enforces realistic results, realative to the best segmentations. If one image is segmented well, the rest will at least be similar to this one because of the mask. However, this does have the limitation of not capturing seasonal dynamics well. The manual segmentation shows that there is considerable intraannual change in failure area, likely due to vegetative growth and, in some cases, snow cover. A case where vegetation has not yet grown in the early season would not be well represented by this approach because it assumes that this earlier period must be smaller than the later, more vegetated, period. 

The NDVI threshold approach was able to perform best on a site specific basis, but, because different sites tended to have different appropriate NDVI thresholds, choosing the threshold best for one site did not translate well to other sites. The variance in thresholds between sites suggests that an adaptive NDVI threshold may lead to further improvements in the segmenting algorithms. The existing masking approach for example, may benefit from adjusting the NDVI mask based on time of year, to allow for larger failures when there would be less vegetation. Incorporating latitude into an adaptive model for NDVI threshold may also help to address the effects of snow cover.

Both Julia-based approaches vastly outperformed the Python based approaches, including a similar seeded approach in Python. This may be because of the complexity of the natural imagery, which made it difficult to detect areas cleanly bounded by edges. In contrast, using numerically represented matrices of color offered a simple and effective approach because of the sufficient contrast.

Within the Python-based approaches, it is evident that there is potential for more robust results in the future. However, available methods (both innate to Python packages and carried over from Julia) still severely underperform compared to segmentation in Julia due to a lower level of development, even in instances where results could be termed visually comparable. This is more evident in the Python-based threshold segmentation approaches than in the approaches most closely mirroring Julia-based ones. Future development of appropriate Python packages, as well as more comprehensive filtering of outliers (which currently cause unreliable spikes in the data), could potentially enable better analysis than is currently possible.

The image segmentation demonstrated that failure growth can be highly variable; growth rates of the failures spanned three orders of magnitude. This variability may partially reflect noise in the imagery and in the segmentation, but it is also probably a reflection of failure age. Although initiation dates were not considered here, it may be that older failures grew less during the observation period because they began to restablize, whereas recently initiated failure grew the most. Additionally, the location of failure may also control total growth because of factors like temperature and knickpoint retreat that could further destabilize one failure relative to another.

The inverse relationship between latitude and failure size is expected. As latitude increases, temperature decreases, which favors soils remaining frozen and being less suceptible to failure. The positive relationship between failure size and year is also expected; failure grow in time and are even known to be a persistent source of sediment long after inital disturbance in more temperate climates (Dethier et al., 2016).

### Conclusion

We segmented arctic hillslope failures using image segmentation. We found that seeded segmentation which utilized Normalized Difference Indicies was the most generalizable. Growth rates across sites within Canada and Alaska show considerable variation. Such variation indicates that sediment fluxes in these regions is likely to be site specific. We also observed a vegetative effect that complicates intra-annual failure size predictions; failures do not always grow in a linear or monotonic fashion. 

### Learning Outcomes and Contribution Statements

This project revealed the sensitivity of different algorithms to the data being used and performance across languages. Julia's relativley less developed ecosystem of packages was not anticipated to outperform Python, yet was much easier to use and had better results.

While Python's segmentation was not preferred, Python's capabilities for handling rasters was much simpler to use than Julia's. Resultantly, the main code uses calls between languages for processing.

Similarly, the sensitvity of the algorithms to data quality was more than expected. Cloudy images needed to be manually removed because they drastically impacted results.

Best subset selection was found to be suprisingly efficient. Although it become coputational expensive, best subset selection with the five variables usd was quite fast.

Christian wrote the code for data preprocessing, Julia-based image segmenation, and data analysis, and performed manual validation. Kyrylo wrote the code for manual validation. Sonia worked on Python-based image segmentation, wrote the code for Python-based threshold segmentation, and data analysis. Josh worked on validating Julia code and assisting with manual validation.

### References

Dethier, E. N., Magilligan, F. J., Renshaw, C. E., & Nislow, K. H. (2016). The role of chronic and episodic disturbances on channel–hillslope coupling: The persistence and legacy of extreme floods. Earth Surface Processes and Landforms, 41(10), Article 10. https://doi.org/10.1002/esp.3958

Douglas, M. M., Li, G. K., Fischer, W. W., Rowland, J. C., Kemeny, P. C., West, A. J., Schwenk, J., Piliouras, A. P., Chadwick, A. J., & Lamb, M. P. (2022). Organic carbon burial by river meandering partially offsets bank erosion carbon fluxes in a discontinuous permafrost floodplain. Earth Surface Dynamics, 10(3), 421–435. https://doi.org/10.5194/esurf-10-421-2022

Huang, L., Willis, M. J., Li, G., Lantz, T. C., Schaefer, K., Wig, E., Cao, G., & Tiampo, K. F. (2023). Identifying active retrogressive thaw slumps from ArcticDEM. ISPRS Journal of Photogrammetry and Remote Sensing, 205, 301–316. https://doi.org/10.1016/j.isprsjprs.2023.10.008

IPCC, 2014. Climate Change 2014: Synthesis Report. Contribution of Working Groups I, II, III to the Fifth Assessment Report of the Intergovernmental Panel on Climate Change. IPCC, Geneva, Switzerland.

Kokelj, S. V., Kokoszka, J., van der Sluijs, J., Rudy, A. C. A., Tunnicliffe, J., Shakil, S., Tank, S. E., & Zolkos, S. (2021). Thaw-driven mass wasting couples slopes with downstream systems, and effects propagate through Arctic drainage networks. The Cryosphere, 15(7), 3059–3081. https://doi.org/10.5194/tc-15-3059-2021

Kokelj, S. V., & Jorgenson, M. T. (2013). Advances in Thermokarst Research. Permafrost and Periglacial Processes, 24(2), 108–119. https://doi.org/10.1002/ppp.1779

Kokelj, S. V., Lacelle, D., Lantz, T. C., Tunnicliffe, J., Malone, L., Clark, I. D., & Chin, K. S. (2013). Thawing of massive ground ice in mega slumps drives increases in stream sediment and solute flux across a range of watershed scales. Journal of Geophysical Research: Earth Surface, 118(2), 681–692. https://doi.org/10.1002/jgrf.20063

Lininger, K. B., & Wohl, E. (2019). Floodplain dynamics in North American permafrost regions under a warming climate and implications for organic carbon stocks: A review and synthesis. Earth-Science Reviews, 193, 24–44. https://doi.org/10.1016/j.earscirev.2019.02.024

Rantanen, M., Karpechko, A. Y., Lipponen, A., Nordling, K., Hyvärinen, O., Ruosteenoja, K., Vihma, T., & Laaksonen, A. (2022). The Arctic has warmed nearly four times faster than the globe since 1979. Communications Earth & Environment, 3(1), 1–10. https://doi.org/10.1038/s43247-022-00498-3

Tank, S. E., McClelland, J. W., Spencer, R. G. M., Shiklomanov, A. I., Suslova, A., Moatar, F., Amon, R. M. W., Cooper, L. W., Elias, G., Gordeev, V. V., Guay, C., Gurtovaya, T. Y., Kosmenko, L. S., Mutter, E. A., Peterson, B. J., Peucker-Ehrenbrink, B., Raymond, P. A., Schuster, P. F., Scott, L., … Holmes, R. M. (2023). Recent trends in the chemistry of major northern rivers signal widespread Arctic change. Nature Geoscience, 16(9), Article 9. https://doi.org/10.1038/s41561-023-01247-7
