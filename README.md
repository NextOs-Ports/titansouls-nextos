# Titan Souls — NextOS compatibility port (ARMv7, BYO data)

**Language / Idioma:** [English](#english) · [Português](#português)

The standalone source export contains only port-specific free code, manifests,
documentation and the installation recipe. The generated launcher and
redistributable framework runtime are materialized for the data-free public ZIP;
they are not vendored as framework source in that export. Neither form contains
Titan Souls, an APK, an OBB, extracted Android libraries, game assets or saves.

## English

### Status and validation boundary

Titan Souls reaches its native Android flow through a Linux ARMHF compatibility
loader. A binary audit showed that the guest's `ANativeActivity_onCreate` is only
the stock `android_native_app_glue`: it allocates `android_app`, installs standard
callbacks and starts a thread that calls `android_main`. The adapter reproduces
that observable setup under `nxandroid` and delegates directly to the real
`android_main`, which remains owner of the game loop. The public migration uses
the current NextOS framework instead of the legacy monolithic loader.

The physical evidence is deliberately split by hardware and artifact:

| Target | Evidence | Status |
|---|---|---|
| ArkOS, Mali-G31, 640×480 | Predecessor `5b46a16d…` reached gameplay with video, audio, input and persistent save. Final `ff934a4a…` had its SHA-256 verified on-device and reached the title through the NXExtract marker fast path, pinned modules, pad 1, nxgl, Pulse/ALSA audio, `FRAMEWORK READY` and native CREATE/START. | Exact final binary quick boot proven; full gameplay acceptance remains tied to the predecessor candidate |
| NextOS, Mali-450 / Utgard, 1280×720 | Predecessor `5b46a16d…` completed a clean NXExtract install and reached gameplay at about 60 fps with audio, input and save. Final `ff934a4a…` had its SHA-256 verified on-device and passed the same quick-boot path to the title. | Exact final binary quick boot proven; predecessor gameplay proven; the one-pixel tile grid remains an accepted known limitation |
| Any other device family | None | Unsupported until the exact same ZIP and SHA-256 pass there |

Version 1.0.0-rc.1 is therefore a private-test release candidate, not evidence
of universal device support. The exact packaged ZIP/SHA-256 still needs a
physical install and full gameplay retest; passing host gates does not replace
that proof.

### Architecture

- `nxloader` strictly loads the two pinned ARMv7 Android modules: FMOD Ex first,
  then the Abstraction Games engine. Relocation, import resolution, ARM/Thumb
  hooks, soft-float call boundaries, final protection and initializers retain
  their native order.
- The audited fixed guest currently asks the dynamic façade only for the exact
  OpenSL ES surface and `__android_log_write` through `RTLD_DEFAULT`. The façade
  still retains a generic host `dlopen`/`dlsym` compatibility fallback, however;
  replacing it with an exact OpenSL magic handle, the explicit log symbol and
  rejection of everything else remains post-RC hardening work.
- `nxandroid` describes the delegated NativeActivity lifecycle without inventing
  Java callbacks or skipping `android_main`.
- `nxcompat` probes the host and accepts the runtime only after the graphics,
  input and audio receipts satisfy the manifest requirements.
- `nxgl` owns the SDL/EGL/GLES2 window and share root. The guest EGL façade
  creates child contexts and keeps the engine's single swap/present path.
- `nxinput` owns the one SDL event pump and translates the firmware controller
  mapping to the Android input queue.
- `nxaudio` validates the FMOD Ex → OpenSL ES → SDL output contract; the guest's
  queued PCM remains under the narrow per-game shim.
- `nxgenerator` 0.2.0 and `nxbootstrap` 0.6.4 produce one foreground PortMaster
  launcher. A second public `run.sh` is forbidden.
- NXExtract 1.2.6 installs owner-provided data transactionally. `nxabi` and
  `nxrelease` audit every packaged ELF and reopen the deterministic ZIP.
  `nxobs` is used only on the host to sanitize a support bundle; neither raw
  logs nor that bundle belongs in the public ZIP.

### Tile-grid diagnosis and attempted mitigation

The historical grid is not present in the artwork. Captured tilemap vertices
have exact adjacent 16×16 geometry and exact 16/1024 atlas spans. The stronger
explanation is precision at the atlas edge: Mali-400/450 fragment arithmetic is
FP16, so an interpolated coordinate in the upper half of a 1024-pixel atlas can
round into the neighbouring tile. A transparent neighbour is discarded and the
clear colour remains visible as a one-pixel line.

An offline FP16 replay of the captured title tilemap predicted 291 samples one
texel beyond their intended horizontal tile. A structural quarter-texel inset
removed all predicted excursions without dropping either edge texel in that
model. The candidate therefore recognizes only the Titan Souls 16×16 tilemap
quad layout, moves each UV endpoint by 0.25/1024 in U and V, and promotes only
the hueshift shader's UV varying from `lowp` to `mediump`. It does not globally
change texture wrapping, filtering, unrelated shaders or geometry.

The physical Mali-450 test still showed the grid with both changes active. The
simulation exposed a real precision hazard, but that hazard is not a sufficient
explanation or the dominant path on this driver. The port carries the narrow
mitigation without claiming a fix, and the grid remains a known visual
limitation. The next discriminating experiments are a discard-colour probe on
Utgard, a geometry-edge/vertex-rounding A/B, and—only if sampling is proven—the
standard half-texel or an extruded-border atlas approach. The clean Mali-G31
result cannot classify the Utgard defect. Relevant precision background is
available from Arm's
[mobile GPU precision benchmark](https://community.arm.com/arm-community-blogs/b/mobile-graphics-and-gaming-blog/posts/benchmarking-floating-point-precision-in-mobile-gpus)
and [Mali-400 texture-coordinate discussion](https://community.arm.com/support-forums/f/mobile-graphics-and-gaming-forum/9384/incorrect-drawing-image-with-wayland-on-mali400).

### Controls

- Left stick and D-pad: native movement axes.
- Face, shoulder and stick buttons: native Android gamepad buttons.
- Start: native game menu.
- Select + Start: orderly exit through the same shutdown request used by
  `SIGTERM`.

The launcher exports the firmware's controller mapping only when it is nonempty.
It does not capture the D-pad for a cursor and does not force SDL video or audio
drivers.

### Owner data and installation

Use a lawfully obtained Android v1.0.3 copy. NXExtract identifies inputs by
content rather than by their filename and accepts the pinned `armeabi-v7a`
engine/FMOD libraries, APK assets and `main.31.com.devolver.titansouls.obb`.
See [INSTALLATION.md](INSTALLATION.md) for the public package layout.

### Build and host gates

```bash
# Run from this port directory (the standalone repository root).
# Monorepo checkout only: cd ports/titansouls
export NEXTOS_SDK_ROOT=/path/to/sdk-or-armhf-sysroot
export NEXTOS_FRAMEWORK_ROOT=/path/to/framework
export NXEXTRACT_SOURCE_ROOT=/path/to/canonical-nxextract
./build_universal.sh
python3 -B "$NXEXTRACT_SOURCE_ROOT/nxextract.py" \
  recipe-check --recipe extractor.json
python3 -B "$NEXTOS_FRAMEWORK_ROOT/nxabi/nxabi.py" \
  audit build/titansouls-nextos
python3 -B "$NEXTOS_FRAMEWORK_ROOT/nxrelease/nxrelease.py" validate \
  --manifest nxrelease.json
# Or run all generation/build/ABI/release gates into a new destination:
./package/build-package.sh /path/to/new-release-directory
```

Inside the integration monorepo, the framework and NXExtract roots are found
automatically; `NEXTOS_SDK_ROOT` remains explicit. A standalone source checkout
must set all three roots shown above. The package recipe materializes the
generated launcher and redistributable runtimes outside the tracked source
allowlist.

The public executable is named `titansouls-nextos`. Its release profile is
ARMHF with a declared minimum glibc of 2.28 and a hard ceiling of 2.30. The
final gate checks every Linux ELF, not only the game loader. Android owner
libraries are validated by NXExtract and are never packaged.

### Source map and licences

- `src/main.c`, `src/ts_loader.c`: native sequence and strict two-module loader.
- `src/lifecycle.c`, `src/framework_bridge.c`: nxandroid lifecycle and nxcompat
  receipts/readiness.
- `src/egl_shim.c`: guest EGL façade over nxgl.
- `src/android_shim.c`: Android looper/input façade over nxinput.
- `src/opensles_shim.c`: FMOD/OpenSL queue bridge validated by nxaudio.
- `src/imports.c`, `src/tilemap_uv_fix.h`: guest import façade, hueshift UV
  precision promotion and tilemap UV correction.
- `extractor.json`: port-specific BYO-data recipe. The canonical NXExtract 1.2.6
  runtime is materialized only in `.build/` and the public ZIP.
- `port-env.sh`: separates the guest's `LOG.txt` from `log.txt` on
  case-insensitive filesystems.
- `build_universal.sh`, `nxrelease.json`: low-glibc build and public package
  gates.

The NextOS loader and integration are GPL-3.0-only; see `LICENSE`. NXExtract is
MIT-licensed; see `licenses/NXExtract-MIT.txt`. Titan Souls, its Android engine,
FMOD Ex binary, artwork, music and other owner data remain under their respective
rightsholders' terms and are outside these licences. See `NOTICE.md`.

## Português

### Estado e limite da validação

Titan Souls percorre seu fluxo Android nativo por um loader de compatibilidade
Linux ARMHF. A auditoria binária mostrou que `ANativeActivity_onCreate` contém
somente o `android_native_app_glue` padrão: cria `android_app`, instala callbacks
e abre uma thread que chama `android_main`. O adapter reproduz esse resultado
observável sob `nxandroid` e delega diretamente ao `android_main` real, que
continua dono do loop. A migração usa o framework atual do NextOS no lugar do
loader monolítico legado.

A evidência física está separada por hardware e por artefato:

| Alvo | Evidência | Estado |
|---|---|---|
| ArkOS, Mali-G31, 640×480 | O predecessor `5b46a16d…` chegou ao gameplay com vídeo, áudio, controle e save persistente. O `ff934a4a…` final teve SHA-256 conferido no aparelho e chegou ao título pelo fast path do marcador NXExtract, módulos pinados, pad 1, nxgl, áudio Pulse/ALSA, `FRAMEWORK READY` e CREATE/START nativos. | Boot rápido do binário final exato provado; a aceitação de gameplay completo ainda pertence ao candidato predecessor |
| NextOS, Mali-450 / Utgard, 1280×720 | O predecessor `5b46a16d…` fez instalação limpa pelo NXExtract e chegou ao gameplay a cerca de 60 fps com áudio, controle e save. O `ff934a4a…` final teve SHA-256 conferido no aparelho e passou pelo mesmo boot rápido até o título. | Boot rápido do binário final exato provado; gameplay provado no predecessor; a grade de um pixel permanece como limitação conhecida aceita |
| Qualquer outra família | Nenhuma | Sem suporte até o mesmo ZIP e SHA-256 passar nela |

Logo, a versão 1.0.0-rc.1 é candidata de teste privado, não prova de suporte
universal. O ZIP/SHA-256 empacotado exato ainda requer instalação física e novo
teste completo de gameplay; gate de host não substitui essa prova.

### Arquitetura

- `nxloader` carrega estritamente os dois módulos Android ARMv7 pinados: FMOD Ex
  primeiro e depois a engine da Abstraction Games. Relocação, imports, hooks
  ARM/Thumb, fronteiras soft-float, proteção final e inicializadores preservam a
  ordem nativa.
- O guest fixo auditado pede à fachada dinâmica somente a superfície OpenSL ES
  exata e `__android_log_write` via `RTLD_DEFAULT`. A fachada ainda preserva um
  fallback genérico de compatibilidade por `dlopen`/`dlsym`; trocá-lo pelo magic
  handle exato de OpenSL, pelo símbolo explícito de log e rejeição do restante é
  hardening posterior a este RC.
- `nxandroid` descreve o lifecycle delegado de NativeActivity sem inventar
  callbacks Java nem pular o `android_main`.
- `nxcompat` sonda o host e só libera o runtime quando os recibos de vídeo,
  entrada e áudio satisfazem o manifesto.
- `nxgl` é dono da janela e da raiz compartilhada SDL/EGL/GLES2. A fachada EGL
  do guest cria contextos filhos e preserva o único swap/present da engine.
- `nxinput` é dono do único pump de eventos SDL e traduz o mapping do firmware
  para a fila de entrada Android.
- `nxaudio` valida o contrato FMOD Ex → OpenSL ES → SDL; o PCM enfileirado pelo
  guest permanece no shim estreito deste jogo.
- `nxgenerator` 0.2.0 e `nxbootstrap` 0.6.4 geram um único launcher PortMaster em
  foreground. Um segundo `run.sh` público é proibido.
- NXExtract 1.2.6 instala os dados do dono de forma transacional. `nxabi` e
  `nxrelease` auditam cada ELF empacotado e reabrem o ZIP determinístico.
  `nxobs` serve somente para sanitizar um bundle de suporte no host; nem logs
  brutos nem esse bundle entram no ZIP público.

### Diagnóstico e mitigação tentada para a grade

A grade histórica não faz parte da arte. Os vértices capturados do tilemap têm
geometria adjacente exata de 16×16 e intervalos exatos de 16/1024 no atlas. A
explicação mais forte é a precisão na borda: a aritmética de fragmento do
Mali-400/450 é FP16, então uma coordenada interpolada na metade superior de um
atlas de 1024 pixels pode arredondar para o tile vizinho. Se ele for transparente,
o fragmento é descartado e a cor de limpeza aparece como linha de um pixel.

Uma reprodução offline em FP16 do tilemap capturado no título previu 291 amostras
um texel além do tile horizontal correto. Um recuo estrutural de um quarto de texel
eliminou todas as excursões previstas sem perder os texels das bordas no modelo.
A implementação é estreita: reconhece o layout de quads 16×16 de Titan Souls e
move somente as extremidades UV em 0,25/1024 em U e V. Ela também promove apenas
o varying UV do shader hueshift de `lowp` para `mediump`. Não muda globalmente
wrap, filtro, outros shaders ou geometria.

O teste físico no Mali-450 ainda mostrou a grade com as duas mudanças ativas.
Portanto, a simulação revelou um risco real de precisão, mas não explica sozinha
o caminho dominante nesse driver. O port mantém a mitigação estreita sem chamá-la
de correção, e a grade permanece como limitação visual conhecida. Os próximos
testes discriminantes são colorir o caminho de `discard` no Utgard, comparar
cobertura geométrica/arredondamento do vertex e, somente se a amostragem for
provada, tentar meio texel padrão ou atlas com bordas extrudadas. O Mali-G31 já
era limpo e não classifica o defeito Utgard.

### Controles

- Analógico esquerdo e D-pad: eixos nativos de movimento.
- Botões frontais, ombros e cliques dos analógicos: botões Android nativos.
- Start: menu nativo.
- Select + Start: saída ordenada pelo mesmo pedido usado por `SIGTERM`.

O launcher só exporta o mapping do firmware quando ele não está vazio. Não rouba
o D-pad para cursor e não força driver SDL de vídeo ou áudio.

### Dados do dono e instalação

Use uma cópia Android v1.0.3 obtida legalmente. O NXExtract identifica os arquivos
pelo conteúdo, não pelo nome, e aceita as bibliotecas `armeabi-v7a` pinadas, os
assets do APK e `main.31.com.devolver.titansouls.obb`. Veja
[INSTALLATION.md](INSTALLATION.md) para a árvore do pacote público.

### Compilação, fontes e licenças

Os comandos e o mapa de fontes da seção em inglês valem igualmente aqui. O
executável público chama-se `titansouls-nextos`; o perfil ARMHF declara glibc
mínima 2.28 e recusa qualquer ELF Linux acima de GLIBC_2.30.

O loader e a integração NextOS são GPL-3.0-only. NXExtract é MIT. Titan Souls,
a engine Android, o binário FMOD Ex, arte, música e demais dados do dono continuam
sob os termos dos respectivos titulares e não entram no pacote público.
