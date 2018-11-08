## Voorbeeld laravel project met docker setup

Op 16 november waren we te gast bij de opleiding [Interactieve multimedia design](https://weareimd.be/) van de Thomas More hogeschool in Mechelen voor een gastles Docker. 

Doel van de gastles: een docker setup die de studenten toelaat lokaal een laravel applicatie te ontwikkelen m.b.v. Docker en hun applicatie op een server te deployen m.b.v. Docker.

### Voor dat je begint...

Zorg ervoor dat je Docker geinstalleerd hebt op je systeem. Dat kan je [hier](https://www.docker.com/get-started) doen... Is docker echt volledig nieuw?Check de website van [iamgoodbytes](https://github.com/iamgoodbytes) [dockerleren.be](https://www.dockerleren.be/) of [onze presentatie](https://studiohyperdrive.be) van de gastles. 

### Hoe zijn we begonnen aan deze setup? 

We hebben lokaal geen PHP of andere dependencies geinstalleerd behalve Docker, we zijn dus volledig afhankelijk van de kracht van Docker. 

We zijn gestart met een lege folder waarin we volgend commando uitgevoerd hebben:

```
$ docker run --rm -v $(pwd):/app composer/composer create-project --prefer-dist laravel/laravel myproject
```

Door composer in een Docker container te runnen met als image `composer`, hoeven we `composer` niet lokaal op ons systeem te installeren. 

De `--rm` vlag zorgt ervoor dat de container na het uitvoeren direct opgeruimd wordt, zo blijven er geen onnodige containers op ons systeem achter. 
`-v $(pwd):/app` gebruiken we om de huidige directory te mounten in de `app` folder van de Docker container en zorgt ervoor dat de changes in de Docker container zichtbaar zijn op onze lokale toestel. 
`composer/composer create-project` is het composer commando voor het maken van een nieuw project
Met het laatste argument `laravel/laravel myproject` geven we aan dat we een laravel applicatie willen maken met myproject als naam. 

Als alles goed gegaan is, staat er nu een nieuwe Laravel installatie klaar. 

### Opzetten van de Docker setup 

Onze Laravel applicatie heeft drie onderdelen nodig om te kunnen werken: 
1) Uiteraard PHP om de PHP code uit te voeren. 
2) MySQL als database.
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
In tegenstelling tot de andere twee services gaan we hier niet zelf een Docker file aanmaken maar maken we rechtsreeks gebruik van een de MySQL image die beschikbaar is via de Docker hub. We laten Docker ook weten dat we een specifiek volume voorzien voor onze database data zodat we de data niet telkens kwijt spelen als we onze Docker containers opnieuw op starten. 

### Aanmaken van de Dockerfile(s)

We groeperen de Docker files in een mapje `.docker`. 

De eerste Dockerfile die we maken is: `nginx.dockerfile`

```
# We use nginx, apache is also possible
FROM nginx:1.10

# Define the vhost config
ADD vhost.conf /etc/nginx/conf.d/default.conf
```
We geven aan dat onze image moet starten vanaf de `nginx:1.10` image en dat we het bestand `vhost.conf` in onze folder (zie repository) willen kopieren naar `/etc/nginx/conf.d/default.conf` in de nginx Docker container. 

Ten slotte maken we de `php.dockerfile` 
```
# Use php 7!
FROM php:7.2-fpm

# just the basics needed for a typical Laravel CRUD app 
RUN apt-get update && apt-get install -y libmcrypt-dev \
    mysql-client --no-install-recommends \
    && pecl install mcrypt-1.0.1 \
    && docker-php-ext-enable mcrypt \
    && docker-php-ext-install pdo_mysql
```
We geven opnieuw aan dat we willen starten van specifieke image, deze keer vanaf `php:7.2-fpm`. Daarnaast installeren we ook een aantal PHP dependencies die Laravel zal nodig hebben. 

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
`php` = de sercice naam
`php artisan key:generate` het commando dat we willen uitvoeren in de service
 
Nadien kan je ook nog steeds commando's gebruiken, bijvoorbeeld voor het maken van een nieuwe controller:
`docker-compose exec php php artisan make:controller MyController`

### Project starten en stoppen
Start: `docker-compose up`
Stop: `docker-compose stop`
