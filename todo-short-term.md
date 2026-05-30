# План: Разделить экспорт/импорт мира на players + cells

## Мотивация
Объединение player и cell в один `world.tar.gz` было ошибкой. Нужно иметь возможность импортировать/экспортировать персонажей независимо от ячеек (например, перенести игроков с другого сервера, не трогая мир).

## Форматы архивов

### `players.tar.gz`
```
players.tar.gz
└── player/
    └── AccountName1.json
```

### `cells.tar.gz`
```
cells.tar.gz
└── cell/
    └── -1_-2.json
```

### `world.tar.gz` (остаётся как combined)
```
world.tar.gz
├── player/
│   └── AccountName1.json
└── cell/
    └── -1_-2.json
```

---

## Шаги реализации

### 1. `server_setup/scripts/package.sh`
- [ ] Добавить `package_players(output_file)` — упаковка только `player/`
- [ ] Добавить `package_cells(output_file)` — упаковка только `cell/`
- [ ] `package_world()` переписать через вызов `package_players()` + `package_cells()` (чтобы не дублировать логику)

### 2. `server_setup/scripts/import_players.sh` (новый)
- [ ] Принимает `players.tar.gz` из `/tes3mp-easy/import-players/`
- [ ] Бэкапит текущих игроков через `package_players()`
- [ ] Распаковывает в `container-data/server/data/player/`
- [ ] **НЕ останавливает TES3MP** (игроков можно добавлять на горячую)
- [ ] Очищает `import-players/`

### 3. `server_setup/scripts/import_cells.sh` (новый)
- [ ] Принимает `cells.tar.gz` из `/tes3mp-easy/import-cells/`
- [ ] Бэкапит текущие cell через `package_cells()`
- [ ] **Останавливает TES3MP** (ячейки менять на горячую нельзя/рискованно)
- [ ] Распаковывает в `container-data/server/data/cell/`
- [ ] Запускает TES3MP
- [ ] Очищает `import-cells/`

### 4. `server_setup/scripts/import_world.sh` (рефакторинг)
- [ ] Использовать `package_players()` + `package_cells()` для бэкапов
- [ ] Останавливает TES3MP
- [ ] Распаковывает world.tar.gz
- [ ] Запускает TES3MP

### 5. `server_setup/scripts/install.sh`
- [ ] Добавить `import_players.sh` и `import_cells.sh` в загрузку

### 6. `tools/linux/tes3mp-easy-export.conf`
- [ ] Разделить `WORLD_DIR` на две отдельные переменные:
  ```ini
  [world]
  PLAYER_DIR=/home/user/tes3mp-world/player
  CELL_DIR=/home/user/tes3mp-world/cell
  ```

### 7. Клиентские утилиты

#### `tools/linux/tes3mp-easy-export-world` (изменить)
- [ ] Иcпользовать `PLAYER_DIR` + `CELL_DIR` из конфига вместо `WORLD_DIR`
- [ ] source package.sh, упаковка через `package_world()`

#### `tools/linux/tes3mp-easy-export-players` (новый)
- [ ] Читает `PLAYER_DIR` из конфига
- [ ] source package.sh, упаковка через `package_players()`
- [ ] SCP на сервер в `/tes3mp-easy/import-players/`
- [ ] SSH `bash scripts/import_players.sh`

#### `tools/linux/tes3mp-easy-export-cells` (новый)
- [ ] Читает `CELL_DIR` из конфига
- [ ] source package.sh, упаковка через `package_cells()`
- [ ] SCP на сервер в `/tes3mp-easy/import-cells/`
- [ ] SSH `bash scripts/import_cells.sh`

### 8. `docs/admin/management.md`
- [ ] Добавить в таблицу: export-players, export-cells, импорт соответствующих

### 9. Удалить старые
- [ ] Удалить `import_world.sh` (заменяется новым) — а, нет, он остаётся как combined, просто рефакторим
- [ ] (ничего не удаляем, import_world.sh остаётся)