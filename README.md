# parkingbrake
Parkingbrake is an automated transcoding application powered by [Handbrake](https://handbrake.fr/).

    docker run -p 8080 -p 8080/udp -v /app/data:/var/share/transcoding --name parkingbrake sanmadjack/parkingbrake:latest

It has a web gui accessible on port 8080 for viewing transcoding progress and settings. It does not currently allow interacting with the transcoding or changing settings. 

One volume is used at /app/data. Within that volume there are three folders:

1. input - This folder is where you place the files to transcode. The server scans this folder on startup, and watches for new/deleted/updated files after startup.
2. output - This folder is where the transcoded files are placed.
3. trash - This folder contains the original files after they have transcoded.  

Parkingbrake does not maintain a persistent database of processes, instead always processing whatever is in the input folder. After processing, the original video files are moved to the trash folder.

Settings are controlled via json files in the data folder. All settings are in addition to HandBrakeCLI's defaults.

One settings.json should be created in the root of the data folder with settings you want to be applied to all files.

Additional settings.json files in sub-folders to override settings for those particular folders. 

Settings can be overridden for specific files by using the "files" element, which should contain a map of files names and settings objects. 

Here is a sample of all of the available settings:

    {
        "encoder": "x265_10bit",
        "preset": "veryslow",
        "quality": 18,
        "two_pass": true,
        "decomb": true,
        "detelecine": true,
        "width": 0, 
        "height": 0,
        "audio_codecs": ["opus"],
        "audio_languages":[
            "jpn","chi","eng","und"
        ],
        "detect_hd_audio_substream": false,
        "flip_subtitles": true,
        "files": {
            "title_01.mkv": {
                "chapter_start": 1,
                "chapter_end": 4
            },
            "title_02.mkv": {
                "chapter_start": 1,
                "chapter_end": 4,
                "chapter_split": 2
            },
            "title_04.mkv": {
                "chapter_splits": [2,3,2]
            }   
        }
    }
    
### Encoding settings:

|Name|Description|Default|Options|
|---|---|---|---|
|encoder|The encoder to use|x264|x264<br>x264_10bit<br>x265<br>x265_10bit<br>x265_12bit<br>mpeg4<br>mpeg2<br>VP8<br>VP9<br>theora|
|preset|The preset to use, options vary by encoder|medium|ultrafast<br>superfast<br>veryfast<br>faster<br>fast<br>medium<br>slow<br>slower<br>veryslow<br>placebo|
|quality|The quality setting to use|24|Any integer|
|two_pass|Whether to use two-pass encoding|true|true<br>false|
|decomb|Whether to use decomb|true|true<br>false|
|detelecine|Whether to use detelecine|true|true<br>false|
|height|The height for the outputted video. 0 does not resize the video.|0| Any integer|
|width|The width for the outputted video. 0 does not resize the video.|0|Any integer|
|max_height|Specifies the max height for a video, resizing it if the video is taller than the specified height|0|Any integer greater than zero
|audio_encoder|The audio encoder for the outputted audio|opus|none<br>ca_aac<br>ca_haac<br>ac3<br>eac3<br>mp3<br>vorbis<br>flac16<br>flac24<br>opus<br>copy|
|mixdown|The max audio channels to use for the outputted audio|s7point1|mono<br>left_only<br>right_only<br>stereo<br>dpl1<br>dpl2<br>s5point1<br>s6point1<br>s7point1<br>s5_2_lfe|
|audio_quality|The audio quality to use. The meaning of the number varies by encoder|8|Any integer|
|chapter_start|The chapter to start converting from.|1|Any integer|
|chapter_end|The chapter to stop converting at, 0 indicating last chapter|0|Any integer|
|chapter_splits|Splits the file based on array of chapter counts. Ignored if file has no chapters or if chapter_split is used. Works with chapter_start and chapter_end.|[]|Any array of integers greater than 0|
|chapter_split|Splits the file(s) into separate output files every x chapters, 0 indicating not splitting. Trailing chapters less than the number of chapters specified are included in the last file, for example if a chapter_split of 3 is used with a file with 11 chapters, it will create 3 files with chapters 1-3, 4-6, and 7-11. Ignored if file has no chapters. Works with chapter_start and chapter_end.|0|Any integer greater than 0|
|audio_languages|The audio languages to import. Specified as an array of strings.|all languages|Any three-letter audio language code|
|detect_hd_audio_substream|MakeMKV usually exports super high-quality audio streams along with their backwards-compatibly sub-stream, resulting in MKV files with duplicate audio streams. Enabling this option attempts to detect these and remove the duplicates. This is not perfect, and can sometimes eat commentary tracks. |false|true<br>false|
|flip_subtitles|Flips the first and second subtitle tracks, used for Anime that use text-only subtitles as the first track|false|true<br>false|
|files|Allows specifying settings for individual files|nothing|A map of file names and settings objects|

### Hardcoded Handbrake flags
The below flags are always used. If you would like one or more of them made optional, please open an issue ticket.

    --min-duration 0
    --format av_mkv
    --markers
    --encoder-profile auto
    --vfr
    --auto-anamorphic
    --no-hqdn3d
    --no-nlmeans
    --no-unsharp
    --no-lapsharp
    --no-deblock