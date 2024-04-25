## ArgoCD with github actions for end-to-end CI/CD

Prerequisite
- A kubernetes cluster
- Any Sample application created in the above assignments
- Running argocd instance

```html
<!DOCTYPE html>
<Head>
<title>
Simplest page
</title>
<Head>
<h1> This is the simplest HTML page</h1>
```

Create a docker image and push it to dockerhub
Need to add the `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets in the github repository.

Setup a github action worflow in the sample application repository [.github/workflows/CI.yaml](https://github.com/rajatrj16/nginx-test-app/blob/master/.github/workflows/ci.yaml)

```yaml
name: CI
on:
  push:
    branches:
      - master
jobs:
  build:
    name: create-and-push-image
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - name: Checkout Repo
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v3
        with:
          context: .
          file: ./Dockerfile
          push: true
          tags: rajatrj16/nginx-test-app:${{ github.sha }}

      - name: Update Version
        run: |
          version=$(cat ./kubernetes/deployment.yaml | grep image: | awk '{print $2}' | cut -d ':' -f 2)
          echo "$version"
          sed -i "s/$version/${{ github.sha }}/" ./kubernetes/deployment.yaml
          cat ./kubernetes/deployment.yaml | grep image: | awk '{print $2}'
      
      - name: Commit and push changes
        uses: devops-infra/action-commit-push@v0.3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          commit_message: Image version updated
```

Argocd works with helm, Kustomize or plane manifests.

Plane manifests for the sample application [deployment.yaml](https://github.com/rajatrj16/nginx-test-app/blob/master/kubernetes/deployment.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test-app
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx-test-app
        image: rajatrj16/nginx-test-app:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test-app
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

Setup an application in argocd UI or using CLI
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-test-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/rajatrj16/nginx-test-app.git
    targetRevision: HEAD
    path: kubernetes
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      selfHeal: true
      Prune: true
      Replace: true
      allowEmpty: true
    syncOptions:
    - CreateNamespace=true
    - Prune=true
    - Replace=true
```
Make sure the appliation is sync to fetch and deploy the latest change from code repository.

Sync argocd app:

```yaml
argocd app sync nginx-test-app
```
