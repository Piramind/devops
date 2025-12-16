#!/bin/bash
# Путь к файлу со списком сервисов
INPUT_FILE="services.txt"
# Имя репозитория (например my-registry.local/project)
REPO_NAME="your_repo_name"
# Имя пользователя/группы для chown
OWNER="your_username:your_username"

# Проверяем, что файл существует
if [ ! -f "$INPUT_FILE" ]; then
    echo "File $INPUT_FILE not found!"
    exit 1
fi

# Чтение файла построчно
while IFS= read -r line; do
    # Пропуск пустых строк
    [[ -z "$line" ]] && continue

    # Разделяем строку вида service:version
    SERVICE=$(echo "$line" | cut -d':' -f1)
    VERSION=$(echo "$line" | cut -d':' -f2)

    IMAGE="${REPO_NAME}/${SERVICE}:${VERSION}"
    OUTPUT="${SERVICE}_${VERSION}.tar"

    echo "Saving $IMAGE -> $OUTPUT"
    docker save "$IMAGE" -o "$OUTPUT"
    # Присвоение владельца файлу
    echo "Setting owner $OWNER for $OUTPUT"
    chown "$OWNER" "$OUTPUT"

done < "$INPUT_FILE"
