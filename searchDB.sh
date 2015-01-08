# Script to search a pattern in the entire database.

# Steps to run this script
# 1. Launch db2cmd from start->search for db2cmd and execute it
# 2. Goto cygwin folder and excecute cygwin.bat
# 3. Run this command: export DB2CLP=**$$**
# 4. Run this command to remove windows white spaces from script: dos2unix searchDB.sh
# 5. Run this script as follows: sh searchDB.sh dbname pattern datatype
#	 - dbname:name of DB in which pattern is to be searched
#    - pattern: pattern to be searched in DB
#	 - datatype: datatype of pattern (enter v for varchar, i for integer, c for char)
# 6. Result of script is found in file 'result.out' as SchemaName.TableName.ColumnName

#!/bin/csh
if [[ $# -eq 3 ]]; then
	idbname=$1
	iPattern=$2
	if [ -f result.out ];
	then	rm result.out
	fi
	case $3 in
		i|I) 
			iDatatype="INTEGER"
			vPattern=$iPattern
			;;
		v|V)
			iDatatype="VARCHAR"
			vPattern="'%$iPattern%'"
			;;
		c|C)
			iDatatype="CHARACTER"
			vPattern="'%$iPattern%'"
			;;
		*)
			echo "Entered datatype cannot be searched by this utility."
			exit
			;;
	esac
	echo "**********Running script with following values**********"
	echo "dbname=$idbname"
	echo "Pattern=$iPattern"
	echo "Datatype=$iDatatype"
	echo "********************************************************"
	vDatatype="'$iDatatype'"	
	echo "**********Searching DB may take time. Please be patient...**********"
	db2 -x CONNECT TO $idbname >> output.out
	if [ "$?" -ne "0" ]
		then echo "**********Error while connecting database**********"
		exit
	else 
		echo "**********Connected to $idbname DB**********"
		echo "**********Getting Schema Information**********"
		db2 -x "SELECT distinct(tabschema) FROM syscat.tables where tabschema not like 'SYS%'"| sed -e 's/ //g' > DBSchemas.out
		#while read SchemaName
		for SchemaName in $(cat DBSchemas.out)
		do
			echo "**Searching schema $SchemaName for tables*****"
			vSCHEMA="'$SchemaName'"
			db2 -x "set current schema $SchemaName" >> output.out 
			db2 -x "SELECT tabname FROM syscat.tables WHERE tabschema=UPPER($vSCHEMA)"| sed -e 's/ //g' > DBTables.out
			#while read TableName
			for TableName in $(cat DBTables.out)
			do
				echo "**********Scanning table $TableName for value $iPattern**********"
				vTable="'$TableName'"
				db2 -x "SELECT COLNAME FROM syscat.columns WHERE tabname=UPPER($vTable) AND tabschema=UPPER($vSCHEMA) AND TYPENAME=UPPER($vDatatype)" > TabColumns.out
				for ColumnName in $(cat TabColumns.out)  
				do
				case $iDatatype in
					INTEGER) 
						db2 -x "SELECT '${SchemaName}.${TableName}.${ColumnName}' from sysibm.sysdummy1 where exists (SELECT 1 from $TableName WHERE $ColumnName=$vPattern)"|sed 's/ //g' >> result.out
						;;
					CHARACTER|VARCHAR)
						db2 -x "SELECT '${SchemaName}.${TableName}.${ColumnName}' from sysibm.sysdummy1 where exists (SELECT 1 from $TableName WHERE UPPER($ColumnName) like UPPER($vPattern))"|sed 's/ //g' >> result.out
						;;
				esac
				done #< TabColumns.out
				rm TabColumns.out
			done #< DBTables.out
			rm DBTables.out
		done #< DBSchemas.out
		rm DBSchemas.out
		db2 -x "terminate" >> output.out
	fi
	rm output.out
	fsize=$(stat -c %s result.out)
	#sed -e 's/ //g' < result.out
	if [[ $fsize -eq 0 ]]; then
		rm result.out
		echo "No match found in Database"
	else
		echo "**********Search completed successfully. Please find output in result.out**********"
	fi
else 
	echo "**********Run script with proper arguments**********"
fi
exit