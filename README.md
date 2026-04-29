# Robot Framework Test Environment Setup

A script that helps users quickly build a **Robot Framework** test environment based on Docker.

---

## 📋 Requirements

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- GNU bash, version 5.1.16(1)-release (x86_64-pc-linux-gnu)

---

## 🖥️ Supported Environment

| OS | Version |
|----|---------|
| Ubuntu | 22.04 |
| Ubuntu | 24.x |

## Package
| package | Version |
|---------|---------|
| gitlab-runner | 16.x |
| gitlab-runner | 18.11.1 |
| docker | 29.4.0 |
| docker compose | v5.1.2 |

---

## 🚀 Get Started

```bash
bash setup_test_master.sh
```

### Expected Output

```
[Success]: Found Docker at /usr/bin/docker (Version: 29.4.0)
[Success]: Found Docker Compose (Version: 5.1.2)
--- 檢查完成，環境已準備就緒 ---
```

---

## 🛠️ Toolkit

| Script | Description |
|--------|-------------|
| `setup_test_master.sh` | Main setup script to initialize the test environment |
| `install_docker.sh` | Helper script to install Docker if not already present |

---

## 📁 Project Structure

```
.
├── setup_test_master.sh      # Main entry point
├── install_docker.sh         # Docker installation helper
├── install_gitlab_runner.sh  # Gitlab runner installation helper
├── mount_test_data.sh        # Mount test data helper
├── pull_spx_image.sh         # Manual Pull SPX image
└── README.md
```