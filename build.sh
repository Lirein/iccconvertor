#!/bin/sh
lazbuild --build-mode=Linux64 iccconvertor.lpi
lazbuild --build-mode=Win64 iccconvertor.lpi
upx -9 iccconvertor iccconvertor.exe
mkdir -p dist
cp -r icc dist
cp iccconvertor.ini dist
cp iccconvertor dist
test -f  iccconvertor.tar.gz && rm  iccconvertor.tar.gz
tar -zcf iccconvertor.tar.gz dist
rm dist/iccconvertor
cp iccconvertor.exe dist
cp convert.exe dist
test  iccconvertor.zip && rm iccconvertor.zip
zip -9 -r iccconvertor.zip dist
rm -r dist
