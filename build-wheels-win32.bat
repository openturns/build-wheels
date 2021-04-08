echo on
set pkgname=%1
set pkgver=%2
set PYBASEVER=%3
set TAG=%4
appveyor DownloadFile https://github.com/openturns/build-modules/releases/download/v1.16rc1/%pkgname%-%pkgver%-py%PYBASEVER%-x86_64.exe
rmdir /s /q %cd%\install
%pkgname%-%pkgver%-py%PYBASEVER%-x86_64.exe /userlevel=1 /S /FORCE /D=%cd%\install
move %cd%\install\Lib\site-packages\%pkgname% %cd%
move %cd%\install\Lib\site-packages\%pkgname%-%pkgver%.dist-info %cd%
dir /p %cd%\%pkgname%
python write_RECORD.py %pkgname% %pkgver%
dir /p %cd%\%pkgname%-%pkgver%.dist-info
7z a -tzip %pkgname%-%pkgver%-%TAG%.whl %pkgname% %pkgname%-%pkgver%.dist-info
