@echo mike-coding password: ' ' 
@echo mysql password: ''

@echo off

wsl sudo service apache2 start
wsl sudo service mysql start

REM Give services some time to boot up
timeout /t 2

wsl ./dbRefresh.sh

start http://localhost

echo.
echo Press any key to end demo...
pause >nul

REM Stop Apache and MySQL
wsl sudo service apache2 stop
wsl sudo service mysql stop

echo.
echo Demo ended. Press any key to exit.
pause >nul