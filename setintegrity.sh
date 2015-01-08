#!/bin/csh

#Script  to search and remove all tables from the integrity pending state of a DB2 database.

if [[ -n "$2" ]]
then

	export DB_NAME=$1
	export DB_SCHEMA=$2

    db2 connect to $DB_NAME
    db2 set current schema $DB_SCHEMA
    rm -rf tabname.out
    db2 -x "select tabname from syscat.tables where tabschema='$DB_SCHEMA' and type='T' and status='C'" | sed -e 's/ //g' > tabname.out
    while read line
    do
        db2 -x "SET INTEGRITY FOR $DB_SCHEMA.$line immediate checked"
    done < tabname.out
    db2 connect reset
    
else
    echo ""
    echo "Usage: setintegrity.sh <DB_NAME> <DB_SCHEMA>"
    echo ""
    exit 1
fi