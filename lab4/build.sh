#!/bin/bash
cd lambda_app
pip install -r requirements.txt -t .
zip -r ../lambda_package.zip .
cd ..