FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source
COPY app.py .

# Expose port
EXPOSE 5001

# Set environment variables for RabbitMQ (override in Kubernetes if needed)
ENV RABBITMQ_HOST=rabbitmq.rabbitmq.svc.cluster.local \
    RABBITMQ_USERNAME=user \
    RABBITMQ_PASSWORD=bitnami

CMD ["python", "app.py"]
