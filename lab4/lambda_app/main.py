from fastapi import FastAPI

app = FastAPI()

@app.get("/hello")
def hello():
    return {"message": "Hello from FastAPI on AWS Lambda!"}

def handler(event, context):
    from mangum import Mangum
    asgi_handler = Mangum(app)
    return asgi_handler(event, context)