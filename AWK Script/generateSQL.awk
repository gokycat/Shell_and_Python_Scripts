#Given an input file with data separated by field separators
#and the syntax (here UPDATE SQL) of the SQL statement to be generated,
#for given data this AWK script is used to generate SQL script which has same
#syntax but different data values from the given input file. 
#save this script as generateSQL.awk and execute it as -
#awk -f generateSQL.awk input.txt > output.sql
# --------------------------------------------------------------------------------------------

#!/bin/csh
BEGIN{
FS="|";}
{
printf ( "UPDATE MyTble \n");
printf ( " SET Column1=’%s\n",$2 "‘");
printf ( " WHERE Column2=’%s",$1"‘;\n\n");
}
END{
printf ( "CONNECT RESET;\n");
}