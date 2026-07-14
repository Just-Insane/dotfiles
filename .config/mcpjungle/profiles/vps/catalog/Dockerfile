FROM python:3.13-slim

RUN pip install --no-cache-dir "fastmcp[tasks]==3.4.4"

WORKDIR /app
COPY server.py /app/server.py

USER 65532:65532
EXPOSE 8000

CMD ["python", "/app/server.py"]
