import rasterio
import numpy as np
import matplotlib.pyplot as plt
from PIL import Image
import os
import glob

def calculate_ndvi(file_path, threshold=False, display=False, metadata_list=None):
    # Extract the base name and last 10 digits before the file extension
    base_name = os.path.basename(file_path)
    dir_name = os.path.dirname(file_path)
    name, ext = os.path.splitext(base_name)

    # Define subfolder paths
    ndvi_folder = os.path.join(dir_name, "NDVI")
    rgb_folder = os.path.join(dir_name, "RGB")
    rgba_folder = os.path.join(dir_name, "RGBA")  
    ndwi_folder = os.path.join(dir_name, "NDWI")
    
    # Create subfolders if nonexistent
    os.makedirs(ndvi_folder, exist_ok=True)
    os.makedirs(rgb_folder, exist_ok=True)
    os.makedirs(rgba_folder, exist_ok=True)
    os.makedirs(ndwi_folder, exist_ok=True)

    # Define file names and paths
    ndvi_name = f"NDVI_{name[-10:]}.jpg"
    rgb_name = f"RGB_{name[-10:]}.jpg"
    rgba_name = f"RGBA_{name[-10:]}.png"  # Save RGBA as PNG
    ndwi_name = f"NDWI_{name[-10:]}.jpg"
    
    ndvi_path = os.path.join(ndvi_folder, ndvi_name)
    rgb_path = os.path.join(rgb_folder, rgb_name)
    rgba_path = os.path.join(rgba_folder, rgba_name)
    ndwi_path = os.path.join(ndwi_folder, ndwi_name)

    with rasterio.open(file_path) as src:
        # Read the affine transform to get the pixel size
        transform = src.transform
        pixel_width = transform[0]
        pixel_height = -transform[4]
        
        # Get width, height, and CRS
        width = src.width
        height = src.height
        crs = src.crs

        # Append pixel resolution information to the metadata list
        if metadata_list is not None:
            metadata_list.append({
                'file': base_name,
                'pixel_width': pixel_width,
                'pixel_height': pixel_height,
                'width': width,
                'height': height,
                'crs': crs
            })

        # Read the RGB bands (Band order: Red, Green, Blue, NIR, SWIR)
        blue = src.read(3).astype(np.float32)
        green = src.read(2).astype(np.float32)
        red = src.read(1).astype(np.float32)
        nir = src.read(4).astype(np.float32)
        swir = src.read(5).astype(np.float32)

        # Stack the bands into an RGB image
        rgb = np.stack((red, green, blue), axis=-1)

        # Normalize the RGB image to the range [0, 1] for display
        rgb_normalized = rgb / np.max(rgb)

        # Save RGB as JPEG
        rgb_normalized_uint8 = (rgb_normalized * 255).astype(np.uint8)
        rgb_image = Image.fromarray(rgb_normalized_uint8)
        rgb_image.save(rgb_path)

        # Display the RGB image
        if display:
            plt.figure(figsize=(10, 10))
            plt.imshow(rgb_normalized)
            plt.title('RGB Image')
            plt.axis('off')
            plt.show()

        # Calculate NDVI
        ndvi = (nir - red) / (nir + red)

        # Handle NaNs and Infs
        ndvi[np.isnan(ndvi)] = 0.0
        ndvi[np.isinf(ndvi)] = 0.0

        # Calculate NDWI
        ndwi = (nir - swir) / (nir + swir)

        # Handle NaNs and Infs
        ndwi[np.isnan(ndwi)] = 0.0
        ndwi[np.isinf(ndwi)] = 0.0

        # Apply threshold if provided
        if threshold is not False:
            ndvi = np.where(ndvi < threshold, 1, 0)

        # Normalize NDVI to the range [0, 255] for saving as an image
        ndvi_normalized = ((ndvi - np.min(ndvi)) / (np.max(ndvi) - np.min(ndvi)) * 255).astype(np.uint8)
        ndwi_normalized = ((ndwi - np.min(ndwi)) / (np.max(ndwi) - np.min(ndwi)) * 255).astype(np.uint8)
        
        # Save NDVI as JPEG
        ndvi_image = Image.fromarray(ndvi_normalized)
        ndvi_image.save(ndvi_path)

        ndwi_image = Image.fromarray(ndwi_normalized)
        ndwi_image.save(ndwi_path)

        # Display NDVI
        if display:
            plt.figure()
            plt.imshow(ndvi_normalized, cmap='RdYlGn')
            plt.colorbar()
            plt.title('NDVI')
            plt.axis('off')
            plt.show()

        # Create an alpha channel based on NDVI or NIR threshold
        alpha = (ndvi < 0.5).astype(np.uint8) * 255

        # Stack RGB and Alpha to create RGBA
        rgba = np.dstack((rgb_normalized_uint8, alpha))

        # Save RGBA as PNG
        rgba_image = Image.fromarray(rgba, 'RGBA')
        rgba_image.save(rgba_path)

        # Display the RGBA image
        if display:
            plt.figure(figsize=(10, 10))
            plt.imshow(rgba)
            plt.title('RGBA Image')
            plt.axis('off')
            plt.show()

    print(f"NDVI image saved as {ndvi_name}")
    print(f"RGBA image saved as {rgba_name}")

def process_folder(path, threshold=False):
    metadata_list = []
    # Find all TIFF files in the input directory
    tiff_files = glob.glob(os.path.join(path, "*.tif"))

    # Loop over each file and process it
    for tiff_file in tiff_files:
        print(f"Processing {tiff_file}")
        calculate_ndvi(tiff_file, threshold=threshold, metadata_list=metadata_list)

    # Save all metadata to a single file
    metadata_path = os.path.join(path, "metadata.txt")
    with open(metadata_path, 'a') as f:  # Append mode
        for metadata in metadata_list:
            f.write(f"File: {metadata['file']}\n")
            f.write(f"Pixel width: {metadata['pixel_width']} meters\n")
            f.write(f"Pixel height: {metadata['pixel_height']} meters\n")
            f.write(f"Width: {metadata['width']} pixels\n")
            f.write(f"Height: {metadata['height']} pixels\n")
            f.write(f"CRS: {metadata['crs']}\n")
            f.write("\n")

def process_file(path, threshold=False):
    metadata_list = []
    print(f"Processing {path}")
    calculate_ndvi(path, threshold=threshold, metadata_list=metadata_list)

    # Save metadata to a single file
    dir_name = os.path.dirname(path)
    metadata_path = os.path.join(dir_name, "metadata.txt")
    with open(metadata_path, 'a') as f:  # Append mode
        for metadata in metadata_list:
            f.write(f"File: {metadata['file']}\n")
            f.write(f"Pixel width: {metadata['pixel_width']} meters\n")
            f.write(f"Pixel height: {metadata['pixel_height']} meters\n")
            f.write(f"Width: {metadata['width']} pixels\n")
            f.write(f"Height: {metadata['height']} pixels\n")
            f.write(f"CRS: {metadata['crs']}\n")
            f.write("\n")
