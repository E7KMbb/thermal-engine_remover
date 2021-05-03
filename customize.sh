##########################################################################################
#
# Magisk模块安装脚本
#
##########################################################################################
##########################################################################################
#
# 使用说明:
#
# 1. 将文件放入系统文件夹(删除placeholder文件)
# 2. 在module.prop中填写您的模块信息
# 3. 在此文件中配置和调整
# 4. 如果需要开机执行脚本，请将其添加到post-fs-data.sh或service.sh
# 5. 将其他或修改的系统属性添加到system.prop
#
##########################################################################################
##########################################################################################
#
# 安装框架将导出一些变量和函数。
# 您应该使用这些变量和函数来进行安装。
#
# !请不要使用任何Magisk的内部路径，因为它们不是公共API。
# !请不要在util_functions.sh中使用其他函数，因为它们也不是公共API。
# !不能保证非公共API在版本之间保持兼容性。
#
# 可用变量:
#
# MAGISK_VER (string):当前已安装Magisk的版本的字符串(字符串形式的Magisk版本)
# MAGISK_VER_CODE (int):当前已安装Magisk的版本的代码(整型变量形式的Magisk版本)
# BOOTMODE (bool):如果模块当前安装在Magisk Manager中，则为true。
# MODPATH (path):你的模块应该被安装到的路径
# TMPDIR (path):一个你可以临时存储文件的路径
# ZIPFILE (path):模块的安装包（zip）的路径
# ARCH (string): 设备的体系结构。其值为arm、arm64、x86、x64之一
# IS64BIT (bool):如果$ARCH(上方的ARCH变量)为arm64或x64，则为true。
# API (int):设备的API级别（Android版本）
#
# 可用函数:
#
# ui_print <msg>
#     打印(print)<msg>到控制台
#     避免使用'echo'，因为它不会显示在定制recovery的控制台中。
#
# abort <msg>
#     打印错误信息<msg>到控制台并终止安装
#     避免使用'exit'，因为它会跳过终止的清理步骤
#
##########################################################################################

##########################################################################################
# 变量
##########################################################################################

# 如果您需要更多的自定义，并且希望自己做所有事情
# 请在custom.sh中标注SKIPUNZIP=1
# 以跳过提取操作并应用默认权限/上下文上下文步骤。
# 请注意，这样做后，您的custom.sh将负责自行安装所有内容。
SKIPUNZIP=0
# 如果您需要调用Magisk内部的busybox
# 请在custom.sh中标注ASH_STANDALONE=1
ASH_STANDALONE=1

##########################################################################################
# 替换列表
##########################################################################################

# 列出你想在系统中直接替换的所有目录
# 查看文档，了解更多关于Magic Mount如何工作的信息，以及你为什么需要它


# 按照以下格式构建列表
# 这是一个示例
REPLACE_EXAMPLE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# 在这里建立您自己的清单
REPLACE="
"
##########################################################################################
# 安装设置
##########################################################################################

chmod -R 0755 $MODPATH/tools
chooseport() {
  # Keycheck binary by someone755 @Github, idea for code below by Zappo @xda-developers
  # Calling it first time detects previous input. Calling it second time will do what we want
  [ "$1" ] && local delay=$1 || local delay=3
  local error=false
  while true; do
    timeout 0 $MODPATH/tools/$ARCH32/keycheck
    timeout $delay $MODPATH/tools/$ARCH32/keycheck
    local SEL=$?
    if [ $SEL -eq 42 ]; then
      return 0
    elif [ $SEL -eq 41 ]; then
      return 1
    else
      $error && abort "- 音量键错误!"
      error=true
      echo "- 未检测到音量键。再试一次。"
    fi
  done
}

make_empty_conf() {
  ui_print "- 正在进行替换"
  mkdir -p ${MODPATH}/system/etc
  mkdir -p ${MODPATH}/system/vendor/etc
  for tconf in $(ls /system/etc/thermal-engine*.conf /system/vendor/etc/thermal-engine*.conf)
  do
    ui_print "  conf: 替换了${tconf}"
    touch ${MODPATH}${tconf}
  done
}

make_empty_bin() {
  ui_print "- 正在进行替换"
  mkdir -p ${MODPATH}/system/bin
  mkdir -p ${MODPATH}/system/vendor/bin
  mkdir ${MODPATH}/system/vendor/lib
  mkdir ${MODPATH}/system/vendor/lib64
  touch $MODPATH/system/bin/thermal-engine
  touch $MODPATH/system/vendor/bin/thermal-engine
  touch $MODPATH/system/vendor/lib/libthermalioctl.so
  touch $MODPATH/system/vendor/lib/libthermalclient.so
  touch $MODPATH/system/vendor/lib64/libthermalioctl.so
  touch $MODPATH/system/vendor/lib64/libthermalclient.so
}

make_empty_all() {
  ui_print "- 感谢coolapk@落叶凄凉TEL 提供的方法"
  ui_print "- 正在进行替换"
  find /system /vendor /product /system_ext -name "*thermal*" -o -name "*thermald*" -o -name "*thermalc*" -o -name "*perfboostsconfig.xml*" -o -name "*perfconfigstore.xml*" -o -name "*targetconfig.xml*" -o -name "*commonresourceconfigs.xml*" -o -name "*targetresourceconfigs.xml*" -type f | while read i; do
    echo "$i" | fgrep -q 'android.' && continue
    ui_print "  all: 替换了$i"
    for partition in vendor product system_ext; do
      if [ $(echo "$i" | awk -F '/' '{print $2}' | grep -c "$partition") -ne "0" ]; then
         heads="true"
         break
      fi
    done
    if [ ${heads} = "true" ]; then
       file_dir="$MODPATH/system${i%/*}"
       [[ ! -d $file_dir ]] && mkdir -p $file_dir
       touch $MODPATH/system$i
    else
       file_dir="$MODPATH${i%/*}"
       [[ ! -d $file_dir ]] && mkdir -p $file_dir
       touch $MODPATH$i
    fi
  done
  if [ -d /data/vendor/thermal ];then
     mkdir -p $MODPATH/bak
     cp -rf /data/vendor/thermal/* $MODPATH/bak
     rm -rf /data/vendor/thermal/*
  fi
}

rebak() {
  sh $MODPATH/uninstall.sh
}

rebak
ui_print " "
ui_print " - 选择方法 -"
ui_print "   选择您想要使用的替换方法:"
ui_print "   [音量+] = conf & binary (推荐)"
ui_print "   [音量-] = all(删的最全，但有能发生各种意外，如果没有必要请不要选择)"
ui_print " "
if chooseport; then
  ui_print "   选择您想要使用的替换方法:"
  ui_print "   [音量+] = conf(推荐)"
  ui_print "   [音量-] = binary(如果conf模式不生效，请尝试这个)"
  ui_print " "
  if chooseport; then
    make_empty_conf
  else
    make_empty_bin
  fi
else
  make_empty_all
fi

# 删除多余文件
 rm -rf \
 $MODPATH/system/placeholder $MODPATH/customize.sh \
 $MODPATH/*.md $MODPATH/.git* $MODPATH/LICENSE $MODPATH/tools 4>/dev/null

##########################################################################################
# 权限设置
##########################################################################################

# 请注意，magisk模块目录中的所有文件/文件夹都有$MODPATH前缀-在所有文件/文件夹中保留此前缀
# 一些例子:
  
# 对于目录(包括文件):
# set_perm_recursive  <目录>                <所有者> <用户组> <目录权限> <文件权限> <上下文> (默认值是: u:object_r:system_file:s0)
  
# set_perm_recursive $MODPATH/system/lib 0 0 0755 0644
# set_perm_recursive $MODPATH/system/vendor/lib/soundfx 0 0 0755 0644

# 对于文件(不包括文件所在目录)
# set_perm  <文件名>                         <所有者> <用户组> <文件权限> <上下文> (默认值是: u:object_r:system_file:s0)
  
# set_perm $MODPATH/system/lib/libart.so 0 0 0644
# set_perm /data/local/tmp/file.txt 0 0 644

# 默认权限请勿删除
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm  $MODPATH/system/bin/thermal-engine 0 0 0755
set_perm  $MODPATH/system/vendor/bin/thermal-engine 0 0 0755
