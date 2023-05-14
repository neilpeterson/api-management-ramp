from flask import Flask, request

app = Flask(__name__)

@app.route('/sum', methods=['POST'])
def sum():
    num1 = request.json['num1']
    num2 = request.json['num2']
    result = num1 + num2
    return {'result': result}

@app.route('/', methods=['POST'])
def sum():
    return {'result': 'You get me..'}

if __name__ == '__main__':
    app.run(debug=True)