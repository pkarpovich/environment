# Bruno .bru File Syntax

## Basic Request

```
meta {
  name: Request Name
  type: http
  seq: 1
}

get {
  url: https://api.example.com/users
}
```

## HTTP Methods

```
get {
  url: {{BASE_URL}}/resource
}

post {
  url: {{BASE_URL}}/resource
  body: json
}

put {
  url: {{BASE_URL}}/resource/:id
  body: json
}

delete {
  url: {{BASE_URL}}/resource/:id
}

patch {
  url: {{BASE_URL}}/resource/:id
  body: json
}
```

## Request Body

### JSON

```
post {
  url: {{BASE_URL}}/users
  body: json
}

body:json {
  {
    "name": "John",
    "email": "john@example.com",
    "settings": {
      "notify": true
    }
  }
}
```

### Form URL Encoded

```
post {
  url: {{BASE_URL}}/login
  body: form-urlencoded
}

body:form-urlencoded {
  username: john
  password: secret
}
```

### Text

```
post {
  url: {{BASE_URL}}/raw
  body: text
}

body:text {
  Raw text content here
}
```

## Headers

```
headers {
  Authorization: Bearer {{TOKEN}}
  Content-Type: application/json
  X-Custom-Header: value
}
```

## Query Parameters

```
get {
  url: {{BASE_URL}}/users?page=1&limit=10
}

params:query {
  page: 1
  limit: 10
  filter: active
}
```

## Path Parameters

```
get {
  url: {{BASE_URL}}/users/:id
}

params:path {
  id: 123
}
```

## Environment File

Location: `environments/<name>.bru`

```
vars {
  BASE_URL: https://api.example.com
  TOKEN: your-api-token
  API_KEY: secret-key
}
```

## Variables

Use `{{VARIABLE_NAME}}` syntax anywhere:

```
post {
  url: {{BASE_URL}}/{{API_VERSION}}/users
}

headers {
  Authorization: Bearer {{TOKEN}}
}

body:json {
  {
    "api_key": "{{API_KEY}}"
  }
}
```

## Collection Structure

```
collection/
├── bruno.json           # Collection config
├── environments/
│   ├── Local.bru
│   ├── Dev.bru
│   └── Prod.bru
├── auth/
│   ├── login.bru
│   └── logout.bru
└── users/
    ├── list.bru
    ├── create.bru
    └── delete.bru
```

## bruno.json

```json
{
  "version": "1",
  "name": "My API",
  "type": "collection"
}
```
