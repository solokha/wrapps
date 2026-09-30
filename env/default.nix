{ pkgs, inputs, self }:
let
  system = pkgs.stdenv.hostPlatform.system;

  tools = import ./packages.nix { inherit pkgs; };

  wrapped = [
    self.packages.${system}.helix
    self.packages.${system}.zellij
    self.packages.${system}.nh
  ];

  envrc = pkgs.writeText "envrc" ''
    # Промпт и история: темы приходят из noctalia (палитра/настройки в ~/.config),
    # без noctalia — дефолтный вид.
    eval "$(${pkgs.starship}/bin/starship init bash)"

    # atuin: история; стрелка-вверх остаётся за bash, чтобы не выгрызать нативы.
    eval "$(${pkgs.atuin}/bin/atuin init bash --disable-up-arrow)"

    # Токены (ssh-agent для GitHub) настраиваются автоматически, но только если
    # они физически есть: ключи в ~/.ssh И FIDO2-токен в системе. На live ISO и
    # на чужом хосте ~/.ssh может приехать из контракта сохранения вместе с
    # handle'ами — поднимать там агент для GitHub никто не просил.
    _have_key=0
    for _k in "$HOME"/.ssh/id_ecdsa_sk* "$HOME"/.ssh/id_ed25519_sk*; do
      case "$_k" in *.pub) continue ;; esac
      [ -f "$_k" ] && { _have_key=1; break; }
    done
    _have_fido=0
    grep -lqiE 'HID_NAME=.*FIDO' /sys/class/hidraw/hidraw*/device/uevent 2>/dev/null && _have_fido=1

    if [ "$_have_key" = 1 ] && [ "$_have_fido" = 1 ]; then
      # Свой сокет, не systemd-шный: NixOS поднимает агента для всех, у него нет
      # SSH_ASKPASS в окружении, и он отвечает "agent refused operation".
      eval "$(${agent}/bin/wrapps-agent)"

      # Ключи грузим только в интерактивной оболочке: ssh-add на sk-ключе
      # открывает PIN-диалог, и на каждый `nix run .#env` он появлялся бы заново.
      # wrapps-keys пропускает уже загруженные, поэтому окно одно на сессию.
      if [ -t 0 ]; then
        ${keys}/bin/wrapps-keys >/dev/null 2>&1 || true
      fi
    fi

    # sops/age: стандартные пути, чтобы правился ~/.config/sops.
    export SOPS_AGE_KEY_FILE="''${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
  '';

  denv = pkgs.writeShellScriptBin "denv" ''
    export SHELL="${pkgs.bash}/bin/bash"
    export EDITOR="${self.packages.${system}.helix}/bin/hx"
    export PATH="${pkgs.lib.makeBinPath (tools ++ wrapped)}:$PATH"
    exec ${pkgs.bash}/bin/bash --rcfile ${envrc} "$@"
  '';

  shell = pkgs.writeShellScriptBin "shell" ''
    exec ${denv}/bin/denv "$@"
  '';

  # ── ssh-агент, который умеет спрашивать PIN ────────────────────────────────
  #
  # ssh-agent сам обращается к SSH_ASKPASS за PIN и за подтверждением
  # присутствия — проверено на обычном ed25519 с паролем. На FIDO2-ключе он
  # спрашивает то же самое, поэтому проблема не в токене, а в том, что агент
  # запущен без переменных: без них он молча отвечает "agent refused
  # operation", и это выглядит как «подпись невозможна».
  #
  # Переменные обязаны быть в окружении агента, а не только вызывающего шелла:
  # агент наследует их при старте, поэтому задаются ДО `ssh-agent`.
  #
  # В askpass ставится штатный openssh-askpass из nixpkgs, свой диалог не
  # пишем: протокол askpass (приглашение в argv[1], секрет в stdout) — это
  # ровно то, что делает openssh-askpass. pinentry не подходит: это диалог
  # gpg-агента, он говорит по Assuan и в этой роли зависает.
  #
  # stdout — только строки для eval, остальное в stderr, иначе eval испортится.
  agent = pkgs.writeShellScriptBin "wrapps-agent" ''
    set -euo pipefail

    # Живость агента — по ТЕКСТУ, а не по коду возврата: у живого агента без
    # ключей `ssh-add -l` даёт "The agent has no identities" и rc=1, то же
    # самое, что при битом сокете, но только битый сокет должен считаться
    # мёртвым. На rc=1 новый агент поднимался бы поверх живого, и каждая
    # проверка молча перезапускала бы его.
    agent_alive() {
      local out
      out="$(ssh-add -l 2>&1)" || true
      case "$out" in
        *"The agent has no identities"*) return 0 ;;
        *"256 "*|*"307 "*|*"384 "*|*"512 "*) return 0 ;;
        *) return 1 ;;
      esac
    }

    sock="''${WRAPPS_AGENT_SOCK:-''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wrapps-agent.sock}"
    pidfile="$sock.pid"
    mkdir -p "$(dirname "$sock")"

    # Диалог PIN: штатный openssh-askpass из nixpkgs, свой не пишем. Он нужен
    # только там, где у агента нет терминала: из графической сессии это окно,
    # с консоли live ISO терминал есть и агент спрашивает сам. Поэтому без
    # дисплея SSH_ASKPASS намеренно НЕ задаётся — иначе агент на консоли ушёл
    # бы в окно, которого там нет, вместо вопроса в терминале.
    #
    # Обёртка askpass-guard ставится между агентом и диалогом и ничего не
    # спрашивает сама: она считает обращения к токену и отказывает после
    # лимита, потому что неверный PIN тратит попытку на самом токене.
    if [ -n "''${WRAPPS_ASKPASS:-}" ]; then
      real_askpass="$WRAPPS_ASKPASS"
    elif [ -n "''${WAYLAND_DISPLAY:-''${DISPLAY:-}}" ]; then
      # В nixpkgs бинарь лежит в libexec/gtk-ssh-askpass, не в bin/, и это
      # GTK3 — на Wayland он идёт через XWayland, то есть через DISPLAY.
      real_askpass=${pkgs.openssh-askpass}/libexec/gtk-ssh-askpass
    else
      real_askpass=""
    fi
    if [ -n "$real_askpass" ] && [ ! -x "$real_askpass" ]; then
      echo "askpass не найден или не исполняем: $real_askpass" >&2
      exit 1
    fi
    if [ -n "$real_askpass" ]; then
      askpass=${guard}/bin/wrapps-askpass-guard
      export WRAPPS_ASKPASS_REAL="$real_askpass"
    else
      askpass=""
    fi

    # Агент считается нашим только если этот pid — тот самый ssh-agent,
    # запущенный на этом сокете. Иначе сокет занят чужим или прошлым агентом:
    # он держит ключи, но поднят без SSH_ASKPASS, и подпись через него не идёт.
    ours() {
      local pid cmd
      [ -f "$pidfile" ] || return 1
      pid="$(cat "$pidfile" 2>/dev/null || true)"
      [ -n "$pid" ] || return 1
      kill -0 "$pid" 2>/dev/null || return 1
      # /proc/<pid>/cmdline разделён NUL, поэтому «-a <сокет>» в нём не найти
      # grep'ом как есть: совпало бы только после замены разделителей.
      cmd="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)"
      case "$cmd" in
        ssh-agent*" -a $sock"*) return 0 ;;
        *) return 1 ;;
      esac
    }

    if ! ours; then
      if [ -S "$sock" ]; then
        SSH_AUTH_SOCK="$sock" ssh-agent -k >/dev/null 2>&1 || true
        rm -f "$sock"
        echo "старый агент на $sock снят: он поднят без SSH_ASKPASS" >&2
      fi
      rm -f "$pidfile"
      # Счётчик PIN живёт столько же, сколько агент: с новым агентом и
      # счётчик начинается с нуля, иначе лимит пережил бы то, ради чего
      # поднимается новый агент.
      rm -f "$sock.pin-count"
    fi

    if ! ours; then
      # Вывод `ssh-agent -a SOCK` — строки вида `VAR=VALUE; export VAR;` плюс
      # `echo Agent pid N;`. Последняя при eval внутри скрипта ушла бы в наш
      # stdout и сломала бы `eval "$(wrapps-agent)"` у вызывающего, поэтому eval
      # не делаем, а разбираем вывод сами. Модуль не нужен: `;` в пути сокета
      # не бывает.
      #
      # pgrep по шаблону «-a <сокет>» не годится: он совпадает и с командной
      # строкой вызывающего шелла, и pidfile записал бы не тот pid.
      _out="$(SSH_ASKPASS="$askpass" \
              SSH_ASKPASS_REQUIRE="${askpass:+force}" \
              WRAPPS_ASKPASS_REAL="$real_askpass" \
              WRAPPS_PIN_COUNTER="$sock.pin-count" \
                ssh-agent -a "$sock")"
      _sock_out="$(printf '%s\n' "$_out" | sed -n 's/^SSH_AUTH_SOCK=\([^;]*\);.*/\1/p' | head -n1)"
      _pid="$(printf '%s\n' "$_out" | sed -n 's/^SSH_AGENT_PID=\([^;]*\);.*/\1/p' | head -n1)"
      if [ -z "$_sock_out" ] || [ -z "$_pid" ]; then
        echo "не удалось разобрать вывод ssh-agent: $_out" >&2
        exit 1
      fi
      [ "$_sock_out" = "$sock" ] || {
        echo "агент поднялся на $_sock_out вместо $sock" >&2
        exit 1
      }
      printf '%s\n' "$_pid" >"$pidfile"
    fi

    # Живость проверяем именно этого сокета, а не текущего SSH_AUTH_SOCK:
    # старый агент на ~/.ssh/socket не должен мешать. Проверка ДО вывода строк
    # для eval — при мёртвом агенте вызывающий не должен получить валидный
    # SSH_AUTH_SOCK и вслепую уйти в push.
    if ! agent_alive; then
      echo "агент на $sock не отвечает" >&2
      exit 1
    fi

    # Переменные достаются вызывающему тоже: ими пользуются ssh и git, когда
    # подпись идёт мимо агента. Без дисплея SSH_ASKPASS не выводится вовсе,
    # чтобы не переопределить то, что на консоли и так работает.
    if [ -n "$askpass" ]; then
      echo "export SSH_ASKPASS=$askpass"
      echo "export SSH_ASKPASS_REQUIRE=force"
      # Счётчик и настоящий диалог — в окружение вызывающего: ssh и git
      # спрашивают PIN иногда мимо агента, и без счётчика лимит обходился бы.
      echo "export WRAPPS_ASKPASS_REAL=$real_askpass"
      echo "export WRAPPS_PIN_COUNTER=$sock.pin-count"
    fi
    echo "export SSH_AUTH_SOCK=$sock"
  '';

  # ── Счётчик обращений к токену ────────────────────────────────────────────
  #
  # Токен тратит попытку на каждый неверный PIN, и счётчик попыток у него
  # обнуляется только сбросом через меню токена. Поэтому число запросов в
  # сессии ограничено, а оболочка вслух говорит, что лимит reached: молча
  # перестав спрашивать нельзя, это выглядит как «подпись не работает».
  #
  # Считает ОБРАЩЕНИЯ, а не неудачи: правильный PIN тратить нечего, и отказ
  # считать успех нельзя — он счётчик не обнуляет. Состояние — в файле рядом
  # с сокетом агента, то есть живёт ровно столько же, сколько агент.
  guard = pkgs.writeShellScriptBin "wrapps-askpass-guard" ''
    set -uo pipefail

    real="''${WRAPPS_ASKPASS_REAL:-}"
    if [ -z "$real" ] || [ ! -x "$real" ]; then
      printf 'askpass-guard: WRAPPS_ASKPASS_REAL не задан или не исполняем\n' >&2
      exit 1
    fi

    counter="''${WRAPPS_PIN_COUNTER:-''${WRAPPS_AGENT_SOCK:-''${XDG_RUNTIME_DIR:-/tmp}/wrapps-agent.sock}.pin-count}"
    limit="''${WRAPPS_PIN_LIMIT:-3}"

    # На FIDO2 агент задаёт ДВА вопроса: «Confirm user presence» и «Enter PIN».
    # На первый отвечаем сами: настоящая проверка присутствия — физическое
    # касание токена, его нельзя ни пропустить, ни подделать, а окно на него
    # только добавляет лишний диалог. Счётчик и окно нужны ровно на один
    # вопрос — на PIN, и на него одна попытка токена.
    case "''${1:-}" in
      *"Confirm user presence"*)
        printf 'y\n'
        exit 0
        ;;
    esac

    n=0
    if [ -f "$counter" ]; then
      read -r n <"$counter" 2>/dev/null || n=0
    fi
    case "$n" in
      *[!0-9]*) n=0 ;;
    esac

    if [ "$n" -ge "$limit" ]; then
      printf 'askpass-guard: лимит запросов PIN исчерпан (%s из %s) на %s\n' \
        "$n" "$limit" "$counter" >&2
      printf 'askpass-guard: токен не тронут. Сбросить счётчик: rm %s\n' "$counter" >&2
      exit 1
    fi

    n=$((n + 1))
    printf '%s\n' "$n" >"$counter"

    # Диалог спросит сам и напечатает ответ в stdout, куда его ждёт агент.
    # Счётчик НЕ обнуляется: успешный запрос тоже потратил токенное время, и
    # лимит должен ограничивать именно число касаний за сессию.
    exec "$real" "$@"
  '';

  # ── Загрузка sk-ключей в агент ────────────────────────────────────────────
  #
  # Каждый ssh-add на sk-ключе — это ОДИН запрос PIN на токен, и неверный PIN
  # тратит попытку на самом токене. Отсюда два решения:
  #   - по умолчанию грузится ОДИН ключ (тот, что нужен GitHub), а не все: два
  #     токена означали бы два окна подряд и две попытки на пустом месте;
  #   - уже загруженные ключи пропускаются, повторного окна не будет.
  # Все ключи — осознанно, через WRAPPS_ALL_SK_KEYS=1.
  keys = pkgs.writeShellScriptBin "wrapps-keys" ''
    set -uo pipefail

    # rc=1 у живого агента без ключей («no identities») — это не поломка,
    # поэтому судим по тексту, как в wrapps-agent.
    agent_alive() {
      local out
      out="$(ssh-add -l 2>&1)" || true
      case "$out" in
        *"The agent has no identities"*) return 0 ;;
        *"256 "*|*"307 "*|*"384 "*|*"512 "*) return 0 ;;
        *) return 1 ;;
      esac
    }

    if [ -z "''${SSH_AUTH_SOCK:-}" ] || ! agent_alive; then
      printf 'ssh-агент не поднят: eval "$(wrapps-agent)"\n' >&2
      exit 1
    fi

    fingerprint() { ssh-keygen -lf "$1" 2>/dev/null | awk "{print \$2}"; }

    loaded=0
    added=0
    failed=0
    for k in "$HOME"/.ssh/id_ecdsa_sk* "$HOME"/.ssh/id_ed25519_sk*; do
      case "$k" in *.pub) continue ;; esac
      [ -f "$k" ] || continue
      if [ -n "''${WRAPPS_SK_KEY:-}" ]; then
        [ "$k" = "$WRAPPS_SK_KEY" ] || continue
      elif [ -z "''${WRAPPS_ALL_SK_KEYS:-}" ] && [ $((loaded + added)) -gt 0 ]; then
        # По умолчанию — один ключ: каждый ssh-add на sk-ключе это запрос PIN
        # на токен, а лишние ключи всё равно не нужны, потому что GitHub ходит
        # по ~/.ssh/config с IdentitiesOnly и одним IdentityFile.
        break
      fi
      fp="$(fingerprint "$k.pub")"
      if [ -n "$fp" ] && ssh-add -l | grep -qF "$fp"; then
        loaded=$((loaded + 1))
        continue
      fi
      if ssh-add "$k" 2>/dev/null; then
        added=$((added + 1))
        printf 'загружен: %s\n' "$k" >&2
      else
        failed=$((failed + 1))
        printf 'НЕ загружен (нет токена или не тот PIN): %s\n' "$k" >&2
        # Без WRAPPS_ALL_SK_KEYS следующий ключ означал бы ещё один запрос PIN
        # после уже неудачного: стоп здесь, разбираться с причиной дешевле.
        [ -z "''${WRAPPS_ALL_SK_KEYS:-}" ] && break
      fi
    done

    # «sk-ключей нет» — только если не нашлось НИ ОДНОГО файла. Иначе причина в
    # другом (токен не вставлен, PIN не тот), и такая формулировка уводила бы
    # в ssh-keygen -K вместо правды.
    if [ "$((loaded + added + failed))" -eq 0 ]; then
      printf 'sk-ключей в ~/.ssh нет: cd ~/.ssh && ssh-keygen -K\n' >&2
      exit 1
    fi
    if [ "$failed" -gt 0 ]; then
      printf 'не загружено ключей: %s. Проверь, что токен вставлен и PIN верный.\n' "$failed" >&2
      exit 1
    fi
    if [ "$added" -gt 0 ]; then
      printf 'готово, добавлено ключей: %s. Дальше push спросит PIN и касание.\n' "$added" >&2
    else
      printf 'готово, ключ уже в агенте.\n' >&2
    fi
  '';

  # Точка входа по требованию:  eval "$(gitauth)"
  # Вызывающий получает все три переменные, а не только SSH_AUTH_SOCK: ssh и
  # git подписывают иногда мимо агента, и без askpass в их окружении подпись
  # снова упирается в «agent refused operation».
  gitauth = pkgs.writeShellScriptBin "gitauth" ''
    set -euo pipefail
    eval "$(${agent}/bin/wrapps-agent)"
    ${keys}/bin/wrapps-keys
    echo "export SSH_ASKPASS=''${SSH_ASKPASS:-}"
    echo "export SSH_ASKPASS_REQUIRE=''${SSH_ASKPASS_REQUIRE:-}"
    echo "export WRAPPS_ASKPASS_REAL=''${WRAPPS_ASKPASS_REAL:-}"
    echo "export WRAPPS_PIN_COUNTER=''${WRAPPS_PIN_COUNTER:-}"
    echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
  '';

  # ── Конфиг git для чужих хостов и live ISO ─────────────────────────────────
  #
  # На своих NixOS-хостах всё разложено /etc/gitconfig'ом (infra, git.nix), и
  # повторная запись в ~/.gitconfig только задвоила бы строки. Этот скрипт
  # настраивает подпись и IdentitiesOnly там, где системного конфига нет.
  gitsetup = pkgs.writeShellScriptBin "gitsetup" ''
    set -euo pipefail

    if [ "$(git config --system --get gpg.format 2>/dev/null || true)" = "ssh" ]; then
      printf 'подпись коммитов уже настроена системно — ничего не меняю\n'
      exit 0
    fi

    key=""
    for k in "$HOME"/.ssh/id_ecdsa_sk* "$HOME"/.ssh/id_ed25519_sk*; do
      case "$k" in *.pub) continue ;; esac
      [ -f "$k" ] && { key="$k"; break; }
    done
    if [ -z "$key" ]; then
      printf 'sk-ключей в ~/.ssh нет: cd ~/.ssh && ssh-keygen -K\n' >&2
      exit 1
    fi

    git config --global gpg.format ssh
    git config --global commit.gpgsign true
    git config --global tag.gpgsign true
    git config --global user.signingKey "$key"
    printf 'подпись коммитов: gpg.format=ssh, ключ %s\n' "$key"

    if [ -f /etc/ssh/allowed_signers ]; then
      git config --global gpg.ssh.allowedSignersFile /etc/ssh/allowed_signers
      printf 'проверка подписей: /etc/ssh/allowed_signers\n'
    fi

    # IdentitiesOnly: в ~/.ssh лежат sk-ключи от двух токенов, и без него ssh
    # предлагает серверу оба — и на каждое лишнее предложение приходится ещё
    # и лишний запрос PIN.
    cfg="$HOME/.ssh/config"
    if [ ! -e "$cfg" ]; then
      mkdir -p "$HOME/.ssh"
      chmod 700 "$HOME/.ssh"
      # Heredoc с отступом не годится: отступы Nix срезает по общему префиксу,
      # и в файл попали бы строки с разным уровнем. Поэтому unquoted EOF и
      # нулевой отступ — единственная форма, где ssh_config читается как надо.
      cat >"$cfg" <<EOF
# Создано wrapps: gitsetup. Файл перезаписывается, только пока его нет.
Host github.com *.github.com
  User git
  HostName github.com
  IdentityFile $key
  IdentitiesOnly yes
EOF
      chmod 600 "$cfg"
      printf 'создан %s: github.com только с %s\n' "$cfg" "$(basename "$key")"
    elif ! grep -q 'github.com' "$cfg" 2>/dev/null; then
      printf 'ВНИМАНИЕ: %s уже есть и без блока github.com — добавь сам:\n' "$cfg"
      printf '  Host github.com\n    User git\n    IdentityFile %s\n    IdentitiesOnly yes\n' "$key"
    else
      printf '%s уже настраивает github.com — не трогаю\n' "$cfg"
    fi

    for what in user.name user.email; do
      if [ -z "$(git config --get "$what" 2>/dev/null || true)" ]; then
        printf 'ВНИМАНИЕ: не задано %s — коммит не пройдёт. Задай в ~/.gitconfig.\n' "$what"
      fi
    done
  '';
in
pkgs.symlinkJoin {
  name = "env";
  paths = tools ++ wrapped ++ [
    denv
    shell
    agent
    guard
    keys
    gitauth
    gitsetup
  ];
  meta.mainProgram = "denv";
}
