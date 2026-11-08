<h1 align="center">GS 02 — FIAP Store no Amazon EKS</h1>

<p align="center"><img src="docs/architecture/cloud.gif" alt="Arquitetura AWS: Cloudflare, VPC com subnets públicas e privadas em 3 AZs, NLBs, NAT por AZ, EKS, EBS e ECR" /></p>

A FIAP Store roda num cluster **Amazon EKS** criado por **Terraform** e entregue por **GitOps** com o **Argo CD**. O tráfego entra pelo proxy da **Cloudflare** (HTTPS na borda), passa pelos NLBs nas subnets públicas e chega aos nós nas subnets privadas. Cada AZ tem seu NAT Gateway para a saída.

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
| [`terraform/`](terraform/) | VPC, EKS, Argo CD e Secrets (o ECR fica em `terraform/ecr/`, com state próprio) |
| [`k8s/`](k8s/) | tudo que o Argo CD aplica no cluster |
| [`app/`](app/) | código e Dockerfiles da FIAP Store |
| [`avaliacao/`](avaliacao/) | script de correção do professor e relatórios do trivy |
| [`docs/`](docs/) | enunciado e diagramas |

## Integrantes

| Nome | RM |
|---|---|
| Anderson Huang | 565920 |
| Luiz Brito | 562192 |
