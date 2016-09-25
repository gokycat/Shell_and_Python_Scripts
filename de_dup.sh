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
	count=0
	for ((i=1;i<=${total_columns};i++)); do
		echo "### Computing md5 for column number ${i}"
    	column_md5=`cut -d${delimiter} -f${i} ${file} | tail -n +2 | md5`
    	if [ ${i} -eq 1 ]
    	then
    		unique_md5s[${count}]=${column_md5}
    		unique_columns[${count}]=${i}
    		count=$((count+1))
		elif [[ " ${unique_md5s[@]} " =~ " ${column_md5} " ]]; then
    		echo "duplicate column found NUMBER: ${i}"
		else
    		unique_md5s[${count}]=${column_md5}
    		unique_columns[${count}]=${i}
    		count=$((count+1))
		fi
    	echo "md5 for column ${i} is ${column_md5}"
	done	
	echo "printing unique column numbers ${unique_columns[@]}"
	output_file=`../${output_dir}/${file}`
	echo ${output_file}
	# #chmod 777 ${output_file}
	# for col in `echo ${unique_columns[@]} | tr " " "\n"`
	# do
 #    	column_data=`cut -d${delimiter} -f${i} ${file}`
 #    	paste -d , ${output_file} ${column_data} >> ${output_file}
	# done
done














