# GitHub SSH Key 配置指南 (新手向)

##  简介
如果你从未接触过 Git 或 GitHub，可能会对“SSH Key”感到陌生。简单来说，**SSH Key 就像是你的“数字身份证”**。

- **为什么需要它？**
  配置好它之后，当你向 GitHub 上传（推送）文件时，GitHub 就能自动识别你是谁，而**不需要你每次都输入账号和密码**。
- **安全性：**
  它由两部分组成：
  1.  **公钥 (Public Key)**：你可以把它给任何人（在这个例子中是给 GitHub）。
  2.  **私钥 (Private Key)**：**绝对不能**给任何人，必须保存在你自己的电脑里。

---

##  第 1 步：检查现有的 Key

在生成新的 Key 之前，我们先看看电脑里是不是已经有了。

1.  打开你的 **终端 (Terminal)** (在 Mac 上按 `Command + 空格`，输入 `Terminal` 打开)。
2.  输入以下命令并按回车：

    ```bash
    ls -al ~/.ssh
    ```

3.  **观察结果：**
    - 如果你看到名为 `id_rsa.pub` 或 `id_ed25519.pub` 的文件，说明你可能已经有了。
    - 如果提示 `No such file or directory` 或者列表里没有上述文件，说明你需要从头开始（请继续看第 2 步）。

---

##  第 2 步：生成新的 SSH Key

我们将创建一个新的、安全的 Key。

1.  在终端中，复制并粘贴以下命令（**请将邮箱替换为你注册 GitHub 时的邮箱**）：

    ```bash
    ssh-keygen -t ed25519 -C "你的邮箱@example.com"
    ```

2.  **按回车键** 执行。
3.  **系统会提示你选择保存位置**：
    ```text
    Enter file in which to save the key (/Users/你的名字/.ssh/id_ed25519):
    ```
     **直接按回车键** (使用默认路径)。

4.  **系统会提示你设置密码 (Passphrase)**：
    ```text
    Enter passphrase (empty for no passphrase):
    ```
     **推荐做法**：为了实现**全自动备份**（不需要每次备份都输密码），请**直接按回车键**（留空）。
    - *注意：再次确认密码时，也直接按回车。*

5.  成功后，你会看到类似 `Your identification has been saved in...` 的提示，以及一个字符组成的“矩形图案”。

---

##  第 3 步：复制公钥内容

现在我们需要把“公钥”的内容复制出来，准备贴给 GitHub。

1.  在终端输入以下命令：

    ```bash
    cat ~/.ssh/id_ed25519.pub
    ```
    *(如果你在上一步生成的是 id_rsa，则输入 `cat ~/.ssh/id_rsa.pub`)*

2.  终端会显示一串以 `ssh-ed25519` 开头的很长的字符。
3.  **选中这串字符（从 `ssh-` 开始一直到你的邮箱结束），然后复制它 (Command + C)。**

---

##  第 4 步：添加到 GitHub

1.  打开浏览器，登录 [GitHub](https://github.com/)。
2.  点击右上角的 **头像** -> 选择 **Settings (设置)**。
3.  在左侧菜单栏中，找到并点击 **SSH and GPG keys**。
4.  点击绿色的 **New SSH key** 按钮。
5.  填写信息：
    - **Title (标题)**：随便填，比如 `我的MacBook` (方便你以后知道这是哪台电脑)。
    - **Key (密钥内容)**：点击输入框，**粘贴 (Command + V)** 你刚才在第 3 步复制的内容。
6.  点击 **Add SSH key** 按钮。
    - *GitHub 可能会要求你再次输入登录密码进行确认。*

---

##  第 5 步：测试连接

最后，我们来验证一下是否配置成功。

1.  回到终端，输入以下命令：

    ```bash
    ssh -T git@github.com
    ```

2.  如果你是第一次连接，终端会显示一段警告：
    ```text
    The authenticity of host 'github.com ...' can't be established.
    Are you sure you want to continue connecting (yes/no/[fingerprint])?
    ```
     **输入 `yes` 并按回车。**

3.  如果成功，你应该会看到类似下面的欢迎语：
    ```text
    Hi <你的用户名>! You've successfully authenticated, but GitHub does not provide shell access.
    ```

 **恭喜！你已经成功配置了 SSH Key。** 现在你可以使用本项目的自动化脚本同步你的 Obsidian 笔记了。