from flask import Flask, request, jsonify
from azure.cosmos import CosmosClient, exceptions, PartitionKey
import os

app = Flask(__name__)

# Initialize Cosmos DB client
COSMOS_ENDPOINT = os.getenv('COSMOS_ENDPOINT')
COSMOS_KEY = os.getenv('COSMOS_KEY')
DATABASE_NAME = os.getenv('DATABASE_NAME')
CONTAINER_NAME = os.getenv('CONTAINER_NAME')

client = CosmosClient(COSMOS_ENDPOINT, COSMOS_KEY)
database = client.create_database_if_not_exists(id=DATABASE_NAME)
container = database.create_container_if_not_exists(
    id=CONTAINER_NAME,
    partition_key=PartitionKey(path="/id"),
    offer_throughput=400
)

@app.route('/sum', methods=['POST'])
def sum():
    num1 = request.json['num1']
    num2 = request.json['num2']
    result = num1 + num2
    return {'result': result}

@app.route("/")
def hello():
    return "Hello World!"

@app.route('/read', methods=['GET'])
def query_cosmos():
    query = "SELECT * FROM c"
    items = list(container.query_items(
        query=query,
        enable_cross_partition_query=True
    ))
    return jsonify(items)

@app.route('/write', methods=['POST'])
def write_cosmos():
    data = request.json
    container.create_item(body=data)
    return jsonify({'status': 'Item created successfully'})

if __name__ == '__main__':
    app.run(debug=True)