# Omarchy Drawer Notifications

[🇬🇧 English](README.md)

Уведомления [Omarchy](https://omarchy.org) (клон стокового `omarchy.notifications`), где тосты лежат в одной
панели. Со сплошным баром у края — например, скином `frame` из
[omarchy-bar-skins](https://github.com/KamradSmeshnyavy/omarchy-bar-skins) — панель прилипает к бару и краю
экрана вогнутыми углами; с прозрачным или плавающим баром — плавающая карточка с отступом и тенью. Высота
следует за числом тостов. Демон, «Не беспокоить», история и IPC — стоковые.

## Установка

```sh
git clone https://github.com/KamradSmeshnyavy/omarchy-drawer-notifications ~/.config/omarchy/plugins/kamradsmeshnyavy.notifications
omarchy-shell shell rescanPlugins
omarchy plugin enable kamradsmeshnyavy.notifications   # обратно к стоку: omarchy plugin enable omarchy.notifications
```

## Настройки

`~/.config/omarchy/notify-style.json`, применяются на лету; [Customizer](https://github.com/KamradSmeshnyavy/omarchy-customizer) —
Окна → Уведомления. Ключи — в [README.md](README.md#settings): стиль, угол (справа / слева / по центру), ширина,
сколько тостов видно сразу, вид карточек (`flat` / `bordered` / `nihil`), «следовать стилю бара», режим прилипания, свой фон / альфа / скругление.

Правки стоковых файлов помечены `// drawer:`.

**Токены стиля.** `~/.config/omarchy/style.json` (пишет
[omarchy-customizer](https://github.com/KamradSmeshnyavy/omarchy-customizer) → Пресеты → Стиль) настраивает панели поверх
бара: `elevation` 0–2 (тени), `motion` (множитель скорости анимаций, 0 — без них), `material` (`auto` / `solid` /
`glass`), `cornerScale` (0 — прямые углы), `typeface` (`shell` — шрифт Omarchy, `profile` — sans из
`~/.config/omarchy/fonts.json`; иконки всегда в шрифте Omarchy). Нет файла — вид как раньше.

## Лицензия

MIT (вместе со стоковым плагином Omarchy, из которого сделан клон).
