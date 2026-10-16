# A/V Scripts (and Commands)
A place for the scripts I write for my audio/video projects. These do things to images and video clips.

# General Usage
I run these bash scripts in a Cygwin terminal (mintty) on Windows 10, in iTerm2/Homebrew on a Mac, and in Linux, whatever terminal comes with that distro. You need a variety of other command line tools installed for the scripts to work with. They expect all executables to be in your PATH environment variable. So make sure you've set all that up and can run them individually on the command line before trying to run anything from this repo.

## Extra Tools Required
These all must be installed and made functional on the command line. Please follow the installation instructions at the web sites for these tools.
* ImageMagick: https://imagemagick.org/
* ffmpeg: http://ffmpeg.org/
* exiftool: https://exiftool.org/
* mkclean: https://www.matroska.org/downloads/mkclean.html

## Other Notable Binaries Used
Make sure all these work on your computer.
* basename
* cut
* sort
* awk
* printf

## Installation
* Clone this repo to a folder in a convenient location on your computer.
* Add the path to this folder to your PATH environment variable.
* Run the scripts in a clean folder where you want the output files to be placed.

I recommend always running these scripts inside an empty folder, and reference your source files with the full path to where they are. The scripts will write their temp and output files to the current working folder. You risk damaging your source files if you run these scripts within the folders where your source files are stored.

# Commands

## Photos and Home Videos

### Date/Time Stamps

**When sorting files by the generic "Date" column in Windows Explorer**
* JPG files based on Date Taken column
    - Pulled from the EXIF tag DateTimeOriginal
    - **localtime without TZ offset**
* PNG based on Date Modified column
    - Pulled from the file's FileModifyDate data
    - **localtime with TZ offset**
* Videos based on "Media Created" column
    - Pulled from either of the QuickTime tags CreateDate or MediaCreateDate
    - **UTC**

So when you vacation outside of your home timezone, those pictures and videos will not sort correctly in Windows, until you set your computer clock's timezone to the same as where you went on vacation.

* Shift a video's time stamp to 3 hours earlier
```
exiftool '-QuickTime:MediaCreateDate-=3' '-QuickTime:CreateDate-=3' file.mp4
```
* Copy Date Taken (DateTimeOriginal) to File Modified stamp in a directory
```
exiftool '-FileModifyDate<DateTimeOriginal' dir
```
* Copy Media Created (CreateDate or MediaCreateDate) to File Modified stamp in a directory
```
exiftool '-FileModifyDate<MediaCreateDate' dir
```
* Copy File Modified from originals to edited copies
```
SRCEXT="JPG"
DSTEXT="png"
for file in $(ls -1 *.${DSTEXT})
	do
	SRCFILE=$(basename -s .${DSTEXT} ${file}).${SRCEXT}
	FMTIME="$(exiftool -args -FileModifyDate ${SRCFILE})"
	exiftool "$FMTIME" $file
done
```
* Copy tags from originals to edited files
```
for file in $(ls -1 GX*-1080p.MP4)
	do
	SRCFILE=$(basename -s '-1080p.MP4' $file).MP4
	exiftool -tagsFromFile $SRCFILE $file
done
```

### Convert image sequence to video
```
# ffmpeg: (creates CRF 15 x264/x265 .mkv file)
# -framerate - the frame rate of the INPUT media
# -r - the frame rate of the OUTPUT media
# input-csp=i422 and format=yuvj422p work together to maintain color space quality from JPGs
# Source images are 4000x3000. Crop to 4000x2250 for 16:9

# GoPro time lapse image sequence
# JPG image sequence (YUV 4:2:2)
ffmpeg \
-start_number 22527 \
-framerate 60 \
-i G00%05d.JPG \
-codec:v libx264 -x264-params 'crf=15:input-csp=i422' \
-r 60 \
-filter:v 'crop=4000:2250:0:0,scale=1920:-1,format=yuvj422p' \
PoolParty.mkv

# Chopped up panorama image
# PNG image sequence (RGB)
ffmpeg \
-start_number 00000 \
-framerate 60 \
-i pan%05d.png \
-c:v libx265 -x265-params crf=15 \
-r 60 \
BuildingPan.mkv
```

# Scripts
## make-pan.sh
This converts a panoramic still image, like what modern smartphones create, into a video that pans the length of the image.
These panoramic files are extreme dimensions, and any offline viewing or mixing into a video is difficult as a result.  The script can intake horizontal or vertical panos. And you can pan right, left, up or down.  The dimensions of the video are based on the source pano, and the aspect ratio is stuck at 16:9. Feel free to change that inside the script.

The script chops up the pano into "frames", which are video-sized still images that will become each video frame.  It then reassembles the frames into a video. Each frame is cropped out of the source pano, offset by a few pixels, relative to the prior frame, and then saved as a still image file.

The number of pixels between each frame determines how long the video will be, how fast the pan will scan across your screen, and how smooth the pan will be. Fewer pixels between frames makes the pan scan slower and longer, and looks smoother.  More pixels between frames results in a faster and shorter pan, and choppier. You control this value on the command line. If you omit it, the script will default to 25 pixels.

The video created will run at 30 fps by default. You can set the framerate on the command line. Stick with "normal" frame rates, such as 15, 24, 30, 60 and 120. The higher the framerate, the faster and smoother your video pan will be. Beware that 60 or 120 fps will result in a huge video file which has such a high bitrate that it may not play on anything but the most powerful computers. It WILL still be usable in your video editing tools, even on lower-power computers.  Depending on what video editing tools you use, you may be required to set the framerate to a number that matches the rest of your project. But integers only - no decimals. You can't set something like 23.997. It would have to be 24. Keep in mind that no matter what framerate you set, your video editing software will ultimately determine the final framerate.  So setting a high rate is not always as useful as it sounds. But it can have a positive effect on your final output.

"What's best" is up to you to determine, by performing test runs with different numbers and reviewing the videos to see how you like them.

The script outputs both a 720p x264 low-quality preview and a 1080p x264 lossless main video at the same time. In the case when your main video is too bulky to watch directly (very common!), you can watch the preview video to verify the results of the conversion.  Then use the main video in your editing project.

All the still frame image files are left behind so you can look at them. But you should delete them once you have a video clip you like. Be sure to delete them before running the script subsequent times, or you may end up with errant frames in your video.

### Running
Prep your source panoramic images before running the script. Do things like cropping, color and levels adjustments, etc., so that your pan video will be as clean as possible on the output.

The simple form:

```make-pan.sh <filename>```

For example: `make-pan.sh /home/Users/mchester/Desktop/Vacation2019/20190629_131016.jpg`

This creates a video that pans right on a horizontal panoramic image, where each frame is 25 pixels from the prior frame, and it runs at 30 frames per second. This video is reasonably smooth, maybe a little choppy if you want to see much detail, and it moves through a 360-degree pan in the neighborhood of about 25 seconds.

The explicit form:

```make-pan.sh <source_file> <direction> <increment> <framerate> <cut_from_start> <cut_from_end>```

    Where:
    * direction is one of right, left, up, down (default right)
    * increment is how many pixels of shift between frames. (default 25) More than about 33 is pretty jittery.
    * framerate is how many frames per second the resulting video will be. (default 30)
    * cut_from_start is how many frames you want to cut off at the beginning of the video. (default 0)
    * cut_from_end is how many frames you want to cut off at the end of the video. (default 0)

For example: `make-pan.sh ../IMG_3418.JPG up 13 60 5 75`

This creates a video that pans up a vertical panoramic image, where each frame is 13 pixels from the prior frame, and it runs at 60 frames per second. We cut off 5 frames at the beginning, because there was too much sidewalk in the pano.  And we chopped off 75 frames of empty sky at the top of the pano. This is a pretty smooth video and it moves fairly quickly. That image was actually a shot of the Space Needle in Seattle, WA. So the pan video allows us to get full width of the screen and full height of the Space Needle, for a more impressive shot on a big-screen TV.

When specifying args, all but the file name are optional, but their positions are not.  If you specify an arg for `<increment>`, you must specify `<direction>` before it. If you want to specify `<cut_from_end>`, you must specify all args in the correct order.
