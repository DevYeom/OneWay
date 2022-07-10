#!/bin/bash
set -eo pipefail
IFS=$'\n\t'

#remove all existing files
rm -fR ~/Library/Developer/Xcode/Templates/File\ Templates/OneWay

#create directory

mkdir -p ~/Library/Developer/Xcode/Templates/File\ Templates/OneWay

cp -R OneWay.xctemplate ~/Library/Developer/Xcode/Templates/File\ Templates/OneWay
