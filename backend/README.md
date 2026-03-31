# PoseCoach Backend API

PoseCoach iOS App 的后端服务，提供 Pose 模板管理、App 配置下发、数据统计和 Apple 内购验证。

## 技术栈

- **FastAPI** - 异步 Web 框架
- **SQLAlchemy 2.0** - 异步 ORM
- **SQLite** - 轻量级数据库（生产可切换 PostgreSQL）
- **Pydantic v2** - 数据校验
- **Docker** - 容器化部署

## API 接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `GET /api/v1/poses/` | GET | 获取 Pose 模板列表 |
| `GET /api/v1/poses/{id}` | GET | 获取单个 Pose 详情 |
| `GET /api/v1/poses/scenes/{scene}/tips` | GET | 获取场景拍摄技巧 |
| `GET /api/v1/config/` | GET | 获取 App 配置包 |
| `POST /api/v1/analytics/event` | POST | 上报单个事件 |
| `POST /api/v1/analytics/batch` | POST | 批量上报事件 |
| `POST /api/v1/iap/verify` | POST | 验证 Apple 内购收据 |
| `GET /api/v1/health` | GET | 健康检查 |

## 快速开始

### 本地开发
```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 初始化数据库和种子数据
python scripts/seed_data.py

# 启动开发服务器
uvicorn app.main:app --reload --port 8000
```

### Docker 部署
```bash
cp .env.example .env
# 编辑 .env 填入实际配置
docker-compose up -d
```

### 查看 API 文档
启动后访问 http://localhost:8000/docs 查看自动生成的 Swagger 文档。

## 目录结构
```
backend/
├── app/
│   ├── api/           # API 路由
│   │   ├── poses.py       # Pose 模板 CRUD
│   │   ├── config.py      # App 配置下发
│   │   ├── analytics.py   # 数据统计
│   │   └── iap.py         # 内购验证
│   ├── core/          # 核心配置
│   │   ├── config.py      # 环境变量配置
│   │   ├── database.py    # 数据库连接
│   │   └── security.py    # API 鉴权
│   ├── models/        # 数据模型
│   │   ├── pose.py        # Pose 表
│   │   ├── config.py      # 配置表
│   │   ├── analytics.py   # 统计表
│   │   └── schemas.py     # Pydantic schemas
│   └── main.py        # FastAPI 入口
├── scripts/
│   └── seed_data.py   # 种子数据初始化
├── tests/
│   └── test_api.py    # API 测试
├── requirements.txt
├── Dockerfile
└── docker-compose.yml
```
