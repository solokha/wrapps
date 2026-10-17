# Handoff: порядок ключей в ssh-agent (@clone первым)

- Date / host / agent: 2026-10-17 09:45 / rover / opencode (V2)
- Goal: push не должен трогать `@alone` и тратить на него PIN с касанием.
- Done:
  - `env/default.nix`, `wrapps-agent`: ключи кладутся в агент в порядке
    `@clone` → остальные. Раньше порядок задавал glob `id_ecdsa_sk*`, то есть
    `@alone` шёл первым.
  - Порядок записывается третьей строкой в pidfile рядом с сокетом и сверяется
    в `usable()`: агент, поднятый старым скриптом, перезапускается, а не живёт
    со старым порядком молча.
  - `README.md` / `README.en.md`, раздел FIDO2: почему порядок задаёт агент, а
    не `ssh_config`.
- Why:
  - Живой push печатал `sign_and_send_pubkey: signing failed for ECDSA-SK
    "…id_ecdsa_sk_rk_solo@alone" from agent: agent refused operation`: агент
    отвечает не на тот вопрос, который задавали. `ssh` предлагает серверу ключи
    из агента раньше файловых и **в порядке агента** (`sshconnect2.c`,
    `agent_keys`), поэтому `IdentityFile` в `/etc/ssh/ssh_config` порядок
    предложения не задаёт — при том что `/etc/ssh/ssh_config` (infra,
    `services/git.nix`) перечисляет `@clone` первым именно ради этого.
  - В агенте ключи лежали в порядке glob: `solo@alone`, `solo@clone`,
    `work@alone`, `work@clone`. Первым предлагался `@alone`, сервер его
    принимал (ключ зарегистрирован), и вставленный `@clone` тратил
    взаимодействие дважды: на credential, которого в нём нет (отсюда
    «agent refused operation»), и на настоящую подпись.
- Verified:
  - Песочница с подставным `$HOME`: порядок `ssh-add` — `solo@clone`,
    `work@clone`, `solo@alone`, `work@alone`; pidfile из трёх строк; агент со
    старым pidfile (2 строки) и агент после появления нового ключа
    перезапускаются; при неизменном порядке агент переиспользуется.
  - `nix flake check` — all checks passed; `alejandra --check` чисто.
  - Живьём: агент перезапущен новым скриптом (без токена), `ssh-add -l` —
    `ssh:solo@clone` первым, `work@clone`, `solo@alone`, `work@alone`.
- Not done / next:
  - Пуш этого коммита — следующим шагом (ожидание: окно PIN и касание на
    `@clone`, строки про `@alone` в выводе нет).
  - `infra/modules/services/git.nix`, описание `identityFiles`: там сказано
    «Порядок не важен: неверный вариант отсеивается бесплатно». Верно для ключа,
    которого нет в агенте, и неверно для ключа, чей токен не вставлен: его
    взаимодействие оплачивает вставленный токен. Правка — отдельная задача в
    `infra` (свой репозиторий, свой push).
- Open questions / risks:
  - Если вставлен `@alone`, а `@clone` нет, картина зеркальная: первым
    предлагается `@clone` и упирается в отказ. Порядок выбирает, какой токен
    платит лишним взаимодействием; взят `@clone` — он всегда с собой.
- How to resume: `wrapps/env/default.nix` (`wrapps-agent`), README «FIDO2».
