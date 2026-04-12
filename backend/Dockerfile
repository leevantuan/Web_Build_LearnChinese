# ============================================================
# Backend — ASP.NET runtime chỉ chạy DLL đã publish sẵn
# Image size: ~220MB (aspnet:9.0-alpine)
# ============================================================
FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine

WORKDIR /app

# Copy pre-published .NET output
COPY build/ .

# Create volume mount points
RUN mkdir -p /app/audio /app/uploads

ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://+:8080

EXPOSE 8080

ENTRYPOINT ["dotnet", "LearningChinese.API.dll"]
