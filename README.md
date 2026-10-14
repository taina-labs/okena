# Okena

Okena (Tupi-Guarani: porta, entrada; ok = casa) e o codigo do app do Taina.
Taina e o produto: e o nome que a pessoa ve, busca na loja e le na interface.
Okena nunca aparece para quem usa.

## O que vive aqui

    api/openapi.yaml   o contrato da API JSON v1 (compartilhado com o backend)
    ios/               o app Swift (agora)
    android/           o app Kotlin (depois)
    design/            os tokens espelhados do Penpot

Identificadores das lojas: bundle iOS e application id Android, os dois
`io.taina.app`.

## O contrato

`api/openapi.yaml` e um documento OpenAPI 3.0.3 completo e autocontido: um
gerador de cliente Swift nao precisa de mais nada. Ele descreve a superficie
inteira do v1: sessao por token de dispositivo, pessoas, pastas e arquivos
(com upload, download e miniatura), lixeira, fotos, mural, pedidos de acesso,
armazenamento e saude.

Os `components` espelham o arquivo do kernel
(`ypy/api/openapi.components.yaml`), que e a fonte unica das formas de record
(zona, papel, envelope de erro, paginacao) e que o kernel protege com um teste
de conformidade. Os `paths` sao do box e vivem na tabela da
`tekoa/tecnico/RFC_005_API_E_APP.md`. Quando o kernel muda uma forma, este
espelho muda junto.

O documento esta em pt-BR, como o resto do Taina: e a lingua dos docs e da
interface, e o codigo (identificadores) fica em ingles.

## Autenticacao

O app nao usa sessao de cookie. Ele entra em `POST /api/v1/session` com usuario
e senha e recebe um **token de dispositivo** (`tnd_...`) uma unica vez; guarda
no Keychain e manda em `Authorization: Bearer <token>`. A revogacao (pela
propria pessoa ou pela zeladora) vale na requisicao seguinte.

## Regras que o app respeita

- **casa** e privada por padrao: cada pessoa concede leitura explicitamente.
- **praca** e partilhada por norma; colocar algo la e o proprio consentimento.
- A **zeladora** cuida da maquina e nao tem atalho para a casa de ninguem.
- Um box serve **uma** comunidade: sem troca de comunidade, sem feed entre
  instancias.
