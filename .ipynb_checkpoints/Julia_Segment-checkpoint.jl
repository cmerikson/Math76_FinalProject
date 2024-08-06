using Images, ImageView, ImageSegmentation, ImageDraw, FileIO, Plots, PyCall

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
function count_pixels(file_path::String, Seed1::Tuple{Int64,Int64}, Seed2::Tuple{Int64,Int64}; Seed3::Union{Nothing, Tuple{Int64,Int64}} = nothing, Seed4::Union{Nothing, Tuple{Int64,Int64}} = nothing, Display::Bool = false, crop_size::Union{Nothing, Tuple{Int, Int}}=nothing, mods::Union{Nothing, Vector{Tuple{Real, Real, Vararg{Float64}}}}=nothing)
    if endswith(file_path, ".jpg")
        img = load(file_path)
        if crop_size != nothing
            img = crop_center(img, crop_size)
        end

        if mods != nothing
            img = draw_line(img, mods)
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
function segmented_object(file_path::String, Seed1::Tuple{Int64,Int64}, Seed2::Tuple{Int64,Int64}; Seed3::Union{Nothing, Tuple{Int64,Int64}} = nothing, Seed4::Union{Nothing, Tuple{Int64,Int64}} = nothing, crop_size::Union{Nothing, Tuple{Int, Int}}=nothing, mods::Union{Nothing, Vector{Tuple{Real, Real, Vararg{Float64}}}}=nothing)
    if endswith(file_path, ".jpg")
        img = load(file_path)
        if crop_size != nothing
            img = crop_center(img, crop_size)
        end

        if mods != nothing
            img = draw_line(img, mods)
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
