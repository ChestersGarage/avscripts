#!/bin/bash

# A list of CRF values you want encoded for visual quality testing
CRFS="18"
# Try multiple codecs and compare quality vs file sizes
CODECS="264"
# Different frame rates on the input dictate the speed of the time lapse
# Try multiple values
FRS="60"
# The GoPro files start at arbitrary numbers and count up from there.
STARTAT="18103"
# Length of the clip you want in seconds 00.000
# https://ffmpeg.org/ffmpeg-utils.html#time-duration-syntax
LENGTH="19.5"
#            -t $LENGTH \
# Framerate of the output video.
# Must be equal or less than input framerate.
OUTFR="60"


# -start_number 19849 : Images are numbered, starting here.
# -framerate 60 : Adjust to desired input image rate
# -i G00%05d.JPG : My GoPro names files with "G" and numbers:
#                  two zeros, followed by five digits, and ".JPG" at the end.
# -movflags faststart : An MP4 flag to load stream data sooner and consistently.
# -filter:v 'crop=4000:2250:0:0,scale=3840:-1,format=yuvj422p' : Manipulate input images:
#      Images are 4:3 aspect, cut to 16:9 (trims the bottom off the images)
#      Scale down to 4k (3840) by whatever keeps it 16:9
#      GoPro JPG files have a wider color space (4:2:2),
#        so we pass that manually through to the video encoder.
# -codec:v libx${CODEC} -x${CODEC}-params "crf=${CRF}:input-csp=i422" : Encoder stuff:
#      Encode with libx264/5
#      CRF value
#      That color space thing (4:2:2) from above
# -r $FR : Frame rate of the output file; try to keep within even divisions of input framerate.
# FallSunSet-4k-CRF${CRF}-x${CODEC}-${FR}fps.mp4 : The files will be named with this format, based on the three variables.
LENGTHARG=""
if [[ "$LENGTH" != "All" ]]
then
    LENGTHARG="-t $LENGTH"
fi

for CRF in ${CRFS}
do
    for CODEC in ${CODECS}
    do
        for FR in ${FRS}
        do
            time ffmpeg \
            -start_number $STARTAT \
            -framerate $FR \
            $LENGTHARG \
            -i G00%05d.JPG \
            -movflags faststart \
            -filter:v 'crop=4000:2250,scale=1920:-1,format=yuvj422p' \
            -codec:v libx${CODEC} -x${CODEC}-params "crf=${CRF}" \
            -r $OUTFR \
            NewYearSunset-${STARTAT}-${LENGTH}-FHD-CRF${CRF}-x${CODEC}-${OUTFR}fps.mp4
        done
    done
done

# crop=4000:2250:0:810,
