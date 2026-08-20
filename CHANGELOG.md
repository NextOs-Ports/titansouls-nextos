# Changelog

## 1.0.8-candidate.1 — 2026-08-20 — OPT-IN CANDIDATE

- Candidato final da promoção mixed-ABI, construído pelo pipeline real
  (nxgenerator + nxbootstrap + nxrelease), não mais por materialização a
  partir de um ZIP-base pinado.
- `nxproject.json`/`nxport.json` passam a declarar `execution_roles` (schema 2):
  extrator AArch64 nativo com closure de host; splash e jogo ARMHF por
  `native-or-loader` com closure de firmware (e de port, no jogo). O launcher
  0.6.27 roteia cada papel e emite `EXECUTION RECEIPT`.
- NXExtract 1.2.13 com a UI canônica AArch64; NXSplash 0.1.2 byte-idêntica.
- O executável ARMHF é **byte-idêntico** ao do teste de campo
  `1.0.8-spruce-test.1`: só o lado host mudou.
- Aceitação física no Miyoo Flip/spruceOS continua PENDENTE; sem ela não há
  tag imutável nem release pública.

## 1.0.8-spruce-test.1 — 2026-08-20 — PRIVATE TEST

- Candidato isolado para o runtime ARMHF montado pelo spruceOS no Miyoo Flip.
  Não altera nem promove uma nova versão do framework compartilhado.
- No Spruce AArch64, o NXExtract usa a UI canônica AArch64 para que a tela de
  instalação não dependa do loader ARMHF fora do caminho padrão. A identidade
  visual e o código da UI permanecem byte-idênticos ao artefato canônico.
- Antes do jogo ARMHF, descarta somente hints de vídeo SDL herdados do frontend
  64-bit e deixa a SDL 32-bit autodetectar seu backend `mali`; não força
  `SDL_VIDEODRIVER`.
- Seleciona primeiro os diretórios ARMHF reais `usr/lib32` da imagem oficial e
  fixa os providers não-versionados `libEGL.so`/`libGLESv2.so`, que apontam
  diretamente para o libmali 32-bit.
- Diagnóstico port-local registra drivers SDL compilados, acesso aos device
  nodes, resultado imediato de `SDL_InitSubSystem(VIDEO)` e o journal do nxgl.
  Falha continua falha: não há fallback headless nem sucesso falso.

## 1.0.7 — 2026-08-19

- Launcher regenerado com nxbootstrap 0.6.26: validador do resultado do
  NXExtract compativel com engines futuros (classe dos updates hibridos do
  muOS). Sem mudanca de gameplay.
- Quem vem de versao anterior: instalacao LIMPA (apagar a pasta titansouls E
  o "Titan Souls.sh" antes de extrair).
