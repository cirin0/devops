# Детальне пояснення CloudFormation шаблону (template.yaml)

Цей шаблон описує інфраструктуру для деплойменту FastAPI на AWS Lambda за API Gateway. Він очікує, що ZIP з кодом уже завантажений у S3 бакет формату: <ProjectName>-code-<AccountId> з ключем fastapi-lambda.zip (це робить ваш deploy/update скрипт).

## Структура файлу

- AWSTemplateFormatVersion — версія формату шаблону.
- Description — короткий опис призначення стеку.
- Parameters — параметри, що можна задати при деплої (тут ProjectName).
- Resources — ресурси, які буде створено:
  - IAM роль для Lambda (LambdaExecutionRole)
  - Функція Lambda (FastAPIFunction)
  - Дозвіл для API Gateway викликати Lambda (ApiGatewayPermission)
  - API Gateway (ApiGateway)
  - Ресурс-проксі для всіх шляхів (ProxyResource)
  - Метод для проксі-ресурсу (ProxyMethod)
  - Метод для кореневого ресурсу (RootMethod)
  - Деплоймент API Gateway (ApiDeployment)
- Outputs — корисні значення на виході (URL API, ім’я Lambda, ім’я S3 бакета).

## Parameters

- ProjectName (String, за замовчуванням fastapi-service-3)
  - Використовується для іменування: <ProjectName>-function, <ProjectName>-api та для посилання на S3 бакет <ProjectName>-code-<AccountId>.

## Resources (призначення та ключові поля)

1) LambdaExecutionRole (AWS::IAM::Role)
- Навіщо: довірена роль, яку Lambda буде приймати для виконання.
- Ключове:
  - AssumeRolePolicyDocument: дозволяє сервісу lambda.amazonaws.com AssumeRole.
  - ManagedPolicyArns: базова політика логів AWSLambdaBasicExecutionRole.
- За потреби можна додати додаткові дозволи (наприклад доступ до S3, DynamoDB тощо).

2) FastAPIFunction (AWS::Lambda::Function)
- Навіщо: власне ваша функція з FastAPI + Mangum.
- Ключове:
  - FunctionName: <ProjectName>-function.
  - Runtime: python3.12 (має відповідати версії інтерпретатора, з якою сумісні ваші залежності).
  - Handler: lambda_function.handler (модуль та об’єкт-обробник, який створює Mangum).
  - Role: ARN ролі з LambdaExecutionRole.
  - Code: вказує де взяти артефакт:
    - S3Bucket: <ProjectName>-code-<AccountId> (створюється скриптом, НЕ шаблоном).
    - S3Key: fastapi-lambda.zip (файл, який завантажує ваш скрипт).
  - Timeout/MemorySize: ліміти виконання та пам’яті.
  - Environment: змінні середовища (опційно). PYTHONPATH=/var/task — стандартний шлях до коду в Lambda.

3) ApiGateway (AWS::ApiGateway::RestApi)
- Навіщо: вхідна точка HTTP. Дає змогу звертатися до Lambda через HTTP.
- Ключове:
  - Name: <ProjectName>-api
  - EndpointConfiguration: REGIONAL (типова конфігурація для більшості випадків).

4) ProxyResource (AWS::ApiGateway::Resource)
- Навіщо: «catch-all» ресурс для будь-якого шляху, наприклад /docs, /openapi.json, /health тощо.
- Ключове:
  - ParentId: корінь API.
  - PathPart: {proxy+} — шаблон для всіх підшляхів.

5) ProxyMethod (AWS::ApiGateway::Method)
- Навіщо: метод ANY для ресурсу {proxy+}, який працює в режимі AWS_PROXY і прокидає запит у Lambda.
- Ключове:
  - HttpMethod: ANY
  - AuthorizationType: NONE (без авторизації)
  - Integration:
    - Type: AWS_PROXY
    - IntegrationHttpMethod: POST
    - Uri: виклик Lambda через arn apigateway.

6) RootMethod (AWS::ApiGateway::Method)
- Навіщо: такий самий метод ANY, але для кореня / (щоб працював і "/").
- Ключове: аналогічно ProxyMethod, але ResourceId = RootResourceId.

7) ApiGatewayPermission (AWS::Lambda::Permission)
- Навіщо: дає API Gateway право викликати вашу Lambda.
- Ключове:
  - Action: lambda:InvokeFunction
  - FunctionName: посилання на Lambda.
  - Principal: apigateway.amazonaws.com
  - SourceArn: ARN вашого RestApi з wildcard на будь-який метод/шлях.

8) ApiDeployment (AWS::ApiGateway::Deployment)
- Навіщо: «фіксує» поточну конфігурацію API в конкретний stage (prod).
- Ключове:
  - DependsOn: RootMethod і ProxyMethod (щоб деплой відбувся після створення методів).
  - StageName: prod (це і є ваш префікс /prod у URL).

## Outputs

- ApiUrl — повний базовий URL вашого API у stage prod (використовується у скриптах).
- LambdaFunctionName — ім’я функції (зручно для оновлень).
- S3BucketName — очікуваний бакет із кодом (щоб звіряти зі скриптом деплою).

## Потік запиту

Клієнт → API Gateway (ANY /, ANY /{proxy+}) → Lambda (handler від Mangum) → FastAPI.
Оскільки stage prod додає префікс /prod, у додатку використано root_path="/prod", щоб FastAPI коректно формував посилання (зокрема /docs і /openapi.json).

## Типові помилки і як уникнути

- S3 NoSuchKey: у бакеті немає fastapi-lambda.zip. Переконайтеся, що update/deploy скрипт завантажив ZIP саме з ім’ям fastapi-lambda.zip у бакет <ProjectName>-code-<AccountId>.
- Bucket AlreadyExists / AlreadyOwnedByYou: якщо бакет створено поза CloudFormation, не створюйте його з CFN; просто посилайтеся на нього в Code. Ваш шаблон робить саме так — корректно.
- 403 на /openapi.json або /docs: зазвичай через невірний префікс stage. У Lambda за API Gateway додавайте root_path="/prod" або змінюйте StageName і root_path синхронно.

## Повна робоча версія шаблону (рекомендовано)

Нижче — приклад повної, узгодженої з вашими скриптами версії. Вона не створює S3 бакет, а лише посилається на нього.

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'FastAPI service with API Gateway, Lambda and S3'

Parameters:
  ProjectName:
    Type: String
    Default: 'fastapi-service-3'
    Description: 'Project name for resource naming'

Resources:
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

  FastAPIFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-function'
      Runtime: python3.12
      Handler: lambda_function.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        S3Bucket: !Sub '${ProjectName}-code-${AWS::AccountId}'
        S3Key: 'fastapi-lambda.zip'
      Timeout: 30
      MemorySize: 256
      Environment:
        Variables:
          PYTHONPATH: '/var/task'

  ApiGateway:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: !Sub '${ProjectName}-api'
      Description: 'FastAPI Service with AWS API Gateway'
      EndpointConfiguration:
        Types: [REGIONAL]

  ProxyResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref ApiGateway
      ParentId: !GetAtt ApiGateway.RootResourceId
      PathPart: '{proxy+}'

  ProxyMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref ApiGateway
      ResourceId: !Ref ProxyResource
      HttpMethod: ANY
      AuthorizationType: NONE
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${FastAPIFunction.Arn}/invocations'

  RootMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref ApiGateway
      ResourceId: !GetAtt ApiGateway.RootResourceId
      HttpMethod: ANY
      AuthorizationType: NONE
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${FastAPIFunction.Arn}/invocations'

  ApiGatewayPermission:
    Type: AWS::Lambda::Permission
    Properties:
      Action: lambda:InvokeFunction
      FunctionName: !Ref FastAPIFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub 'arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${ApiGateway}/*/*'

  ApiDeployment:
    Type: AWS::ApiGateway::Deployment
    DependsOn:
      - RootMethod
      - ProxyMethod
    Properties:
      RestApiId: !Ref ApiGateway
      StageName: prod

Outputs:
  ApiUrl:
    Description: 'FastAPI Service URL'
    Value: !Sub 'https://${ApiGateway}.execute-api.${AWS::Region}.amazonaws.com/prod/'

  LambdaFunctionName:
    Description: 'Lambda Function Name'
    Value: !Ref FastAPIFunction

  S3BucketName:
    Description: 'S3 Bucket for Lambda Code'
    Value: !Sub '${ProjectName}-code-${AWS::AccountId}'
```

## Узгодження зі скриптами

- deploy.sh / update_lambda.sh:
  - Формують ZIP (fastapi-lambda.zip).
  - Завантажують у бакет ${ProjectName}-code-${AccountId}.
  - Тоді або деплоять CFN (deploy.sh), або тільки оновлюють код функції (update_lambda.sh).
- Зміна ProjectName потребує:
  - Перезаливки ZIP у бакет з новою назвою.
  - Передеплою стеку або оновлення коду з новими іменами.
