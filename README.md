# GitOps Repository

Repositório GitOps para gerenciar múltiplos clusters Kubernetes via ArgoCD.

## Estrutura

```
.
├── _bootstrap/                     # Manifests aplicados manualmente 1x por cluster
│   ├── cluster-01/
│   │   └── project.yaml            # AppProject + ApplicationSet do cluster-01
│   └── cluster-02/
│       └── project.yaml            # AppProject + ApplicationSet do cluster-02
├── clusters/                       # Estado desejado por cluster
│   ├── cluster-01/
│   │   └── namespaces/             # 1 pasta por namespace gerenciado
│   │       ├── argocd/
│   │       └── nginx/
│   └── cluster-02/
│       └── namespaces/
│           └── argocd/
├── components/                     # Definições reutilizáveis (Helm/Kustomize)
│   ├── argocd/                     # Chart argo-cd + values
│   └── nginx/                      # Chart nginx + values
└── README.md
```

## Topologia

- **Clusters independentes**: cada cluster (`cluster-01`, `cluster-02`) roda seu próprio ArgoCD e gerencia apenas seu próprio estado.
- **AppProject + ApplicationSet por cluster**: o manifesto em `_bootstrap/<cluster>/project.yaml` cria um `AppProject` e um `ApplicationSet` que varre `clusters/<cluster>/namespaces/*` gerando uma `Application` por pasta.
- **Components compartilhados**: `components/*` é a fonte única de verdade para charts/values; cada `kustomization.yaml` de namespace apenas referencia o component correspondente.

## Fluxo

1. ArgoCD é instalado manualmente uma única vez no cluster.
2. Aplica-se `_bootstrap/<cluster>/project.yaml` (cria `AppProject` + `ApplicationSet`).
3. O `ApplicationSet` descobre as pastas em `clusters/<cluster>/namespaces/*` e gera uma `Application` por namespace.
4. Cada `Application` faz `kustomize build` da sua pasta e sincroniza no cluster (auto-sync + selfHeal habilitados, `CreateNamespace=true`).

## Adicionar um novo cluster

1. Crie `_bootstrap/cluster-XX/project.yaml` baseado em `_bootstrap/cluster-01/project.yaml` (trocar nome do `AppProject` e o `path` do gerador `git/directories` para `clusters/cluster-XX/namespaces/*`).
2. Crie `clusters/cluster-XX/namespaces/<ns>/kustomization.yaml` para cada namespace, referenciando o component em `components/<ns>`.
3. Instale o ArgoCD no novo cluster manualmente.
4. Aplique o bootstrap:
   ```bash
   kubectl --context cluster-XX apply -f _bootstrap/cluster-XX/project.yaml
   ```
5. Adicione o cluster como spoke (opcional) registrando um `Secret` `argocd/cluster-XX` em outro cluster que já tenha ArgoCD.

## Adicionar uma nova app em um cluster existente

1. Garanta que o `component` correspondente exista em `components/<app>/` (com `kustomization.yaml` e `values.yaml`).
2. Crie `clusters/<cluster>/namespaces/<app>/kustomization.yaml` referenciando o component:
   ```yaml
   ---
   resources:
     - ../../../../components/<app>
   ```
3. Commit & push. O `ApplicationSet` detecta a nova pasta e cria a `Application` automaticamente.

## Bootstrap via justfile

```bash
just bootstrap             # cluster-01
just bootstrap-cluster-02  # cluster-02
```

## Validação

```bash
just validate
```

Roda `kustomize build --enable-helm` em todos os namespaces de todos os clusters.

## Secrets

Use **SealedSecrets**: criptografe secrets no Git, decifre no cluster via `sealed-secrets-controller`.
Para criar um secret:
```bash
echo -n mypassword | kubectl create secret generic db --dry-run=client \
  --from-file=password=/dev/stdin -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml > components/<app>/sealed-secret.yaml
```
