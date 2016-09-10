; BACAR Lone Tag File Cleaner
; Copyright (c) 2016 Henrik Söderström
; This script is published under Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0) licence.
; You are free to use the script as you please, even commercially, but you should publish the edited code
; under the same licence and give the original creator appropriate credit. More information about the licence
; can be found at http://creativecommons.org/licenses/by-sa/4.0/ .

; This script is used to remove clean up (=delete) old converted file "tag" files that are created
; when conversiontag_method := "logfolder" is used. The tagging method is used to check if there is a
; file created for the video file and decides to either convert or skip the file. The old log files
; are deleted if the original video file is being removed with BACAR using the days_keepold = setting.
; But if the user deletes the original video file manually, the old log files will stay in the
; %dir_rec%\bacar_log\log_data\ forever. This script was created to help keeping things clean, so that
; the log_data\ folder will only keep those .txt files that actually have a valid counterpart (video)
; file. Other .txt files are deleted, as they serve no purpose (well, you can use them to keep track of
; what you have converted, ever. Even if you don't have the originals left).
; There is also the parameter clean_logfolder = yes in BACAR, that does the exact same thing every
; time BACAR is being run, so this script can only be used when setting up the system.

; GENERAL AUTOHOTKEY SETUP, DON'T EDIT, COMMENTS PROVIDED FOR CLARIFICATION.
SendMode, Input  													; Recommended for new scripts due to its superior speed and reliability.
#NoEnv  															; Recommended for performance and compatibility with future AutoHotkey releases.
#SingleInstance FORCE												; There can only be one instance of this script running.
SetWorkingDir, %A_ScriptDir% 										; Ensures a consistent starting directory (will be overwritten later in this script).
FileEncoding, UTF-8													; Used in coherence with actual file converter script (BACAR).
StringCaseSense, On													; Turns on case-sensitivity, which helps to create more specific commands.

; GENERAL PREFERENCES (USER CONFIRMATION REQUIRED). DO NOT REMOVE THE 2x DOUBLE QUOTES, FILL THE VALUE BETWEEN THEM, USE "" FOR EMPTY.
dir_rec := ""														; The complete path (without the last "\") of the video files. Note: The tag files are not in this folder, but in %dir_rec%\bacar_log\log_data\. Leave empty "" to use script's directory (as video file location).

; --------------------------------------------------------------------------------
; The next part forms the main flow of the script. The script has several
; subscripts (below) of which each serve different easily identifiable
; purpose.

; GENERAL SETUP VALIDATION
GoSub, init_global													; This subscript checks if all of the prerequisites are valid. Failing one of the tests will most likely end the script.

; INITIAL QUERY TO EXECUTE THE SCRIPT OR NOT
GoSub, query_runscript												; Confirm the execution of the script with OK/Cancel (and 10 sec timeout defaulting to OK).


; FIRST COUNT OF THE LONE TAG FILES
GoSub, process_count

Sleep 1000

; MESSAGE BOX ABOUT FOUND TAG FILES AND QUERY TO CONTINUE WITH REMOVING THE LONE FILES
GoSub, query_count_continue

; THE ACTUAL REMOVING OF THE LONE TAG FILES
GoSub, remove_lone_tag_files

Sleep 2000

; SECOND COUNT OF THE LONE TAG FILES
GoSub, process_count

; DELETE THE TAGGING FOLDER IF IT IS LEFT EMPTY AFTER THE PROCESS
GoSub, remove_empty_tag_folder

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

query_runscript:
{
	MsgBox, 1, CHECKING,
	(LTrim
		Tag files in
		%dir_rec%\bacar_log\log_data\
		
		without source file counterpart	in
		%dir_rec%
		
		are about to be removed. The process will start
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

process_count:
{
	count_total_files = 0
	count_lone_files = 0
	
	IfExist, %dir_rec%\bacar_log\log_data\
		Loop, %dir_rec%\bacar_log\log_data\*.txt
		{
			count_total_files += 1				
	
			StringTrimRight, tagsource_filename, A_LoopFileName, 4				; This removes four characters (.txt) from the file name and saves the supposed source file name in a variable.
			IfNotExist, %dir_rec%\%tagsource_filename%
			{
				count_lone_files += 1	; In this case the tag file does not have a valid counterpart file, and is prone to be deleted.
			}
			else
			{
				continue				; In this case the tag file has a valid counterpart file and the script skips to the next file.
			}	
		}
		else
		{
			MsgBox, 0, NOTHING TO CLEAN,
			(LTrim
				There seems to be no folder to clean, exiting.
				
				(Should be %dir_rec%\bacar_log\log_data\)
			)
			GoSub, End_2
		}
	return
}

query_count_continue:
{
	MsgBox, 1, COUNT BEFORE CLEANING,
	(LTrim
		Before cleaning, there are total of %count_total_files%
		tag files in the directory
		%dir_rec%\bacar_log\log_data\ .
		
		Of these files, %count_lone_files% have no valid source
		file available and these lone files may be removed.
		If there are no files left after the removal, the folder
		%dir_rec%\bacar_log\ is also removed.
				
		You can remove the lone tag files now by selecting "OK".
		
		You can cancel the process by selecting "Cancel".
	)
	IfMsgBox Cancel
	{
		GoSub, End_2
	}
	return
}

remove_lone_tag_files:
{
	Loop, %dir_rec%\bacar_log\log_data\*.txt
	{
		StringTrimRight, tagsource_filename, A_LoopFileName, 4				; This removes four characters (.txt) from the file name and saves the supposed source file name in a variable.
		IfExist, %dir_rec%\%tagsource_filename%
		{
			continue				; In this case the tag file has a valid counterpart file and the script skips to the next file.
		}
		else
		{
			RunWait, %comspec% /c del /Q "%dir_rec%\bacar_log\log_data\%A_LoopFileName%"
		}		
	}
	return
}

remove_empty_tag_folder:
{
	count_total_files_after = 0
	Loop, %dir_rec%\bacar_log\log_data\*.*
	{
		count_total_files_after += 1
	}
	If (count_total_files_after < 1)
	{
		RunWait, %comspec% /c rd /S /Q "%dir_rec%\bacar_log"
		msg_tagfolder := "The tag folder bacar_log\ was empty and was deleted"
	}
	else
	{
		msg_tagfolder := "The tag folder still has files and was not removed"
	}
	return
}

info_result:
{
	MsgBox, 0, FINAL COUNT,
	(LTrim
		After cleaning, there are total of %count_total_files%
		tag files in the directory
		%dir_rec%\bacar_log\log_data\ .
		
		Of these files, %count_lone_files% files is/are missing
		the corresponding source file.
		
		%msg_tagfolder%
		
		Click "OK" to exit.
	)
	return
}
