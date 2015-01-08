#Takes two files as arguments and copies common contents to file CommonValues.out
#Also copies extra content in File1(which is not in File2) into a file ExtraInFile1
#One value per line in input files

#!/bin/csh
File1=$1
File2=$2
for line in $(cat $File1)
do
returnValue=$(grep -iw $line $File2)
exitStatus=$?
case $exitStatus in
0) #found
	echo $line >> CommonValues.out
	;;
1) #not found
	echo $line >> ExtraIn$File1
	;;
esac
done