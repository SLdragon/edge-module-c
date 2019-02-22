FROM mcr.microsoft.com/windows/nanoserver:1809
WORKDIR /app
ADD BinariesToCopy/ /app
ADD vscproject.exe /app
CMD ["vscproject.exe"] 