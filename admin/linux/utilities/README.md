# Admin Mods Upload

Скрипт для загрузки модов на сервер TES3MP.

## Как настроить

### 1. Отредактируйте конфиг

```bash
nano admin/linux/utilities/tes3mp-mods-upload.conf
```

### 2. Настройте SSH (чтобы работало `ssh tes3mp-server`)

Добавьте в `~/.ssh/config` (подставьте свой IP):

```
Host tes3mp-server
    HostName <ip-адрес сервера>
    User <имя пользователя на сервере>
```

Настройте ключ (потребуется пароль от сервера):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" && ssh-copy-id tes3mp-server
```

### 3. Запустите

```bash
./admin/linux/utilities/tes3mp-mods-upload
```

## Переменные конфига

| Переменная | Описание                        | Пример                    |
|------------|---------------------------------|---------------------------|
| `SSH_HOST` | SSH-хост (алиас или user@ip)    | `tes3mp-server`           |
| `MODS_DIR` | Путь к локальной папке с модами | `/home/user/tes3mp-mods`  |