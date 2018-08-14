#!/bin/bash
set -o nounset
###################################################################################################
title="LANDesk md5 chunk calculator"
###################################################################################################

filepath="$1"

filename=$(basename "$1")

split -b 10m "$filepath" "/tmp/$filename.chunk."

echo "					<array>"
for chunk in "/tmp/$filename.chunk."* ; do
echo "						<string>"$(md5 -q "$chunk")"</string>"
rm "$chunk"
done
echo "					</array>"
