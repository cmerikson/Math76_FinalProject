using Images, ImageView, ImageSegmentation, ImageDraw, ImageMorphology, FileIO, Plots, PyCall, Glob, DataFrames, Dates

# Function for calling band selection from python script
function select_bands(file::String, bandA::Int, bandB::Int, bandC::Union{Nothing, Int}, output::String)
    py_file_path = joinpath(@__DIR__, "Select_Bands.py")
    @pyinclude(py_file_path)
    py"select_bands"(file,bandA,bandB,bandC,output)
end

# Function for cropping image for dimensional consistency
function crop_center(img::AbstractArray, crop_size::Tuple{Int, Int})
    img_height, img_width = size(img)
    crop_height, crop_width = crop_size
    center_y, center_x = div(img_height, 2), div(img_width, 2)
    
    top = max(1, center_y - div(crop_height, 2))
    bottom = min(img_height, center_y + div(crop_height, 2))
    left = max(1, center_x - div(crop_width, 2))
    right = min(img_width, center_x + div(crop_width, 2))
    
    return img[top:bottom, left:right]
end

#Function to preview imagery and select coordinates
function preview(file::String; crop_size::Union{Nothing, Tuple{Int, Int}}=nothing)
    img = load(file)
    if crop_size != nothing
        img = crop_center(img, crop_size)
    end
    imshow(img)
end

# Function to draw line on image
function draw_line(img::AbstractArray, modifications::Vector{Tuple{Real, Real, Vararg{Float64}}})
    if eltype(img) <: Gray
        img = colorview(RGB, img, img, img)
    end
    
    line = LineSegment(CartesianIndex(modifications[1][1],modifications[1][2]), CartesianIndex(modifications[2][1],modifications[2][2]))
    color = RGB{N0f8}(modifications[3][1], modifications[3][2], modifications[3][3])
    temp = copy(img)
    temp = draw!(temp, line, color)
    return temp
end

# Function to display segments with a title
function display_segments(segments, file_path::String)
    segment = map(i -> segment_mean(segments, i), labels_map(segments))
    file_name = splitext(basename(file_path))[1]
    title_text = last(file_name, 10)
    plot_title = "$title_text"
    plot = Plots.plot(segment, framestyle=:none, title=plot_title)
    display(plot)
end

# Function to get pixel count of segmented area
function count_pixels(file_path::String, Seed1::Tuple{Int64,Int64}, Seed2::Tuple{Int64,Int64}; Seed3::Union{Nothing, Tuple{Int64,Int64}} = nothing, Seed4::Union{Nothing, Tuple{Int64,Int64}} = nothing, Display::Bool = false, crop_size::Union{Nothing, Tuple{Int, Int}}=nothing, mods::Union{Nothing, Vector{Tuple{Real, Real, Vararg{Float64}}}}=nothing, water_mask::Union{Nothing, BitMatrix}=nothing)
    if endswith(file_path, ".jpg")
        img = load(file_path)
        if crop_size != nothing
            img = crop_center(img, crop_size)
        end

        if mods != nothing
            img = draw_line(img, mods)
        end

        if water_mask != nothing
            img = img .* water_mask
        end
        
        if Seed3 == nothing && Seed4 == nothing
            seeds = [(CartesianIndex(Seed1),1), (CartesianIndex(Seed2),2)]
        elseif Seed3 != nothing && Seed4 == nothing
            seeds = [(CartesianIndex(Seed1),1), (CartesianIndex(Seed2),2), (CartesianIndex(Seed3),3)]
        else
            seeds = [(CartesianIndex(Seed1),1), (CartesianIndex(Seed2),2), (CartesianIndex(Seed3),3), (CartesianIndex(Seed4),4)]
        end
        
        segments = seeded_region_growing(img, seeds)    
        pixel_dict = segment_pixel_count(segments)
        pixel_count = pixel_dict[:1]
        
        if Display
            display_segments(segments,file_path)
        end

        println("The segemented region contains $pixel_count pixels.")
        return pixel_count
    else
        println("File is not a .jpg: $file_path")
        return nothing
    end
end

# Function for returning segmented object
function segmented_object(file_path::String, Seed1::Tuple{Int64,Int64}, Seed2::Tuple{Int64,Int64}; Seed3::Union{Nothing, Tuple{Int64,Int64}} = nothing, Seed4::Union{Nothing, Tuple{Int64,Int64}} = nothing, crop_size::Union{Nothing, Tuple{Int, Int}}=nothing, mods::Union{Nothing, Vector{Tuple{Real, Real, Vararg{Float64}}}}=nothing, water_mask::Union{Nothing, BitMatrix}=nothing)
    if endswith(file_path, ".jpg")
        img = load(file_path)
        if crop_size != nothing
            img = crop_center(img, crop_size)
        end

        if mods != nothing
            img = draw_line(img, mods)
        end

        if water_mask != nothing
            img .* water_mask
        end
        
        if Seed3 == nothing && Seed4 == nothing
            seeds = [(CartesianIndex(Seed1),1), (CartesianIndex(Seed2),2)]
        elseif Seed3 != nothing && Seed4 == nothing
            seeds = [(CartesianIndex(Seed1),1), (CartesianIndex(Seed2),2), (CartesianIndex(Seed3),3)]
        else
            seeds = [(CartesianIndex(Seed1),1), (CartesianIndex(Seed2),2), (CartesianIndex(Seed3),3), (CartesianIndex(Seed4),4)]
        end
        
        segments = seeded_region_growing(img, seeds)    
        
        return segments
    end
end

function segment_mask(folder::String, Seed1::Tuple{Int64,Int64}, Seed2::Tuple{Int64,Int64}; Seed3::Union{Nothing, Tuple{Int64,Int64}} = nothing, Seed4::Union{Nothing, Tuple{Int64,Int64}} = nothing, Display::Bool = false, ndvi_threshold::Float64 = 1.0, ndwi_threshold::Float64 = 0.65, ndwi_image::Union{Nothing, String}=nothing, crop_size::Union{Nothing, Tuple{Int, Int}}=nothing, mods::Union{Nothing, Vector{Tuple{Real, Real, Vararg{Float64}}}}=nothing)
    
    # Get all files with tif extension
    files = glob("*.tif", folder)
    
    if isempty(files)
        println("No files found. Check folder path and file naming conventions.")
        return nothing
    end

    date_format = DateFormat("yyyy-mm-dd")
    
    # Function to extract and parse date from the last ten characters of filename
    function extract_date(filename)
        base = basename(filename) # Remove folder path
        date_str = base[11:20] # Get the last ten characters excluding extension
        return Date(date_str, date_format) # Parse date
    end

    # Sort files by the extracted date in reverse order
    sorted = sort(files, by = x -> extract_date(x), rev = true)

    file_count = length(sorted)

    # Initialize result storage
    results = DataFrame()
    mask = nothing
    outlines = heatmap(framestyle=:none)
    masks = 0

    # Create a temporary directory
    temp_dir = mktempdir()

    # NDWI Water Mask
    if ndwi_image != nothing
        selected_image = filter(s -> occursin(ndwi_image, s), files)
        if length(selected_image) == 1
            selected_image = first(selected_image) # Convert from :Vector{String} to ::String
            ndwi_path = select_bands(selected_image, 5,4,nothing, joinpath(temp_dir, "ndwi.jpg"))
            ndwi = load(ndwi_path)
            binary_ndwi = ndwi .> ndwi_threshold
            water_mask = .!dilate(binary_ndwi)
        elseif length(selected_image) > 1
            error("Error: There are multiple files with names matching the image selected for water masking.")
        elseif length(selected_image) == 0
            error("Error: Provided raster for water mask not found.")
        end
    else
        print("Defaulting to no water mask.")
        water_mask = 1.0
    end

    # Main Segmentation
    for i in [1:1:file_count;]
        rgb_path = select_bands(sorted[i], 1,2,3, joinpath(temp_dir, "rgb.jpg"))
        ndvi_path = select_bands(sorted[i], 4,1,nothing, joinpath(temp_dir, "ndvi.jpg"))

        date = extract_date(sorted[i])

        if i == 1
            pixel_count = count_pixels(rgb_path, Seed1, Seed2, Seed3=Seed3, Seed4=Seed4, Display=false, crop_size=crop_size, mods=mods) 
            
            row = DataFrame(Date=date, Pixels=pixel_count)
            append!(results, row)
            segments = segmented_object(rgb_path, Seed1, Seed2, Seed3=Seed3, crop_size=crop_size, mods=mods)
            mask = labels_map(segments) .== 1
            mask = mask .* water_mask

            if Display
                masks = masks .+ mask
                outlines = heatmap!(reverse(masks, dims=1))
            end
        end

        if i > 1
            constraint = results[i-1, "Pixels"]
            tentative = count_pixels(rgb_path, Seed1, Seed2, Seed3=Seed3, Seed4=Seed4, Display=false, crop_size=crop_size, mods=mods) 
            
            if tentative <= constraint
              row = DataFrame(Date=date, Pixels=tentative)
              append!(results, row)
              segments = segmented_object(rgb_path, Seed1, Seed2, Seed3=Seed3, crop_size=crop_size, mods=mods)
              mask = labels_map(segments) .== 1
              mask = mask .* water_mask
              if Display
                masks = masks .+ mask
                outlines = heatmap!(reverse(masks, dims=1))
              end
            end

            if tentative > constraint
                # Get NDVI of current image
                NDVI = load(ndvi_path)

                if ndvi_threshold < 1.0
                    # Binarize
                    NDVI = (NDVI .> ndvi_threshold)
                end

                if crop_size != nothing
                    NDVI = crop_center(NDVI, crop_size)
                end
                
                # Mask NDVI of current image by area of previous image
                Masked_NDVI = mask .* NDVI .* water_mask
                
                # Tally pixels meeting criterion within masked area
                pixel_count = count(x -> x != 0, Masked_NDVI)

                # Add to table and update mask
                row = DataFrame(Date=date, Pixels=pixel_count)
                append!(results, row)

                if Display
                    # Convert Masked_NDVI to binary values
                    binary_Masked_NDVI = Masked_NDVI .> 0
                    masks = masks .+ binary_Masked_NDVI
                    outlines = heatmap!(reverse(masks, dims=1))
                end
            end
        end
    end

    # Clean up by deleting the temporary directory and its contents
    rm(temp_dir, recursive=true)

    if Display
        display(outlines)
    end
    
    #results.Date = Date.(results.Date, "yyyy-mm-dd")
    results = sort!(results, :Date)
end