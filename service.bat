@echo off
:: ═════╣ Устанавливаем шрифт ╠═════
reg add "HKCU\Console" /v "FaceName" /t REG_SZ /d "Lucida Console" /f > nul
reg add "HKCU\Console" /v "FontFamily" /t REG_DWORD /d 54 /f > nul

:: ═════╣ Устанавливаем UTF-8 ╠═════
chcp 65001 > nul
title NoBan service v6.1
set "LOCAL_VERSION=6.1"

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
echo  ╠═════════ NoBan v!LOCAL_VERSION! ═════════╣
echo.
echo   [1] Проверить статус
echo   [2] Выполнить диагностику
echo   [3] Проверить обновления
echo   [4] Переключить игровой фильтр [%GameFilterStatus%]
echo   [5] Переключить ipset [%IPsetStatus%]
echo   [6] Установить автозагрузку
echo   [7] Убрать автозагрузку / Остановить NoBan
echo   [8] Проверка работоспособности доменов
echo   [9] Проверка доменов (Простая)    :: Test
echo   [10] Профессиональная разблокировка
echo   [0] Выход
echo.
echo  ╠═════════ NoBan v!LOCAL_VERSION! ═════════╣
echo.
set /p menu_choice=Введите выбор [0-10]:

if "%menu_choice%"=="1" goto service_status
if "%menu_choice%"=="2" goto service_diagnostics
if "%menu_choice%"=="3" goto service_check_updates
if "%menu_choice%"=="4" goto game_switch
if "%menu_choice%"=="5" goto ipset_switch
if "%menu_choice%"=="6" goto service_install
if "%menu_choice%"=="7" goto service_remove
if "%menu_choice%"=="8" goto service_check_domains
if "%menu_choice%"=="9" goto service_autofind
if "%menu_choice%"=="10" goto professional_unlock
if "%menu_choice%"=="0" exit /b
goto menu

:: ═════╣ Автоопределение стратегии (проверка всех профилей из checks\bat) ╠═════
:service_autofind
cls

set "PROFILES_DIR=%~dp0checks\bat"
if not exist "%PROFILES_DIR%" (
    call :PrintRed " [-] Папка 'checks\bat' не найдена."
    pause
    goto menu
)

:: Собираем список всех .bat файлов
set "profile_count=0"
for %%f in ("%PROFILES_DIR%\*.bat") do (
    set /a profile_count+=1
    set "profile_name_!profile_count!=%%~nxf"
    set "profile_path_!profile_count!=%%f"
)

if %profile_count%==0 (
    call :PrintRed " [-] В папке 'checks\bat' нет bat-файлов."
    pause
    goto menu
)

:: Останавливаем текущий обход, если он запущен
tasklist /FI "IMAGENAME eq NoBan.exe" 2>nul | find /I "NoBan.exe" >nul
if not errorlevel 1 (
    call :PrintYellow " [i] Останавливаю текущий обход..."
    taskkill /IM NoBan.exe /F >nul 2>&1
    timeout /t 2 /nobreak >nul
)

color 0F
echo.
echo  Профиль        Discord  YouTube  Google
echo.
echo ═════════════════════════════════════════════
echo.

:: Создаём временный файл для результатов
set "result_file=%temp%\noban_autofind.txt"
> "%result_file%" echo.

:: Перебираем все профили
for /l %%i in (1,1,%profile_count%) do (
    set "profile=!profile_name_%%i!"
    set "profile_path=!profile_path_%%i!"

    :: Запускаем профиль (рабочая папка — корень NoBan)
    pushd "%~dp0"
    start "NoBan Test" /min cmd /c "!profile_path!"
    popd
    timeout /t 5 /nobreak >nul

    :: Проверяем Discord
    set "discord_ok=0"
    curl -s -L -m 5 -o "%temp%\noban_discord.html" "https://discord.com" >nul 2>&1
    if not errorlevel 1 (
        findstr /i "discord" "%temp%\noban_discord.html" >nul
        if not errorlevel 1 set "discord_ok=1"
    )
    del "%temp%\noban_discord.html" 2>nul

    :: Проверяем YouTube
    set "youtube_ok=0"
    curl -s -L -m 5 -o "%temp%\noban_youtube.html" "https://youtube.com" >nul 2>&1
    if not errorlevel 1 (
        findstr /i "YouTube" "%temp%\noban_youtube.html" >nul
        if not errorlevel 1 set "youtube_ok=1"
    )
    del "%temp%\noban_youtube.html" 2>nul

    :: Проверяем Google
    set "google_ok=0"
    curl -s -L -m 5 -o "%temp%\noban_google.html" "https://google.com" >nul 2>&1
    if not errorlevel 1 (
        findstr /i "Google" "%temp%\noban_google.html" >nul
        if not errorlevel 1 set "google_ok=1"
    )
    del "%temp%\noban_google.html" 2>nul

    :: Останавливаем тестовый процесс
    taskkill /IM NoBan.exe /F >nul 2>&1

    :: Выводим строку результата
    set "discord_str= - "
    if !discord_ok!==1 set "discord_str= + "
    set "youtube_str= - "
    if !youtube_ok!==1 set "youtube_str= + "
    set "google_str= - "
    if !google_ok!==1 set "google_str= + "

    echo  !profile!    !discord_str!      !youtube_str!     !google_str!
    echo  !profile!;!discord_ok!;!youtube_ok!;!google_ok! >> "%result_file%"
)

echo.
echo.
echo  [+] - сервис доступен
echo.
echo  [-] - сервис недоступен
echo.
echo ═════════════════════════════════════════════
echo.

del "%result_file%" 2>nul
pause
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
    call :PrintGreen " "
	call :PrintGreen " [+] Обход NoBan активен"
	call :PrintGreen " "
) else (
    call :PrintRed " "
    call :PrintRed " [-] Обход NoBan не активен"
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
    echo  [-] Папка "autoload" не найдена!
    echo.
    pause
    goto menu
    )
)

:: Если в папке autoload нет .bat файлов
if !count!==0 (
    echo.
    echo  [-] В папке "autoload" не найдено ни одного .bat-файла!
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
set /p "choice=Введите выбор [1-8]: "
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

:: ═════╣ Текущая версия и URL-адреса ╠═════
set "GITHUB_VERSION_URL=https://raw.githubusercontent.com/wcrasss/NoBan/main/service/version.txt"
set "GITHUB_RELEASE_URL=https://github.com/wcrasss/NoBan/tags/"
set "GITHUB_DOWNLOAD_URL=https://github.com/wcrasss/NoBan/releases/latest"

:: ═════╣ Получение последней версии с GitHub ╠═════
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Invoke-WebRequest -Uri \"%GITHUB_VERSION_URL%\" -Headers @{\"Cache-Control\"=\"no-cache\"} -UseBasicParsing -TimeoutSec 5).Content.Trim()" 2^>nul') do set "GITHUB_VERSION=%%A"

:: ═════╣ Ошибка ╠═════
if not defined GITHUB_VERSION (
    color 0F
    echo.
    echo ╠══════════════════ NoBan - Ошибка ══════════════════╣
    echo.
    echo  Не удалось загрузить последнюю версию.
    echo  Это предупреждение не влияет на работу NoBan.
    echo.
    echo ╠══════════════════ NoBan - Ошибка ══════════════════╣
    echo.
    timeout /T 9
    if "%1"=="soft" exit
    goto menu
)

:: ═════╣ Сравнение версий ╠═════
if "%LOCAL_VERSION%"=="%GITHUB_VERSION%" (
    color 0F
    echo.
    echo ╠══════════════════ NoBan ══════════════════╣
    echo.
    echo   У вас установлена последняя версия: v%LOCAL_VERSION%
    echo.
    echo ╠══════════════════ NoBan ══════════════════╣
    echo.

    if "%1"=="soft" exit
    pause
    goto menu
)

color 0F
echo.
echo ╠══════════════════ NoBan !LOCAL_VERSION! ══════════════════╣
echo.
echo  Доступна новая версия - v%GITHUB_VERSION%
echo  Страница релиза - %GITHUB_RELEASE_URL%%GITHUB_VERSION%
echo.
echo  Мы рекомендуем скачать последнюю версию.
echo.
echo ╠══════════════════ NoBan %GITHUB_VERSION% ══════════════════╣
echo.
echo [i] Открытие страницы...
start "" "%GITHUB_DOWNLOAD_URL%"


if "%1"=="soft" exit
pause
goto menu

:: ═════╣ Диагностика ╠═════
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
    )
)
                call :PrintRed "[-] Не удалось удалить !dirPath!"
            )
        ) else (
            call :PrintRed "[-] !dirPath! не существует"
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
    call :PrintYellow " [i] Перезапустите NoBan, чтобы изменения вступили в силу."
) else (
    echo Отключение игрового фильтра...
    del /f /q "%gameFlagFile%"
    call :PrintYellow " [i] Перезапустите NoBan, чтобы изменения вступили в силу."
)

pause
goto menu

:: ═════╣ Переключение ipset ╠═════
:ipset_switch_status
chcp 65001 > nul

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
set "url=https://raw.githubusercontent.com/wcrasss/NoBan/main/service/ipset-service.txt"

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

:: ═════╣ Проверка доменов через профиль или без профиля ╠═════
:service_check_domains
cls
setlocal enabledelayedexpansion

set "PROFILES_DIR=%~dp0checks\bat"

:: Собираем список профилей
set "profile_count=0"
if exist "%PROFILES_DIR%" (
    for %%f in ("%PROFILES_DIR%\*.bat") do (
        set /a profile_count+=1
        set "profile_name_!profile_count!=%%~nxf"
        set "profile_path_!profile_count!=%%f"
    )
)

echo.
echo  ╠══════ Доступные профиля ══════╣
echo.
if %profile_count%==0 (
    echo   (нет профилей в папке checks\bat)
) else (
    for /l %%i in (1,1,%profile_count%) do (
        echo   [%%i] !profile_name_%%i!
    )
)
echo   [0] Без профиля (проверка без обхода)
echo.
echo  ╠════════════ NoBan ════════════╣
echo.
set /p "profile_choice=[?] Выберите профиль [0-%profile_count%]: "
if "%profile_choice%"=="0" goto check_without_profile
if %profile_choice% gtr %profile_count% goto service_check_domains
if %profile_choice% lss 0 goto service_check_domains

set "selected_profile=!profile_name_%profile_choice%!"
set "profile_path=!profile_path_%profile_choice%!"
echo.
echo  [i] Выбран профиль: %selected_profile%
echo.

:: Останавливаем текущий обход
tasklist /FI "IMAGENAME eq NoBan.exe" 2>nul | find /I "NoBan.exe" >nul
if not errorlevel 1 (
    call :PrintYellow " "
    call :PrintYellow " [i] Останавливаю текущий обход..."
    call :PrintYellow " "
    taskkill /IM NoBan.exe /F >nul 2>&1
    timeout /t 2 /nobreak >nul
)

:: Запускаем выбранный профиль
echo Запуск профиля %selected_profile%...
pushd "%~dp0"
start "NoBan Test" /min cmd /c "!profile_path!"
popd
timeout /t 5 /nobreak >nul
set "PROFILE_ACTIVE=1"
goto select_domain_file

:check_without_profile
set "PROFILE_ACTIVE=0"
echo.
call :PrintYellow " "
call :PrintYellow " [i] Проверка без обхода (чистая доступность сайтов)"
call :PrintYellow " "
goto select_domain_file

:select_domain_file
:: Выбор файла с доменами
set "CHECKS_DIR=%~dp0checks"
if not exist "%CHECKS_DIR%" (
    call :PrintRed " [-] Папка 'checks' не найдена."
    if %PROFILE_ACTIVE%==1 taskkill /IM NoBan.exe /F >nul 2>&1
    pause
    goto menu
)

set "file_count=0"
for %%f in ("%CHECKS_DIR%\*.txt") do (
    set /a file_count+=1
    set "file_name_!file_count!=%%~nxf"
    set "file_path_!file_count!=%%f"
)

if %file_count%==0 (
    call :PrintRed " [-] В папке 'checks' нет файлов со списками доменов."
    if %PROFILE_ACTIVE%==1 taskkill /IM NoBan.exe /F >nul 2>&1
    pause
    goto menu
)

echo.
echo  ╠═══════ Доступные файлы ═══════╣
echo.
for /l %%i in (1,1,%file_count%) do (
    echo     [%%i] !file_name_%%i!
)
echo     [0] Выход
echo.
echo  ╠════════════ NoBan ════════════╣
echo.
set /p "file_choice=[?] Выберите файл [0-%file_count%]: "
if "%file_choice%"=="0" (
    if %PROFILE_ACTIVE%==1 taskkill /IM NoBan.exe /F >nul 2>&1
    goto menu
)
if %file_choice% gtr %file_count% goto select_domain_file

set "selected_file=!file_path_%file_choice%!"
set "selected_name=!file_name_%file_choice%!"
echo.
echo  [i] Выбран файл доменов: %selected_name%
echo.

:: Проверка доменов
echo.
echo  [i] Проверка доменов...
echo.

set "SUCCESS=0"
set "FAILED=0"
set "result_file=%temp%\noban_domains_%random%.txt"
echo Домен;Статус > "%result_file%"

for /f "usebackq delims=" %%d in ("%selected_file%") do (
    set "domain=%%d"
    for /f "tokens=*" %%a in ("!domain!") do set "domain=%%a"
    if defined domain if not "!domain:~0,1!"=="#" (
        set "status=НЕДОСТУПЕН"
        curl -s -L -m 10 -o "%temp%\noban_domain_check.html" "https://!domain!" >nul 2>&1
        if not errorlevel 1 (
            findstr /i "." "%temp%\noban_domain_check.html" >nul
            if not errorlevel 1 set "status=ДОСТУПЕН"
        )
        del "%temp%\noban_domain_check.html" 2>nul
        echo !domain! - !status!
        echo !domain!;!status! >> "%result_file%"
        if "!status!"=="ДОСТУПЕН" (set /a SUCCESS+=1) else (set /a FAILED+=1)
    )
)

:: Останавливаем профиль, если он был запущен
if %PROFILE_ACTIVE%==1 (
    taskkill /IM NoBan.exe /F >nul 2>&1
    call :PrintGreen " [+] Профиль остановлен."
)

echo.
echo  ╠═════════════ Результат ═════════════╣
echo.
echo   Доступно: %SUCCESS%  Недоступно: %FAILED%
echo.
echo  ╠═════════════ Результат ═════════════╣
echo.
pause
goto menu

:: ═════╣ Профессиональная разблокировка (подменю) ╠═════
:professional_unlock
cls
echo.
echo  ╠════════════ Выберите ════════════╣
echo.
echo   [1] Spotify
echo   [2] IntelliJ IDEA (JetBrains)
echo   [3] Telegram Web
echo   [0] Назад
echo.
echo  ╠════════════ Выберите ════════════╣
echo.
set /p "unlock_choice=Введите выбор [0-3]: "
if "%unlock_choice%"=="1" goto spotify_unlock_manual
if "%unlock_choice%"=="2" goto intellij_unlock_manual
if "%unlock_choice%"=="3" goto telegram_unlock_manual
if "%unlock_choice%"=="0" goto menu

:: ═════╣ Spotify — ручная разблокировка через hosts ╠═════
:spotify_unlock_manual
cls

:: 1. Создаём/открываем файл с правилами
set "SPOTIFY_HOSTS_RULES=%~dp0checks\rest\spotify-hosts.txt"
if not exist "%SPOTIFY_HOSTS_RULES%" (
    call :PrintYellow " [i] Файл с правилами не найден. Создаю стандартный..."
    (
        echo # Spotify bypass IPs
        echo 45.155.204.190 accounts.spotify.com
        echo 45.155.204.190 aet.spotify.com
        echo 45.155.204.190 api-partner.spotify.com
        echo 45.155.204.190 api.spotify.com
        echo 45.155.204.190 gew1-dealer.spotify.com
        echo 45.155.204.190 gew1-spclient.spotify.com
        echo 45.155.204.190 login5.spotify.com
        echo 45.155.204.190 open.spotify.com
        echo 45.155.204.190 spclient.wg.spotify.com
        echo 45.155.204.190 www.spotify.com
        echo 95.182.120.241 accounts.spotify.com
        echo 95.182.120.241 aet.spotify.com
        echo 95.182.120.241 api-partner.spotify.com
        echo 95.182.120.241 api.spotify.com
        echo 95.182.120.241 gew1-dealer.spotify.com
        echo 95.182.120.241 gew1-spclient.spotify.com
        echo 95.182.120.241 login5.spotify.com
        echo 95.182.120.241 open.spotify.com
        echo 95.182.120.241 spclient.wg.spotify.com
        echo 95.182.120.241 www.spotify.com
        echo # Spotify CDN
        echo 45.155.204.190 open-exp.spotifycdn.com
        echo 95.182.120.241 audio-fa-tls13.spotifycdn.com
        echo 95.182.120.241 concerts.spotifycdn.com
        echo 95.182.120.241 heads-fa-tls13.spotifycdn.com
        echo 95.182.120.241 image-cdn-fa.spotifycdn.com
        echo 95.182.120.241 mrkt.spotifycdn.com
        echo 95.182.120.241 open-exp.spotifycdn.com
        echo 95.182.120.241 pickasso.spotifycdn.com
        echo 95.182.120.241 podz-content.spotifycdn.com
        echo 95.182.120.241 seed-mix-image.spotifycdn.com
        echo 95.182.120.241 spotifycdn.com
        echo 95.182.120.241 spotifycdn.net
        echo 95.182.120.241 thisis-images.spotifycdn.com
        echo 95.182.120.241 wap.spotifycdn.com
        echo 95.182.120.241 web-sdk-assets.spotifycdn.com
    ) > "%SPOTIFY_HOSTS_RULES%"
    call :PrintGreen " [+] Файл создан: %SPOTIFY_HOSTS_RULES%"
)

:: 2. Открываем файл с правилами в блокноте
call :PrintYellow " [i] Открываю файл для копирования..."
start notepad.exe "%SPOTIFY_HOSTS_RULES%"
timeout /t 2 >nul

:: 3. Открываем папку etc
call :PrintYellow " [i] Открываю папку %SystemRoot%\System32\drivers\etc"
start explorer "%SystemRoot%\System32\drivers\etc"

:: 4. Инструкция
echo.
echo  ╠════════════════════ Инструкция ════════════════════╣
echo.
echo    1. Скопируйте содержимое открытого блокнота
echo    2. В папке etc найдите файл 'hosts'
echo    3. Откройте его через блокнот
echo    4. Вставьте скопированные строки в файл hosts
echo    5. Сохраните файл (Ctrl+S). Подтвердите
echo    6. Закройте блокнот и проводник
echo    7. Рекомендуем 'Выполнить сброс DNS'
echo.
echo  ╠════════════════════ Инструкция ════════════════════╣
echo.
set /p "flush=Выполнить сброс DNS сейчас? (Да/Нет): "
if /i "%flush%"=="да" (
    ipconfig /flushdns >nul
    call :PrintGreen " "
    call :PrintYellow " [i] Удаляем..."
    call :PrintYellow " [i] Кушаем печеньки..."
    call :PrintYellow " [i] Ещё чуть чуть..."
    call :PrintGreen " [+] DNS-кэш сброшен "
    call :PrintGreen " "
) else (
    call :PrintRed " "
    call :PrintRed " [-] Сброс DNS отменён "
    call :PrintRed " "
)
pause
goto menu

:: ═════╣ IntelliJ IDEA — ручная разблокировка через hosts ╠═════
:intellij_unlock_manual
cls

set "RULES_FILE=%~dp0checks\rest\intellij-hosts.txt"
set "HOSTS_DIR=%SystemRoot%\System32\drivers\etc"

:: Проверяем, существует ли папка rest
if not exist "%~dp0checks\rest" (
    call :PrintYellow " [i] Папка checks\rest не найдена. Создаю..."
    mkdir "%~dp0checks\rest"
)

:: Создаём файл с правилами, если его нет
if not exist "%RULES_FILE%" (
    call :PrintYellow " [i] Файл intellij-hosts.txt не найден. Создаю..."
    (
        echo # IntelliJ IDEA / JetBrains bypass IPs
        echo 45.155.204.190 datalore.jetbrains.com
        echo 45.155.204.190 plugins.jetbrains.com
        echo 45.155.204.190 download.jetbrains.com
        echo 45.155.204.190 api.jetbrains.ai
        echo 45.155.204.190 account.jetbrains.com
    ) > "%RULES_FILE%"
    call :PrintGreen " [+] Файл создан: %RULES_FILE%"
)

:: Открываем файл с правилами в блокноте
call :PrintYellow " [i] Открываю файл для копирования..."
start notepad.exe "%RULES_FILE%"
timeout /t 2 >nul

:: Открываем папку etc
call :PrintYellow " [i] Открываю папку %HOSTS_DIR%"
start explorer "%HOSTS_DIR%"

:: Инструкция
echo.
echo  ╠════════════════════ Инструкция ════════════════════╣
echo.
echo    1. Скопируйте содержимое открытого блокнота
echo    2. В папке etc найдите файл 'hosts'
echo    3. Откройте его через блокнот
echo    4. Вставьте скопированные строки в файл hosts
echo    5. Сохраните файл (Ctrl+S). Подтвердите
echo    6. Закройте блокнот и проводник
echo    7. Рекомендуем 'Выполнить сброс DNS'
echo.
echo  ╠════════════════════ Инструкция ════════════════════╣
echo.
set /p "flush=Выполнить сброс DNS сейчас? (Да/Нет): "
if /i "%flush%"=="да" (
    ipconfig /flushdns >nul
    call :PrintGreen " "
    call :PrintYellow " [i] Удаляем..."
    call :PrintYellow " [i] Кушаем печеньки..."
    call :PrintYellow " [i] Ещё чуть чуть..."
    call :PrintGreen " [+] DNS-кэш сброшен "
    call :PrintGreen " "
) else (
    call :PrintRed " "
    call :PrintRed " [-] Сброс DNS отменён "
    call :PrintRed " "
)
pause
goto menu

:: ═════╣ Telegram Web — ручная разблокировка через hosts ╠═════
:telegram_unlock_manual
cls

set "RULES_FILE=%~dp0checks\rest\telegram-hosts.txt"
set "HOSTS_DIR=%SystemRoot%\System32\drivers\etc"

if not exist "%~dp0checks\rest" mkdir "%~dp0checks\rest"

if not exist "%RULES_FILE%" (
    call :PrintYellow " [i] Файл telegram-hosts.txt не найден. Создаю..."
    (
        echo # Telegram Web bypass IPs
        echo 149.154.167.220 zws4.web.telegram.org
        echo 149.154.167.220 vesta.web.telegram.org
        echo 149.154.167.220 vesta-1.web.telegram.org
        echo 149.154.167.220 venus-1.web.telegram.org
        echo 149.154.167.220 telegram.me
        echo 149.154.167.220 telegram.dog
        echo 149.154.167.220 telegram.space
        echo 149.154.167.220 telesco.pe
        echo 149.154.167.220 tg.dev
        echo 149.154.167.220 telegram.org
        echo 149.154.167.220 t.me
        echo 149.154.167.220 api.telegram.org
        echo 149.154.167.220 td.telegram.org
        echo 149.154.167.220 venus.web.telegram.org
        echo 149.154.167.220 web.telegram.org
        echo 149.154.167.220 kws2-1.web.telegram.org
        echo 149.154.167.220 kws2.web.telegram.org
        echo 149.154.167.220 kws4-1.web.telegram.org
        echo 149.154.167.220 kws4.web.telegram.org
        echo 149.154.167.220 zws2-1.web.telegram.org
        echo 149.154.167.220 zws2.web.telegram.org
        echo 149.154.167.220 zws4-1.web.telegram.org
    ) > "%RULES_FILE%"
    call :PrintGreen " [+] Файл создан: %RULES_FILE%"
)

:: Открываем файл с правилами в блокноте
call :PrintYellow " [i] Открываю файл для копирования..."
start notepad.exe "%RULES_FILE%"
timeout /t 2 >nul

:: Открываем папку etc
call :PrintYellow " [i] Открываю папку %HOSTS_DIR%"
start explorer "%HOSTS_DIR%"

:: Инструкция
echo.
echo  ╠════════════════════ Инструкция ════════════════════╣
echo.
echo    1. Скопируйте содержимое открытого блокнота
echo    2. В папке etc найдите файл 'hosts'
echo    3. Откройте его через блокнот
echo    4. Вставьте скопированные строки в файл hosts
echo    5. Сохраните файл (Ctrl+S). Подтвердите
echo    6. Закройте блокнот и проводник
echo    7. Рекомендуем 'Выполнить сброс DNS'
echo.
echo  ╠════════════════════ Инструкция ════════════════════╣
echo.
set /p "flush=Выполнить сброс DNS сейчас? (Да/Нет): "
if /i "%flush%"=="да" (
    ipconfig /flushdns >nul
    call :PrintGreen " "
    call :PrintYellow " [i] Удаляем..."
    call :PrintYellow " [i] Кушаем печеньки..."
    call :PrintYellow " [i] Ещё чуть чуть..."
    call :PrintGreen " [+] DNS-кэш сброшен "
    call :PrintGreen " "
) else (
    call :PrintRed " "
    call :PrintRed " [-] Сброс DNS отменён "
    call :PrintRed " "
)
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
