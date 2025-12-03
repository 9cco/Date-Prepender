#!/bin/bash

# Author: Fredrik Nicolai Krohg
# Last-modified-date: 2025-12-03
# Place: Oslo Norway
# Licence: GPL 3.0

# Renames all files that does not have the date and time prepended in the
# format YYYYmmdd_HHMMSS, and prepends this by using the "last-modified"-date
# or the "file-create" date or the "Create Date" exif-data if available, whicever
# is earliest.


# Rename JPGs with dates
# Copyright (C) 2025  Fredrik Nicolai Krohg

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

if ! find . -maxdepth 1 -type f -iname '*.jpg' | grep -q .; then
    echo "No files found, exiting."
    exit 0
fi
# [0-9][0-9][0-9][0-9][01][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9][0-5][0-9]*
find . -maxdepth 1 -type f -iname '*.jpg' | while read -r file; do
    base=$(basename "$file")
    dir=$(dirname "$file")

    fileCreationDate=$(stat -c %y "$file" 2>/dev/null | cut -d ' ' -f 1,2 || stat -c %w "$file" 2>/dev/null | cut -d ' ' -f 1,2)
    fileCreationDateTimeFormatted=$(date -d "$fileCreationDate" +"%Y%m%d_%H%M%S" 2>/dev/null || echo "unknown")

    # Attempting to find exif-information
    exifCreationString=$(exiftool -CreateDate "$file" | cut -d ':' -f 2-6 | xargs)
    exifCreationDate=$(echo $exifCreationString | cut -d ' ' -f 1 | xargs | tr ':' '-')
    exifCreationTime=$(echo $exifCreationString | cut -d ' ' -f 2 | xargs)
    exifCreationDateTime="$exifCreationDate $exifCreationTime"
    exifCreationDateTimeFormatted=$(date -d "$exifCreationDateTime" +"%Y%m%d_%H%M%S" 2>/dev/null || echo "unknown")

    # Figuring out the earliest creation time by lexicographical order.
    if [[ "${fileCreationDateTimeFormatted}" == "unknown" && "${exifCreationDateTimeFormatted}" == "unknown" ]]; then
        echo "Could not determine creation date for $file" >&2
        continue
    fi

    creationDateTimeFormatted="$exifCreationDateTimeFormatted"
    if [[ "${exifCreationDateTimeFormatted}" == "unknown" ]]; then
        creationDateTimeFormatted="$fileCreationDateTimeFormatted"
    elif [[ "$exifCreationDateTimeFormatted" != "unknown" && "$fileCreationDateTimeFormatted" != "unknown" ]]; then
        if [[ "$exifCreationDateTimeFormatted" < "$fileCreationDateTimeFormatted" ]]; then
            creationDateTimeFormatted="$exifCreationDateTimeFormatted"
        else
            creationDateTimeFormatted="$fileCreationDateTimeFormatted"
        fi
    fi

    # If the filename does not have a prepended date-time this gives the correct new name
    newFilename="${creationDateTimeFormatted}_${base}"
    # If the filename has a prepended date-time already, we have to figure out the earliest.
    if [[ "$base" =~ ^[0-9][0-9][0-9][0-9][01][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9][0-5][0-9].* ]]; then
        # Extract the prepended date
        newFilename="${base}"
        filePrefix=$(echo $base | sed -E "s/^([0-9][0-9][0-9][0-9][01][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9][0-5][0-9]).*/\1/")
        # Use lexicographical order again to find the earliest date.
        if [[ "$creationDateTimeFormatted" < "$filePrefix" ]]; then
            redactedFilename=$(echo $base | sed -E "s/^[0-9][0-9][0-9][0-9][01][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9][0-5][0-9](.*)/\1/")
            newFilename="${creationDateTimeFormatted}${redactedFilename}"
        fi
    fi

    if [[ "$file" == "$dir/${newFilename}" ]]; then
        continue
    fi

    #echo "$file > $dir/${newFilename}"
    mv -n "$file" "$dir/${newFilename}"
done

echo "Files renamed successfully!"
