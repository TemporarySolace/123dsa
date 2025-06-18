import pika, os
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/', methods=['POST'])
def produce():
    data = request.get_json()
    message = data.get('message', '')

    rabbitmq_host = os.environ.get("RABBITMQ_HOST", "rabbitmq.rabbitmq.svc.cluster.local")
    rabbitmq_user = os.environ.get("RABBITMQ_USERNAME", "user")
    rabbitmq_pass = os.environ.get("RABBITMQ_PASSWORD", "bitnami")

    credentials = pika.PlainCredentials(rabbitmq_user, rabbitmq_pass)
    parameters = pika.ConnectionParameters(host=rabbitmq_host, credentials=credentials)

    connection = pika.BlockingConnection(parameters)
    channel = connection.channel()

    # Ensure the task_queue exists
    channel.queue_declare(queue='task_queue', durable=True)

    channel.basic_publish(
        exchange='',
        routing_key='task_queue',
        body=message,
        properties=pika.BasicProperties(delivery_mode=2),
    )

    connection.close()
    return jsonify({"status": "Message sent"})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
