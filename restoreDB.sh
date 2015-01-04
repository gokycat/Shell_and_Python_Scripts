#!/bin/ksh
DB_BACKUP_DIR=~/backup

echo "The backup dir is: ${DB_BACKUP_DIR}"
if [[ -n "$2" ]]
then

	export DB_MASTER=$1   #Source DB name
	export DB_NAME=$2     #Target DB name
	
    # Check to see if current database exists
	export CHECK_DB=$(db2 list db directory | grep "Database name" | awk -F "=" '{print $2}' | grep ${DB_NAME}| wc -l | awk '{print $1}' )
	db2 terminate

	function restoreDB {
		echo "restoring latest backup of ${DB_MASTER} into ${DB_NAME}"
		if [[ -f ${DB_BACKUP_DIR}/${DB_MASTER}-into-${DB_NAME}-redirect.sql ]]
		then
			rm ${DB_BACKUP_DIR}/${DB_MASTER}-into-${DB_NAME}-redirect.sql
			rm ${DB_BACKUP_DIR}/${DB_MASTER}_NODE0000.out
		fi
		# Get current database time stamp
		DB_TSTAMP=`ls ${DB_BACKUP_DIR}/${DB_MASTER}.* | xargs basename | awk -F "." '{print $6}'`

		echo "db2 restore db ${DB_MASTER} from ${DB_BACKUP_DIR} taken at  ${DB_TSTAMP} into ${DB_NAME}"
		db2 restore db ${DB_MASTER} from ${DB_BACKUP_DIR} taken at ${DB_TSTAMP} into ${DB_NAME} 
		echo "RC: $RC" 
		db2 terminate
	}
	
	if (( ${CHECK_DB} < 1 ))
	then
	    echo "${DB_NAME} does not exist, database will be created."
	    restoreDB
	    exit 0
	else
	    echo ""
	    echo "Forcing any connections that still exist to the database..."
        echo ""

        DB_APP_HANDLE=$(db2 list applications | grep ${DB_NAME} | awk '{print $3}')
	
        for i in ${DB_APP_HANDLE}
	    do
            echo "Forcing Application handle ${DB_APP_HANDLE} on ${DB_NAME}"
	        db2 "force applications ($i)"
	    done
		db2 deactivate database ${DB_NAME}
        db2 terminate

        echo "Dropping previous version of database"
        db2 drop db ${DB_NAME}
        db2 terminate

        # Call function
        restoreDB      
	fi
else
    echo ""
    echo "Usage: restoreDB.sh <dbMaster> <dbName>"
    echo ""
    exit 1
fi

