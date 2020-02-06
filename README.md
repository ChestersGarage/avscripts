# A/V Scripts
A place for the scripts I write for my audio/video projects. These do things to images and video clips. 

# General Usage
I run these bash scripts in a Cygwin terminal (mintty) on Windows 10, in iTerm2/Homebrew on a Mac, and in Linux, whatever terminal comes with that distro. You need a variety of other command line tools installed for the scripts to work with. They expect all executables to be in your PATH environment variable. So make sure you've set all that up and can run them individually on the command line before trying to run anything from this repo.

## Extra Tools Required
* ImageMagick: https://imagemagick.org/
* ffmpeg: http://ffmpeg.org/
* exiftool: https://exiftool.org/

## Other Notable Binaries Used
Make sure all these work on your computer.
* basename
* cut
* sort
* awk
* printf

## Installation
* Put this repo somewhere convenient.
* Add it to your PATH environment variable.
* Run in the folder you want the OUTPUT to be placed.

I recommend always running these scripts inside an empty folder, and reference your source files with the full path to where they are. The scripts will write their temp and output files to the current working folder. You risk damaging your source files if you run these scripts within the folders where your source files are stored.

# Scripts
## make-pan.sh
This converts a panoramic still image, like what modern smartphones create, into a video that pans the length of the image.
These panoramic files are extreme dimensions, and any offline viewing or mixing into a video is difficult as a result.  The script can intake horizontal or vertical panos. And you can pan right, left, up or down.  The dimensions of the video are based on the source pano, and the aspect ratio is stuck at 16:9. Feel free to change that inside the script.

The script chops up the pano into "frames", which are video-sized still images that will become each video frame.  It then reassembles the frames into a video. Each frame is cropped out of the source pano, offset by a few pixels, relative to the prior frame, and then saved as a still image file.

The number of pixels between each frame determines how long the video will be, how fast the pan will scan across your screen, and how smooth the pan will be. Fewer pixels between frames makes the pan scan slower and longer, and looks smoother.  More pixels between frames results in a faster and shorter pan, and choppier. You control this value on the command line. If you omit it, the script will default to 25 pixels.

The video created will run at 30 fps by default. You can set the framerate on the command line. Stick with "normal" frame rates, such as 15, 24, 30, 60 and 120. The higher the framerate, the faster and smoother your video pan will be. Beware that 60 or 120 fps will result in a huge video file which has such a high bitrate that it may not play on anything but the most powerful computers. It WILL still be usable in your video editing tools, even on lower-power computers.  Depending on what video editing tools you use, you may be required to set the framerate to a number that matches the rest of your project. But integers only - no decimals. You can't set something like 23.997. It would have to be 24. Keep in mind that no matter what framerate you set, your video editing software will ultimately determine the final framerate.  So setting a high rate is not always as useful as it sounds. But it can have a positive effect on your final output.

"What's best" is up to you to determine, by performing test runs with different numbers and reviewing the videos to see how you like them.

The script outputs both a 720p x264 low-quality preview and a 1080p x264 lossless main video at the same time. In the case when your main video is too bulky to watch directly (very common!), you can watch the preview video to verify the results of the conversion.  Then use the main video in your editing project.

All the still frame image files are left behind so you can look at them. But you can delete them once you have a video clip you like. Be sure to delete them before running the script subsequent times, or you may end up with errant frames in your video.

### Running
```make-pan.sh <source_file> <direction> <increment> <framerate>```

For example: `make-pan.sh ../IMG_3418.JPG up 13 60`

This creates a video that pans up a vertical panoramic image, where each frame is 13 pixels from the prior frame, and it runs at 60 frames per second. This is a pretty smooth video and it moves fairly quickly. That image was actually a shot of the Space Needle in Seattle, WA. So the pan video allows us to get full width of the TV and full height of the Space Needle, for a more imperessive shot.
