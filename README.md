<h1 align="center">GS 02 — FIAP Store no Amazon EKS</h1>

<p align="center"><img src="docs/architecture/cloud.gif" alt="Arquitetura AWS: Cloudflare, VPC com subnets públicas e privadas em 3 AZs, NLBs, NAT por AZ, EKS, EBS, ECR e GitHub Actions" /></p>

A FIAP Store roda num cluster **Amazon EKS** criado por **Terraform** e entregue por **GitOps** com o **Argo CD**. O tráfego entra pelo proxy da **Cloudflare** (HTTPS na borda), passa pelos NLBs nas subnets públicas e chega aos nós nas subnets privadas. Cada AZ tem seu NAT Gateway para a saída.

| | |
|---|---|
| Loja | https://loja.luizbrito6.com.br |
| Argo CD | https://argocd.luizbrito6.com.br/applications/argocd/fiap-store |
| Correção | `./avaliacao/verifica-gs.sh https://loja.luizbrito6.com.br` → **80/80** |

## Arquiteturas

Cada contexto do laboratório tem o seu diagrama, junto do código que ele descreve:

| Contexto | O que mostra | Onde |
|---|---|---|
| Nuvem (AWS) | rede, cluster, balanceadores, registro e volumes | este README |
| GitOps | Terraform → Argo CD → app-of-apps → plataforma e FIAP Store | [k8s/README.md](k8s/README.md) |
| Aplicação | fluxo de requisições, fila, banco e isolamento por namespace | [app/README.md](app/README.md#arquitetura) |

## Estrutura

| Pasta | Conteúdo |
|---|---|
| [`terraform/`](terraform/) | VPC, EKS, Argo CD e Secrets |
| [`terraform/ecr/`](terraform/ecr/) | repositórios ECR e role do GitHub Actions (state próprio: sobrevivem ao destroy do cluster) |
| [`k8s/`](k8s/) | tudo que o Argo CD aplica no cluster |
| [`app/`](app/) | código e Dockerfiles da FIAP Store |
| [`.github/workflows/`](.github/workflows/) | CI: build, trivy e push das imagens no ECR |
| [`avaliacao/`](avaliacao/) | script de correção e relatórios do trivy |
| [`docs/`](docs/) | enunciado e diagramas |

> **Terraform no lugar do `cluster.yaml`:** o enunciado sugere `eksctl`. Usamos Terraform (módulos oficiais `terraform-aws-modules`) para criar rede, cluster, Argo CD e Secrets num único `apply`, e destruir tudo num único `destroy`.

## Pré-requisitos

- AWS CLI com o profile `delta`, Terraform ≥ 1.16, kubectl e Docker.
- Domínio na Cloudflare, com SSL/TLS no modo **Full** e um API token com `Zone:DNS:Edit` e `Zone:Zone:Read` na zona.

## Criar o ambiente do zero

**1. ECR e role do CI** (só na primeira vez; não é destruído junto com o cluster):

```bash
cd terraform/ecr && terraform init && terraform apply
```

**2. Imagens.** O CI publica a cada push em `app/` (tag `sha-<commit>`). As tags fixas usadas pelos manifestos foram publicadas uma vez à mão (os repositórios são imutáveis):

```bash
REGISTRY=345843269906.dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password --profile delta | docker login -u AWS --password-stdin $REGISTRY
docker build -t $REGISTRY/store-api:1.0 app/store-api && docker push $REGISTRY/store-api:1.0
docker build --build-arg APP_VERSION=2.0 -t $REGISTRY/store-api:2.0 app/store-api && docker push $REGISTRY/store-api:2.0
docker build -t $REGISTRY/store-worker:1.0 app/store-worker && docker push $REGISTRY/store-worker:1.0
docker build -t $REGISTRY/store-front:1.2 app/store-front && docker push $REGISTRY/store-front:1.2
```

**3. Secrets.** Nenhum valor vai para o Git. O token da Cloudflare fica num arquivo ignorado pelo Git:

```bash
echo 'cloudflare_api_token = "<token>"' > terraform/terraform.tfvars
```

O Terraform cria no cluster:

| Secret | Namespaces | Origem |
|---|---|---|
| `store-db-credentials` (chave `password`) | `store-prod`, `store-data` | senha aleatória (`random_password`) |
| `cloudflare-api-token` (chave `api-token`) | `external-dns`, `cert-manager` | `terraform.tfvars` |
| `store-tls` | `store-prod` | emitido pelo cert-manager (Let's Encrypt, DNS-01) |

**4. Cluster, Argo CD e Secrets** (~20 min):

```bash
cd terraform && terraform init && terraform apply
$(terraform output -raw configure_kubectl)
```

**5. GitOps.** A partir daqui o Argo CD aplica sozinho tudo que está em `k8s/`. Acompanhar até todas ficarem `Synced` e `Healthy`:

```bash
kubectl -n argocd get applications -w
```

**6. Conferir:** `./avaliacao/verifica-gs.sh https://loja.luizbrito6.com.br`

### Acessos

```bash
# Argo CD: usuário admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Grafana (dashboard "FIAP Store"): http://localhost:3000, usuário admin
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

## Destruir tudo

A ordem importa: balanceadores e volumes são criados pelo Kubernetes, não pelo Terraform. Se o cluster sumir antes, eles ficam órfãos (e cobrando).

```bash
# 1. Apagar a Application root: o finalizer apaga em cascata as Applications e tudo que elas criaram
kubectl -n argocd delete application root

# 2. Esperar os volumes EBS e o NLB do Traefik sumirem
kubectl get pv                                         # até ficar vazio
kubectl get svc -A | grep LoadBalancer                 # só pode restar o argocd-server

# 3. Remover o Argo CD (leva o NLB dele) e depois o resto
cd terraform
terraform destroy -target=helm_release.argocd
terraform destroy

# 4. Conferir que não sobrou nada
aws elbv2 describe-load-balancers --profile delta --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-volumes --profile delta --filters Name=tag-key,Values=kubernetes.io/created-for/pvc/name --query 'Volumes[].VolumeId'
```

O ECR fica (state separado). Para apagá-lo também, no fim do semestre: `cd terraform/ecr && terraform destroy`.

## Extras

| Extra | Onde |
|---|---|
| `store-data` em Pod Security `restricted` (Postgres e Redis como não-root) | [`k8s/fiap-store/10-store-data.yaml`](k8s/fiap-store/10-store-data.yaml) |
| CI que constrói, escaneia e publica no ECR | [`.github/workflows/images.yml`](.github/workflows/images.yml) (OIDC, sem chave de acesso) |
| Manifestos com Kustomize | [`k8s/fiap-store/kustomization.yaml`](k8s/fiap-store/kustomization.yaml) |
| Prometheus e Grafana com dashboard da FIAP Store | [`k8s/monitoring/`](k8s/monitoring/) |
| TLS emitido pelo cert-manager | [`k8s/platform/cluster-issuer.yaml`](k8s/platform/cluster-issuer.yaml) |

Além do pedido: imagens com base **Chainguard** (0 vulnerabilidades no trivy) e HTTPS na borda pela Cloudflare, com os balanceadores aceitando só os IPs dela.

## Uso de IA

Usamos o **Claude Code** (Anthropic) como par de programação, num ambiente configurado por nós:

| Recurso | Para quê |
|---|---|
| Claude Code (CLI) | escrever e revisar Terraform, manifests, Dockerfiles e READMEs; investigar falhas no cluster (`kubectl`, logs, eventos) |
| Skills | `architecture-diagrams` (diagramas animados com ícones oficiais), `systematic-debugging` (investigação de causa raiz), `brainstorming` (desenho da solução antes do código) |
| Plugins | Superpowers (fluxos de trabalho: debugging, planejamento, verificação antes de concluir) e Context7 (documentação atualizada de bibliotecas) |
| Harness configurado | regras globais no `CLAUDE.md` (respostas objetivas, YAGNI, KISS, sempre conferir a documentação oficial), hooks e o RTK para reduzir saída de comandos |

Toda mudança foi revisada e aplicada por nós (`terraform apply` sempre rodado por um integrante). Qualquer integrante explica qualquer arquivo deste repositório.

## Integrantes

| Nome | RM |
|---|---|
| Anderson Huang | 565920 |
| Luiz Brito | 562192 |
