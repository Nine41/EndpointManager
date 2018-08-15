#!/bin/bash

#  createIvantiAgentPKG.sh
#  Created by Nine41 Consulting, LLC 8/12/18.

# variables for script
developerInstallerCert="devolperID"
agentVersion="11.0.0.25"
agentIdentifier="com.ivanti.macOS.agent"

# deleting old packages, if any
rm -f ./Agent/IvantiMacAgent.pkg
rm -f ./Agent/IvantiMacAgentMDMReady.pkg


if test -z "$1"; then
echo "Agent Installer Missing: Please add the path to the Ivanti Agent DMG file as a parameter."
exit 1
fi

mkdir -p ./Agent

cp "$1" ./Agent/IvantiMacAgent.dmg


CURRENT=`pwd`
BASENAME=`basename "$CURRENT"`

echo "$BASENAME"
echo "$PWD"

# Build Package and Sign
pkgbuild --root ./Agent --identifier "$agentIdentifier" --scripts ./scripts --version "$agentVersion" --install-location /tmp --sign "$developerInstallerCert" ./Agent/"IvantiMacAgent.pkg"
productbuild --sign "$developerInstallerCert" --version "$agentVersion" --identifier "$agentIdentifier" --package ./Agent/IvantiMacAgent.pkg ./Agent/IvantiMacAgentMDMReady.pkg
sleep 3

# set filesize in manifest.plist
echo "Updating file size in manifest"
fileSize=( $(/usr/bin/mdls ./Agent/IvantiMacAgentMDMReady.pkg | grep kMDItemLogicalSize | awk '{print $3}' ) )
manifestFileSize=( $(/usr/libexec/PlistBuddy -c "Print :items:0:metadata:sizeInBytes" ./Agent/manifest.plist) )

echo "File size for the newly created IvantiMacAgentMDMReady.pkg is "$fileSize.
echo "Current file size in the manifest.plist is "$manifestFileSize.
echo "Updating the file size in the manifest.plist file."
/usr/libexec/PlistBuddy -c "Set :items:0:metadata:sizeInBytes $fileSize" ./Agent/manifest.plist

manifestFileSizeUpdated=( $(/usr/libexec/PlistBuddy -c "Print :items:0:metadata:sizeInBytes" ./Agent/manifest.plist) )
echo "The file size in the manifest.plist file is now $manifestFileSizeUpdated."

if [ ${fileSize} == ${manifestFileSizeUpdated} ]; then
  echo "File size and manifest file match, plist was properly edited"
else
  echo "File size and manifest file do not match, plist was not properly edited"
  exit 1
fi

# Get the MD5 hash in 10 MBs chunks and set in manifest
updatedMD5Array=()
while IFS= read -r line; do
    updatedMD5Array+=( "$line" )
done < <(./md5_chunks.sh ./Agent/IvantiMacAgentMDMReady.pkg | sed 's/\<array\>//g' | sed 's/\<\/array\>//g'| sed 's/\<string\>//g' | sed 's/\<\/string\>//g'| sed '/^\[\[:space:\]\]*$/d' )
echo The updated plist MD5 array is ${updatedMD5Array[@]}
/usr/libexec/PlistBuddy -c "Delete :items:0:assets:0:md5s" ./Agent/manifest.plist
/usr/libexec/PlistBuddy -c "Add :items:0:assets:0:md5s array" ./Agent/manifest.plist
for hash in "${updatedMD5Array[@]}";
do
    # Write the team identifier to the file
    ((  i++ ))
    /usr/libexec/PlistBuddy -c "Add :items:0:assets:0:md5s:${i} string ${hash}" ./Agent/manifest.plist
    lastArrayNumber=$(expr $i - 1)
done

#delete the last blank line in array plist
/usr/libexec/PlistBuddy -c "Delete :items:0:assets:0:md5s:${lastArrayNumber}" ./Agent/manifest.plist
echo "Deleting the last blank line from the plist array"
# delete first blank line in array plist
/usr/libexec/PlistBuddy -c "Delete :items:0:assets:0:md5s:0" ./Agent/manifest.plist
echo "Deleting the first blank line from the plist array"

# cleaning up un-needed files
rm -f ./Agent/IvantiMacAgent.pkg
rm -f ./Agent/IvantiMacAgent.dmg
