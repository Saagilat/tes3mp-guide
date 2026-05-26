# Client Mods Download

Скрипт для автоматической загрузки и установки модов с сервера TES3MP.

## Как настроить

### 1. Отредактируйте конфиг

```bash
nano client/linux/utilities/tes3mp-mods-download.conf
```

Укажите правильные пути для вашей системы:

| Переменная         | Описание                                                             | Пример                                       |
|--------------------|----------------------------------------------------------------------|----------------------------------------------|
| `CLIENT_DEFAULT`   | Путь к `tes3mp-client-default.cfg` (оттуда берётся hostname сервера) | `/home/user/Games/tes3mp/tes3mp-client-default.cfg` |
| `DATA_FILES`       | Путь к папке Data Files OpenMW                                       | `/home/user/Games/OpenMW/Data Files`         |
| `OPENMW_CFG`       | Путь к `openmw.cfg`                                                  | `/home/user/.config/openmw/openmw.cfg`       |

### 2. Запустите

./client/linux/utilities/tes3mp-mods-download
```
