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

## Licença

AGPL-3.0, a mesma do Tainá. Veja `LICENSE`.
