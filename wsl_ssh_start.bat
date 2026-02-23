@echo off
REM === WSL SSH 자동 시작 + 포트 포워딩 스크립트 ===
REM Startup 폴더에서 실행 시 관리자 권한이 필요합니다.

REM --- 관리자 권한 확인 및 자동 상승 ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

REM --- 1. WSL SSH 서비스 시작 (root로 실행하여 sudo 불필요) ---
echo [1/4] SSH 서비스 시작 중...
"C:\Windows\System32\wsl.exe" -u root -- service ssh start

REM --- 2. WSL IP 주소 가져오기 ---
echo [2/4] WSL IP 확인 중...
for /f "tokens=1" %%i in ('"C:\Windows\System32\wsl.exe" -e hostname -I') do set WSL_IP=%%i
echo       WSL IP: %WSL_IP%

REM --- 3. 기존 포트 포워딩 전부 삭제 후 현재 IP로 재설정 ---
echo [3/4] 포트 포워딩 설정 중...
"C:\Windows\System32\netsh.exe" interface portproxy reset >nul 2>&1

"C:\Windows\System32\netsh.exe" interface portproxy add v4tov4 listenport=22 listenaddress=0.0.0.0 connectport=22 connectaddress=%WSL_IP%
"C:\Windows\System32\netsh.exe" interface portproxy add v4tov4 listenport=80 listenaddress=0.0.0.0 connectport=80 connectaddress=%WSL_IP%
"C:\Windows\System32\netsh.exe" interface portproxy add v4tov4 listenport=443 listenaddress=0.0.0.0 connectport=443 connectaddress=%WSL_IP%
"C:\Windows\System32\netsh.exe" interface portproxy add v4tov4 listenport=222 listenaddress=0.0.0.0 connectport=222 connectaddress=%WSL_IP%
"C:\Windows\System32\netsh.exe" interface portproxy add v4tov4 listenport=3000 listenaddress=0.0.0.0 connectport=3000 connectaddress=%WSL_IP%
"C:\Windows\System32\netsh.exe" interface portproxy add v4tov4 listenport=5000 listenaddress=0.0.0.0 connectport=5000 connectaddress=%WSL_IP%
"C:\Windows\System32\netsh.exe" interface portproxy add v4tov4 listenport=10000 listenaddress=0.0.0.0 connectport=10000 connectaddress=%WSL_IP%

echo       포트 포워딩 목록:
"C:\Windows\System32\netsh.exe" interface portproxy show v4tov4

REM --- 4. 방화벽 규칙 추가 (이미 있으면 건너뜀) ---
echo [4/4] 방화벽 규칙 확인 중...
"C:\Windows\System32\netsh.exe" advfirewall firewall show rule name="WSL SSH" >nul 2>&1
if %errorlevel% neq 0 (
    "C:\Windows\System32\netsh.exe" advfirewall firewall add rule name="WSL SSH" dir=in action=allow protocol=TCP localport=22,80,222,443,3000,5000,10000
    echo       방화벽 규칙 추가 완료
) else (
    echo       방화벽 규칙 이미 존재
)

echo.
echo === 설정 완료 ===
echo 외부에서 SSH 접속: ssh [사용자명]@[외부IP] -p 22
echo.
pause
