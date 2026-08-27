# Lua AMQP Client

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

基于 [rabbitmq-c](https://github.com/alanxz/rabbitmq-c) 的轻量级 Lua C 扩展 AMQP 客户端封装库

## 安装步骤 (Ubuntu 22.04 + Lua 5.3)

### 1. 安装系统依赖

```bash
apt update
apt install -y \
    build-essential \
    gcc \
    make \
    pkg-config \
    git \
    wget \
    curl \
    lua5.3 \
    liblua5.3-dev \
    luarocks \
    librabbitmq-dev
```

### 2. 源码编译与安装

```bash
rm -rf obj bin/amqp.so
mkdir -p obj bin
make
luarocks --lua-version=5.3 make
lua5.3 -e 'local amqp=require("amqp"); print("AMQP module loaded OK")'
```

---

## 快速上手

### 基础生产者与消费者示例

```lua
local amqp = require("amqp")

-- 1. 创建 RabbitMQ 连接
local conn = amqp.new({
  host = "127.0.0.1",
  port = 5672,
  username = "guest",
  password = "guest",
  vhost = "/"
})

-- 2. 打开通道
local channel = conn:open_channel()

-- 3. 声明队列
local queue = channel:queue_declare("test_queue")

-- 4. 发送消息到队列
queue:publish_message("Hello, RabbitMQ!")

-- 5. 消费消息（阻塞等待）
local msg, tag, props = queue:consume_message()
print("收到消息: " .. msg .. ", delivery_tag: " .. tag)

-- 6. 确认消息 (ACK)
channel:ack(tag)

-- 7. 关闭连接
conn:close()
```

### 交换机路由（Topic / Direct / Fanout / Headers）

```lua
local amqp = require("amqp")

local conn = amqp.new({ host = "127.0.0.1", port = 5672 })
local channel = conn:open_channel()

-- 声明交换机和队列
local exchange = channel:exchange_declare("logs_topic", "topic")
local queue = channel:queue_declare("error_logs")

-- 绑定队列与路由键
queue:bind("logs_topic", "*.error")

-- 发布带路由键、属性和自定义请求头的消息
exchange:publish_message(
  "app.error",
  "数据库连接异常！",
  { content_type = "text/plain" },
  { source = "auth_service", severity = "high" }
)

-- 消费消息并读取 Header
local msg, tag, props = queue:consume_message()
print("消息内容: " .. msg)
local headers = props:headers()
print("自定义 Header 'severity': " .. (headers["severity"] or "nil"))

channel:ack(tag)
conn:close()
```

### SSL / TLS 安全连接

```lua
local amqp = require("amqp")

local conn = amqp.new({
  host = "127.0.0.1",
  port = 5671,
  ssl = true,
  cacert = "/path/to/ca.pem",
  cert = "/path/to/client_cert.pem",   -- 可选
  key = "/path/to/client_key.pem",     -- 可选
  timeout = 5000000                   -- 握手超时时间（微秒）
})

local channel = conn:open_channel()
-- ...
conn:close()
```

---

## API 文档与参数说明

### 1. `amqp.new(params)`

创建并建立与 RabbitMQ Broker 的会话连接。

* **参数:** `params` (table 表)| 参数         | 类型    | 默认值 / 必填              | 说明                                         |
  | :----------- | :------ | :------------------------- | :------------------------------------------- |
  | `host`     | string  | `"127.0.0.1"`            | 服务器地址或主机名                           |
  | `port`     | number  | `5672` (SSL 为 `5671`) | 端口号                                       |
  | `username` | string  | `"guest"`                | 登录用户名                                   |
  | `password` | string  | `"guest"`                | 登录密码                                     |
  | `vhost`    | string  | `"/"`                    | 虚拟主机                                     |
  | `ssl`      | boolean | `false`                  | 是否启用 SSL/TLS                             |
  | `cacert`   | string  | `ssl = true` 时必填      | CA 证书文件路径                              |
  | `cert`     | string  | 可选                       | 客户端证书路径                               |
  | `key`      | string  | 可选                       | 客户端私钥路径                               |
  | `timeout`  | number  | `0`                      | SSL 连接超时时间（微秒，`0` 表示不设超时） |
* **返回值:** `conn` (连接会话对象 userdata)。

### 2. `conn:open_channel()`

在连接上打开一个通道（通道 ID 为 1）。

* **返回值:** `channel` (通道对象 userdata)。

### 3. `conn:close()`

关闭 AMQP 连接并释放底层 Socket 与连接资源。

---

### 4. `channel:queue_declare(name, [passive], [durable], [exclusive], [auto_delete], [arguments])`

*别名: `channel:queue(name)`*

在当前通道上声明或获取队列。

* **参数:**
  * `name` *(string, 必填)*: 队列名称。
  * `passive` *(boolean, 可选, 默认: `false`)*: 若为 true，仅检查队列是否存在，不存在则报错而不自动创建。
  * `durable` *(boolean, 可选, 默认: `true`)*: 是否持久化（Broker 重启后队列仍保留）。
  * `exclusive` *(boolean, 可选, 默认: `false`)*: 是否独占（仅对当前连接可见，连接断开自动删除）。
  * `auto_delete` *(boolean, 可选, 默认: `false`)*: 最后一个消费者断开后是否自动删除。
  * `arguments` *(table, 可选)*: 队列额外参数（如 `x-dead-letter-exchange`、TTL 等，支持字符串与整数值）。
* **返回值:** `queue` (队列对象 userdata)。

### 5. `channel:exchange_declare(name, [type], [passive], [durable], [auto_delete], [internal])`

*别名: `channel:exchange(name)`*

在当前通道上声明或获取交换机。

* **参数:**
  * `name` *(string, 必填)*: 交换机名称。
  * `type` *(string, 可选, 默认: `"direct"`)*: 交换机类型（`"direct"`, `"fanout"`, `"topic"`, `"headers"`）。
  * `passive` *(boolean, 可选, 默认: `false`)*: 是否被动声明。
  * `durable` *(boolean, 可选, 默认: `true`)*: 是否持久化。
  * `auto_delete` *(boolean, 可选, 默认: `false`)*: 是否自动删除。
  * `internal` *(boolean, 可选, 默认: `false`)*: 是否为内部交换机（客户端无法直接发布消息）。
* **返回值:** `exchange` (交换机对象 userdata)。

### 6. `channel:ack(delivery_tag, [multiple])`

确认消息（ACK）。

* **参数:**
  * `delivery_tag` *(number, 必填)*: 消费消息时获取的消息投递标识。
  * `multiple` *(boolean, 可选, 默认: `false`)*: 是否批量确认小于等于该 tag 的所有未确认消息。

### 7. `channel:nack(delivery_tag, [multiple], [requeue])`

拒绝消息（NACK）。

* **参数:**
  * `delivery_tag` *(number, 必填)*: 消息投递标识。
  * `multiple` *(boolean, 可选, 默认: `false`)*: 是否批量拒绝。
  * `requeue` *(boolean, 可选, 默认: `true`)*: 被拒绝的消息是否重新入队（false 则丢弃或进入死信队列）。

### 8. `channel:qos(prefetch_count)`

设置通道的服务质量（QoS）预取计数。

* **参数:**
  * `prefetch_count` *(number, 必填)*: 允许的最大未确认消息数量。

---

### 9. `queue:publish_message(message, [exchange], [properties], [headers])`

直接发送消息到当前队列。

* **参数:**
  * `message` *(string, 必填)*: 消息内容字符串。
  * `exchange` *(string, 可选, 默认: `""`)*: 目标交换机名称（留空则发送至默认交换机并路由到同名队列）。
  * `properties` *(table, 可选)*: AMQP 基础属性表：
    * `content_type` *(string)*
    * `content_encoding` *(string)*
    * `reply_to` *(string)*
  * `headers` *(table, 可选)*: 自定义 Header 键值对。

### 10. `queue:consume_message([no_local], [no_ack], [no_exclusive], [timeout])`

从队列中消费一条消息（阻塞调用）。

* **参数:**
  * `no_local` *(boolean, 可选, 默认: `false`)*
  * `no_ack` *(boolean, 可选, 默认: `false`)*: 是否自动确认（true 表示无需手动 `channel:ack`）。
  * `no_exclusive` *(boolean, 可选, 默认: `false`)*
  * `timeout` *(number, 可选, 默认: `0`)*: 超时时间（微秒，`0` 表示无限等待）。
* **返回值:**
  1. `msg` *(string)*: 消息主体内容。
  2. `delivery_tag` *(number)*: 消息投递标识。
  3. `properties` *(properties userdata)*: 消息属性对象。

### 11. `queue:bind(exchange_name, binding_key, [headers])`

将队列绑定到交换机。

* **参数:**
  * `exchange_name` *(string, 必填)*: 目标交换机名称。
  * `binding_key` *(string, 必填)*: 路由键或绑定模式。
  * `headers` *(table, 可选)*: 自定义 Header 表（用于 `headers` 交换机匹配）。

### 12. `queue:unbind(exchange_name, binding_key, [headers])`

解绑队列与交换机。

---

### 13. `exchange:publish_message(routing_key, message, [properties], [headers])`

向交换机发送指定 routing_key 的消息。

* **参数:**
  * `routing_key` *(string, 必填)*: 路由键。
  * `message` *(string, 必填)*: 消息内容主体。
  * `properties` *(table, 可选)*: 基础属性（`content_type`, `content_encoding`, `reply_to`）。
  * `headers` *(table, 可选)*: 自定义 Header 键值对表。

### 14. `exchange:delete([if_used])`

删除交换机。

* **参数:**
  * `if_used` *(boolean, 可选, 默认: `false`)*: 若为 true，仅在交换机未被使用时删除。

---

### 15. `properties:headers()`

从消费到的消息属性中提取 Header 键值对。

* **返回值:** `table`: 包含所有 Header 字符串键值对的 Lua 表。
