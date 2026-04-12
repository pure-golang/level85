#!/bin/bash

# Функция для обработки каждого репозитория
process_repo() {
    echo "Processing repository: $1"
    cd "$1"
    git config user.name "aka"
    git config user.email "andrew.kachanov@gmail.com"
    cd ..
}

# Обход всех папок в текущем каталоге
for dir in ./*/
do
    # Проверка, является ли папка репозиторием Git
    if [ -d "$dir/.git" ]
    then
        process_repo "$dir"
    fi
done
