# Demo for building Umbraco Docker images, and publishing to Github's Container Registry


A demo showing how to build Umbraco v13 in Docker with Github Actions, and then push the created Docker Image to a Github Packages registry.  The package created by this repo can be found at [https://github.com/liamlaverty/umbraco-docker-container-in-github-package-registry/pkgs/container/container-reg-test](https://github.com/liamlaverty/umbraco-docker-container-in-github-package-registry/pkgs/container/container-reg-test).

## Install Umbraco using the dotnet CLI

A step-by-step guide to install Umbraco using the Dotnet CLI is below. Replace `ContainerRegistryTest` with your intended Umbraco project name. 
See the official [Umbraco documentation for guidance on installing Umbraco](https://docs.umbraco.com/umbraco-cms/fundamentals/setup/install/install-umbraco-with-templates) for further details, or other installation techniques.

### Commands in short

Enter the commands below to quick-install the Umbraco project, details are outlined in [Detailed installation](#detailed-installation) section

```bash
dotnet new install Umbraco.Templates
dotnet new umbraco -n ContainerRegistryTest
dotnet new sln
dotnet sln add ContainerRegistryTest
dotnet build ./ContainerRegistryTest/
dotnet run ./ContainerRegistryTest/
```

### Detailed installation

A more detailed overview of the Umbraco installation

- Install Umbraco's project templates by running `dotnet new install Umbraco.Templates`
- Run `dotnet new umbraco -n ContainerRegistryTest` to create an empty Umbraco Project
- Optionally run `dotnet new sln` to create a dotnet `sln` solution file
- Optionally run `dotnet sln add ContainerRegistryTest` to add your `ContainerRegistryTest` project to your new `sln`
- build the application with `dotnet build ./ContainerRegistryTest/`
- run the application with `dotnet run ./ContainerRegistryTest/`


## Create `.dockerignore`

Create a file named `.dockerignore` inside of the Umbraco Project at the path `./ContainerRegistryTest/.dockerignore`. Take care to put this into the Umbraco project, rather than the top-level solution folder. 

Add the following lines to exclude the bin and obj folders from the resulting Docker Image

```bash
**/bin/
**/obj/
```

## Create the Dockerfile

Create a file in the top-level directory named `Dockerfile` - the file has no extension. Add the following code:

```dockerfile
# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/dotnet/sdk:8.0 as build-env
WORKDIR /src
COPY ["ContainerRegistryTest/ContainerRegistryTest.csproj", "."]

RUN dotnet restore
COPY . .
RUN dotnet publish ContainerRegistryTest/ContainerRegistryTest.csproj --configuration Release --output /publish

FROM mcr.microsoft.com/dotnet/sdk:8.0 as runtime-env
WORKDIR /publish
COPY --from=build-env /publish .
ENV ASPNETCORE_URLS "http://+:80"
EXPOSE 80
ENTRYPOINT [ "dotnet", "ContainerRegistryTest.dll"]
```

## Optionally Build the Dockerfile

This step is optional in your local environment, Github's actions will run the Docker commands. 

- Install Docker (see https://www.docker.com/products/docker-desktop/ for the easiest install)
- Build the image with `docker image build . --tag umbraco-docker-container-in-github-package-registry` 
  - This names the image `umbraco-docker-container-in-github-package-registry` in your local Docker installation

## Create Github Actions to build & publish your containerised Umbraco images

- Create the directory `./.github/workflows/` before starting

### Create `publish-umbraco-image-to-registry.yml` to build & publish the package as a Docker Image

This file is reproduced from Github's [documentation on publishing docker images]( https://docs.github.com/en/actions/publishing-packages/publishing-docker-images). It builds the application, and then pushes it to your repository's Packages URL. 

```yml
# See  for details

name: Create and publish a Docker image of the Umbraco application

# Configures this workflow to run every time a change is pushed to the branch `release`.
on:
  push:
    branches: ['release']

# Defines two custom environment variables for the workflow. These are used for the Container registry domain, and a name for the Docker image that this workflow builds.
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

# There is a single job in this workflow. It's configured to run on the latest available version of Ubuntu.
jobs:
  build-and-push-image:
    runs-on: ubuntu-latest
    # Sets the permissions granted to the `GITHUB_TOKEN` for the actions in this job.
    permissions:
      contents: read
      packages: write
      # 
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      # Uses the `docker/login-action` action to log in to the Container registry registry using the account and password that will publish the packages. Once published, the packages are scoped to the account defined here.
      - name: Log in to the Container registry
        uses: docker/login-action@65b78e6e13532edd9afa3aa52ac7964289d1a9c1
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      # This step uses [docker/metadata-action](https://github.com/docker/metadata-action#about) to extract tags and labels that will be applied to the specified image. The `id` "meta" allows the output of this step to be referenced in a subsequent step. The `images` value provides the base name for the tags and labels.
      - name: Extract metadata (tags, labels) for Docker
        id: meta
        uses: docker/metadata-action@9ec57ed1fcdbf14dcef7dfbe97b2010124a938b7
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
      # This step uses the `docker/build-push-action` action to build the image, based on your repository's `Dockerfile`. If the build succeeds, it pushes the image to GitHub Packages.
      # It uses the `context` parameter to define the build's context as the set of files located in the specified path. For more information, see "[Usage](https://github.com/docker/build-push-action#usage)" in the README of the `docker/build-push-action` repository.
      # It uses the `tags` and `labels` parameters to tag and label the image with the output from the "meta" step.
      - name: Build and push Docker image
        uses: docker/build-push-action@f2a1d5e99d037542a71f64918e516c093c6f3fc4
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

```


### (Optional) Create `build-umbraco.yml` to build your site with dotnet

The following github action is optional. It will build an Umbraco application in dotnet and then run unit tests. It does nothing with Docker, but is useful as a first-stage build workflow as it runs common CI/CD steps. 

```yml
# This workflow will build a .NET project
# For more information see: https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-net

name: .NET Umbraco build

on:
  push:
    branches: [ "main", "stage", "develop" ]
  pull_request:
    branches: [ "main", "develop" ]

jobs:
  build:

    runs-on: ubuntu-latest
    env: 
      working-directory: './ContainerRegistryTest'
      
    steps:
    - name: checkout source
      uses: actions/checkout@v3
    
    - name: Setup .NET
      uses: actions/setup-dotnet@v3
      with:
        dotnet-version: 8.0.x
    
    - name: Restore dependencies
      working-directory: ${{env.working-directory}}
      run: dotnet restore
    
    - name: Build
      working-directory: ${{env.working-directory}}
      run: dotnet build --no-restore
    
    - name: Test
      working-directory: ${{env.working-directory}}
      run: dotnet test --no-build --verbosity normal
```

### (Optional) Create `docker-build-umbraco-image.yml` to build your Umbraco site with dotnet into a Docker image

The following github action is optional. It will build a Docker image of the Umbraco application.

```yml
name: Docker Build Umbraco Image

on:
  push:
    branches: [ "main", "stage", "develop" ]
  pull_request:
    branches: [ "main", "develop" ]

jobs:  
  build-umbraco-container:

    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3
    - name: Build Umbraco Docker image
      run: docker build . --file ./Dockerfile --tag my-image-name:$(date +%s)

```

