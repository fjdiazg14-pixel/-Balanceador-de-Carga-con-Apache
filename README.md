# -Balanceador-de-Carga-con-Apache  

Francisco Javier Díaz Garrón  
22/11/2026  
ASIR 2º  

## Índice
1. [Introducción y Aclaración](#1-introducción-y-aclaración)
2. [Explicación Paso a Paso de las Configuraciones](#3-explicación-paso-a-paso-de-las-configuraciones)
   - [2.1. Definición de la Infraestructura (`Vagrantfile`)](#21-definición-de-la-infraestructura-vagrantfile)
   - [2.2. Capa 3: Servidor de Base de Datos (`aprovisionamiento_bd.sh`)](#22-capa-3-servidor-de-base-de-datos-aprovisionamiento_bdsh)
   - [2.3. Capa 2: Servidores Web Backend (`aprovisionamiento_web.sh`)](#23-capa-2-servidores-web-backend-aprovisionamiento_websh)
   - [2.4. Capa 1: Balanceador de Carga (`aprovisionamiento_balanceador.sh`)](#24-capa-1-balanceador-de-carga-aprovisionamiento_balanceadorsh)
   - [2.5. Dominio en DuckDNS y Certificado SSL con Certbot y Let's Encrypt](#25-dominio-en-duckdns-y-certificado-ssl-con-certbot-y-lets-encrypt)
3. [Comprobaciones y Capturas de Pantalla](#4-comprobaciones-y-capturas-de-pantalla)
4. [Screencast de Demostración](#5-screencast-de-demostración)

## 1. Introducción y Aclaración

En esta práctica se ha desplegado una aplicación web de gestión de usuarios sobre una arquitectura de tres niveles utilizando Vagrant con imágenes de Debian 12. El objetivo es repartir la carga de trabajo y aislar las redes por capas, creando cuatro máquinas virtuales:  

1. **Nivel 1 - Balanceador de Carga (`FranciscoJavierDiazGarronBalanceador`):** Es la única máquina la cual pueden ver los usuarios, el resto permanecen ocultas en redes internas (red pública `red_web`, IP `172.20.1.10`) y con acceso a Internet. Recibe las peticiones de los usuarios mediante redirección de puertos (`80 -> 8080` y `443 -> 8443`) y las reparte entre los servidores web utilizando Nginx y un certificado SSL válido de Let's Encrypt asociado al dominio `franciscojavierdiaz.duckdns.org`.  
2. **Nivel 2 - Servidores Web Backend (`FranciscoJavierDiazGarronWeb1` y `FranciscoJavierDiazGarronWeb2`):** Dos servidores Apache con PHP situados en dos redes privadas, `172.20.1.21` y `172.20.1.22` en `red_web`, y `172.20.2.21` y `172.20.2.22` en `red_bbdd` que sirven la aplicación web y no tienen acceso a Internet. Solo aceptan peticiones HTTP procedentes del balanceador.  
3. **Nivel 3 - Servidor de Base de Datos (`FranciscoJavierDiazGarronBBDD`):** Máquina con MariaDB situada en una red interna aislada `red_bbdd`, IP `172.20.2.20` y sin acceso a Internet, que almacena los registros de la aplicación y solo acepta conexiones desde los dos servidores web.  

### Aclaración sobre la infraestructura utilizada
Debido a que en mi ordenador no puedo virtualizar por lo que no puedo crear máquinas virtuales, la práctica se ha realizado en el entorno Killercoda, se ha utilizado Vagrant con el proveedor Docker (`provider "docker"`) en lugar de VirtualBox, ya que en killercoda no existe Virtualbox. De este modo, cada máquina es un contenedor Debian 12 independiente con su propio servicio SSH, redes privadas aisladas (`red_web` y `red_bbdd`) y reglas de cortafuegos (`iptables`) para controlar exactamente el tráfico permitido en cada capa.  

## 2. Explicación Paso a Paso de las Configuraciones  

### 2.1. Definición de la Infraestructura (`Vagrantfile`)

`Vagrant.configure("2") do |config|` --> Inicia el bloque de configuración principal de Vagrant.  

`config.ssh.username = "vagrant"`, `config.ssh.password = "vagrant"` y `config.ssh.insert_key = false` --> Configuran el usuario, la contraseña y desactivan el intercambio automático de claves SSH para que Vagrant pueda conectarse directamente a los contenedores Docker.  

`cmd_arranque = ["bash", "-c", "..."]` --> Define el comando inicial que ejecutarán los contenedores al arrancar: actualiza repositorios, instala openssh-server y sudo, crea el directorio /run/sshd, crea el usuario vagrant con permisos sudo sin contraseña y arranca el demonio SSH en primer plano (`/usr/sbin/sshd -D`).  

`config.vm.define "base_datos" do |bd|` --> Define la máquina de Capa 3 con el hostname `FranciscoJavierDiazGarronBBDD`, usando la imagen debian:bookworm, conectada únicamente a la red `red_bbdd` con la IP `172.20.2.20` y ejecutando el script `aprovisionamiento_bd.sh`.  

`config.vm.define "web1" do |w1|` y `config.vm.define "web2" do |w2|` --> Definen las dos máquinas de Capa 2 `FranciscoJavierDiazGarronWeb1` y `FranciscoJavierDiazGarronWeb2`, conectadas a `red_web` (`172.20.1.21` y `172.20.1.22`) y a `red_bbdd` (`172.20.2.21` y `172.20.2.22`), pasando a `aprovisionamiento_web.sh` el argumento `"Servidor Web 1"` y `"Servidor Web 2"` respectivamente, ademas de ejecutarse el aprovisionamiento.  

`config.vm.define "balanceador" do |bal|` --> Define la máquina de Capa 1 `FranciscoJavierDiazGarronBalanceador`, conectada a `red_web` (`172.20.1.10`), redirigiendo los puertos `80 -> 8080` y `443 -> 8443` mediante Port Forwarding y ejecutando `aprovisionamiento_balanceador.sh`.  

### 2.2. Capa 3: Servidor de Base de Datos (`aprovisionamiento_bd.sh`)  

`#!/bin/bash` --> Indica al sistema que el archivo debe ejecutarse utilizando el intérprete de comandos Bash.  

`export DEBIAN_FRONTEND=noninteractive` --> Permite que la instalación de paquetes sea no interactiva y se realice automáticamente sin esperar confirmación del usuario.  

`apt-get update -y` --> Actualiza la lista de paquetes disponibles y sus versiones en el sistema.  

`apt-get install -y mariadb-server git iptables iptables-persistent iproute2` --> Instala sin pedir confirmación el servidor de bases de datos MariaDB, Git, el cortafuegos `iptables`, el paquete `iptables-persistent` para guardar las reglas de forma permanente y `iproute2` para gestionar las rutas de red.  

`sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf` --> Edita el archivo de configuración de MariaDB para sustituir la escucha local `127.0.0.1` por `0.0.0.0`, permitiendo conexiones remotas desde los servidores web de Capa 2, ya que 0.0.0.0 permite la escucha de todas las redes.  

`service mariadb restart` --> Reinicia el servicio de MariaDB para aplicar la nueva configuración de red.  

`git clone https://github.com/josejuansanchez/iaw-practica-lamp /tmp/app` --> Clona el repositorio de la aplicación dentro de una carpeta temporal `/tmp/app` para obtener el fichero SQL.  

`mysql -e "CREATE DATABASE IF NOT EXISTS lamp_db;"` --> Crea la base de datos `lamp_db` si no existe previamente.  

`mysql -e "CREATE USER IF NOT EXISTS 'javier-lamp'@'%' IDENTIFIED BY '1234';"` --> Crea el usuario `javier-lamp` con contraseña `1234` permitiendo su conexión desde cualquier host de la red interna.  

`mysql -e "GRANT ALL PRIVILEGES ON lamp_db.* TO 'javier-lamp'@'%';"` --> Concede todos los privilegios al usuario `javier-lamp` sobre todas las tablas de `lamp_db`.  

`mysql -e "FLUSH PRIVILEGES;"` --> Recarga la tabla de privilegios de MariaDB para aplicar los permisos al instante.  

`mysql lamp_db < /tmp/app/db/database.sql` --> Importa la estructura de tablas y datos desde `database.sql` dentro de la base de datos `lamp_db`.  

`rm -rf /tmp/app` --> Elimina la carpeta temporal `/tmp/app` una vez importada la base de datos.  

`iptables -A INPUT -i lo -j ACCEPT` --> Permite todo el tráfico interno de la interfaz local (`loopback`).  

`iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT` --> Permite el tráfico de respuesta de conexiones que ya estén establecidas o relacionadas.  

`iptables -A INPUT -p tcp --dport 22 -j ACCEPT` --> Permite el acceso por SSH puerto 22 para la administración y aprovisionamiento de Vagrant.  

`iptables -A INPUT -p tcp -s 172.20.2.21 --dport 3306 -j ACCEPT` --> Permite peticiones TCP al puerto de MariaDB 3306 procedentes únicamente de la IP del Servidor Web 1 (`172.20.2.21`).  

`iptables -A INPUT -p tcp -s 172.20.2.22 --dport 3306 -j ACCEPT` --> Permite peticiones TCP al puerto de MariaDB 3306 procedentes únicamente de la IP del Servidor Web 2 (`172.20.2.22`).  

`iptables -P INPUT DROP` --> Establece la política por defecto de entrada en DROP, bloqueando cualquier otro tráfico no autorizado hacia la base de datos.  

`netfilter-persistent save` --> Guarda las reglas de `iptables` de forma persistente para que no se pierdan al reiniciar.  

`ip route del default` --> Elimina la puerta de enlace predeterminada para cortar el acceso a Internet en la sesión actual.  

`cat << 'EOF' > /etc/systemd/system/no-internet.service` --> Crea el archivo de servicio `no-internet.service` en `systemd` para mantener el aislamiento de Internet tras reiniciar  

`[Unit]` --> Define los metadatos y dependencias de arranque del servicio  

`Description=Eliminar ruta por defecto para aislar de Internet` --> Descripción descriptiva del servicio.  

`After=network-online.target` --> Indica que el servicio debe ejecutarse justo después de que la red esté completamente levantada.  

`Wants=network-online.target` --> Indica que requiere que el objetivo de red esté activo antes de lanzarse.  

`[Service]` --> Define el comportamiento y comando del servicio  

`Type=oneshot` --> Indica que ejecuta una única acción puntual y finaliza.  

`ExecStart=/sbin/ip route del default` --> Orden exacta que ejecuta al arrancar (eliminar la ruta por defecto).  

`RemainAfterExit=yes` --> Mantiene el estado del servicio como activo tras finalizar la orden.  

`[Install]` --> Define el nivel de arranque:  

`WantedBy=multi-user.target` --> Vincula el servicio al arranque estándar multiusuario de Linux.  

`EOF` --> Marca el final del bloque de texto en `no-internet.service`.  

`systemctl daemon-reload` --> Recarga la configuración de `systemd` para reconocer el nuevo servicio creado.  

`systemctl enable no-internet.service` --> Habilita el servicio `no-internet.service` para que se ejecute automáticamente en cada arranque.  


### 2.3. Capa 2: Servidores Web Backend (`aprovisionamiento_web.sh`)  

`#!/bin/bash` --> Indica que el script debe ejecutarse con el intérprete Bash.  

`export DEBIAN_FRONTEND=noninteractive` --> Configura la instalación de paquetes en modo automático sin preguntas interactivas.  

`NOMBRE_SERVIDOR=$1` --> Guarda en la variable `NOMBRE_SERVIDOR` el primer argumento pasado desde el `Vagrantfile` (`Servidor Web 1` o `Servidor Web 2`).  

`apt-get update -y` --> Actualiza la lista de paquetes del sistema.  

`apt-get install -y apache2 php libapache2-mod-php php-mysql git iptables iptables-persistent iproute2` --> Instala Apache2, PHP, el módulo de integración entre Apache y PHP, el controlador MySQL para PHP, Git, el cortafuegos `iptables` y las herramientas de red `iproute2`.  

`rm -rf /var/www/html/*` --> Elimina los archivos por defecto del directorio público de Apache.  

`git clone https://github.com/josejuansanchez/iaw-practica-lamp /tmp/app` --> Clona el repositorio con la aplicación web en la carpeta temporal `/tmp/app`.  

`cp -r /tmp/app/src/* /var/www/html/` --> Copia el código fuente de la aplicación al directorio raíz de Apache (`/var/www/html/`).  

`rm -rf /tmp/app` --> Borra la carpeta temporal `/tmp/app`.  

`sed -i "s/localhost/172.20.2.20/g" /var/www/html/config.php` --> Sustituye en `config.php` el servidor `localhost` por la dirección IP del servidor de base de datos (`172.20.2.20`).  

`sed -i "s/database_name_here/lamp_db/g" /var/www/html/config.php` --> Sustituye el nombre de la base de datos por `lamp_db` en config.php.  

`sed -i "s/username_here/javier-lamp/g" /var/www/html/config.php` --> Sustituye el usuario de la base de datos por `javier-lamp` en config.php.  

`sed -i "s/password_here/1234/g" /var/www/html/config.php` --> Sustituye la contraseña por `1234` en config.php.  

`sed -i "s/<body>/<body><div style='background:#222;color:#fff;padding:10px;text-align:center;'>Atendido por: <strong>$NOMBRE_SERVIDOR ($(hostname))<\/strong><\/div>/g" /var/www/html/index.php` --> Inserta una barra superior en `index.php` mostrando qué servidor (`Servidor Web 1` o `Servidor Web 2`) y `hostname` atiende la petición web.  

`chown -R www-data:www-data /var/www/html/` --> Cambia el propietario y grupo de todos los archivos de la web al usuario `www-data` de Apache para evitar problemas de permisos.  

`service apache2 restart` --> Reinicia el servidor web Apache para aplicar todos los cambios.  

`iptables -A INPUT -i lo -j ACCEPT` --> Permite el tráfico interno de la interfaz local (`loopback`).  

`iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT` --> Permite las respuestas de conexiones ya establecidas.  

`iptables -A INPUT -p tcp --dport 22 -j ACCEPT` --> Permite el acceso SSH puerto 22.  

`iptables -A INPUT -p tcp -s 172.20.1.10 --dport 80 -j ACCEPT` --> Permite tráfico HTTP al puerto `80` procedente únicamente de la IP del balanceador de carga (`172.20.1.10`).  

`iptables -P INPUT DROP` --> Bloquea por defecto cualquier otra conexión entrante hacia los servidores web.  

`netfilter-persistent save` --> Guarda las reglas de `iptables` de forma permanente.  

`ip route del default` --> Elimina la ruta por defecto para aislar de Internet a los servidores de Capa 2.  

`cat << 'EOF' > /etc/systemd/system/no-internet.service` --> Crea el archivo de servicio `no-internet.service` en `systemd` para mantener aislados de Internet a los servidores web tras reiniciar  

`[Unit]` --> Define los metadatos y dependencias de arranque del servicio:  

`Description=Eliminar ruta por defecto para aislar Capa 2` --> Descripción descriptiva del servicio dentro del sistema.  

`After=network-online.target` --> Indica que el servicio debe ejecutarse justo después de que la red esté completamente levantada.  

`Wants=network-online.target` --> Indica que el servicio requiere que el objetivo de red esté activo antes de lanzarse.  

`[Service]` --> Define qué orden ejecuta el servicio y cómo se comporta:  

`Type=oneshot` --> Indica que el servicio ejecuta una única acción puntual y finaliza.  

`ExecStart=/sbin/ip route del default` --> Orden exacta que ejecuta al arrancar (eliminar la ruta por defecto para cortar Internet).  

`RemainAfterExit=yes` --> Mantiene el estado del servicio como activo tras haber terminado de ejecutarse.  

`[Install]` --> Define en qué momento del arranque se activará el servicio  

`WantedBy=multi-user.target` --> Vincula el servicio al arranque estándar multiusuario de Linux, para que lo ejecuten todos los usuarios.  

`EOF` --> Marca el final del bloque de texto en `/etc/systemd/system/no-internet.service`.  

### 2.4. Capa 1: Balanceador de Carga (`aprovisionamiento_balanceador.sh`)  

`#!/bin/bash` --> Indica al sistema que el archivo debe ejecutarse utilizando el intérprete de comandos Bash.  

`export DEBIAN_FRONTEND=noninteractive` --> Configura la instalación en modo no interactivo para no detenerse pidiendo confirmaciones al usuario.  

`apt-get update -y` --> Actualiza la lista de paquetes disponibles y sus versiones en el sistema.  

`apt-get install -y nginx certbot python3-certbot-nginx iptables iptables-persistent iproute2` --> Instala sin pedir confirmación el servidor proxy inverso Nginx, Certbot, el plugin de Certbot para Nginx, el cortafuegos `iptables`, `iptables-persistent` para guardar las reglas y `iproute2`.  

`cat << 'EOF' > /etc/nginx/sites-available/balanceador` --> Crea el archivo de configuración del sitio virtual de Nginx metiendo todo el contenido siguiente hasta encontrar la marca `EOF`  

`upstream backend_webs {` --> Inicia el bloque que define el grupo de servidores backend entre los que se repartirá el tráfico:  

`server 172.20.1.21;` --> Añade al grupo de balanceo la IP del Servidor Web 1.  

`server 172.20.1.22;` --> Añade al grupo de balanceo la IP del Servidor Web 2.  

`}` --> Cierra el bloque `upstream`.  

`server {` --> Inicia el bloque del servidor virtual que atenderá las peticiones entrantes:  

`listen 80 default_server;` --> Indica a Nginx que escuche peticiones HTTP en el puerto `80` como servidor por defecto.  

`server_name _;` --> Acepta peticiones dirigidas a cualquier nombre de dominio o dirección IP.  

`location / {` --> Define cómo gestionar todas las peticiones dirigidas a la ruta raíz /  

`proxy_pass http://backend_webs;` --> Reenvía la petición hacia el grupo `backend_webs`, alternando entre `Web1` y `Web2` mediante algoritmo Round Robin.  

`proxy_set_header Host $host;` --> Conserva y reenvía la cabecera original `Host` solicitada por el cliente.  

`proxy_set_header X-Real-IP $remote_addr;` --> Pasa al servidor backend la dirección IP real del cliente que realiza la petición.  

`proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;` --> Añade la IP del cliente a la lista de proxies por los que ha pasado la petición.  

`proxy_set_header X-Forwarded-Proto $scheme;` --> Informa al servidor backend de si la petición original llegó por `http` o por `https`.  

`}` --> Cierra el bloque `location`.  

`}` --> Cierra el bloque `server`.  

`EOF` --> Marca el final del bloque de configuración en `/etc/nginx/sites-available/balanceador`.  

`rm -f /etc/nginx/sites-enabled/default` --> Elimina el enlace simbólico del sitio web por defecto de Nginx.  

`ln -s /etc/nginx/sites-available/balanceador /etc/nginx/sites-enabled/` --> Crea el enlace simbólico en `sites-enabled` para activar la configuración del balanceador.  

`nginx -t` --> Comprueba que la sintaxis de los archivos de configuración de Nginx no contiene errores.  

`service nginx restart` --> Reinicia Nginx para poner en marcha el balanceador de carga.  

`iptables -A INPUT -i lo -j ACCEPT` --> Permite el tráfico interno de la interfaz local (`loopback`).  

`iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT` --> Permite el tráfico de conexiones ya establecidas o relacionadas.  

`iptables -A INPUT -p tcp --dport 22 -j ACCEPT` --> Permite el acceso SSH puerto 22.  

`iptables -A INPUT -p tcp --dport 80 -j ACCEPT` --> Permite el tráfico web HTTP puerto 80 desde el exterior.  

`iptables -A INPUT -p tcp --dport 443 -j ACCEPT` --> Permite el tráfico web seguro HTTPS puerto 443 desde el exterior.  

`iptables -P INPUT DROP` --> Establece la política por defecto de entrada en DROP para bloquear cualquier otro puerto distinto de 22, 80 y 443.  

`netfilter-persistent save` --> Guarda las reglas del cortafuegos de forma permanente.  


### 2.5. Dominio en DuckDNS y Certificado SSL con Certbot y Let's Encrypt  

1. Se registra el subdominio gratuito `franciscojavierdiaz.duckdns.org` en la plataforma DuckDNS.

      ![Dominio DuckDNS](imagenes/Captura%20de%20pantalla_8.png)
   
2. Dado que el entorno Killercoda utiliza un proxy dinámico para el tráfico web entrante, se solicita el certificado SSL/TLS dentro del contenedor del balanceador mediante Certbot empleando el desafío DNS (`DNS-01`)
   
`certbot certonly --manual --preferred-challenges dns -d franciscojavierdiaz.duckdns.org` --> Solicita únicamente la emisión del certificado (`certonly`) de forma manual (`--manual`) validando la propiedad mediante un registro DNS (`--preferred-challenges dns`) para el dominio `franciscojavierdiaz.duckdns.org`.  

   ![Dominio DuckDNS](imagenes/Captura%20de%20pantalla_9.png)

3. Se crea el registro `TXT` `_acme-challenge.franciscojavierdiaz.duckdns.org` en DuckDNS con el token facilitado por Certbot, generando los certificados válidos emitidos por **Let's Encrypt** en `/etc/letsencrypt/live/franciscojavierdiaz.duckdns.org/`.
   
4. Finalmente, se añade en `/etc/nginx/sites-available/balanceador` el bloque servidor HTTPS para cifrar las conexiones:
   
`listen 443 ssl;` --> Habilita la escucha de conexiones seguras HTTPS en el puerto `443` utilizando SSL/TLS.  

`server_name franciscojavierdiaz.duckdns.org;` --> Asocia este servidor virtual al dominio certificado.  

`ssl_certificate /etc/letsencrypt/live/franciscojavierdiaz.duckdns.org/fullchain.pem;` --> Indica la ruta del certificado público y la cadena de confianza emitida por Let's Encrypt.  

`ssl_certificate_key /etc/letsencrypt/live/franciscojavierdiaz.duckdns.org/privkey.pem;` --> Indica la ruta de la clave privada asociada al certificado.  

`location / { proxy_pass http://backend_webs; ... }` --> Redirige todo el tráfico HTTPS descifrado hacia los servidores backend `Web1` y `Web2`.  

`service nginx reload` --> Recarga la configuración de Nginx sin interrumpir el servicio para activar el certificado SSL.  

  ![Dominio DuckDNS](imagenes/Captura%20de%20pantalla_7.png)

## 3. Comprobaciones y Capturas de Pantalla  

### 3.1. Estado general del escenario (`vagrant status`)  
Se comprueba que las cuatro instancias (`base_datos`, `web1`, `web2` y `balanceador`) se encuentran levantadas y en ejecución simultánea  

![Estado general Vagrant](imagenes/Captura%20de%20pantalla_1.png)  

### 3.2. Capa 3 - Base de Datos (`FranciscoJavierDiazGarronBBDD`)  
Se verifica que el servicio MariaDB está activo y que iptables mantiene la política DROP, aceptando conexiones al puerto 3306 únicamente desde Web1 172.20.2.21 y Web2 172.20.2.22`  

![Estado Base de Datos](imagenes/Captura%20de%20pantalla_3.png)  

### 3.3. Capa 2 - Servidores Web (`Web1` y `Web2`)  
Se comprueba que tanto FranciscoJavierDiazGarronWeb1 como FranciscoJavierDiazGarronWeb2 tienen Apache2 corriendo y restringen el acceso al puerto 80 exclusivamente a la IP del balanceador 172.20.1.10  

![Estado Servidores Web](imagenes/Captura%20de%20pantalla_4.png)  

### 3.4. Capa 1 - Balanceador (`Nginx`) y Aislamiento de Internet  
Se verifica que Nginx está activo en FranciscoJavierDiazGarronBalanceador con los puertos 22, 80 y 443 abiertos  

![Estado Balanceador Nginx](imagenes/Captura%20de%20pantalla_5.png)  

Además, se comprueba mediante ip route en la base de datos que no dispone de puerta de enlace por defecto, demostrando que está totalmente aislada de Internet  

![Aislamiento de Internet](imagenes/Captura%20de%20pantalla_6.png)  

### 3.5. Funcionamiento del Balanceo de Carga (Round Robin)
Al realizar dos peticiones HTTP consecutivas al balanceador (`http://localhost:8080`), se comprueba cómo alterna automáticamente entre Servidor Web 1 y Servidor Web 2  

![Prueba Balanceo de Carga](imagenes/Captura%20de%20pantalla_2.png)

---

## 4. Screencast de Demostración

Y para acabar en el siguiente video se puede observar que los servidores funcionan porque nos aparece la aplicación y su funcionamiento añadiendo un registro guardandolo mostrando que también funciona la base de datos y como se elimina el registro.  

https://github.com/user-attachments/assets/ef88e21e-1090-40c0-9bc7-74311bc90e3d
