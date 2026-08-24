# GitOps Repository

Repositório GitOps para gerenciar o ArgoCD e todas as aplicações do cluster via Git.

## Estrutura

```
.
├── apps/                          # Definições de aplicações (Helm/Kustomize/raw)
│   ├── example/                   # App de exemplo
│   └── sealed-secrets/            # Bitnami Sealed Secrets
├── clusters/                      # Estado desejado por cluster
│   ├── prod/                      # Cluster primário (hub - roda o ArgoCD)
│   │   ├── infrastructure/        # ingress, cert-manager, sealed-secrets
│   │   ├── platform/              # monitoring, logging, policies
│   │   ├── apps/                  # apps de negócio
│   │   └── apps.yaml              # App of Apps do cluster prod
│   └── dr/                        # Cluster de DR (spoke)
│       ├── infrastructure/
│       ├── platform/
│       ├── apps/
│       └── apps.yaml              # App of Apps do cluster dr
├── templates/                     # Templates reutilizáveis (Application, etc)
└── README.md
```

## Topologia

- **Hub-and-spoke**: ArgoCD roda no cluster `prod` e gerencia tanto `prod` quanto `dr`.
- **App of Apps**: cada cluster tem um `apps.yaml` que lista todas as Applications dele.

## Fluxo

1. ArgoCD é instalado manualmente uma única vez no cluster `prod`.
2. ArgoCD sincroniza `clusters/prod/apps.yaml` (root App of Apps).
3. O root App cria Applications filhas para `infrastructure/`, `platform/`, `apps/`.
4. O root App também cria um Application que aponta para `clusters/dr/apps.yaml`,
   que faz o ArgoCD sincronizar manifests no cluster `dr` (configurado como destination).

## Adicionar uma nova app

1. Crie os manifests em `apps/<nome>/` ou use um chart Helm.
2. Crie uma Application em `clusters/prod/apps/<nome>.yaml` (e `clusters/dr/...` se replicado).
3. Commit & push. ArgoCD sincroniza automaticamente (auto-sync habilitado).

## Secrets

Use **SealedSecrets**: criptografe secrets no Git, decifre no cluster via `sealed-secrets-controller`.
Para criar um secret:
```bash
echo -n mypassword | kubectl create secret generic db --dry-run=client \
  --from-file=password=/dev/stdin -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml > apps/<app>/sealed-secret.yaml
```
