FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["PasswordlessWorkshop.Api/PasswordlessWorkshop.Api.csproj", "PasswordlessWorkshop.Api/"]
RUN dotnet restore "PasswordlessWorkshop.Api/PasswordlessWorkshop.Api.csproj"
COPY . .
WORKDIR "/src/PasswordlessWorkshop.Api"
RUN dotnet build "PasswordlessWorkshop.Api.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "PasswordlessWorkshop.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "PasswordlessWorkshop.Api.dll"]