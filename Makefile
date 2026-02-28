# Author: mingxiaoyu (fengying0347@163.com)
#
# Licensed to the public under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-cloudflarespeedtest

LUCI_TITLE:=LuCI support for Cloudflare Speed Test
LUCI_DEPENDS:=+!wget&&!curl:curl
LUCI_PKGARCH:=all
PKG_VERSION:=1.11
PKG_RELEASE:=0
PKG_LICENSE:=AGPL-3.0
PKG_MAINTAINER:=<https://github.com/stevenjoezhang/luci-app-cloudflarespeedtest>

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

