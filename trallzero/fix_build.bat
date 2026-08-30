@echo off
chcp 65001 >nul
title Fix Flutter Build - Trall Zero

echo.
echo +------------------------------------------+
echo ^|       Fix Flutter Build - Trall Zero     ^|
echo +------------------------------------------+
echo.

REM -- 1. Parar daemons e processos pendentes do Java/Gradle
echo [1/6] Finalizando processos Java e daemons do Gradle...
taskkill /f /im java.exe 2>nul
call android\gradlew.bat --stop 2>nul
if %errorlevel% neq 0 (
    echo     [AVISO] Nenhum daemon rodando ou gradlew nao encontrado.
) else (
    echo     [OK] Daemons parados.
)
echo.

REM -- 2. Limpar caches locais do projeto (.gradle)
echo [2/6] Removendo pastas de cache local (.gradle)...
rmdir /s /q .gradle 2>nul
rmdir /s /q android\.gradle 2>nul
echo     [OK] Caches locais removidos.
echo.

REM -- 3. Remove arquivos de lock do cache global do Gradle
echo [3/6] Removendo locks do cache global do Gradle...
del /q /f "%USERPROFILE%\.gradle\caches\*.lock" 2>nul
del /q /f "%USERPROFILE%\.gradle\caches\modules-*\*.lock" 2>nul
echo     [OK] Locks globais removidos.
echo.

REM -- 4. Flutter clean
echo [4/6] Executando flutter clean...
call flutter clean
if %errorlevel% neq 0 (
    echo     [ERRO] Flutter clean falhou!
    pause
    exit /b 1
)
echo     [OK] Projeto limpo.
echo.

REM -- 5. Flutter pub get
echo [5/6] Restaurando dependencias (flutter pub get)...
call flutter pub get
if %errorlevel% neq 0 (
    echo     [ERRO] flutter pub get falhou!
    pause
    exit /b 1
)
echo     [OK] Dependencias restauradas.
echo.

REM -- 6. Build APK debug
echo [6/6] Buildando APK (debug)...
call flutter build apk --debug
if %errorlevel% neq 0 (
    echo.
    echo     [ERRO] Build falhou! Tente:
    echo       - Fechar o Android Studio
    echo       - Desativar o antivirus temporariamente
    echo       - Rodar este script como Administrador
    pause
    exit /b 1
)

echo.
echo +------------------------------------------+
echo ^|         BUILD CONCLUIDO COM SUCESSO!     ^|
echo +------------------------------------------+
echo.
echo APK gerado em: build\app\outputs\flutter-apk\app-debug.apk
echo.
pause
