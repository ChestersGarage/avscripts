#!/bin/bash

# Chops up a panoramic image into frames and reassembles as a short video
# Put this script into a separate folder and run against a file outside of it
# All files will be created in current working folder.

if [[ -z $1 ]]
then
    echo "At least give me a file name!"
    exit 1
fi

# We at least need the file name, including full or relative path.
pano_file_name=$1
# One of up, down, left or right
pan_direction=${2:-right}
# Each frame is this many px to the right of, or above, the prior frame
increment=${3:-25}
# Set frame rate to 30 if not specified
framerate=${4:-30}
# Set the first frame to bigger than zero
cut_from_start=${5:-0}
# Set the last frame by cutting off this many from the end
cut_from_end=${6:-0}

# Aspect ratio
aspect_width=16
aspect_height=9

# Can be any file type compatible with H265 video.
output_file_extension="mkv"

# We need to know the file name bits in order to create the output file name.
pano_file_extension=$(basename ${pano_file_name} | cut -d '.' -f 2)
output_file="$(basename -s .${pano_file_extension} ${pano_file_name})"

# Need to know the dimensions of the pano
pano_geometry=$(magick identify ${pano_file_name} 2>> make-pan-error.log | awk '{ print $3 }')
pano_width=$(echo ${pano_geometry} | cut -d x -f 1)
pano_height=$(echo ${pano_geometry} | cut -d x -f 2)

# We want the pano wide enough for at least one second of video
verify_wide(){
    min_width=$(( (($pano_height / $aspect_height) * $aspect_width) + ( $framerate * $increment) ))
    if [[ ${pano_width} -lt ${min_width} ]]
    then
        echo "Not enough frames for at least 1 second of video."
        echo "Reduce increment or framerate, or get a wider panorama."
        exit 1
    fi
}

# We want the pano tall enough for at least one second of video
verify_tall(){
    min_height=$(( (($pano_width / $aspect_width) * $aspect_height) + ( $framerate * $increment) ))
    if [[ ${pano_height} -lt ${min_height} ]]
    then
        echo "Not enough frames for at least 1 second of video."
        echo "Reduce increment or framerate, or get a taller panorama."
        exit 1
    fi
}

# When panning horizontally, assume frame height is the same as the pano
# Derive the width from the height, and count how many fit in the pano
set_h_framing(){
    frame_height=$pano_height
    frame_width=$(( ($pano_height / $aspect_height) * $aspect_width ))
    frame_all=$(( ($pano_width - $frame_width) / $increment ))
}

# When panning vertically, assume frame width is the same as the pano
# Derive the height from the width, and count how many fit in the pano
set_v_framing(){
    frame_width=$pano_width
    frame_height=$(( ($pano_width / $aspect_width) * $aspect_height ))
    frame_all=$(( ($pano_height - $frame_height) / $increment ))
}

# Chop up the pano into still frames
make_frames(){
    frame=$(( $cut_from_start ))
    frame_position=$(( $frame * $increment ))
    frame_count=$(( $frame_all - $cut_from_start - $cut_from_end ))
    frame_last=$(( $cut_from_start + $frame_count ))

    echo ""
    echo "Panorama size: $pano_width x $pano_height; $frame_all total possible frames."
    echo "Raw frame size: $frame_width x $frame_height (will be scaled to 1920 x 1080)"
    echo "Approximate video length: $(( $frame_count / $framerate )).$(( ($frame_count % $framerate) * 10 / $framerate )) second(s); $frame_count frames."
    echo "Starting at frame $cut_from_start; ending at frame $frame_last."
    echo ""

    while [[ $frame -le $frame_last ]]
    do
        # Set the offset along the pano
        frame_position=$(($frame * $increment))
        # Pad the sequence numbers at 5 digits for better file naming
        printf -v padded_frame "%05d" $frame
        if [[ "$mode" == "horizontal" ]]
        then
            frame_data="${frame_width}x${frame_height}+${frame_position}+0"
        else
            frame_data="${frame_width}x${frame_height}+0+${frame_position}"
        fi
        # Run it!
        magick ${pano_file_name} -crop ${frame_data} -resize 1920x1080 pan${padded_frame}.png 2>> make-pan-error.log
        echo -en "\rFrame: ${padded_frame}"
        # And count
        frame=$(($frame + 1))
    done
    echo ""
}

# Panning left or up requires swapping the start and end cut points
swap_cut_points(){
    cut_from_start_temp=$cut_from_end
    cut_from_end=$cut_from_start
    cut_from_start=$cut_from_start_temp
}

# Panning left or up requires simply reversing a right or down frame sequence.
reverse_sequence(){
    echo "Reversing the frame sequence."
    file_list=$(ls -1 pan*.png | sort --reverse)
    counter=0
    for file in ${file_list}
    do
        # Pad the counter to 5 digits "%05d"
        printf -v padded_counter "%05d" ${counter}
        mv -f $file revpan${padded_counter}.png
        counter=$((${counter} + 1))
    done
}

# Since cutting off the beginning results in a frame sequence
# that starts at a number other than zero,
# we must resequence them to start at zero.
# Otherwise ffmpeg will fail.
resequence(){
    echo "Resequencing the frames to start at 0."
    file_list=$(ls -1 pan*.png | sort)
    counter=0
    for file in ${file_list}
    do
        # Pad the counter to 5 digits "%05d"
        printf -v padded_counter "%05d" ${counter}
        mv -f $file fwdpan${padded_counter}.png
        counter=$((${counter} + 1))
    done
}

# Stack all the frames together into a video clip
make_video(){
    echo "Assembling frames into a video."
    if [[ $direction == reversed ]]
    then
        input_file_pattern="revpan%05d.png"
    else
        input_file_pattern="fwdpan%05d.png"
    fi
    ffmpeg -framerate ${framerate} -i ${input_file_pattern} \
    -c:v libx265 -crf 0 -s 1920x1080 ${output_file}.${output_file_extension} \
    -c:v libx265 -crf 30 -s 1280x720 ${output_file}-preview.${output_file_extension} \
    2>> make-pan-error.log
}

clean_mkv(){
    if [[ ${output_file_extension} == mkv ]]
    then
        echo "Cleaning the mkv file."
        mv ${output_file}.${output_file_extension} ${output_file}-dirty.${output_file_extension}
        mkclean --remux ${output_file}-dirty.${output_file_extension} ${output_file}.${output_file_extension}  2>> make-pan-error.log
        rm -f ${output_file}-dirty.${output_file_extension}
    fi
}

# K, now do it!
case ${pan_direction} in
right)
    mode="horizontal"
    verify_wide
    set_h_framing
    make_frames
    resequence
    make_video
    clean_mkv
    ;;
left)
    mode="horizontal"
    direction="reversed"
    swap_cut_points
    verify_wide
    set_h_framing
    make_frames
    reverse_sequence
    make_video
    clean_mkv
    ;;
down)
    mode="vertical"
    verify_tall
    set_v_framing
    make_frames
    resequence
    make_video
    clean_mkv
    ;;
up)
    mode="vertical"
    direction="reversed"
    swap_cut_points
    verify_tall
    set_v_framing
    make_frames
    reverse_sequence
    make_video
    clean_mkv
    ;;
esac
