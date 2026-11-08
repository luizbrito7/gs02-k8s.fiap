# Ambiente: criar e destruir

Passo a passo para subir a FIAP Store do zero e para destruir tudo sem deixar recurso cobrando. Todos os comandos partem da raiz do repositório.

| Etapa | Tempo aproximado |
|---|---|
| ECR e role do CI (só na primeira vez) | 1 min |
| `terraform apply` (rede, EKS, Argo CD, Secrets) | 20 min |
| Argo CD sincronizar tudo (9 Applications) | 5 min |
| Certificado TLS, DNS e primeira execução do CronJob | até 15 min |

## Pré-requisitos

- AWS CLI com o profile `delta`, Terraform ≥ 1.16, kubectl e Docker.
- Domínio na Cloudflare com SSL/TLS no modo **Full**.
- API token da Cloudflare com `Zone:DNS:Edit` e `Zone:Zone:Read` na zona (usado pelo external-dns e pelo cert-manager).

## Criar

### 1. ECR e role do CI

Só na primeira vez. Fica num state separado e sobrevive ao destroy do cluster, junto com as imagens.

```bash
cd terraform/ecr
terraform init && terraform apply
cd ../..
```

Cria os repositórios `store-api`, `store-worker` e `store-front` (tags imutáveis, scan no push) e a role `github-ecr-gs-lab`, que o GitHub Actions assume por OIDC.

### 2. Imagens

As versões fixas usadas na demonstração foram publicadas uma vez à mão:

```bash
REGISTRY=345843269906.dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password --profile delta --region us-east-1 | docker login -u AWS --password-stdin $REGISTRY
docker build -t $REGISTRY/store-api:1.0 app/store-api && docker push $REGISTRY/store-api:1.0
docker build --build-arg APP_VERSION=2.0 -t $REGISTRY/store-api:2.0 app/store-api && docker push $REGISTRY/store-api:2.0
docker build -t $REGISTRY/store-worker:1.0 app/store-worker && docker push $REGISTRY/store-worker:1.0
docker build -t $REGISTRY/store-front:1.2 app/store-front && docker push $REGISTRY/store-front:1.2
```

Depois disso, cada push em `app/` dispara o CI ([`images.yml`](../.github/workflows/images.yml)):

1. build das 3 imagens e scan do trivy (falha com `CRITICAL` ou `HIGH`);
2. push no ECR com a tag `sha-<commit>`, com credencial temporária via OIDC (nenhuma chave guardada no GitHub);
3. commit das tags novas em [`k8s/fiap-store/kustomization.yaml`](../k8s/fiap-store/kustomization.yaml): o Argo CD vê o commit e faz o rollout.

Para rodar o CI à mão: `gh workflow run images.yml`.

### 3. Secrets

Nenhum valor vai para o Git. O token da Cloudflare fica num arquivo ignorado pelo Git:

```bash
echo 'cloudflare_api_token = "<token>"' > terraform/terraform.tfvars
```

O Terraform cria no cluster:

| Secret | Namespaces | Origem |
|---|---|---|
| `store-db-credentials` (chave `password`) | `store-prod`, `store-data` | senha aleatória (`random_password`) |
| `cloudflare-api-token` (chave `api-token`) | `external-dns`, `cert-manager` | `terraform.tfvars` |
| `store-tls` | `store-prod` | emitido pelo cert-manager (Let's Encrypt, DNS-01) |

### 4. Rede, cluster, Argo CD e Secrets

```bash
cd terraform
terraform init && terraform apply          # 78 recursos, ~20 min
$(terraform output -raw configure_kubectl)
cd ..
```

| Arquivo | O que cria |
|---|---|
| [`00-provider.tf`](00-provider.tf) | providers, nomes e autenticação no cluster |
| [`01-vpc.tf`](01-vpc.tf) | VPC em 3 AZs, subnets públicas e privadas, um NAT por AZ |
| [`02-eks.tf`](02-eks.tf) | EKS 1.35, 5 nós `t3.medium`, addons (VPC CNI com NetworkPolicy, EBS CSI, metrics-server) |
| [`03-argocd.tf`](03-argocd.tf) | Argo CD num NLB que só aceita IPs da Cloudflare, e a Application `root` |
| [`04-secrets.tf`](04-secrets.tf) | namespaces com Pod Security e os Secrets |

O endpoint do EKS só aceita o IP público de quem rodou o `apply`. Se o seu IP mudar, rode o `apply` de novo.

### 5. GitOps

A partir daqui o Argo CD aplica sozinho tudo que está em [`k8s/`](../k8s/). Acompanhar até as 9 Applications ficarem `Synced` e `Healthy`:

```bash
kubectl -n argocd get applications -w
```

### 6. Rollout por commit

O item B7 exige 2 revisões da `store-api`, e um cluster novo tem só uma. Trocar o `newTag` da `store-api` em [`k8s/fiap-store/kustomization.yaml`](../k8s/fiap-store/kustomization.yaml) (ex.: `"2.0"` → `"1.0"`), fazer commit e push.

### 7. Conferir

```bash
AWS_PROFILE=delta ./avaliacao/verifica-gs.sh https://loja.luizbrito6.com.br
```

O resultado da última execução está em [`avaliacao/resultado-verifica-gs.txt`](../avaliacao/resultado-verifica-gs.txt).

### Acessos

| O quê | Como |
|---|---|
| Loja | https://loja.luizbrito6.com.br |
| Argo CD (usuário `admin`) | https://argocd.luizbrito6.com.br, senha: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` |
| Grafana (usuário `admin`, dashboard "FIAP Store") | `kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80` e abrir http://localhost:3000, senha: `kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' \| base64 -d` |

## Destruir

A ordem importa: balanceadores e volumes são criados pelo Kubernetes, não pelo Terraform. Se o cluster sumir antes, eles ficam órfãos (e cobrando) e travam a exclusão da VPC.

```bash
# 1. Apagar a Application root: o finalizer apaga em cascata as Applications e tudo que elas criaram
kubectl -n argocd delete application root

# 2. Apagar o volume do banco (o StatefulSet mantém o PVC de propósito) e esperar EBS e NLB do Traefik sumirem
kubectl -n store-data delete pvc --all
kubectl get pv                                  # até ficar vazio
kubectl get svc -A | grep LoadBalancer          # só pode restar o argocd-server

# 3. Remover o Argo CD (leva o NLB dele) e depois o resto
cd terraform
terraform destroy -target=helm_release.argocd
terraform destroy
cd ..

# 4. Conferir que não sobrou nada
aws elbv2 describe-load-balancers --profile delta --region us-east-1 --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-volumes --profile delta --region us-east-1 --filters Name=tag-key,Values=kubernetes.io/created-for/pvc/name --query 'Volumes[].VolumeId'
```

O ECR fica. Para apagá-lo também: `cd terraform/ecr && terraform destroy`.

## Problemas conhecidos

| Sintoma | Causa | Solução |
|---|---|---|
| `terraform destroy` travado em `aws_vpc` com `DependencyViolation` | security group `k8s-elb-*` de um Classic LB antigo ficou na VPC | apagar o SG (`aws ec2 delete-security-group --group-id <id>`) e rodar o `destroy` de novo |
| `Minimum capacity N can't be greater than desired size` ao mudar o node group | o módulo EKS ignora `desired_size` depois da criação | ajustar antes com `aws eks update-nodegroup-config --scaling-config minSize=..,maxSize=..,desiredSize=..` |
| `verifica-gs.sh`: "Nao foi possivel falar com o cluster" com o cluster no ar | timeout do DNS local (`systemd-resolved`) | rodar de novo ou usar DNS público: `resolvectl dns <interface> 1.1.1.1 8.8.8.8` |
| `Error acquiring the state lock` | outro `terraform` rodando no mesmo state | esperar o outro terminar |
