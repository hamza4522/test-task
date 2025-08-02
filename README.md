# Task-2: CI/CD Pipeline for Node.js App on EC2

This project sets up a full **CI/CD pipeline using GitHub Actions** to deploy a Node.js Express app to an **Amazon EC2** instance.

---
## 📋 Prerequisites

Before using this pipeline, make sure you have:

- An **EC2 instance** running Amazon Linux with:
  - Node.js 16+ installed
  - PM2 installed globally (`npm install -g pm2`)
  - Nginx installed and configured to reverse proxy port 80 to localhost:3000
  - Security group allowing inbound HTTP (port 80) and SSH (port 22) access

- Your **private SSH key** for the `ec2-user` on the EC2 instance

- In your **GitHub repository**, add the following **Secrets** (via Settings → Secrets and variables → Actions):

  | Secret Name   | Description                                  |
  | ------------- | -------------------------------------------- |
  | `EC2_HOST`    | Public IP or DNS of your EC2 instance       |
  | `EC2_SSH_KEY` | Private SSH key for `ec2-user` (PEM format) |

---
## 🚀 What This Pipeline Does

When code is pushed to the `task-2` branch:

1. **Checks out your code**
2. **Installs Node.js dependencies**
3. **Lints your code** using ESLint
4. **Packages your app** into a zip file
5. **SCPs the app** to your EC2 instance using your SSH key
6. **SSHs into EC2**, kills the running app, replaces it, installs dependencies, and restarts the app using PM2

---

## 🧾 Required Project Files

Your repository should include:

### `server.js`

```js
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.send('<h1>Welcome to the Node.js Web App</h1>');
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
<img width="1920" height="1080" alt="Screenshot 2025-08-02 185612" src="https://github.com/user-attachments/assets/8c39ff39-1386-4d66-9e85-e16f2b5fcbd1" />
<img width="1920" height="1080" alt="Screenshot 2025-08-02 185645" src="https://github.com/user-attachments/assets/9b00a360-3deb-43c7-b1ad-5c3d59a9593c" />
<img width="1920" height="1080" alt="Screenshot 2025-08-02 185813" src="https://github.com/user-attachments/assets/d29e4e09-caeb-4595-a9fc-688e3dc803ce" />
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/21379327-b6e8-4dad-8deb-3bd672d0092b" />

