#!/bin/bash
#
#

 WorkDir="/var/lib/sigm"
 DB="Oracle"

 # Descomprimir scripts para la base de datos
 cd $WorkDir 

 # Descargar si se puede el ZIP con los scripts
 dev=1
 if [ ! -e sigem_bd_dist-${SIGM_VERSION}-bd.zip ]
 then
    if [ "" != "$SIGM_REPO" ]
    then
       dev=0
       echo "Descargarndo 'sigem_bd_dist-${SIGM_VERSION}-bd.zip' de '$SIGM_REPO'" >&2
       wget "$SIGM_REPO/es/ieci/tecdoc/sigem/sigem_bd_dist/$SIGM_VERSION/sigem_bd_dist-${SIGM_VERSION}-bd.zip"
    fi
 fi

 if [ -e sigem_bd_dist-${SIGM_VERSION}-bd.zip ]
 then
    unzip sigem_bd_dist-${SIGM_VERSION}-bd.zip "$DB/*" || exit 123
    if [ 1 -eq $dev ]
    then
       echo "USANDO scripts locales (desarrollo)" >&2
    fi
 else
    echo "ERROR: No se puede acceder a sigem_bd_dist-${SIGM_VERSION}-bd.zip ... saliendo" >&2
    exit 126
 fi
 

 #
 # CREACION DE TABLESPACES...
 #
 #  - Crear uno para los esquemas comunes
 #  - Otro  para la entidad 000
 #  - Crear uno independiente para la auditoria (come mucho)
 #
 
 cat >$WorkDir/01-CreateTS.sql <<EOSQL

-- Para evitar que nos pregunte por los ampersand
SET escape on
SET define off

-- Evitar caducidad de contraseña
ALTER PROFILE "DEFAULT" LIMIT PASSWORD_LIFE_TIME UNLIMITED;

-- Cambiar la clave del system para que no caduque
ALTER USER system IDENTIFIED BY oracle;

-- Crear los tableSpaces
CREATE TABLESPACE tbs_sigm_common DATAFILE 'tbs_common.dbf' SIZE 200M ONLINE;
CREATE TABLESPACE tbs_sigm_audit_000  DATAFILE 'tbs_audit_000.dbf' SIZE  200M ONLINE;
CREATE TABLESPACE tbs_sigm_000  DATAFILE 'tbs_entidad_000.dbf' SIZE  512M ONLINE;

-- Crear usuarios
CREATE USER sigemadmin IDENTIFIED BY passw0rd DEFAULT TABLESPACE tbs_sigm_common
  TEMPORARY TABLESPACE TEMP
      QUOTA UNLIMITED ON tbs_sigm_common ;

GRANT connect,resource TO sigemadmin;
GRANT create view TO sigemadmin;



CREATE USER fwktd_dir3 IDENTIFIED BY passw0rd DEFAULT TABLESPACE tbs_sigm_common
  TEMPORARY TABLESPACE TEMP
      QUOTA UNLIMITED ON tbs_sigm_common ;

GRANT connect,resource TO fwktd_dir3;
GRANT create view TO fwktd_dir3;



CREATE USER fwktd_audit_000 IDENTIFIED BY passw0rd DEFAULT TABLESPACE tbs_sigm_audit_000
  TEMPORARY TABLESPACE TEMP
      QUOTA UNLIMITED ON tbs_sigm_audit_000 ;

GRANT connect,resource TO fwktd_audit_000;
GRANT create view TO fwktd_audit_000;



CREATE USER registrods_000 IDENTIFIED BY passw0rd DEFAULT TABLESPACE tbs_sigm_000
  TEMPORARY TABLESPACE TEMP
      QUOTA UNLIMITED ON tbs_sigm_000 ;

GRANT connect,resource TO registrods_000;
GRANT create view TO registrods_000;



CREATE USER fwktd_sirds_000 IDENTIFIED BY passw0rd DEFAULT TABLESPACE tbs_sigm_000
  TEMPORARY TABLESPACE TEMP
      QUOTA UNLIMITED ON tbs_sigm_000 ;

GRANT connect,resource TO fwktd_sirds_000;
GRANT create view TO fwktd_sirds_000;



CREATE USER archivods_000 IDENTIFIED BY passw0rd DEFAULT TABLESPACE tbs_sigm_000
  TEMPORARY TABLESPACE TEMP
      QUOTA UNLIMITED ON tbs_sigm_000 ;

GRANT connect,resource TO archivods_000;
GRANT create view TO archivods_000;
GRANT EXECUTE ON CTXSYS.CTX_DDL TO archivods_000;


CREATE USER etramitacionds_000 IDENTIFIED BY passw0rd DEFAULT TABLESPACE tbs_sigm_000
  TEMPORARY TABLESPACE TEMP
      QUOTA UNLIMITED ON tbs_sigm_000 ;

GRANT connect,resource TO etramitacionds_000;
GRANT create view TO etramitacionds_000;


CREATE USER tramitadords_000 IDENTIFIED BY passw0rd DEFAULT TABLESPACE tbs_sigm_000
  TEMPORARY TABLESPACE TEMP
      QUOTA UNLIMITED ON tbs_sigm_000 ;

GRANT connect,resource TO tramitadords_000;
GRANT create view TO tramitadords_000;


exit;

EOSQL
 
 # Crear directorio de inicializacion si no existe
 mkdir -p /docker-entrypoint-initdb.d

 # Inicializacion de la Base de datos
 cat >/docker-entrypoint-initdb.d/SIGM.sh  <<EOF

cd $WorkDir 
echo "CREANDO TABLESPACES y USUARIOS" >&2
/u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s system/oracle @01-CreateTS.sql

cd $WorkDir/$DB 
echo "Inicializando sigemAdmin" >&2
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s sigemadmin/passw0rd @sigemAdmin/sigemAdmin.sql 


echo "Inicializando fwktd-dir3DS" >&2
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s fwktd_dir3/passw0rd @dir3/fwktd-dir3-create.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s fwktd_dir3/passw0rd @dir3/fwktd-dir3-insert.sql

echo "Inicializando fwktd-auditDS_000" >&2

# Correccion de scripts para que no fallen
echo -e "SET SQLBLANKLINES ON\\n\\n" > /tmp/a
cat audit/fwktd-audit-create.sql >> /tmp/a
cp -f /tmp/a audit/fwktd-audit-create.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s fwktd_audit_000/passw0rd @audit/fwktd-audit-create.sql

echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s fwktd_audit_000/passw0rd @tramitador/50-tramitador_auditoria_datos.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s fwktd_audit_000/passw0rd @registro/06-insert_data_registro_auditoria_datos_oracle.sql

echo "Inicializando registroDS_000" >&2

echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s registrods_000/passw0rd @registro/01.1_create_tables_registro_sigem_oracle.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s registrods_000/passw0rd @registro/01.2_create_tables_invesdoc_registro_sigem_oracle.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s registrods_000/passw0rd @registro/01.3_create_views_invesdoc_registro_sigem_oracle.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s registrods_000/passw0rd @registro/02.1_create_indexes_constraints_registro_sigem_oracle.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s registrods_000/passw0rd @registro/02.2_create_indexes_constraints_invesdoc_registro_sigem_oracle.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s registrods_000/passw0rd @registro/03.1_insert_data_registro_sigem_oracle.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s registrods_000/passw0rd @registro/03.2_insert_data_invesdoc_registro_sigem_oracle.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s registrods_000/passw0rd @registro/04.1_insert_clob_invesdoc_registro_sigem_oracle.sql

# Correccion de scripts para que no fallen
echo -e "SET SQLBLANKLINES ON\\n\\n" > /tmp/a
cat registro/05-sicres3.sql >> /tmp/a
cp -f /tmp/a  registro/05-sicres3.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s registrods_000/passw0rd @registro/05-sicres3.sql

echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s registrods_000/passw0rd @sigemEstructuraOrganizativa/01.1_create_tables_sigem_estructura_organizativa.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s registrods_000/passw0rd @sigemEstructuraOrganizativa/02.1_create_indexes_constraints_estructura_organizativa.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s registrods_000/passw0rd @create_user_consolidacion.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s registrods_000/passw0rd @repositorios_registro_sigem_oracle.sql


echo "Importando Informes de SIGM" >&2
/u01/app/oracle/product/11.2.0/xe/bin/imp  system/oracle file=registro/SCR_REPORTS.DMP touser=registrods_000 tables=SCR_REPORTS log=SCR_REPORTS_IMP.log ignore=Y


echo "Inicializando fwktd-sirDS_000" >&2

echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s fwktd_sirds_000/passw0rd @sir/fwktd-sir-create.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s fwktd_sirds_000/passw0rd @sir/fwktd-sir-insert.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s fwktd_sirds_000/passw0rd @sir/fwktd-dm-bd-create.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s fwktd_sirds_000/passw0rd @sir/fwktd-dm-bd-insert.sql



echo "Inicializando archivoDS_000" >&2

echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/01.archivo-create-tables-oracle.sql

# Cambiar parametro
cat archivo/02.archivo-create-indexes-oracle.sql | sed -e "s+&1+tbs_sigm_000+g" > /tmp/aa
cp -f /tmp/aa archivo/02.archivo-create-indexes-oracle.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/02.archivo-create-indexes-oracle.sql 
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/03.archivo-insert-data-oracle.sql

# Evitar que los Ampersand se traten como vbles
echo -e "SET DEFINE OFF \\n\\n" > /tmp/a
cat archivo/04.archivo-insert-clob-oracle.sql >> /tmp/a
cp -f /tmp/a  archivo/04.archivo-insert-clob-oracle.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/04.archivo-insert-clob-oracle.sql

echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/05.archivo-create-functions-oracle.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/06.archivo-create-procedures-oracle.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/07.archivo-personalization-oracle.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/complementario/archivo-organizacion-bd/01.archivo-organizacion-bd-create-tables-oracle.sql

# Cambiar parametro
cat archivo/complementario/archivo-organizacion-bd/02.archivo-organizacion-bd-create-indexes-oracle.sql | sed -e "s+&1+tbs_sigm_000+g" > /tmp/aa
cp -f /tmp/aa archivo/complementario/archivo-organizacion-bd/02.archivo-organizacion-bd-create-indexes-oracle.sql
echo "exit;"  | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/complementario/archivo-organizacion-bd/02.archivo-organizacion-bd-create-indexes-oracle.sql

echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/complementario/archivo-busqueda-documental/01.ARCHIVOFTSTH.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/complementario/archivo-busqueda-documental/02.ARCHIVOFTSTB.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/complementario/archivo-busqueda-documental/03.ARCHIVOINTERMEDIA.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/complementario/archivo-busqueda-documental/04.ARCHIVOJOBINTERMEDIA.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s archivods_000/passw0rd @archivo/complementario/archivo-busqueda-documental/05.ARCHIVOOPT.sql


echo "Inicializando eTramitacionDS_000" >&2

echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s etramitacionds_000/passw0rd @eTramitacion/01_create_tables.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s etramitacionds_000/passw0rd @eTramitacion/02_create_indexes_constraints.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s etramitacionds_000/passw0rd @eTramitacion/03_insert_data.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s etramitacionds_000/passw0rd @eTramitacion/04_insert_data_tasks.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s etramitacionds_000/passw0rd @csv/fwktd-csv-create.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s etramitacionds_000/passw0rd @eTramitacion/05_insert_data_csv_fwktd_module.sql


echo "Inicializando TramitadorDS_000" >&2

echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/01-create_sequences.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/02-create_tables.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/02b-create_indexes_constraints.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/03-create_views.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/03b-create_procedures.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/04-datos_iniciales.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.1-datos_prototipos-create_sequences.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.1-datos_prototipos-create_tables.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.1-datos_prototipos-create_constraints.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.1-datos_prototipos.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.2-datos_prototipos_v1.9-create_sequences.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.2-datos_prototipos_v1.9-create_tables.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.2-datos_prototipos_v1.9-create_indexes_constraints.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.2-datos_prototipos_v1.9.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.3-informes_estadisticos.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/07-actualizacion_permisos.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/08-configuracion_publicador.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/04b-datos_iniciales_clob.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/04b-datos_iniciales_plantillas_clob.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.1b-datos_prototipos_clob.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.1b-datos_prototipos_plantillas_clob.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.2b-datos_prototipos_v1.9_clob.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.2b-datos_prototipos_v1.9_plantillas_clob.sql
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.3-informes_estadisticos.sql 
echo "exit;" | /u01/app/oracle/product/11.2.0/xe/bin/sqlplus -s tramitadords_000/passw0rd @tramitador/06.3-informes_estadisticos_clob.sql   


rm -f /tmp/a /tmp/aa

EOF

