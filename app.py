from flask import Flask, request
import requests
import os

app = Flask(__name__)

@app.route('/sum', methods=['POST'])
def sum():
    num1 = request.json['num1']
    num2 = request.json['num2']
    result = num1 + num2
    return {'result': result}

@app.route("/")
def hello():

    url = os.getenv('TARGET_URL')
    if not url:
        return "Environment variable TARGET_URL not set", 500
    
    response = requests.get(url)
    return response.text

if __name__ == '__main__':
    app.run(debug=True)