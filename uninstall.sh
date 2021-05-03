# 该脚本将在卸载期间执行，您可以编写自定义卸载规则
if [ -d /data/vendor/thermal ];then
   cp -rf $MODPATH/bak/* /data/vendor/thermal
fi
