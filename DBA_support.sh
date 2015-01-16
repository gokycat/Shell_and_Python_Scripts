#!/bin/ksh

# This script collects a number of DB2 diagnostic items that will be reviewed by DBA Support
# The script must run as the instance owner.  A temporary directory called DBA_support
# will be created under the current working directory.

# Parameters
#   database name
#   DBA_support_db2.sh -d <database name>

#. ~/.profile

. ~/sqllib/db2profile

echo "Utility to collect support data"

WHO=$(whoami)

if [ $WHO != $DB2INSTANCE ];  then
        print "Script must be run by DB2 instance owner!"
        exit 1
fi

SCRIPTNAME=$(basename $0)

USAGE="\n $SCRIPTNAME -d <DB> [-h] \n"

unset DBNAME

while getopts d:h OPT
do
        case $OPT in
                d)  DBNAME=$OPTARG
                    typeset -u DATABASE
                        ;;
                h)  print $USAGE; exit 0
                        ;;
                ?)  print "Unknown option $OPT!"; print $USAGE; exit 1
                        ;;
        esac
done

#  The script requires the database name to be passed to it.

if [[ -z $DBNAME ]] then
        print "$SCRIPTNAME: Database name is required!"
        print $USAGE
        exit 1
fi

FILEYY=$(date +%Y)
FILEMM=$(date +%m)
HYPHEN='-'
FILEDD=$(date +%d)
MIMIC='_mimic'
UNDERSCORE='_'

FILEDATE=$FILEYY$HYPHEN$FILEMM$HYPHEN$FILEDD
PARTIALNAME=$UNDERSCORE$DBNAME$UNDERSCORE$FILEDATE

echo "FILEDATE " $FILEDATE
echo "PARTIALNAME " $PARTIALNAME


# Cleanup files prior to collecting current information

outdir="./DBA_support"
if [ -f DBA_support$PARTIALNAME.tar ]  
then
  rm DBA_support.tar 
fi

if [ -f $outdir ]  
then
  rmdir $outdir 
fi

mkdir $outdir

db2 "connect to $DBNAME "

##########################################################################################################
#
# This section captures several pieces of diagnostic information with DB2 commands
#
##########################################################################################################

#  Get dbm cfg parameters

db2 get dbm cfg  > $outdir/dbm_cfg$HYPHEN$FILEDATE.out


#  Get db cfg parameters

db2 get db cfg for $DBNAME > $outdir/db_cfg_$DBNAME$HYPHEN$FILEDATE.out

#  Get  db2 registry variables

db2set -all  > $outdir/db2_registry$HYPHEN$FILEDATE.out

#  Get  db2 version information

db2level  > $outdir/db2level$HYPHEN$FILEDATE.out


#  Get  tablespace space usage  information

db2 list tablespaces show detail > $outdir/tablespaces$HYPHEN$FILEDATE.out


##########################################################################################################
#
# This section captures several pieces of information from the DB2 Catalog 
#
##########################################################################################################

#  Get  table/tablespace/bufferpool combination information

db2 "select substr(a.tabname,1,30) as table_name,a.type as type,substr(b.tbspace,1,22) as tablespace, substr(c.bpname,1,18) as bufferpool, c.pagesize,
 c.npages as npages,  b.tbspaceid as tbspaceid,
a.card as Number_of_rows, a.stats_time as last_updated_stats
   from syscat.tables a,
   syscat.tablespaces b,
   syscat.bufferpools c
 where a.type in ('S', 'T')
 and  a.tabSCHEMA not like 'SYS%'
 and  a.tabname not like 'ADVIS%'
 and  a.tabname not like 'EXPLAIN%'
 and a.tbspaceid = b.tbspaceid
 and b.bufferpoolid = c. bufferpoolid
order by 1 asc
with ur"  > $outdir/tbspace_bufferpool$HYPHEN$FILEDATE.out

db2 "SELECT Substr(tabname, 1, 15)  AS tabname,
       Substr(indname, 1, 20)  AS index,
       firstkeycard,
       first2keycard,
       first3keycard,
       first4keycard,
       fullkeycard,
       Substr(colnames, 1, 50) AS colnames 
FROM   syscat.indexes
ORDER  BY fullkeycard desc 
with ur"  > $outdir/index_card_sa$HYPHEN$FILEDATE.out

db2 "select substr(a.tabname,1,20) as tabname,
a.rows_read as TOTRowsRead,
(a.rows_read/(b.commit_sql_stmts + b.rollback_sql_stmts + 1)) as RowsRead_PerTX,
(b.commit_sql_stmts + b.rollback_sql_stmts) as TOT_TX
from sysibmadm.snaptab a, sysibmadm.snapdb b
where a.dbpartitionnum=b.dbpartitionnum
and b.db_name='$DBNAME' and TABSCHEMA not like 'SYS%' order by a.rows_read desc with ur"  > $outdir/rows_read_TX_sa$HYPHEN$FILEDATE.out

db2 "SELECT substr(a.tabname,1,20)                         AS table,
          a.indname                                        AS index,
       a.fullkeycard                                       AS IXFULLKEYCARD,
       b.card                                              AS TBCARD,
       Int(( Float(a.fullkeycard) / Float(b.card) ) * 100) AS IX_TABCARD_ratio
FROM   syscat.indexes a
       INNER JOIN syscat.tables b
               ON a.tabschema = b.tabschema 
                  AND a.tabname = b.tabname 
WHERE  a.fullkeycard > 1
       AND a.tabschema <> 'SYSIBM'
       AND b.card > 1000
       AND a.uniquerule <> 'U' 
       AND Int(( Float(a.fullkeycard) / Float(b.card) ) * 100) < 5 
       AND a.tabname IN (SELECT c.tabname 
                         FROM   sysibmadm.snaptab c )
ORDER  BY 1, 
          2, 
          3 with ur" > $outdir/probable_drop_ind_sa$HYPHEN$FILEDATE.out

#  Get  bufferpool sizing information

db2 "select bufferpoolid,
substr(bpname,1,18) as bpname, npages, pagesize
from syscat.bufferpools
order by bufferpoolid
with ur" > $outdir/bpsizing$HYPHEN$FILEDATE.out
##$HYPHEN$FILEDATE.out

# Get Bufferpool hit ratio information
# SNAPSHOT_TIMESTAMP is commented out to make the report a little less wide, but could be uncommented so that the report has the timestamp in it

db2 "SELECT
-- SNAPSHOT_TIMESTAMP,
SUBSTR(DB_NAME,1,10) AS DB_NAME,
SUBSTR(BP_NAME,1,14) AS BP_NAME,
TOTAL_LOGICAL_READS, TOTAL_PHYSICAL_READS, TOTAL_HIT_RATIO_PERCENT,
DATA_LOGICAL_READS, DATA_PHYSICAL_READS, DATA_HIT_RATIO_PERCENT,
INDEX_LOGICAL_READS, INDEX_PHYSICAL_READS, INDEX_HIT_RATIO_PERCENT
FROM SYSIBMADM.BP_HITRATIO
 ORDER BY 2 with UR" > $outdir/bphitratio$HYPHEN$FILEDATE.out

#  Get database snapshot for everyting

db2 "get snapshot for all on $DBNAME" > $outdir/snapshot_$DBNAME$HYPHEN$FILEDATE.out

#  Get log usage.  The TOTAL_LOG_USED_TOP_KB will give you the maximum log used space in KB
db2 "SELECT
substr(DB_NAME,1,10) as DB_NAME,
LOG_UTILIZATION_PERCENT, TOTAL_LOG_USED_KB,
TOTAL_LOG_AVAILABLE_KB, TOTAL_LOG_USED_TOP_KB
FROM SYSIBMADM.LOG_UTILIZATION
WITH UR" > $outdir/logusage$HYPHEN$FILEDATE.out

#  Collect basic index information

db2 "select substr(tabname,1,30) as table_name, substr(indname,1,21) as index_name,
firstkeycard, fullkeycard, clusterfactor, clusterratio, numrids,stats_time
from syscat.indexes
order by indschema,1,2 WITH UR" > $outdir/index_info_basic$HYPHEN$FILEDATE.out

#  Collect advanced index information

db2 "select substr(tabname,1,30) as tabname, substr(indname,1,21) as indname,indextype,tbspaceid,
iid,firstkeycard, fullkeycard, numrids,NLEAF,NLEVELS,PCTFREE,REVERSE_SCANS,
clusterfactor, clusterratio, stats_time
from syscat.indexes
order by indschema,1,2 WITH UR" > $outdir/index_info_adv$HYPHEN$FILEDATE.out

#  Collect advanced index information

db2 "select *
from syscat.indexes
 WITH UR" > $outdir/full_index_info$HYPHEN$FILEDATE.out

# This gives an idea of how many rows are in each table (cardinality)  

db2 "select substr(tabname,1,30) as tabname, card as row_count,stats_time
from syscat.tables
where type IN ('S', 'T')
and tabschema not like 'SYS%'
order by card desc
with ur" > $outdir/row_count$UNDERSCORE$FILEDATE.out

# Run db2pd to collect tcbstats information

db2pd -d $DBNAME -tcbstats all > $outdir/tcbstats$UNDERSCORE$FILEDATE.out

# In order to use the index usage information from db2pd, we need to know what the IID.s mean on your system, so  
# we will need the results of the following SQL which tells how the IIDs match up to tables 

db2 "select substr(i.indschema,1,10) as indschema, substr(i.indname,1,30) as indname,  i.IID, substr(t.tabname,1,30) as tabname, t.tableid, t.tbspaceid, substr(tb.tbspace,1,30) as tbspace from syscat.indexes i, syscat.tables t, syscat.tablespaces tb
where i.indschema not like 'SYS%'
and t.tbspaceid = tb.tbspaceid
and i.tabschema = t.tabschema
and i.tabname = t.tabname
order by t.tabname,t.tableid,i.IID asc
with ur" > $outdir/index_mapping$UNDERSCORE$FILEDATE.out

##########################################################################################################
#
# This section captures DDL from the database 
#
##########################################################################################################

db2look -d $DBNAME -e -l -o $outdir/$DBNAME$UNDERSCORE$FILEDATE.ddl

db2look -d $DBNAME -m -o $outdir/$DBNAME$UNDERSCORE$FILEDATE$MIMIC.ddl

##########################################################################################################
#
# This section captures  memory diagnostic information
#
##########################################################################################################

# This captures memory usage for the instance, the database(s), and applications
db2mtrk -i -d -v  > $outdir/db2mtrk_instance$UNDERSCORE$FILEDATE.out

# This captures memory usage for the instance, the database(s), and applications (maximum values that have been allocated)
db2mtrk -i -d -v -m  > $outdir/db2mtrk_instance_max$UNDERSCORE$FILEDATE.out

# This captures the information for private memory 
db2mtrk -p -v > $outdir/db2mtrk_private$UNDERSCORE$FILEDATE.out

# This captures the information for private memory (maximum values that have been allocated)
db2mtrk -p -m -v > $outdir/db2mtrk_private_max$UNDERSCORE$FILEDATE.out

# Get index usage information with the MON_GET_INDEX administrative view
db2 "export to $outdir/idx_temp.del of del
select a.TABNAME, a.INDNAME, substr(a.COLNAMES,2) as COLNAMES, a.UNIQUERULE , a.IID, a.UNIQUE_COLCOUNT, a.NLEAF, a.NLEVELS,
      a.FIRSTKEYCARD, a.FIRST2KEYCARD, a.FIRST3KEYCARD, a.FIRST4KEYCARD , a.FULLKEYCARD, a.CREATE_TIME, a.STATS_TIME,
      b.CARD, b.OVERFLOW, b.STATS_TIME,t.*
from syscat.indexes a, syscat.tables b, TABLE(MON_GET_INDEX('','', -2)) as T
where a.tabname = b.tabname
  and a.tabname = t.tabname
  and b.type in ('S','T')
  and a.iid = t.iid"

# Create a header line for the index usage information
echo "TABNAME,INDNAME,COLNAMES,UNIQUERULE,IID,UNIQUE_COLCOUNT,NLEAF,NLEVELS,FIRSTKEYCARD,FIRST2KEYCARD,FIRST3KEYCARD,FIRST4KEYCARD,FULLKEYCARD,CREATE_TIME,STATS_TIME,CARD,OVERFLOW,STATS_TIME,TABSCHEMA,TABNAME,IID,MEMBER,DATA_PARTITION_ID,NLEAF,NLEVELS,INDEX_SCANS,INDEX_ONLY_SCANS,KEY_UPDATES,INCLUDE_COL_UPDATES,PSEUDO_DELETES,DEL_KEYS_CLEANED,ROOT_NODE_SPLITS,INT_NODE_SPLITS,BOUNDARY_LEAF_NODE_SPLITS,NONBOUNDARY_LEAF_NODE_SPLITS,PAGE_ALLOCATIONS,PSEUDO_EMPTY_PAGES,EMPTY_PAGES_REUSED,EMPTY_PAGES_DELETED,PAGES_MERGED,ADDITIONAL_DETAILS" >  $outdir/idxstat_header.del

#  Create final output for index usage information
cat $outdir/idxstat_header.del $outdir/idx_temp.del > $outdir/idxstat$UNDERSCORE$FILEDATE.csv

# Get contents of Package Cache with the MON_GET_PKG_CACHE_STMT table function in del format for use in Excel
db2 "export to $outdir/pkg_cache_all_temp.csv of del
select * from TABLE(MON_GET_PKG_CACHE_STMT(null,null,null,-2 )) "

# Get list of columns returned by the MON_GET_PKG_CACHE_STMT table function for the customers FixPack level.  The columns do vary by FixPack version.
# This requires the creation of a view and a table that will be dropped immediately after the db2look runs

db2 "create view ZZZ.montbl1 as select * from TABLE(MON_GET_PKG_CACHE_STMT ( 'D', NULL, NULL, -2)) as T"
db2 "create table ZZZ.montbl like ZZZ.montbl1"

db2 -x "select substr(colname,1,30) from syscat.columns where tabname = 'MONTBL' and tabschema = 'ZZZ' order by colno asc" > $outdir/head.csv

tr '\n' ',' < $outdir/head.csv > $outdir/head1.csv

echo >> $outdir/head1.csv

#  Create final output for Package Cache usage information
cat $outdir/head1.csv $outdir/pkg_cache_all_temp.csv > $outdir/pkg_cache_all$UNDERSCORE$FILEDATE.csv

db2 "drop view ZZZ.montbl1"
db2 "drop table ZZZ.montbl"


# Get partial information from Package Cache with the MON_GET_PKG_CACHE_STMT table function in del format for use in Excel
db2 "export to $outdir/pkg_cache_partial_temp.csv of del
SELECT
SECTION_TYPE, EFFECTIVE_ISOLATION as ISO_LVL, EXECUTABLE_ID,
NUM_EXECUTIONS, NUM_EXEC_WITH_METRICS, PREP_TIME,
TOTAL_CPU_TIME AS CPU_TIME,
INTEGER(ROUND((TOTAL_CPU_TIME / (NUM_EXEC_WITH_METRICS + .0000001)))) AS AVG_CPU_MICROSEC,
STMT_EXEC_TIME,
INTEGER(ROUND((STMT_EXEC_TIME / (NUM_EXEC_WITH_METRICS + .0000001)))) AS AVG_EXEC_MS,
ROWS_MODIFIED,
INTEGER(ROUND((ROWS_MODIFIED / (NUM_EXEC_WITH_METRICS + .0000001)))) AS AVG_ROWS_MODIFIED,
ROWS_READ,
INTEGER(ROUND((ROWS_READ / (NUM_EXEC_WITH_METRICS + .0000001)))) AS AVG_ROWS_READ,
ROWS_RETURNED,
INTEGER(ROUND((ROWS_RETURNED / (NUM_EXEC_WITH_METRICS + .0000001)))) AS AVG_ROWS_RETURNED,
(ROWS_RETURNED / (rows_read + .000001)) as rows_selected_ratio,
STMT_TEXT,
TOTAL_SORTS,SORT_OVERFLOWS, TOTAL_ACT_TIME, TOTAL_ACT_WAIT_TIME, LOCK_WAITS,LOCK_TIMEOUTS,LOCK_ESCALS,DEADLOCKS
FROM TABLE(MON_GET_PKG_CACHE_STMT(NULL, NULL, NULL, -1))
WHERE EXECUTABLE_ID IS NOT NULL
ORDER BY ROWS_READ DESC"

# Create a header line for the pkg cache information
echo "SECTION TYPE, EFFECTIVE ISOLATION as ISO LVL, EXECUTABLE ID,NUM EXECUTIONS, NUM EXEC WITH METRICS, PREP TIME,TOTAL CPU TIME AS CPU TIME,AVG CPU MICROSEC,STMT EXEC TIME,AVG EXEC MS,ROWS MODIFIED,AVG ROWS MODIFIED,ROWS READ,AVG ROWS READ,ROWS RETURNED, AVG ROWS RETURNED,Rows Selected Ratio,STMT TEXT,TOTAL SORTS,SORT OVERFLOWS, TOTAL ACT TIME, TOTAL ACT WAIT TIME, LOCK WAITS,LOCK TIMEOUTS,LOCK ESCALS,DEADLOCKS" >  $outdir/pkg_cache_header1.del

# Create a header line for the pkg cache information
echo "STATEMENT,NUM_EXECUTIONS,PCT_TOT_QRY_EXEC,ROWS_READ_ALL_EXC,TOT_RR_PER_EXC,PCT_TOT_RR_ALL_EXC,TOTAL_CPU_TIME_ALL_EXC,TOT_CPU_PER_EXC,PCT_TOT_CPU_ALL_EX,STMT_EXEC_TIME_ALL_EXC,TOT_EXC_TME_PER_EXC,PCT_TOT_EXEC_ALL_EXC,SORT_TIME_ALL_EXC,SORT_TME_PER_EXC,PCT_TOT_SRT_ALL_EXC" >  $outdir/pkg1_sa.del

db2 "export to $outdir/pkg_cache_info_sa.del of del
WITH SUM_TAB (SUM_RR, SUM_CPU, SUM_EXEC, SUM_SORT, SUM_NUM_EXEC) AS (
        SELECT  FLOAT(SUM(ROWS_READ)),
                FLOAT(SUM(TOTAL_CPU_TIME)),
                FLOAT(SUM(STMT_EXEC_TIME)),
                FLOAT(SUM(TOTAL_SECTION_SORT_TIME)),
                FLOAT(SUM(NUM_EXECUTIONS))
            FROM TABLE(MON_GET_PKG_CACHE_STMT ( NULL, NULL, NULL, -2)) AS T
        )
SELECT
        substr(STMT_TEXT,1,1000) as STATEMENT,
		NUM_EXECUTIONS,
		DECIMAL(100*(FLOAT(NUM_EXECUTIONS)/SUM_TAB.SUM_NUM_EXEC),20,2) AS PCT_TOT_QRY_EXEC,
		ROWS_READ AS ROWS_READ_ALL_EXC,
        DECIMAL((FLOAT(ROWS_READ)/NUM_EXECUTIONS),20,2) AS TOT_RR_PER_EXC,
        DECIMAL(100*(FLOAT(ROWS_READ)/SUM_TAB.SUM_RR),20,2) AS PCT_TOT_RR_ALL_EXC,
        TOTAL_CPU_TIME AS TOTAL_CPU_TIME_ALL_EXC,
		DECIMAL((FLOAT(TOTAL_CPU_TIME)/NUM_EXECUTIONS),20,2) AS TOT_CPU_PER_EXC,
        DECIMAL(100*(FLOAT(TOTAL_CPU_TIME)/SUM_TAB.SUM_CPU),20,2) AS PCT_TOT_CPU_ALL_EXC,
        STMT_EXEC_TIME AS STMT_EXEC_TIME_ALL_EXC,
		DECIMAL((FLOAT(STMT_EXEC_TIME)/NUM_EXECUTIONS),20,2) AS TOT_EXC_TME_PER_EXC,
        DECIMAL(100*(FLOAT(STMT_EXEC_TIME)/SUM_TAB.SUM_EXEC),20,2) AS PCT_TOT_EXEC_ALL_EXC,
		TOTAL_SECTION_SORT_TIME AS SORT_TIME_ALL_EXC,
		DECIMAL((FLOAT(TOTAL_SECTION_SORT_TIME)/NUM_EXECUTIONS),20,2) AS SORT_TME_PER_EXC,
		DECIMAL(100*(FLOAT(TOTAL_SECTION_SORT_TIME)/SUM_TAB.SUM_SORT),20,2) AS PCT_TOT_SRT_ALL_EXC		
    FROM TABLE(MON_GET_PKG_CACHE_STMT ( NULL, NULL, NULL, -2)) AS T, SUM_TAB
    ORDER BY NUM_EXECUTIONS DESC WITH UR " 

cat $outdir/pkg1_sa.del $outdir/pkg_cache_info_sa.del > $outdir/pkg_cache_info_sa$UNDERSCORE$FILEDATE.csv	

# Create a header line for the pkg cache information
echo "STATEMENT,NUM_EXECUTIONS,ROWS_READ_ALL_EXC,PCT_TOT_RR_ALL_EXC,ROWS_RETURNED_ALL_EXC,READ_EFFICIENCY_ALL_EXC" >  $outdir/pkg2_sa.del

db2 "export to $outdir/pkg_cache_rowinfo_sa.del of del
 WITH SUM_TAB (SUM_RR) AS (
        SELECT FLOAT(SUM(ROWS_READ))
        FROM TABLE(MON_GET_PKG_CACHE_STMT ( NULL, NULL, NULL, -2)) AS T)
SELECT
        SUBSTR(STMT_TEXT,1,1000) AS STATEMENT,
		NUM_EXECUTIONS,
        ROWS_READ AS ROWS_READ_ALL_EXC,
        DECIMAL(100*(FLOAT(ROWS_READ)/SUM_TAB.SUM_RR),5,2) AS PCT_TOT_RR_ALL_EXC,
        ROWS_RETURNED AS ROWS_RETURNED_ALL_EXC,
        CASE
            WHEN ROWS_RETURNED > 0 THEN
				DECIMAL(100*(FLOAT(ROWS_RETURNED)/FLOAT(ROWS_READ)),10,2)
            ELSE -1
        END AS READ_EFFICIENCY_ALL_EXC
    FROM TABLE(MON_GET_PKG_CACHE_STMT ( NULL, NULL, NULL, -2)) AS T, SUM_TAB
    ORDER BY NUM_EXECUTIONS DESC WITH UR" 

cat $outdir/pkg2_sa.del $outdir/pkg_cache_rowinfo_sa.del > $outdir/pkg_cache_row_info_sa$UNDERSCORE$FILEDATE.csv

db2 "select decimal(PKG_CACHE_INSERTS,10,3) as PKG_CACHE_INSERTS, decimal(PKG_CACHE_LOOKUPS,10,3) as PKG_CACHE_LOOKUPS, 100*decimal(1-decimal(PKG_CACHE_INSERTS,10,3)/decimal(PKG_CACHE_LOOKUPS,10,3),10,3) as pkg_cache_hit_ratio from table(SYSPROC.MON_GET_WORKLOAD('SYSDEFAULTUSERWORKLOAD', -2)) as t with ur" > $outdir/pkg_cache_hit_ratio_sa$UNDERSCORE$FILEDATE.out

	
#  Create final output for index usage information
cat $outdir/pkg_cache_header1.del $outdir/pkg_cache_partial_temp.csv > $outdir/pkg_cache_partial$UNDERSCORE$FILEDATE.csv
  
# Get contents of Package Cache with the MON_GET_PKG_CACHE_STMT table function in ixf format to load to a DB2 table for analysis
db2 "export to $outdir/pkg_cache_all.ixf of ixf
select * from TABLE(MON_GET_PKG_CACHE_STMT(null,null,null,-2 )) "

# Get Wait Time totals from Package Cache using the MON_GET_PKG_CACHE_STMT table function
db2 "SELECT
SUM(TOTAL_CPU_TIME) AS TOT_CPU_TIME, SUM(STMT_EXEC_TIME) AS TOT_EXEC_TIME
,SUM(TOTAL_ACT_TIME) AS TOT_ACT_TIME, SUM(TOTAL_ACT_WAIT_TIME) AS TOT_WAIT_TIME
,SUM(LOCK_WAIT_TIME) AS TOT_LOCK_WAIT_TIME
,SUM(LOCK_WAITS) AS TOT_LOCK_WAITS
,SUM(LOCK_ESCALS) AS TOT_LOCK_ESCALS
,SUM(LOCK_TIMEOUTS) AS TOT_LOCK_TIMEOUTS
,SUM(DEADLOCKS) AS TOT_DEADLOCKS
,SUM(FCM_RECV_WAIT_TIME) AS TOT_FCM_RECV_WAIT_TIME
,SUM(FCM_SEND_WAIT_TIME) AS TOT_FCM_SEND_WAIT_TIME
,SUM(LOG_BUFFER_WAIT_TIME) AS TOT_LOG_BUFFER_WAIT_TIME
,SUM(LOG_DISK_WAIT_TIME) as TOT_LOG_DISK_WAIT_TIME
,SUM(TOTAL_ROUTINE_TIME) as TOT_TOTAL_ROUTINE_TIME
,SUM(POOL_READ_TIME) as TOT_POOL_READ_TIME
,SUM(POOL_WRITE_TIME) as TOT_POOL_WRITE_TIME
,SUM(TOTAL_SORTS) as TOT_SORTS
,SUM(SORT_OVERFLOWS) as TOT_SORT_OVERFLOWS
FROM TABLE(MON_GET_PKG_CACHE_STMT(NULL, NULL, NULL, -1))
with ur" > $outdir/wait_time_totals$UNDERSCORE$FILEDATE.out

db2 "SELECT
substr(t.TABNAME,1,20) as TABNAME,
substr(INDNAME,1,20) as INDNAME,
CARD,
FULLKEYCARD,
decimal((100*(float(FULLKEYCARD)/float(CARD))),5,2) as indfullkey_to_card_pct
from syscat.tables t, syscat.indexes i
where t.tabname=i.tabname and t.tabschema=i.tabschema
and t.tabschema not like 'SYS%'
and t.type='T'
order by decimal((100*(float(FULLKEYCARD)/float(CARD))),5,2) 
with ur" > $outdir/indfullkey_to_card_pct_sa$UNDERSCORE$FILEDATE.out

db2 "SELECT
substr(t.TABNAME,1,20) as TABNAME,
substr(INDNAME,1,20) as INDNAME,
AVGROWSIZE as ROWSIZE,
AVGLEAFKEYSIZE as KEYSIZE,
100*(decimal((float(AVGLEAFKEYSIZE)/float(AVGROWSIZE)),7,5)) as PCT_OF_ROWSIZE
from syscat.tables t, syscat.indexes i
where t.tabname=i.tabname and t.tabschema=i.tabschema
and t.type='T'
and AVGROWSIZE > 0
and t.tabschema not like 'SYS%'
order by PCT_OF_ROWSIZE desc 
with ur" > $outdir/indfullkey_to_row_size_pct_sa$UNDERSCORE$FILEDATE.out

db2 "SELECT Substr(a.tabname, 1, 20)tabname, 
       Substr(c.bpname, 1, 20) BPNAME 
FROM   syscat.tables a, 
       syscat.tablespaces b, 
       syscat.bufferpools c 
WHERE  a.tabschema not like 'SYS%'
       AND a.TYPE = 'T' 
       AND a.tbspace = b.tbspace 
       AND B.bufferpoolid = C.bufferpoolid with ur" > $outdir/tab_to_buffpool_sa$UNDERSCORE$FILEDATE.out

db2 "SELECT Substr(t.tabname, 1, 20)      AS TABNAME, 
       Substr(indname, 1, 20)        AS INDNAME, 
       i.lastused, 
       fullkeycard                   AS indfullkeycard, 
       card                          AS table_card, 
       Decimal(clusterfactor, 10, 5) AS clusterfactor 
FROM   syscat.tables t, 
       syscat.indexes i 
WHERE  t.tabname = i.tabname 
       AND t.tabschema = i.tabschema 
       AND t.TYPE = 'T' 
       AND fullkeycard < 0.5 * card 
       AND clusterfactor != -1 
       AND uniquerule = 'D' 
       AND clusterfactor < 0.8 
       AND t.tabschema NOT LIKE 'SYS%' 
ORDER  BY fullkeycard, 
          clusterfactor 
WITH UR " > $outdir/bad_ind_clus_card_sa$UNDERSCORE$FILEDATE.out

# Get table access report using MON_GET_TABLE table function
db2 "SELECT varchar(tabschema,8) as tabschema,
       varchar(tabname,30) as tabname,
       sum(TABLE_SCANS) as total_table_scans,
       sum(rows_read) as total_rows_read,
       sum(rows_inserted) as total_rows_inserted,
       sum(rows_updated) as total_rows_updated,
       sum(rows_deleted) as total_rows_deleted
FROM TABLE(MON_GET_TABLE('','',-2)) AS t
GROUP BY tabschema, tabname
ORDER BY total_rows_read DESC with ur" > $outdir/table_access_totals$UNDERSCORE$FILEDATE.out

# Get tablespace utilization information using  SYSIBMADM.TBSP_UTILIZATION
db2 "SELECT  * FROM SYSIBMADM.TBSP_UTILIZATION
order by TBSP_FREE_SIZE_KB DESC  with ur" > $outdir/tablespace_utilization$UNDERSCORE$FILEDATE.out


rm $outdir/idx_temp.del
rm $outdir/idxstat_header.del
rm $outdir/pkg_cache_header1.del
rm $outdir/pkg_cache_partial_temp.csv
rm $outdir/head.csv 
rm $outdir/head1.csv 
rm $outdir/pkg_cache_all_temp.csv

# Copy all the files in the temporary directory into a single tar file named DBAsupport<databasename><date>.tar
tar cvf DBAsupport$PARTIALNAME.tar $outdir/*

gzip DBAsupport$PARTIALNAME.tar 

# Cleanup the temporary directory
cd $outdir
rm *.out
rm *.ddl
rm *.del
rm *.csv
rm *.ixf

cd ..
rmdir $outdir

