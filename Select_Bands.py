import numpy as np
import rasterio
from PIL import Image

def select_bands(file_path, bands, output_path):
    with rasterio.open(file_path) as src:
        if len(bands) == 2:
            # Read the specified bands for NDVI-like calculation
            band1 = src.read(bands[0]).astype(np.float32)
            band2 = src.read(bands[1]).astype(np.float32)

            # Calculate the normalized difference index
            normalized_index = (band1 - band2) / (band1 + band2 + 1e-10)  # Add small value to avoid division by zero

            # Normalize to range [0, 1] for display
            normalized_index_scaled = (normalized_index + 1) / 2  # Shift to range [0, 1]

            # Convert to uint8
            normalized_index_uint8 = (normalized_index_scaled * 255).astype(np.uint8)

            # Create a grayscale image from the array
            final_image = Image.fromarray(normalized_index_uint8)

        elif len(bands) == 3:
            # Create a list to hold the selected bands for RGB image
            selected_bands = [src.read(band).astype(np.float32) for band in bands]

            # Stack the selected bands into an image
            stacked_image = np.stack(selected_bands, axis=-1)

            # Normalize the image to the range [0, 1] for display
            stacked_normalized = stacked_image / np.max(stacked_image)

            # Convert to uint8
            stacked_normalized_uint8 = (stacked_normalized * 255).astype(np.uint8)

            # Create an RGB image from the array
            final_image = Image.fromarray(stacked_normalized_uint8)

        else:
            raise ValueError("Please specify either two bands for NDVI-like normalization or three bands for RGB image.")

        # Save as JPEG
        final_image.save(output_path, format='JPEG')

    return output_path
