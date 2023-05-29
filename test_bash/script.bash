#!/bin/bash

# Function to remove postfixes from service names
remove_postfix() {
    echo $1 | sed -E 's/-[[:xdigit:]]{10}-[[:xdigit:]]{6}//'
}

# Set default server name if argument is not provided
SERVER=${1:-default_server}

# Get current date in the specified format
DATE=$(date +"%d_%m_%Y")

# Download the source file
curl -O https://raw.githubusercontent.com/GreatMedivack/files/master/list.out

# Create the failed and running files
awk -F'\t' '$2 == "Error" || $2 == "CrashLoopBackOff" { print $1 }' list.out | while read -r service; do
    echo $(remove_postfix $service) >> "${SERVER}_${DATE}_failed.out"
done

awk -F'\t' '$2 == "Running" { print $1 }' list.out | while read -r service; do
    echo $(remove_postfix $service) >> "${SERVER}_${DATE}_running.out"
done

# Count the number of services in the created files
failed_count=$(wc -l < "${SERVER}_${DATE}_failed.out")
running_count=$(wc -l < "${SERVER}_${DATE}_running.out")

# Create the report file
echo "Number of working services: $running_count" > "${SERVER}_${DATE}_report.out"
echo "Number of services with errors: $failed_count" >> "${SERVER}_${DATE}_report.out"
echo "System user name: $USER" >> "${SERVER}_${DATE}_report.out"
echo "Date: $(date +"%d/%m/%y")" >> "${SERVER}_${DATE}_report.out"

# Create an archive if it doesn't exist
archive="${SERVER}_${DATE}.tar.gz"
if [ ! -f "archives/$archive" ]; then
    mkdir -p archives
    tar -czf "archives/$archive" "${SERVER}_${DATE}"*
fi

# Delete all files except those in the archives folder
rm -rf !("archives")

# Check the archive for damage
if tar tf "archives/$archive" >/dev/null 2>&1; then
    echo "completed"
else
    echo "Error: Archive may be damaged."
fi
