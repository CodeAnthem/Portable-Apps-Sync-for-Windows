@echo off
:: #################################################################################################################################################################################
:: | [CRAFTED] PAS Manager | Portable App Sync by CodeAnthem | Created: 22.07.2023
:: | [AUTHOR] CodeAnthem | [MODIFIED] 24.05.2024 | [VERSION] 1.03
:: ----------------------------------------------------------------------------------------------------------------------------------------------------------------
:: | [DESCRIPTION]
:: |  Manager of portable app sync
:: ----------------------------------------------------------------------------------------------------------------------------------------------------------------
:: | [NOTES]
:: |  Hint: Can't be run from network share with admin priviledges
:: ----------------------------------------------------------------------------------------------------------------------------------------------------------------
:: #################################################################################################################################################################################


:: ### SETUP: VARIABLES
:: #################################################################################################################################################################################
    set "pathRemoteRoot="
    set "pathLocalRoot="
    set "remoteTargetFolder="
    set "delayScriptExit=false" REM overwritten by reg config
:: #################################################################################################################################################################################


:: ### WORKFLOW
:: #################################################################################################################################################################################
    call:getHeader "Loading"

    :: SETTINGS MENU
    if "%~1" == "" ( call:settingsMenu && exit )

    :: GET LOCATIONS
    call:getRemoteLocation "%~2"
    call:getLocalLocation

    :: SAVE TARGET DIRECTORY NAME
    set "remoteTargetFolder=%~1"

    :: SET SYSTEM VARIABLES
    set "pathLocalSystem=%pathLocalRoot%\__PAS_System"
    set "pathRemoteSystem=%pathRemoteRoot%\__PAS_System"

    :: DEBUG INFO
   rem  echo "remoteTargetFolder %remoteTargetFolder%"
   rem  echo "pathLocalRoot %pathLocalRoot%"
   rem  echo "pathRemoteRoot %pathRemoteRoot%"
   rem  echo "pathLocalSystem %pathLocalSystem%"
   rem  echo "pathRemoteSystem %pathRemoteSystem%"
   rem  pause

    :: UPDATE SYSTEM
   rem  call:updatePASSystem
    if "%~3" == "forceUpdate" ( call:updatePASSystem ) else ( call:checkIfSystemUpdateRequired )

    :: CALL ITSELF IF NOT RUNNING FROM LOCAL
    set "scriptFileName=%~nx0"
    if "%pathLocalSystem%\%scriptFileName%" NEQ "%~f0" (
       call "%pathLocalSystem%\%scriptFileName%" "%remoteTargetFolder%" "%pathRemoteRoot%"
       exit /b
    )

    :: CREATE NEW DESTINATION FOLDER NAME, remoteTargetFolder + " Tools"
    for /f "usebackq delims=" %%I in (`powershell "\"%remoteTargetFolder%\".toUpper()"`) do set "localTargetFolder=%%~I"
    set "pathLocalTarget=%pathLocalRoot%\%localTargetFolder% Tools"
    if not exist "%pathLocalTarget%" mkdir "%pathLocalTarget%"
    
    :: GET REMOTE TARGET PATH
    set "pathRemoteTarget=%pathRemoteRoot%\%remoteTargetFolder%"
    if exist "%pathRemoteTarget%" ( pushd "%pathRemoteTarget%" >nul ) else ( call:exception_remoteTargetDoesntExist "%pathRemoteTarget%" )

    :: SYNC
    call:getHeader "SYNC %remoteTargetFolder%"
    if not exist "%pathLocalTarget%" mkdir "%pathLocalTarget%"
    call:syncSingleFolder
    call:syncWriteUpdater
    call:syncCreateShortcut "Remote" "%pathLocalTarget%" "%pathRemoteTarget%"
    call:syncExit

    :: EXIT
    exit /b
    pause
:: #################################################################################################################################################################################

:: ### FUNCTIONS: MENUS
:: #################################################################################################################################################################################
    :settingsMenu
        call:getHeader "Settings Menu"
        color 0b
        echo.

        for /f "tokens=2*" %%a in ('reg query "HKCU\Software\PortableAppSync" /v Location 2^>^&1^|find "REG_"') do @set location=%%b
        echo.  - '1' Location  -^> %location%

        for /f "tokens=2*" %%a in ('reg query "HKCU\Software\PortableAppSync" /v DelayExit 2^>^&1^|find "REG_"') do @set exitdelay=%%b
        if "%exitdelay%" == "" ( echo.  - '2' DelayExit -^> false ) else ( echo.  - '2' DelayExit -^> %exitdelay% )

        echo.

        setlocal
        SET /P M="      Type 1, OR 2, then press ENTER:"
        IF "%M%" == "" ( 
          echo.
          echo "Exiting now the menu - Press any key to exit"
          pause > nul
          exit
        )
        IF "%M%" == "1" call:menuToSetLocation
        IF "%M%" == "2" call:menuToSetExitDelay
        endlocal
    goto:settingsMenu
:: ----------------------------------------------------------------------------------------------------------------------------------------------------------------
    :menuToSetLocation
    	call:getHeader "Select a location"
    	color 0b
    	echo. ...............................................
      for /f "tokens=2*" %%a in ('reg query "HKCU\Software\PortableAppSync" /v Location 2^>^&1^|find "REG_"') do @set location=%%b
      if "%location%" == "" ( echo.  No location set! ) else ( echo.  Current value: %location% )
    	echo. ...............................................
    	echo.
    	echo.  - '1' -^> 'C:\_PortableAppSync'
    	echo.  - '2' -^> Profile: '%USERPROFILE%\PortableAppSync'
    	echo.  - '3' -^> Appdata: '%LOCALAPPDATA%\PortableAppSync'
    	echo.  - 'Enter your own location path'
    	echo.
    	SET /P M="      Type 1, 2, 3, custom path or leave it empty, then press ENTER:"
    	IF "%M%"=="" ( call:exception_noValidOptionSelected )
    	IF "%M%" == "1" ( call:regSetLocation "C:\_PortableAppSync" && goto:eof )
    	IF "%M%" == "2" ( call:regSetLocation "%USERPROFILE%\PortableAppSync" && goto:eof )
    	IF "%M%" == "3" ( call:regSetLocation "%LOCALAPPDATA%\PortableAppSync" && goto:eof )
      call:regSetLocation "%M%"
    goto:eof
:: ----------------------------------------------------------------------------------------------------------------------------------------------------------------
    :menuToSetExitDelay
    	call:getHeader "Select a location"
    	color 0b
    	echo. ...............................................
      for /f "tokens=2*" %%a in ('reg query "HKCU\Software\PortableAppSync" /v DelayExit 2^>^&1^|find "REG_"') do @set delayExit=%%b
      if "%delayExit%" == "" ( echo.  Current value: False ) else ( echo.  Current value: %delayExit% )
    	echo. ...............................................
    	echo.
    	echo.  - '1' -^> 'True'
    	echo.  - '2' -^> 'False'
    	echo.
    	SET /P M="      Type 1 OR 2 then press ENTER:"
    	IF "%M%" == "1" ( call:regSetExitDelay "True" && goto:eof )
    	IF "%M%" == "2" ( call:regSetExitDelay "False" && goto:eof )
    goto:eof
:: #################################################################################################################################################################################


:: ### FUNCTIONS: Locations
:: #################################################################################################################################################################################
    :regSetExitDelay
       >nul reg add "HKCU\Software\PortableAppSync" /F /v DelayExit /t REG_SZ /d "%~1"
    goto:eof
:: ----------------------------------------------------------------------------------------------------------------------------------------------------------------
    :regSetLocation
       >nul reg add "HKCU\Software\PortableAppSync" /F /v Location /t REG_SZ /d "%~1"
       set "pathLocalRoot=%~1"
    goto:eof
:: ----------------------------------------------------------------------------------------------------------------------------------------------------------------
    :getLocalLocation
       for /f "tokens=2*" %%a in ('reg query "HKCU\Software\PortableAppSync" /v Location 2^>^&1^|find "REG_"') do @set pathLocalRoot=%%b
       if "%pathLocalRoot%" == "" call:menuToSetLocation
    goto:eof
    :getRemoteLocation
       if "%~1"=="" ( for %%i in ("%~dp0..") do set "pathRemoteRoot=%%~fi" ) else ( set "pathRemoteRoot=%~1" )
       if not exist "%pathRemoteRoot%" call:exception_remoteLocationDoesntExist "%pathRemoteRoot%"
    goto:eof
:: #################################################################################################################################################################################


:: ### FUNCTIONS: UPDATE SYSTEM
:: #################################################################################################################################################################################
    :checkIfSystemUpdateRequired
       call:getHeader "System Update Check"
       color 0d
       :: check if local location exists or create it
          if not exist "%pathLocalRoot%" mkdir "%pathLocalRoot%" || call:exception_unableToCreatePASdirectory "%pathLocalRoot%"
         rem  if not exist "%pathLocalRoot%" ( call:exception_unableToCreatePASdirectory "%pathLocalRoot%" )
       :: update system if system directory doesnt exist
          if not exist "%pathLocalSystem%" ( call:updatePASSystem && goto:eof )
       :: compare version and update system if mismatch
          :: get remote version
          for /f %%f in ('dir /b /on /a-d "%pathRemoteSystem%\v*.version"') do set "remoteVersionFile=%pathRemoteSystem%\%%~f"
          if not exist "%remoteVersionFile%" ( call:exception_remoteVersionFileNotFound "%pathRemoteSystem%" )
          set /p remoteVersion=<"%remoteVersionFile%"
          :: get local version
          for /f %%f in ('dir /b /on /a-d "%pathLocalSystem%\v*.version"') do set "localVersionFile=%pathLocalSystem%\%%~f"
          set /p localVersion=<"%localVersionFile%"
          :: skip update if versions equal
          if "%localVersion%"=="%remoteVersion%" ( goto:eof )
       :: update system
       call:updatePASSystem
    goto:eof
:: ----------------------------------------------------------------------------------------------------------------------------------------------------------------
    :updatePASSystem
       call:getHeader "System Updating"
       robocopy "%pathRemoteSystem%" "%pathLocalSystem%" /PURGE /LEV:1 /NJH /NDL /NJS /NFL /NP /XF "_Setup_IncrementVersion.bat"
       call:getHeader "System Updated!"
       call:syncCreateShortcut "Remote" "%pathLocalSystem%" "%pathRemoteSystem%"
       call:syncCreateShortcut "Remote" "%pathLocalRoot%" "%pathRemoteRoot%"
       call:updateWriteAllUpdater
    goto:eof
:: ----------------------------------------------------------------------------------------------------------------------------------------------------------------
    :updateWriteAllUpdater
       set "_fileName=%pathLocalRoot%\PortableAppSync_UpdateAll.bat"
       echo>"%_fileName%" @echo off
       echo>>"%_fileName%" :: Automatically generated from PortableAppSync
       echo>>"%_fileName%" mkdir "%pathLocalSystem%"
       echo>>"%_fileName%" copy ^>nul "%pathRemoteSystem%\PortableAppSync_UpdateAllWorkflow.bat" "%pathLocalSystem%\PortableAppSync_UpdateAllWorkflow.bat"
       echo>>"%_fileName%" call "%pathLocalSystem%\PortableAppSync_UpdateAllWorkflow.bat"
       echo>>"%_fileName%" exit /b
    goto:eof
:: #################################################################################################################################################################################


:: ### FUNCTIONS: SYNC SINGLE FOLDER
:: #################################################################################################################################################################################
    :syncSingleFolder
       :: EXCLUDE FILTER
       set "rcSettings=/NS /NC /NFL /NDL /NP /NJS /NJH /XF "*.url""
       call:getExcludedFiles
      rem  echo rcSettings:
      rem  echo %rcSettings%
      rem  pause

       :: SYNC NOW
       color 0e
       echo. - Sync Started:
      rem  echo "pathRemoteTarget %pathRemoteTarget%"
      rem  echo "pathLocalTarget %pathLocalTarget%"
       robocopy "%pathRemoteTarget%" "%pathLocalTarget%" /mir %rcSettings%
       color 0a
       echo. - Sync Done!
    goto:eof
:: ----------------------------------------------------------------------------------------------------------------------------------------------------------------
    :getExcludedFiles
       SetLocal EnableDelayedExpansion
       if not exist "excludedFiles.txt" goto:eof
       set "rcSettings=!rcSettings! /xf excludedFiles.txt"
       set "rcSettings=!rcSettings! /xf IncrementVersion.bat"
       set "rcSettings=!rcSettings! /xf __DownloadToComputer.bat"
       
       :: ADD ENTRIES OF EXCLUDE FILE TO rcSettings
       for /F "tokens=*" %%A in (excludedFiles.txt) do ( if exist "%pathRemoteTarget%\%%A" set "rcSettings=!rcSettings! /xf "%pathRemoteTarget%\%%A"" )
       
       for /F "delims=" %%V in ("!rcSettings!") DO (    
         endlocal
         set "rcSettings=%%V"
       )		
    goto:eof & set rcSettings
:: ----------------------------------------------------------------------------------------------------------------------------------------------------------------
    :syncWriteUpdater
       echo>"%pathLocalTarget%\Updater.bat" @echo off
       echo>>"%pathLocalTarget%\Updater.bat" cd /d "%%~dp0"
       echo>>"%pathLocalTarget%\Updater.bat" if not exist "..\__PAS_System\%~nx0" (
       echo>>"%pathLocalTarget%\Updater.bat"     copy ^>nul "%pathRemoteSystem%\%~nx0" "..\__PAS_System\%~nx0"
       echo>>"%pathLocalTarget%\Updater.bat"     call "..\__PAS_System\%~nx0" "%remoteTargetFolder%" "%pathRemoteRoot%" "forceUpdate"
       echo>>"%pathLocalTarget%\Updater.bat" ) else ( call "..\__PAS_System\%~nx0" "%remoteTargetFolder%" "%pathRemoteRoot%" )
       echo. - Updater written successfully
    goto:eof
:: ----------------------------------------------------------------------------------------------------------------------------------------------------------------
    :syncCreateShortcut
       set "shortcut_name=%~1"
       set "shortcut_location=%~2"
       set "shortcut_target=%~3"
      rem  echo "shortcut_name %shortcut_name%"
      rem  echo "shortcut_location %shortcut_location%"
      rem  echo "shortcut_target %shortcut_target%"
      rem  pause
       powershell "$s=(New-Object -COM WScript.Shell).CreateShortcut('%shortcut_location%\%shortcut_name%.lnk');$s.TargetPath='%shortcut_target%';$s.Save()"
       echo. - Shortcut created successfully
    goto:eof
:: ----------------------------------------------------------------------------------------------------------------------------------------------------------------
    :syncExit
       for /f "tokens=2*" %%a in ('reg query "HKCU\Software\PortableAppSync" /v DelayExit 2^>^&1^|find "REG_"') do @set delayScriptExitReg=%%b
       if "%delayScriptExitReg%" NEQ "" set "delayScriptExit=%delayScriptExitReg%"
       if "%delayScriptExit%"=="true" (
           echo.
           echo. Closing in 2 seconds
           timeout /t 2 /nobreak >nul
       )
    goto:eof
:: #################################################################################################################################################################################


:: ### FUNCTIONS: ERRORS
:: #################################################################################################################################################################################
    :exception_argumentsMissing
       color 0c
       echo =====================================================================================================
       echo. Invalid Argumnets:
       echo. Arg1: '%~1'
       echo. Arg2: '%~2'
       echo. - Abort
       echo =====================================================================================================
       echo.
       pause
    exit /b
    :exception_remoteLocationDoesntExist
       color 0c
       echo =====================================================================================================
       echo. "Remote location does not exist: '%~1'"
       echo. - Abort
       echo =====================================================================================================
       echo.
       pause
    exit /b
    :exception_remoteTargetDoesntExist
       color 0c
       echo =====================================================================================================
       echo. "Remote target does not exist: '%~1'"
       echo. - Abort
       echo =====================================================================================================
       echo.
       pause
    exit /b
    :exception_noValidOptionSelected
       color 0c
       echo =====================================================================================================
       echo. "No valid option selected"
       echo. - Abort
       echo =====================================================================================================
       echo.
       pause
    exit /b
    :exception_unableToCreatePASdirectory
       color 0c
       echo =====================================================================================================
       echo. "Unable to create directory at: '%~1'"
       echo. - Abort
       echo =====================================================================================================
       echo.
       pause
    exit /b
    :exception_remoteVersionFileNotFound
       color 0c
       echo =====================================================================================================
       echo. "Remote directory doesn't have any version file at: '%~1'"
       echo. - Abort
       echo =====================================================================================================
       echo.
       pause
    exit /b
:: #################################################################################################################################################################################


:: ### FUNCTIONS: UI
:: #################################################################################################################################################################################
    :getHeader
       cls
       echo =====================================================================================================
       if "%~1" == "" (
          echo. Portable Apps Sync
       ) else (
          echo. Portable Apps Sync: %~1
          title PAS: %~1
       )
       echo =====================================================================================================
       echo.
    goto:eof
:: #################################################################################################################################################################################

