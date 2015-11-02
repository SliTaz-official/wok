#!/bin/sh

echo '#define VERSION_STRING "'$VERSION'"' > version.h
echo $VERSION
