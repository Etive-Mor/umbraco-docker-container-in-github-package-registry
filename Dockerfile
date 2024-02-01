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