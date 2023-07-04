echo "******************************************************************************"
echo "Post install setups based on needs of the project." `date`
echo "******************************************************************************"
echo "******************************************************************************"
echo "Create FRA directory" `date`
echo "******************************************************************************"
mkdir -p /u01/fra
ls -ld /u01/fra
echo "Waiting a minute to config"
sleep 60
echo "******************************************************************************"
echo "Enable Flash Recovery Area and flashback features" `date`
echo "******************************************************************************"
# fulfill FRA prereqs
sqlplus -s / as sysdba <<EOF
  alter system set db_recovery_file_dest_size=10G scope=both sid='*';
  alter system set db_recovery_file_dest='/u01/fra/' scope=both sid='*';
  alter system set db_flashback_retention_target=60 scope=both sid='*';
  ALTER SYSTEM SET UNDO_RETENTION = 120 scope=both sid='*';
  alter database force logging;
  shutdown immediate;
  startup nomount;
  select status from v\$instance;
EOF
echo "configured and wait the DB to shutdown"
sleep 20

echo "******************************************************************************"
echo "enabling archive " `date`
echo "******************************************************************************"

sqlplus -s / as sysdba <<EOF
BEGIN
  dbms_lock.sleep(seconds =>30);
END;
/
  alter database mount;
  alter database archivelog;
  alter database open;
EOF

sleep 20
echo "******************************************************************************"
echo "Report all configs after configurations" `date`
echo "******************************************************************************"
sleep 10
# verification steps
sqlplus -s  / as sysdba <<EOF
  alter system switch logfile;
  alter database flashback on;
  set pages 200
  set lines 200
  col FORCE_LOGGING for a12
  col LOG_MODE for a12
  col VALUE format a50
  col NAME format a80
  select name, value from v\$parameter
  where name =  'undo_retention'
  or name = 'db_recovery_file_dest'
  or name = 'db_recovery_file_dest_size'
  or name = 'db_flashback_retention_target'
  /
  SELECT log_mode FROM v\$database;
  select flashback_on from v\$database;
  select force_logging from v\$database;

EOF



echo "******************************************************************************"
echo "configure rman" `date`
echo "******************************************************************************"
  rman target / <<EOF
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '/u01/fra/snapcf_cdb1.f';
CONFIGURE ARCHIVELOG DELETION POLICY TO BACKED UP 1 TIMES TO 'DISK';
show all;
EOF
