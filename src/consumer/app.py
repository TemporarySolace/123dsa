from flask import Flask, jsonify
import pika, os

app = Flask(__name__)

@app.route('/')
def consume():
    rabbitmq_host = os.environ.get("RABBITMQ_HOST", "rabbitmq.rabbitmq.svc.cluster.local")
    rabbitmq_user = os.environ.get("RABBITMQ_USERNAME", "user")
    rabbitmq_pass = os.environ.get("RABBITMQ_PASSWORD", "bitnami")

    credentials = pika.PlainCredentials(rabbitmq_user, rabbitmq_pass)
    parameters = pika.ConnectionParameters(host=rabbitmq_host, credentials=credentials)

    connection = pika.BlockingConnection(parameters)
    channel = connection.channel()

    # Ensure the task_queue exists
    channel.queue_declare(queue='task_queue', durable=True)

    method_frame, header_frame, body = channel.basic_get(queue='task_queue', auto_ack=True)
    message = body.decode() if body else "No message"

    connection.close()
    return jsonify({"status": "Consumed", "message": message})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
