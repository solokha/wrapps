# Handoff: #env сорсит harness.env — {env:...} в opencode.json

- Date / host / agent: 2026-10-17 10:37 / rover / opencode (V2)
- Goal: чтобы переменные хоста (HARNESS_DIR, адреса локальных моделей) доходили до
  собственного окружения агента, а не терялись.
- Done:
  - `env/default.nix`, блок `envrc`: под `[ -r "$HOME/.config/harness.env" ]` —
    `set -a; . "$HOME/.config/harness.env"; set +a`. Коммит `fe24815`, запушен в `main`.
  - Проверено интерактивным bash под pty
    (`script -qec "bash --rcfile <envrc> -i" /dev/null`) с изолированным `HOME`:
    без файла переменные пусты, с файлом — есть. Важно: `bash -c` rcfile **не
    читает**, поэтому проверять только под pty с `-i`.
  - `nix flake check` — all checks passed; `alejandra --check` чисто.
- State: `main` чисто, `fe24815` == `origin/main`. Потребитель — `infra`.
- Next steps:
  1. `infra`: лок поднят до `fe24815` (`43fb443`), toplevel собран; остался
     `nh os switch .#rover` и перезапуск сессии.
  2. Адреса моделей: значения в `harness/hosts/rover.env` (`localhost:8080/8081`) на
     rover никто не слушает. atlas отдаёт `192.168.77.4:8080` (llama-swap:
     `qwen3.8-27b`, `gemma-4-12b-it-Q4_K_M`), valet — `192.168.77.3:8083`
     (`gemma-4-E4B-it-Q4_K_M`). Плюс `opencode.json` шлёт id `main`/`fast`, которых у
     серверов нет. Решение и правки — в `harness`, не здесь.
- Open questions / risks: см. п. 2 — без этого `llm-main`/`llm-fast` нерабочие, даже
  когда переменные доходят.
- How to resume: `wrapps/env/default.nix` (блок `envrc`), `harness/hosts/rover.env`,
  `harness/adapters/opencode/opencode.json`, `infra/docs/lab-notes.md` («Открыто»).
