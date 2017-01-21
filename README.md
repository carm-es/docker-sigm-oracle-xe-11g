
SIGM (oracle-xe-11g) en Docker
================================

Este directorio permite construir la base de datos de SIGM
sobre Oracle Express Edition 11g Release 2 en Ubuntu 14.04 LTS.


El fichero **Dockerfile** está basado en [wnameless/oracle-xe-11g:14.04.4](https://github.com/wnameless/docker-oracle-xe-11g), al 
que se ha añadido el soporte para 
[ejecutar los scripts de inicialización de la base de datos](https://carm-es.github.io/SIGM/3.0.1/Documentaci%C3%B3n-t%C3%A9cnica/instalaci%C3%B3n/Configuraci%C3%B3n-para-Oracle-11g.html).

Esta imagen puede usarse para **testear una versión concreta de SIGM** o bien para **depurar el 
procedimiento y documentación de inicialización de la base de datos**, durante el desarrollo.


### Cómo usar esta imagen

Primero genere la imagen:
```
docker build -t sigm/oracle-11g:3.0.1-M2 .
```

Luego podrá ejecutarla mediante:
```
docker run -p 1521:1521 -p 49160:22 -d sigm/oracle-11g:3.0.1-M2
```

Podrá conectar a esta instancia *(credenciales según [wnameless/oracle-xe-11g:14.04.4](https://github.com/wnameless/docker-oracle-xe-11g))*:
```
hostname: localhost
port: 1521
sid: xe
username: system
password: oracle
```

También podrá conectar por SSH:
```
ssh -p 49160 root@localhost
```

Contraseñas:

* para `SYS` y `SYSTEM`: `oracle`
* para `root`: `admin`
* para los usuarios de SIGM *(sigemadmin,tramitadords_000,registrods_000, etc)*: `passw0rd`


Si desea conectar desde un cliente Oracle (*toad, sqlplus, etc*) deberá añadir a su fichero `$TNS_ADMIN/tnsnames.ora` 
la cadena de conexión a SIGM:

```
SIGM = (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = *DIR_IP*)(PORT = *PUERTO*))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = XE)
    )
  )
```

..donde...

* `*DIR_IP*` será la dirección IP del equipo que ejecuta el contenedor para Oracle *(ejemplos: 127.0.0.1, 192.168.1.20, etc)*
* `*PUERTO*` será el puerto TCP que mapeó al 1521 al lanza el comando `docker run -p *PUERTO*:1521 ` 


### Personalización

Existen dos variables en el fichero `Dokerfile` que controlan el despliegue de la versión de SIGM:

* **`SIGM_VERSION`** que permite indicar la versión de SIGM a desplegar. Hasta ahora sólo se ha probado para [3.0.1-M2](https://github.com/carm-es/SIGM/tree/3.0.1-M2)
* **`SIGM_REPO`** que apunta al repositorio de artefactos generados con la compilación de SIGM *(resultado de ejecutar: `mvn deploy ...`)*

El despliege tratará de descargar el fichero `$SIGM_REPO/es/ieci/tecdoc/sigem/sigem_bd_dist/$SIGM_VERSION/sigem_bd_dist-${SIGM_VERSION}-bd.zip` que contiene todos los scripts de inicialización de las distintas base de datos.

Para tareas de desarrollo y depuración también se comentar la definición de `SIGM_REPO`, copiar el fichero `sigem_bd_dist-${SIGM_VERSION}-bd.zip` al mismo directorio que `Dockerfile` y descomentar:
```  
#ADD sigem_bd_dist-${SIGM_VERSION}-bd.zip /var/lib/sigm/sigem_bd_dist-${SIGM_VERSION}-bd.zip 
``` 

Cada vez que cambie este `.zip` deberá ejecutar:
```
 docker build -t sigm/oracle-11g:3.0.1-M2 .
 docker run -p 1521:1521 -p 49160:22 -i sigm/oracle-11g:3.0.1-M2
```

También podrá personalizar la imagen para comprobar el despliegue de SIGM sobre otras versiones de Oracle, de forma rápida. Para ello deberá editar el fichero `Dockerfile` y cambiar:
```
# Selección de versión de Oracle a usar
#   https://github.com/wnameless/docker-oracle-xe-11g
FROM wnameless/oracle-xe-11g:14.04.4
``` 


