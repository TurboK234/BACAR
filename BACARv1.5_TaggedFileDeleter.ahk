; BACAR Tagged Source File Deleter v.1.5
; Copyright (c) 2016 Henrik Söderström
; This script is published under Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0) licence.
; You are free to use the script as you please, even commercially, but you should publish the edited code
; under the same licence and give the original creator appropriate credit. More information about the licence
; can be found at http://creativecommons.org/licenses/by-sa/4.0/ .

; This script is used to delete files, that have the "file already converted" tag. This tag is created by BACAR script,
; and it involves the original (source) files of the conversion process.
; There are different methods to tag the files, and the method is promoted by conversiontag_method variable of the
; main BACAR script. This script checks all of the methods and gives a report of the found files before deleting the files.
; You should not be able to delete anything else than BACAR tagged files with this script, unless you really want to
; fake the tagging manually (like creating a fake filename.ext.txt file in bacar_log\log_data\).
; Tip: If you want to delete the source files automatically you can use the days_keepold variable in BACAR. If you want
; to delete the files right after the successful conversion in an automated manner you can use the days_keepold = 0 .
; In this case, you should be very sure that the resulting files are converted the way that you want to.
; This script, instead, has confirmation queries for safety. This was mainly created to help setting up the system.

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

; MESSAGE BOX ABOUT FOUND FILES AND QUERY TO CONTINUE WITH DELETING
GoSub, query_count_continue

; FINAL CONFIRMATION QUERY BEFORE DELETING
GoSub, query_for_deleting	

; THE ACTUAL DELETING
GoSub, delete_tagged_files

Sleep 1000

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
		The deletion of the selected files
		is about to be begin in 10 seconds.
		
		Note that the script will use the folder
		in which it is located if dir_rec is not
		defined.
		
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
	MsgBox, 1, COUNT BEFORE DELETING,
	(LTrim
		Before deleting, there are total of %count_total_files% files
		with the extension .%extension_rec% in
		the directory %dir_rec% .
		
		Of these files, %count_converted_files% have been tagged
		as converted by BACAR.
		
		Total count of different tags:
		attribute -> %count_attribute%
		logfolder -> %count_logfolderfile%
		rename -> %count_rename%
		
		You are about to delete the (source) files that have
		been tagged as being converted. Make sure that the target
		files are valid and in a safe location.
		You can start deleting now by selecting "OK".
		
		You can cancel the process by selecting "Cancel".
	)
	IfMsgBox Cancel
	{
		GoSub, End_2
	}
	return
}

query_for_deleting:
{
	MsgBox, 1, FINAL WARNING,
	(LTrim
		The script will delete the converted files
		permanently, are you sure?
		
		Continue by selecting "OK".
		
		You can cancel the process by selecting "Cancel".
	), 10
	IfMsgBox Cancel
	{
		GoSub, End_2
	}
	return
}


delete_tagged_files:
{
	Loop, %dir_rec%\*.%extension_rec%
	{
		Sleep 200
		conversionstatus = 0					; conversionstatus variable is first set as 0 (undetermined), no files should be deleted accidentally.
		IfExist, %dir_rec%\bacar_log\log_data\%A_LoopFileName%.txt
		{
			RunWait, %comspec% /c del /Q "%dir_rec%\%A_LoopFileName%"
			RunWait, %comspec% /c del /Q "%dir_rec%\bacar_log\log_data\%A_LoopFileName%.txt"
			continue
		}
		FileGetAttrib, current_fileattributes, %A_LoopFileName%
		IfInString, current_fileattributes, T
		{
			RunWait, %comspec% /c del /Q "%dir_rec%\%A_LoopFileName%"
			current_fileattributes =			; makes sure that the next file can not be erroneously evaluated as having T attribute.
			continue							; continues to the next file, since the loop file does not exist anymore.
		}
		else
		{
			current_fileattributes =			; makes sure that the next file can not be erroneously evaluated as NOT having T attribute.
		}
		IfInString, A_LoopFileName, _CONVERTED
		{
			RunWait, %comspec% /c del /Q "%dir_rec%\%A_LoopFileName%"
			continue
		}
	}
	return
}

info_result:
{
	MsgBox, 0, FINAL COUNT,
	(LTrim
		After deleting, there are total of %count_total_files%
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
