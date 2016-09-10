; BACAR Conversion Tagger
; Copyright (c) 2016 Henrik Söderström
; This script is published under Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0) licence.
; You are free to use the script as you please, even commercially, but you should publish the edited code
; under the same licence and give the original creator appropriate credit. More information about the licence
; can be found at http://creativecommons.org/licenses/by-sa/4.0/ .

; This script is used to tag files as "converted". This is usually done by BACAR script after a successful conversion.
; There are situations, though, when you might want to tag files regardless of their actual conversion status, especially
; when setting up the BACAR script for optimal results. The tags can be removed with BACAR Conversion Tag Remover script.
; You should avoid double-tagging files with two or more different methods, especially conversiontag_method = logfolder
; and conversiontag_method = rename cause problems if used for the same files, since they both rely on filenames for tagging.
; It should be noted that the tagging of BACAR involves the source files, not the destination files. Destination files may
; easily be reorganized this way.

; GENERAL AUTOHOTKEY SETUP, DON'T EDIT, COMMENTS PROVIDED FOR CLARIFICATION.
SendMode, Input  													; Recommended for new scripts due to its superior speed and reliability.
#NoEnv  															; Recommended for performance and compatibility with future AutoHotkey releases.
#SingleInstance FORCE												; There can only be one instance of this script running.
SetWorkingDir, %A_ScriptDir% 										; Ensures a consistent starting directory (will be overwritten later in this script).
FileEncoding, UTF-8													; Used in coherence with actual file converter script (BACAR).
StringCaseSense, On													; Turns on case-sensitivity, which helps to create more specific commands.

; GENERAL PREFERENCES (USER CONFIRMATION REQUIRED). DO NOT REMOVE THE 2x DOUBLE QUOTES, FILL THE VALUE BETWEEN THEM, USE "" FOR EMPTY.
dir_rec := ""														; The complete path (without the last "\") of the video files from which the conversion tag should be removed. Leave empty "" to use script's directory.
extension_rec := "mkv"													; The extension of the searched files. Don't use wildcards, as file name body is evaluated based on length of this string.
conversiontag_method := "attribute"											; This needs to be one of the supported methods (either "rename", "attribute" or "logfolder"). This defines which files get "tagged".
global_filename_iff := ""											; Sets a single string to look for in each processed filename, and process only those files. (Logical iff). Optional, leave empty "" if no use.
global_filename_ifnot := ""											; Sets a single string to look for in each processed filename, and skip over those files. (Logical if not). Optional, leave empty "" if no use.


; --------------------------------------------------------------------------------
; The next part forms the main flow of the script. The script has several
; subscripts (below) of which each serve different easily identifiable
; purpose.

; INITIAL QUERY TO EXECUTE THE SCRIPT OR NOT
GoSub, query_runscript												; Confirm the execution of the script with OK/Cancel (and 10 sec timeout defaulting to OK).

; GENERAL SETUP VALIDATION
GoSub, init_global													; This subscript checks if all of the prerequisites are valid. Failing one of the tests will most likely end the script.

; FIRST COUNT OF THE FILES (TOTAL AND TAGGED)
GoSub, process_count

Sleep 1000

; MESSAGE BOX ABOUT FOUND FILES AND QUERY TO CONTINUE WITH TAGGING
GoSub, query_count_continue

; THE ACTUAL UNTAGGING OF THE FILES
GoSub, tag_conversion_status

Sleep 2000

; SECOND COUNT OF THE FILES (TOTAL AND TAGGED)
GoSub, process_count

Sleep 500

; MESSAGE BOX ABOUT RESULTING FILES AND THEIR CONVERSION STATUS
GoSub, info_result

End_2:
{
	ExitApp				; This should be the only command/line that exits the script.
}

; --------------------------------------------------------------------------------
; Next part consists of different subscripts. They are located here in the end of
; the script to enhance usability/readablility of this script.

query_runscript:
{
	MsgBox, 1, CHECKING,
	(LTrim
		The selected files are about to get tagged
		as "converted". The process will start
		in 10 seconds.
		
		Continue by selecting "OK".
		
		You can cancel the process by selecting "Cancel".
	), 10
	IfMsgBox Cancel
	{
		GoSub, End_2
	}
	return
}

init_global:
{
	EnvGet, Env_Path, Path

	If (dir_rec = "")
		{
			dir_rec = %A_ScriptDir%
			return
		}
	IfNotExist, %dir_rec%
	{
		MsgBox, 0, SETUP ERROR,
		(LTrim
			The script fails to run as dir_rec (the location
			of the source files) is not a valid location,
			please check the setting or leave the field empty
			to use the script's directory.
		)
		GoSub, End_2
	}

	SetWorkingDir, %dir_rec%
	
	If (conversiontag_method = "rename" or conversiontag_method = "attribute" or conversiontag_method = "logfolder")
	{
		; The script continues only if this attribute is set up correctly.
	}
	else
	{
		MsgBox, 0, SETUP ERROR,
		(LTrim
		Tagging method for converted files is not valid.
		Check conversiontag_method in general prefereces.
		
		The script will end when you click "OK"
		)
		GoSub, End_2
	}
	return
}

process_count:
{
	count_total_files = 0
	count_converted_files = 0
	count_rename = 0
	count_attribute = 0
	count_logfolderfile = 0
	
	Loop, %dir_rec%\*.%extension_rec%
	{
		If (global_filename_iff <> "")
		{
			IfInString, A_LoopFileName, %global_filename_iff%
			{
				; Global rule for file handling was met, proceeding.
			}
			else
			{			
				continue		; Global rule for file handling was not met, skipping the current loop file.
			}
		}
		If (global_filename_ifnot <> "")
		{
			IfInString, A_LoopFileName, %global_filename_ifnot%
			{			
				continue		; Global rule for file exclusion was met, skipping the current loop file.
			}
			else
			{
				; Global rule for file exclusion was not met, proceeding.
			}
		}
		
		count_total_files += 1				

		GoSub, check_conversion_status		; Checking first, if the file has already been converted before continuing. Tagging method is defined by the variable.
		If (conversionstatus = 2)
		{
			count_converted_files += 1
			If (is_attribute = 1)
			{
				count_attribute += 1
				is_attribute = 0
			}
			If (is_logfolderfile = 1)
			{
				count_logfolderfile += 1
				is_logfolderfile = 0
			}
			If (is_rename = 1)
			{
				count_rename += 1
				is_rename = 0
			}
		}
		else
		{
			continue						; Skip to the next file, if the file was not tagged as converted.
		}
	}
	return
}

check_conversion_status:
{
	conversionstatus = 0					; conversionstatus variable is first set as 0 (undetermined), can later be set as 1 (defined as "not converted", though this is hard to establish) or more likely 2 (converted).
	FileGetAttrib, current_fileattributes, %A_LoopFileName%
	IfInString, current_fileattributes, T
	{
		is_attribute = 1
		conversionstatus = 2
		current_fileattributes =
	}
	else
	{
		current_fileattributes =
	}
	IfExist, %dir_rec%\bacar_log\log_data\%A_LoopFileName%.txt
	{
		is_logfolderfile = 1
		conversionstatus = 2
	}
	IfInString, A_LoopFileName, _CONVERTED
	{
		is_rename = 1
		conversionstatus = 2
	}
	return
}

query_count_continue:
{
	MsgBox, 1, COUNT BEFORE TAGGING,
	(LTrim
		Before tagging, there are total of %count_total_files% files
		with the extension .%extension_rec% in
		the directory %dir_rec% .
		
		Of these files, %count_converted_files% have been tagged
		as converted by BACAR.
		
		Total count of different tags:
		attribute -> %count_attribute%
		logfolder -> %count_logfolderfile%
		rename -> %count_rename%
		
		You are about to tag with method "%conversiontag_method%" .
		You can start tagging now by selecting "OK".
		
		You can cancel the process by selecting "Cancel".
	)
	IfMsgBox Cancel
	{
		GoSub, End_2
	}
	return
}

tag_conversion_status:
{
	Loop, %dir_rec%\*.%extension_rec%
	{
		If (conversiontag_method = "attribute")
		{
			FileSetAttrib, +T, %A_LoopFileName%
		}
		If (conversiontag_method = "logfolder")
		{
			IfNotExist, %dir_rec%\bacar_log\log_data\%A_LoopFileName%.txt
			{
				IfNotExist, %dir_rec%\bacar_log
				{
					RunWait, %comspec% /c mkdir "%dir_rec%\bacar_log"
					Sleep 500
					IfNotExist, %dir_rec%\bacar_log
					{
						FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : bacar_log directory for conversion logging could not be created, quitting. `n", %dir_rec%\conversionlog-%current_year%.txt	
						GoSub, End_2
					}			
				}
				IfNotExist, %dir_rec%\bacar_log\readme.txt
				{
					FileAppend, This folder was created to keep track of the files converted successfully by BACAR script. `n, %dir_rec%\bacar_log\readme.txt
					FileAppend, The use of this folder is promoted by the script variable conversiontag_method. `n, %dir_rec%\bacar_log\readme.txt
					FileAppend, Please be aware that deleting this folder or the data in it also erases the conversion log. `n, %dir_rec%\bacar_log\readme.txt
					Sleep 500
				}
				IfNotExist, %dir_rec%\bacar_log\log_data
				{
					RunWait, %comspec% /c mkdir "%dir_rec%\bacar_log\log_data"
					Sleep 500
					IfNotExist, %dir_rec%\bacar_log\log_data
					{
						FileAppend, % A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " : bacar_log\log_data directory for conversion logging could not be created, quitting. `n", %dir_rec%\conversionlog-%current_year%.txt	
						GoSub, End_2
					}			
				} 
				FileAppend, % "Tagged without conversion " A_DD "/" A_MM "/" A_YYYY " " A_Hour ":" A_Min ":" A_Sec " `n", %dir_rec%\bacar_log\log_data\%A_LoopFileName%.txt
				Sleep 500
			}
		}
		If (conversiontag_method = "rename")
		{
			IfNotInString, A_LoopFileName, _CONVERTED
			{
				StringLen, length_extension_rec, extension_rec
				length_extensionplusperiod_rec := (length_extension_rec + 1)
				StringTrimRight, filenamebody, A_LoopFileName, %length_extensionplusperiod_rec%
				RunWait, %comspec% /c rename "%dir_rec%\%A_LoopFileName%" "%filenamebody%_CONVERTED.%extension_rec%"
				Sleep 200
			}
		}
	}
	return
}

info_result:
{
	MsgBox, 0, FINAL COUNT,
	(LTrim
		After tagging, there are total of %count_total_files%
		with the extension .%extension_rec% in
		the directory %dir_rec% .
		
		Of these files, %count_converted_files% are still tagged
		as converted by BACAR.
		
		Total count of different tags:
		attribute -> %count_attribute%
		logfolder -> %count_logfolderfile%
		rename -> %count_rename%
		
		Click "OK" to exit.
	)
	return
}
