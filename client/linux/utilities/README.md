# Client Mods Download

Скрипт для автоматической загрузки и установки модов с сервера TES3MP.

## Файлы

- `tes3mp-mods-download` — скрипт для скачивания модов с сервера
- `tes3mp-mods-download.conf` — пример конфигурации

## Как настроить

### 1. Скопируйте конфиг

```bash
mkdir -p ~/.config/tes3mp
cp client/linux/utilities/tes3mp-mods-download.conf ~/.config/tes3mp/
```

### 2. Отредактируйте конфиг

```bash
nano ~/.config/tes3mp/tes3mp-mods-download.conf
```

Укажите правильные пути для вашей системы:

| Переменная         | Описание                                                               | Пример                                       |
|--------------------|------------------------------------------------------------------------|----------------------------------------------|
| `CLIENT_DEFAULT`   | Путь к `tes3mp-client-default.cfg` (берётся оттуда hostname сервера)   | `/home/user/Games/tes3mp/tes3mp-client-default.cfg` |
| `DATA_FILES`       | Путь к папке Data Files OpenMW                                         | `/home/user/Games/OpenMW/Data Files`         |
| `OPENMW_CFG`       | Путь к `openmw.cfg`                                                    | `/home/user/.config/openmw/openmw.cfg`       |

### 3. Запустите скрипт

```bash
./client/linux/utilities/tes3mp-mods-download
```

Скрипт:
1. Скачивает архив модов с сервера (порт 8085)
2. Удаляет старые моды из Data Files (оригинальные файлы Morrowind сохраняются)
3. Распаковывает новые моды
4. Добавляет `include = mods.cfg` в `openmw.cfg`, если его там нет

## Зависимости

- `bash`, `curl`, `unzip`

## Как это работает

Скрипт читает `hostname` из `tes3mp-client-default.cfg` и скачивает моды по адресу:

```
http://<hostname>:8085/get-mods
```

Этот endpoint предоставляется nginx-контейнером на сервере TES3MP.