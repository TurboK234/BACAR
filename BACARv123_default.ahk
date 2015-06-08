; BACAR v1.2.3 - Bloated AutoHotkey Conversion Assistant for Recordings
; Copyright (c) 2015 Henrik Söderström
; This script is published under Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0) licence.
; You are free to use the script as you please, even commercially, but you should publish the edited code
; under the same licence and give the original creator appropriate credit. More information about the licence
; can be found at http://creativecommons.org/licenses/by-sa/4.0/ .

; GENERAL AUTOHOTKEY SETUP, DON'T EDIT, COMMENTS PROVIDED FOR CLARIFICATION.
SendMode, Input  													; Recommended for new scripts due to its superior speed and reliability.
#NoEnv  															; Recommended for performance and compatibility with future AutoHotkey releases.
#SingleInstance FORCE												; There can only be one instance of this script running.
SetWorkingDir, %A_ScriptDir% 										; Ensures a consistent starting directory (will be overwritten later in this script).
FileEncoding, UTF-8													; Required for correct handling of FFprobe's report and metadata file creation.
StringCaseSense, On													; Turns on case-sensitivity, which helps to create more spesific fingerprints.
current_year = %A_YYYY%												; Used by conversionlog-YEAR.txt, so that the whole script will log to the same file, even if the year changed during the conversion.

; GENERAL CONVERSION PREFERENCES (USER CONFIRMATION REQUIRED). DO NOT REMOVE THE 2x DOUBLE QUOTES, FILL THE VALUE BETWEEN THEM, USE "" FOR EMPTY.
dir_ffmpeg := ""													; The complete path (without the last "\") of both ffmpeg.exe and ffprobe.exe .
dir_rec := ""														; The complete path (without the last "\") of the video files to be converted.
dir_target := ""													; The complete path (without the last "\") of the new converted files and their metadata .nfo -file. This needs to pre-exist, the script will not create it.
extension_rec := ""													; The extension of the original files. Don't use wildcards, as file name body is evaluated based on length of this string.
extension_target := ""												; The extension of the target files (without the period).
days_before_conversion = 1											; # of days before the file is processed. This option looks at the source file's modification time, and considers only dates and rounds up (i.e. file modified yesterday -> value = 1). Use 0 to convert files regardless of their age. This is a safety measure for automated setups, not to convert files that are currently being written / recorded. As such, "1" is usually a good number.
days_keepold = -1													; # of days to keep original (succesfully converted) recordings, older files are deleted. Use -1 to disable deleting.
skip_conversion = no												; Skips the whole conversion part of this script if "yes".
skip_organizer = yes												; Skips the whole reorganizer part of this script if "yes". !!!NOTE: Skipping ("yes") IS recommended for setting up the script and converting the old files, as organizer WILL delete old files right after conversion. Good mainly for PVR-setups, and even then days_keepold = 30 (or more) is recommended.
show_conversion_confirmation = yes									; Show a OK/Cancel dialogue for each file before each file's encoding process, shows the ffmpeg command to be executed. Not suitable for automated workflow, good for setting up.
logging = yes														; Keep yearly log (in Source file folder) of the conversion process. Good for debugging and automated workflow. Note: logging will happen regardless of this option, only the log file (also the pre-existing!) will be deleted afterwards if "no".

; GENERAL FFMPEG OPTIONS FOR ALL FILES / STREAMS (USER CONFIRMATION AND ADDITIONS RECOMMENDED). DO NOT REMOVE THE 2x DOUBLE QUOTES, FILL THE VALUE BETWEEN THEM, USE "" FOR EMPTY.
global_ffmpeg_options_before_input := "" 							; Parameters that are passed to ffmpeg as written, placed before "-i" (input file). Used for general options, usually not required.
global_ffmpeg_extraparameters_before_mappings := ""					; Parameters that are passed to ffmpeg before searched mappings (defined below). Can be used to specify general mappings, for example "-map 0:a" to include all audio streams.
global_ffmpeg_extraparameters_after_mappings := ""					; Parameters that are passed to ffmpeg after searched mappings.
global_codec_encoder_video := ""									; Parameter that is passed to ffmpeg after option -codec:v
global_codec_encoder_audio := ""									; Parameter that is passed to ffmpeg after option -codec:a
global_codec_encoder_subtitle := ""									; Parameter that is passed to ffmpeg after option -codec:s
global_ffmpeg_extraparameters_before_output := ""					; Parameters that are passed to ffmpeg as written (inside double quotes), placed after stream mappings and before output file.
global_ffmpeg_extraparameters_after_output := ""					; Parameters that are passed to ffmpeg as written (inside double quotes), placed after output file.
keep_source_time = yes												; Sets the source file (creation time) to target file if "yes".
write_filename_as_title = no										; Writes the filename (without the extension) as <title> metadata in the .nfo file.
write_time_to_plot = no												; A special (script creator's preferred) engine, that writes the file creation time (not reliable for copied files) to .xml "plot", before the searched plot metadata, even if "plot" metadata is not searched for.
write_channel_to_plot = no											; A special (script creator's preferred) engine, that writes the channel name (only tested with Finnish cable tv's .wtv-files) to .xml "plot", before the searched plot metadata, even if "plot" metadata is not searched for.
channel_fingerprint := ""											; Used by write_channel_to_plot, this variable should include the string that appears ALWAYS and ONLY on the line that has the channel name in ffprobe's report (for example service_provider: )

; FILE SPECIFIC CONVERSION INCLUSION/EXCLUSION RULES (OPTIONAL). DO NOT REMOVE THE 2x DOUBLE QUOTES, FILL THE VALUE BETWEEN THEM, USE "" FOR EMPTY.
global_filename_iff := ""											; Sets a single string to look for in each processed filename, and process only those files. (Logical iff)
global_filename_ifnot := ""											; Sets a single string to look for in each processed filename, and skip over those files. (Logical if not)
global_ffprobereport_iff := ""										; Sets a single string to look for in ffprobe's report for each processed file, and process only those files. (Logical iff)
global_ffprobereport_ifnot := ""									; Sets a single string to look for in ffprobe's report for each processed file, and skip over those files. (Logical if not)

; INITIAL SETUP VALIDATION
GoSub, init_zero													; This subscript mainly checks, if the %dir_rec% is a valid location, as logging of any kind and the script function requires this. Gives a huge error and exits if not found.

; INITIAL QUERY TO EXECUTE THE SCRIPT OR NOT (CAN BE EASILY DISABLED BY ADDING A SEMICOLON (;) IN FRONT OF THE LINE BELOW)
GoSub, query_runscript												; Confirm the execution of the script with OK/Cancel (and 10 sec timeout defaulting to OK). Suitable especially for scheduled execution.


; EXTRACTION / CONVERSION RULES BASED ON FFPROBE'S ANALYSIS:
; (THERE CAN BE MORE THAN ONE, PLEASE COPY THE <----...----> MARKED SECTION FOR EACH RULE)
; DO NOT REMOVE THE 2x DOUBLE QUOTES, FILL THE VALUE BETWEEN THEM, USE "" FOR EMPTY.

; <----------------------------------------------------------------------
; Copy each section starting from the line above
; Extraction rule title: *** Empty, saved as a template for user generated rules ***		; non-formal title for user reminder
extraction_type =													; Type of data to extract (streamindex/metadata_nfo supported)
extraction_line_rule_1 := ""										; The "fingerprint" data in the ffprobe's report that distinguishes the selected line from every other line. Try to find a unique string.
extraction_line_rule_2 := ""										; Optional: User can fill here another rule that is REQUIRED TO COEXIST WITH rule_1 on the SAME LINE for the same extraction process (logical "AND").
line_exclusion_rule_1 := ""											; Optional: User can fill here one string that causes the line to be skipped if found. Handy, if line_rule_1 and line_rule_2 are inadequate.
stream_include_or_exclude := ""										; Used by ffmpeg to set a "negative mapping" (exclusion) if "exclude"
metadata_xml_header := ""											; Required only for .nfo metadata extraction, gives the field an appropriate header in the target .nfo -file. Don't fill <> here, only the text.
extractionrule_filename_iff := ""									; Sets a single string to look for in each processed filename, and apply this rule in only those files. (Logical iff)
extractionrule_filename_ifnot := ""									; Sets a single string to look for in each processed filename, and don't apply this rule with those files. (Logical if not)
extractionrule_ffprobereport_iff := ""								; Sets a single string to look for in ffprobe's report for each processed file, and apply this rule in only those files. (Logical iff)
extractionrule_ffprobereport_ifnot := ""							; Sets a single string to look for in ffprobe's report for each processed file, and don't apply this rule with those files. (Logical if not)
; The following line needs to be copy-pasted for each rule.
GoSub, init_common
;--------------
; Copy to the end of this line (and paste below) to add new rules ------>



; THESE TWO RULES ARE ONLY EXAMPLES (THEY ARE COMMENTED OUT WITH SEMICOLONS), FEEL FREE TO REMOVE
; ; <----------------------------------------------------------------------
; ; Copy each section starting from the line above
; ; Extraction rule title: *** (.wtv) Include Finnish DVB subtitles on AVA channel ***		; non-formal title for user reminder
; extraction_type = streamindex														; Type of data to extract (streamindex/metadata_nfo supported)
; extraction_line_rule_1 := "Subtitle: dvb_subtitle"								; The "fingerprint" data in the ffprobe's report that distinguishes the selected line from every other line. Try to find a unique string.
; extraction_line_rule_2 := "fin"													; Optional: User can fill here another rule that is REQUIRED TO COEXIST WITH rule_1 on the SAME LINE for the same extraction process (logical "AND").
; line_exclusion_rule_1 := "impaired"												; Optional: User can fill here one string that causes the line to be skipped if found. Handy, if line_rule_1 and line_rule_2 are inadequate.
; stream_include_or_exclude := "include"											; Used by ffmpeg to set a "negative mapping" (exclusion) if "exclude". Used only by "streamindex" exctraction type.
; metadata_xml_header := ""															; Used only for .nfo metadata extraction, gives the field an appropriate header in the target .nfo -file. Don't fill <> here, only the text.
; extractionrule_filename_iff := ""													; Sets a single string to look for in each processed filename, and apply this rule in only those files. (Logical iff)
; extractionrule_filename_ifnot := ""												; Sets a single string to look for in each processed filename, and don't apply this rule with those files. (Logical if not)
; extractionrule_ffprobereport_iff := "service_provider: AVA"						; Sets a single string to look for in ffprobe's report for each processed file, and apply this rule in only those files. (Logical iff)
; extractionrule_ffprobereport_ifnot := ""											; Sets a single string to look for in ffprobe's report for each processed file, and don't apply this rule with those files. (Logical if not)
; ; The following line needs to be copy-pasted for each rule.
; GoSub, init_common
; ;--------------
; ; Copy to the end of this line (and paste below) to add new rules ------>
; ; <----------------------------------------------------------------------
; ; Copy each section starting from the line above
; ; Extraction rule title: *** (.wtv) Extract show title from metadata as .nfo (xml) <originaltitle> ***	; non-formal title for user reminder
; extraction_type = metadata_nfo													; Type of data to extract (streamindex/metadata_nfo supported)
; extraction_line_rule_1 := "Title           :"										; The "fingerprint" data in the ffprobe's report that distinguishes the selected line from every other line. Try to find a unique string.
; extraction_line_rule_2 := ""														; Optional: User can fill here another rule that is REQUIRED TO COEXIST WITH rule_1 on the SAME LINE for the same extraction process (logical "AND").
; line_exclusion_rule_1 := ""												; Optional: User can fill here one string that causes the line to be skipped if found. Handy, if line_rule_1 and line_rule_2 are inadequate.
; stream_include_or_exclude := ""													; Used by ffmpeg to set a "negative mapping" (exclusion) if "exclude"
; metadata_xml_header := "originaltitle"											; Required only for .nfo metadata extraction, gives the field an appropriate header in the target .nfo -file. Don't fill <> here, only the text.
; extractionrule_filename_iff := ""													; Sets a single string to look for in each processed filename, and apply this rule in only those files. (Logical iff)
; extractionrule_filename_ifnot := ""												; Sets a single string to look for in each processed filename, and don't apply this rule with those files. (Logical if not)
; extractionrule_ffprobereport_iff := ""											; Sets a single string to look for in ffprobe's report for each processed file, and apply this rule in only those files. (Logical iff)
; extractionrule_ffprobereport_ifnot := ""											; Sets a single string to look for in ffprobe's report for each processed file, and don't apply this rule with those files. (Logical if not)
; ; The following line needs to be copy-pasted for each rule.
; GoSub, init_common
; ;--------------
; ; Copy to the end of this line (and paste below) to add new rules ------>
; ;
; THE EXAMPLES END HERE <-


; -----------------------------------------------------------------------------------------------
; ACTUAL DATA PROCESSING ENGINE(S) BELOW THIS LINE, EDITING THIS DATA CAN EASILY BREAK THE SCRIPT

FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Initiating script. `n", %dir_rec%\conversionlog-%current_year%.txt

init_global:
EnvGet, Env_Path, Path
SetWorkingDir, %dir_rec%
dir_temp = %dir_rec%\temp
StringLen, length_extension_rec, extension_rec
length_extensionplusperiod_rec := (length_extension_rec + 1)
StringLeft, drive_rec, dir_rec, 3
StringLeft, drive_target, dir_target, 3
DriveSpaceFree, freespace_rec, %drive_rec%
DriveSpaceFree, freespace_target, %drive_target%
freespace_rec_gt := Round(freespace_rec / 1024)
freespace_target_gt := Round(freespace_target / 1024)

; Check the prerequisites.
IfNotExist, %dir_ffmpeg%\ffmpeg.exe
{
	FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : ffmpeg.exe can't be found in the defined location, quitting. `n", %dir_rec%\conversionlog-%current_year%.txt
	GoSub, End_2
}
IfNotExist, %dir_ffmpeg%\ffprobe.exe
{
	FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : ffprobe.exe can't be found in the defined location, quitting. `n", %dir_rec%\conversionlog-%current_year%.txt
	GoSub, End_2
}
IfNotExist, %dir_rec%
{	
	FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : The directory for the source files can't be found, quitting. `n", %dir_rec%\conversionlog-%current_year%.txt
	GoSub, End_2
}
IfNotExist, %dir_target%
{
	FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : The directory for the target files can't be found, quitting. `n", %dir_rec%\conversionlog-%current_year%.txt
	GoSub, End_2
}
If (freespace_rec < 10240)
{
	FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Not enough space on the source drive (10 Gb required, " freespace_rec_gt " Gb available), quitting. `n", %dir_rec%\conversionlog-%current_year%.txt
	GoSub, End_2
}
If (freespace_target < 10240)
{
	FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Not enough space on the target drive (10 Gb required, " freespace_target_gt " Gb available), quitting. `n", %dir_rec%\conversionlog-%current_year%.txt
	GoSub, End_2
}
IfNotExist, %dir_rec%\temp
{
	RunWait, %comspec% /c mkdir "%dir_temp%"
	RunWait, %comspec% /c copy "%dir_rec%\*.log" "%dir_temp%\*.tlo"		; .tlo as in "Temporary Log File", only used to preserve old .log files in dir_rec (copied back in the end of this script).
	RunWait, %comspec% /c del /Q "%dir_rec%\*.log"	; dir_rec needs to be emptied of .log files as FFprobe will result in one .log that should not be mixed with older files.
	IfNotExist, %dir_rec%\temp
	{
		FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Temp dir could not be created, quitting. `n", %dir_rec%\conversionlog-%current_year%.txt	
		GoSub, End_2
	}
	FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Temporary directory (sourcedir\temp) was created. The script will not remove it automatically, but user can delete it after the script has finished. `n", %dir_rec%\conversionlog-%current_year%.txt
}
else
{
	RunWait, %comspec% /c del /Q "%dir_temp%\*.log"
	RunWait, %comspec% /c del /Q "%dir_temp%\*.str"
	RunWait, %comspec% /c del /Q "%dir_temp%\*.nfo"
	RunWait, %comspec% /c del /Q "%dir_temp%\*.tlo"
	RunWait, %comspec% /c copy "%dir_rec%\*.log" "%dir_temp%\*.tlo"		; .tlo as in "Temporary Log File", only used to preserve old .log files in dir_rec (copied back in the end of this script).
	RunWait, %comspec% /c del /Q "%dir_rec%\*.log"					; dir_rec needs to be emptied of .log files as FFprobe will result in one .log that should not be mixed with older files.
}

FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Prerequisites were met, proceeding. `n", %dir_rec%\conversionlog-%current_year%.txt

process_conversion:
Loop, %dir_rec%\*.%extension_rec%
{
	rule_skip = 0
	If (skip_conversion = "yes")
	{
		FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Skipping conversion (and metadata creation), skip_conversion = yes . `n", %dir_rec%\conversionlog-%current_year%.txt
		break
	}
	IfExist, %dir_rec%\*.log
	{	
		RunWait, %comspec% /c del /Q "%dir_rec%\*.log"
	}
	IfExist, %dir_temp%\*.log
	{	
		RunWait, %comspec% /c del /Q "%dir_temp%\*.log"
	}
	IfExist, %dir_temp%\*.nfo
	{	
		RunWait, %comspec% /c del /Q "%dir_temp%\*.nfo"
	}
	IfExist, %dir_temp%\*.str
	{	
		RunWait, %comspec% /c del /Q "%dir_temp%\*.str"
	}
	
	; * File loop initialization & checkup
	
	IfInString, A_LoopFileName, _CONVERTED
	{
		FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : File " A_LoopFileName " is already converted. `n", %dir_rec%\conversionlog-%current_year%.txt
		continue
	}
	
	FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : File " A_LoopFileName " found, checking and processing... `n", %dir_rec%\conversionlog-%current_year%.txt
	
	If (global_filename_iff <> "")
	{
		IfInString, A_LoopFileName, %global_filename_iff%
		{
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Global rule for file handling was met, proceeding. `n", %dir_rec%\conversionlog-%current_year%.txt
		}
		else
		{			
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Global rule for file handling was not met, skipping the file " A_LoopFileName ". `n", %dir_rec%\conversionlog-%current_year%.txt
			continue
		}
	}

	If (global_filename_ifnot <> "")
	{
		IfInString, A_LoopFileName, %global_filename_ifnot%
		{			
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Global rule for file exclusion was met, skipping the file " A_LoopFileName ". `n", %dir_rec%\conversionlog-%current_year%.txt
			continue
		}
		else
		{
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Global rule for file exclusion was not met, proceeding. `n", %dir_rec%\conversionlog-%current_year%.txt
		}
	}
	DriveSpaceFree, freespace_rec, %drive_rec%
	DriveSpaceFree, freespace_target, %drive_target%
	freespace_rec_gt := Round(freespace_rec / 1024)
	freespace_target_gt := Round(freespace_target / 1024)
	If (freespace_rec < 10240)
	{
		FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Not enough space on the source drive (10 Gb required, " freespace_rec_gt " Gb available), quitting. `n", %dir_rec%\conversionlog-%current_year%.txt
		Break
	}
	If (freespace_target < 10240)
	{
		FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Not enough space on the target drive (10 Gb required, " freespace_target_gt " Gb available), quitting. `n", %dir_rec%\conversionlog-%current_year%.txt
		Break
	}
	
	StringLeft, current_date, A_Now, 8										; saves current date as new YYYYMMDD variable.
	FileGetTime, mod_time_current_file, %dir_rec%\%A_LoopFileName%, M		; saves the modification time of the current file
	StringLeft, mod_date_current_file, mod_time_current_file, 8				; saves year, month and date to the new variable in YYYYMMDD form.
	source_mod_age = %current_date%											; to avoid confusion on the next line, copy current_date to a variable that will eventually only show the difference of dates (in days).
	EnvSub, source_mod_age, %mod_date_current_file%, Days
	If (days_before_conversion >= 1)
	{
		
		If (source_mod_age < days_before_conversion)
		{
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : File " A_LoopFileName " (" source_mod_age " day(s) since modified) is newer than days_before_conversion defines, skipping the file. `n", %dir_rec%\conversionlog-%current_year%.txt
			continue
		}
	}
	
	StringTrimRight, filenamebody_source, A_LoopFileName, %length_extensionplusperiod_rec%	

	; * FFprobe report engine
	RunWait, %comspec% /c ""%dir_ffmpeg%\ffprobe.exe" -report "%dir_rec%\%A_LoopFileName%""
	Sleep, 200
	RunWait, %comspec% /c copy "%dir_rec%\*.log" "%dir_temp%\ffprobereport.log"
	Sleep, 200
	FileRead, ffprobereport, %dir_temp%\ffprobereport.log
	Sleep, 200
	RunWait, %comspec% /c del /Q "%dir_rec%\*.log"
	
	If (global_ffprobereport_iff <> "")
	{
		global_ffprobereport_iff_encountered = 0
		Loop, Read, %dir_temp%\ffprobereport.log
		{
			IfInString, A_LoopReadLine, %global_ffprobereport_iff%
			{
				global_ffprobereport_iff_encountered = 1
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Global rule for file handling (based on FFprobe's report) was met, proceeding. `n", %dir_rec%\conversionlog-%current_year%.txt
				break		; Breaks the ffprobereport.log reading loop, as sufficient data was found.
			}
		}
		
		If (global_ffprobereport_iff_encountered < 1)
		{
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Global rule for file handling (based on FFprobe's report) was not met, skipping file " A_LoopFileName ". `n", %dir_rec%\conversionlog-%current_year%.txt
			RunWait, %comspec% /c del /Q "%dir_temp%\*.log"
			ffprobereport =
			continue
		}
	}

	If (global_ffprobereport_ifnot <> "")
	{
		global_ffprobereport_ifnot_encountered = 0
		Loop, Read, %dir_temp%\ffprobereport.log
		{
			IfInString, A_LoopReadLine, %global_ffprobereport_ifnot%
			{
				global_ffprobereport_ifnot_encountered = 1
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Global rule for file exclusion (based on FFprobe's report) was met, skipping file " A_LoopFileName ". `n", %dir_rec%\conversionlog-%current_year%.txt
				break		; Breaks the ffprobereport.log reading loop, as sufficient data was found.
			}
		}
		
		If (global_ffprobereport_ifnot_encountered = 1)
		{
			RunWait, %comspec% /c del /Q "%dir_temp%\*.log"
			ffprobereport =
			continue
		}
		else
		{
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Global rule for file exclusion (based on FFprobe's report) was not met, proceeding. `n", %dir_rec%\conversionlog-%current_year%.txt
		}
	}
	
	; * Metadata to .nfo (xml) scraper engine
	FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Starting metadata to .nfo (xml) engine. `n", %dir_rec%\conversionlog-%current_year%.txt
	metadata_appended = 0
	plot_open = 0
	plot_closed = 0
	
	If (write_filename_as_title = "yes")
	{
		StringReplace, filenamebody_edited, filenamebody_source, &, &amp;, 1
		StringReplace, filenamebody_edited, filenamebody_edited, ", &quot;, 1
		StringReplace, filenamebody_edited, filenamebody_edited, ', &apos;, 1
		StringReplace, filenamebody_edited, filenamebody_edited, <, &lt;, 1
		StringReplace, filenamebody_source_xml, filenamebody_edited, >, &gt;, 1
		
		If (metadata_appended < 1)
		{
			FileAppend, <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>`r`n, %dir_temp%\metadata.xml
			FileAppend, <movie>`r`n, %dir_temp%\metadata.xml
			FileAppend, % A_Space A_Space A_Space A_Space "<title>" filenamebody_source_xml "</title>`r`n", %dir_temp%\metadata.xml
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Filename body added as title metadata. `n", %dir_rec%\conversionlog-%current_year%.txt
			metadata_appended += 1
		}
		else
		{
			FileAppend, % A_Space A_Space A_Space A_Space "<title>" filenamebody_source_xml "</title>`r`n", %dir_temp%\metadata.xml
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Filename body added as title metadata. `n", %dir_rec%\conversionlog-%current_year%.txt
			metadata_appended += 1
		}
	}
			
	While, (A_Index <= metadata_rulecount)
	{
		current_metadata_found = 0
		metadata_current_index = %A_Index%			; This index number is needed in the following file reading loop that overwrites A_Index, hence this copying.

		If (extractionrule_filename_iff_metadata_%metadata_current_index% <> "")
		{
			IfInString, A_LoopFileName, % extractionrule_filename_iff_metadata_%metadata_current_index%
			{
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Metadata (index " metadata_current_index ") specific rule (based on filename) was met, proceeding. `n", %dir_rec%\conversionlog-%current_year%.txt
			}
			else
			{			
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Metadata (index " metadata_current_index ") specific rule (based on filename) was not met, skipping the rule. `n", %dir_rec%\conversionlog-%current_year%.txt
				continue
			}
		}
		
		If (extractionrule_filename_ifnot_metadata_%metadata_current_index% <> "")
		{
			IfInString, A_LoopFileName, % extractionrule_filename_ifnot_metadata_%metadata_current_index%
			{
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Metadata (index " metadata_current_index ") specific rule (based on filename) for rule exclusion was met, skipping the rule. `n", %dir_rec%\conversionlog-%current_year%.txt
				continue
			}
			else
			{			
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Metadata (index " metadata_current_index ") specific rule (based on filename) for rule exclusion was not met, proceeding. `n", %dir_rec%\conversionlog-%current_year%.txt
			}
		}		

		If (extractionrule_ffprobereport_iff_metadata_%metadata_current_index% <> "")
		{
			rule_ffprobereport_iff_encountered = 0
			Loop, Read, %dir_temp%\ffprobereport.log
			{
				IfInString, A_LoopReadLine, % extractionrule_ffprobereport_iff_metadata_%metadata_current_index%
				{
					rule_ffprobereport_iff_encountered = 1
					FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Metadata (index " metadata_current_index ") specific rule (based on FFprobe's report) was met, proceeding. `n", %dir_rec%\conversionlog-%current_year%.txt
					break		; Breaks the ffprobereport.log reading loop, as sufficient data was found.
				}
			}
			
			If (rule_ffprobereport_iff_encountered < 1)
			{
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Metadata (index " metadata_current_index ") specific rule (based on FFprobe's report) was not met, skipping the rule. `n", %dir_rec%\conversionlog-%current_year%.txt
				continue
			}
		}

		If (extractionrule_ffprobereport_ifnot_metadata_%metadata_current_index% <> "")
		{
			rule_ffprobereport_ifnot_encountered = 0
			Loop, Read, %dir_temp%\ffprobereport.log
			{
				IfInString, A_LoopReadLine, % extractionrule_ffprobereport_ifnot_metadata_%metadata_current_index%
				{
					rule_ffprobereport_ifnot_encountered = 1
					FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Metadata (index " metadata_current_index ") specific rule (based on FFprobe's report) for rule exclusion was met, skipping the rule. `n", %dir_rec%\conversionlog-%current_year%.txt
					break		; Breaks the ffprobereport.log reading loop, as sufficient data was found.
				}
			}
			
			If (rule_ffprobereport_ifnot_encountered = 1)
			{
				continue
			}
			else
			{
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Metadata (index " metadata_current_index ") specific rule (based on FFprobe's report) for rule exclusion was not met, proceeding. `n", %dir_rec%\conversionlog-%current_year%.txt
			}
		}
			
		Loop, Read, %dir_temp%\ffprobereport.log
		{
			If (line_exclusion_rule_1_metadata_%metadata_current_index% <> "")
			{
				IfInString, A_LoopReadLine, % line_exclusion_rule_1_metadata_%metadata_current_index%
				{
					FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Line exclusion rule (index " metadata_current_index ") was encountered, skipping a line. `n", %dir_rec%\conversionlog-%current_year%.txt					
					continue
				}
			}
			
			IfInString, A_LoopReadLine, % extraction_line_rule_1_metadata_%metadata_current_index%
			{
				If (extraction_line_rule_2_metadata_%metadata_current_index% = "")
				{
					If (current_metadata_found < 1)
					{						
						current_metadata_found += 1
						StringGetPos, metadata_colon_pos_left, A_LoopReadLine, :, L1
						StringTrimLeft, current_metadata_raw, A_LoopReadLine, (metadata_colon_pos_left + 2)
						StringReplace, current_metadata_edited, current_metadata_raw, &, &amp;, 1
						StringReplace, current_metadata_edited, current_metadata_edited, ", &quot;, 1
						StringReplace, current_metadata_edited, current_metadata_edited, ', &apos;, 1
						StringReplace, current_metadata_edited, current_metadata_edited, <, &lt;, 1
						StringReplace, current_metadata_final, current_metadata_edited, >, &gt;, 1						
						FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Based on one search criteria (index " metadata_current_index "), following metadata was extracted >" current_metadata_final "< . `n", %dir_rec%\conversionlog-%current_year%.txt
					}
					else
					{
						FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Metadata (index " metadata_current_index ") already found with provided search criteria (line_rule_1 = " extraction_line_rule_1_metadata_%metadata_current_index% "). The script is confused, skipping the particular search. Refine your search, please. `n", %dir_rec%\conversionlog-%current_year%.txt
						metadata_colon_pos_left = 
						current_metadata_raw = 
						current_metadata_edited = 
						current_metadata_final = 
						break
					}				
				}
				else
				{
					IfInString, A_LoopReadLine, % extraction_line_rule_2_metadata_%metadata_current_index%
					{
						If (current_metadata_found < 1)
						{
							current_metadata_found += 1
							StringGetPos, metadata_colon_pos_left, A_LoopReadLine, :, L1
							StringTrimLeft, current_metadata_raw, A_LoopReadLine, (metadata_colon_pos_left + 2)
							StringReplace, current_metadata_edited, current_metadata_raw, &, &amp;, 1
							StringReplace, current_metadata_edited, current_metadata_edited, ", &quot;, 1
							StringReplace, current_metadata_edited, current_metadata_edited, ', &apos;, 1
							StringReplace, current_metadata_edited, current_metadata_edited, <, &lt;, 1
							StringReplace, current_metadata_final, current_metadata_edited, >, &gt;, 1
							FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Based on two search criteria (index " metadata_current_index "), following metadata was extracted >" current_metadata_final "< . `n", %dir_rec%\conversionlog-%current_year%.txt
						}
						else
						{							
							FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Metadata (index " metadata_current_index ") already found with provided search criteria (line_rule_1 = " extraction_line_rule_1_metadata_%metadata_current_index% " and line_rule_2 = " extraction_line_rule_2_metadata_%metadata_current_index% "). The script is confused, skipping the particular search. Refine your search, please. `n", %dir_rec%\conversionlog-%current_year%.txt
							metadata_colon_pos_left = 
							current_metadata_raw = 
							current_metadata_edited = 
							current_metadata_final = 
							break
						}
					}
					else
					{						
						FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Extraction line_rule_1 (" extraction_line_rule_1_metadata_%metadata_current_index% ") was met on a line but not line_rule_2 (" extraction_line_rule_2_metadata_%metadata_current_index% "), skipping the line. `n", %dir_rec%\conversionlog-%current_year%.txt
						continue
					}
				}
			}
			else
			{
				continue		; If the first rule (line_rule_1) is not found, skip to the next line.
			}
		}

		If (metadata_xml_header_metadata_%metadata_current_index% = "plot")
		{
			If (write_time_to_plot = "yes")
			{
				FileGetTime, source_file_creation_time, %dir_rec%\%A_LoopFileName%, C
				FormatTime, source_time_formatted, %source_file_creation_time%, d.M.yyyy HH:mm
				If (metadata_appended < 1)
				{
					FileAppend, <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>`r`n, %dir_temp%\metadata.xml
					FileAppend, <movie>`r`n, %dir_temp%\metadata.xml
					FileAppend, % A_Space A_Space A_Space A_Space "<" metadata_xml_header_metadata_%metadata_current_index% ">" source_time_formatted " | ", %dir_temp%\metadata.xml
					FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Source creation time added to plot metadata. `n", %dir_rec%\conversionlog-%current_year%.txt
					metadata_appended += 1
					plot_open = 1
				}
				else
				{
					FileAppend, % A_Space A_Space A_Space A_Space "<" metadata_xml_header_metadata_%metadata_current_index% ">" source_time_formatted " | ", %dir_temp%\metadata.xml
					FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Source creation time added to plot metadata. `n", %dir_rec%\conversionlog-%current_year%.txt
					metadata_appended += 1
					plot_open = 1
				}
			}
			If (write_channel_to_plot = "yes")
			{
				Loop, Read, %dir_temp%\ffprobereport.log
				{
					IfInString, A_LoopReadLine, %channel_fingerprint%
					{
						If (channel_found < 1)
						{						
							channel_found += 1
							StringGetPos, channel_colon_pos_left, A_LoopReadLine, :, L1
							StringTrimLeft, current_channel_raw, A_LoopReadLine, (channel_colon_pos_left + 2)
							StringReplace, current_channel_edited, current_channel_raw, &, &amp;, 1
							StringReplace, current_channel_edited, current_channel_edited, ", &quot;, 1
							StringReplace, current_channel_edited, current_channel_edited, ', &apos;, 1
							StringReplace, current_channel_edited, current_channel_edited, <, &lt;, 1
							StringReplace, current_channel_final, current_channel_edited, >, &gt;, 1						
							FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Channel name was found: >" current_channel_final "< . `n", %dir_rec%\conversionlog-%current_year%.txt
						}
						else
						{
							FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Channel already found with provided criteria (channel_fingerprint = " channel_fingerprint "). Using the first found channel, but please refine your search rule. `n", %dir_rec%\conversionlog-%current_year%.txt
						}
					}
					else
					{
						continue		; If the channel_fingerprint is not found on the line, skip to the next line.
					}
				}
				If (channel_found < 1)
				{
					FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Channel name data could not be retrieved. " | " will still be written to plot metadata. Refine your search or use ""no"" for write_channel_to_plot. `n", %dir_rec%\conversionlog-%current_year%.txt
				}	
				If (metadata_appended < 1)
				{
					FileAppend, <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>`r`n, %dir_temp%\metadata.xml
					FileAppend, <movie>`r`n, %dir_temp%\metadata.xml
					FileAppend, % A_Space A_Space A_Space A_Space "<" metadata_xml_header_metadata_%metadata_current_index% ">" current_channel_final " | ", %dir_temp%\metadata.xml
					FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Channel name added to plot metadata. `n", %dir_rec%\conversionlog-%current_year%.txt
					metadata_appended += 1
					plot_open = 1
				}
				else
				{
					If (plot_open < 1)
					{
						FileAppend, % A_Space A_Space A_Space A_Space "<" metadata_xml_header_metadata_%metadata_current_index% ">" current_channel_final " | ", %dir_temp%\metadata.xml
						FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Channel name added to plot metadata. `n", %dir_rec%\conversionlog-%current_year%.txt
					}
					else
					{
						FileAppend, % current_channel_final " | ", %dir_temp%\metadata.xml
						FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Channel name added to plot metadata. `n", %dir_rec%\conversionlog-%current_year%.txt
					}
				}	
			}
			If (plot_open = 1)
			{
				FileAppend, % current_metadata_final "</" metadata_xml_header_metadata_%metadata_current_index% ">`r`n", %dir_temp%\metadata.xml
				plot_open = 0
				plot_closed = 1
			}
			else
			{
				If (metadata_appended < 1)
				{
					FileAppend, <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>`r`n, %dir_temp%\metadata.xml
					FileAppend, <movie>`r`n, %dir_temp%\metadata.xml
					FileAppend, % A_Space A_Space A_Space A_Space "<" metadata_xml_header_metadata_%metadata_current_index% ">" current_metadata_final "</" metadata_xml_header_metadata_%metadata_current_index% ">`r`n", %dir_temp%\metadata.xml
					metadata_appended += 1
					plot_closed = 1
				}
				else
				{
					FileAppend, % A_Space A_Space A_Space A_Space "<" metadata_xml_header_metadata_%metadata_current_index% ">" current_metadata_final "</" metadata_xml_header_metadata_%metadata_current_index% ">`r`n", %dir_temp%\metadata.xml 
					metadata_appended += 1
					plot_closed = 1
				}
			}	
		}
		
		If (current_metadata_final <> "" && metadata_xml_header_metadata_%metadata_current_index% <> "plot" )			; if metadata exists, i.e. it was found on ONE line that meets the rules (line_rule_1 (and line_rule_2 if set)), then append it to the .xml file.
		{
			If (metadata_appended < 1)
			{
				FileAppend, <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>`r`n, %dir_temp%\metadata.xml
				FileAppend, <movie>`r`n, %dir_temp%\metadata.xml
				FileAppend, % A_Space A_Space A_Space A_Space "<" metadata_xml_header_metadata_%metadata_current_index% ">" current_metadata_final "</" metadata_xml_header_metadata_%metadata_current_index% ">`r`n", %dir_temp%\metadata.xml
				metadata_appended += 1
			}
			else
			{
				FileAppend, % A_Space A_Space A_Space A_Space "<" metadata_xml_header_metadata_%metadata_current_index% ">" current_metadata_final "</" metadata_xml_header_metadata_%metadata_current_index% ">`r`n", %dir_temp%\metadata.xml 
				metadata_appended += 1
			}
		}
		If (current_metadata_final = "")
		{
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Metadata with index " metadata_current_index " was not found. `n", %dir_rec%\conversionlog-%current_year%.txt
		}
		
		current_metadata_final = 
		current_metadata_edited =
		current_metadata_raw =
	}
	
	If (write_time_to_plot = "yes" && plot_closed < 1)		; In case plot was not searched (or found) according to user set rules, this will still write time to plot metadata.
	{
		FileGetTime, source_file_creation_time, %dir_rec%\%A_LoopFileName%, C
		FormatTime, source_time_formatted, %source_file_creation_time%, d.M.yyyy HH:mm
		If (metadata_appended < 1)
		{
			FileAppend, <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>`r`n, %dir_temp%\metadata.xml
			FileAppend, <movie>`r`n, %dir_temp%\metadata.xml
			FileAppend, % A_Space A_Space A_Space A_Space "<" metadata_xml_header_metadata_%metadata_current_index% ">" source_time_formatted " | ", %dir_temp%\metadata.xml
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Source file creation time added to plot metadata. `n", %dir_rec%\conversionlog-%current_year%.txt
			metadata_appended += 1
			plot_open = 1
		}
		else
		{
			FileAppend, % A_Space A_Space A_Space A_Space "<" metadata_xml_header_metadata_%metadata_current_index% ">" source_time_formatted " | ", %dir_temp%\metadata.xml
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Source file creation time added to plot metadata. `n", %dir_rec%\conversionlog-%current_year%.txt
			metadata_appended += 1
			plot_open = 1
		}
	}
	If (write_channel_to_plot = "yes" && plot_closed < 1)	; In case plot was not searched (or found) according to user set rules, this will still write channel to plot metadata.
	{
	channel_found = 0
		Loop, Read, %dir_temp%\ffprobereport.log
		{
			IfInString, A_LoopReadLine, %channel_fingerprint%
			{
				If (channel_found < 1)
				{						
					channel_found += 1
					StringGetPos, channel_colon_pos_left, A_LoopReadLine, :, L1
					StringTrimLeft, current_channel_raw, A_LoopReadLine, (channel_colon_pos_left + 2)
					StringReplace, current_channel_edited, current_channel_raw, &, &amp;, 1
					StringReplace, current_channel_edited, current_channel_edited, ", &quot;, 1
					StringReplace, current_channel_edited, current_channel_edited, ', &apos;, 1
					StringReplace, current_channel_edited, current_channel_edited, <, &lt;, 1
					StringReplace, current_channel_final, current_channel_edited, >, &gt;, 1						
					FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Channel name was found: >" current_channel_final "< . `n", %dir_rec%\conversionlog-%current_year%.txt
				}
				else
				{
					FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Channel already found with provided criteria (channel_fingerprint = " channel_fingerprint "). Using the first found channel, but please refine your search rule. `n", %dir_rec%\conversionlog-%current_year%.txt
				}
			}
			else
			{
				continue		; If the channel_fingerprint is not found on the line, skip to the next line.
			}
		}
		If (channel_found < 1)
		{
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Channel name data could not be retrieved. " | " will still be written to plot metadata. Refine your search or use ""no"" for write_channel_to_plot. `n", %dir_rec%\conversionlog-%current_year%.txt
		}	
		If (metadata_appended < 1)
		{
			FileAppend, <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>`r`n, %dir_temp%\metadata.xml
			FileAppend, <movie>`r`n, %dir_temp%\metadata.xml
			FileAppend, % A_Space A_Space A_Space A_Space "<" metadata_xml_header_metadata_%metadata_current_index% ">" current_channel_final " | ", %dir_temp%\metadata.xml
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Channel name added to plot metadata. `n", %dir_rec%\conversionlog-%current_year%.txt
			metadata_appended += 1
			plot_open = 1
		}
		else
		{
			If (plot_open < 1)
			{
				FileAppend, % A_Space A_Space A_Space A_Space "<" metadata_xml_header_metadata_%metadata_current_index% ">" current_channel_final " | ", %dir_temp%\metadata.xml
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Channel name added to plot metadata. `n", %dir_rec%\conversionlog-%current_year%.txt
				metadata_appended += 1
				plot_open = 1
			}
			else
			{
				FileAppend, % current_channel_final " | ", %dir_temp%\metadata.xml
				metadata_appended += 1
			}
		}	
	}
	If (plot_open >= 1)
	{
		FileAppend, % "</plot>`r`n", %dir_temp%\metadata.xml
		plot_open = 0
		plot_closed = 1
		metadata_appended += 1
	}	
	
	If (metadata_appended > 0)
	{
		FileAppend, </movie>`r`n, %dir_temp%\metadata.xml
		RunWait, %comspec% /c copy "%dir_temp%\metadata.xml" "%dir_target%\%filenamebody_source%.nfo"
		RunWait, %comspec% /c del "%dir_temp%\metadata.xml"
		FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Metadata written (filename.nfo) to target folder. `n", %dir_rec%\conversionlog-%current_year%.txt
	}

	; * Stream index mapper engine
	FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Starting stream mapping engine. `n", %dir_rec%\conversionlog-%current_year%.txt			
	file_streammap_failed = 0
	While, (A_Index <= streamextr_rulecount)
	{
		current_stream_found = 0
		stream_current_index = %A_Index%			; This index number is needed in the following file reading loop that overwrites A_Index, hence this copying.

		If (extractionrule_filename_iff_streamextr_%stream_current_index% <> "")
		{
			IfInString, A_LoopFileName, % extractionrule_filename_iff_streamextr_%stream_current_index%
			{
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Stream search (index " stream_current_index ") specific rule (based on filename) was met, proceeding. `n", %dir_rec%\conversionlog-%current_year%.txt
			}
			else
			{			
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Stream search (index " stream_current_index ") specific rule (based on filename) was not met, skipping the rule. `n", %dir_rec%\conversionlog-%current_year%.txt
				continue
			}
		}
		
		If (extractionrule_filename_ifnot_streamextr_%stream_current_index% <> "")
		{
			IfInString, A_LoopFileName, % extractionrule_filename_ifnot_streamextr_%stream_current_index%
			{
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Stream search (index " stream_current_index ") specific rule (based on filename) for rule exclusion was met, skipping the rule. `n", %dir_rec%\conversionlog-%current_year%.txt
				continue
			}
			else
			{			
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Stream search (index " stream_current_index ") specific rule (based on filename) for rule exclusion was not met, proceeding. `n", %dir_rec%\conversionlog-%current_year%.txt
			}
		}		

		If (extractionrule_ffprobereport_iff_streamextr_%stream_current_index% <> "")
		{
			rule_ffprobereport_iff_encountered = 0
			Loop, Read, %dir_temp%\ffprobereport.log
			{
				IfInString, A_LoopReadLine, % extractionrule_ffprobereport_iff_streamextr_%stream_current_index%
				{
					rule_ffprobereport_iff_encountered = 1
					FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Stream search (index " stream_current_index ") specific rule (based on FFprobe's report) was met, proceeding. `n", %dir_rec%\conversionlog-%current_year%.txt
					break		; Breaks the ffprobereport.log reading loop, as sufficient data was found.
				}
			}
			
			If (rule_ffprobereport_iff_encountered < 1)
			{
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Stream search (index " stream_current_index ") specific rule (based on FFprobe's report) was not met, skipping the rule. `n", %dir_rec%\conversionlog-%current_year%.txt
				continue
			}
		}

		If (extractionrule_ffprobereport_ifnot_streamextr_%stream_current_index% <> "")
		{
			rule_ffprobereport_ifnot_encountered = 0
			Loop, Read, %dir_temp%\ffprobereport.log
			{
				IfInString, A_LoopReadLine, % extractionrule_ffprobereport_ifnot_metadata_%metadata_current_index%
				{
					rule_ffprobereport_ifnot_encountered = 1
					FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Stream search (index " stream_current_index ") specific rule (based on FFprobe's report) for rule exclusion was met, skipping the rule. `n", %dir_rec%\conversionlog-%current_year%.txt
					break		; Breaks the ffprobereport.log reading loop, as sufficient data was found.
				}
			}
			
			If (rule_ffprobereport_ifnot_encountered = 1)
			{
				continue
			}
			else
			{
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Stream search (index " stream_current_index ") specific rule (based on FFprobe's report) for rule exclusion was not met, proceeding. `n", %dir_rec%\conversionlog-%current_year%.txt
			}
		}
				
		Loop, Read, %dir_temp%\ffprobereport.log
		{
			If (line_exclusion_rule_1_streamextr_%stream_current_index% <> "")
			{
				IfInString, A_LoopReadLine, % line_exclusion_rule_1_streamextr_%stream_current_index%
				{
					FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Line exclusion rule (index " stream_current_index ") was encountered, skipping a line. `n", %dir_rec%\conversionlog-%current_year%.txt					
					continue
				}
			}
			
			IfInString, A_LoopReadLine, % extraction_line_rule_1_streamextr_%stream_current_index%
			{
				If (extraction_line_rule_2_streamextr_%stream_current_index% = "")
				{
					If (current_stream_found < 1)
					{
						; FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Looping for " extraction_line_rule_1_streamextr_%stream_current_index% ", found on the line " A_LoopReadLine ". `n", %dir_rec%\conversionlog-%current_year%.txt
						current_stream_found += 1
						StringGetPos, stream_colon_pos_left, A_LoopReadLine, :, L1
						StringMid, current_stream, A_LoopReadLine, (stream_colon_pos_left + 2), 1					
						FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Based on one search criteria (index " stream_current_index "), following stream number was extracted >" current_stream "< . `n", %dir_rec%\conversionlog-%current_year%.txt
					}
					else
					{
						FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Stream with search index " stream_current_index "  already found with provided search criteria (line_rule_1). Script is confused, skipping conversion. Please refine your search. `n", %dir_rec%\conversionlog-%current_year%.txt
						stream_colon_pos_left = 
						current_stream = 
						file_streammap_failed = 1
						break
					}
				
				}
				else
				{
					IfInString, A_LoopReadLine, % extraction_line_rule_2_streamextr_%stream_current_index%
					{
						If (current_stream_found < 1)
						{
							current_stream_found += 1
							StringGetPos, metadata_colon_pos_left, A_LoopReadLine, :, L1
							StringGetPos, stream_colon_pos_left, A_LoopReadLine, :, L1
							StringMid, current_stream, A_LoopReadLine, (stream_colon_pos_left + 2), 1
							FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Based on two search criteria (index " stream_current_index "), following stream number was extracted >" current_stream "< . `n", %dir_rec%\conversionlog-%current_year%.txt
						}
						else
						{
							FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Stream with search index " stream_current_index "  already found with provided search criteria (line_rule_1 and line_rule_2). Script is confused, skipping conversion. Please refine your search. `n", %dir_rec%\conversionlog-%current_year%.txt
							metadata_colon_pos_left = 
							stream_colon_pos_left = 
							current_stream = 
							file_streammap_failed = 1
							break
						}
					}
					else
					{
						FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Extraction rule 1 was met on a line but not rule 2, skipping the line (with stream search index " stream_current_index "). `n", %dir_rec%\conversionlog-%current_year%.txt
						continue
					}
				}
			}
			else
			{
				continue			; If the first rule (line_rule_1) is not found, skip to the next line.
			}
		}
		If (file_streammap_failed = 1)
		{
			file_streammap_failed = 2
			IfExist, %dir_target%\%filenamebody_source%.nfo
			{
				RunWait, %comspec% /c del "%dir_target%\%filenamebody_source%.nfo"
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Stream mappings failed/conflicted, conversion cancelled for file " A_LoopFileName ". Deleting the created .xml and skipping to next file. `n", %dir_rec%\conversionlog-%current_year%.txt
				break
			}
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Stream mappings failed/conflicted, conversion cancelled for file " A_LoopFileName ". Skipping to next file. `n", %dir_rec%\conversionlog-%current_year%.txt
			break
		}
		If (current_stream <> "")			; if the stream was found, i.e. it was found on ONE line that meets the rules (line_rule_1 and line_rule_2), then create a mapping argument for FFmpeg.
		{
			FileAppend, % "-map" A_Space exclusion_sign_streamextr_%stream_current_index% "0:" current_stream A_Space, %dir_temp%\mappings.str
		}
		else
		{
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Stream with search index " stream_current_index " was not found. `n", %dir_rec%\conversionlog-%current_year%.txt
			continue
		}
		current_stream = 
	}
	
	If (file_streammap_failed = 2)
	{	
		RunWait, %comspec% /c del /Q "%dir_rec%\*.log"
		RunWait, %comspec% /c del /Q "%dir_temp%\*.log"
		RunWait, %comspec% /c del /Q "%dir_temp%\*.str"
		file_streammap_failed = 0
		continue			; This skips to the next file in case stream mapping caused an error (usually search conflict).
	}
	
	; * FFmpeg command engine
	{
		FileRead, mappings, %dir_temp%\mappings.str
		RunWait, %comspec% /c del /Q "%dir_temp%\*.str"		; Delete the mappings.str -file as soon as it is read to a variable, as it would corrupt the mappings of the next file.
		StringTrimRight, mappings, mappings, 1				; Trims the last Space away. Space is always present, if the variable has any data.
		ffmpegstring_final = "%dir_ffmpeg%\ffmpeg.exe" %global_ffmpeg_options_before_input% -i "%dir_rec%\%A_LoopFileName%" %global_ffmpeg_extraparameters_before_mappings% %mappings% %global_ffmpeg_extraparameters_after_mappings% -codec:v %global_codec_encoder_video% -codec:a %global_codec_encoder_audio% -codec:s %global_codec_encoder_subtitle% "%dir_target%\%filenamebody_source%.%extension_target%"
		If (show_conversion_confirmation = "yes")
		{
			MsgBox, 1, Check conversion options,
			(LTrim
				The conversion of file %A_LoopFileName% is about
				to begin. The command to be executed is:
				
				%ffmpegstring_final%
				
				You can start the conversion by selecting "OK".
				
				You can cancel the conversion by selecting "Cancel"
				(skips to the next file).
			)
			IfMsgBox Cancel
			{			
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Conversion process of " A_LoopFileName " was cancelled by user before FFmpeg execution. `n", %dir_rec%\conversionlog-%current_year%.txt				
				RunWait, %comspec% /c del /Q "%dir_rec%\*.log"
				RunWait, %comspec% /c del /Q "%dir_temp%\*.log"
				RunWait, %comspec% /c del /Q "%dir_temp%\*.str"
				continue
			}
		}
		FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Initiating conversion, command: " ffmpegstring_final " `n", %dir_rec%\conversionlog-%current_year%.txt				
		RunWait, %comspec% /c "%ffmpegstring_final%"
		Sleep 2000
		FileGetSize, target_file_size, %dir_target%\%filenamebody_source%.%extension_target%, M
		If (target_file_size < 10)
		{
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Target file is either missing of suspiciously small in size, skipping to the next file (no renaming of source file, deleting target and metadata .nfo file). `n", %dir_rec%\conversionlog-%current_year%.txt
			RunWait, %comspec% /c del /Q "%dir_target%\%filenamebody_source%.%extension_target%"
			RunWait, %comspec% /c del /Q "%dir_target%\%filenamebody_source%.nfo"
			RunWait, %comspec% /c del /Q "%dir_rec%\*.log"
			RunWait, %comspec% /c del /Q "%dir_temp%\*.log"
			RunWait, %comspec% /c del /Q "%dir_temp%\*.str"
			continue
		}
		else
		{			
			If (keep_source_time = "yes")
			{
				FileGetTime, source_crea_time, %dir_rec%\%A_LoopFileName%, C
				FileSetTime, %source_crea_time%, %dir_target%\%filenamebody_source%.%extension_target%, C
				FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Source file creation timestamp written to target file. `n", %dir_rec%\conversionlog-%current_year%.txt
			}
			RunWait, %comspec% /c rename "%dir_rec%\%A_LoopFileName%" "%filenamebody_source%_CONVERTED.%extension_rec%"
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Success, File converted succesfully and renamed to filename_CONVERTED.ext . `n", %dir_rec%\conversionlog-%current_year%.txt
			
		}
	}
	
	; * Clean up & check engine
	{
		filename_body_source =
		ffprobereport =
		metadata_appended =
		channel_found =
		current_stream_found =
		RunWait, %comspec% /c del /Q "%dir_rec%\*.log"
		RunWait, %comspec% /c del /Q "%dir_temp%\*.log"
		RunWait, %comspec% /c del /Q "%dir_temp%\*.str"
		RunWait, %comspec% /c del /Q "%dir_temp%\*.nfo"
	}
	
}

process_organize:
FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Starting organizer. `n", %dir_rec%\conversionlog-%current_year%.txt
Loop, %dir_rec%\*.%extension_rec%
{
	If (skip_organizer = "yes")
	{
		FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Skipping organizer, skip_organizer = yes . `n", %dir_rec%\conversionlog-%current_year%.txt
		break
	}
	
	IfInString, A_LoopFileName, _CONVERTED
	{
		FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Converted file " A_LoopFileName " found. `n", %dir_rec%\conversionlog-%current_year%.txt
		StringLeft, current_date, A_Now, 8											; saves current date as new YYYYMMDD variable.
		FileGetTime, crea_time_current_file, %dir_rec%\%A_LoopFileName%, C			; saves the creation time of the current file
		StringLeft, crea_date_current_file, crea_time_current_file, 8				; saves year, month and date to the new variable in YYYYMMDD form.
		If (days_keepold >= 0)
		{
			source_crea_age = %current_date%										; to avoid confusion on the next line, copy current_date to a variable that will eventually only show the difference of dates (in days).
			EnvSub, source_crea_age, %crea_date_current_file%, Days
			If (source_crea_age <= days_keepold)
			{
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : File " A_LoopFileName " (" source_crea_age " day(s) since created) is newer than days_keepold defines, skipping the file. `n", %dir_rec%\conversionlog-%current_year%.txt
			continue
			}
			else
			{
			FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : File " A_LoopFileName " (" source_crea_age " day(s) since created) is older than days_keepold defines, deleting the file. `n", %dir_rec%\conversionlog-%current_year%.txt
			RunWait, %comspec% /c del /Q "%dir_rec%\%A_LoopFileName%"
			}
		}
		else
		{
		FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Age-based deleting of files disabled, skipping to next file. `n", %dir_rec%\conversionlog-%current_year%.txt
		continue
		}
	}
	else
	{
		FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Not-converted file " A_LoopFileName " found, skipping. `n", %dir_rec%\conversionlog-%current_year%.txt
		continue
	}
	
}

final_cleanup:
{
	IfExist, %dir_rec%\*.log
	{	
		RunWait, %comspec% /c del /Q "%dir_rec%\*.log"
	}
	IfExist, %dir_temp%\*.tlo
	{	
		RunWait, %comspec% /c copy "%dir_temp%\*.tlo" "%dir_rec%\*.log"
		Sleep 200
		RunWait, %comspec% /c del /Q "%dir_temp%\*.tlo"
	}
	IfExist, %dir_temp%\*.log
	{	
		RunWait, %comspec% /c del /Q "%dir_temp%\*.log"
	}
	IfExist, %dir_temp%\*.str
	{	
		RunWait, %comspec% /c del /Q "%dir_temp%\*.str"
	}
	IfExist, %dir_temp%\*.nfo
	{	
		RunWait, %comspec% /c del /Q "%dir_temp%\*.nfo"
	}
}

End_2:
{
	FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : End of the script. `n", %dir_rec%\conversionlog-%current_year%.txt

	If (logging = "no")
	{
		RunWait, %comspec% /c del /Q "%dir_rec%\conversionlog-%current_year%.txt"
	}

	ExitApp				; This should be the only command/line that exits the script.
}

; --------------------------------------------------------------------------------
; Next part consists of different subscripts. They are located here in the end of
; the script to enhance usability/readablility of this script. Subscripts are
; not intended to exit the script, they should either return to main script
; (with "return") or direct to the end of the main script (End_2: subscript logs
; the end and exits the script).

init_zero:
{
	If (%dir_rec% = "")
	{
		MsgBox, 0, SETUP ERROR,
		(LTrim
			The script fails to run as dir_rec (the location
			of the source files) is not a valid location,
			and even logging will fail. Thus you will only see
			this error and then the script exits.
		)
		ExitApp			; Unconditional exit.
	}
	IfNotExist, %dir_rec%
	{
		MsgBox, 0, SETUP ERROR,
		(LTrim
			The script fails to run as dir_rec (the location
			of the source files) is not a valid location,
			and even logging will fail. Thus you will only see
			this error and then the script exits.
		)
		ExitApp			; Unconditional exit.
	}
	return
}


query_runscript:
{
	MsgBox, 1, Conversion of multimedia files,
	(LTrim
		The conversion of selected video files (or other
		multimedia files) will start automatically
		in 10 seconds.
		
		You can start the conversion now by selecting "OK".
		
		You can cancel the conversion by selecting "Cancel".
	), 10
	IfMsgBox Cancel
	{
		FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Conversion process cancelled by user before initialization. `n", %dir_rec%\conversionlog-%current_year%.txt
		GoSub, End_2
	}
	return
}

; The search initing below is very central part of the whole script and also very delicate.
; You should not touch the code, unless you are implementing a new search/extraction type.

init_common:
{
	if (extraction_type = "streamindex")
	{
		total_rulecount += 1
		total_ruletag = %total_rulecount%
		GoSub, init_streamindex
		return
	}
	if (extraction_type = "metadata_nfo")
	{
		total_rulecount += 1
		total_ruletag := %total_rulecount%
		GoSub, init_metadata_nfo
		return
	}
	FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : Invalid extraction_type (" extraction_type ") set, skipping. `n", %dir_rec%\conversionlog-%current_year%.txt
	extraction_type =
	extraction_line_rule_1 = 
	extraction_line_rule_2 = 
	stream_include_or_exclude = 
	metadata_xml_header =							
	extractionrule_filename_iff = 
	extractionrule_filename_ifnot = 
	extractionrule_ffprobereport_iff =					
	extractionrule_ffprobereport_ifnot =
	streamextr_tag =
	return
}

init_streamindex:
{
	streamextr_rulecount += 1
	streamextr_tag = streamextr_%streamextr_rulecount%
	extraction_line_rule_1_%streamextr_tag% = %extraction_line_rule_1%
	extraction_line_rule_2_%streamextr_tag% = %extraction_line_rule_2%
	line_exclusion_rule_1_%streamextr_tag% = %line_exclusion_rule_1%
	if (stream_include_or_exclude = "exclude")
	{
		exclusion_sign_%streamextr_tag% := "-"
	}
	else
	{
		exclusion_sign_%streamextr_tag% := ""
	}
	extractionrule_filename_iff_%streamextr_tag% = %extractionrule_filename_iff%
	extractionrule_filename_ifnot_%streamextr_tag% = %extractionrule_filename_ifnot%
	extractionrule_ffprobereport_iff_%streamextr_tag% = %extractionrule_ffprobereport_iff%
	extractionrule_ffprobereport_ifnot_%streamextr_tag% = %extractionrule_ffprobereport_ifnot%
	; Next, clear the non-tagged variables after tagging
	extraction_type =					
	extraction_line_rule_1 = 
	extraction_line_rule_2 = 
	line_exclusion_rule_1 = 
	stream_include_or_exclude = 
	metadata_xml_header =							
	extractionrule_filename_iff = 
	extractionrule_filename_ifnot = 
	extractionrule_ffprobereport_iff =					
	extractionrule_ffprobereport_ifnot =
	streamextr_tag =
	; And return to read the next rule / continue with the script.
	return
}

init_metadata_nfo:
{
	metadata_rulecount += 1
	metadata_tag = metadata_%metadata_rulecount%
	extraction_line_rule_1_%metadata_tag% = %extraction_line_rule_1%
	extraction_line_rule_2_%metadata_tag% = %extraction_line_rule_2%
	line_exclusion_rule_1_%metadata_tag% = %line_exclusion_rule_1%
	metadata_xml_header_%metadata_tag% = %metadata_xml_header%
	extractionrule_filename_iff_%metadata_tag% = %extractionrule_filename_iff%
	extractionrule_filename_ifnot_%metadata_tag% = %extractionrule_filename_ifnot%
	extractionrule_ffprobereport_iff_%metadata_tag% = %extractionrule_ffprobereport_iff%
	extractionrule_ffprobereport_ifnot_%metadata_tag% = %extractionrule_ffprobereport_ifnot%
	; Next, clear the non-tagged variables after tagging
	extraction_type =					
	extraction_line_rule_1 = 
	extraction_line_rule_2 = 
	stream_include_or_exclude = 
	metadata_xml_header =							
	extractionrule_filename_iff = 
	extractionrule_filename_ifnot = 
	extractionrule_ffprobereport_iff =					
	extractionrule_ffprobereport_ifnot =
	metadata_tag =
	; And return to read the next rule / continue with the script.
	return
}
