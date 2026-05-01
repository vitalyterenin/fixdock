# DockSidecarProbe

Эксперимент для проверки XPC endpoint `com.apple.dock.sidecar`.

Dock содержит строки `getDockDisplay`, `requestDockOnDisplay`, `removeDockFromDisplay` и активный launchd endpoint `com.apple.dock.sidecar`. Этот probe отправляет минимальные XPC-словарные сообщения и печатает reply/event без движения курсора.

## Read-only запуск

```bash
cd /Users/vitalyterenin/Projects/Personal/Fixdock/Experiments/DockSidecarProbe
swift run DockSidecarProbe
```

## Guarded write-запуск

```bash
swift run DockSidecarProbe --target-display <CGDirectDisplayID> --apply
```

`--apply` обязателен для сообщений `requestDockOnDisplay`, потому что они потенциально могут менять экран Dock.
