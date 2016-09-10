# BACAR
Bloated AutoHotkey Conversion Assistant for Recordings - AHK-script to automatically convert media files using FFmpeg with certain metadata/content awareness.

The script was originally written to be used in conjunction with Windows Media Center and .wtv files created by the program. Best results for metadata conversion were thought to be possible only with .wtv files, but it turned out that at least TVHeadend can record to .mkv files that have the metadata of the recording in a very similar manner as .wtv files. The actual conversion works with all the filetypes that are supported by FFmpeg.

The metadata file (.nfo (XML format), used by Kodi/XBMC) can be created even without proper metadata (TS-files, for example), and it can be edited manually if the metadata is present in some other format. No external scraping is included and it's not a planned TO-DO, although technically possible. This will be easiest to implement when a specific PVR backend is already in use.

To view the metadata you have to select "Local metadata only" (.nfo icon) in Kodi/XBMC when adding the folder to your library. Frequent/daily library updates with XBMC Library Auto Update (Plugin) are recommended.

Basic knowledge of FFmpeg and conversion parameters are required for proper setup. One needs to investigate the source files with FFprobe to define the rules for the wanted streams, this is the most time consuming part of the setup.
