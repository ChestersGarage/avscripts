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
first_frame=${5:-0}
# Set the last frame position, i.e.: "max_frame_position - last_frame"
last_frame=${6:-0}

# We need to know the file name bits in order to create the output file name.
pano_file_extension=$(basename ${pano_file_name} | cut -d '.' -f 2)
output_file="$(basename -s .${pano_file_extension} ${pano_file_name})"
# Can be any file type compatible with H264 video.
output_file_extension="mkv"

# Need to know the dimensions of the pano
pano_geometry=$(magick identify ${pano_file_name} | awk '{ print $3 }')
pano_width=$(echo ${pano_geometry} | cut -d x -f 1)
pano_height=$(echo ${pano_geometry} | cut -d x -f 2)

# Frame dimensions
aspect_width=16
aspect_height=9

verify_wide(){
    # We want the pano wide enough for at least one second of video
    min_width=$(( (($pano_height / $aspect_height) * $aspect_width) + ( $framerate * $increment) ))
    if [[ ${pano_width} -lt ${min_width} ]]
    then
        echo "Not enough frames for at least 1 second of video."
        echo "Reduce increment or framerate, or get a wider panorama."
        exit 1
    fi
}

verify_tall(){
    # We want the pano tall enough for at least one second of video
    min_height=$(( (($pano_width / $aspect_width) * $aspect_height) + ( $framerate * $increment) ))
    if [[ ${pano_height} -lt ${min_height} ]]
    then
        echo "Not enough frames for at least 1 second of video."
        echo "Reduce increment or framerate, or get a taller panorama."
        exit 1
    fi
}

# When panning horizontally, assume frame height is the same as the pano
set_h_framing(){
    frame_height=$pano_height
    frame_width=$(( ($pano_height / $aspect_height) * $aspect_width ))
    frame_count=$(( (($pano_width - $frame_width) / $increment) - $first_frame - $last_frame ))
    make_frames
}

# When panning vertically, assume frame width is the same as the pano
set_v_framing(){
    frame_width=$pano_width
    frame_height=$(( ($pano_width / $aspect_width) * $aspect_height ))
    frame_count=$(( (($pano_height - $frame_height) / $increment) - $first_frame - $last_frame ))
    make_frames
}

# Chops up the pano into still frames
make_frames(){
    frame=$(( $first_frame ))
    frame_position=$(( $frame * $increment ))

    echo "Panorama size: $pano_width x $pano_height"
    echo "Raw frame size: $frame_width x $frame_height (will be scaled to 1920 x 1080)"
    echo "Approximate video length: $(( $frame_count / $framerate )).$(( ($frame_count % $framerate) * 100 / $framerate )) second(s); $frame_count frames."
    echo ""

    while [[ $frame -le $frame_count ]]
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
        magick ${pano_file_name} -crop ${frame_data} -resize 1920x1080 pan${padded_frame}.png
        echo "Frame number: ${padded_frame}"
        echo ""
        # And count
        frame=$(($frame + 1))
    done
}

# Panning left or up requires simply reversing a right or down frame sequence, respectively.
reverse_sequence(){
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

# Stack all the frames together into a video clip
make_video(){
    if [[ $direction == reversed ]]
    then
        input_file_pattern="revpan%05d.png"
    else
        input_file_pattern="pan%05d.png"
    fi
    ffmpeg -framerate ${framerate} -i ${input_file_pattern} \
    -c:v libx265 -crf 0 -s 1920x1080 ${output_file}.${output_file_extension} \
    -c:v libx265 -crf 30 -s 1280x720 ${output_file}-preview.${output_file_extension}
}

clean_mkv(){
    if [[ ${output_file_extension} == mkv ]]
    then
        mv ${output_file}.${output_file_extension} ${output_file}-dirty.${output_file_extension}
        mkclean --remux ${output_file}-dirty.${output_file_extension} ${output_file}.${output_file_extension}
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
    make_video
    clean_mkv
    ;;
left)
    mode="horizontal"
    direction="reversed"
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
    make_video
    clean_mkv
    ;;
up)
    mode="vertical"
    direction="reversed"
    verify_tall
    set_v_framing
    make_frames
    reverse_sequence
    make_video
    clean_mkv
    ;;
esac
