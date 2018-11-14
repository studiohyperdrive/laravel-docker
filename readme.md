## Voorbeeld laravel project met docker setup

> Bekijk de demo hier: http://imd-docker.studiohyperdrive.be/

Op 16 november waren we te gast bij de opleiding [Interactieve multimedia design](https://weareimd.be/) van de Thomas More hogeschool in Mechelen voor een gastles Docker. 

Doel van de gastles: een docker setup die de studenten toelaat lokaal een laravel applicatie te ontwikkelen m.b.v. Docker en hun applicatie op een server te deployen m.b.v. Docker.

### Voor dat je begint...

Zorg ervoor dat je Docker geinstalleerd hebt op je systeem. Dat kan je [hier](https://www.docker.com/get-started) doen... Is docker echt volledig nieuw? Check de website van [iamgoodbytes](https://github.com/iamgoodbytes): [dockerleren.be](https://www.dockerleren.be/) of [onze presentatie](https://studiohyperdrive.be) van de gastles. 

### Hoe zijn we begonnen aan deze setup? 

We hebben lokaal geen PHP of andere dependencies geinstalleerd behalve Docker, we zijn dus volledig afhankelijk van de kracht van Docker. 

We zijn gestart met een lege folder waarin we volgend commando uitgevoerd hebben:

```
$ docker run --rm -v $(pwd):/app composer:1.7 create-project --prefer-dist laravel/laravel myproject
```

Door composer in een Docker container te runnen met als image `composer:1.7`, hoeven we `composer` niet lokaal op ons systeem te installeren. 

- De `--rm` vlag zorgt ervoor dat de container na het uitvoeren direct opgeruimd wordt, zo blijven er geen onnodige containers op ons systeem achter.  
- `-v $(pwd):/app` gebruiken we om de huidige directory te mounten in de `app` folder van de Docker container en zorgt ervoor dat de changes in de Docker container zichtbaar zijn op onze lokale toestel.  
- `composer:1.7` is de image die we gebruiken voor onze container
- `create-project` is het composer commando voor het maken van een nieuw project  
Met het laatste argument `laravel/laravel myproject` geven we aan dat we een laravel applicatie willen maken met myproject als naam. 

Als alles goed gegaan is, staat er nu een nieuwe Laravel installatie klaar. 

### Opzetten van de Docker setup 

Onze Laravel applicatie heeft drie onderdelen nodig om te kunnen werken: 
1) Uiteraard PHP om de PHP code uit te voeren. 
2) Een database, bijvoorbeeld MySQL.
3) En tenslotte hebben we gekozen voor nginx als webserver.

Aangezien elke docker-container maar één verantwoordelijk mag hebben komen deze drie benodigdheden overeen met drie docker-containers die we gaan definiëren in onze docker-compose file. 

### De docker-compose.yml file

We starten van versie 3 en voegen een aantal services toe: 

```
version: '3'
services:
```

Als eerste service voegen we PHP toe:
```
services:
  php:
    build:
      context: ./
      dockerfile: .docker/php.dockerfile
    working_dir: /var/www
    volumes:
      - ./:/var/www
    environment:
      - "DB_PORT=3306"
      - "DB_HOST=mysql"
```

Onder het `build` niveau beschrijven we welke Docker file de service moet gebruiken. Onze PHP service zal gebruik maken van een Docker file die we in de volgende stappen zelf gaan opbouwen.

In de sectie `volumes` bepalen we dat onze huidige folder `./` gemount moet worden naar de `/var/www` folder in onze Docker container zodat de PHP engine onze files kan vinden. 

Ten slotte kunnen we via de `environment` parameter ook een aantal configuratie variabelen overschrijven die normaal in de `.env` file staan.


Als tweede service nginx:
```
  nginx:
    build:
      context: ./
      dockerfile: .docker/nginx.dockerfile
    working_dir: /var/www
    volumes:
      - ./:/var/www
    ports:
      - 8080:80
```

De setup is gelijkaardig aan de PHP service, maar we gebruiken een andere Docker file die we ook zullen aanmaken in de volgende stappen. 
Daarnaast configureren we via de `ports` parameter dat het process dat op poort 80 draait in onze Docker container (=nginx) doorgestuurd moet worden naar poort 8080 op onze hostmachine. Hierdoor kunnen we op onze lokale machine surfen naar http://localhost:8080 

En als laatste voegen we ook MySQL toe aan onze services
```
  mysql:
    image: mysql:5.7
    volumes:
      - dbdata:/var/lib/mysql
    environment:
      - "MYSQL_DATABASE=studiohyperdrive"
      - "MYSQL_USER=studiohyperdrive"
      - "MYSQL_PASSWORD=secret"
      - "MYSQL_ROOT_PASSWORD=secret"
    ports:
        - "33061:3306"

volumes:
  dbdata:
```
In tegenstelling tot de andere twee services gaan we hier niet zelf een Docker file aanmaken maar maken we rechtsreeks gebruik van een de MySQL image die beschikbaar is via de Docker hub. We laten Docker ook weten dat we een specifiek volume voorzien voor onze database data zodat we de data niet steeds verliezen als we onze Docker containers opnieuw op starten. 

### Productie: docker.compose.ci.yml

Voor op onze servers (dev, acc, prod, ... omgevingen) maken we een `docker.compose.ci.yml` file aan. Deze docker-compose file zal bij ons intern gebruikt worden door de CI tool (bijvoorbeeld Circle CI, travis of bitbucket pipelines) voor het builden van de services en nadien voor het deployen en opstarten. `docker.compose.ci.yml` neemt standaard alle waarden over van de van `docker.compose.yml` we hoeven de configuratie voor de services dus niet opnieuw te herhalen behalve de zaken die we willen aanpassen. We laten nginx nu bijvoorbeeld doorverwijzen naar poort 80, ipv poort 8080 lokaal.

Als je de setup wilt opstarten of stoppen a.d.h.v. deze setup, moet je docker starten met:
```
$ docker-compose -f docker-compose.ci.yml up
$ docker-compose -f docker-compose.ci.yml stop
```

### Aanmaken van de Dockerfile(s)

We groeperen de Docker files in een mapje `.docker`. 

De eerste Dockerfile die we maken is: `nginx.dockerfile`

```
# We use nginx, apache is also possible
FROM nginx:1.10

# Define the vhost config
ADD vhost.conf /etc/nginx/conf.d/default.conf
```
We geven aan dat onze image moet starten vanaf de `nginx:1.10` image en dat we het bestand `vhost.conf` in onze folder (zie onder) willen kopieren naar `/etc/nginx/conf.d/default.conf` in de nginx Docker container. 

De vhost file ziet er zo uit:
```
server {
    listen 80;
    index index.php index.html;
    root /var/www/public;

    location / {
        try_files $uri /index.php?$args;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }
}
```
Bekijk zeker de documentatie van nginx even als je exact wilt weten wat hier gebeurt. Wat voor docker belangrijk is, zijn volgende regels: 

```
location ~ \.php$ {
  ...
  fastcgi_pass php:9000;
  ...
}
```

Hier zeggen we dat nginx alle .php bestanden moet laten uitvoeren door `php:9000`. Als we deze string ontleden komen we uit op: `php` en `9000`. `php` is de naam van de service die we in de compose file gebruikt hebben en `9000` is de poort waar de PHP service op draait. Docker-compose herkent deze benaming en weet op die manier de requests juist door te sturen naar de verschillende containers. 

Ten slotte maken we de `php.dockerfile` 
```
# Stage 1: Build with composer
FROM composer:1.7 as builder

WORKDIR /var/www
COPY . ./

RUN composer install

# Stage 2: use php 7!
FROM php:7.2-fpm as server

# just the basics needed for a typical Laravel CRUD app 
RUN apt-get update && apt-get install -y libmcrypt-dev \
    mysql-client --no-install-recommends \
    && pecl install mcrypt-1.0.1 \
    && docker-php-ext-enable mcrypt \
    && docker-php-ext-install pdo_mysql

# use build from stage 1
COPY --from=builder /var/www /var/www
```

Deze dockerfile ziet er iets anders uit dan de vorige aangezien we hier starten vanaf twee verschillende base-images. Dit noemen we een multi-stage Dockerfile.

In de eerste stage kiezen we ervoor om te starten vanaf de `composer` stage en we geven deze stage de naam `builder`. Met het `WORKDIR /var/www` commando geven we aan in welke folder we willen werken (`/var/www`). En met het `COPY . ./` commando geven we aan dat we alle files van onze host (onze laravel app) willen kopiëren naar de workdir (`/var/www`). 

Ten slotte starten we het `composer install` commando door `RUN composer install` toe te voegen aan de Dockerfile.

In de tweede stage geven we opnieuw aan dat we willen starten vanaf specifieke image, deze keer vanaf `php:7.2-fpm`. Daarnaast installeren we ook een aantal PHP dependencies die Laravel zal nodig hebben. Met `COPY --from=builder /var/www /var/www` zeggen we dat we de `/var/www` uit de `builder container` willen kopiëren naar de huidige container zodat we alle files hebben die composer daarnet aangemaakt heeft. 

De laatste stage van een multi-stage Dockerfile is het script / de software dat zal draaien in de uiteindelijke container. 

Door nu `docker-compose up` uit te voeren, zullen alle containers opgestart worden. 

### Laravel commando's uitvoeren

Als we onze Laravel applicatie de eerste keer starten moeten we een aantal commando's uitvoeren. Een commando uitvoeren in Docker is heel gemakkelijk door `docker-compose exec [service-naam] [command]` uit te voeren. 

Bijvoorbeeld voor onze PHP service: 

Bijvoorbeeld:
```
docker-compose exec php [command]
```

Als je de applicatie voor de allereerste keer start, voer je best deze commando's uit: 
```
docker-compose exec php php artisan key:generate
docker-compose exec php php artisan optimize
docker-compose exec php php artisan migrate --seed
```

Het commando in detail: `php php artisan key:generate`
`php` = de service naam
`php artisan key:generate` het commando dat we willen uitvoeren in de service
 
Nadien kan je ook nog steeds commando's gebruiken, bijvoorbeeld voor het maken van een nieuwe controller:
`docker-compose exec php php artisan make:controller MyController`

### Project starten en stoppen
- Start: `docker-compose up`
- Stop: `docker-compose stop`

### Laravel applicatie voor de eerste keer opstarten
- Zorg ervoor dat je een `.env` file aanmaakt vanaf de `.env.example` file
- Zorg ervoor dat `composer install` uitegevoerd is (normaal gezien doet het docker script dat)
- Zorg ervoor dat eventuele seeds / migraties uitgevoerd worden (dit kan een post-deploy hook zijn in een CI tool)
