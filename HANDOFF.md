# Fixdock handoff

## Цель

Сделать Fixdock утилитой, которая закрепляет Dock на выбранном пользователем экране и умеет переключать выбранный экран без использования физического курсора как механизма переноса.

Старый курсорный перенос технически работал, но UX неприемлемый: пользователь работает, а курсор внезапно прыгает к краю монитора и обратно. Это раздражает и ощущается как поломка управления. Этот подход запрещён.

## Критическое правило: курсор нельзя дёргать

Это жёсткое ограничение проекта.

Запрещено:

- программно перемещать видимый курсор для переноса Dock;
- использовать `CGWarpMouseCursorPosition`;
- скрывать курсор через `NSCursor.hide()` ради незаметного переноса;
- постить synthetic mouse move/edge events как механизм переноса Dock;
- возвращать курсор “обратно” после программного переноса;
- добавлять такой механизм в production, debug flag или эксперимент без явного отдельного разрешения пользователя.

Если очередная гипотеза требует движения физического курсора, считать её непригодной и не реализовывать.

## Текущее состояние проекта

Путь проекта:

```bash
/Users/vitalyterenin/Projects/Personal/Fixdock
```

Установленное приложение:

```text
/Users/vitalyterenin/Applications/Fixdock.app
```

Bundle id:

```text
local.vitalyterenin.Fixdock
```

Сборка и установка:

```bash
cd /Users/vitalyterenin/Projects/Personal/Fixdock
Scripts/install-app.sh
```

Основные файлы:

- `Sources/Fixdock/AppDelegate.swift` — menu bar UI, выбор экрана, orchestration
- `Sources/Fixdock/MouseEdgeGuard.swift` — Accessibility event tap, гасит edge-жест Dock на невыбранных экранах
- `Sources/Fixdock/DockSystemController.swift` — работа с `com.apple.dock allow-display-switching`
- `Sources/Fixdock/DisplayManager.swift` — список экранов и их координаты
- `Experiments/SkyLightDockDisplaySwitch/` — отдельный Swift CLI для проверки приватных SkyLight/CoreGraphics Services гипотез
- `Experiments/DockSidecarProbe/` — отдельный Swift CLI для проверки XPC endpoint `com.apple.dock.sidecar`

Обновление 2026-05-01T23:00:30+02:00:

- Production-код больше не запускает `DockRelocator` автоматически при старте, выборе экрана или изменении экранов.
- Если Dock ещё не на выбранном экране, меню теперь показывает fallback-инструкцию: подвести курсор к краю выбранного экрана один раз.
- `Sources/Fixdock/DockRelocator.swift` удалён из production target.
- `DockSystemController` больше не содержит `killall Dock`; приложение пишет `allow-display-switching` без перезапуска Dock и постит `com.apple.dock.prefchanged`.
- `DockSystemController.currentDockDisplayID` теперь сначала читает Dock rect через `SLSGetDockRectWithOrientation`, а `CGWindowListCopyWindowInfo` оставлен fallback-источником.
- Добавлен эксперимент `Experiments/SkyLightDockDisplaySwitch`, который печатает managed displays, current spaces, Dock windows, Dock rect, role windows, cursor before/after и умеет выполнять guarded write-тесты только с `--apply`.

Обновление 2026-05-01T23:25:00+02:00:

- `Experiments/SkyLightDockDisplaySwitch` расширен флагом `--test-dock-rect-reason`.
- `SLSGetDockRectWithReason` подтверждён с сигнатурой `(CGSConnectionID, CGRect*, Int32*) -> Int32`.
- `SLSSetDockRectWithReason` подтверждён с сигнатурой `(CGSConnectionID, CGRect, Int32) -> Int32`; он меняет Dock rect в WindowServer и успешно восстанавливается, но фактическое окно Dock из `CGWindowListCopyWindowInfo` остаётся на исходном display. Это не решает перенос Dock.
- Добавлен эксперимент `Experiments/DockSidecarProbe` для endpoint `com.apple.dock.sidecar`.
- Наивные XPC-сообщения `getDockDisplay` и `requestDockOnDisplay` с ключами `disp`, `display`, `displayID` получают `XPCErrorDescription = "Connection interrupted"` / `Connection invalid`. Endpoint существует, но нужен reverse фактического протокола или handshake.
- Прямая проверка AX parameterized attribute `NextDockForDisplayID` через system-wide и Dock AX element не дала рабочего пути: получены AX ошибки `-25202` и `-25213`.
- Установленный `DockLock Lite.app` в `/Applications`, `/System/Applications` и `/Users/vitalyterenin/Applications` не найден; prefs `pro.docklock.lite` на машине остаются.

Обновление 2026-05-02T00:02:44+02:00:

- Исправлена production-регрессия: `AppDelegate.updateProtection()` теперь выставляет `com.apple.dock allow-display-switching` до попытки запустить `MouseEdgeGuard`.
- Если Dock уже на выбранном экране, приложение закрепляет его через `allow-display-switching = false` даже без Accessibility-доступа.
- Если выбран другой экран или текущий экран Dock не удалось определить, приложение включает `allow-display-switching = true`, чтобы пользователь не попадал в тупик, где ручной штатный перенос невозможен.
- `DockSystemController.currentDockDisplayID` теперь сначала использует фактическое окно Dock из `CGWindowListCopyWindowInfo`, а SkyLight Dock rect оставлен fallback-источником. Это снижает риск принять stale SkyLight rect за реальное положение Dock.
- Приложение пересобрано и переустановлено в `/Users/vitalyterenin/Applications/Fixdock.app`. Проверено: при `targetDisplayID = 3` после старта `allow-display-switching = 1`, при возврате `targetDisplayID = 1` после старта `allow-display-switching = 0`.

Обновление 2026-05-02T00:08:11+02:00:

- Добавлены unified logs с subsystem `local.vitalyterenin.Fixdock`, category `AppDelegate`: старт, выбор экрана, текущий экран Dock, `allow-display-switching`, состояние `MouseEdgeGuard`.
- Добавлен пункт меню `Открыть Accessibility`, который открывает системные настройки Privacy & Security → Accessibility.
- Диагностика запущенного приложения показала `edgeGuard=false`: текущий `/Users/vitalyterenin/Applications/Fixdock.app` не имеет Accessibility-доступа, поэтому event tap не создаётся и edge-защита не работает.
- Выполнен `tccutil reset Accessibility local.vitalyterenin.Fixdock` и приложение перезапущено. После reset macOS всё равно ждёт ручного разрешения Accessibility для установленного bundle.
- На машине нет стабильного codesigning identity (`security find-identity -v -p codesigning` вернул `0 valid identities found`). Из-за ad-hoc подписи TCC может требовать перевыдать Accessibility после локальных пересборок.

## Что уже известно

Работает:

- `defaults write com.apple.dock allow-display-switching -bool false` закрепляет Dock на текущем экране.
- `defaults write com.apple.dock allow-display-switching -bool true` возвращает штатный перенос Dock между экранами.
- `MouseEdgeGuard` с Accessibility может гасить edge-жест на невыбранных экранах без блокировки всей нижней полосы.

Не подходит:

- Любое решение, где видимый пользовательский курсор прыгает по экрану.
- Любое решение, где приложение двигает/прячет/возвращает курсор даже “быстро” или “незаметно”.
- Фоновый `killall Dock` или перезапуск Dock по таймеру: это вызывает мигание/перерисовку экранов.
- Широкая невидимая edge-полоса поверх экранов: курсор начинает “спотыкаться”.
- UI с отдельными режимами “включить защиту”, “закрепить”, “разрешить перенос”: нужен один контрол, выбор экрана.

Текущее UX-требование:

- В меню остаётся одна настройка: выбор экрана.
- При выборе другого экрана Dock должен оказаться на нём без участия видимого курсора.
- После этого Dock не должен сам переезжать на другие экраны.

## Главная проблема

Публичного API macOS для “поставить Dock на display X” не найдено. Штатный перенос Dock завязан на gesture у края экрана. Старый `DockRelocator` имитировал этот gesture через курсор; этот подход запрещён и удалён из production.

Следующий этап должен найти некурсорный механизм. Нельзя “временно” возвращать курсорный перенос.

## Направление 1: приватные SkyLight/CoreGraphics Services API

Это основной кандидат.

Нужно исследовать приватные символы, связанные с Spaces, displays и Dock:

```bash
strings /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock | rg -i "display|space|dock|switch"
nm -gj /System/Library/PrivateFrameworks/SkyLight.framework/SkyLight 2>/dev/null | rg -i "display|space|dock|managed"
strings /System/Library/PrivateFrameworks/SkyLight.framework/SkyLight | rg -i "display|space|dock|managed"
```

Что искать:

- функции, которые меняют current display/current space;
- функции, связанные с `SLSManagedDisplay`, `CGSSpace`, `DisplaySpaces`;
- внутренний message/API path, который меняет Dock display напрямую без mouse events и без перемещения курсора;
- способ изменить display binding Dock напрямую, если такое состояние хранится в WindowServer/Dock.

В Dock binary уже встречались строки/типы вроде:

- `DisplaySpaces`
- `ManagedDisplayInfo`
- `SLSManagedDisplayIterator`
- `CGSSpace`
- `SpaceSwitcherDisplay`
- `DockImmutabilityPreferences`
- `allow-display-switching`

План эксперимента:

1. Написать отдельный маленький Swift/C эксперимент вне приложения, который вызывает приватные функции через `dlopen`/`dlsym`.
2. Проверять эффект через `CGWindowListCopyWindowInfo`: Dock window bounds должны перейти на frame целевого дисплея.
3. Только после подтверждения переносить в Fixdock.

Критерий успеха:

- Dock переезжает на выбранный экран.
- `CGEvent(source: nil)?.location` до/после не меняется.
- Не происходит `killall Dock`.
- Dock PID не меняется.

Текущие результаты эксперимента:

- `SLSCopyManagedDisplays`, `SLSCopyBestManagedDisplayForRect`, `SLSManagedDisplayGetCurrentSpace`, `SLSManagedDisplaysCopyRoleWindows`, `SLSGetDockRectWithOrientation` и `SLSSetDockRectWithOrientation` успешно резолвятся через `dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight")`.
- На текущей конфигурации экраны:
  - CG display `1`, managed display `37D8832A-2D66-02CA-B9F7-8F30A301B230`, current space `1`.
  - CG display `3`, managed display `A9689BE6-2B12-4CF5-82E5-79D79F20E9B1`, current space `91`.
- `SLSManagedDisplaysCopyRoleWindows` в диапазоне ролей `0...64` показал только `role=1`, который соответствует role windows `[34]` и `[7985]`; это не Dock window.
- Стабильная сигнатура для чтения Dock rect:

```swift
@convention(c) (
    CGSConnectionID,
    UnsafeMutablePointer<CGRect>,
    UnsafeMutablePointer<Int32>,
    UnsafeMutablePointer<Int32>
) -> Int32
```

- Стабильная сигнатура для записи Dock rect:

```swift
@convention(c) (CGSConnectionID, CGRect, Int32, Int32) -> Int32
```

- `SLSSetDockRectWithOrientation` может поменять Dock rect в WindowServer на rect целевого экрана без движения курсора и без перезапуска Dock, но за время теста фактическое окно Dock из `CGWindowListCopyWindowInfo` осталось на исходном display. Это пока не считается решением переноса Dock.
- `SLSSetDockRectWithReason` ведёт себя аналогично: меняет Dock rect в WindowServer, но фактическое окно Dock остаётся на исходном display.
- Старый 3-аргументный вызов `SLSGetDockRectWithOrientation` нестабилен и может ронять процесс; не использовать.

## Направление 2: Apple Events / Dock scripting / internal Dock messages

Проверить, есть ли у Dock Apple Events, XPC или distributed notifications для смены display.

Команды для разведки:

```bash
sdef /System/Library/CoreServices/Dock.app 2>/dev/null
ls -R /System/Library/CoreServices/Dock.app/Contents
strings /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock | rg -i "xpc|mach|notify|notification|display|space"
launchctl print gui/$(id -u)/com.apple.Dock.agent 2>/dev/null
```

Вероятность ниже, чем у SkyLight, но если есть внутренний message path, это будет чище, чем приватный WindowServer API.

Текущий результат:

- `sdef /System/Library/CoreServices/Dock.app` не вернул scripting dictionary.
- `launchctl print gui/$(id -u)/com.apple.Dock.agent` показывает активный endpoint `com.apple.dock.sidecar`.
- В Dock binary есть строки `SidecarMessage`, `getDockDisplay`, `requestDockOnDisplay`, `removeDockFromDisplay`, `dockDisplayChanged`.
- `DockSidecarProbe` с минимальными XPC dictionary-сообщениями пока получает только разрыв соединения. Следующий шаг — разбирать `DockSidecarConnection` / `SidecarMessage` глубже, а не перебирать ключи вслепую.

## Направление 3: Reverse engineering DockLock Lite

На машине есть prefs DockLock Lite:

```bash
defaults read pro.docklock.lite
```

Там видно:

- `settings.dock.control_mode = 1`
- `settings.dock.lock_position = 1`
- `settings.dock.workspaces`

Нужно понять, хранит ли DockLock screen/workspace binding и как именно он переносит Dock без видимого курсора.

Что сделать:

1. Найти установленный DockLock, если он есть, или скачать заново.
2. Посмотреть подпись, entitlements и linked frameworks:

```bash
codesign -dv --entitlements :- /path/to/DockLock.app 2>&1
otool -L /path/to/DockLock.app/Contents/MacOS/*
strings /path/to/DockLock.app/Contents/MacOS/* | rg -i "display|space|dock|cursor|mouse|event|sky|sls|cgs"
```

3. Запустить DockLock и мониторить:

```bash
log stream --style compact --predicate 'process CONTAINS[c] "DockLock" OR process == "Dock"'
fs_usage -w -f filesys | rg "DockLock|com.apple.dock|com.apple.spaces"
```

4. Сравнить изменения defaults до/после смены выбранного экрана в DockLock:

```bash
defaults read com.apple.dock > /tmp/dock.before
defaults read com.apple.spaces > /tmp/spaces.before
# сменить экран в DockLock
defaults read com.apple.dock > /tmp/dock.after
defaults read com.apple.spaces > /tmp/spaces.after
diff -u /tmp/dock.before /tmp/dock.after
diff -u /tmp/spaces.before /tmp/spaces.after
```

Если DockLock тоже использует приватные SkyLight функции, это должно проявиться в linked frameworks/strings/logs.

Текущий результат:

- Локальные prefs `defaults read pro.docklock.lite` есть.
- Сам `.app` в стандартных папках приложений не найден, поэтому linked frameworks, entitlements и runtime logs пока проверить не удалось.

## Направление 4: Screen Recording / window visibility limitation

В текущем установленном приложении `currentDockDisplayID` иногда возвращает `nil`, потому что `CGWindowListCopyWindowInfo` может не отдавать достаточную информацию без Screen Recording. Из терминала та же проверка часто видит Dock window.

Нужно решить:

- использовать другой источник состояния: на 2026-05-01 добавлен primary read через `SLSGetDockRectWithOrientation`;
- `CGWindowListCopyWindowInfo` оставлен fallback-источником.

Не добавлять Screen Recording без необходимости: это ухудшит onboarding.

## Направление 5: fallback без программного движения курсора

Если прямого API не найдётся, лучше плохой fallback сделать честным, но не раздражающим:

- меню выбирает target display;
- если Dock ещё не на target, статус показывает “Подведите курсор к краю выбранного экрана один раз”;
- после ручного штатного переноса Fixdock закрепляет выбранный экран edge-фильтром.

Это хуже, чем автоматический перенос, но лучше, чем приложение внезапно двигает курсор за пользователя.

Важно: fallback не должен содержать автоматическое движение курсора. Только пользователь сам решает, делать ли ручной edge-жест.

## Важные ограничения

- Не использовать движение видимого курсора как production-механизм.
- Не возвращать `DockRelocator`, `CGWarpMouseCursorPosition`, `NSCursor.hide()` или synthetic mouse move перенос.
- Не использовать `killall Dock` в фоне или по таймеру.
- Не добавлять новые видимые режимы в меню.
- Не возвращать старую модель с несколькими кнопками.
- Не ломать свободное движение курсора по второму экрану.
- Не блокировать всю нижнюю/боковую область экрана.

## Рекомендуемый следующий шаг

Начать с отдельного экспериментального файла/скрипта вне app bundle:

```text
Experiments/SkyLightDockDisplaySwitch/
Experiments/DockSidecarProbe/
```

Цель эксперимента:

- принять `displayID`;
- без изменения cursor location попытаться вызвать приватный SkyLight/CoreGraphics Services путь;
- вывести before/after Dock window bounds;
- вывести before/after cursor location;
- вывести before/after Dock PID.
- для XPC-ветки понять формат `SidecarMessage` и handshake endpoint `com.apple.dock.sidecar`.

Только если эксперимент докажет перенос Dock без курсора, переносить это в `Sources/Fixdock`.

## Старое поведение, которое уже убрано из production

Раньше перенос выполнялся здесь:

```text
Sources/Fixdock/AppDelegate.swift
Sources/Fixdock/DockRelocator.swift
```

`DockRelocator` двигал курсор к edge point выбранного экрана, постил synthetic mouse moved events и возвращал курсор обратно. Этот файл удалён из production target. Целевая задача следующего этапа — найти и подтвердить некурсорный relocation backend в `Experiments/SkyLightDockDisplaySwitch`, затем переносить только подтверждённый механизм в `Sources/Fixdock`.
