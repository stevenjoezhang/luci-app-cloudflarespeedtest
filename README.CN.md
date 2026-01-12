# luci-app-cloudflarespeedtest

[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/stevenjoezhang/luci-app-cloudflarespeedtest/build.yml?style=for-the-badge&logo=GitHub)](https://github.com/stevenjoezhang/luci-app-cloudflarespeedtest/actions/workflows/build.yml)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/stevenjoezhang/luci-app-cloudflarespeedtest?style=for-the-badge)](https://github.com/stevenjoezhang/luci-app-cloudflarespeedtest/releases)

[English](README.md)

**luci-app-cloudflarespeedtest** 是一个用于 OpenWrt 的 LuCI 插件，基于 [CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest) 核心工具开发。它可以自动测试 Cloudflare IP 的延迟和下载速度，筛选出最适合当前网络环境的优选 IP，并自动更新到 SSR+、Passwall 等代理插件中，从而实现对 Cloudflare 托管网站的访问加速。

本项目 fork 自 [mingxiaoyu/luci-app-cloudflarespeedtest](https://github.com/mingxiaoyu/luci-app-cloudflarespeedtest)，并在原版基础上进行了大量的重构与改进。

## 主要特性

*   **自动测速与优选**：定期或手动运行 CloudflareSpeedTest，筛选最佳 IP。
*   **应用到代理插件**：支持自动将优选 IP 应用到 SSR+、Passwall 等常见 OpenWrt 代理工具。
*   **可视化图表**：新增历史数据图表，直观展示延迟与下载速度的波动趋势。
*   **自动下载核心**：插件包不包含核心二进制文件，首次运行时会自动下载，减小安装包体积，降低部署门槛。
*   **优化的界面与日志**：重新设计的状态展示与日志格式，进度与报错更清晰。

## 安装与使用

1.  从 [Releases](https://github.com/stevenjoezhang/luci-app-cloudflarespeedtest/releases) 页面下载最新的 `.ipk` 或 `.apk` 文件。
2.  上传到路由器并安装：
    ```bash
    opkg install luci-app-cloudflarespeedtest_*.ipk
    ```
    *注：如果安装时提示缺少依赖，请先更新 opkg 源 (`opkg update`)。*
3.  进入 LuCI 界面 -> 服务 -> CloudflareSpeedTest 进行配置。

## 截图

![概览](screenshots/overview.png)
![历史趋势](screenshots/chart.png)

## 编译

```bash
# 仅编译软件包
make package/luci-app-cloudflarespeedtest/compile V=99

# 编译完整固件
make menuconfig
#choose LuCI ---> 3. Applications  ---> <*> luci-app-cloudflarespeedtest..... for LuCI ----> save
make V=99
```

## 致谢

*   [CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest)
*   [mingxiaoyu/luci-app-cloudflarespeedtest](https://github.com/mingxiaoyu/luci-app-cloudflarespeedtest)
