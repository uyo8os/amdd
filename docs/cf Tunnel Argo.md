1.  登录cf，点击 Zero Trust ，如果还没有开通的话就开通一下，随便输入一个”团队名字“，然后 下一步，选择免费计划，到达提示付款页面 点击 ”**取消并退出**“就可以开通了。

2.  进入 Zero Trust ，点击”**网络**“ 在这里可以添加隧道。输入名字 下一步到”**安装并运行连接器**“这里，下面有一个**请妥善保管您的令牌**，我们复制”**4运行以下命令**“复制这个令牌：

   ```
   # 复制下来就是这样的
   cloudflared.exe service install # 这段不需要，只有ey下面这个 token 就行
   eyJhIjoiMDBhZDE*******zktYjM2MmUzY2JmMjRmIiwicyI6IlpqaGtNM********
   ```

   2.1. 下一步到**添加已发布应用程序路由**，这里会让你填一些信息。

   1. 主机名：填子域名，选择域名。
      ”**路径**“ 这里跟节点一样，如果节点是 "path": "/" ，那么路径就不用管了，如果是 "path": "/mkskvc/sg1" 那么路径也要填/mkskvc/sg1
   2. 服务：“类型‘ 选择HTTP就行，”URL“ 这里填 localhost:8080 注意把8080替换成你节点的端口，然后完成。

   3. Cloudflare Tunnel Argo部署：

      ```
      bash <(curl -Ls https://raw.githubusercontent.com/uyo8os/amdd/main/install-argo.sh)
      
      1. 需要配置多少个域名->端口？(例如 2)： 只有一个节点就填1
      2. 请输入要绑定的域名：这里填刚刚添加的主机名那里填的域名，看看在刚刚添加到隧道配置里找到 已发布应用程序路由 这里有显示
      3. 请输入本地监听端口：就是节点的端口，跟”URL”这里的一样
      4. 请输入 WebSocket 路径：节点是 "path": "/" 就填 /
      5. 请输入协议类型：http 跟刚刚添加的一样
      6. 请选择凭证方式：选择1 Cloudflare Token（推荐）
         请输入 Cloudflare Tunnel Token（以 eyJ 开头）： 刚刚复制的token
         
      查看日志： journalctl -u cloudflared -f
      重启服务： systemctl restart cloudflared
      重新执行此脚本(选择2)可卸载
      
      ```

      

