# Segmenting Arctic Hillslope Failures
## Math 76 Mathematics and AI Final Project
#### Christian Erikson, Kyrylo Bakumenko, Sonia Meytin, and Joshua Piesner

### Introduction

Arctic regions are warming as much as four times faster than the global average (Rantanen et al. 2022), creating the potential for rapid environmental change. Hillslope failures, such as permafrost thaw slumps, are an increasing signature of the new climatic regime on the landscape (Kokelj et al. 2021). Here, we track the growth of hillslope failures over time using image segmentation and compare our segemntation results to manually selected failure regions. By seeding segmentation regions, we extract failure areas from Sentinel-2 satellite imagery and quantify average growth rates during the summer season from 2019 to 2024. These growth rates serve as an estimate of carbon-rich sediments transitioning from colluvial to alluvial systems.

### Workflow
#### Data Preprocessing
We downloaded Sentinel-2 satellite images using the Google Earth Engine API at locations with hillslope failures using the `Sentinel_Download.py` script. We then selected the Red, Green, Blue, Near-Infrared, and Short Wave Infrared bands from the Sentinel rasters and established a naming convention using the `Process_TIFF.py` script. This script also created both true-color and false-color images to aid visualization.

#### Manual Segmentation
We created a validation dataset by interpolating between manually selected points on true-color imagery to isolate pixels within failure regions. We used these manual selections to compare the accuracy of automatic segmentation algorithms.

#### Julia Segmentation
To segment hillslope failures, we first created RGB imagery from the rasters of satillite data. We then used seeded segmentation, with seeds within and outside of the failed area, to classify failed pixels. We masked water using a normalized differnce water index to limit turbid water from being calssified as a hillslope failure. We also used a normalized difference vegetation index to restrict the possible failure area for early dates.

#### Python Segmentation
To segment slump development, we also generated Python scripts in parallel to those in Julia. One script mirrored the Julia script, importing its functions in order to process the data near-identically. The other script employed mean threshold segmentation and automatic threshold segmentation. With mean threshold segmentation, a threshold of 1.25 * the mean pixel value in the image was found to best segment the RGB images in grayscale. With automatic threshold segmentation, a threshold was generated using inbuilt functions in the Scikit Image package. These functions are not as robust as those in Julia, generating correspondingly rougher results.

#### Model Development
We used the Bayesian Information Criterion to inform best model subset selection on the manual validation data. We incorporated non-linear effects by including higher order variables of original features.

### Data Source

https://developers.google.com/earth-engine/datasets/catalog/COPERNICUS_S2_SR_HARMONIZED

### References

Kokelj, S. V., Kokoszka, J., van der Sluijs, J., Rudy, A. C. A., Tunnicliffe, J., Shakil, S., Tank, S. E., & Zolkos, S. (2021). Thaw-driven mass wasting couples slopes with downstream systems, and effects propagate through Arctic drainage networks. The Cryosphere, 15(7), 3059–3081. https://doi.org/10.5194/tc-15-3059-2021

Rantanen, M., Karpechko, A. Y., Lipponen, A., Nordling, K., Hyvärinen, O., Ruosteenoja, K., Vihma, T., & Laaksonen, A. (2022). The Arctic has warmed nearly four times faster than the globe since 1979. Communications Earth & Environment, 3(1), 1–10. https://doi.org/10.1038/s43247-022-00498-3
