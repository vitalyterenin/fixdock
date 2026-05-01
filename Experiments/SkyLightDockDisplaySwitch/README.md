# SkyLightDockDisplaySwitch

Эксперимент для проверки переноса Dock между managed displays через приватные SkyLight API без движения видимого курсора.

## Запуск read-only диагностики

```bash
cd /Users/vitalyterenin/Projects/Personal/Fixdock/Experiments/SkyLightDockDisplaySwitch
swift run SkyLightDockDisplaySwitch
```

Диагностика печатает:

- `CGDirectDisplayID`, bounds и managed display identifier для каждого активного экрана;
- текущий Dock rect из `SLSGetDockRectWithOrientation`;
- текущее окно Dock из `CGWindowListCopyWindowInfo`;
- managed display role windows для выбранного диапазона ролей;
- позицию курсора до и после запуска.

## Поиск role window

```bash
swift run SkyLightDockDisplaySwitch --scan-roles 0...32
```

Если какая-то роль содержит window id Dock, это кандидат для следующего write-эксперимента.

## Write-эксперимент

```bash
swift run SkyLightDockDisplaySwitch --target-display <CGDirectDisplayID> --set-role-window <role> --apply
```

`--apply` обязателен, чтобы случайный запуск не менял состояние WindowServer. Перед использованием нужно вручную проверить, что выбранная `role` действительно соответствует Dock window.

## Reversible Dock rect test

```bash
swift run SkyLightDockDisplaySwitch --target-display <CGDirectDisplayID> --test-dock-rect --apply
```

Этот тест вызывает `SLSSetDockRectWithOrientation` с rect на целевом экране, ждёт короткое время, печатает состояние и по умолчанию возвращает исходный rect.

Чтобы не возвращать rect автоматически:

```bash
swift run SkyLightDockDisplaySwitch --target-display <CGDirectDisplayID> --test-dock-rect --keep-dock-rect --apply
```

## Reversible Dock rect with reason test

```bash
swift run SkyLightDockDisplaySwitch --target-display <CGDirectDisplayID> --test-dock-rect-reason --apply
```

Этот тест вызывает `SLSSetDockRectWithReason`, ждёт короткое время, печатает состояние и по умолчанию возвращает исходный rect. На текущей конфигурации он меняет Dock rect в WindowServer, но фактическое окно Dock остаётся на исходном display.
