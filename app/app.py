#!/usr/bin/env python3

from flask import Flask, request, jsonify
from azure.cosmos import CosmosClient, exceptions, PartitionKey
import requests
import os
import ssl
import base64
import sys
from pathlib import Path

# Environment variables used in this application:
# 1. ENABLE_COSMOS_DB - Set to 'true' to enable Cosmos DB operations
# 2. COSMOS_ENDPOINT - The endpoint URL for Azure Cosmos DB (required if ENABLE_COSMOS_DB=true)
# 3. COSMOS_KEY - The access key for Azure Cosmos DB (required if ENABLE_COSMOS_DB=true)
# 4. DATABASE_NAME - The name of the Cosmos DB database (required if ENABLE_COSMOS_DB=true)
# 5. CONTAINER_NAME - The name of the Cosmos DB container (required if ENABLE_COSMOS_DB=true)
# 6. TARGET_URL - Target URL for the service-to-service endpoint (required for /s2s endpoint)
# 7. USE_HTTPS - Set to 'true' to enable HTTPS server (defaults to 'false')
# 8. CERT_PATH - Path to SSL certificate file (required if USE_HTTPS=true)
# 9. KEY_PATH - Path to SSL key file (required if USE_HTTPS=true)

app = Flask(__name__)

# Initialize Cosmos DB client if feature flag is set
if os.getenv('ENABLE_COSMOS_DB') == 'true':
    COSMOS_ENDPOINT = os.getenv('COSMOS_ENDPOINT')
    COSMOS_KEY = os.getenv('COSMOS_KEY')
    DATABASE_NAME = os.getenv('DATABASE_NAME')
    CONTAINER_NAME = os.getenv('CONTAINER_NAME')

    if not COSMOS_ENDPOINT or not COSMOS_KEY or not DATABASE_NAME or not CONTAINER_NAME:
        error_message = "One or more required environment variables (COSMOS_ENDPOINT, COSMOS_KEY, DATABASE_NAME, CONTAINER_NAME) are not set."
        app.logger.error(error_message)
        raise EnvironmentError(error_message)

    client = CosmosClient(COSMOS_ENDPOINT, COSMOS_KEY)
    database = client.create_database_if_not_exists(id=DATABASE_NAME)
    container = database.create_container_if_not_exists(
        id=CONTAINER_NAME,
        partition_key=PartitionKey(path="/id"),
        offer_throughput=400
    )

@app.route("/")
def hello():
    return "Hello World!"

@app.route('/sum', methods=['POST'])
def sum():
    num1 = request.json['num1']
    num2 = request.json['num2']
    result = num1 + num2
    return {'result': result}

@app.route("/s2s")
def get():

    url = os.getenv('TARGET_URL')
    if not url:
        return "Environment variable TARGET_URL not set", 500
    
    response = requests.get(url)
    return response.text

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

    # Use environment variable to determine whether to run HTTP or HTTPS
    if os.environ.get("USE_HTTPS").lower() == "true":
        # Check for certificate path environment variables
        cert_path = os.environ.get("CERT_PATH")
        key_path = os.environ.get("KEY_PATH")
        
        # Validate certificate paths exist
        if not cert_path or not os.path.exists(cert_path):
            print(f"Error: Certificate file not found at path: {cert_path}")
            print("Please set CERT_PATH environment variable to a valid certificate file path.")
            exit(1)
            
        if not key_path or not os.path.exists(key_path):
            print(f"Error: Key file not found at path: {key_path}")
            print("Please set KEY_PATH environment variable to a valid key file path.")
            exit(1)
            
        # Run HTTPS server with certificate from environment variable path
        try:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS)
            context.load_cert_chain(cert_path, keyfile=key_path)
            app.run(host='0.0.0.0', port=8443, ssl_context=context)
        except Exception as e:
            print(f"Error loading certificates: {e}")
            exit(1)
    else:
        # Run HTTP server
        app.run(host='0.0.0.0', port=8080)