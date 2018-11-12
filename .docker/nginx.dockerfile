# We use nginx, apache is also possible
FROM nginx:1.10

# Define the vhost config
ADD vhost.conf /etc/nginx/conf.d/default.conf

COPY . ./
