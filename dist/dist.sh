#!/bin/sh

# Build .love
cd ..
zip -qr9 dist/LoveHotel.love *.lua data
cd dist

# Build windows
rm -rf win
mkdir win
if [ ! -e love-0.8.0-win-x86-damn-you-ATI.zip ]
then
  wget -q "https://bitbucket.org/Boolsheet/love_winbin/downloads/love-0.8.0-win-x86-damn-you-ATI.zip"
fi
unzip -qqn -d win love-0.8.0-win-x86-damn-you-ATI.zip DevIL.dll libraries.txt licenses.txt love.exe lua51.dll mpg123.dll OpenAL.dll SDL.dll

cd win
cat love.exe ../LoveHotel.love > LoveHotel.exe
rm love.exe
cp ../../CHANGELOG CHANGELOG.txt
cp ../../COPYING COPYING.txt
cp ../../README.md README.txt
todos CHANGELOG.txt COPYING.txt README.txt
zip -FS -qr9 ../lovehotel-win.zip *
cd ..

# Build mac
rm -rf mac
mkdir -p mac
if [ ! -e love-0.8.0-macosx-ub.zip ]
then
  wget -q "https://bitbucket.org/rude/love/downloads/love-0.8.0-macosx-ub.zip"
fi
unzip -qqn -d mac love-0.8.0-macosx-ub.zip

cd mac
mv love.app LoveHotel.app
cp ../LoveHotel.love LoveHotel.app/Contents/Resources/
sed -i -e "s/>org\.love2d\.love</>com\.3sillyhats\.lovehotel</" -e "s/>LÖVE</>Love Hotel</" -e '/^\t<key>UTExportedTypeDeclarations<\/key>$/,/^\t<\/array>$/d' LoveHotel.app/Contents/Info.plist
cp ../../CHANGELOG CHANGELOG
cp ../../COPYING COPYING
cp ../../README.md README.md
zip -FS -qr9 ../lovehotel-mac.zip *
cd ..

# Build linux
rm -rf linux
mkdir -p linux
cd linux
mv ../LoveHotel.love .
cp ../../CHANGELOG CHANGELOG
cp ../../COPYING COPYING
cp ../../README.md README.md
zip -FS -qr9 ../lovehotel-love.zip *
cd ..

# Checksums
md5sum lovehotel-win.zip lovehotel-mac.zip lovehotel-love.zip > MD5SUMS
