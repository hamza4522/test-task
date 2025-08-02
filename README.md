# Task-2: CI/CD Pipeline for Node.js App on EC2

This project sets up a full **CI/CD pipeline using GitHub Actions** to deploy a Node.js Express app to an **Amazon EC2** instance.

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
