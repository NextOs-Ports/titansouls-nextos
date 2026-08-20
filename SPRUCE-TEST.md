# Titan Souls — Spruce ARMHF private acceptance test

Test ID: `1.0.8-spruce-test.1`

This ZIP is an isolated Miyoo Flip/spruceOS test, not a public release. The
game remains ARMHF because the original Android build supplies only
`armeabi-v7a`; the setup UI is the canonical AArch64 NXExtract UI so it can run
in Spruce's already-working native 64-bit environment.

## Clean test

1. Remove both the previous `titansouls/` directory and the previous
   `Titan Souls.sh` launcher before extracting this ZIP.
2. Put the lawful Titan Souls 1.0.3 owner data described in `INSTALLATION.md`
   inside `titansouls/gamedata/`.
3. Launch from the Spruce/PortMaster frontend, not through SSH.
4. A valid first run must visibly show NXExtract, then NXSplash, then reach the
   game. Headless extraction is forbidden in this candidate.
5. Test video, music/SFX, controls, save and SELECT+START exit.

If the game does not boot, preserve these files without editing them:

- `titansouls/nxextract.log`
- `titansouls/nxextract-ui.log`
- `titansouls/titansouls-bootstrap.log`
- `titansouls/titansouls-runtime.log`
- `titansouls/nxextract-result.json`

The runtime log deliberately records the exact SDL video failure, the compiled
32-bit SDL backend list and access to `/dev/fb0`, `/dev/ion`, `/dev/mali0` and
DRM nodes. A non-zero result is intentional when a required layer fails; it
must never be reported as success.

---

# Teste privado Titan Souls — Spruce ARMHF

Este ZIP é um teste isolado para Miyoo Flip/spruceOS, não uma release pública.
O jogo continua ARMHF porque o Android original possui apenas `armeabi-v7a`;
a tela do NXExtract usa o artefato canônico AArch64, aproveitando o ambiente
64-bit do Spruce que já funciona corretamente.

## Teste limpo

1. Apague tanto a pasta antiga `titansouls/` quanto o launcher antigo
   `Titan Souls.sh` antes de extrair este ZIP.
2. Coloque os dados legais do dono descritos em `INSTALLATION.md` dentro de
   `titansouls/gamedata/`.
3. Inicie pelo frontend Spruce/PortMaster, nunca por SSH.
4. Na primeira execução correta devem aparecer, nesta ordem: NXExtract visível,
   NXSplash e jogo. Extração headless está proibida neste candidato.
5. Teste vídeo, música/efeitos, controles, save e saída por SELECT+START.

Se não iniciar, preserve sem editar os cinco arquivos de diagnóstico listados
acima. O log registra a causa exata devolvida pela SDL 32-bit; uma camada que
falhar encerra com erro real, nunca com sucesso falso.
