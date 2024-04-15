#!/bin/bash

declare -a resized_files
declare -a raw_files
declare -a durations
declare -i total_duration=0

scale="2880:1800"

# Feles should have {int}.mp4 name
raw_files=($(ls *.mp4 | grep -E '^(?:[1-9]|[1-3][0-9]|40)\.mp4$' | sort -n))
echo "Raw files count: ${#raw_files[@]}"

# Resize Raw files to the same scale
for file in "${raw_files[@]}"; do
  echo "Resizing ${file}..."
  save_as="resized_${file}"
  ffmpeg -i ${file} -vf scale=${scale} ${save_as}
  echo "Finished saved as ${save_as}"
done

# List resized files
resized_files=($(ls resized_*.mp4))
echo "Processing resized_files: ${resized_files[@]}"

# Calc durations of each video
for file in "${resized_files[@]}"; do
  duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${file}")
  duration=$(printf "%.0f" $duration)
  durations+=("$duration")
  total_duration+=$duration
  echo "Duration of $file: $duration seconds"
done

echo "Finished with video durations; total elements found: ${#durations[@]}"

# Start generating the filter_complex
echo "Starting filter generation..."

filter_complex=""
input_files=""
previous_offset=0
transition_duration=2
previous_output="v0"

for (( i=0; i<${#resized_files[@]}; i++ )); do
  input_files+="-i ${resized_files[i]} "
  filter_complex+="[${i}:v]fps=30/1,settb=AVTB[v${i}];"

  if [ $i -gt 0 ]; then
    new_output="out${i}"
    previous_offset=$(($previous_offset + ${durations[$i - 1]} - $transition_duration))
    filter_complex+="[${previous_output}][v${i}]xfade=transition=fade:duration=$transition_duration:offset=$previous_offset[$new_output];"
    previous_output=$new_output
  fi
done

# Use the last output from xfade as the output to the file
echo "Filter complex: $filter_complex"

ffmpeg $input_files -filter_complex "$filter_complex" -map "[$previous_output]" output.mp4

echo "Merging complete. Output file is output.mp4"
