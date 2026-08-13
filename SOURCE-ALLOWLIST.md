# Source-only repository boundary / Limite do repositório de fontes

This repository is an explicit source allowlist. It contains only the
Titan Souls compatibility adapter, its tests, generated public launcher,
data-free extraction recipe, release metadata, documentation and port-specific
build/package recipes.

It does **not** contain copied NextOS framework source, NXExtract runtime or UI,
compiled executables or libraries, APK/OBB content, extracted game assets,
saves, logs or support bundles.

The test release asset is assembled outside the Git source tree from pinned
external framework/NXExtract inputs. Owner-provided Android data is never part
of either the source repository or the release asset.

---

Este repositório usa uma allowlist explícita. Ele contém somente o adapter de
compatibilidade de Titan Souls, testes, o launcher público gerado, receita de
extração sem dados, metadados de release, documentação e receitas de
build/pacote específicas do port.

Ele **não** contém cópias das fontes do framework NextOS, runtime/UI do
NXExtract, executáveis ou bibliotecas compiladas, conteúdo de APK/OBB, assets
extraídos, saves, logs ou bundles de suporte.

O asset de release de teste é montado fora da árvore Git a partir de entradas
externas pinadas do framework/NXExtract. Dados Android fornecidos pelo dono não
entram no repositório nem no asset de release.
