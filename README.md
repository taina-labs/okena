# Okena

Okena (Tupi-Guarani: porta, entrada; ok = casa) é o código do app do Tainá.
Tainá é o produto: é o nome que a pessoa vê, busca na loja e lê na interface.
Okena nunca aparece para quem usa.

## O que vive aqui

    api/openapi.yaml   o contrato da API JSON v1, compartilhado com o backend
    ios/               o app Swift (agora)
    android/           o app Kotlin (depois)
    design/            os tokens espelhados do Penpot

Bundle iOS e application id Android: `io.taina.app`.

## O contrato

`api/openapi.yaml` é um documento OpenAPI 3.0.3 completo e autocontido: um
gerador de cliente Swift não precisa de mais nada. Ele cobre a superfície
inteira do v1: sessão por token de dispositivo, pessoas, pastas e arquivos
(com upload, download e miniatura), lixeira, fotos, mural, pedidos de acesso,
armazenamento e saúde.

Os `components` espelham o arquivo do kernel (`ypy/api/openapi.components.yaml`),
que é a fonte única das formas de record (zona, papel, envelope de erro,
paginação) e que o kernel protege com um teste de conformidade. Os `paths` são
do box e vivem na tabela da `RFC_005_API_E_APP.md`, no repositório `tekoa`.
Quando o kernel muda uma forma, este espelho muda junto.

## Autenticação

O app não usa sessão de cookie. Ele entra em `POST /api/v1/session` com usuário
e senha e recebe um token de dispositivo (`tnd_...`) uma única vez; guarda no
Keychain e manda em `Authorization: Bearer <token>`. A revogação, pela própria
pessoa ou pela zeladora, vale na requisição seguinte.

## Regras que o app respeita

- **casa** é privada por padrão: cada pessoa concede leitura explicitamente.
- **praça** é partilhada por norma; colocar algo lá é o próprio consentimento.
- A **zeladora** cuida da máquina e não tem atalho para a casa de ninguém.
- Um box serve **uma** comunidade: sem troca de comunidade, sem feed entre
  instâncias.

## Rodar o app

Precisa de Xcode 27 (Swift 6) e do XcodeGen.

```bash
brew install xcodegen

cd ios/Core && swift test        # o núcleo, sem interface
cd ios/App && xcodegen generate  # escreve Okena.xcodeproj
open Okena.xcodeproj
```

O projeto do Xcode é gerado, não fica no repositório: `project.yml` é a fonte da
verdade. Abra o `#Preview` de qualquer tela para vê-la funcionando contra uma
comunidade de mentira, sem caixa e sem rede.

Se o seu terminal exporta `SDKROOT`, `DEVELOPER_DIR`, `LD` ou `CFLAGS` (um dev
shell de Nix, por exemplo), o `xcodebuild` adota esses valores e falha ao ligar.
A chamada que funciona:

```bash
cd ios/App
env -u LD -u CC -u CXX -u CPPFLAGS -u LDFLAGS -u AR -u NM -u RANLIB \
    -u MACOSX_DEPLOYMENT_TARGET \
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
    xcodebuild -project Okena.xcodeproj -scheme Okena \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath .derived CODE_SIGNING_ALLOWED=NO build
```

### Duas armadilhas do simulador

- **Assinatura**: um build de simulador com `CODE_SIGNING_ALLOWED=NO` sai sem
  entitlements, o Keychain recusa a escrita (`errSecMissingEntitlement`) e o
  login falha com "Não foi possível guardar a sessão neste aparelho". Deixe a
  assinatura ad-hoc padrão do Xcode para rodar no simulador.
- **Primeiro setup**: o app começa na tela de Setup, então precisa de um
  endereço de verdade. Para pular as teclas em teste, o build de DEBUG lê
  `TAINA_HOST`, `TAINA_USERNAME` e `TAINA_PASSWORD` do ambiente, que o
  simulador entrega pelo prefixo `SIMCTL_CHILD_`:

```bash
SIMCTL_CHILD_TAINA_HOST=http://taina.yby \
SIMCTL_CHILD_TAINA_USERNAME=ana \
SIMCTL_CHILD_TAINA_PASSWORD=segredo \
  xcrun simctl launch --terminate-running-process booted io.taina.app
```

### Instalar no seu iPhone

Para usar o app num aparelho de verdade, o caminho mais curto é rodar do Xcode
com o seu Apple ID:

1. `cd ios/App && xcodegen generate`, depois abra `Okena.xcodeproj`.
2. Xcode > Settings > Accounts: adicione o seu Apple ID (uma conta gratuita
   serve).
3. Selecione o target **Okena** > *Signing & Capabilities* > marque
   *Automatically manage signing* e escolha o seu *Team*.
4. Se a assinatura reclamar do bundle id, troque `io.taina.app` por algo único
   (ex.: `io.taina.app.voce`). Nada no código depende dele além do serviço do
   Keychain, que fica como está.
5. No iPhone: Ajustes > Privacidade e Segurança > **Modo de Desenvolvedor** >
   ligue (o aparelho reinicia). Conecte por cabo e confie no computador.
6. Escolha o iPhone como destino no Xcode e rode (⌘R).
7. No iPhone: Ajustes > Geral > VPN e Gerenciamento de Dispositivo > confie no
   certificado.
8. Na tela de Setup do app, informe o endereço da caixa (um nome de tailnet, ou
   um IP na mesma rede). O app aceita `http` de propósito, e diz isso em voz
   alta.

Uma conta gratuita expira o app em 7 dias (rode de novo do Xcode). Uma conta
paga ($99/ano) vale um ano e libera o TestFlight, que é o caminho melhor para
mandar o app para outras pessoas.

O esquema de URL `taina` já está registrado (`project.yml`): os links de convite
e de redefinição de senha abrem o app, não o navegador. Para testar o deep link
sem tocar numa tela (simulador, script), o build de DEBUG lê `TAINA_DEEPLINK` no
boot, no mesmo molde do `TAINA_HOST`:

```bash
SIMCTL_CHILD_TAINA_DEEPLINK="taina://convite/TOKEN?host=http%3A%2F%2Ftaina.yby" \
  xcrun simctl launch --terminate-running-process booted io.taina.app
```

## Conferir contra uma caixa de verdade

O core traz um smoke executável que percorre a fatia mínima da API pela mesma
camada que o app usa. É a forma mais rápida de saber se o problema é da caixa ou
do cliente:

```bash
cd ios/Core
swift run okena-smoke http://taina.yby --user ana --password segredo --write
```

Sem `--write` ele só lê. Com `--write` ele cria a pasta `pasta-do-smoke`, sobe
`teste-do-smoke.txt`, baixa de volta e confere os bytes, pede a miniatura (que
um texto não tem) e diz o que deixou na comunidade. O token do aparelho nunca é
impresso.

### O que já existe

O `OkenaCore` cobre a API v1 inteira: instância e sessão por token de
dispositivo, quem está agindo, dispositivos, pessoas, pastas e arquivos (subir,
baixar, miniatura, renomear, mover, trocar de zona, apagar), lixeira, fotos,
mural, pedidos de acesso, armazenamento e saúde, mais o aceite de convite e a
redefinição de senha por deep link. Um método no protocolo `TainaAPI` por
endpoint.

O app tem as telas de Setup, Login, Início, Arquivos (com a lixeira), Fotos,
Mural, Moradores, Armazenamento, Saúde, Pedidos, Conta, e as de aceite de
convite e de redefinição de senha. Um modelo por tela, decisões em funções
puras.

As três fontes da marca vêm empacotadas em `Resources/Fonts`: os TTF variáveis
das mesmas famílias que a web auto-hospeda, com a licença OFL de cada uma. O
eixo `wght` é o mesmo nas duas pontas.

Falta: o ícone, a arte da tela de abertura, e o app Android.

## Licença

AGPL-3.0, a mesma do Tainá. Veja `LICENSE`.
