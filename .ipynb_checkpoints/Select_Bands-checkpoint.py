import numpy as np
import rasterio
from PIL import Image

def select_bands(file_path, output_path, bands):
    with rasterio.open(file_path) as src:
        # Read the affine transform to get the pixel size
        transform = src.transform
        pixel_width = transform[0]
        pixel_height = -transform[4]

        # Create a list to hold the selected bands
        selected_bands = []

        # Read and append each selected band
        for band in bands:
            selected_bands.append(src.read(band).astype(np.float32))

        # Stack the selected bands into an image
        stacked_image = np.stack(selected_bands, axis=-1)

        # Normalize the image to the range [0, 1] for display
        stacked_normalized = stacked_image / np.max(stacked_image)

        # Convert to uint8
        stacked_normalized_uint8 = (stacked_normalized * 255).astype(np.uint8)

        # Create an image from the array
        final_image = Image.fromarray(stacked_normalized_uint8)

        # Save as JPEG
        final_image.save(output_path, format='JPEG')

    return output_path