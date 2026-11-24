#!/bin/bash

## Variables

PROJECT_NAME=$(basename "$PWD") ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
PROJECT_GROUPS=$({ id -G; stat -c %g /dev/dri/* /dev/kvm /dev/snd/*; } 2>/dev/null | tr ' ' '\n' | sort -un \
    | sed "/^0\?$/d; /^$PROJECT_GID$/d" | sed 's/.*/\\n\\1    - "&"/' | tr -d '\n') ## your groups and those of the GPU, KVM and sound devices, as group_add lines for composehack
USER=django

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans

    find . -mindepth 1 -maxdepth 1 \
        | sed "
            /Dockerfile/d;
            /project.sh/d;
            /README.md/d;
        " \
        | xargs -I {} rm -rf {}

}

compose() {

    if [[ ! -f docker-compose.yml ]]; then
        cat << EOF > docker-compose.yml
services:
    adminer:
        image: adminer:6.3.1
        environment:
            ADMINER_DEFAULT_SERVER:     database
        ports:
            - 8080:8080
        depends_on:
            - database

    database:
        image: postgres:19.0
        volumes:
            - db_data:/var/lib/postgresql
        environment:
            POSTGRES_DB:                $PROJECT_NAME
            POSTGRES_USER:              $PROJECT_NAME
            POSTGRES_PASSWORD:          $PROJECT_NAME
        healthcheck:
            test: [ CMD, pg_isready, -U, $PROJECT_NAME, -d, $PROJECT_NAME ]
            interval: 5s
            timeout: 5s
            retries: 30

    django:
        build: .
        working_dir: /home/$USER
        volumes:
            - .:/home/$USER
        command: [ python, manage.py, runserver, 0.0.0.0:8000 ]
        ports:
            - 8000:8000
        environment:
            HOME:                       /home/$USER
            DATABASE_HOST:              database
            DATABASE_NAME:              $PROJECT_NAME
            DATABASE_USER:              $PROJECT_NAME
            DATABASE_PASSWORD:          $PROJECT_NAME
        depends_on:
            database:
                condition: service_healthy

volumes:
    db_data:
EOF
    fi

}

composehack() {

    if ! grep -q "user\:" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID${PROJECT_GROUPS:+\n\1group_add\:$PROJECT_GROUPS}\n\1@}" docker-compose.yml
    fi

}

gitignore() {

    if [[ ! -f .gitignore ]]; then
        cat << EOF > .gitignore
## Docker related

/docker-compose.yml

## Python related

/.cache
/.venv
__pycache__/
*.py[cod]

## Django related

/db.sqlite3
/media
/staticfiles
EOF
    fi

}

django() {

    if [[ ! -f requirements.txt ]]; then
        cat << EOF > requirements.txt
Django
psycopg[binary]
EOF
    fi

    docker compose run --rm --no-deps django sh -c " \
        [ -d .venv ] || python3 -m venv .venv \
        && pip install --upgrade pip \
        && pip install -r requirements.txt"

    if [[ ! -f manage.py ]]; then

        docker compose run --rm --no-deps django django-admin startproject config .

        cat << 'EOF' >> config/settings.py


# Settings for the services in docker-compose.yml

import os  # noqa: E402

ALLOWED_HOSTS = ['localhost', '127.0.0.1', '[::1]']

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'HOST': os.environ['DATABASE_HOST'],
        'NAME': os.environ['DATABASE_NAME'],
        'USER': os.environ['DATABASE_USER'],
        'PASSWORD': os.environ['DATABASE_PASSWORD'],
    }
}
EOF

    fi

    docker compose run --rm django python manage.py migrate
    docker compose run --rm django python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='$PROJECT_NAME').exists():
    User.objects.create_superuser('$PROJECT_NAME', 'foo@bar.com', '$PROJECT_NAME')
    print('Created superuser $PROJECT_NAME')
"
    docker compose run --rm django python manage.py test

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    gitignore
    django

    docker compose up -d && \
    echo "Site: http://localhost:8000  Admin: http://localhost:8000/admin  Adminer: http://localhost:8080"

}

"$1"
