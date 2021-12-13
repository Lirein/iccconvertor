#!/bin/sh
lazbuild iccconvertor.lpi
strip iccconvertor
mkdir -p dist
cp iccconvertor dist
cp iccconvertor.ini dist
cp -r icc dist
