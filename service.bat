@echo off
:: ═════╣ Устанавливаем шрифт ╠═════
reg add "HKCU\Console" /v "FaceName" /t REG_SZ /d "Lucida Console" /f > nul
reg add "HKCU\Console" /v "FontFamily" /t REG_DWORD /d 54 /f > nul

:: ═════╣ Устанавливаем UTF-8 ╠═════
chcp 65001 > nul
title NoBan service v6.0
set "LOCAL_VERSION=6.0"

:: External commands
if "%~1"=="status_noban" (
    call :test_service NoBan soft
    call :tcp_enable
    exit /b
)

if "%~1"=="check_updates" (
    if not "%~2"=="soft" (
        start /b service check_updates soft
    ) else (
        call :service_check_updates soft
    )
    exit /b
)

if "%~1"=="load_game_filter" (
    call :game_switch_status
    exit /b
)


if "%1"=="admin" (
    echo Старт с правами администратора
) else (
    echo Запрос на права администратора...
    powershell -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
    exit /b
)


:: ═════╣ Главное меню ╠═════
setlocal EnableDelayedExpansion
:menu
cls
call :ipset_switch_status
call :game_switch_status

set "menu_choice=null"
color 0F
echo ╠═════════ NoBan v!LOCAL_VERSION! ═════════╣
echo.
echo [1] Проверить статус
echo [2] Выполнить диагностику
echo [3] Проверить обновления
echo [4] Переключить игровой фильтр (%GameFilterStatus%)
echo [5] Переключить ipset (%IPsetStatus%)
echo [6] Установить автозагрузку
echo [7] Убрать автозагрузку / Остановить NoBan
echo [0] Выход
echo.
echo ╠═════════ NoBan v!LOCAL_VERSION! ═════════╣
echo.
set /p menu_choice=Введите выбор [0-7]:

if "%menu_choice%"=="1" goto service_status
if "%menu_choice%"=="2" goto service_diagnostics
if "%menu_choice%"=="3" goto service_check_updates
if "%menu_choice%"=="4" goto game_switch
if "%menu_choice%"=="5" goto ipset_switch
if "%menu_choice%"=="6" goto service_install
if "%menu_choice%"=="7" goto service_remove
if "%menu_choice%"=="0" exit /b
goto menu


:: TCP ENABLE ==========================
:tcp_enable
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul || netsh interface tcp set global timestamps=enabled > nul 2>&1
exit /b


:: ═════╣ Статус ╠═════
:service_status
cls
REM chcp 437 > nul
REM chcp 65001


sc query "NoBan.exe" >nul 2>&1
if !errorlevel!==0 (
    for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\NoBan" /v NoBan 2^>nul') do echo Service strategy installed from "%%B"
)

call :test_service NoBan
call :test_service WinDivert
echo:

tasklist /FI "IMAGENAME eq NoBan.exe" | find /I "NoBan.exe" > nul
if !errorlevel!==0 (
    call :PrintGreen " ╠══════ Обход NoBan активен ══════╣ "
	call :PrintGreen " "
) else (
    call :PrintRed " ╠══════ Обход NoBan не активен ══════╣ "
	call :PrintRed " "
)

pause
goto menu

:test_service
set "ServiceName=%~1"
set "ServiceStatus="

for /f "tokens=3 delims=: " %%A in ('sc query "%ServiceName%" ^| findstr /i "STATE"') do set "ServiceStatus=%%A"
set "ServiceStatus=%ServiceStatus: =%"

if "%ServiceStatus%"=="RUNNING" (
    if "%~2"=="soft" (
        echo "%ServiceName%" УЖЕ ЗАПУЩЕН как служба, используйте "service.bat" и выберите "Remove Services" сначала если хотите запустить отдельный bat.
        pause
        exit /b
    ) else (
        echo "%ServiceName%" служба запущена.
    )
) else if "%ServiceStatus%"=="STOP_PENDING" (
    call :PrintYellow "!ServiceName! останавливается, это может быть вызвано конфликтом с другим обходом. Запустите диагностику для исправления конфликтов"
) else if not "%~2"=="soft" (
    echo "%ServiceName%" служба не запущена.
)

exit /b


:: ═════╣ Автозагрузка ╠═════
:service_remove
cls
chcp 65001

set SRVCNAME=NoBan
sc query "!SRVCNAME!" >nul 2>&1
if !errorlevel!==0 (
    net stop %SRVCNAME%
    sc delete %SRVCNAME%
) else (
    echo Профиль "%SRVCNAME%" не добавлен в автозагрузку!
)

tasklist /FI "IMAGENAME eq NoBan.exe" | find /I "NoBan.exe" > nul
if !errorlevel!==0 (
    taskkill /IM NoBan.exe /F > nul
)

sc query "WinDivert" >nul 2>&1
if !errorlevel!==0 (
    net stop "WinDivert"

    sc query "WinDivert" >nul 2>&1
    if !errorlevel!==0 (
        sc delete "WinDivert"
    )
)
net stop "WinDivert14" >nul 2>&1
sc delete "WinDivert14" >nul 2>&1

pause
goto menu


:: ═════╣ Автозагрузка ╠═════
:service_install
cls
::chcp 65001

:: Основной
cd /d "%~dp0"
set "BIN_PATH=%~dp0bin\"
set "LISTS_PATH=%~dp0lists\"
set "AUTOLOAD_PATH=%~dp0autoload\"

:: Проверяем существование папки autoload
color C
if not exist "!AUTOLOAD_PATH!" (
    echo.
    echo ╠════════════ Ошибка ════════════╣
    echo.
    echo    Папка "autoload" не найдена!
    echo.
    echo ╠════════════ Ошибка ════════════╣
    echo.
    echo.
    echo.
    pause
    goto menu
    )
)

:: Если в папке autoload нет .bat файлов
if !count!==0 (
    echo.
    echo ╠════════════ Ошибка ════════════╣
    echo.
    echo В папке "autoload" не найдено ни одного .bat-файла!
    echo.
    echo ╠════════════ Ошибка ════════════╣
    echo.
    echo.
    echo.
    pause
    goto menu
)

:: Поиск файлов .bat в папке автозагрузки
color 0F
echo ╠══════ Выберите профиль ══════╣

echo.
set "count=0"
for %%f in ("!AUTOLOAD_PATH!*.bat") do (
    set "filename=%%~nxf"
    if /i not "!filename:~0,7!"=="service" (
        set /a count+=1
        echo !count!. %%~nf
        set "file!count!=%%f"
        set "name!count!=%%~nxf"
    )
)

:: Аргументы: «Значение должно быть достигнуто».
set "choice="
echo.
set /p "choice=Введите выбор [1-4]: "
if "!choice!"=="" goto :eof

set "selectedFile=!file%choice%!"
set "selectedFileName=!name%choice%!"
if not defined selectedFile (
    echo Неверный выбор!
    pause
    goto menu
)

:: Аргументы, за которыми должно следовать значение.
set "args_with_value=sni"

:: Разбор аргументов (mergeargs: 2=start param|3=arg with value|1=params args|0=default)
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="

for /f "tokens=*" %%a in ('type "!selectedFile!"') do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"

    echo !line! | findstr /i "%BIN%NoBan.exe" >nul
    if not errorlevel 1 (
        set "capture=1"
    )

    if !capture!==1 (
        if not defined args (
            set "line=!line:*%BIN%NoBan.exe"=!"
        )

        set "temp_args="
        for %%i in (!line!) do (
            set "arg=%%i"

            if not "!arg!"=="^" (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 (
                    set "mergeargs=0"
                )

                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"

                    echo !arg! | findstr ":" >nul
                    if !errorlevel!==0 (
                        set "arg=\!QUOTE!!arg!\!QUOTE!"
                    ) else if "!arg:~0,1!"=="@" (
                        set "arg=\!QUOTE!@%~dp0!arg:~1!\!QUOTE!"
                    ) else if "!arg:~0,5!"=="%%BIN%%" (
                        set "arg=\!QUOTE!!BIN_PATH!!arg:~5!\!QUOTE!"
                    ) else if "!arg:~0,7!"=="%%LISTS%%" (
                        set "arg=\!QUOTE!!LISTS_PATH!!arg:~7!\!QUOTE!"
                    ) else (
                        set "arg=\!QUOTE!%~dp0!arg!\!QUOTE!"
                    )
                ) else if "!arg:~0,12!" EQU "%%GameFilter%%" (
                    set "arg=%GameFilter%"
                )

                if !mergeargs!==1 (
                    set "temp_args=!temp_args!,!arg!"
                ) else if !mergeargs!==3 (
                    set "temp_args=!temp_args!=!arg!"
                    set "mergeargs=1"
                ) else (
                    set "temp_args=!temp_args! !arg!"
                )

                if "!arg:~0,2!" EQU "--" (
                    set "mergeargs=2"
                ) else if !mergeargs!==2 (
                    set "mergeargs=1"
                ) else if !mergeargs!==1 (
                    for %%x in (!args_with_value!) do (
                        if /i "%%x"=="!arg!" (
                            set "mergeargs=3"
                        )
                    )
                )
            )
        )

        if not "!temp_args!"=="" (
            set "args=!args! !temp_args!"
        )
    )
)

:: Создание сервиса с разобранными аргументами
call :tcp_enable

set ARGS=%args%
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
echo Final args: !ARGS!
set SRVCNAME=NoBan

net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
sc create %SRVCNAME% binPath= "\"%BIN_PATH%NoBan.exe\" !ARGS!" DisplayName= "NoBan" start= auto
sc description %SRVCNAME% "Программное обеспечение для обхода DPI NoBan"
sc start %SRVCNAME%
reg add "HKLM\System\CurrentControlSet\Services\NoBan" /v NoBan /t REG_SZ /d "!selectedFileName!" /f

color 0A
echo.
echo NoBan успешно добавлен в Автозагрузку!
echo.
pause
goto menu

:: ═════╣ Проверка обновлений ╠═════
:service_check_updates
chcp 65001
cls

:: Set current version and URLs
set "GITHUB_VERSION_URL=6.0"
set "GITHUB_RELEASE_URL=https://github.com/wcrasss/NoBan/releases"
set "GITHUB_DOWNLOAD_URL=https://github.com/wcrasss/NoBan/releases"

:: Get the latest version from GitHub
for /f "delims=" %%A in ('powershell -command "(Invoke-WebRequest -Uri \"%GITHUB_VERSION_URL%\" -Headers @{\"Cache-Control\"=\"no-cache\"} -TimeoutSec 5).Content.Trim()" 2^>nul') do set "GITHUB_VERSION=%%A"

:: Error handling
if "%LOCAL_VERSION%"=="%GITHUB_VERSION%" (
    echo Latest version installed: %LOCAL_VERSION%
    
    if "%1"=="soft" exit 
    pause
    goto menu
) 

color 0F
echo.
echo ╠══════════════════ NoBan !LOCAL_VERSION! ══════════════════╣
echo.
echo  Страница релиза: github.com/wcrasss/NoBan/releases
echo.
echo ╠══════════════════ NoBan !LOCAL_VERSION! ══════════════════╣
echo.

set "CHOICE="
set /p "CHOICE="[i] Хотите посмотреть версии NoBan? (да/нет): "
if "%CHOICE%"=="" set "CHOICE=Y"
if /i "%CHOICE%"=="да" set "CHOICE=Y"

if /i "%CHOICE%"=="Y" (
    echo Открываю страницу загрузки...
    start "" "https://github.com/wcrasss/NoBan/releases"
)


if "%1"=="soft" exit 
pause
goto menu
)

:: Version comparison ==============================================
if "%LOCAL_VERSION%"=="%GITHUB_VERSION%" (
    echo Latest version installed: %LOCAL_VERSION%
    
    if "%1"=="soft" exit 
    pause
    goto menu
) 

color 0F
echo.
echo ╠══════════════════ NoBan !LOCAL_VERSION! ══════════════════╣
echo.
echo  Страница релиза: github.com/wcrasss/NoBan/releases
echo.
echo ╠══════════════════ NoBan !LOCAL_VERSION! ══════════════════╣
echo

set "CHOICE="
set /p "CHOICE="[i] Хотите посмотреть версии NoBan? (да/нет): "
if "%CHOICE%"=="" set "CHOICE=Y"
if /i "%CHOICE%"=="да" set "CHOICE=Y"

if /i "%CHOICE%"=="Y" (
    echo Открываю страницу загрузки...
    start "" "https://github.com/wcrasss/NoBan/releases"
)


if "%1"=="soft" exit 
pause
goto menu



:: DIAGNOSTICS =========================
:service_diagnostics
cls

:: Base Filtering Engine
sc query BFE | findstr /I "RUNNING" > nul
if !errorlevel!==0 (
    call :PrintGreen "[+] Проверка Base Filtering Engine пройдена"
) else (
    call :PrintRed "[-] Base Filtering Engine не запущен. Эта служба требуется для работы NoBan"
)
echo:

:: TCP timestamps check
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul
if !errorlevel!==0 (
    call :PrintGreen "[+] Проверка TCP timestamps пройдена"
) else (
    call :PrintYellow "[?] TCP timestamps отключены. Включаю timestamps..."
    netsh interface tcp set global timestamps=enabled > nul 2>&1
    if !errorlevel!==0 (
        call :PrintGreen "[+] TCP timestamps успешно включены"
    ) else (
        call :PrintRed "[-] Не удалось включить TCP timestamps"
    )
)
echo:

:: AdguardSvc.exe
tasklist /FI "IMAGENAME eq AdguardSvc.exe" | find /I "AdguardSvc.exe" > nul
if !errorlevel!==0 (
    call :PrintRed "[-] Найден процесс Adguard. Adguard может вызывать проблемы с Discord"
) else (
    call :PrintGreen "[+] Проверка Adguard пройдена"
)
echo:

:: Killer
sc query | findstr /I "Killer" > nul
if !errorlevel!==0 (
    call :PrintRed "[-] Найдены службы Killer. Killer конфликтует с NoBan"
) else (
    call :PrintGreen "[+] Проверка Killer пройдена"
)
echo:

:: Intel Connectivity Network Service
sc query | findstr /I "Intel" | findstr /I "Connectivity" | findstr /I "Network" > nul
if !errorlevel!==0 (
    call :PrintRed "[-] Найдена служба Intel Connectivity Network Service. Она конфликтует с NoBan"
) else (
    call :PrintGreen "[+] Проверка Intel Connectivity пройдена"
)
echo:

:: Check Point
set "checkpointFound=0"
sc query | findstr /I "TracSrvWrapper" > nul
if !errorlevel!==0 (
    set "checkpointFound=1"
)

sc query | findstr /I "EPWD" > nul
if !errorlevel!==0 (
    set "checkpointFound=1"
)

if !checkpointFound!==1 (
    call :PrintRed "[-] Найдены службы Check Point. Check Point конфликтует с NoBan"
    call :PrintRed "Попробуйте удалить Check Point"
) else (
    call :PrintGreen "[+] Проверка Check Point пройдена"
)
echo:

:: SmartByte
sc query | findstr /I "SmartByte" > nul
if !errorlevel!==0 (
    call :PrintRed "[-] Найдены службы SmartByte. SmartByte конфликтует с NoBan"
    call :PrintRed "Попробуйте удалить или отключить SmartByte через services.msc"
) else (
    call :PrintGreen "[+] Проверка SmartByte пройдена"
)
echo:

:: VPN
sc query | findstr /I "VPN" > nul
if !errorlevel!==0 (
    call :PrintYellow "[i] Найдены VPN службы. Некоторые VPN могут конфликтовать с NoBan"
    call :PrintYellow "Убедитесь, что все VPN отключены!"
) else (
    call :PrintGreen "[+] Проверка VPN пройдена"
)
echo:

:: DNS
set "dohfound=0"
for /f "delims=" %%a in ('powershell -Command "Get-ChildItem -Recurse -Path 'HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\' | Get-ItemProperty | Where-Object { $_.DohFlags -gt 0 } | Measure-Object | Select-Object -ExpandProperty Count"') do (
    if %%a gtr 0 (
        set "dohfound=1"
    )
)
if !dohfound!==0 (
    call :PrintYellow "[i] Убедитесь, что вы настроили безопасный DNS в браузере с нестандартным DNS провайдером,"
    call :PrintYellow "[i] Если вы используете Windows 11, вы можете настроить зашифрованный DNS в Настройках чтобы скрыть это предупреждение!"
) else (
    call :PrintGreen "[+] Проверка безопасного DNS пройдена"
)
echo:

:: WinDivert conflict
tasklist /FI "IMAGENAME eq NoBan.exe" | find /I "NoBan.exe" > nul
set "winws_running=!errorlevel!"

sc query WinDidvert | findstr /I "RUNNING STOP_PENDING" > nul
set "windivert_running=!errorlevel!"

if !winws_running! neq 0 if !windivert_running!==0 (
    call :PrintYellow "[i] NoBan.exe не запущен, но служба WinDivert активна. Пытаюсь удалить WinDivert..."

    net stop "WinDivert" >nul 2>&1
    sc delete "WinDivert" >nul 2>&1
    if !errorlevel! neq 0 (
        call :PrintRed "[-] Не удалось удалить WinDivert. Проверяю конфликтующие службы..."

        set "conflicting_services=GoodbyeDPI"
        set "found_conflict=0"

        for %%s in (!conflicting_services!) do (
            sc query "%%s" >nul 2>&1
            if !errorlevel!==0 (
                call :PrintYellow "[i] Найдена конфликтующая служба: %%s. Останавливаю и удаляю..."
                net stop "%%s" >nul 2>&1
                sc delete "%%s" >nul 2>&1
                if !errorlevel!==0 (
                    call :PrintGreen "[+] Служба успешно удалена: %%s"
                ) else (
                    call :PrintRed "[-] Не удалось удалить службу: %%s"
                )
                set "found_conflict=1"
            )
        )

        if !found_conflict!==0 (
            call :PrintRed "[-] Конфликтующих служб не найдено. Проверьте вручную, не использует ли другой обход WinDivert."
        ) else (
            call :PrintYellow "[i] Пытаюсь снова удалить WinDivert..."

            sc delete "WinDivert" >nul 2>&1
            sc query "WinDivert" >nul 2>&1
            if !errorlevel! neq 0 (
                call :PrintGreen "[+] WinDivert успешно удален после удаления конфликтующих служб."
            ) else (
                call :PrintRed "[-] WinDivert все еще не может быть удален. Проверьте вручную, не использует ли другой обход WinDivert."
            )
        )
    ) else (
        call :PrintGreen "[+] WinDivert успешно удален"
    )

    echo:
)

:: Conflicting bypasses
set "conflicting_services=GoodbyeDPI discordfix_NoBan NoBan1 NoBan2"

for %%s in (!conflicting_services!) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel!==0 (
        if "!found_conflicts!"=="" (
            set "found_conflicts=%%s"
        ) else (
            set "found_conflicts=!found_conflicts! %%s"
        )
        set "found_any_conflict=1"
    )
)

if !found_any_conflict!==1 (
    call :PrintRed "[-] Найдены конфликтующие службы обхода: !found_conflicts!"

    set "CHOICE="
    set /p "CHOICE=Хотите удалить эти конфликтующие службы? (Y/N) (по умолчанию: N) "
    if "!CHOICE!"=="" set "CHOICE=N"
    if "!CHOICE!"=="y" set "CHOICE=Y"

    if /i "!CHOICE!"=="Y" (
        for %%s in (!found_conflicts!) do (
            call :PrintYellow "[i] Останавливаю и удаляю службу: %%s"
            net stop "%%s" >nul 2>&1
            sc delete "%%s" >nul 2>&1
            if !errorlevel!==0 (
                call :PrintGreen "[+] Служба успешно удалена: %%s"
            ) else (
                call :PrintRed "[-] Не удалось удалить службу: %%s"
            )
        )

        net stop "WinDivert" >nul 2>&1
        sc delete "WinDivert" >nul 2>&1
        net stop "WinDivert14" >nul 2>&1
        sc delete "WinDivert14" >nul 2>&1
    )

    echo:
)

:: Discord cache clearing
set "CHOICE="
set /p "CHOICE=Хотите очистить кэш Discord? (да/нет): "
if "!CHOICE!"=="да" set "CHOICE=Y"

if /i "!CHOICE!"=="Y" (
    tasklist /FI "IMAGENAME eq Discord.exe" | findstr /I "Discord.exe" > nul
    if !errorlevel!==0 (
        echo Discord запущен, закрываю...
        taskkill /IM Discord.exe /F > nul
        if !errorlevel! == 0 (
            call :PrintGreen "[+] Discord успешно закрыт"
        ) else (
            call :PrintRed "[-] Не удалось закрыть Discord"
        )
    )

    set "discordCacheDir=%appdata%\discord"

    for %%d in ("Cache" "Code Cache" "GPUCache") do (
        set "dirPath=!discordCacheDir!\%%~d"
        if exist "!dirPath!" (
            rd /s /q "!dirPath!"
            if !errorlevel!==0 (
                call :PrintGreen "[+] Успешно удалено !dirPath!"
            ) else (
                call :PrintRed "[-] Не удалось удалить !dirPath!"
            )
        ) else (
            call :PrintRed "[-] !dirPath! не существует"
        )
    )
)
echo:

pause
goto menu


:: GAME SWITCH ========================
:game_switch_status
chcp 65001 > nul

set "gameFlagFile=%~dp0bin\game_filter.enabled"

if exist "%gameFlagFile%" (
    set "GameFilterStatus=enabled"
    set "GameFilter=1024-65535"
) else (
    set "GameFilterStatus=disabled"
    set "GameFilter=12"
)
exit /b


:game_switch
chcp 65001 > nul
cls

if not exist "%gameFlagFile%" (
    echo Включение игрового фильтра...
    echo ENABLED > "%gameFlagFile%"
    call :PrintYellow "Перезапустите NoBan, чтобы изменения вступили в силу."
) else (
    echo Отключение игрового фильтра...
    del /f /q "%gameFlagFile%"
    call :PrintYellow "Перезапустите NoBan, чтобы изменения вступили в силу."
)

pause
goto menu

:: ═════╣ Переключение ipset ╠═════
:ipset_switch_status
chcp 437 > nul

set "listFile=%~dp0lists\ipset-all.txt"
for /f %%i in ('type "%listFile%" 2^>nul ^| find /c /v ""') do set "lineCount=%%i"

if !lineCount!==0 (
    set "IPsetStatus=any"
) else (
    findstr /R "^203\.0\.113\.113/32$" "%listFile%" >nul
    if !errorlevel!==0 (
        set "IPsetStatus=none"
    ) else (
        set "IPsetStatus=loaded"
    )
)
exit /b


:ipset_switch
chcp 437 > nul
cls

set "listFile=%~dp0lists\ipset-all.txt"
set "backupFile=%listFile%.backup"

if "%IPsetStatus%"=="loaded" (
    echo Переключение в режим "none"...

    if not exist "%backupFile%" (
        ren "%listFile%" "ipset-all.txt.backup"
    ) else (
        del /f /q "%backupFile%"
        ren "%listFile%" "ipset-all.txt.backup"
    )

    >"%listFile%" (
        echo 203.0.113.113/32
    )

) else if "%IPsetStatus%"=="none" (
    echo Переключение в режим "any"...

    >"%listFile%" (
        rem Creating empty file
    )

) else if "%IPsetStatus%"=="any" (
    echo Переключение в режим "loaded"...

    if exist "%backupFile%" (
        del /f /q "%listFile%"
        ren "%backupFile%" "ipset-all.txt"
    ) else (
        echo Ошибка: Нет резервной копии для восстановления. Сначала обновите список через меню служб.
        pause
        goto menu
    )
    
)

pause
goto menu


:: IPSET UPDATE =======================
:ipset_update
chcp 437 > nul
cls

set "listFile=%~dp0lists\ipset-all.txt"
set "url=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/ipset-service.txt"

echo Updating ipset-all...

if exist "%SystemRoot%\System32\curl.exe" (
    curl -L -o "%listFile%" "%url%"
) else (
    powershell -NoProfile -Command ^
        "$url = '%url%';" ^
        "$out = '%listFile%';" ^
        "$dir = Split-Path -Parent $out;" ^
        "if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null };" ^
        "$res = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing;" ^
        "if ($res.StatusCode -eq 200) { $res.Content | Out-File -FilePath $out -Encoding UTF8 } else { exit 1 }"
)

echo Finished

pause
goto menu

:: ═════╣ Цвета ╠═════

:PrintGreen
powershell -Command "Write-Host \"%~1\" -ForegroundColor Green"
exit /b

:PrintRed
powershell -Command "Write-Host \"%~1\" -ForegroundColor Red"
exit /b

:PrintYellow
powershell -Command "Write-Host \"%~1\" -ForegroundColor Yellow"
exit /b