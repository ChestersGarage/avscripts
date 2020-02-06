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

pano_file_extension=$(basename ${pano_file_name} | cut -d '.' -f 2)
output_file="$(basename -s .${pano_file_extension} ${pano_file_name})"
# Can be any file type compatible with H264 video.
output_file_extension="mp4"

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
h_frame_size(){
    frame_height=$pano_height
    frame_width=$(( ($pano_height / $aspect_height) * $aspect_width ))
}

# When panning vertically, assume frame width is the same as the pano
v_frame_size(){
    frame_width=$pano_width
    frame_height=$(( ($pano_width / $aspect_width) * $aspect_height ))
}

show_framing_info(){
    echo "Panorama size: $pano_width x $pano_height"
    echo "Frame Size: $frame_width x $frame_height"
    echo "Number of frames: $frame_count"
    echo ""
}

make_h_frames(){
    frame_count=$(( ($pano_width - ($frame_width + $increment)) / $increment ))
    show_framing_info
    frame=0
    frame_position=0
    max_frame_position=$(( $frame_count * $increment ))
    while [[ $frame_position -le $max_frame_position ]]
    do
        # Set the offset along the pano
        frame_position=$(($frame * $increment))
        # Pad the sequence numbers at 5 digits for better file naming
        printf -v padded_frame "%05d" $frame
        # Run it!
        magick ${pano_file_name} -crop ${frame_width}x${frame_height}+${frame_position}+0 -resize 1920x1080 pan${padded_frame}.png
        echo "Frame number: ${padded_frame}"
        echo ""
        # And count
        frame=$(($frame + 1))
    done
}

make_v_frames(){
    frame_count=$(( ($pano_height - ($frame_height + $increment)) / $increment ))
    show_framing_info
    frame=0
    frame_position=0
    max_frame_position=$(( $frame_count * $increment ))
    while [[ $frame_position -le $max_frame_position ]]
    do
        # Set the offset along the pano
        frame_position=$(($frame * $increment))
        # Pad the sequence numbers at 5 digits for better file naming
        printf -v padded_frame "%05d" $frame
        # Run it!
        magick ${pano_file_name} -crop ${frame_width}x${frame_height}+0+${frame_position} -resize 1920x1080 pan${padded_frame}.png
        echo "Frame number: ${padded_frame}"
        echo ""
        # And count
        frame=$(($frame + 1))
    done
}

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

make_rev_video(){
    ffmpeg -framerate ${framerate} -i revpan%05d.png \
    -c:v libx264 -crf 0 -s 1920x1080 ${output_file}.${output_file_extension} \
    -c:v libx264 -crf 25 -s 1280x720 ${output_file}-preview.${output_file_extension}
}

make_video(){
    ffmpeg -framerate ${framerate} -i pan%05d.png \
    -c:v libx264 -crf 0 -s 1920x1080 ${output_file}.${output_file_extension} \
    -c:v libx264 -crf 25 -s 1280x720 ${output_file}-preview.${output_file_extension}
}

# K, now do it!
case ${pan_direction} in
right)
    verify_wide
    h_frame_size
    make_h_frames
    make_video
    ;;
left)
    verify_wide
    h_frame_size
    make_h_frames
    reverse_sequence
    make_rev_video
    ;;
down)
    verify_tall
    v_frame_size
    make_v_frames
    make_video
    ;;
up)
    verify_tall
    v_frame_size
    make_v_frames
    reverse_sequence
    make_rev_video
    ;;
esac
