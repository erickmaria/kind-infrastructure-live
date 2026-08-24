# Justfile - Comandos úteis para o repo GitOps

# Bootstrap: aplicar o root Application manualmente (apenas uma vez)
bootstrap:
	kubectl apply -f _bootstrap/cluster-01/project.yaml

# Bootstrap do cluster-02 (aplicar manualmente apontando para o novo cluster)
bootstrap-cluster-02:
	kubectl apply -f _bootstrap/cluster-02/project.yaml

# Validar manifests com kustomize
validate:
	kustomize build clusters/cluster-01/namespaces/argocd --enable-helm
	kustomize build clusters/cluster-01/namespaces/nginx --enable-helm
	kustomize build clusters/cluster-02/namespaces/argocd --enable-helm

# Ver diff antes de aplicar
diff:
	kubectl diff -k clusters/prod --server-side

# Criar SealedSecret
seal-secret:
	@echo "Uso: just seal-secret <nome> <namespace> <chave>=<valor>"
	@echo "Ex: just seal-secret db example password=supersecret"

# Gerar exemplo de SealedSecret
seal-example:
	echo -n "supersecret" | \
	kubectl create secret generic example-secret \
	  --namespace=example \
	  --from-file=password=/dev/stdin \
	  --dry-run=client -o yaml | \
	kubeseal --controller-name=sealed-secrets \
	  --controller-namespace=sealed-secrets \
	  -o yaml > apps/example/sealed-secret.yaml

# Ver logs do ArgoCD
logs:
	kubectl -n argocd logs deployment/argocd-repo-server -f

# Status das apps
status:
	kubectl -n argocd get applications

# Sincronizar uma app específica
sync:
	@echo "Uso: just sync <nome-da-app>"
	@kubectl -n argocd patch app $(NAME) -p '{"operation":{"sync":{}}}' --type merge

# Ver recursos de uma app
resources:
	@echo "Uso: just resources <nome-da-app>"
	@kubectl -n argocd get app $(NAME) -o jsonpath='{.status.resources}'