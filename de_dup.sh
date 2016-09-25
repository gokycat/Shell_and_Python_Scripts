#!/bin/ksh

delimiter=','
#check run-arguments
if [ ${#} -ne 2 ]
then
    echo "ERROR: Run script with proper arguments"
    echo "Usage: ./de_dup.dh input-dir-path output-dir-path"
    exit 1
fi

input_dir=$1
output_dir=$2

echo "### Running CSV de-dup script with input-dir: ${input_dir} and output-dir: ${output_dir}"

#check if input directory exists
if [ ! -d ${input_dir} ]; then
  echo "ERROR: Input directory: ${input_dir} does not exists"
  exit 1
fi

# look for empty dir 
if [ ! "$(ls -A ${input_dir})" ]; then
     echo "ERROR: Input directory ${input_dir} is empty"
     exit 1
fi

#check if output directory exists
if [ ! -d ${output_dir} ]; then
  echo "Output directory: ${output_dir} does not exists"
  echo "Creating new output directory"
  mkdir -p ${output_dir}
fi

echo "### Listing files in input_dir: $input_dir"

files=`ls -1 ${input_dir}`

for file in $files
do
	echo "${file}"
done

cd ${input_dir}

for file in $files
do
	echo "### De-duping file: ${file}"
	header=`head -1 ./${file}`
	echo "### Header for file: ${file} is header: ${header}"
	total_columns=`echo $header | awk -F${delimiter} '{print NF}'`
	for ((i=1;i<=${total_columns};i++)); do
		echo "### Computing md5 for column number "
    	column_md5=`cut -d${delimiter} -f${i} ${file} | tail -n +2 | md5`
    	echo "md5 for column ${i} is ${column_md5}"
	done	

done














