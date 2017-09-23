#!/bin/bash

# Script for downloading runoff observations from database

# Define period:

tstart=200010010000
tstop=$(date +%Y%m%d%H%M)

# Define path to station list:

stat_list="$HOME/flood_forecasting/control/hbv_fields.csv"

# Define path to output directory:

path_out="$HOME/flood_forecasting/runoff_observed"

# Remove old files

rm $path_out/*.*

# Start downloading data

echo "Downloading data from $tstart to $tstop"

for irow in `awk 'NR>1 {print NR}' $stat_list`
do

reg=`awk -F';' -v n=$irow 'NR==n {print $1}' $stat_list `
mno=`awk -F';' -v n=$irow 'NR==n {print $2}' $stat_list `
vno=`awk -F';' -v n=$irow 'NR==n {print $5}' $stat_list `

echo "Downloaded data for station: " $reg $mno $vno

$HYDRA/bin/prog/lescon_day -f timevalue 29 $reg $mno 0 1001 $vno | \
awk '{FS=" "; OFS="\t"; print substr($1,1,4) "-" substr($1,5,2) "-" substr($1,7,2), $2 }'\
 > $path_out/$reg.$mno.0.1001.$vno

done
